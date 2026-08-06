local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local StudsConverter = require(ServerStorage:WaitForChild("StudsConverter"))
local Constants = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Constants"))
local RIG_TYPE = Constants.RIG_TYPE

local PaintService = Knit.CreateService({
	Name = "PaintService",
	Client = {
		PaintSplashed = Knit.CreateSignal(),
	},
})

local R15_LIMB_GROUPS = {}
do
	local function group(...)
		local parts = { ... }
		for _, name in ipairs(parts) do
			R15_LIMB_GROUPS[name] = parts
		end
	end
	group("RightUpperArm", "RightLowerArm", "RightHand")
	group("LeftUpperArm", "LeftLowerArm", "LeftHand")
	group("RightUpperLeg", "RightLowerLeg", "RightFoot")
	group("LeftUpperLeg", "LeftLowerLeg", "LeftFoot")
	group("UpperTorso", "LowerTorso")
end

local painting = {}
local locked = {}

local function isOnMapPaintable(player)
	local char = player.Character
	if not char then return false end
	return StudsConverter.isConverted(char)
end

function PaintService.Client:SetPainting(player, enable)
	if typeof(enable) ~= "boolean" then return end
	if enable and not isOnMapPaintable(player) then return end
	painting[player] = enable and true or nil
end

function PaintService.Client:SetLocked(player, enable)
	if typeof(enable) ~= "boolean" then return end
	if enable and not isOnMapPaintable(player) then return end
	locked[player] = enable and true or nil
end

function PaintService.Client:PaintPart(player, targetPart, color)
	if not painting[player] then return end
	if typeof(color) ~= "Color3" then return end
	if typeof(targetPart) ~= "Instance" or not targetPart:IsA("BasePart") then return end

	local char = player.Character
	if not char then return end
	if not targetPart:IsDescendantOf(char) then return end

	local group = (RIG_TYPE == "R15") and R15_LIMB_GROUPS[targetPart.Name]
	if group then
		for _, partName in ipairs(group) do
			local limb = char:FindFirstChild(partName)
			if limb and limb:IsA("BasePart") then
				StudsConverter.paintPart(limb, color)
				PaintService.Client.PaintSplashed:FireAll(limb, color, 12)
			end
		end
	else
		StudsConverter.paintPart(targetPart, color)
		PaintService.Client.PaintSplashed:FireAll(targetPart, color, 18)
	end
end

function PaintService.Client:PaintBody(player, color)
	if not painting[player] then return end
	if typeof(color) ~= "Color3" then return end
	if not isOnMapPaintable(player) then return end

	local char = player.Character
	if not char then return end
	StudsConverter.paintAll(char, color)

	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		PaintService.Client.PaintSplashed:FireAll(hrp, color, 45)
	end
end

Players.PlayerRemoving:Connect(function(player)
	painting[player] = nil
	locked[player] = nil
end)

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		painting[player] = nil
		locked[player] = nil
	end)
end)

return PaintService
