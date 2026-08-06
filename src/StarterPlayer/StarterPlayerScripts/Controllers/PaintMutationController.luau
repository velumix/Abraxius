local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Icon = require(ReplicatedStorage.Packages.Icon)

local PaintMutationController = Knit.CreateController({
	Name = "PaintMutationController",
})

local EFFECT_NAMES = {
	BigHead = "Big Head",
	TinyBody = "Tiny Body",
	LowGravity = "Low Gravity",
	SuperJump = "Super Jump",
	ForcedBrightColor = "Forced Bright Color",
}

local latestState = {}
local icon = nil

local function formatEffectName(effect: string): string
	return EFFECT_NAMES[effect] or (effect or "NONE")
end

function PaintMutationController:KnitInit() end

function PaintMutationController:KnitStart()
	local service = Knit.GetService("PaintMutationService")

	service.StateChanged:Connect(function(state)
		latestState = state or {}
		if not latestState.active then
			if icon then
				icon:destroy()
				icon = nil
			end
			return
		end
		if not icon then
			icon = Icon.new()
			icon:setLabel("MUTATION")
			icon:setCaption("Paint Mutation")
			icon:setRight()
			icon:setOrder(20)
		end
	end)

	RunService.RenderStepped:Connect(function()
		if not icon or not latestState.active then
			return
		end
		local effect = latestState.effect or "NONE"
		local nextIn = latestState.nextTickAt and math.max(0, math.floor(latestState.nextTickAt - os.clock())) or 0
		icon:setLabel(string.format("%s | %ds", formatEffectName(effect), nextIn))
		icon:setCaption("Paint Mutation")
	end)
end

return PaintMutationController
