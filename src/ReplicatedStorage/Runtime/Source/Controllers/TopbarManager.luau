local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules

local Topbar = require(Modules.Topbar)

local TopbarManager = {}

function TopbarManager:AddButton(Name)
	if not Name then
		warn("No Name provided for Topbar Button")
		return
	end
	local button = Topbar.new()
	button:setLabel(Name)
	return button
end

return TopbarManager
