local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Constants = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Constants"))
local MatchState = require(script.Parent:WaitForChild("MatchState"))
local MatchRemotes = require(script.Parent:WaitForChild("MatchRemotes"))
local RagdollCorpse = require(ServerScriptService:WaitForChild("RagdollCorpse"))
local KillEffectApplier = require(ServerScriptService:WaitForChild("KillEffectApplier"))
local BackKnife = require(ServerScriptService:WaitForChild("BackKnife"))
local QuestManager = require(ServerScriptService:WaitForChild("QuestManager"))

local KILL_COINS = Constants.Coins.KILL_COINS
local ScreenFade = MatchRemotes.ScreenFade
local KillReward = MatchRemotes.KillReward

local roles = MatchState.roles
local found = MatchState.found
local seekers = MatchState.seekers
local seekerOut = MatchState.seekerOut
local eliminating = MatchState.eliminating
local sizePurchasedThisRound = MatchState.sizePurchasedThisRound
local foundTime = MatchState.foundTime
local foundOrder = MatchState.foundOrder
local kills = MatchState.kills

local function knitSvc(name)
	local ok, s = pcall(function()
		return Knit.GetService(name)
	end)
	return ok and s or nil
end

local function attributedKnifeKiller(deadChar)
	local hum = deadChar and deadChar:FindFirstChildOfClass("Humanoid")
	local tag = hum and hum:FindFirstChild("LastKnifeKiller")
	local killer = tag and tag:IsA("ObjectValue") and tag.Value or nil
	if killer and killer.Parent and roles[killer] == "Seeker" and not seekerOut[killer] then
		return killer
	end
	return nil
end

local Elimination = {}

local deps = {}
function Elimination.init(d)
	deps = d
end

function Elimination.eliminate(player: Player)
	if not player or eliminating[player] then
		return
	end
	if roles[player] ~= "Hider" or found[player] then
		return
	end
	local Placement = deps.placement
	eliminating[player] = true
	found[player] = true

	deps.clearOffer(player)
	sizePurchasedThisRound[player] = nil
	Placement.clearDesiredPlacement(player)
	Placement.setLobbyRespawn(player)
	foundTime[player] = os.clock()
	table.insert(foundOrder, player.Name)
	deps.broadcastHidersLeft()
	deps.broadcastRoleMap()

	local killer = nil
	local eliminatedOk = pcall(function()
		local deadChar = player.Character
		if deadChar then
			killer = attributedKnifeKiller(deadChar) or seekers[1]
			local corpse = RagdollCorpse.spawn(deadChar)
			local keId
			keId = killer and knitSvc("DataService"):GetEquippedKillEffect(killer)
			if corpse and keId then
				pcall(function()
					KillEffectApplier.apply(corpse, keId)
				end)
			end
			if player.Character == deadChar then
				player.Character = nil
			end
			deadChar:Destroy()
			player:LoadCharacter()
		end
	end)
	if not eliminatedOk then
		warn("[MatchManager] eliminateHider: character cleanup failed for " .. player.Name .. "; forcing respawn")
		pcall(function()
			player:LoadCharacter()
		end)
	end
	if killer then
		kills[killer] = (kills[killer] or 0) + 1
		knitSvc("CoinService"):Award(killer, KILL_COINS, "seeker kill")
		KillReward:FireClient(killer, KILL_COINS)
		pcall(QuestManager.notifyKill, killer)
	end

	ScreenFade:FireClient(player, "in", {
		message = "You have been found!",
		fadeTime = 0,
	})

	deps.setInRound(player, false)

	BackKnife.setSuppressed(player, false)
	deps.announceFound(player.Name)

	local respawnConn
	respawnConn = player.CharacterAdded:Connect(function(newChar)
		if respawnConn then
			respawnConn:Disconnect()
			respawnConn = nil
		end
		task.spawn(function()
			Placement.waitUntilPlaceable(player, 5)
			Placement.pivot(player, Placement.getLobbyTarget())
		end)
		BackKnife.setSuppressed(player, false)
		task.wait(0.9)
		ScreenFade:FireClient(player, "out", { fadeTime = 0.4 })
	end)

	task.delay(4.0, function()
		if respawnConn then
			respawnConn:Disconnect()
			respawnConn = nil
		end
		ScreenFade:FireClient(player, "out", { fadeTime = 0.4 })
	end)

	task.delay(4.0, function()
		Placement.waitUntilPlaceable(player, 10)
		deps.offerJoinAsSeeker(player)
	end)

	eliminating[player] = nil
end

return Elimination
