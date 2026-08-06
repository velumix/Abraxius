local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Icon = require(ReplicatedStorage.Packages.Icon)

local AdminSeekerController = Knit.CreateController({
	Name = "AdminSeekerController",
})

local ABILITIES = {
	{ id = "PaintStomp", name = "Stomp", order = 1 },
	{ id = "RevealRoar", name = "Roar", order = 2 },
	{ id = "SpeedBoost", name = "Boost", order = 3 },
}

local icons = {}

local function sendNotification(data)
	task.defer(function()
		pcall(function()
			StarterGui:SetCore("SendNotification", {
				Title = data.title or "ADMIN SEEKER",
				Text = data.text or "",
				Duration = data.duration or 5,
			})
		end)
	end)
end

local function clearIcons()
	for _, icon in ipairs(icons) do
		if icon then
			icon:destroy()
		end
	end
	table.clear(icons)
end

function AdminSeekerController:KnitInit() end

function AdminSeekerController:KnitStart()
	self.adminSeekerService = Knit.GetService("AdminSeekerService")

	self.adminSeekerService.Notify:Connect(function(data)
		if type(data) ~= "table" then
			return
		end

		if data.title or data.text then
			sendNotification(data)
		end

		if data.show == true then
			clearIcons()
			for _, ability in ipairs(ABILITIES) do
				local icon = Icon.new()
				icon:setLabel(ability.name)
				icon:setRight()
				icon:setOrder(ability.order)
				icon:oneClick(true)
				icon:setCaption(ability.name)
				icon.selected:Connect(function()
					self.adminSeekerService.UseAbility:Fire(ability.id)
				end)
				table.insert(icons, icon)
			end
		elseif data.show == false then
			clearIcons()
		end
	end)
end

return AdminSeekerController
