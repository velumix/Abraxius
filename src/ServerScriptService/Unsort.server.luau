
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets
local Blocks = Assets.Blocks

local Blacklisted = {"Grid", "Shape"}

for _, folder in Blocks.Categories:GetChildren() do
	for index, model in folder:GetChildren() do
		if not table.find(Blacklisted, folder.Name) then
			model.Name = folder.Name.. "_Model_".. index
		end
		
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part:SetAttribute("OriginalColor", part.Color)
			end
		end
		
		model.Parent = Blocks.SELECTABLE
	end
end
