-- @author Velumix
-- @version 0.0.1
--[=[
	@class ProfileController
	@client
	Maintains the client-visible profile cache from an initial snapshot and
	batched patches. Server-only profile fields never enter this cache.
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Modules.Knit) :: typeof(require(ReplicatedStorage.Modules.Knit.KnitClient))
local ProfileSchema = require(ReplicatedStorage.Shared.ProfileSchema)
local Signal = require(ReplicatedStorage.Modules.Signal)
local Trove = require(ReplicatedStorage.Modules.Trove)

type ClientData = { [any]: any }
type ProfilePatch = ProfileSchema.ProfilePatch

local ProfileController = Knit.CreateController({
	Name = "ProfileController",
})

--[=[
	@prop Loaded Signal
	@within ProfileController
	Fires with a detached snapshot after initial load.
]=]
ProfileController.Loaded = Signal.new()
--[=[
	@prop Changed Signal
	@within ProfileController
	Fires with `(path, value, snapshot)` for every applied patch.
]=]
ProfileController.Changed = Signal.new()
--[=[
	@prop BatchChanged Signal
	@within ProfileController
	Fires once after a replicated patch batch with `(patches, snapshot)`. Prefer
	this signal for UI that renders several profile values together.
]=]
ProfileController.BatchChanged = Signal.new()
--[=[
	@prop StateChanged Signal
	@within ProfileController
	Fires with `(state, detail)` when the server profile state changes.
]=]
ProfileController.StateChanged = Signal.new()
ProfileController._data = nil :: ClientData?
ProfileController._loaded = false
ProfileController._service = nil
ProfileController._trove = Trove.new()

--[=[
	Returns whether the controller has accepted an initial snapshot or patch.

	@return boolean
]=]
function ProfileController:IsLoaded(): boolean
	return self._loaded
end

--[=[
	Returns a deep-cloned snapshot of the complete client-visible cache.

	@return table?
]=]
function ProfileController:GetData(): ClientData?
	local data = self._data :: ClientData?
	return if data then ProfileSchema.Clone(data) else nil
end

--[=[
	Reads and clones one value from the client cache.

	@param path string | {any}
	@return any
]=]
function ProfileController:GetValue(path: string | { any }): any
	local data = self._data :: ClientData?
	return if data then ProfileSchema.Clone(ProfileSchema.Read(data, path)) else nil
end

function ProfileController:_acceptSnapshot(data: ClientData?)
	if not data then
		return
	end
	self._data = ProfileSchema.Clone(data)
	self._loaded = true
	self.Loaded:Fire(self:GetData())
end

function ProfileController:_applyPatches(patches: { ProfilePatch })
	local existingData = self._data :: ClientData?
	local data: ClientData = existingData or {}
	if not existingData then
		self._data = data
	end
	for _, patch in ipairs(patches) do
		ProfileSchema.ApplyPatch(data, patch)
	end
	self._loaded = true
	-- Clone the profile once per network batch instead of once per patch. A level
	-- award, inventory grant, or committed mutation commonly contains several
	-- patches, so this keeps replication work proportional to batches.
	local snapshot = self:GetData()
	for _, patch in ipairs(patches) do
		self.Changed:Fire(patch.Path, ProfileSchema.Clone(patch.Value), snapshot)
	end
	self.BatchChanged:Fire(ProfileSchema.Clone(patches), snapshot)
end

--[=[
	Requests a fresh allow-listed snapshot from `PlayerDataService`.
]=]
function ProfileController:Refresh()
	if not self._service then
		return
	end
	self._service
		:GetSnapshot()
		:andThen(function(data)
			self:_acceptSnapshot(data :: any)
		end)
		:catch(warn)
end

function ProfileController:KnitStart()
	self._service = Knit.GetService("PlayerDataService")
	self._trove:Add(self._service.DataLoaded:Connect(function(data)
		self:_acceptSnapshot(data :: any)
	end))
	self._trove:Add(self._service.DataPatched:Connect(function(patches)
		self:_applyPatches(patches :: any)
	end))
	self._trove:Add(self._service.StateChanged:Connect(function(state, detail)
		self.StateChanged:Fire(state, detail)
	end))
	self:Refresh()
end

--[=[
	Disconnects remote signals and destroys controller-owned signals.
]=]
function ProfileController:Destroy()
	self._trove:Clean()
	self.Loaded:Destroy()
	self.Changed:Destroy()
	self.BatchChanged:Destroy()
	self.StateChanged:Destroy()
end

return ProfileController
