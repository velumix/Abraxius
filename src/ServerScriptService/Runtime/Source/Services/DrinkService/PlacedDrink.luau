local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage.Modules

local Mince = require(Modules.Mince)
local Component = Mince.Component

local PlacedDrink = Component{
	Tag = "PlacedDrink",
}

function PlacedDrink:Construct()
	local handle

	if self.Instance:IsA("Model") then
		handle = self.Instance.PrimaryPart or 
			self.Instance:FindFirstChild("Handle") or 
			self.Instance:FindFirstChildOfClass("Part") or 
			self.Instance:FindFirstChildOfClass("MeshPart")
	else
		handle = self.Instance:FindFirstChild("Handle") or 
			self.Instance:FindFirstChildOfClass("Part") or 
			self.Instance:FindFirstChildOfClass("MeshPart")
	end

	if handle then
		self.ClickDetector = handle:FindFirstChildOfClass("ClickDetector")

		if not self.ClickDetector then
			self.ClickDetector = Instance.new("ClickDetector")
			self.ClickDetector.MaxActivationDistance = 10
			self.ClickDetector.Parent = handle
		end

		self.Connection = self.ClickDetector.MouseClick:Connect(function(player)
			self:HandlePickup(player)
		end)
	end
end

function PlacedDrink:Stop()
	if self.Connection then
		self.Connection:Disconnect()
		self.Connection = nil
	end

	if self.ClickDetector then
		self.ClickDetector:Destroy()
		self.ClickDetector = nil
	end
end

function PlacedDrink:HandlePickup(player)
	local DrinkService = Mince:Get("DrinkService")
	DrinkService:PickupPlacedDrink(player, self.Instance)
end

return PlacedDrink
