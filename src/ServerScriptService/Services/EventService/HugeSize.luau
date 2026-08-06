local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local ModifierUtils = require(ServerScriptService.Modules.ModifierUtils)
local RoundGatedEffect = require(script.Parent.Utilities.RoundGatedEffect)

local EVENT_NAME = "HugeSize"
local DEFAULT_SCALE = 2

local SCALE_OBJECTS = { "BodyDepthScale", "BodyHeightScale", "BodyWidthScale", "HeadScale" }

local function scaleCharacter(character: Model, scale: number)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	for _, objectName in ipairs(SCALE_OBJECTS) do
		local scaleValue = humanoid:FindFirstChild(objectName)
		if scaleValue and scaleValue:IsA("NumberValue") then
			scaleValue.Value = scale
		end
	end
end

local function setPlayerScale(player: Player, scale: number)
	player:SetAttribute("HugeSizeScale", scale)
	if player.Character then
		scaleCharacter(player.Character, scale)
	end
end

return {
	Duration = 60,

	Activate = function(context)
		local scale = context.Config and context.Config.scale
		scale = tonumber(scale) or DEFAULT_SCALE
		scale = math.clamp(scale, 0.5, 5)

		print(`[HugeSize] Activating at {scale}x`)

		local function applyToInRound()
			ModifierUtils.forEachPlayerInRound(function(player: Player)
				setPlayerScale(player, scale)
			end)
		end

		local function onPlayerAdded(player: Player)
			context.trove:Add(player.CharacterAdded:Connect(function(character: Model)
				task.delay(0.25, function()
					if ModifierUtils.inRound(player) then
						scaleCharacter(character, scale)
					end
				end)
			end))
			if player.Character then
				task.delay(0.25, function()
					if ModifierUtils.inRound(player) then
						scaleCharacter(player.Character, scale)
					end
				end)
			end
		end

		-- Apply once the round is live (and re-apply if the round resumes after a reset).
		RoundGatedEffect.Bind(context, applyToInRound)

		-- Also catch anyone already in a live round when the event starts.
		if ModifierUtils.anyInRound() then
			applyToInRound()
		end

		-- Catch respawns and late joiners while the event is active.
		context.trove:Add(Players.PlayerAdded:Connect(onPlayerAdded))
		for _, player in ipairs(Players:GetPlayers()) do
			onPlayerAdded(player)
		end

		-- Reset everyone back to normal size when the event ends.
		context.trove:Add(function()
			print("[HugeSize] Deactivating; resetting sizes")
			for _, player in ipairs(Players:GetPlayers()) do
				setPlayerScale(player, 1)
			end
		end)
	end,
}
