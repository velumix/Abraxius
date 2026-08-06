local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local resetBindable = Instance.new("BindableEvent")
resetBindable.Name = "ResetButtonOverride"

resetBindable.Event:Connect(function()
	-- Reset is permanently disabled. The button press is swallowed.
end)

task.spawn(function()
	local bound = false
	repeat
		local ok = pcall(function()
			StarterGui:SetCore("ResetButtonCallback", resetBindable)
		end)
		if ok then
			bound = true
		else
			task.wait(0.2)
		end
	until bound
end)
