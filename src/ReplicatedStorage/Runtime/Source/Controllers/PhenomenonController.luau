local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules
local Mince = require(Modules.Mince)
local Signal = require(Modules.Signal)

local PhenomenonController = {
	Name = "PhenomenonController",
	Timeline = {},
	Registry = {},
	TimelineChanged = Signal.new(),
	CurrentChanged = Signal.new(),
}

function PhenomenonController:_getServerNowUtc()
	if self.ServerTimeUTC and self.ServerTimeReceivedAt then
		return self.ServerTimeUTC + (time() - self.ServerTimeReceivedAt)
	end
	return os.time(os.date("!*t"))
end

function PhenomenonController:Setup()
	self.Remote = Mince:GetEvent("Phenomena")
	self.TimelineRemote = self.Remote:Extend("Timeline")
	self.RegistryRemote = self.Remote:Extend("Registry")

	self.TimelineRemote.Event:Connect(function(data)
		if type(data) ~= "table" then return end

		if data.Timeline then
			self.Timeline = data.Timeline
			self.ServerTimeUTC = data.ServerTimeUTC
			self.ServerTimeReceivedAt = time()
			self.TimelineChanged:Fire(self.Timeline)
		end
	end)

	self.RegistryRemote.Event:Connect(function(registry)
		if type(registry) == "table" then
			self.Registry = registry
		end
	end)
end

function PhenomenonController:GameStart()
	self.TimelineRemote:Fire()
	self.RegistryRemote:Fire()

	task.spawn(function()
		local attempts = 0
		local waitTime = 1

		while attempts < 8 do
			if self.Timeline and #self.Timeline > 0 then
				break
			end

			task.wait(waitTime)
			self.TimelineRemote:Fire()
			attempts += 1
			waitTime = math.min(waitTime * 2, 15)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(30)

			if not self.Timeline or #self.Timeline == 0 then
				self.TimelineRemote:Fire()
			else
				local lastBlock = self.Timeline[#self.Timeline]
				local lastEnd = lastBlock and (lastBlock.HourStartTime + 3600) or 0
				local now = self:_getServerNowUtc()

				if lastEnd > 0 and now >= (lastEnd - 60) then
					self.TimelineRemote:Fire()
				end
			end
		end
	end)

	task.spawn(function()
		local lastId = nil

		while true do
			task.wait(5)

			local current = self:GetCurrent()
			local currentId = current and current.Id

			if currentId ~= lastId then
				lastId = currentId
				self.CurrentChanged:Fire(current)
			end
		end
	end)
end

function PhenomenonController:GetCurrent()
	local now = self:_getServerNowUtc()

	for _, hourBlock in ipairs(self.Timeline) do
		if hourBlock.Phenomena then
			for _, slot in ipairs(hourBlock.Phenomena) do
				if now >= slot.StartTime and now < slot.EndTime then
					return slot.Data
				end
			end
		end
	end

	return nil
end

function PhenomenonController:GetUpcoming(count)
	count = count or 10
	local now = self:_getServerNowUtc()
	local upcoming = {}

	for _, hourBlock in ipairs(self.Timeline) do
		if hourBlock.Phenomena then
			for _, slot in ipairs(hourBlock.Phenomena) do
				if slot.EndTime > now and #upcoming < count then
					table.insert(upcoming, slot)
				end
			end
		end
	end

	return upcoming
end

function PhenomenonController:GetInfo(id)
	return self.Registry[id]
end

function PhenomenonController:IsDiscovered(id)
	local DiscoveryManager = Mince:Get("DiscoveryManager")
	if not DiscoveryManager then return false end

	local info = self.Registry[id]
	if not info then return false end

	local scanId = info.ScanId
	if not scanId or scanId == "" then return true end

	local types = {"Vertebrates", "Invertebrates", "Corals and Plants"}
	for _, discoveryType in ipairs(types) do
		if DiscoveryManager:HasDiscovered(discoveryType, scanId) then
			return true
		end
	end

	return false
end

function PhenomenonController:GetDisplayName(id)
	local info = self.Registry[id]
	if not info then return "Unknown" end

	if self:IsDiscovered(id) then
		return info.Name
	end

	return "*Unknown*"
end

return PhenomenonController
