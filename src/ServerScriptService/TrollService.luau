-- TrollService (server): applies a purchased troll to seeker target(s) and fires the notification
-- banners. Server-authoritative — only ever called from MatchManager.ProcessReceipt AFTER it has
-- validated the buyer is an active hider in the ROUND phase. This module does NOT re-validate the
-- buyer (the receipt handler owns that); it DOES resolve the seeker target pool from the live match
-- state via the MatchManager BindableFunctions, so it always acts on who's actually seeking right now.
--
-- Effect split:
--   * Jumpscare / Flashbang / Confusion  -> client-driven (fired via TrollNotify { effect = ... }):
--       movement input + fullscreen visuals live on the client, so the client owns them.
--   * Freeze / Trip                      -> server-applied to the character (walkspeed/blue tint,
--       ragdoll-style stumble), since they touch the Humanoid/physics the server controls.
-- Every troll also fires the red countdown banner to the target ("You have been trolled by X!") and
-- to the buyer ("You trolled X!"), reusing the Reveal banner look on the client.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

local TrollConfig = require(ReplicatedStorage:WaitForChild("TrollConfig"))

local TrollService = {}

-- wired by MatchManager.init-time call so we don't hard-depend on load order
local MatchManager           -- the MatchManager Script instance (holds the Bindable APIs as children)
local TrollNotify            -- RemoteEvent (server -> the trolled seeker + buyer)
local TrollBroadcast         -- RemoteEvent (server -> ALL clients: public "X trolled Y" toast)

function TrollService.bind(matchManagerScript)
	MatchManager = matchManagerScript
	local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
	TrollNotify = Remotes:WaitForChild("TrollNotify")
	TrollBroadcast = Remotes:WaitForChild("TrollBroadcast")
end

-- ===== 3D positional troll sound (heard by anyone within ~50 studs of the target) =====
-- The effect sounds live in SoundService.TrollSounds. We play them as a 3D Sound parented to a
-- short-lived emitter at the TARGET's position so they fall off with distance: the sound gets
-- progressively LOUDER the closer a listener is, and fades to silence by ~50 studs. Nearby players
-- (other seekers/hiders) hear the troll happen, but it isn't a global 2D blast.
local SOUND_HEAR_DISTANCE = 50  -- studs: inaudible past this; volume scales up the closer you get
local SOUND_FULL_DISTANCE = 6   -- studs: at/inside this it's full volume; between here and 50 it ramps
local TROLL_SOUND_NAMES = {     -- effect key -> Sound name in SoundService.TrollSounds
	Jumpscare = "Jumpscare",
	Flashbang = "flashbang",
	Trip = "Trip",
	Freeze = "Freeze",
	Confusion = "Confuse",        -- note: effect KEY is "Confusion", the Sound is named "Confuse"
}
local function playTrollSoundAt(target, effectKey)
	local soundName = TROLL_SOUND_NAMES[effectKey]
	if not soundName then return end
	local folder = SoundService:FindFirstChild("TrollSounds")
	local template = folder and folder:FindFirstChild(soundName)
	if not template then return end
	local char = target.Character
	local root = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
	if not root then return end

	-- anchored, invisible emitter at the target so the sound is positional (carries the 3D rolloff).
	local emitter = Instance.new("Part")
	emitter.Name = "TrollSoundEmitter"
	emitter.Anchored = true
	emitter.CanCollide = false
	emitter.CanQuery = false
	emitter.CanTouch = false
	emitter.Transparency = 1
	emitter.Size = Vector3.new(1, 1, 1)
	emitter.CFrame = root.CFrame
	emitter.Parent = workspace

	local sound = template:Clone()
	sound.Looped = false
	-- InverseTapered rolloff = volume ramps up as the listener nears the emitter (proximity falloff).
	-- Full volume within SOUND_FULL_DISTANCE, tapering to silence by SOUND_HEAR_DISTANCE (50 studs).
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = SOUND_FULL_DISTANCE
	sound.RollOffMaxDistance = SOUND_HEAR_DISTANCE
	sound.Parent = emitter
	sound:Play()
	-- clean up when finished (or after a safe window if Ended never fires)
	sound.Ended:Once(function() emitter:Destroy() end)
	Debris:AddItem(emitter, 12)
end

local function getActiveSeekers()
	if not MatchManager then return {} end
	local api = MatchManager:FindFirstChild("GetActiveSeekers")
	if not api then return {} end
	local ok, list = pcall(function() return api:Invoke() end)
	if ok and type(list) == "table" then return list end
	return {}
end

-- ===== target resolution =====
-- "all" -> every active seeker. "one" -> the active seeker physically NEAREST to the buyer (matches
-- how Reveal One picks its target). Falls back to a random active seeker if positions can't be read.
local function resolveTargets(buyer, scope)
	local seekers = getActiveSeekers()
	if #seekers == 0 then return {} end
	if scope == "all" then return seekers end

	local bChar = buyer.Character
	local bRoot = bChar and bChar:FindFirstChild("HumanoidRootPart")
	if bRoot then
		local best, bestDist = nil, math.huge
		for _, s in ipairs(seekers) do
			local sChar = s.Character
			local sRoot = sChar and sChar:FindFirstChild("HumanoidRootPart")
			if sRoot then
				local d = (sRoot.Position - bRoot.Position).Magnitude
				if d < bestDist then best, bestDist = s, d end
			end
		end
		if best then return { best } end
	end
	-- fallback: random active seeker (buyer mid-respawn / no positions)
	return { seekers[math.random(1, #seekers)] }
end

-- ===== server-applied effects =====

-- Freeze: walkspeed clamped low + body tinted blue for FREEZE_SECONDS, then restored. We save and
-- restore each part's original Color so skins/colors come back exactly. Guarded with a per-character
-- token so overlapping freezes (two buyers) don't restore early or leave the tint stuck.
local freezeToken = setmetatable({}, { __mode = "k" })  -- [character] = number
local function applyFreeze(target)
	local char = target.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	freezeToken[char] = (freezeToken[char] or 0) + 1
	local myToken = freezeToken[char]

	local originalColors = {}
	for _, p in ipairs(char:GetDescendants()) do
		if p:IsA("BasePart") then
			originalColors[p] = p.Color
			p.Color = TrollConfig.FREEZE_COLOR
		end
	end

	local prevSpeed = hum.WalkSpeed
	hum.WalkSpeed = TrollConfig.FREEZE_WALKSPEED

	task.delay(TrollConfig.FREEZE_SECONDS, function()
		-- only the most recent freeze on this character restores, so a second freeze extends cleanly
		if freezeToken[char] ~= myToken then return end
		if hum and hum.Parent then
			-- restore to the round hider/seeker speed rather than a stale captured value where possible:
			-- the seeker speed is the live correct one. Fall back to the captured prevSpeed.
			hum.WalkSpeed = prevSpeed
		end
		for p, col in pairs(originalColors) do
			if p and p.Parent then p.Color = col end
		end
	end)
end

-- Trip: a brief stumble using the engine's Ragdoll state. This is much cleaner than PlatformStand
-- because the humanoid stays in its normal state machine and can recover automatically.
-- We disable GettingUp while ragdolled so the player doesn't pop back up early, then re-enable it
-- and request GettingUp when the trip ends. Per-character token so overlapping trips don't un-ragdoll
-- the victim too soon.
local tripToken = setmetatable({}, { __mode = "k" })
local function applyTrip(target)
	local char = target.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	tripToken[char] = (tripToken[char] or 0) + 1
	local myToken = tripToken[char]

	-- kill momentum so a running/jumping seeker isn't flung across the map
	local root = char:FindFirstChild("HumanoidRootPart")
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end

	pcall(function()
		hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
		hum:ChangeState(Enum.HumanoidStateType.Ragdoll)
	end)

	task.delay(TrollConfig.TRIP_SECONDS, function()
		if tripToken[char] ~= myToken then return end
		if not (hum and hum.Parent) then return end

		pcall(function()
			hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
			hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		end)

		-- safety net: if the engine didn't get them up, force a normal locomotion state
		task.delay(0.5, function()
			if tripToken[char] ~= myToken then return end
			if not (hum and hum.Parent) then return end
			local state = hum:GetState()
			if state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.FallingDown then
				hum:ChangeState(Enum.HumanoidStateType.RunningNoPhysics)
			end
		end)
	end)
end

-- ===== notifications =====
-- Banner to the trolled seeker + the buying hider, plus (for client-driven effects) the effect cue.
-- Also plays the effect's 3D sound at the target so nearby players hear it (see playTrollSoundAt).
local function notifyTarget(target, buyerName, effectKey)
	if not TrollNotify then return end
	-- the visual/movement effect cue (only the client-driven ones carry an effect)
	if effectKey == "Jumpscare" then
		TrollNotify:FireClient(target, { effect = "Jumpscare", duration = TrollConfig.JUMPSCARE_SECONDS })
	elseif effectKey == "Flashbang" then
		TrollNotify:FireClient(target, { effect = "Flashbang", duration = TrollConfig.FLASHBANG_SECONDS })
	elseif effectKey == "Confusion" then
		TrollNotify:FireClient(target, { effect = "Confusion", duration = TrollConfig.CONFUSION_SECONDS })
	end
	-- 3D positional sound at the target (heard within ~30 studs by everyone, including the target)
	playTrollSoundAt(target, effectKey)
	-- the red countdown banner ("You have been trolled by X! (Ns)")
	TrollNotify:FireClient(target, { banner = "trolled", by = buyerName, duration = TrollConfig.BANNER_SECONDS })
end

-- ===== public entry point =====
-- Apply a troll. key is a TrollConfig.Trolls key; scope is "one"|"all". buyer is the active hider who
-- paid. Returns the number of seekers actually trolled (0 if none were around — caller still grants,
-- mirroring Reveal's "buyer chose to buy" policy). Never errors out of the receipt handler.
function TrollService.apply(buyer, key, scope)
	local def = TrollConfig.Trolls[key]
	if not def then return 0 end

	local targets = resolveTargets(buyer, scope)
	for _, target in ipairs(targets) do
		if target and target.Parent then
			if key == "Freeze" then
				applyFreeze(target)
			elseif key == "Trip" then
				applyTrip(target)
			end
			-- client-driven effects + the "you got trolled" banner
			notifyTarget(target, buyer.Name, key)
		end
	end

	-- buyer's own confirmation banner ("You trolled X! (Ns)"). For "all" we say "all seekers".
	local targetLabel
	if scope == "all" then
		targetLabel = "all seekers"
	elseif #targets > 0 then
		targetLabel = targets[1].Name
	else
		targetLabel = "nobody"
	end
	if TrollNotify then
		TrollNotify:FireClient(buyer, { banner = "buyer", target = targetLabel, duration = TrollConfig.BANNER_SECONDS })
	end

	-- public broadcast to EVERYONE: "<buyer> trolled <target> with <Effect>!" (fades after 3s client-side).
	-- Only announce when at least one seeker was actually trolled, so an empty round doesn't spam a toast.
	if TrollBroadcast and #targets > 0 then
		TrollBroadcast:FireAllClients({
			buyer = buyer.Name,
			target = targetLabel,
			effect = def.name or key,
		})
	end

	return #targets
end

-- ===== DEBUG ONLY =====
-- Apply an effect DIRECTLY to a specific player, bypassing seeker resolution and all validation.
-- This exists solely so TrollDebug can let you SEE each effect on yourself in Studio without needing
-- a real round, a seeker, or a completed purchase. It is NOT used by the real purchase path. Safe to
-- delete along with the TrollDebug script before release.
function TrollService.debugApplyTo(target, key, buyerName)
	local def = TrollConfig.Trolls[key]
	if not def or not target or not target.Parent then return false end
	if key == "Freeze" then
		applyFreeze(target)
	elseif key == "Trip" then
		applyTrip(target)
	end
	notifyTarget(target, buyerName or "DEBUG", key)
	return true
end

return TrollService
