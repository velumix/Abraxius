-- @author Velumix
-- @version 0.0.1
--[=[
	@class PlayerDataService
	@server
	Owns profile lifecycle, validated domain mutations, safe client replication,
	and durable commit confirmation for transaction receipts.
]=]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local EnvironmentConfig = require(ReplicatedStorage.Config.EnvironmentConfig)
local Nerve = require(ReplicatedStorage.Modules.Nerve)
local NetGuard = require(ServerScriptService.NetGuard)
local ProfileConfig = require(ReplicatedStorage.Config.ProfileConfig)
local ProfileMigrations = require(ReplicatedStorage.Shared.ProfileMigrations)
local ProfileSchema = require(ReplicatedStorage.Shared.ProfileSchema)
local ProfileStoreModule: any = Nerve.GetDependency("ProfileStore")
local Signal = Nerve.GetDependency("Signal")
local Trove = Nerve.GetDependency("Trove")

local environment = EnvironmentConfig.Resolve()
local liveStore = ProfileStoreModule.New(environment.StoreName, ProfileConfig.DefaultProfile)
local ProfileStore = if environment.UseMockData then liveStore.Mock else liveStore

local PlayerDataService = Nerve.CreateService({
	Name = "PlayerDataService",
	Client = {
		DataLoaded = Nerve.CreateSignal(Nerve.Schema.Tuple({
			Nerve.Schema.Unknown,
		})),
		DataPatched = Nerve.CreateSignal(Nerve.Schema.Tuple({
			Nerve.Schema.Unknown,
		})),
		StateChanged = Nerve.CreateSignal(Nerve.Schema.Tuple({
			Nerve.Schema.String,
			Nerve.Schema.Optional(Nerve.Schema.String),
		})),
	},
	Network = {
		GetSnapshot = Nerve.Method({
			Request = Nerve.Schema.Tuple({}),
			Response = Nerve.Schema.Tuple({
				Nerve.Schema.Optional(Nerve.Schema.Unknown),
				Nerve.Schema.Optional(Nerve.Schema.String),
			}),
			RateLimit = { Requests = 3, Window = 5 },
		}),
		GetValue = Nerve.Method({
			Request = Nerve.Schema.Tuple({
				Nerve.Schema.String,
			}),
			Response = Nerve.Schema.Tuple({
				Nerve.Schema.Optional(Nerve.Schema.Unknown),
				Nerve.Schema.Optional(Nerve.Schema.String),
			}),
			RateLimit = { Requests = 10, Window = 2 },
		}),
		IsReady = Nerve.Method({
			Request = Nerve.Schema.Tuple({}),
			Response = Nerve.Schema.Tuple({
				Nerve.Schema.Boolean,
			}),
			RateLimit = { Requests = 10, Window = 2 },
		}),
		SetSetting = Nerve.Method({
			Request = Nerve.Schema.Tuple({
				Nerve.Schema.String,
				Nerve.Schema.Unknown,
			}),
			Response = Nerve.Schema.Tuple({
				Nerve.Schema.Boolean,
				Nerve.Schema.Optional(Nerve.Schema.String),
			}),
			RateLimit = { Requests = 6, Window = 5 },
		}),
	},
})

--[=[
	@prop DataLoaded Signal
	@within PlayerDataService
	Server signal fired with `(player, clientSnapshot)`.
]=]
PlayerDataService.DataLoaded = Signal.new()
--[=[
	@prop DataPatched Signal
	@within PlayerDataService
	Server signal fired with `(player, patch)`.
]=]
PlayerDataService.DataPatched = Signal.new()
--[=[
	@prop StateChanged Signal
	@within PlayerDataService
	Server signal fired with `(player, state, detail)`.
]=]
PlayerDataService.StateChanged = Signal.new()
--[=[
	@prop MutationApplied Signal
	@within PlayerDataService
	Server signal fired after a typed domain mutation.
]=]
PlayerDataService.MutationApplied = Signal.new()
--[=[
	@prop ProfileReleased Signal
	@within PlayerDataService
	Server signal fired after a profile session lock releases.
]=]
PlayerDataService.ProfileReleased = Signal.new()
PlayerDataService._profiles = {}
PlayerDataService._states = {}
PlayerDataService._loading = {}
PlayerDataService._commitLocks = {}
PlayerDataService._patchQueues = {}
PlayerDataService._patchScheduled = {}
PlayerDataService._pendingCommitSnapshots = {}
PlayerDataService._mutationLogs = {}
PlayerDataService._commitReleased = Signal.new()
PlayerDataService._trove = Trove.new()

NetGuard.Define("Data.GetSnapshot", {
	RateLimit = { Requests = 3, Window = 5 },
})
NetGuard.Define("Data.GetValue", {
	RateLimit = { Requests = 10, Window = 2 },
	MaxStringLength = 128,
	Validate = function(_player, path)
		return ProfileSchema.IsValidRemotePath(path) and ProfileSchema.IsClientVisible(path), "INVALID_PATH"
	end,
})
NetGuard.Define("Data.IsReady", {
	RateLimit = { Requests = 10, Window = 2 },
})
NetGuard.Define("Data.SetSetting", {
	RateLimit = { Requests = 6, Window = 5 },
	MaxStringLength = 64,
	Validate = function(_player, setting, value)
		local expectedType = ProfileConfig.AllowedSettings[setting]
		return expectedType ~= nil and type(value) == expectedType, "INVALID_SETTING"
	end,
})

local function isPositiveInteger(value)
	return type(value) == "number" and value > 0 and value % 1 == 0 and value < math.huge
end

local function validReason(reason)
	return type(reason) == "string" and #reason > 0 and #reason <= 64
end

local function profileKey(player: Player): string
	return "Player_" .. tostring(player.UserId)
end

local function awaitCondition(signal, timeout: number?, condition)
	local ready, initialValue = condition()
	if ready then
		return initialValue
	end

	local waitingThread = coroutine.running()
	local settled = false
	local waiting = false
	local outcome = nil
	local connection
	local timeoutThread

	local function settle(value)
		if settled then
			return
		end
		settled = true
		outcome = value
		if connection then
			connection:Disconnect()
		end
		if timeoutThread and coroutine.running() ~= timeoutThread then
			task.cancel(timeoutThread)
		end
		if waiting then
			task.spawn(waitingThread)
		end
	end

	connection = signal:Connect(function(...)
		local complete, value = condition(...)
		if complete then
			settle(value)
		end
	end)
	if timeout then
		timeoutThread = task.delay(math.max(timeout, 0), function()
			settle(nil)
		end)
	end

	local complete, value = condition()
	if complete then
		settle(value)
	end
	if not settled then
		waiting = true
		coroutine.yield()
	end
	return outcome
end

local function restoreTable(target, snapshot)
	table.clear(target)
	for key, value in pairs(snapshot) do
		target[key] = value
	end
end

local function deepEqual(left, right)
	if left == right then
		return true
	end
	if type(left) ~= "table" or type(right) ~= "table" then
		return false
	end
	for key, value in pairs(left) do
		if not deepEqual(value, right[key]) then
			return false
		end
	end
	for key in pairs(right) do
		if left[key] == nil then
			return false
		end
	end
	return true
end

function PlayerDataService:_setState(player: Player, state: string, detail: string?)
	self._states[player] = state
	self.StateChanged:Fire(player, state, detail)
	if player.Parent == Players then
		self.Client.StateChanged:Fire(player, state, detail)
	end
end

--[=[
	Returns `NotLoaded`, `Loading`, `Ready`, `Failed`, `Releasing`, or `Released`.

	@param player Player
	@return string
]=]
function PlayerDataService:GetState(player: Player): string
	return self._states[player] or "NotLoaded"
end

function PlayerDataService:_clientSnapshot(player: Player)
	local profile = self._profiles[player]
	return if profile then ProfileSchema.ClientSnapshot(profile.Data) else nil
end

function PlayerDataService:_fireLoaded(player: Player)
	local snapshot = self:_clientSnapshot(player)
	if not snapshot then
		return
	end
	self.DataLoaded:Fire(player, snapshot)
	self.Client.DataLoaded:Fire(player, snapshot)
end

function PlayerDataService:_queuePatch(player: Player, path, value)
	if not ProfileSchema.IsClientVisible(path) then
		return
	end

	local patch = ProfileSchema.MakePatch(path, value)
	self.DataPatched:Fire(player, patch)

	local queue = self._patchQueues[player]
	if not queue then
		queue = {}
		self._patchQueues[player] = queue
	end
	table.insert(queue, patch)

	if self._patchScheduled[player] then
		return
	end
	self._patchScheduled[player] = true
	task.defer(function()
		self._patchScheduled[player] = nil
		local patches = self._patchQueues[player]
		self._patchQueues[player] = nil
		if patches and #patches > 0 and player.Parent == Players then
			self.Client.DataPatched:Fire(player, patches)
		end
	end)
end

function PlayerDataService:_queueSnapshotDiff(player: Player, before, after)
	local roots = {}
	for root in pairs(before) do
		roots[root] = true
	end
	for root in pairs(after) do
		roots[root] = true
	end
	for root in pairs(roots) do
		if not deepEqual(before[root], after[root]) then
			self:_queuePatch(player, root, after[root])
		end
	end
end

function PlayerDataService:_recordMutation(player: Player, operation: string, reason: string, details)
	local log = self._mutationLogs[player]
	if not log then
		log = {}
		self._mutationLogs[player] = log
	end
	table.insert(log, {
		Operation = operation,
		Reason = reason,
		Details = ProfileSchema.Clone(details),
		Timestamp = os.time(),
	})
	if #log > 100 then
		table.remove(log, 1)
	end
	self.MutationApplied:Fire(player, operation, reason, details)
end

--[=[
	Loads, migrates, reconciles, and session-locks a player's profile. Loading is
	idempotent and cancellation follows the player's lifetime.

	@param player Player
	@return any? -- Active ProfileStore profile, or `nil` on failure.
]=]
function PlayerDataService:LoadProfile(player: Player)
	if self._profiles[player] then
		return self._profiles[player]
	end
	if self._loading[player] then
		return nil
	end

	self._loading[player] = true
	self:_setState(player, "Loading")

	local ok, result = xpcall(function()
		return ProfileStore:StartSessionAsync(profileKey(player), {
			Cancel = function()
				return player.Parent ~= Players
			end,
		})
	end, debug.traceback)
	self._loading[player] = nil
	local profile = if ok then result else nil
	local lastError = if ok then "profile session returned nil" else tostring(result)

	if not profile then
		self:_setState(player, "Failed", lastError)
		if player.Parent == Players then
			player:Kick("Your data could not be loaded. Please rejoin.")
		end
		return nil
	end

	profile:AddUserId(player.UserId)
	local fromVersion, toVersion = ProfileMigrations.Apply(profile.Data)
	profile:Reconcile()
	if fromVersion ~= toVersion then
		print(`Migrated profile {player.UserId} from schema {fromVersion} to {toVersion}`)
	end
	profile.OnSessionEnd:Connect(function()
		self._profiles[player] = nil
		if self._commitLocks[player] then
			self._commitLocks[player] = nil
			self._commitReleased:Fire(player)
		end
		self._pendingCommitSnapshots[player] = nil
		self.ProfileReleased:Fire(player)
		if player.Parent == Players then
			self:_setState(player, "Released")
			player:Kick("Your data was loaded from another server. Please rejoin.")
		else
			self._states[player] = nil
		end
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return nil
	end

	self._profiles[player] = profile
	self:_setState(player, "Ready")
	self:_fireLoaded(player)
	return profile
end

--[=[
	Begins an asynchronous save and releases the player's session lock.

	@param player Player
]=]
function PlayerDataService:ReleaseProfile(player: Player)
	local profile = self._profiles[player]
	if not profile then
		return
	end
	self:_setState(player, "Releasing")
	self._profiles[player] = nil
	profile:EndSession()
end

--[=[
	Returns whether the server currently owns an active profile for the player.

	@param player Player
	@return boolean
]=]
function PlayerDataService:IsLoaded(player: Player): boolean
	return self._profiles[player] ~= nil
end

--[=[
	Returns the active ProfileStore profile for server infrastructure. Gameplay
	systems should prefer typed mutation APIs.

	@param player Player
	@return any?
]=]
function PlayerDataService:GetProfile(player: Player)
	return self._profiles[player]
end

--[=[
	Returns a deep-cloned complete server profile snapshot.

	@param player Player
	@return table?
]=]
function PlayerDataService:GetData(player: Player)
	local profile = self._profiles[player]
	return if profile then ProfileSchema.Clone(profile.Data) else nil
end

--[=[
	Reads and clones one server profile value.

	@param player Player
	@param path string | {any}
	@return any
]=]
function PlayerDataService:GetValue(player: Player, path)
	local profile = self._profiles[player]
	return if profile then ProfileSchema.Clone(ProfileSchema.Read(profile.Data, path)) else nil
end

--[=[
	Yields until a profile becomes ready, fails, the player leaves, or the optional
	timeout expires.

	@param player Player
	@param timeout number? -- Maximum seconds to wait; `nil` waits indefinitely.
	@return any? -- Active ProfileStore profile.
	@yields
]=]
function PlayerDataService:WaitForProfile(player: Player, timeout: number?)
	return awaitCondition(self.StateChanged, timeout, function(changedPlayer, state)
		local profile = self._profiles[player]
		if profile then
			return true, profile
		end
		if player.Parent ~= Players then
			return true, nil
		end
		if changedPlayer == player and (state == "Failed" or state == "Released") then
			return true, nil
		end
		return false, nil
	end)
end

function PlayerDataService:_setValue(player: Player, path, value)
	assert(not self._commitLocks[player], "profile is locked by a durable mutation")
	local profile = self._profiles[player]
	assert(profile ~= nil, "profile is not loaded")
	ProfileSchema.Write(profile.Data, path, value)
	self:_queuePatch(player, path, value)
	return value
end

--[=[
	Awards a configured currency and emits a client patch and mutation audit entry.

	@param player Player
	@param currency string -- Key allow-listed by `ProfileConfig.CurrencyFields`.
	@param amount number -- Positive integer amount.
	@param reason string -- Stable audit reason, at most 64 characters.
	@return number -- New currency balance.
]=]
function PlayerDataService:AwardCurrency(player: Player, currency: string, amount: number, reason: string)
	assert(ProfileConfig.CurrencyFields[currency] == true, "unsupported currency")
	assert(isPositiveInteger(amount), "amount must be a positive integer")
	assert(validReason(reason), "reason must be a non-empty string up to 64 characters")
	local nextValue = (tonumber(self:GetValue(player, currency)) or 0) + amount
	self:_setValue(player, currency, nextValue)
	self:_recordMutation(player, "AwardCurrency", reason, { Currency = currency, Amount = amount })
	return nextValue
end

--[=[
	Spends currency if the player can afford it. Use this instead of changing the
	balance directly so the transaction is tracked.

	@param player Player
	@param currency string
	@param amount number -- Positive integer cost.
	@param reason string -- Stable transaction/SKU reason.
	@return boolean -- Whether the balance was changed.
	@return number -- Balance after the attempt.
]=]
function PlayerDataService:SpendCurrency(
	player: Player,
	currency: string,
	amount: number,
	reason: string
): (boolean, number)
	assert(ProfileConfig.CurrencyFields[currency] == true, "unsupported currency")
	assert(isPositiveInteger(amount), "amount must be a positive integer")
	assert(validReason(reason), "reason must be a non-empty string up to 64 characters")
	local balance = tonumber(self:GetValue(player, currency)) or 0
	if balance < amount then
		return false, balance
	end
	local nextValue = balance - amount
	self:_setValue(player, currency, nextValue)
	self:_recordMutation(player, "SpendCurrency", reason, { Currency = currency, Amount = amount })
	return true, nextValue
end

--[=[
	Adds experience, performs level-ups, and replicates both changed fields.

	@param player Player
	@param amount number -- Positive integer amount.
	@param reason string -- Stable audit reason.
	@return number -- New level.
	@return number -- Remaining experience toward the next level.
]=]
function PlayerDataService:AddExperience(player: Player, amount: number, reason: string)
	assert(isPositiveInteger(amount), "amount must be a positive integer")
	assert(validReason(reason), "invalid reason")
	local experience = (tonumber(self:GetValue(player, "Experience")) or 0) + amount
	local maxLevel = self._progression:GetMaxLevel()
	local level = math.clamp(tonumber(self:GetValue(player, "Level")) or 1, 1, maxLevel)
	while level < maxLevel do
		local required = self._progression:GetExperienceForLevel(level)
		if experience < required then
			break
		end
		experience -= required
		level += 1
	end
	if level >= maxLevel then
		experience = 0
	end
	self:_setValue(player, "Experience", experience)
	self:_setValue(player, "Level", level)
	self:_recordMutation(player, "AddExperience", reason, { Amount = amount })
	return level, experience
end

--[=[
	Adds a stackable inventory item.

	@param player Player
	@param itemId string -- Stable item identifier, at most 64 characters.
	@param amount number? -- Positive integer; defaults to `1`.
	@param reason string -- Stable audit reason.
	@return number -- New item count.
]=]
function PlayerDataService:AddItem(player: Player, itemId: string, amount: number?, reason: string)
	local resolvedAmount: number = amount or 1
	assert(type(itemId) == "string" and #itemId > 0 and #itemId <= 64, "invalid item ID")
	assert(isPositiveInteger(resolvedAmount), "amount must be a positive integer")
	assert(validReason(reason), "invalid reason")
	local path = { "Inventory", itemId }
	local nextValue = (tonumber(self:GetValue(player, path)) or 0) + resolvedAmount
	self:_setValue(player, path, nextValue)
	self:_recordMutation(player, "AddItem", reason, { ItemId = itemId, Amount = resolvedAmount })
	return nextValue
end

--[=[
	Updates an allow-listed player setting after validating its configured type.

	@param player Player
	@param setting string
	@param value any
	@param reason string -- Stable audit reason.
	@return any -- Stored value.
]=]
function PlayerDataService:SetSetting(player: Player, setting: string, value, reason: string)
	local expectedType = ProfileConfig.AllowedSettings[setting]
	assert(expectedType ~= nil and type(value) == expectedType, "invalid setting or value")
	assert(validReason(reason), "invalid reason")
	self:_setValue(player, { "Settings", setting }, value)
	self:_recordMutation(player, "SetSetting", reason, { Setting = setting })
	return value
end

--[=[
	Returns a detached copy of the player's bounded in-memory mutation audit log.

	@param player Player
	@return {table}
]=]
function PlayerDataService:GetMutationLog(player: Player)
	return ProfileSchema.Clone(self._mutationLogs[player] or {})
end

--[=[
	Serializes a critical profile mutation and waits until ProfileStore confirms
	that its monotonically increasing commit marker was saved. The mutator receives
	`(data, commitVersion)` and must return `(accepted, result)`. It must mutate only
	the provided data table and must not call another PlayerDataService mutation.

	@param player Player
	@param mutator (data: table, commitVersion: number) -> (boolean, any)
	@param timeout number? -- Seconds before returning a retryable failure.
	@return boolean -- Whether the mutation is durably persisted.
	@return any -- Mutator result or stable failure code.
	@return number? -- Confirmed commit version on success.
	@yields
]=]
function PlayerDataService:RunCommittedMutation(player: Player, mutator, timeout: number?)
	local commitTimeout: number = timeout or ProfileConfig.CommitTimeoutSeconds
	local deadline = os.clock() + commitTimeout
	if self._commitLocks[player] then
		local unlocked = awaitCondition(self._commitReleased, commitTimeout, function(unlockedPlayer)
			if not self._commitLocks[player] then
				return true, true
			end
			return unlockedPlayer == player and not self._commitLocks[player], true
		end)
		if not unlocked then
			return false, "COMMIT_LOCK_TIMEOUT"
		end
	end

	local profile = self._profiles[player]
	if not profile or not profile:IsActive() then
		return false, "PROFILE_NOT_READY"
	end
	self._commitLocks[player] = true

	local backup = ProfileSchema.Clone(profile.Data)
	local clientBefore = self._pendingCommitSnapshots[player] or ProfileSchema.ClientSnapshot(profile.Data)
	local commerce = profile.Data.Commerce
	local lastSavedCommerce = if profile.LastSavedData then profile.LastSavedData.Commerce else nil
	local version = math.max(
		tonumber(commerce.CommitVersion) or 0,
		tonumber(if lastSavedCommerce then lastSavedCommerce.CommitVersion else nil) or 0
	) + 1
	local ok, accepted, result = xpcall(mutator, debug.traceback, profile.Data, version)
	if not ok or accepted == false then
		restoreTable(profile.Data, backup)
		self._commitLocks[player] = nil
		self._commitReleased:Fire(player)
		if not ok then
			warn(`Committed mutation failed for {player.UserId}: {accepted}`)
			return false, "MUTATION_FAILED"
		end
		return false, result or "MUTATION_REJECTED"
	end

	profile.Data.Commerce.CommitVersion = version
	profile:Save()
	local confirmed = awaitCondition(profile.OnAfterSave, math.max(deadline - os.clock(), 0), function(lastSavedData)
		local savedData = lastSavedData or profile.LastSavedData
		local savedCommerce = if savedData then savedData.Commerce else nil
		if (tonumber(if savedCommerce then savedCommerce.CommitVersion else nil) or 0) >= version then
			return true, true
		end
		if not profile:IsActive() then
			return true, false
		end
		return false, nil
	end)

	if confirmed then
		self._pendingCommitSnapshots[player] = nil
		local clientAfter = ProfileSchema.ClientSnapshot(profile.Data)
		self._commitLocks[player] = nil
		self._commitReleased:Fire(player)
		self:_queueSnapshotDiff(player, clientBefore, clientAfter)
		return true, result, version
	end

	self._commitLocks[player] = nil
	self._commitReleased:Fire(player)
	self._pendingCommitSnapshots[player] = self._pendingCommitSnapshots[player] or clientBefore
	return false, "COMMIT_TIMEOUT"
end

--[=[
	@client
	@within PlayerDataService
	Remote method that returns the caller's allow-listed client snapshot.

	@return table? -- Client-visible snapshot.
	@return string? -- NetGuard rejection code.
]=]
function PlayerDataService.Client:GetSnapshot(player: Player)
	local allowed, reason = NetGuard.Check(player, "Data.GetSnapshot")
	if not allowed then
		return nil, reason
	end
	return self.Server:_clientSnapshot(player)
end

--[=[
	@client
	@within PlayerDataService
	Remote method that reads one allow-listed client-visible path.

	@param path string
	@return any
	@return string? -- NetGuard rejection code.
]=]
function PlayerDataService.Client:GetValue(player: Player, path: string)
	local allowed, reason = NetGuard.Check(player, "Data.GetValue", path)
	if not allowed then
		return nil, reason
	end
	return ProfileSchema.Clone(self.Server:GetValue(player, path))
end

--[=[
	@client
	@within PlayerDataService
	Remote method that reports whether the caller's profile is ready.

	@return boolean
]=]
function PlayerDataService.Client:IsReady(player: Player): boolean
	local allowed = NetGuard.Check(player, "Data.IsReady")
	return allowed and self.Server:IsLoaded(player)
end

--[=[
	@client
	@within PlayerDataService
	Persists one allow-listed player preference.

	@param setting string
	@param value any
	@return boolean
	@return string?
]=]
function PlayerDataService.Client:SetSetting(player: Player, setting: string, value)
	local allowed, reason = NetGuard.Check(player, "Data.SetSetting", setting, value)
	if not allowed then
		return false, reason
	end
	if not self.Server:IsLoaded(player) then
		return false, "PROFILE_NOT_READY"
	end
	self.Server:SetSetting(player, setting, value, "PlayerPreference")
	return true, nil
end

function PlayerDataService:NerveInit()
	self._progression = Nerve.GetService("ProgressionService")
end

function PlayerDataService:NerveStart()
	print(
		`[PlayerDataService] Environment={environment.Name} Store={environment.StoreName} MockData={environment.UseMockData}`
	)
	self._trove:Connect(Players.PlayerAdded, function(player)
		task.spawn(function()
			self:LoadProfile(player)
		end)
	end)
	self._trove:Connect(Players.PlayerRemoving, function(player)
		self:ReleaseProfile(player)
		self._states[player] = nil
		self._patchQueues[player] = nil
		self._patchScheduled[player] = nil
		self._pendingCommitSnapshots[player] = nil
		self._mutationLogs[player] = nil
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			self:LoadProfile(player)
		end)
	end
end

--[=[
	Disconnects service-owned runtime connections. Intended for test teardown.
]=]
function PlayerDataService:Destroy()
	self._trove:Clean()
end

return PlayerDataService
