
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage.Packages

local Component = require(Packages.Component)

local Components = script.Components
local Services = script.Services

for _, component in Components:GetDescendants() do
	if component:IsA("ModuleScript") then
		require(component)
	end
end

for _, service in Services:GetDescendants() do
	if service:IsA("ModuleScript") then
		local module = require(service)
		if module["Initialize"] then
			module:Initialize()
		end
	end
end