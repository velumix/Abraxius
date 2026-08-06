local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local ModifierCoordinator = require(ServerScriptService.Modules.ModifierCoordinator)
local ModifierUtils = require(ServerScriptService.Modules.ModifierUtils)
local PaintballGunGiver = require(ServerScriptService.Modules.PaintballGunGiver)
local RoundGatedEffect = require(script.Parent.Utilities.RoundGatedEffect)
local SparkModEvents = require(ServerScriptService.SparkMod.Services.Events)
local Knife = require(ServerScriptService:WaitForChild("MatchManager").MatchKnife)
local MapManager = require(ServerScriptService.MapManager)
local BossConfig = require(ReplicatedStorage.Config.BossConfig)

local BOSS_NAME = "PaintBoss"
local MINION_NAME = "PaintMinion"
local EVENT_NAME = "PaintingBoss"
local ACTIVATE_COOLDOWN = 5

local strippedKnifePlayers = {}
local lastActivateTime = 0

local function giveGunsToAllInRound()
	ModifierUtils.forEachPlayerInRound(function(player: Player)
		if Knife.seekerHasKnife(player) then
			strippedKnifePlayers[player] = true
			print(`[PaintingBoss] tracking knife for {player.Name}`)
		end
		PaintballGunGiver.StripSeekerKnife(player)
		PaintballGunGiver.GiveGun(player)
	end)
end

local function grantPaintballSkin()
	local ok, ds = pcall(function()
		return Knit.GetService("DataService")
	end)
	if not ok or not ds then
		warn("[PaintingBoss] DataService not available; cannot grant paintball skin")
		return
	end
	ModifierUtils.forEachPlayerInRound(function(player: Player)
		ds:GrantWeaponOnce(player, "paintball", "none")
	end)
end

local function stripGunsFromAll()
	for _, player in ipairs(Players:GetPlayers()) do
		PaintballGunGiver.StripGuns(player)
	end

	-- Re-equip the seeker knife for anyone who had one when the boss started.
	for player, _ in pairs(strippedKnifePlayers) do
		if player.Parent then
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 and ModifierUtils.inRound(player) then
				print(`[PaintingBoss] restoring knife for {player.Name}`)
				local ok, err = pcall(function()
					Knife.giveKnife(player)
				end)
				if not ok then
					warn(`[PaintingBoss] failed to restore knife for {player.Name}: {err}`)
				end
			else
				print(`[PaintingBoss] skipping knife restore for {player.Name}: dead/left round`)
			end
		end
	end

	table.clear(strippedKnifePlayers)
end

return {
	Duration = 180,

	CanActivate = function()
		if os.clock() - lastActivateTime < ACTIVATE_COOLDOWN then
			return false, "cooldown"
		end
		return true
	end,

	Activate = function(context)
		lastActivateTime = os.clock()

		local bossService = Knit.GetService("BossService")
		local PaintingBossService = Knit.GetService("PaintingBossService")
		local GameModeService = Knit.GetService("GameModeService")
		local bossDiedConnection = nil
		local spawnedMonsters: { [Model]: boolean } = {}
		local started = false
		local spawnFailed = false
		local endedNaturally = false
		local resultNotified = false
		local pausedWhileWaiting = false

		local function pauseEventTimerWhileWaiting()
			if pausedWhileWaiting then
				return
			end
			pausedWhileWaiting = true

			local remaining = context.Remaining or context.Duration
			local localOk, localErr = pcall(function()
				SparkModEvents._Pause(EVENT_NAME, remaining)
			end)
			if not localOk then
				warn(`[PaintingBoss] Failed to pause local event timer while waiting for round: {localErr}`)
			end
			print(`[PaintingBoss] Event timer paused while waiting for a live round; remaining={remaining}`)
		end

		local function resumeEventTimerForBossFight()
			if not pausedWhileWaiting then
				return
			end
			pausedWhileWaiting = false

			local localOk, localErr = pcall(function()
				SparkModEvents._Resume(EVENT_NAME)
			end)
			if not localOk then
				warn(`[PaintingBoss] Failed to resume local event timer for boss fight: {localErr}`)
			end
			print("[PaintingBoss] Event timer resumed for active boss fight")
		end

		local function endEventLocally()
			-- PaintingBoss is a per-server round objective even when the admin event is global.
			-- Do not globally cancel the SparkMod event from one server's local result.
			Knit.GetService("EventService"):endLocal(EVENT_NAME)
		end

		local function checkAllDead()
			if next(spawnedMonsters) == nil then
				print("[PaintingBoss] All monsters defeated; ending event locally")
				endedNaturally = true
				PaintingBossService:SetBossEventVictory()
				endEventLocally()
			end
		end

		local function armPlayerForEvent(player: Player)
			if not ModifierUtils.inRound(player) then
				return
			end
			if Knife.seekerHasKnife(player) then
				strippedKnifePlayers[player] = true
			end
			PaintballGunGiver.StripSeekerKnife(player)
			PaintballGunGiver.GiveGun(player)
		end

		local function startPaintingBoss()
			if started then
				print("[PaintingBoss] Already started; ignoring duplicate start")
				return true
			end

			local activeMode = GameModeService:GetActive()
			if activeMode ~= "hideandseek" then
				pauseEventTimerWhileWaiting()
				print(`[PaintingBoss] Waiting for hideandseek round before spawning boss; activeMode={tostring(activeMode)}`)
				return false
			end
			resumeEventTimerForBossFight()
			ModifierCoordinator.cancelAllExcept(EVENT_NAME)

			print(`[PaintingBoss] Spawning {BOSS_NAME}...`)
			local spawnResult, bossModel = bossService:Spawn(BOSS_NAME)
			print(`[PaintingBoss] Spawn result: {spawnResult}`)
			if typeof(spawnResult) == "string" and not spawnResult:match("^Spawned") then
				warn(`[PaintingBoss] Failed to spawn {BOSS_NAME}: {spawnResult}`)
				spawnFailed = true
				endEventLocally()
				return true
			end
			if not bossModel then
				warn(`[PaintingBoss] Spawn returned success but no boss model for {BOSS_NAME}`)
				spawnFailed = true
				endEventLocally()
				return true
			end
			started = true
			spawnedMonsters[bossModel] = true

			-- Release seekers immediately if the event starts during the hide phase.
			if PaintingBossService:IsHidePhase() then
				print("[PaintingBoss] Releasing seekers early")
				PaintingBossService:ReleaseSeekers()
			end

			print(`[PaintingBoss] Giving paintball guns to all in-round players`)
			giveGunsToAllInRound()

			-- Extend the round so it lasts at least the boss event duration from now.
			local matchManager = ServerScriptService:FindFirstChild("MatchManager")
			local roundStartClock = matchManager and matchManager:GetAttribute("RoundStartClock")
			local elapsed = if roundStartClock then os.clock() - roundStartClock else 0
			bossService:SetRoundTimeOverride(elapsed + context.Duration)

			-- Tell clients the boss event is active so the timer/info can change.
			PaintingBossService:SetEventActive(true, context.Duration, context.Remaining)

			-- Spawn paint minions at player spawn points so they land on valid ground like the boss does.
			local bossDef = BossConfig.Get(BOSS_NAME)
			local minionCount = bossDef and bossDef.minionCount or 0
			local minionSpawnRadius = bossDef and bossDef.minionSpawnRadius or 5
			if minionCount > 0 then
				print(`[PaintingBoss] Spawning {minionCount} minions`)
				for i = 1, minionCount do
					local cf = MapManager.getPlayerSpawnCFrame()
					if not cf then
						warn(`[PaintingBoss] No spawn point available for minion {i}`)
						continue
					end

					-- Scatter around the spawn point so they don't stack.
					local angle = math.random() * math.pi * 2
					local radius = math.random() * minionSpawnRadius
					local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
					local minionPos = cf.Position + offset

					local minionResult, minionModel = bossService:SpawnAt(MINION_NAME, CFrame.new(minionPos))
					print(`[PaintingBoss] Minion {i} spawn result: {minionResult}`)
					if typeof(minionResult) == "string" and not minionResult:match("^Spawned") then
						warn(`[PaintingBoss] Minion {i} failed to spawn: {minionResult}`)
					end
					if minionModel then
						spawnedMonsters[minionModel] = true
					end
				end
			end

			checkAllDead()
			return true
		end

		-- Catch seekers (and any in-round players) who respawn after the event has started.
		context.trove:Add(Players.PlayerAdded:Connect(function(player: Player)
			local function onCharacterAdded(_character: Model)
				if not started then
					return
				end
				-- Give them a moment to fully spawn/place before swapping gear.
				task.delay(0.25, function()
					armPlayerForEvent(player)
				end)
			end
			context.trove:Add(player.CharacterAdded:Connect(onCharacterAdded))
			if player.Character then
				onCharacterAdded(player.Character)
			end
		end))

		for _, player in ipairs(Players:GetPlayers()) do
			context.trove:Add(player.CharacterAdded:Connect(function(_character: Model)
				if not started then
					return
				end
				task.delay(0.25, function()
					armPlayerForEvent(player)
				end)
			end))
		end

		-- End the event early when ALL spawned monsters die.
		bossDiedConnection = bossService.BossDiedSignal:Connect(function(payload: { name: string, model: Model? })
			print(`[PaintingBoss] Monster died: {payload and payload.name}`)
			if payload and payload.model then
				spawnedMonsters[payload.model] = nil
			end
			checkAllDead()
		end)

		RoundGatedEffect.Bind(context, startPaintingBoss, { retryWhileActive = true })

		-- Also try immediately in case the round is already live when the event starts.
		if MapManager.isLoaded() and ModifierUtils.anyInRound() then
			print("[PaintingBoss] Round is already live; spawning immediately")
			startPaintingBoss()
		else
			print("[PaintingBoss] Waiting for live round phase before spawning")
			pauseEventTimerWhileWaiting()
		end

		context.trove:Add(function()
			if bossDiedConnection then
				bossDiedConnection:Disconnect()
				bossDiedConnection = nil
			end
			if spawnFailed then
				warn("[PaintingBoss] Event ended because the boss failed to spawn")
			elseif started and not endedNaturally then
				print("[PaintingBoss] Event ended before all monsters died (timeout/cancel)")
				PaintingBossService:SetBossEventTimeout()
			elseif not started then
				warn("[PaintingBoss] Event ended before boss spawned; likely cancelled before a live round was available")
			end
			bossService:ClearRoundTimeOverride()
			bossService:EndEvent()
			bossService:Clear()
			stripGunsFromAll()
			if endedNaturally then
				grantPaintballSkin()
			end
			if started and not resultNotified then
				resultNotified = true
				PaintingBossService:NotifyResult(endedNaturally)
			end
			PaintingBossService:SetEventActive(false)
		end)
	end,

	Deactivate = function()
		-- Cleanup is handled by the trove above; this hook is kept for compatibility.
	end,
}
