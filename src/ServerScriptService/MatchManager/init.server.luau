local MatchmakingService = game:GetService("MatchmakingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local StudsConverter = require(ServerStorage:WaitForChild("StudsConverter"))

local Constants = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Constants"))
local dsCoin, dsLevel, dsStats, dsInv
do
	local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"))
	local cache: { [string]: any } = {}
	local function svc(n: string): any
		if cache[n] == nil then
			local ok, s = pcall(function()
				return Knit.GetService(n)
			end)
			if not ok then
				warn("[MatchManager] failed to get Knit service '" .. n .. "': " .. tostring(s))
				cache[n] = false
			else
				cache[n] = s or false
			end
		end
		local cached = cache[n]
		return cached ~= false and cached or nil
	end
	function dsCoin()
		return svc("CoinService")
	end
	function dsLevel()
		return svc("LevelService")
	end
	function dsStats()
		return svc("StatsService")
	end
	function dsInv()
		return svc("DataService")
	end
end
local SeekerKnifeTemplate = ServerStorage:FindFirstChild("SeekerKnife")

local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"))
local function knitSvc(name)
	local ok, s = pcall(function()
		return Knit.GetService(name)
	end)
	return ok and s or nil
end
local function knitPlayer(userId)
	return type(userId) == "number" and Players:GetPlayerByUserId(userId) or userId
end

local function isAfk(plr: Player): boolean
	local svc = knitSvc("AfkService")
	return svc and svc:IsAfk(plr) or false
end

local KnitInventoryAdapter = {
	getEquippedSkin = function(userId)
		local plr = knitPlayer(userId)
		if not plr then
			return nil
		end
		local svc = knitSvc("DataService")
		return svc and svc:GetEquippedSkin(plr)
	end,
	getEquippedKillEffect = function(userId)
		local plr = knitPlayer(userId)
		if not plr then
			return nil
		end
		local svc = knitSvc("DataService")
		return svc and svc:GetEquippedKillEffect(plr)
	end,
	add = function(player, skinId, effect)
		local svc = knitSvc("DataService")
		if svc then
			svc:AddWeapon(player, skinId, effect or "none")
		end
	end,
	grantPose = function(player, poseId)
		local svc = knitSvc("DataService")
		if svc then
			svc:GrantPose(player, poseId)
		end
	end,
}

local KnitCoinAdapter = {
	award = function(player, amount, reason)
		local svc = knitSvc("CoinService")
		if svc then
			svc:Award(player, amount, reason)
		end
	end,
	credit = function(player, amount, reason)
		local svc = knitSvc("CoinService")
		if svc then
			svc:Credit(player, amount, reason)
		end
	end,
	creditFromPack = function(player, amount, reason)
		local svc = knitSvc("CoinService")
		return svc and svc:CreditFromPack(player, amount, reason) or false
	end,
	spend = function(player, amount)
		local svc = knitSvc("CoinService")
		return svc and svc:Spend(player, amount) or false
	end,
}

local PolicyManager = require(script.Parent:WaitForChild("PolicyManager"))
PolicyManager.init()
local BackKnife = require(script.Parent:WaitForChild("BackKnife"))
BackKnife.setInventoryManager(KnitInventoryAdapter)
BackKnife.init()
local AfkTag = require(script.Parent:WaitForChild("AfkTag"))
AfkTag.init()
local KillEffectApplier = require(script.Parent:WaitForChild("KillEffectApplier"))
local KnifeSkinManager = require(ReplicatedStorage:WaitForChild("KnifeSkinManager"))
local UnboxManager = require(script.Parent:WaitForChild("UnboxManager"))
local AdminSeekerService = require(script.Parent:WaitForChild("Services"):WaitForChild("AdminSeekerService"))
local BossService = require(script.Parent:WaitForChild("Services"):WaitForChild("BossService"))
local ChaosButtonService = require(script.Parent:WaitForChild("Services"):WaitForChild("ChaosButtonService"))
local CoinSpawner = require(script.Parent:WaitForChild("CoinSpawner"))
local HiddenAdminService = require(script.Parent:WaitForChild("Services"):WaitForChild("HiddenAdminService"))
local MapManager = require(script.Parent:WaitForChild("MapManager"))
local MapCatalog = require(ReplicatedStorage:WaitForChild("MapCatalog"))
local ModifierService = require(script.Parent:WaitForChild("Services"):WaitForChild("ModifierService"))
local PaintBucketEventService = require(script.Parent:WaitForChild("Services"):WaitForChild("PaintBucketEventService"))
local PaintMutationService = require(script.Parent:WaitForChild("Services"):WaitForChild("PaintMutationService"))
local RagdollCorpse = require(script.Parent:WaitForChild("RagdollCorpse"))
local TrollConfig = require(ReplicatedStorage:WaitForChild("TrollConfig"))
local TrollService = require(script.Parent:WaitForChild("TrollService"))
local VIPManager = require(script.Parent:WaitForChild("VIPManager"))
local VotingManager = require(script.Parent:WaitForChild("VotingManager"))
VIPManager.init()
local LimitedStockManager = require(script.Parent:WaitForChild("LimitedStockManager"))
LimitedStockManager.init()
local QuestManager = require(script.Parent:WaitForChild("QuestManager"))
QuestManager.init()
local MatchConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("MatchConfig"))
local CONFIG = MatchConfig.CONFIG

local function getRoundDuration(): number
	local svc = knitSvc("BossService")
	return svc and svc:GetRoundTimeOverride() or CONFIG.ROUND
end

local KILL_COINS = Constants.Coins.KILL_COINS

local PITY = MatchConfig.PITY
local SEEKER_BOOST_ATTR = MatchConfig.SEEKER_BOOST_ATTR

local MatchRemotes = require(script.Parent:WaitForChild("Match"):WaitForChild("MatchRemotes"))
local Remotes = MatchRemotes.folder
local StateChanged = MatchRemotes.StateChanged
local ChooseMapConfirm = MatchRemotes.ChooseMapConfirm
local GlobalMapChoice = MatchRemotes.GlobalMapChoice
local MapQueueUpdate = MatchRemotes.MapQueueUpdate
MapManager.setForcedQueueChanged(function(snapshot)
	MapQueueUpdate:FireAllClients(snapshot)
end)
MapQueueUpdate.OnServerEvent:Connect(function(plr)
	MapQueueUpdate:FireClient(plr, MapManager.getForcedQueue())
end)
Players.PlayerAdded:Connect(function(plr)
	MapQueueUpdate:FireClient(plr, MapManager.getForcedQueue())
end)
local RoleAnnounce = MatchRemotes.RoleAnnounce
local InRound = MatchRemotes.InRound

local function setInRound(player: Player, inRound: boolean)
	InRound:FireClient(player, inRound)
	player:SetAttribute("InMatch", inRound)
end
local RoundResult = MatchRemotes.RoundResult
local RoundSummary = MatchRemotes.RoundSummary
local WinSequence = MatchRemotes.WinSequence
local SeekerChance = MatchRemotes.SeekerChance
local RoleMap = MatchRemotes.RoleMap

local RequestRoleMap = MatchRemotes.RequestRoleMap
local HidersLeft = MatchRemotes.HidersLeft
local SeekerQueueUpdate = MatchRemotes.SeekerQueueUpdate
local Blackout = MatchRemotes.Blackout
local ScreenFade = MatchRemotes.ScreenFade
local LockBackpack = MatchRemotes.LockBackpack

local OfferJoinAsSeeker = MatchRemotes.OfferJoinAsSeeker
local JoinAsSeekerResponse = MatchRemotes.JoinAsSeekerResponse
local RequestJoinOffer = MatchRemotes.RequestJoinOffer

local RevealHiders = MatchRemotes.RevealHiders
local TrollNotify = MatchRemotes.TrollNotify
local TrollBroadcast = MatchRemotes.TrollBroadcast

local ReviveEligibility = MatchRemotes.ReviveEligibility

local ReviveTestRequest = MatchRemotes.ReviveTestRequest
local KillReward = MatchRemotes.KillReward

local CoinPurchase = MatchRemotes.CoinPurchase
CoinPurchase.OnServerEvent:Connect(function(player, crateName)
	if type(crateName) ~= "string" then
		return
	end
	local price = KnifeSkinManager.crateCoinPrice(crateName)
	if not price then
		CoinPurchase:FireClient(player, crateName, false, "unknown")
		return
	end
	if dsCoin():Spend(player, price) then
		UnboxManager.openCrate(player, crateName)
		CoinPurchase:FireClient(player, crateName, true, "ok")
	else
		CoinPurchase:FireClient(player, crateName, false, "insufficient")
	end
end)
local Telemetry = MatchRemotes.Telemetry

type Role = "Hider" | "Seeker"
type StateName = "INTERMISSION" | "HIDE" | "ROUND" | "REVEALING_HIDERS" | "RESOLVE"

local State: { [string]: StateName } = { INTERMISSION = "INTERMISSION", HIDE = "HIDE", ROUND = "ROUND", REVEALING_HIDERS = "REVEALING_HIDERS", RESOLVE = "RESOLVE" }
local current: StateName = State.INTERMISSION

local MatchmakingPublisher = require(script.Parent:WaitForChild("Match"):WaitForChild("MatchmakingPublisher"))
local publishMatchmakingState = MatchmakingPublisher.publish
MatchmakingPublisher.initStudio()
local Reveal = require(script.Parent:WaitForChild("Match"):WaitForChild("Reveal"))
local MatchState = require(script.Parent:WaitForChild("Match"):WaitForChild("MatchState"))
local RoundRewards = require(script.Parent:WaitForChild("Match"):WaitForChild("RoundRewards"))
local SeekerKnifeMaintenance = require(script.Parent:WaitForChild("Match"):WaitForChild("SeekerKnifeMaintenance"))
local RevealHighlights = require(script.Parent:WaitForChild("Match"):WaitForChild("RevealHighlights"))
local HidePhase = require(script.Parent:WaitForChild("Match"):WaitForChild("HidePhase"))

local soloRole = nil

local skipPhase = false
local endRound = false
local paused = false

local roles = MatchState.roles
local found = MatchState.found
local foundTime = MatchState.foundTime
local hiders = MatchState.hiders
local seekers = MatchState.seekers
-- AFK state is now owned by AfkService; use isAfk() helper below.
local kills = MatchState.kills
local foundOrder = MatchState.foundOrder
local roundStartTime: number = 0
local sentToLobbyEarly: { [Player]: boolean } = {}
local seekerQueue: { number } = {}
local pity = MatchState.pity
local lastSeekers = MatchState.lastSeekers
local joinedAsSeeker = MatchState.joinedAsSeeker

local offeredJoin: { [Player]: boolean } = {}
local reviveCount = MatchState.reviveCount

local sizePurchasedThisRound = MatchState.sizePurchasedThisRound

local SIZE_SCALES = MatchConfig.SIZE_SCALES

local function applyCharacterScale(player, scale)
	if not player then
		return
	end
	local char = player.Character
	if not char then
		return
	end
	local okScale = pcall(function()
		char:ScaleTo(scale)
	end)
	if not okScale then
		warn("[MatchManager] ScaleTo failed for " .. player.Name)
		return
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum and roles[player] == "Hider" and not found[player] then
		hum.WalkSpeed = CONFIG.HIDER_SPEED
	end
end

local function resetCharacterScale(player)
	if not player then
		return
	end
	sizePurchasedThisRound[player] = nil
	applyCharacterScale(player, 1)
end
local hiderPlacedAt = MatchState.hiderPlacedAt

local ownsSeekerGamepass = MatchState.ownsSeekerGamepass
local SeekerChances = require(script.Parent:WaitForChild("Match"):WaitForChild("SeekerChances"))
SeekerChances.setIsAfk(isAfk)
local refreshSeekerBoost = SeekerChances.refreshBoost
local seekerWeight = SeekerChances.weight
local broadcastSeekerChances = SeekerChances.broadcast
local function removeFromRoundRoster(_plr: Player) end
local function offerClassicJoinAfterAfk(_plr: Player) end

-- MatchManager only calls into AfkService; it never owns AFK infrastructure.
task.defer(function()
	local svc
	for _ = 1, 60 do
		svc = knitSvc("AfkService")
		if svc then
			break
		end
		task.wait(0.1)
	end
	if svc then
		svc:OnToggle(function(plr, afkEnabled)
			if afkEnabled then
				removeFromRoundRoster(plr)
			else
				offerClassicJoinAfterAfk(plr)
			end
			broadcastSeekerChances()
		end)
	else
		warn("[MatchManager] AfkService not available; seeker chances won't react to AFK toggles")
	end
end)

local function broadcastQueue()
	local count = #seekerQueue
	local nextUserId, nextName = nil, nil
	if count > 0 then
		nextUserId = seekerQueue[1]
		local plr = Players:GetPlayerByUserId(nextUserId)
		if plr then
			nextName = plr.DisplayName
		else
			local ok, name = pcall(function()
				return Players:GetNameFromUserIdAsync(nextUserId)
			end)
			if ok then
				nextName = name
			end
		end
	end
	SeekerQueueUpdate:FireAllClients({ count = count, nextUserId = nextUserId, nextName = nextName })
end

local Placement = require(script:WaitForChild("MatchPlacement"))

local Knife = require(script:WaitForChild("MatchKnife"))

local function setFrozen(player, frozen)
	local char = player.Character
	if not char then
		return
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		local sp = game:GetService("StarterPlayer")
		local defWalk = sp.CharacterWalkSpeed
		local defJumpPower = sp.CharacterJumpPower
		local defJumpHeight = sp.CharacterJumpHeight
		hum.WalkSpeed = frozen and 0 or defWalk
		hum.JumpPower = frozen and 0 or defJumpPower
		hum.JumpHeight = frozen and 0 or defJumpHeight
	end
end

local diedConns = MatchState.diedConns
local seekerGone = false
local seekerOut = MatchState.seekerOut
local roundHadHiders = false

local function clearDiedConns()
	for _, c in ipairs(diedConns) do
		if c then
			c:Disconnect()
		end
	end
	table.clear(diedConns)
end

local seekerCountActive = MatchState.seekerCountActive

local function markSeekerOut(player)
	if roles[player] ~= "Seeker" then
		return
	end
	seekerOut[player] = true
	if seekerCountActive() == 0 then
		warn(
			string.format(
				"[SEEKERGONE-DIAG] markSeekerOut set seekerGone=true | phase=%s | player=%s | #seekers=%d\n%s",
				tostring(current),
				tostring(player and player.Name),
				#seekers,
				debug.traceback()
			)
		)
		seekerGone = true
		MatchState.seekerGone = seekerGone
	end
end

local SpectateEvent = MatchRemotes.Spectate

local eliminating = MatchState.eliminating
local placing = MatchState.placing
local announceFound
local offerJoinAsSeeker

local function clearRoundScreens(plr: Player?)
	if not plr or not plr.Parent then
		return
	end

	Blackout:FireClient(plr, false)
	ScreenFade:FireClient(plr, "out", { fadeTime = 0.25 })
	SpectateEvent:FireClient(plr, false)
	OfferJoinAsSeeker:FireClient(plr, false)
end

local hiderStillParticipating = MatchState.hiderStillParticipating

local aliveHiderCount = MatchState.aliveHiderCount

local function broadcastHidersLeft()
	HidersLeft:FireAllClients(aliveHiderCount())
end

local REVEAL_SECONDS = MatchConfig.REVEAL_SECONDS

local aliveHidersList = MatchState.aliveHidersList

local function doReveal(buyer, mode)
	return Reveal.forSeeker(buyer, mode, aliveHidersList(), RevealHiders, REVEAL_SECONDS)
end

local function broadcastRoleMap(targetPlayer)
	local roleMap = {}
	for plr, r in pairs(roles) do
		if not found[plr] then
			roleMap[plr.UserId] = r
		end
	end
	if targetPlayer then
		RoleMap:FireClient(targetPlayer, roleMap)
	else
		RoleMap:FireAllClients(roleMap)
	end
end

RequestRoleMap.OnServerEvent:Connect(function(plr)
	broadcastRoleMap(plr)
end)

local function attributedKnifeKiller(deadChar)
	local hum = deadChar and deadChar:FindFirstChildOfClass("Humanoid")
	local tag = hum and hum:FindFirstChild("LastKnifeKiller")
	local killer = tag and tag:IsA("ObjectValue") and tag.Value or nil
	if killer and killer.Parent and roles[killer] == "Seeker" and not seekerOut[killer] then
		return killer
	end
	return nil
end

local Elimination = require(script.Parent:WaitForChild("Match"):WaitForChild("Elimination"))
Elimination.init({
	placement = Placement,
	clearOffer = function(p) offeredJoin[p] = nil end,
	broadcastHidersLeft = broadcastHidersLeft,
	broadcastRoleMap = broadcastRoleMap,
	setInRound = setInRound,
	announceFound = function(name) if announceFound then announceFound(name) end end,
	offerJoinAsSeeker = function(p) if offerJoinAsSeeker then offerJoinAsSeeker(p) end end,
})
local eliminateHider = Elimination.eliminate

local SeekerConversion = require(script.Parent:WaitForChild("Match"):WaitForChild("SeekerConversion"))
SeekerConversion.init({
	placement = Placement,
	knife = Knife,
	isAfk = isAfk,
	setInRound = setInRound,
	setFrozen = setFrozen,
	markSeekerOut = markSeekerOut,
	broadcastRoleMap = broadcastRoleMap,
	broadcastHidersLeft = broadcastHidersLeft,
	setSeekerGone = function(v) seekerGone = v; MatchState.seekerGone = v end,
	isOffered = function(p) return offeredJoin[p] end,
	markOffered = function(p) offeredJoin[p] = true end,
})
local convertToSeeker = SeekerConversion.convert

local ReviveRules = require(script.Parent:WaitForChild("Match"):WaitForChild("ReviveRules"))
local nextReviveTier = ReviveRules.nextReviveTier
local roundTimeLeft = ReviveRules.roundTimeLeft
local canRevive = ReviveRules.canRevive
local sendReviveEligibility = ReviveRules.sendReviveEligibility

local Revive = require(script.Parent:WaitForChild("Match"):WaitForChild("Revive"))
Revive.init({
	placement = Placement,
	setInRound = setInRound,
	broadcastHidersLeft = broadcastHidersLeft,
	broadcastRoleMap = broadcastRoleMap,
})
local revivePlayer = Revive.revive

offerJoinAsSeeker = SeekerConversion.offerJoin
offerClassicJoinAfterAfk = function(plr: Player)
	if current ~= State.ROUND or roles[plr] ~= nil then
		return
	end
	local gameModeService = knitSvc("GameModeService")
	if not gameModeService or gameModeService:GetActive() ~= "hideandseek" then
		return
	end
	local eventService = knitSvc("EventService")
	if eventService and eventService:isEventActive("PaintingBoss") then
		return
	end
	task.defer(offerJoinAsSeeker, plr)
end

JoinAsSeekerResponse.OnServerEvent:Connect(function(player, accepted)
	if accepted ~= true then
		return
	end
	if not offeredJoin[player] then
		return
	end
	convertToSeeker(player)
end)

RequestJoinOffer.OnServerEvent:Connect(function(player)
	if not player or not player.Parent then
		return
	end
	if not offeredJoin[player] then
		return
	end
	if current ~= State.ROUND then
		return
	end
	if seekerGone then
		return
	end
	if roles[player] == "Seeker" then
		return
	end
	if isAfk(player) then
		return
	end
	if aliveHiderCount() <= 0 then
		return
	end
	OfferJoinAsSeeker:FireClient(player)
	sendReviveEligibility(player)
end)

ReviveEligibility.OnServerEvent:Connect(function(player)
	sendReviveEligibility(player)
end)

local REVIVE_FREE_TESTING = false
ReviveTestRequest.OnServerEvent:Connect(function(player)
	if not REVIVE_FREE_TESTING then
		return
	end
	if not canRevive(player) then
		warn("[Revive][TEST] free revive ignored -- not currently eligible for " .. player.Name)
		return
	end
	print("[Revive][TEST] granting FREE revive to " .. player.Name)
	pcall(revivePlayer, player)
end)

local function broadcast(note: string?, timeLeft: number?)
	publishMatchmakingState(current, timeLeft)

	local roundTimeLeft = timeLeft
	if current == State.HIDE and timeLeft ~= nil then
		roundTimeLeft = timeLeft + CONFIG.ROUND
	end
	StateChanged:FireAllClients({ state = current, timeLeft = timeLeft, roundTimeLeft = roundTimeLeft, note = note })
	Telemetry.Value = string.format("%s | hiders=%d seekers=%d | %s", current, #hiders, #seekers, note or "")
	print("[MatchManager] " .. Telemetry.Value)
end

announceFound = function(name)
	broadcast(name .. " was found!")
end

local function countPlayers()
	return #Players:GetPlayers()
end

local function hasPlaceableCharacter(plr)
	local char = plr and plr.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return root ~= nil and hum ~= nil and hum.Health > 0
end

local function countActive()
	local n = 0
	for _, plr in ipairs(Players:GetPlayers()) do
		if not isAfk(plr) and hasPlaceableCharacter(plr) then
			n += 1
		end
	end
	return n
end

local RoleAssignment = require(script.Parent:WaitForChild("Match"):WaitForChild("RoleAssignment"))
RoleAssignment.init({
	isAfk = isAfk,
	hasPlaceableCharacter = hasPlaceableCharacter,
	placement = Placement,
	clearRoundScreens = clearRoundScreens,
	setInRound = setInRound,
	applyCharacterScale = applyCharacterScale,
	getSoloRole = function() return soloRole end,
	setRoundHadHiders = function(v) roundHadHiders = v end,
	resetSentToLobby = function() sentToLobbyEarly = {} end,
	resetOffered = function() offeredJoin = {} end,
	seekerQueue = seekerQueue,
})

local function minPlayers()
	return soloRole and 1 or CONFIG.MIN_PLAYERS
end

local function sendStateToPlayer(plr: Player)
	-- When an ALTERNATE mode (e.g. Reverse Race) is running a round, MatchManager isn't the driver and
	-- `current` is stale. Detect that via MatchState.current (which every mode keeps live): if a round is
	-- ongoing and this player isn't in it, answer the sync with the lobby "Round active" banner rather
	-- than a stale intermission. Participants are left to their own mode's HUD (and the client also drops
	-- non-rr syncs while an RR phase is on screen), so this only affects lobby spectators.
	local phase = MatchState.current
	local matchManagerDriving = (phase == current)  -- true for HideAndSeek; false when RR owns the phase
	local roundActive = phase ~= nil and phase ~= State.INTERMISSION and phase ~= State.RESOLVE
	if roundActive and not matchManagerDriving and not plr:GetAttribute("InMatch") then
		StateChanged:FireClient(plr, { spectateActive = true })
		return
	end

	local active = countActive()
	local needed = minPlayers()
	StateChanged:FireClient(plr, {
		state = current,
		waiting = current == State.INTERMISSION and active < needed,
		activePlayers = active,
		neededPlayers = needed,
	})
end

StateChanged.OnServerEvent:Connect(function(plr, action)
	if action == "sync" then
		sendStateToPlayer(plr)
	end
end)

local assignRoles = RoleAssignment.assign

local allHidersFound = MatchState.allHidersFound

local function runTimer(duration, shouldEnd, roundExtraOrFn, getDuration)
	local startClock = os.clock()
	while true do
		if paused then
			task.wait(0.2)
		else
			if skipPhase then
				skipPhase = false
				return "interrupted"
			end
			if endRound then
				return "interrupted"
			end
			if shouldEnd and shouldEnd() then
				return "interrupted"
			end
			task.wait(1)
			local total = if getDuration then getDuration() else duration
			local left = math.max(0, math.ceil(total - (os.clock() - startClock)))
			local extra = if typeof(roundExtraOrFn) == "function" then roundExtraOrFn() else (roundExtraOrFn or 0)
			publishMatchmakingState(current, left)
			StateChanged:FireAllClients({ state = current, timeLeft = left, roundTimeLeft = left + extra })
			if left <= 0 then
				break
			end
		end
	end
	return "timeout"
end

local RoleApi = script:FindFirstChild("GetRole")
if not RoleApi then
	RoleApi = Instance.new("BindableFunction")
	RoleApi.Name = "GetRole"
	RoleApi.Parent = script
end
RoleApi.OnInvoke = function(player)
	return roles[player]
end

local GetPhaseApi = script:FindFirstChild("GetPhase")
if not GetPhaseApi then
	GetPhaseApi = Instance.new("BindableFunction")
	GetPhaseApi.Name = "GetPhase"
	GetPhaseApi.Parent = script
end
GetPhaseApi.OnInvoke = function()
	-- Return the shared MatchState phase (HideAndSeek keeps it in sync with `current`; other
	-- game modes like Reverse Race set it directly) so knife/phase checks work across modes.
	return MatchState.current
end

local IsActiveHiderApi = script:FindFirstChild("IsActiveHider")
if not IsActiveHiderApi then
	IsActiveHiderApi = Instance.new("BindableFunction")
	IsActiveHiderApi.Name = "IsActiveHider"
	IsActiveHiderApi.Parent = script
end
IsActiveHiderApi.OnInvoke = function(player)
	return roles[player] == "Hider" and not found[player]
end

local GetActiveSeekersApi = script:FindFirstChild("GetActiveSeekers")
if not GetActiveSeekersApi then
	GetActiveSeekersApi = Instance.new("BindableFunction")
	GetActiveSeekersApi.Name = "GetActiveSeekers"
	GetActiveSeekersApi.Parent = script
end
GetActiveSeekersApi.OnInvoke = function()
	local out = {}
	for _, s in ipairs(seekers) do
		if s and s.Parent and roles[s] == "Seeker" and not seekerOut[s] then
			table.insert(out, s)
		end
	end
	return out
end

local RevealHidersInRadiusApi = script:FindFirstChild("RevealHidersInRadius")
if not RevealHidersInRadiusApi then
	RevealHidersInRadiusApi = Instance.new("BindableFunction")
	RevealHidersInRadiusApi.Name = "RevealHidersInRadius"
	RevealHidersInRadiusApi.Parent = script
end
RevealHidersInRadiusApi.OnInvoke = function(origin: Vector3, radius: number, duration: number?)
	duration = duration or REVEAL_SECONDS
	radius = radius or 10

	local activeSeekers = {}
	for _, s in ipairs(seekers) do
		if s and s.Parent and roles[s] == "Seeker" and not seekerOut[s] then
			table.insert(activeSeekers, s)
		end
	end

	return Reveal.inRadius(origin, radius, aliveHidersList(), activeSeekers, RevealHiders, duration)
end

TrollService.bind(script)

local IsKnifeTargetApi = script:FindFirstChild("IsKnifeTarget")
if not IsKnifeTargetApi then
	IsKnifeTargetApi = Instance.new("BindableFunction")
	IsKnifeTargetApi.Name = "IsKnifeTarget"
	IsKnifeTargetApi.Parent = script
end
IsKnifeTargetApi.OnInvoke = function(player)
	if current == State.REVEALING_HIDERS then
		return false
	end
	return roles[player] == "Hider" and not found[player]
end

local IsKnifeAttackerApi = script:FindFirstChild("IsKnifeAttacker")
if not IsKnifeAttackerApi then
	IsKnifeAttackerApi = Instance.new("BindableFunction")
	IsKnifeAttackerApi.Name = "IsKnifeAttacker"
	IsKnifeAttackerApi.Parent = script
end
IsKnifeAttackerApi.OnInvoke = function(player)
	return roles[player] == "Seeker" and not seekerOut[player]
end

local MarkFound = script:FindFirstChild("MarkFound")
if not MarkFound then
	MarkFound = Instance.new("BindableFunction")
	MarkFound.Name = "MarkFound"
	MarkFound.Parent = script
end
MarkFound.OnInvoke = function(player)
	if roles[player] == "Hider" then
		found[player] = true
		broadcastHidersLeft()
		return true
	end
	return false
end

local SetSolo = script:FindFirstChild("SetSolo")
if not SetSolo then
	SetSolo = Instance.new("BindableFunction")
	SetSolo.Name = "SetSolo"
	SetSolo.Parent = script
end
SetSolo.OnInvoke = function(role)
	if role == "Seeker" or role == "Hider" then
		soloRole = role
	else
		soloRole = nil
	end
	return soloRole
end

local SkipPhaseApi = script:FindFirstChild("SkipPhase")
if not SkipPhaseApi then
	SkipPhaseApi = Instance.new("BindableFunction")
	SkipPhaseApi.Name = "SkipPhase"
	SkipPhaseApi.Parent = script
end
SkipPhaseApi.OnInvoke = function()
	skipPhase = true
	-- Also signal MatchState-driven modes (e.g. Reverse Race) that don't run this module's runTimer
	-- loop; their phase waits consume MatchState.skipPhase to end the current phase.
	MatchState.skipPhase = true
	return MatchState.current or current
end

local EndRoundApi = script:FindFirstChild("EndRound")
if not EndRoundApi then
	EndRoundApi = Instance.new("BindableFunction")
	EndRoundApi.Name = "EndRound"
	EndRoundApi.Parent = script
end
EndRoundApi.OnInvoke = function()
	endRound = true
	return current
end

local PauseRoundApi = script:FindFirstChild("PauseRound")
if not PauseRoundApi then
	PauseRoundApi = Instance.new("BindableFunction")
	PauseRoundApi.Name = "PauseRound"
	PauseRoundApi.Parent = script
end
PauseRoundApi.OnInvoke = function()
	paused = not paused
	return paused, current
end

local RoundBanner = require(script.Parent:WaitForChild("Match"):WaitForChild("RoundBanner"))
RoundBanner.init({
	placement = Placement,
	knife = Knife,
	clearRoundScreens = clearRoundScreens,
	markSentToLobby = function(plr) sentToLobbyEarly[plr] = true end,
})

local function runRound(): ()
	current = State.INTERMISSION
	MatchState.current = current
	local wasInRound = {}
	local wasFound = {}
	for plr, role in pairs(roles) do
		if role then
			wasInRound[plr] = true
		end
	end
	for plr in pairs(found) do
		wasFound[plr] = true
	end
	table.clear(roles)
	table.clear(hiders)
	table.clear(seekers)
	for _, plr in ipairs(Players:GetPlayers()) do
		Placement.safeRestore(plr)
		Knife.clearKnife(plr)
		setFrozen(plr, false)
		Placement.setLobbyRespawn(plr)
		clearRoundScreens(plr)
		if wasInRound[plr] and not wasFound[plr] and not sentToLobbyEarly[plr] then
			Placement.pivot(plr, Placement.getLobbyTarget())
		end
		setInRound(plr, false)
	end
	RoleMap:FireAllClients({})
	HidersLeft:FireAllClients(0)
	for _, plr in ipairs(Players:GetPlayers()) do
		BackKnife.setSuppressed(plr, false)
	end

	skipPhase = false
	endRound = false
	broadcast("waiting in lobby")
	publishMatchmakingState("WAITING", nil, true)
	broadcastSeekerChances()
	-- Studio solo auto-start is gated on the round being explicitly ForcePlay'd, so simply
	-- pressing Play in Studio no longer drops a lone dev straight into a match -- rounds only
	-- start on their own with a natural roster (or via ForcePlay for solo testing).
	local forcedActive = false
	pcall(function()
		local gm = require(game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("GameModeService"))
		forcedActive = gm.forcedActive == true
	end)
	if RunService:IsStudio() and forcedActive and not soloRole and #Players:GetPlayers() == 1 then
		soloRole = "Hider"
		print("[MatchManager] Studio solo (ForcePlay) detected; auto-enabling solo Hider mode")
	end
	while countActive() < minPlayers() do
		local active = countActive()
		Telemetry.Value = "INTERMISSION | waiting for players (" .. active .. "/" .. CONFIG.MIN_PLAYERS .. " active)"
		publishMatchmakingState("WAITING", nil)
		StateChanged:FireAllClients({
			state = State.INTERMISSION,
			waiting = true,
			activePlayers = active,
			neededPlayers = CONFIG.MIN_PLAYERS,
		})
		task.wait(1)
	end

	if MapManager.isLoaded() then
		MapManager.unloadMap()
	end
	local voting = VotingManager.canVote()

	publishMatchmakingState(State.INTERMISSION, CONFIG.INTERMISSION, true)
	runTimer(CONFIG.INTERMISSION)
	if countActive() < minPlayers() then
		return
	end

	local chosenMap = nil
	local usingForced = false
	local forced, isCustom = MapManager.peekForcedMap()
	if forced then
		chosenMap = forced
		usingForced = true
	end
	if not chosenMap and voting and VotingManager.isOpen() then
		chosenMap = VotingManager.resolveVote()
	end
	if not chosenMap then
		chosenMap = MapManager.chooseRandomMap()
	end

	local loaded = MapManager.loadMap(chosenMap, isCustom)
	do
		local cb = knitSvc("ColoringBookService")
		if cb then
			pcall(function()
				cb:ProcessAllDeferredResets()
			end)
			pcall(function()
				cb:SetActive(false)
			end)
		end
	end

	if usingForced and forced and MapManager.getActiveMapName() == forced.Name then
		MapManager.consumeForcedMap()
	end
	if CONFIG.MAP_BUFFER and CONFIG.MAP_BUFFER > 0 then
		broadcast("loading map", CONFIG.MAP_BUFFER)
		runTimer(CONFIG.MAP_BUFFER)
		if countActive() < minPlayers() then
			return
		end
	end

	assignRoles()
	clearDiedConns()
	seekerGone = false
	MatchState.seekerGone = seekerGone
	for _, plr in ipairs(Players:GetPlayers()) do
		if roles[plr] ~= nil then
			BackKnife.setSuppressed(plr, true)
		end
	end
	broadcastQueue()

	current = State.HIDE
	MatchState.current = current
	publishMatchmakingState(State.HIDE, CONFIG.HIDE, true)
	script:SetAttribute("BossEventVictory", false)
	script:SetAttribute("BossEventTimeout", false)
	CoinSpawner.start()

	do
		local cb = knitSvc("ColoringBookService")
		if cb then
			pcall(function()
				cb:SetActive(true)
			end)
		end
	end

	HidePhase.placeHiders(hiders, {
		placement = Placement,
		roleAnnounce = RoleAnnounce,
		screenFade = ScreenFade,
		mapTarget = Placement.mapTarget,
		walkspeed = CONFIG.HIDER_SPEED,
		gracePeriod = 2,
		isActivePhase = function()
			return current == State.HIDE or current == State.ROUND
		end,
		onDeath = eliminateHider,
	})

	for _, s in ipairs(seekers) do
		setFrozen(s, true)
		Blackout:FireClient(s, true, CONFIG.HIDE)
		RoleAnnounce:FireClient(s, "Seeker")
		local schar = s.Character
		local shum = schar and schar:FindFirstChildOfClass("Humanoid")
		if shum then
			table.insert(
				diedConns,
				shum.Died:Connect(function()
					if current == State.ROUND then
						markSeekerOut(s)
					end
				end)
			)
		end

		table.insert(
			diedConns,
			s.CharacterAdded:Connect(function()
				if current == State.ROUND then
					markSeekerOut(s)

					task.defer(function()
						Knife.clearKnife(s)
					end)
				end
			end)
		)
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		setInRound(plr, roles[plr] ~= nil)
	end

	for _, plr in ipairs(Players:GetPlayers()) do
		if roles[plr] ~= nil then
			pcall(QuestManager.notifyRoundPlayed, plr, roles[plr])
		end
	end

	broadcastRoleMap()
	broadcastHidersLeft()

	local hidePhaseStartedAt = os.clock()
	broadcast("role reveal", CONFIG.HIDE)

	task.wait(0.35)
	for _, h in ipairs(hiders) do
		ScreenFade:FireClient(h, "out", { fadeTime = 0.3 })
	end

	task.wait(CONFIG.REVEAL)

	local function roundShouldEnd()
		if soloRole then
			return false
		end
		if seekerGone then
			return true
		end
		if script:GetAttribute("BossEventVictory") == true then
			return true
		end
		if script:GetAttribute("BossEventTimeout") == true then
			return true
		end
		-- Keep the round alive while the Painting Boss event is running.
		local paintingBossService = knitSvc("PaintingBossService")
		if paintingBossService and paintingBossService:IsEventActive() then
			return false
		end
		if allHidersFound() then
			return true
		end
		if roundHadHiders and aliveHiderCount() == 0 then
			return true
		end
		return false
	end

	local StuckHiderSweep = require(script.Parent:WaitForChild("Match"):WaitForChild("StuckHiderSweep"))
	StuckHiderSweep.init({ placement = Placement })

	StuckHiderSweep.startPeriodic()

	local hideRemaining = math.max(0, math.ceil(CONFIG.HIDE - (os.clock() - hidePhaseStartedAt)))
	broadcast("hiders hiding", hideRemaining)
	runTimer(hideRemaining, roundShouldEnd, getRoundDuration)

	if not seekerGone then
		StuckHiderSweep.sweep("hide-end")
	end

	if ((not seekerGone) or soloRole) and not endRound then
		current = State.ROUND
		MatchState.current = current
		publishMatchmakingState(State.ROUND, getRoundDuration(), true)
		roundStartTime = os.clock()
		MatchState.roundStartTime = roundStartTime
		if #hiders > 0 then
			roundHadHiders = true
		end
		broadcastHidersLeft()
		for i, s in ipairs(seekers) do
			local seekerPlr, seekerTarget = s, Placement.mapTarget(i + #hiders)
			Blackout:FireClient(seekerPlr, false)
			setFrozen(seekerPlr, false)
			Placement.setDesiredPlacement(seekerPlr, seekerTarget, {
				valid = function(p)
					return current == State.ROUND and roles[p] == "Seeker" and not seekerOut[p]
				end,
				onPlaced = function(p)
					local c = p.Character
					local hum = c and c:FindFirstChildOfClass("Humanoid")
					if hum then
						hum.WalkSpeed = CONFIG.SEEKER_SPEED
					end
					Knife.giveKnife(p)
				end,
			})
		end

		SeekerKnifeMaintenance.start(Knife)

		broadcast("seekers released", getRoundDuration())

		if VotingManager.canVote() then
			VotingManager.openNextVote()
		end

		task.spawn(function()
			task.wait(0.5)
			for _, plr in ipairs(Players:GetPlayers()) do
				local isAliveHider = (roles[plr] == "Hider" and not found[plr])
				if not isAliveHider then
					local target = plr
					task.spawn(function()
						Placement.waitUntilPlaceable(target, 10)
						offerJoinAsSeeker(target)
					end)
				end
			end
		end)

		script:SetAttribute("RoundStartClock", os.clock())
		runTimer(CONFIG.ROUND, roundShouldEnd, 0, getRoundDuration)

		-- Make sure any Painting Boss event is cleaned up when the round ends so its
		-- timer override and UI don't leak into the next round.
		do
			local bossService = knitSvc("BossService")
			if bossService then
				pcall(function()
					bossService:ClearRoundTimeOverride()
					bossService:Clear()
				end)
			end
			local eventService = knitSvc("EventService")
			if eventService then
				pcall(function()
					eventService:endLocal("PaintingBoss")
				end)
			end
		end
	end
	endRound = false

	-- Decide the winner before entering RESOLVE so we can optionally showcase surviving hiders.
	local bossEventVictory = script:GetAttribute("BossEventVictory") == true
	local bossEventTimeout = script:GetAttribute("BossEventTimeout") == true
	local bossEventFinished = bossEventVictory or bossEventTimeout
	local bossEventResultText = if bossEventVictory then "YOU WON - PAINTBALL KNIFE SKIN" else "YOU LOST - TRY AGAIN NEXT TIME"
	local noHidersLeft = allHidersFound() or (roundHadHiders and aliveHiderCount() == 0)
	local seekersWin = (not bossEventFinished) and noHidersLeft and not seekerGone
	local resultText = if bossEventFinished then bossEventResultText else (seekersWin and "Seekers Win!" or "Hiders Win!")
	local revealHls = {}

	print(`[MatchManager] round ended: result={resultText}, seekersWin={seekersWin}, aliveHiders={aliveHiderCount()}`)

	if not bossEventFinished and not seekersWin then
		-- ===== REVEALING HIDERS (hiders won) =====
		print("[MatchManager] entering REVEALING_HIDERS phase")
		current = State.REVEALING_HIDERS
		MatchState.current = current
		publishMatchmakingState(State.REVEALING_HIDERS, CONFIG.REVEALING_HIDERS, true)

		local revealHiderSet = {}
		for _, h in ipairs(aliveHidersList()) do
			revealHiderSet[h] = true
		end
		for _, plr in ipairs(Players:GetPlayers()) do
			setInRound(plr, false)
			clearRoundScreens(plr)
			Knife.clearKnife(plr)
			if not revealHiderSet[plr] then
				Placement.clearDesiredPlacement(plr)
				BackKnife.setSuppressed(plr, false)
				Placement.safeRestore(plr)
				setFrozen(plr, false)
			end
			SpectateEvent:FireClient(plr, false)
		end
		clearDiedConns()
		CoinSpawner.stop()
		offeredJoin = {}
		RoleMap:FireAllClients({}) -- clear client-side seeker highlights so they don't linger

		local hidersToReveal = aliveHidersList()
		print(`[MatchManager] revealing { #hidersToReveal } hider(s)`)
		revealHls = RevealHighlights.show(hidersToReveal)

		broadcast("hiders revealed", CONFIG.REVEALING_HIDERS)
		print(`[MatchManager] REVEALING_HIDERS timer started for {CONFIG.REVEALING_HIDERS}s`)
		runTimer(CONFIG.REVEALING_HIDERS)
		print("[MatchManager] REVEALING_HIDERS timer finished")

		RevealHighlights.clear(revealHls)

		print(`[MatchManager] REVEALING_HIDERS cleanup complete: removed {#revealHls} highlights`)
	end

	-- ===== RESOLVE =====
	current = State.RESOLVE
	MatchState.current = current
	publishMatchmakingState(State.RESOLVE, CONFIG.RESOLVE, true)
	for _, plr in ipairs(Players:GetPlayers()) do
		setInRound(plr, false)
		clearRoundScreens(plr)
	end
	clearDiedConns()
	for _, plr in ipairs(Players:GetPlayers()) do
		Placement.clearDesiredPlacement(plr)
	end
	CoinSpawner.stop()
	for _, plr in ipairs(Players:GetPlayers()) do
		clearRoundScreens(plr)
	end
	offeredJoin = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		SpectateEvent:FireClient(plr, false)
	end
	local seeker = seekers[1]
	local totalHiders = #hiders
	local seekerKills = (seeker and kills[seeker]) or 0

	local survivors = {}
	for _, h in ipairs(hiders) do
		if not found[h] then
			table.insert(survivors, h.Name)
		end
	end
	local lastFound = foundOrder[#foundOrder]
	local duration = (roundStartTime > 0) and math.floor(os.clock() - roundStartTime) or 0

	RoundBanner.show(bossEventVictory, bossEventTimeout, seekersWin, resultText)

	RoundRewards.resolve(bossEventVictory, bossEventTimeout, seekersWin, resultText)

	broadcast(resultText)
	runTimer(6)
	RoundSummary:FireAllClients(nil)

	local pendingClears = 0
	for _, plr in ipairs(Players:GetPlayers()) do
		if roles[plr] ~= nil and not sentToLobbyEarly[plr] then
			pendingClears += 1
			local target = plr
			task.spawn(function()
				if Placement.waitUntilPlaceable(target, 12) then
					Placement.safeRestore(target)
					Knife.clearKnife(target)
					setFrozen(target, false)
					for _ = 1, 3 do
						if Placement.pivot(target, Placement.getLobbyTarget()) then
							sentToLobbyEarly[target] = true
							break
						end
						task.wait(0.2)
					end
					BackKnife.setSuppressed(target, false)
					if not sentToLobbyEarly[target] then
						warn("[MatchManager] end-of-round: could not place " .. target.Name .. " in lobby after they became ready")
					end
				else
					warn("[MatchManager] end-of-round: " .. target.Name .. " never became placeable; forcing lobby respawn")
					Placement.clearDesiredPlacement(target)
					Placement.setLobbyRespawn(target)
					Knife.clearKnife(target)
					setFrozen(target, false)
					BackKnife.setSuppressed(target, false)
					setInRound(target, false)
					clearRoundScreens(target)
					local ok = pcall(function()
						target:LoadCharacter()
					end)
					if not ok then
						warn("[MatchManager] end-of-round: LoadCharacter failed for " .. target.Name)
					end
					sentToLobbyEarly[target] = true
				end
				pendingClears -= 1
			end)
		end
	end
	do
		local barrierDeadline = os.clock() + 10
		while pendingClears > 0 and os.clock() < barrierDeadline do
			task.wait(0.2)
		end
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		clearRoundScreens(plr)
	end
	BackKnife.refreshAll()

	MapManager.unloadMap()
	RagdollCorpse.clearAll()
	ModifierService:Clear()
	AdminSeekerService:Clear()
	PaintBucketEventService:Clear()
	PaintMutationService:Clear()
	HiddenAdminService:Clear()
	BossService:Clear()
	ChaosButtonService:Clear()
end

Players.PlayerAdded:Connect(function(plr)
	pity[plr] = pity[plr] or 0

	Placement.setLobbyRespawn(plr)
	refreshSeekerBoost(plr)
	plr:GetAttributeChangedSignal(SEEKER_BOOST_ATTR):Connect(function()
		refreshSeekerBoost(plr)
		broadcastSeekerChances()
	end)
	task.spawn(function()
		task.wait(1)
		sendStateToPlayer(plr)
		broadcastSeekerChances()
		broadcastQueue()
	end)
	plr.CharacterAdded:Connect(function()
		task.wait(0.5)

		if (current == State.ROUND or current == State.HIDE) and Placement.desired[plr] then
			local intent = Placement.desired[plr]

			if (not intent.valid) or intent.valid(plr) then
				intent.placed = false
				intent.onPlacedFired = false
				Placement.runPlacement(plr)
			else
				Placement.desired[plr] = nil
				Placement.pivot(plr, Placement.getLobbyTarget())
			end
		elseif (current ~= State.ROUND and current ~= State.HIDE) and not Placement.desired[plr] then
			local char = plr.Character
			if not (char and Placement.isOnLobbyPad(char)) then
				Placement.pivot(plr, Placement.getLobbyTarget())
			end
		elseif (current == State.ROUND or current == State.HIDE) and roles[plr] == nil and not isAfk(plr) then
			Placement.waitUntilPlaceable(plr, 10)
			if offerJoinAsSeeker then
				offerJoinAsSeeker(plr)
			end
		end
	end)
end)

removeFromRoundRoster = function(plr: Player)
	if not roles[plr] then
		return
	end

	local wasSeeker = (roles[plr] == "Seeker")
	Placement.clearDesiredPlacement(plr)

	if wasSeeker then
		markSeekerOut(plr)
	else
		for i = #hiders, 1, -1 do
			if hiders[i] == plr then
				table.remove(hiders, i)
			end
		end
		found[plr] = nil
		foundTime[plr] = nil
	end

	roles[plr] = nil
	resetCharacterScale(plr)
	Knife.clearKnife(plr)
	BackKnife.setSuppressed(plr, false)
	setInRound(plr, false)
	clearRoundScreens(plr)
	Placement.setLobbyRespawn(plr)
	local ok = pcall(function()
		Placement.pivot(plr, Placement.getLobbyTarget())
	end)
	if not ok then
		warn("[MatchManager] removeFromRoundRoster: failed to place " .. plr.Name .. " in lobby")
	end

	broadcastHidersLeft()
	broadcastRoleMap()
end

local MatchGameplayAction = script.Parent:FindFirstChild("MatchGameplayAction")
if not MatchGameplayAction then
	MatchGameplayAction = Instance.new("BindableFunction")
	MatchGameplayAction.Name = "MatchGameplayAction"
	MatchGameplayAction.Parent = script.Parent
end

MatchGameplayAction.OnInvoke = function(action: string, player: Player, payload: any)
	if action == "QueueSeeker" then
		table.insert(seekerQueue, player.UserId)
		broadcastQueue()
		return true
	end

	if action == "ReleaseSeekers" then
		if current == State.HIDE then
			skipPhase = true
		end
		return true
	end

	if action == "ReviveTier" then
		local tier = payload and payload.tier
		if canRevive(player) and nextReviveTier(player) == tier then
			local ok = pcall(revivePlayer, player)
			if not ok then
				warn("[Revive] revivePlayer errored for " .. player.Name)
			end
		else
			warn("[Revive] purchase no longer valid for " .. player.Name .. " (tier " .. tostring(tier) .. "); doing nothing")
		end
		return true
	end

	if action == "RevealHiders" then
		if current ~= State.ROUND or roles[player] ~= "Seeker" or seekerOut[player] then
			warn("[MatchManager] reveal action refused (not an active seeker): " .. player.Name)
			return false
		end
		return pcall(doReveal, player, payload and payload.mode or "one")
	end

	if action == "ApplyTroll" then
		if current ~= State.ROUND or roles[player] ~= "Hider" or found[player] then
			warn("[MatchManager] troll action refused (not an active hider in the seek phase): " .. player.Name)
			return false
		end
		return pcall(TrollService.apply, player, payload and payload.key, payload and payload.scope)
	end

	if action == "ApplyHiderSize" then
		local sizeKey = payload and payload.sizeKey
		local scale = SIZE_SCALES[sizeKey]
		if not scale then
			return false
		end
		if (current ~= State.ROUND and current ~= State.HIDE) or roles[player] ~= "Hider" or found[player] then
			warn("[MatchManager] size action refused (not an active hider in a playable phase): " .. player.Name)
			return false
		end
		local bought = sizePurchasedThisRound[player]
		if bought and bought[sizeKey] then
			warn("[MatchManager] size action refused (" .. sizeKey .. " already used this round): " .. player.Name)
			return false
		end
		local ok = pcall(function()
			applyCharacterScale(player, scale)
		end)
		if ok then
			bought = bought or {}
			bought[sizeKey] = true
			sizePurchasedThisRound[player] = bought
		end
		return ok
	end

	warn("[MatchManager] unknown gameplay action: " .. tostring(action))
	return false
end

Players.PlayerRemoving:Connect(function(plr)
	pity[plr] = nil
	Placement.clearDesiredPlacement(plr)
	lastSeekers[plr] = nil
	ownsSeekerGamepass[plr.UserId] = nil

	if current == State.HIDE or current == State.ROUND then
		if roles[plr] == "Seeker" then
			markSeekerOut(plr)
			for _, other in ipairs(Players:GetPlayers()) do
				if other ~= plr then
					clearRoundScreens(other)
				end
			end
		end

		if roles[plr] == "Hider" then
			for i = #hiders, 1, -1 do
				if hiders[i] == plr then
					table.remove(hiders, i)
				end
			end
			found[plr] = nil
			broadcastHidersLeft()
		end
	end

	for i = #seekerQueue, 1, -1 do
		if seekerQueue[i] == plr.UserId then
			table.remove(seekerQueue, i)
		end
	end
	broadcastQueue()
end)

print("[MatchManager] ready (driven by GameModeOrchestrator)")

if VotingManager.canVote() then
	VotingManager.openVote()
end

local RunMatch = script:FindFirstChild("RunMatch")
if not RunMatch then
	RunMatch = Instance.new("BindableFunction")
	RunMatch.Name = "RunMatch"
	RunMatch.Parent = script
end
RunMatch.OnInvoke = function()
	runRound()
	return true
end
