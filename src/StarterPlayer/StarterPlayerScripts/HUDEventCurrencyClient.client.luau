local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local hud = playerGui:WaitForChild("Hud")
local currency = hud:FindFirstChild("EventCurrency")

if currency and currency:IsA("GuiObject") then
	currency.Visible = false
end
