local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Mince = require(ReplicatedStorage.Modules.Mince)
local Signal = require(ReplicatedStorage.Modules.Signal)

local DiscoveryManager = {
	Name = "DiscoveryManager",
	Discoveries = {}
}

function DiscoveryManager:Setup()
	self.DiscoveryUpdated = Signal.new()

	self.DiscoveryEvent = Mince:GetEvent("DiscoverySystem")
	self.RecordDiscovery = self.DiscoveryEvent:Extend("RecordDiscovery")
	self.GetDiscoveries = self.DiscoveryEvent:Extend("GetDiscoveries")

	self.GetDiscoveries.Event:Connect(function(discoveryType, discoveries)
		self:UpdateDiscoveryType(discoveryType, discoveries)
	end)
end

export type DiscoveryType = "Vertebrates" | "Invertebrates" | "Corals and Plants" | "Artifacts" | "Locations"
export type DiscoveryName = string

function DiscoveryManager:RecordDiscovery(DiscoveryType: DiscoveryType, DiscoveryName: DiscoveryName) : boolean
	self.RecordDiscovery:Fire(DiscoveryType, DiscoveryName)
	if self.RequestDiscoveries then
		self:RequestDiscoveries(DiscoveryType)
	end
	return true
end

function DiscoveryManager:RequestDiscoveries(DiscoveryType: DiscoveryType) : {DiscoveryName}
	self.GetDiscoveries:Fire(DiscoveryType)
	return self.Discoveries[DiscoveryType] or {}
end

function DiscoveryManager:UpdateDiscoveryType(DiscoveryType: DiscoveryType, discoveries: {DiscoveryName})
	if not DiscoveryType or type(DiscoveryType) ~= "string" then
		warn("[DiscoveryManager] Invalid DiscoveryType passed to UpdateDiscoveryType:", DiscoveryType, debug.traceback())
		return {}
	end
	if discoveries == nil then
		warn("[DiscoveryManager] UpdateDiscoveryType received nil discoveries for type:", DiscoveryType)
		discoveries = {}
	end
	self.Discoveries[DiscoveryType] = discoveries

	if self.DiscoveryUpdated then
		self.DiscoveryUpdated:Fire(DiscoveryType, discoveries)
	end

	return self.Discoveries[DiscoveryType]
end

function DiscoveryManager:HasDiscovered(DiscoveryType: DiscoveryType, DiscoveryName: DiscoveryName) : boolean
	if not self.Discoveries[DiscoveryType] then
		return false
	end

	return table.find(self.Discoveries[DiscoveryType], DiscoveryName) ~= nil
end

function DiscoveryManager:GetDiscoveryTypes() : {DiscoveryType}
	local types = {}
	for discoveryType in pairs(self.Discoveries) do
		table.insert(types, discoveryType)
	end
	return types
end

function DiscoveryManager:GetDiscoveryCount(DiscoveryType: DiscoveryType) : number
	return #(self.Discoveries[DiscoveryType] or {})
end

function DiscoveryManager:ClearDiscoveries(DiscoveryType: DiscoveryType) : boolean
	if not self.Discoveries[DiscoveryType] then
		return false
	end

	self.Discoveries[DiscoveryType] = {}
	return true
end

return DiscoveryManager



