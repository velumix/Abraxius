local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local LockBackpack = Remotes:FindFirstChild("LockBackpack")
if not LockBackpack then
	LockBackpack = Instance.new("RemoteEvent")
	LockBackpack.Name = "LockBackpack"
	LockBackpack.Parent = Remotes
end

local TOOL_NAME = "Paintball Gun"
local TOOL_FOLDER = (function()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	return assets and assets:FindFirstChild("Painballs")
end)()

local PaintballGunGiver = {}

local function getTemplate(): Tool
	if TOOL_FOLDER then
		local tools = TOOL_FOLDER:GetChildren()
		local candidates = {}
		for _, child in ipairs(tools) do
			if child:IsA("Tool") then
				table.insert(candidates, child)
			end
		end
		if #candidates > 0 then
			return candidates[math.random(1, #candidates)] :: Tool
		end
	end

	local tool = Instance.new("Tool")
	tool.Name = TOOL_NAME
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = "Paintball Gun"

	local handle: Part = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1, 1, 3)
	handle.Color = Color3.fromRGB(80, 80, 80)
	handle.Material = Enum.Material.SmoothPlastic
	handle.Anchored = false
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Parent = tool

	local muzzle: Attachment = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = Vector3.new(0, 0, -handle.Size.Z / 2)
	muzzle.Parent = handle

	tool.Parent = TOOL_FOLDER or ReplicatedStorage

	return tool
end

function PaintballGunGiver.StripGuns(player: Player)
	local function strip(container: Instance?)
		if not container then
			return
		end
		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("Tool") and child.Name == TOOL_NAME then
				child:Destroy()
			end
		end
	end

	strip(player:FindFirstChildOfClass("Backpack"))
	strip(player.Character)

	-- Unlock the backpack so normal tools/hotbar are available again.
	pcall(function()
		LockBackpack:FireClient(player, false)
	end)
end

function PaintballGunGiver.GiveGun(player: Player): Tool?
	if not player or not player.Parent then
		return nil
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return nil
	end

	PaintballGunGiver.StripGuns(player)

	local template = getTemplate()
	local clone: Tool = template:Clone()
	clone.Name = TOOL_NAME
	clone.Parent = backpack

	CollectionService:AddTag(clone, "Paintball")

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:EquipTool(clone)
	end

	-- Lock the backpack so the paintball gun stays equipped like the seeker knife.
	pcall(function()
		LockBackpack:FireClient(player, true)
	end)

	return clone
end

function PaintballGunGiver.StripSeekerKnife(player: Player)
	local function strip(container: Instance?)
		if not container then
			return
		end
		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("Tool") and child.Name == "SeekerKnife" then
				child:Destroy()
			end
		end
	end

	strip(player:FindFirstChildOfClass("Backpack"))
	strip(player.Character)
end

return PaintballGunGiver
