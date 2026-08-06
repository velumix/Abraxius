local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Mince = require(ReplicatedStorage.Modules.Mince)
local Component = Mince.Component

local Assets = ReplicatedStorage.Assets

local ItemGiverService = {Name = "ItemGiverService"}
ItemGiverService.Items = {}

local ItemGiver = Component{Tag = "ItemGiver"}

function ItemGiverService:Setup()
end

function ItemGiverService:GameStart()
	self.DrinkService = Mince:Get("DrinkService")
end

function ItemGiver:Construct()
	ItemGiverService.Items[self.Instance] = self
	self:SetupClickDetector()
end

function ItemGiver:SetupClickDetector()
	local Mesh = self.Instance

	local clickDetector = Mesh:FindFirstChildOfClass("ClickDetector")
	if not clickDetector then
		clickDetector = Instance.new("ClickDetector")
		clickDetector.MaxActivationDistance = 10
		clickDetector.Parent = Mesh
	end

	self:SetupHighlight(clickDetector)

	self.ClickConnection = clickDetector.MouseClick:Connect(function(player)
		self:GiveToolToPlayer(player)
	end)
end

function ItemGiver:SetupHighlight(clickDetector)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(45, 180, 220)
	highlight.OutlineColor = Color3.fromRGB(65, 200, 240)
	highlight.FillTransparency = 0.5
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Enabled = false
	highlight.Parent = self.Instance

	self.Highlight = highlight

	-- Show highlight on hover
	self.HoverEnterConnection = clickDetector.MouseHoverEnter:Connect(function()
		highlight.Enabled = true
	end)

	self.HoverLeaveConnection = clickDetector.MouseHoverLeave:Connect(function()
		highlight.Enabled = false
	end)
end

function ItemGiver:GiveToolToPlayer(player)
	local backpack = player:FindFirstChild("Backpack")

	if not backpack then
		warn("Player has no backpack")
		return
	end

	local Tool = Assets:FindFirstChild(self.Instance.Name, true)

	if not Tool then
		warn("Tool not found in Assets")
		return
	end

	local toolCopy = Tool:Clone()

	toolCopy.Parent = backpack
	ItemGiverService.DrinkService.ShowError:Fire(player, "You picked up: " .. toolCopy.Name)
end

function ItemGiver:Stop()
	ItemGiverService.Items[self.Instance] = nil
	if self.ClickConnection then
		self.ClickConnection:Disconnect()
		self.ClickConnection = nil
	end
	if self.HoverEnterConnection then
		self.HoverEnterConnection:Disconnect()
		self.HoverEnterConnection = nil
	end
	if self.HoverLeaveConnection then
		self.HoverLeaveConnection:Disconnect()
		self.HoverLeaveConnection = nil
	end
	if self.Highlight then
		self.Highlight:Destroy()
		self.Highlight = nil
	end
end

return ItemGiverService