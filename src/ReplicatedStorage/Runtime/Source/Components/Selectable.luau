local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules
local Assets = ReplicatedStorage.Assets

local Encyclopedia = Assets.Encyclopedia

local Mince = require(Modules.Mince)

local SelectionController = Mince:Get("SelectionController")

local Selectable = Mince.Component({
	Tag = "Selectable",
})

local function GetModule(self)
	if not self.Model then
		return nil
	end

	for _, Module in Encyclopedia:GetDescendants() do
		if Module.Name == self.Model.Name and Module:IsA("ModuleScript") then
			return Module
		end
	end
end

function Selectable:Construct()
	self.Model = self.Instance.Parent :: Model
	self.Selected = false
	if not self.Model then
		return warn("Selectable tag is attached to an instance without a parent; skipping component")
	end

	self.Type = self.Instance:GetAttribute("Type")

	local Module = GetModule(self)
	if Module then
		self.Module = require(Module)
	end

	SelectionController.Track(self)
end

return Selectable
