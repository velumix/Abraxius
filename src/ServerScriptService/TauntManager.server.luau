-- TauntManager: during a round, each active hider periodically emits a random "taunt" sound at
-- their location. The sound is a 3D positional sound played on the SERVER (like the coin pickup
-- sound), so the seeker can hear it with distance falloff and search near that spot.
--
-- STAGGERING: to avoid a cluster of taunts all firing at once, we don't give every hider their own
-- independent 30s timer. Instead we run ONE rotation: the 30s cycle is divided into N equal windows
-- (N = number of active hiders), and we play exactly one hider's taunt per window, cycling through
-- the hiders in order. So each hider taunts once per ~30s, and no two taunts share a window.

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local StudsConverter = require(ServerStorage:WaitForChild("StudsConverter"))
local MatchState = require(ServerScriptService:WaitForChild("Match"):WaitForChild("MatchState"))

local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"))
local CustomTauntService
local function getCustomTauntService()
	if not CustomTauntService then
		CustomTauntService = Knit.GetService("CustomTauntService")
	end
	return CustomTauntService
end
local CoinService
local function getCoinService()
	if not CoinService then
		CoinService = Knit.GetService("CoinService")
	end
	return CoinService
end
local function getCustomTauntSoundId(player)
	local svc = getCustomTauntService()
	return svc and svc:GetSoundId(player) or ""
end

local TauntSounds = SoundService:WaitForChild("TauntSounds")

-- MatchManager publishes the current phase as the first token of MatchTelemetry.Value
-- (e.g. "ROUND | hiders=..."). Manual taunts are allowed during the HIDE head-start AND the ROUND
-- (seek) phase — a hider can choose to taunt in either, but never in the lobby/intermission.
local MatchTelemetry = ReplicatedStorage:WaitForChild("MatchTelemetry")

local function isRoundActive()
	local v = MatchTelemetry.Value or ""
	return v:sub(1, 5) == "ROUND" or v:sub(1, 4) == "HIDE"
end

local function isReverseRaceTauntPhase()
	return MatchState.current == "PREVIEW" or MatchState.current == "HUNT"
end

-- ===== tuning =====
local ROLLOFF_MIN = 10         -- full volume within this many studs
local ROLLOFF_MAX = 180        -- inaudible beyond ~this many studs (2x the old 90-stud range)

-- collect the taunt sound templates once
local taunts = {}
for _, s in ipairs(TauntSounds:GetChildren()) do
	if s:IsA("Sound") then
		table.insert(taunts, s)
	end
end

-- An active hider = a player whose character is currently studs-converted (on the map, hiding) and
-- alive. Used by the manual-taunt validation below (see isActiveHider).

-- Play a random taunt as a 3D positional sound at a world position (server-side, so everyone
-- nearby — including the seeker — hears it with falloff). A short-lived anchored emitter carries
-- the sound, then cleans itself up.
local function playTauntAt(position, customSoundId)
	local emitter = Instance.new("Part")
	emitter.Name = "TauntSoundEmitter"
	emitter.Anchored = true
	emitter.CanCollide = false
	emitter.CanQuery = false
	emitter.CanTouch = false
	emitter.Transparency = 1
	emitter.Size = Vector3.new(1, 1, 1)
	emitter.CFrame = CFrame.new(position)
	emitter.Parent = Workspace

	local sound
	if customSoundId and customSoundId ~= "" then
		sound = Instance.new("Sound")
		sound.SoundId = "rbxassetid://" .. customSoundId
		sound.Volume = 0.6
	else
		if #taunts == 0 then
			emitter:Destroy()
			return
		end
		local template = taunts[math.random(1, #taunts)]
		sound = template:Clone()
	end

	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = ROLLOFF_MIN
	sound.RollOffMaxDistance = ROLLOFF_MAX
	do
		local sfx = game:GetService("SoundService"):FindFirstChild("SFX")
		if sfx then sound.SoundGroup = sfx end
	end
	sound.Parent = emitter
	sound:Play()
	sound.Ended:Connect(function() emitter:Destroy() end)
	task.delay((sound.TimeLength > 0 and sound.TimeLength or 3) + 0.5, function()
		if emitter and emitter.Parent then emitter:Destroy() end
	end)
end

-- ===== manual taunt (the LeftHUD TauntButton) =====
-- A hider can press the TauntButton to play a taunt on demand. We validate server-side that they
-- are an active hider in the seek phase, and enforce a 5s per-player cooldown so it can't be spammed.
local MANUAL_COOLDOWN = 5
local lastManualTaunt = {}  -- [player] = os.clock() of their last manual taunt

local GameRemotes = ReplicatedStorage:WaitForChild("GameRemotes")
local ManualTaunt = GameRemotes:FindFirstChild("ManualTaunt")
if not ManualTaunt then
	ManualTaunt = Instance.new("RemoteEvent")
	ManualTaunt.Name = "ManualTaunt"
	ManualTaunt.Parent = GameRemotes
end

local function hasAliveCharacterRoot(plr)
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return char, hum, root, hum and hum.Health > 0 and root ~= nil
end

local function isActiveHider(plr)
	local char, _, _, alive = hasAliveCharacterRoot(plr)
	return alive and char and StudsConverter.isConverted(char)
end

local function isReverseRaceTauntHider(plr)
	local _, _, _, alive = hasAliveCharacterRoot(plr)
	return alive
		and plr:GetAttribute("ReverseRaceFreeCam") == true
		and MatchState.roles[plr] == "Hider"
		and isReverseRaceTauntPhase()
end

local MANUAL_TAUNT_REWARD = 10  -- coins granted for a manual taunt (gameplay earning)

ManualTaunt.OnServerEvent:Connect(function(plr)
	local reverseRaceHider = isReverseRaceTauntHider(plr)
	if not (isRoundActive() or reverseRaceHider) then return end  -- allowed during regular HIDE/ROUND and reverse-race target turns
	if not (isActiveHider(plr) or reverseRaceHider) then return end
	local now = os.clock()
	local last = lastManualTaunt[plr]
	if last and (now - last) < MANUAL_COOLDOWN then return end  -- still on cooldown; ignore
	lastManualTaunt[plr] = now
	local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	if root then
		playTauntAt(root.Position, getCustomTauntSoundId(plr))
	end
	-- reward the taunt with coins (a gameplay earning: Double-Coins eligible, blocked in private
	-- servers like other earnings). Tell the client to show the "+N COINS" popup ONLY when coins are
	-- actually granted (i.e. not in a private server), so the popup never lies.
	if game.PrivateServerId == "" then
		local svc = getCoinService()
		if svc then
			svc:Award(plr, MANUAL_TAUNT_REWARD, "manual taunt")
			ManualTaunt:FireClient(plr, MANUAL_TAUNT_REWARD)  -- confirmation -> client shows floating popup
		end
	end
end)

Players.PlayerRemoving:Connect(function(plr) lastManualTaunt[plr] = nil end)

-- ===== automatic taunt rotation =====
-- Each ACTIVE hider automatically taunts once per AUTO_CYCLE seconds. One rotation serves everyone:
-- the cycle is split into N equal windows (N = current active hiders) and exactly one hider taunts
-- per window, cycling in order — so taunts are spread out evenly instead of clustering, and each
-- hider reveals their position once per ~AUTO_CYCLE regardless of how many hiders there are.
-- The rotation only plays during the SEEK phase (ROUND) — not the HIDE head-start, when the seekers
-- are still blacked out in the lobby and couldn't hear a taunt anyway (and hiders are still picking
-- spots). Manual taunts keep their wider HIDE+ROUND gate. The rotation self-idles outside ROUND.
-- The hider list is re-collected every window, so hiders who die/convert/leave
-- drop out of the rotation immediately and late joiners are included automatically.
local AUTO_CYCLE = 60  -- seconds: each active hider auto-taunts once per ~60s

-- seek phase only (first MatchTelemetry token is "ROUND")
local function isSeekPhase()
	local v = MatchTelemetry.Value or ""
	return v:sub(1, 5) == "ROUND"
end

task.spawn(function()
	local idx = 0
	while true do
		if not isSeekPhase() then
			idx = 0          -- reset the rotation between rounds
			task.wait(1)
			continue
		end
		-- collect the CURRENT active hiders (converted + alive) fresh each window
		local active = {}
		for _, plr in ipairs(Players:GetPlayers()) do
			if isActiveHider(plr) then table.insert(active, plr) end
		end
		if #active == 0 then
			task.wait(1)
		else
			idx = (idx % #active) + 1
			local plr = active[idx]
			local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
			if root then
				playTauntAt(root.Position, getCustomTauntSoundId(plr))
			end
			task.wait(AUTO_CYCLE / #active)  -- one window; N windows = full 30s cycle
		end
	end
end)

print("[TauntManager] ready (" .. #taunts .. " taunt sounds, manual + auto every " .. AUTO_CYCLE .. "s)")
