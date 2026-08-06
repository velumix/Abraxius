local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local PaintingBossController = Knit.CreateController({
	Name = "PaintingBossController",
})

local GREEN = "70,180,95"
local RED = "220,70,70"
local WHITE = "255,255,255"
local TOP_POS = UDim2.new(0.5, 0, 0.12, 0)

local function rich(rgb: string, text: string): string
	return string.format('<font color="rgb(%s)">%s</font>', rgb, text)
end

local function escapeRich(text: any): string
	return (tostring(text or ""):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local function fmt(t: number): string
	t = math.max(0, math.floor(t or 0))
	return string.format("%d:%02d", math.floor(t / 60), t % 60)
end

function PaintingBossController:KnitStart()
	local ok, err = pcall(function()
		local player = Players.LocalPlayer
		local service = Knit.GetService("PaintingBossService")

		local pg = player:WaitForChild("PlayerGui")
		local timerGui = pg:WaitForChild("Hud")
		local holder = timerGui:WaitForChild("Main"):WaitForChild("Top"):WaitForChild("Timer")
		local announce = holder:WaitForChild("Announce")
		local timer = holder:WaitForChild("Timer")
		local hidersLabel = holder:FindFirstChild("HidersLeftLabel")

		local activeValue = timerGui:FindFirstChild("PaintingBossActive")
		if not activeValue then
			activeValue = Instance.new("BoolValue")
			activeValue.Name = "PaintingBossActive"
			activeValue.Value = false
			activeValue.Parent = timerGui
		end

		local active = false
		local endTick = nil
		local connection = nil

		local function stopLoop()
			if connection then
				connection:Disconnect()
				connection = nil
			end
			active = false
			endTick = nil
			activeValue.Value = false
			if hidersLabel then
				hidersLabel.Visible = false
			end
		end

		local function updateUI()
			if not active or not endTick then
				return
			end
			local left = math.max(0, math.ceil(endTick - tick()))
			holder.Visible = true
			holder.Position = TOP_POS
			announce.RichText = true
			announce.Text = rich(WHITE, "Defeat the ") .. rich(RED, "Paint Boss!")
			timer.RichText = true
			timer.Text = rich(RED, "Boss Event Ends In: ") .. rich(WHITE, fmt(left))
			if hidersLabel then
				hidersLabel.Visible = false
			end
		end

		local function applyState(data)
			if data and data.active then
				active = true
				local remaining = tonumber(data.remaining) or tonumber(data.duration) or 120
				endTick = tick() + remaining
				activeValue.Value = true
				updateUI()
				if not connection then
					connection = RunService.RenderStepped:Connect(updateUI)
				end
			else
				stopLoop()
			end
		end

		service.EventStateChanged:Connect(applyState)

		-- Late-join sync: if the event is already active when this controller starts,
		-- hydrate from the server's current state.
		local stateOk, currentState = pcall(function()
			return service:GetEventState()
		end)
		if stateOk then
			applyState(currentState)
		end

		local notificationController = Knit.GetController("NotificationController")
		if notificationController then
			service.EventEnded:Connect(function(data)
				local color = if data.won then GREEN else RED
				local text = tostring(data.text or "")
				notificationController:Notify({
					text = text,
					rich = string.format('<b><font color="rgb(%s)">%s</font></b>', color, escapeRich(text)),
					Duration = 8,
				})
			end)
		end
	end)
	if not ok then
		warn("[PaintingBossController] KnitStart failed: " .. tostring(err))
	end
end

return PaintingBossController
