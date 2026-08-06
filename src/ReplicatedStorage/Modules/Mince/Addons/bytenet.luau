--[[
	Typed, buffer-backed networking for Mince.

	Packet definitions must be shared by the server and client. Define them once
	in a ReplicatedStorage module, then call Mince:DefinePackets from both
	runtimes before sending or listening.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Modules = script.Parent.Parent.Parent
local ByteNet = require(Modules.ByteNet)

type PacketDefinition = {
	Value: any?,
	Reliability: ("reliable" | "unreliable")?,
	CallbackBehavior: {
		spawnThread: boolean,
		allowMultiple: boolean,
	}?,
	value: any?,
	reliabilityType: ("reliable" | "unreliable")?,
	callbackBehavior: {
		spawnThread: boolean,
		allowMultiple: boolean,
	}?,
}

local Namespaces: { [string]: { [string]: any } } = {}
local NamespaceDefinitions: { [string]: (any) -> { [string]: PacketDefinition } } = {}

local function normalizeDefinition(packetName: string, definition: PacketDefinition)
	assert(type(definition) == "table", `Packet '{packetName}' must have a definition table.`)

	local value = definition.Value
	if value == nil then
		value = definition.value
	end

	assert(value ~= nil, `Packet '{packetName}' is missing Value.`)

	local reliability = definition.Reliability or definition.reliabilityType
	assert(
		reliability == nil or reliability == "reliable" or reliability == "unreliable",
		`Packet '{packetName}' Reliability must be 'reliable' or 'unreliable'.`
	)

	return ByteNet.definePacket({
		value = value,
		reliabilityType = reliability,
		callbackBehavior = definition.CallbackBehavior or definition.callbackBehavior,
	})
end

local function definePackets(_self, namespaceName: string, define: (any) -> { [string]: PacketDefinition })
	assert(type(namespaceName) == "string" and namespaceName ~= "", "Namespace name must be a non-empty string.")
	assert(type(define) == "function", "Packet definitions must be provided by a schema function.")

	local existing = Namespaces[namespaceName]
	if existing then
		assert(
			NamespaceDefinitions[namespaceName] == define,
			`ByteNet namespace '{namespaceName}' was already defined with a different schema function.`
		)
		return existing
	end

	if RunService:IsClient() then
		local storage = ReplicatedStorage:WaitForChild("BytenetStorage")
		assert(
			storage:WaitForChild(namespaceName, 10),
			`Timed out waiting for the server to define ByteNet namespace '{namespaceName}'.`
		)
	end

	local namespace = ByteNet.defineNamespace(namespaceName, function()
		local definitions = define(ByteNet)
		assert(
			type(definitions) == "table" and next(definitions) ~= nil,
			"Packet schema must return a non-empty table."
		)

		local packetNames = {}
		for packetName in definitions do
			assert(type(packetName) == "string" and packetName ~= "", "Packet names must be non-empty strings.")
			table.insert(packetNames, packetName)
		end
		table.sort(packetNames)

		local packets = {}
		for _, packetName in packetNames do
			packets[packetName] = normalizeDefinition(packetName, definitions[packetName])
		end
		return packets
	end)

	Namespaces[namespaceName] = namespace
	NamespaceDefinitions[namespaceName] = define
	return namespace
end

local function getPacket(_self, namespaceName: string, packetName: string)
	local namespace = Namespaces[namespaceName]
	assert(namespace, `ByteNet namespace '{namespaceName}' has not been defined.`)

	local packet = namespace[packetName]
	assert(packet, `Packet '{packetName}' does not exist in namespace '{namespaceName}'.`)
	return packet
end

local function getByteNet()
	return ByteNet
end

local Shared = {
	DefinePackets = definePackets,
	GetPacket = getPacket,
	GetByteNet = getByteNet,
}

return {
	Client = Shared,
	Server = Shared,
}
