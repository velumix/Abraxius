--!optimize 2
--!native
local packetIDs = require(script.Parent.Parent.namespaces.packetIDs)
local readRefs = require(script.Parent.readRefs)

local ref = packetIDs.ref()
local freeThread: thread?

local function functionPasser(fn, ...)
	local aquiredThread = freeThread
	freeThread = nil
	fn(...)
	freeThread = aquiredThread
end

local function yielder()
	while true do
		functionPasser(coroutine.yield())
	end
end

local function runListener(fn, ...)
	if freeThread == nil then
		freeThread = coroutine.create(yielder)
		coroutine.resume(freeThread :: thread)
	end

	task.spawn(freeThread :: thread, fn, ...)
end

return function(incomingBuffer: buffer, references: { [number]: unknown }?, player: Player?)
	local length = buffer.len(incomingBuffer)
	local readCursor = 0

	readRefs.set(references)

	while readCursor < length do
		local packetId = buffer.readu8(incomingBuffer, readCursor)
		local packet = ref[packetId]
		readCursor += 1

		if not packet then
			-- Parallel Actor VMs can receive a shared ByteNet remote before that VM
			-- has defined the packet's namespace. Its layout is unknown here, so the
			-- only safe option is to discard the rest of this coalesced buffer.
			return
		end

		local value, valueLength = packet.reader(incomingBuffer, readCursor)

		readCursor += valueLength

		for _, listener in packet.getListeners() do
			runListener(listener, value, player)
		end
	end
end
