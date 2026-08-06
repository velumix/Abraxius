local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local ModifierUtils = require(ServerScriptService.Modules:WaitForChild("ModifierUtils"))
local PaintMutationEffects = require(ServerScriptService.Modules:WaitForChild("PaintMutationEffects"))

local PaintMutationService = Knit.CreateService({
	Name = "PaintMutationService",
	Client = {
		StateChanged = Knit.CreateSignal(),
		Notify = Knit.CreateSignal(),
	},
})

local active = {
	running = false,
	thread = nil,
	currentEffect = nil,
	nextTickAt = nil,
	endsAt = nil,
}

local CONFIG = {
	interval = 20,
	duration = 120,
}

local charAddedConns = {}

local function buildState()
	return {
		active = active.running,
		effect = active.currentEffect,
		nextTickAt = active.nextTickAt,
		endsAt = active.endsAt,
	}
end

function PaintMutationService:_broadcast()
	self.Client.StateChanged:FireAll(buildState())
end

function PaintMutationService:_applyToPlayer(player: Player)
	if not active.running or not active.currentEffect then
		return
	end
	local ok, err = pcall(function()
		PaintMutationEffects.apply(player, active.currentEffect)
	end)
	if not ok then
		warn(`[PaintMutationService] failed to apply {active.currentEffect} to {player.Name}: {err}`)
	end
end

function PaintMutationService:_watchCharacter(player: Player)
	if charAddedConns[player] then
		return
	end
	charAddedConns[player] = player.CharacterAdded:Connect(function()
		if active.running and active.currentEffect then
			task.wait(0.2)
			self:_applyToPlayer(player)
		end
	end)
end

function PaintMutationService:_cleanupConnections()
	for _, conn in pairs(charAddedConns) do
		conn:Disconnect()
	end
	table.clear(charAddedConns)
end

function PaintMutationService:_applyRandomEffect()
	local effectName = PaintMutationEffects.getRandomEffectName(active.currentEffect)
	active.currentEffect = effectName
	active.nextTickAt = os.clock() + CONFIG.interval

	print(`[PaintMutationService] rolling effect: {effectName}`)

	local appliedCount = 0
	ModifierUtils.forEachPlayerInRound(function(player)
		appliedCount += 1
		self:_applyToPlayer(player)
		self:_watchCharacter(player)
	end)

	print(`[PaintMutationService] applied {effectName} to {appliedCount} player(s)`)

	self.Client.Notify:FireAll({
		effect = effectName,
		nextTickAt = active.nextTickAt,
		endsAt = active.endsAt,
	})

	self:_broadcast()
end

function PaintMutationService:_resetAll()
	PaintMutationEffects.resetAll()
	active.currentEffect = nil
end

function PaintMutationService:Start(duration: number?): (boolean, string)
	if not ModifierUtils.anyInRound() then
		return false, "No active match."
	end

	if active.running then
		self:Clear()
	end

	self:_cleanupConnections()

	active.running = true
	active.endsAt = os.clock() + (duration or CONFIG.duration)

	self:_applyRandomEffect()

	active.thread = task.spawn(function()
		while active.running do
			local waitTime = math.max(0, active.nextTickAt - os.clock())
			task.wait(waitTime)
			if not active.running then
				break
			end
			print("[PaintMutationService] tick: resetting and re-rolling effect")
			self:_resetAll()
			self:_applyRandomEffect()

			if active.endsAt and os.clock() >= active.endsAt then
				self:Clear()
				break
			end
		end
	end)

	return true, "Paint Mutation started."
end

function PaintMutationService:Clear()
	active.running = false
	if active.thread then
		task.cancel(active.thread)
		active.thread = nil
	end
	self:_resetAll()
	self:_cleanupConnections()
	active.currentEffect = nil
	active.nextTickAt = nil
	active.endsAt = nil
	self:_broadcast()
end

Players.PlayerRemoving:Connect(function(player)
	if charAddedConns[player] then
		charAddedConns[player]:Disconnect()
		charAddedConns[player] = nil
	end
end)

return PaintMutationService
