-- KnifeManager: server-authoritative knife hits + projectile broadcast.
-- Damage is gated so only a player actually holding the SeekerKnife (the seeker) can deal it;
-- a client firing KnifeHit without the tool is ignored, which closes the obvious kill-anyone exploit.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")
local KnifeFolder = ReplicatedStorage.Knife

local KnifeRemotes = KnifeFolder.Remotes
local KnifeUtil = KnifeFolder.Util

local GetPlayerFromPart = require(KnifeUtil.Hooks.GetPlayerFromPart)
local KnifeProjectileArgsType = require(KnifeUtil.Types.KnifeProjectileArgs)

-- Role lookup so we can block seeker-vs-seeker damage (multiple seekers exist when players use the
-- "Join As Seeker" prompt). MatchManager exposes a GetRole BindableFunction returning "Hider"/
-- "Seeker"/nil for a player. We resolve it lazily (MatchManager may not be loaded yet at require time)
-- and pcall the invoke so a missing/erroring API never blocks a legitimate hit.
local ServerScriptService = game:GetService("ServerScriptService")
local function getRole(plr)
	local mm = ServerScriptService:FindFirstChild("MatchManager")
	local api = mm and mm:FindFirstChild("GetRole")
	if not api then return nil end
	local ok, role = pcall(function() return api:Invoke(plr) end)
	return ok and role or nil
end

-- Authoritative participant checks from MatchManager. These are STRICTER than getRole and are what
-- actually close the lobby-kill exploits:
--   IsKnifeTarget(plr)   -> true only for an alive hider who is still IN the round (NOT a found hider
--                           who was sent back to the lobby; a found hider keeps the "Hider" role until
--                           round end, so a role-only check would let them be killed at spawn).
--   IsKnifeAttacker(plr) -> true only for a seeker who is still an ACTIVE participant (NOT one flagged
--                           out by death/reset/leave; a converted seeker who reset back to the lobby
--                           with a stale knife must not be able to kill).
-- Both fail-CLOSED: if the API is missing/errors we return false, so a hit is ignored rather than
-- wrongly allowed.
local function isKnifeTarget(plr)
	local mm = ServerScriptService:FindFirstChild("MatchManager")
	local api = mm and mm:FindFirstChild("IsKnifeTarget")
	if not api then return false end
	local ok, res = pcall(function() return api:Invoke(plr) end)
	return ok and res == true
end
local function isKnifeAttacker(plr)
	local mm = ServerScriptService:FindFirstChild("MatchManager")
	local api = mm and mm:FindFirstChild("IsKnifeAttacker")
	if not api then return false end
	local ok, res = pcall(function() return api:Invoke(plr) end)
	return ok and res == true
end

-- Current match phase comes from MatchManager when available, with MatchTelemetry only as a fallback.
-- Knife kills are valid only during ROUND, so late hits during resolve/reveal cannot zero a hider.
local MatchTelemetry = ReplicatedStorage:FindFirstChild("MatchTelemetry")
local function currentMatchPhase()
	local mm = ServerScriptService:FindFirstChild("MatchManager")
	local api = mm and mm:FindFirstChild("GetPhase")
	if api then
		local ok, phase = pcall(function()
			return api:Invoke()
		end)
		if ok and typeof(phase) == "string" then
			return phase
		end
	end
	if not MatchTelemetry then
		MatchTelemetry = ReplicatedStorage:FindFirstChild("MatchTelemetry")
	end
	local v = (MatchTelemetry and MatchTelemetry.Value) or ""
	return v:match("^[^ |]+") or ""
end

local function isSeekPhase()
	local phase = currentMatchPhase()
	return phase == "ROUND" or phase == "HUNT"
end

-- True only if the attacker currently has the SeekerKnife (equipped on the character or in their
-- backpack). This is what gates damage to the actual seeker.
local function attackerHasKnife(player: Player): boolean
	local char = player.Character
	if char and char:FindFirstChild("SeekerKnife") then return true end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack and backpack:FindFirstChild("SeekerKnife") then return true end
	return false
end

-- Play the hider death sound as a 3D positional sound at the kill location, so everyone nearby
-- (the seeker AND other hiders) hears it with distance falloff — a death is an audible event that
-- gives away where it happened. Same short-lived anchored-emitter pattern as the coin/taunt sounds.
local function playDeathSoundAt(position: Vector3)
	local template = SoundService:FindFirstChild("DeathSoundEffectHider")
	if not template then return end

	local emitter = Instance.new("Part")
	emitter.Name = "DeathSoundEmitter"
	emitter.Anchored = true
	emitter.CanCollide = false
	emitter.CanQuery = false
	emitter.CanTouch = false
	emitter.Transparency = 1
	emitter.Size = Vector3.new(1, 1, 1)
	emitter.CFrame = CFrame.new(position)
	emitter.Parent = Workspace

	local sound = template:Clone()
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 10   -- full volume within 10 studs
	sound.RollOffMaxDistance = 180  -- inaudible beyond ~180 studs (2x the old 90-stud range)
	do
		local sfx = SoundService:FindFirstChild("SFX")
		if sfx then sound.SoundGroup = sfx end  -- obey the Settings SFX slider (per-client)
	end
	sound.Parent = emitter
	sound:Play()
	sound.Ended:Connect(function() emitter:Destroy() end)
	task.delay((sound.TimeLength > 0 and sound.TimeLength or 2) + 0.5, function()
		if emitter and emitter.Parent then emitter:Destroy() end
	end)
end

-- ===== anti-exploit state (per attacker) =====
-- lastThrow[player]     = { x0, dir (unit), at = os.clock() } of their last VALIDATED projectile
--                         broadcast; a "throw" kill must line up with this path (see KnifeHit).
-- lastBroadcast[player] = os.clock() of their last projectile broadcast (rate limit).
-- lastKill[player]      = os.clock() of their last accepted kill (cooldown vs scripted spam).
local lastThrow = {}
local lastBroadcast = {}
local lastKill = {}
Players.PlayerRemoving:Connect(function(plr)
	lastThrow[plr] = nil
	lastBroadcast[plr] = nil
	lastKill[plr] = nil
end)

local STAB_RANGE = 16            -- max studs attacker->victim for a stab (melee reach + mobile-latency slack)
local THROW_PATH_TOLERANCE = 14  -- max studs the victim may sit OFF the thrown knife's straight path
local THROW_MAX_TRAVEL = 240     -- max studs ALONG the path (client projectile speed is 200/s; spans the map)
local THROW_WINDOW = 3           -- seconds a recorded throw stays valid for a hit (~1s max flight + slack)
local KILL_COOLDOWN = 0.15       -- min seconds between accepted kills per attacker
local BROADCAST_COOLDOWN = 0.25  -- min seconds between projectile broadcasts per attacker

-- Simple line-of-sight check: ray from `origin` toward the target's HumanoidRootPart, ignoring the
-- attacker's character. If nothing blocks the ray or the first thing hit is part of the target, it's valid.
local function hasLineOfSight(origin: Vector3, attackerChar: Instance, targetChar: Instance): boolean
	local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
	if not targetRoot then return false end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { attackerChar }
	params.IgnoreWater = true

	local result = workspace:Raycast(origin, targetRoot.Position - origin, params)
	if not result then
		return true
	end
	return targetChar:IsAncestorOf(result.Instance)
end

KnifeRemotes.RenderKnifeProjectile.OnServerEvent:Connect(function(player: Player, knifeArgs: KnifeProjectileArgsType.KnifeProjectileArgs)
	-- VALIDATE before re-broadcasting. Previously this forwarded whatever table the client sent
	-- straight to ALL clients — a visual-spam / junk-payload vector. Now: only an active, knife-holding
	-- seeker during the seek phase may broadcast; the payload is REBUILT from whitelisted, type-checked
	-- fields (nothing else passes through); the origin must be at the attacker; and broadcasts are rate
	-- limited per attacker. The validated path is also recorded so "throw" kills can be checked against
	-- where the knife actually flew.
	if typeof(knifeArgs) ~= "table" then return end
	if not isSeekPhase() then return end
	if not attackerHasKnife(player) then return end
	if not isKnifeAttacker(player) then return end

	local now = os.clock()
	if lastBroadcast[player] and (now - lastBroadcast[player]) < BROADCAST_COOLDOWN then return end

	local x0, dir, t0 = knifeArgs.x0, knifeArgs.dir, knifeArgs.t0
	if typeof(x0) ~= "Vector3" or typeof(dir) ~= "Vector3" or typeof(t0) ~= "number" then return end
	if dir.Magnitude < 1e-3 or dir.Magnitude ~= dir.Magnitude then return end  -- zero or NaN direction
	dir = dir.Unit

	-- the projectile must launch from (about) where the attacker actually is
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or (x0 - root.Position).Magnitude > 15 then return end

	-- rebuild a CLEAN payload (whitelist) rather than forwarding the raw client table
	local clean = {
		t0 = t0,
		x0 = x0,
		dir = dir,
		sender = player,
		skinTexture = (typeof(knifeArgs.skinTexture) == "string") and knifeArgs.skinTexture or nil,
		effectId = (typeof(knifeArgs.effectId) == "string") and knifeArgs.effectId or nil,
		meshId = (typeof(knifeArgs.meshId) == "string") and knifeArgs.meshId or nil,
		meshScale = (typeof(knifeArgs.meshScale) == "Vector3") and knifeArgs.meshScale or nil,
		meshTextureId = (typeof(knifeArgs.meshTextureId) == "string") and knifeArgs.meshTextureId or nil,
	}

	lastBroadcast[player] = now
	lastThrow[player] = { x0 = x0, dir = dir, at = now }  -- "throw" kills validate against this path
	KnifeRemotes.RenderKnifeProjectile:FireAllClients(clean)
end)

KnifeRemotes.KnifeHit.OnServerEvent:Connect(function(player: Player, type: "throw" | "stab", hitInstance: BasePart)
	if typeof(hitInstance) ~= "Instance" or not hitInstance:IsA("BasePart") then return end
	if type ~= "stab" and type ~= "throw" then return end
	-- knives only kill during the seek phase — never in the lobby/intermission/resolve. This is the
	-- hard backstop that prevents a seeker who somehow holds a knife off the map from killing lobby
	-- players (e.g. if a Join-As-Seeker placement failed).
	if not isSeekPhase() then return end
	-- only the seeker (a player actually holding the knife) may deal damage
	if not attackerHasKnife(player) then return end
	-- ...and only if MatchManager still considers them an ACTIVE seeker. A seeker who died/reset/left
	-- (flagged out) is back in the lobby; even if a stale knife lingers on them, they cannot kill.
	if not isKnifeAttacker(player) then return end

	local targetPlayer = GetPlayerFromPart(hitInstance)
	if not targetPlayer or targetPlayer == player or not targetPlayer.Character then
		return
	end

	-- The target must be an ALIVE HIDER STILL IN THE ROUND (IsKnifeTarget). This blocks seeker-vs-seeker
	-- damage AND — crucially — a hit on a FOUND hider who was sent back to the lobby (they keep the
	-- "Hider" role until round end, so a role-only check would wrongly allow killing them at spawn).
	if not isKnifeTarget(targetPlayer) then
		return
	end

	-- ignore hits on an already-dead victim, so we don't double-play the death sound / re-kill
	local victimHum = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
	if not victimHum or victimHum.Health <= 0 then
		return
	end

	-- ===== RANGE / PATH VALIDATION =====
	-- The client names the part it hit, so without these checks an exploiting seeker could "hit" any
	-- hider anywhere on the map without aiming. A STAB must happen within melee reach of the attacker.
	-- A THROW must line up with the attacker's last REAL projectile (recorded when their validated
	-- RenderKnifeProjectile broadcast went out): recent, victim near the straight flight path, and at a
	-- plausible distance along it. Legit hits always pass: the client broadcasts the projectile when it
	-- throws, so the path is on record before the hit arrives.
	local now = os.clock()
	if lastKill[player] and (now - lastKill[player]) < KILL_COOLDOWN then return end
	local attackerRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local victimRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not attackerRoot or not victimRoot then return end
	if type == "stab" then
		if (victimRoot.Position - attackerRoot.Position).Magnitude > STAB_RANGE then return end
		-- The client now uses a blade-sized hitbox; make sure the server also rejects through-wall stabs.
		if not hasLineOfSight(attackerRoot.Position, player.Character, targetPlayer.Character) then return end
	else -- "throw"
		local throwRec = lastThrow[player]
		if not throwRec or (now - throwRec.at) > THROW_WINDOW then return end
		local rel = victimRoot.Position - throwRec.x0
		local along = rel:Dot(throwRec.dir)                    -- distance down the flight path
		if along < -5 or along > THROW_MAX_TRAVEL then return end
		local lateral = (rel - throwRec.dir * along).Magnitude -- distance off the path
		if lateral > THROW_PATH_TOLERANCE then return end
		-- Ensure the victim was actually visible from the throw origin (no shooting through walls).
		if not hasLineOfSight(throwRec.x0, player.Character, targetPlayer.Character) then return end
	end
	lastKill[player] = now

	-- play the death sound at the victim's location (positional, heard by seeker + nearby hiders)
	playDeathSoundAt(victimRoot.Position)

	-- Kill the hider by zeroing their Humanoid health rather than BreakJoints(). BreakJoints destroys
	-- every Motor6D on the character, and since the corpse system clones the body on the resulting
	-- Died event, a broken-joint body produces a corpse that falls apart into loose limbs. Setting
	-- Health = 0 fires Died identically but leaves the joints intact, so RagdollCorpse clones a whole
	-- body (this is why reset-deaths looked fine but knife-deaths shattered).
	if victimHum then
		local oldTag = victimHum:FindFirstChild("LastKnifeKiller")
		if oldTag then
			oldTag:Destroy()
		end
		local killerTag = Instance.new("ObjectValue")
		killerTag.Name = "LastKnifeKiller"
		killerTag.Value = player
		killerTag.Parent = victimHum
		Debris:AddItem(killerTag, 5)
		victimHum.Health = 0
	end
end)
