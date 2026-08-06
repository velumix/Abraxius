local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Icon = require(ReplicatedStorage.Packages.Icon)
local UISounds = require(ReplicatedStorage:WaitForChild("UISounds"))

local AfkController = Knit.CreateController({
	Name = "AfkController",
})

local TOPBAR_ORDER = 0
local AFK_ON_COLOR = Color3.fromRGB(77, 190, 122)
local AFK_OFF_COLOR = Color3.fromRGB(235, 238, 245)
local AFK_OFF_BACKGROUND = Color3.fromRGB(18, 18, 21)
local AFK_ON_BACKGROUND = Color3.fromRGB(20, 62, 39)
local COLOR_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PRESS_TWEEN = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SETTLE_TWEEN = TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

function AfkController:KnitStart()
	local ok, err = pcall(function()
		local player = Players.LocalPlayer
		local AfkService = Knit.GetService("AfkService")

		local pg = player:WaitForChild("PlayerGui")
		local gui = pg:WaitForChild("Settings")
		local frame = gui:WaitForChild("HolderFrame"):WaitForChild("Settings")
		local scroll = frame:WaitForChild("ScrollingFrame")

		local row = scroll:FindFirstChild("Afk")
		if row and row:IsA("GuiObject") then
			row.Visible = false
			row.Size = UDim2.fromOffset(0, 0)
		end

		local syncing = false
		local renderedAfk = false
		local afkIcon = Icon.new()
		afkIcon:setName("AfkToggle")
		afkIcon:autoDeselect(false)
		afkIcon:setLabel("AFK", "Deselected")
		afkIcon:setLabel("AFK", "Selected")
		afkIcon:setCaption("AFK: Off")
		afkIcon:setOrder(TOPBAR_ORDER)
		afkIcon:align("right")
		afkIcon:modifyTheme({
			{"Widget", "MinimumWidth", 58},
			{"Widget", "DesiredWidth", 58},
			{"IconLabel", "TextSize", 15},
			{"IconLabel", "TextColor3", AFK_OFF_COLOR, "Deselected"},
			{"IconLabel", "TextColor3", AFK_ON_COLOR, "Selected"},
			{"IconButton", "BackgroundColor3", AFK_OFF_BACKGROUND, "Deselected"},
			{"IconButton", "BackgroundColor3", AFK_ON_BACKGROUND, "Selected"},
			{"IconButton", "BackgroundTransparency", 0.06, "Deselected"},
			{"IconButton", "BackgroundTransparency", 0, "Selected"},
			{"IconSpot", "BackgroundTransparency", 1, "Deselected"},
			{"IconSpot", "BackgroundTransparency", 0.88, "Selected"},
			{"IconSpot", "BackgroundColor3", AFK_ON_COLOR, "Selected"},
		})

		local widget = afkIcon:getInstance("Widget")
		local button = afkIcon:getInstance("IconButton")
		local label = afkIcon:getInstance("IconLabel")
		local spot = afkIcon:getInstance("IconSpot")
		local scale = Instance.new("UIScale")
		scale.Name = "AfkToggleScale"
		scale.Parent = widget

		local activeTweens = {}
		local function refreshAvailability()
			afkIcon:setEnabled(player:GetAttribute("InMatch") ~= true)
		end

		local function playTween(instance, tweenInfo, properties)
			local previous = activeTweens[instance]
			if previous then
				previous:Cancel()
			end

			local tween = TweenService:Create(instance, tweenInfo, properties)
			activeTweens[instance] = tween
			tween:Play()
		end

		local function animateAfkUI(isAfk)
			renderedAfk = isAfk
			playTween(button, COLOR_TWEEN, {
				BackgroundColor3 = isAfk and AFK_ON_BACKGROUND or AFK_OFF_BACKGROUND,
				BackgroundTransparency = isAfk and 0 or 0.06,
			})
			playTween(label, COLOR_TWEEN, {
				TextColor3 = isAfk and AFK_ON_COLOR or AFK_OFF_COLOR,
			})
			playTween(spot, COLOR_TWEEN, {
				BackgroundColor3 = isAfk and AFK_ON_COLOR or AFK_OFF_COLOR,
				BackgroundTransparency = isAfk and 0.88 or 1,
			})

			playTween(scale, PRESS_TWEEN, { Scale = 0.9 })
			task.delay(PRESS_TWEEN.Time, function()
				if scale.Parent then
					playTween(scale, SETTLE_TWEEN, { Scale = 1 })
				end
			end)
		end

		local function applyAfkUI(isAfk)
			if isAfk then
				afkIcon:setCaption("AFK: On")
				if not afkIcon.isSelected then
					syncing = true
					afkIcon:select("Server", afkIcon)
					syncing = false
				end
			else
				afkIcon:setCaption("AFK: Off")
				if afkIcon.isSelected then
					syncing = true
					afkIcon:deselect("Server", afkIcon)
					syncing = false
				end
			end

			if renderedAfk ~= isAfk then
				animateAfkUI(isAfk)
			end
			refreshAvailability()
		end

		applyAfkUI(false)

		-- Lobby spectators keep access during a live round. The icon disappears only after the server
		-- actually places this player into the active match.
		player:GetAttributeChangedSignal("InMatch"):Connect(refreshAvailability)
		refreshAvailability()

		afkIcon:bindEvent("selected", function()
			if syncing then return end
			UISounds.click()
			task.defer(animateAfkUI, true)
			AfkService:SetAfk(true)
		end)

		afkIcon:bindEvent("deselected", function()
			if syncing then return end
			UISounds.click()
			task.defer(animateAfkUI, false)
			AfkService:SetAfk(false)
		end)

		AfkService.AfkChanged:Connect(function(isAfk)
			applyAfkUI(isAfk)
		end)
	end)
	if not ok then
		warn("[AfkController] KnitStart failed: " .. tostring(err))
	end
end

return AfkController
