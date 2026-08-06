local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local ModifierUtils = require(ServerScriptService.Modules:WaitForChild("ModifierUtils"))

local ModifierService = Knit.CreateService({
	Name = "ModifierService",
	Client = {
		StateChanged = Knit.CreateSignal(),
		Countdown = Knit.CreateSignal(),
	},
})

local active = {}
local tickThreads = {}

local function buildState()
	local list = {}
	for id, mod in pairs(active) do
		table.insert(list, {
			id = id,
			name = mod.name,
			startedAt = mod.startedAt,
			endsAt = mod.endsAt,
			nextTickAt = mod.nextTickAt,
			meta = mod.meta or {},
		})
	end
	return list
end

function ModifierService:_broadcast()
	self.Client.StateChanged:FireAll(buildState())
end

function ModifierService:Start(id: string, name: string, options: { [string]: any }?): (boolean, string)
	if not ModifierUtils.anyInRound() then
		return false, "No active match."
	end

	options = options or {}
	if active[id] then
		self:Stop(id)
	end

	local now = os.clock()
	local entry = {
		id = id,
		name = name,
		startedAt = now,
		endsAt = options.duration and (now + options.duration) or nil,
		nextTickAt = options.tickInterval and (now + options.tickInterval) or nil,
		tickInterval = options.tickInterval,
		onStart = options.onStart,
		onTick = options.onTick,
		onStop = options.onStop,
		meta = options.meta or {},
	}
	active[id] = entry

	if entry.onStart then
		local ok, err = pcall(entry.onStart)
		if not ok then
			warn(`[ModifierService] onStart failed for {id}: {err}`)
		end
	end

	if entry.onTick then
		local ok, err = pcall(entry.onTick)
		if not ok then
			warn(`[ModifierService] onTick failed for {id}: {err}`)
		end
	end

	if entry.tickInterval and entry.onTick then
		tickThreads[id] = task.spawn(function()
			while active[id] do
				local waitTime = entry.tickInterval
				if active[id].nextTickAt then
					waitTime = math.max(0, active[id].nextTickAt - os.clock())
				end
				task.wait(waitTime)
				if not active[id] then
					break
				end
				local ok, err = pcall(entry.onTick)
				if not ok then
					warn(`[ModifierService] onTick failed for {id}: {err}`)
				end
				active[id].nextTickAt = os.clock() + entry.tickInterval
				self:_broadcast()
			end
		end)
	end

	self:_broadcast()
	return true
end

function ModifierService:Stop(id: string): boolean
	local entry = active[id]
	if not entry then
		return false
	end
	active[id] = nil
	tickThreads[id] = nil
	if entry.onStop then
		local ok, err = pcall(entry.onStop)
		if not ok then
			warn(`[ModifierService] onStop failed for {id}: {err}`)
		end
	end
	self:_broadcast()
	return true
end

function ModifierService:IsActive(id: string): boolean
	return active[id] ~= nil
end

function ModifierService:GetActive()
	local list = {}
	for _, mod in pairs(active) do
		table.insert(list, mod)
	end
	return list
end

function ModifierService:GetModifier(id: string)
	return active[id]
end

function ModifierService:SetMeta(id: string, meta: { [string]: any })
	local entry = active[id]
	if not entry then
		return
	end
	entry.meta = meta
	self:_broadcast()
end

function ModifierService:Clear()
	local ids = {}
	for id in pairs(active) do
		table.insert(ids, id)
	end
	for _, id in ipairs(ids) do
		self:Stop(id)
	end
end

function ModifierService:KnitStart()
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local expired = {}
		for id, mod in pairs(active) do
			if mod.endsAt and now >= mod.endsAt then
				table.insert(expired, id)
			end
		end
		for _, id in ipairs(expired) do
			self:Stop(id)
		end
	end)
end

return ModifierService
