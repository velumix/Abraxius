local ReplicatedStorage =game:GetService("ReplicatedStorage")

local Mince = require(ReplicatedStorage.Modules.Mince)
local Signal = require(ReplicatedStorage.Modules.Signal)
local Utility = require(ReplicatedStorage.Modules.Utility)
local TableUtil = require(ReplicatedStorage.Modules.TableUtil)

local ProfileService = require(script.ProfileService)
local Players = game:GetService("Players")

local DataSync = Mince:GetEvent("DataSync")
local DataPartialSync = Mince:GetEvent("DataPartialSync")

--[[
	@class PlayerDataManager
	@server

	Owns ProfileService-backed player data for the server runtime.

	PlayerDataManager loads and releases player profiles, maintains per-player
	session state, publishes full and partial profile updates through Mince
	remotes, and creates replicated currency state objects consumed by economy
	and UI systems.
]]

local function GetCurrencyStateName(Player)
	return "Currency_" .. tostring(Player.UserId)
end

local function GetEcoPointsStateName(Player)
	return "EcoPoints_" .. tostring(Player.UserId)
end

local function RejectClientSet(StateName)
	return function(Player, NewValue)
		warn(string.format("[%s] Player %s attempted unauthorized set to %s", StateName, Player.Name, tostring(NewValue)))
		return nil
	end
end

local function SetupPlayerState(Player, profileData)
	if not profileData then
		warn("[PlayerDataManager] SetupPlayerState called with no profileData for", Player.Name)
		return
	end

	local CurrencyState = Mince:GetState(GetCurrencyStateName(Player))
	CurrencyState:SetAudience({ Player })
	CurrencyState.Balance = profileData.Currency.Balance
	CurrencyState.TotalEarned = profileData.Currency.TotalEarned
	CurrencyState.TotalSpent = profileData.Currency.TotalSpent
	CurrencyState.LastIncomeTime = profileData.Currency.LastIncomeTime
	CurrencyState.IncomeStreak = profileData.Currency.IncomeStreak
	CurrencyState.Sources = TableUtil.Copy(profileData.Currency.Sources, true)
	CurrencyState:RegisterSetHandler("Balance", RejectClientSet("CurrencyState"))
	CurrencyState:RegisterSetHandler("TotalEarned", RejectClientSet("CurrencyState"))
	CurrencyState:RegisterSetHandler("TotalSpent", RejectClientSet("CurrencyState"))
	CurrencyState:RegisterSetHandler("Sources", RejectClientSet("CurrencyState"))

	local EcoState = Mince:GetState(GetEcoPointsStateName(Player))
	EcoState:SetAudience({ Player })
	EcoState.Balance = profileData.EcoPoints.Balance
	EcoState.TotalEarned = profileData.EcoPoints.TotalEarned
	EcoState.TotalSpent = profileData.EcoPoints.TotalSpent
	EcoState.Sources = TableUtil.Copy(profileData.EcoPoints.Sources, true)
	EcoState:RegisterSetHandler("Balance", RejectClientSet("EcoPointsState"))
	EcoState:RegisterSetHandler("TotalEarned", RejectClientSet("EcoPointsState"))
	EcoState:RegisterSetHandler("TotalSpent", RejectClientSet("EcoPointsState"))
	EcoState:RegisterSetHandler("Sources", RejectClientSet("EcoPointsState"))
end

local function CleanupPlayerState(Player)
	local Success, CurrencyState = pcall(Mince.GetState, Mince, GetCurrencyStateName(Player))
	if Success and CurrencyState then
		CurrencyState:Destroy()
	end

	local Success2, EcoState = pcall(Mince.GetState, Mince, GetEcoPointsStateName(Player))
	if Success2 and EcoState then
		EcoState:Destroy()
	end
end

local PlayerDataManager = {
	ProfileTemplate = require(script.DefaultData),
	LocalPlayerData = require(script.LocalPlayerData),
	DataStoreKey = "PlayerData.Dev13",
	Profiles = {},
	LocalData = {},

	ProfileReleasing = {},

	ProfileReleased = Signal.new(),
	ProfileLoaded = Signal.new(),
	ProfileLoading = Signal.new(),
	ProfileReset = Signal.new(),
}

local ProfileStore = ProfileService.GetProfileStore(PlayerDataManager.DataStoreKey,PlayerDataManager.ProfileTemplate)
PlayerDataManager.ProfileStore = ProfileStore

--[[
	Waits for registered profile release hooks before releasing a profile.

	@within PlayerDataManager
	@param Player Player
	@param Profile table
]]
function PlayerDataManager:YeildForReleasingFunctions(Player, Profile)
	if not next(PlayerDataManager.ProfileReleasing) then
		return
	end

	local Complete, RunningThread = {}, coroutine.running()
	for _, ControlFn in pairs(PlayerDataManager.ProfileReleasing or {}) do
		Complete[ControlFn] = false
	end

	for _, ControlFn in PlayerDataManager.ProfileReleasing do
		task.defer(function()
			local Success, Result = pcall(ControlFn, Player, Profile)
			if not Success then
				print(`[PlayerDataManager]: FAULT '{Result}'.`)
			end

			Complete[ControlFn] = true

			for _, IsComplete in pairs(Complete or {}) do
				if not IsComplete then
					return
				end
			end

			coroutine.resume(RunningThread)
		end)
	end

	coroutine.yield()
end

--[[
	Registers a callback that runs before a profile is released.

	@within PlayerDataManager
	@param ControlFN (Player, table) -> ()
]]
function PlayerDataManager:WhenReleasing(ControlFN)
	assert(Utility.AssertTypes(ControlFN, "function"))
	PlayerDataManager.ProfileReleasing[newproxy()] = ControlFN
end

function PlayerDataManager:GetAllLocalData()
	return PlayerDataManager.LocalData
end

function PlayerDataManager:GetLocalData(Player : Player)
	if not PlayerDataManager.LocalData[Player] and Player:IsDescendantOf(Players) then
		task.wait()
	end

	if not PlayerDataManager.LocalData[Player] then
		return nil
	end
	return PlayerDataManager.LocalData[Player]
end

--[[
	Gets a loaded profile, yielding until it loads while the player remains in
	game.

	@within PlayerDataManager
	@param Player Player
	@return table?
]]
function PlayerDataManager:GetProfile(Player : Player)
	local Profile = PlayerDataManager.Profiles[Player]
	if Profile then return Profile end

	-- If the profile is NOT loaded in memory, and thee player has already left don'rt allow to yeild thiws.
	if not Player:IsDescendantOf(Players) then
		return nil
	end

	local Thread = coroutine.running()
	local Connection : RBXScriptConnection = PlayerDataManager.ProfileLoaded:Connect(function(ThisPlayer, ThisProfile)
		if ThisPlayer == Player then
			Profile = ThisProfile

			coroutine.resume(Thread)
		end
	end)

	Player.AncestryChanged:Connect(function()
		if not Player:IsDescendantOf(Players) then
			coroutine.resume(Thread)
		end
	end)

	coroutine.yield()

	Connection:Disconnect()

	if Profile == nil then
		return nil
	end
	return Profile
end

--[[
	Gets the data table from a player's loaded profile.

	@within PlayerDataManager
	@param Player Player
	@return table?
]]
function PlayerDataManager:GetProfileData(Player)
	local Profile = PlayerDataManager:GetProfile(Player)
	if not Profile then
		warn("Profile not found for player:", Player.Name)
		return nil
	end

	return Profile.Data
end

--[[
	Resets a player's profile data to the default template and republishes
	replicated state.

	@within PlayerDataManager
	@param Player Player
]]
function PlayerDataManager:ResetProfile(Player)
	local Profile = PlayerDataManager:GetProfile(Player)
	if Profile then
		Profile.Data = TableUtil.Copy(PlayerDataManager.ProfileTemplate, true)
		SetupPlayerState(Player, Profile)
		PlayerDataManager.ProfileReset:Fire(Player, Profile)
		PlayerDataManager.ProfileLoaded:Fire(Player, Profile)
		Profile.Data.FirstOpen = false
	end
end

function PlayerDataManager:ForceSave(Player)
	local Profile = PlayerDataManager:GetProfile(Player)
	if Profile and Profile.Save then
		local success, err = pcall(function()
			Profile:Save()
		end)
		if not success then
			warn("ForceSave failed for", Player.Name, ":", err)
		end
		return success
	end
	return false
end

function PlayerDataManager.PreReconcile(Player, Profile)
	PlayerDataManager.ProfileLoading:Fire(Player,Profile)

	if not Profile.Data.Signatures then
		Profile.Data.Signatures = {}
	end
	local SignatureMatching = {
		["ExampleProcessing"] = {function(Profile)
		end}
	}

	for RequiredSignature,SignatureProcessTable in pairs(SignatureMatching or {}) do
		local SignatureProcessFn = SignatureProcessTable[1]
		local MaxSignatureProcessing = SignatureProcessTable[2] or 1
		local SignatureValue = Profile.Data.Signatures[RequiredSignature] or 0

		if SignatureValue < MaxSignatureProcessing then
			local Success, Result = pcall(SignatureProcessFn,Profile)

			if Success then
				Profile.Data.Signatures[RequiredSignature] = SignatureValue + 1
			else
				warn(`Signature signing failure! ({RequiredSignature}) `)
				warn(Result)
			end
		end
	end
end

function PlayerDataManager:InitProfile(Player, Profile)
	SetupPlayerState(Player, Profile.Data)
	PlayerDataManager.ProfileLoaded:Fire(Player, Profile)

	local AsyncUpdate = function()
		Mince:WaitUntilHandshake(Player)
		PlayerDataManager:UpdatePlayer(Player, "All")
		local PlayerData = PlayerDataManager:GetLocalData(Player)
		PlayerData.Records = Profile.Data.CooldownRecords
	end



	task.spawn(AsyncUpdate)
	task.wait()
	Profile.Data.FirstOpen = false
end

function PlayerDataManager.PlayerAdded(Player)
	PlayerDataManager.LocalData[Player] = PlayerDataManager.LocalPlayerData.new(Player)

	-- Create states early so the client never waits on DataStore.
	SetupPlayerState(Player, PlayerDataManager.ProfileTemplate)

	local Profile = ProfileStore:LoadProfileAsync("PID:" .. Player.UserId)
	if Profile ~= nil then
		Profile:AddUserId(Player.UserId) -- GDPR compliance
		PlayerDataManager.PreReconcile(Player,Profile)
		Profile:Reconcile() -- Fill in missing variables from ProfileTemplate (optional)
		Profile:ListenToRelease(function()
			PlayerDataManager.Profiles[Player] = nil
			-- The Profile could've been loaded on another Roblox server:
			Player:Kick("Profile was already loaded,(Try Re-joining). [ 382 ]")
		end)
		if Player:IsDescendantOf(Players) == true then
			PlayerDataManager.Profiles[Player] = Profile
			-- A Profile has been successfully loaded:
			PlayerDataManager:InitProfile(Player, Profile)
		else
			-- Player left before the Profile loaded:
			PlayerDataManager.ProfileReleased:Fire(Player, Profile)
			PlayerDataManager:YeildForReleasingFunctions(Player, Profile)
			Profile:Release()
		end
	else
		-- The Profile couldn't be loaded possibly due to other
		--   Roblox servers trying to load this Profile at the same time:
		Player:Kick("Profile was already loaded, (Try Re-joining). [ 381 ] ")
	end
end


function PlayerDataManager:Capture(Player,...)
	local PlayerData = PlayerDataManager:GetLocalData(Player)
	local Profile = PlayerDataManager:GetProfileData(Player)

	if not PlayerData then return end
	if not PlayerData.LastProfile then
		PlayerData.LastProfile = TableUtil.Copy(Profile, true)
	end

	local UpdateTopics = {...}
	if #UpdateTopics > 0 then
		for _,Index in pairs(UpdateTopics or {}) do
			PlayerData.LastProfile[Index] = TableUtil.Copy(Profile[Index], true)
		end
	else
		PlayerData.LastProfile = TableUtil.Copy(Profile, true)
	end
end

function PlayerDataManager:PartialUpdate(Player,...)
	local PlayerData = PlayerDataManager:GetLocalData(Player)
	local Profile = PlayerDataManager:GetProfileData(Player)
	local UpdateTopics = {...}

	local LastProfile = PlayerData.LastProfile or Profile

	local UpdateBody , BodyUpdated = {} , false
	for _,Index in pairs(UpdateTopics or {}) do
		UpdateBody[Index] = {}
		for SecndIndex,Value in pairs(Profile[Index] or {}) do
			if not Utility.TableEq(LastProfile[Index][SecndIndex],Profile[Index][SecndIndex])  then
				UpdateBody[Index][SecndIndex] = Profile[Index][SecndIndex]
				BodyUpdated = true
			end
		end
	end

	if BodyUpdated then
		DataPartialSync:Fire(Player, UpdateBody)
	end
end


function PlayerDataManager:SchedulePlayerUpdate(Player, ...)
	local Profile = PlayerDataManager:GetProfileData(Player)
	local LocalData = PlayerDataManager.LocalData[Player]
	local UpdateTopics = {...}

	local IsAll = #UpdateTopics == 1 and UpdateTopics[1] == "All"
	local UpdateBody = {}

	if IsAll then
		for Index,_ in pairs(Profile or {}) do
			LocalData.ScheduledUpdates[Index] = true
		end
	else
		for _,Index in pairs(UpdateTopics or {}) do
			LocalData.ScheduledUpdates[Index] = true
		end
	end
end


--[[
	Sends selected profile sections to one client.

	Pass `"All"` as the only topic to send the entire profile.

	@within PlayerDataManager
	@param Player Player
	@param ... string -- Profile section names or `"All"`.
	@return table
]]
function PlayerDataManager:UpdatePlayer(Player,...)
	local Profile = PlayerDataManager:GetProfileData(Player)

	local UpdateTopics = {...}
	local IsAll = #UpdateTopics == 1 and UpdateTopics[1] == "All"
	local UpdateBody = {}
	for _,Index in pairs(UpdateTopics or {}) do
		UpdateBody[Index] = Profile[Index]
	end
	if IsAll then
		UpdateBody = Profile
	end

	DataSync:Fire(Player, UpdateBody)
	return UpdateBody
end

function PlayerDataManager.PlayerRemoved(Player)
	local Profile = PlayerDataManager.Profiles[Player]
	if Profile ~= nil then
		PlayerDataManager.ProfileReleased:Fire(Player, Profile)
		PlayerDataManager:YeildForReleasingFunctions(Player, Profile)
		Profile:Release()
	end

	CleanupPlayerState(Player)

	task.wait(0.1)

	PlayerDataManager.LocalData[Player] = nil
end

--[[
	Connects player lifecycle handlers and data sync remotes.

	@within PlayerDataManager
]]
function PlayerDataManager:Setup()
	-- Connections
	Players.PlayerAdded:Connect(PlayerDataManager.PlayerAdded)
	Players.PlayerRemoving:Connect(PlayerDataManager.PlayerRemoved)

	-- Catchups
	for _, Player in ipairs(Players:GetPlayers() or {}) do
		coroutine.wrap(PlayerDataManager.PlayerAdded)(Player)
	end

	DataSync.Event:Connect(function(Player, Index)
		local LocalData = PlayerDataManager.LocalData[Player]
		if not LocalData then return end

		if Index then
			local PendingUpdate = LocalData.ScheduledUpdates[Index]

			if PendingUpdate then
				LocalData.ScheduledUpdates[Index] = nil -- Free instead of nilling
				PlayerDataManager:UpdatePlayer(Player,Index)
			end
		end
	end)

	PlayerDataManager.ProfileLoaded:Connect(function(Player)
		Player:SetAttribute("IsProfileLoaded", true)
	end)
end

return PlayerDataManager
