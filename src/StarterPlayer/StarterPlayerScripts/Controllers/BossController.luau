local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HapticService = game:GetService("HapticService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local CameraShaker = require(ReplicatedStorage.Packages.CameraShaker)

local BossController = Knit.CreateController({
	Name = "BossController",
})

local camShake = nil

type HpBarElements = {
	gui: ScreenGui,
	holder: GuiObject?,
	nameLabel: TextLabel?,
	healthLabel: TextLabel?,
	fill: Frame?,
}

local bossBar: HpBarElements? = nil

local function escapeRich(s: string): string
	s = tostring(s)
	s = s:gsub("&", "&amp;")
	s = s:gsub("<", "&lt;")
	s = s:gsub(">", "&gt;")
	return s
end

local function getBarElements(screenGuiName: string): HpBarElements?
	local player = Players.LocalPlayer
	local playerGui = player and player:FindFirstChild("PlayerGui")
	if not playerGui then
		return nil
	end

	local gui = playerGui:FindFirstChild("Hud") :: ScreenGui?
	if not gui then
		gui = playerGui:FindFirstChild(screenGuiName) :: ScreenGui?
		if not gui then
			return nil
		end
	end

	local main = gui:FindFirstChild("Main")
	local top = main and main:FindFirstChild("Top")
	local holder = (top and top:FindFirstChild("PaintBossHPBarHolder")) or gui:FindFirstChild("PaintBossHPBarHolder")
	local nameLabel = holder and holder:FindFirstChild("NameLabel") :: TextLabel?
	local healthLabel = holder and holder:FindFirstChild("HealthLabel") :: TextLabel?
	local fill = holder and holder:FindFirstChild("Bar") :: Frame?

	return {
		gui = gui,
		holder = holder :: GuiObject?,
		nameLabel = nameLabel,
		healthLabel = healthLabel,
		fill = fill,
	}
end

local function getBossBar(): HpBarElements?
	if bossBar then
		return bossBar
	end
	bossBar = getBarElements("PaintBossHPBar")
	if bossBar then
		if bossBar.holder then
			bossBar.holder.Visible = false
		end
	end
	return bossBar
end

local function hideAllHpBars()
	local bar = getBossBar()
	if bar and bar.holder then
		bar.holder.Visible = false
	end
end

function BossController:KnitStart()
	local service = Knit.GetService("BossService")
	local notificationController = Knit.GetController("NotificationController")

	camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value + 1, function(shakeCf: CFrame)
		local camera = Workspace.CurrentCamera
		if camera then
			camera.CFrame *= shakeCf
		end
	end)
	camShake:Start()

	service.SlamImpact:Connect(function(slamPos: Vector3)
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local dist = (root.Position - slamPos).Magnitude
			if dist > 25 then
				return
			end
		end

		if camShake then
			camShake:Shake(CameraShaker.Presets.Explosion)
		end

		-- Mobile (touch) and gamepad haptics.
		local motors = {
			{ Enum.UserInputType.Touch, Enum.VibrationMotor.Large },
			{ Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Large },
		}
		for _, motor in ipairs(motors) do
			local inputType, motorType = motor[1], motor[2]
			if HapticService:IsMotorSupported(inputType, motorType) then
				HapticService:SetMotor(inputType, motorType, 0.8)
				task.delay(0.2, function()
					HapticService:SetMotor(inputType, motorType, 0)
				end)
			end
		end
	end)

	-- Combined boss + minion HP bar shown at all times during the event.
	local function updateCombinedHpBar(data)
		local bar = getBossBar()
		if not bar then
			return
		end
		local health = math.floor(tonumber(data.health) or 0)
		local maxHealth = math.floor(tonumber(data.maxHealth) or 1)
		if bar.nameLabel then
			bar.nameLabel.Text = "Paint Boss & Minions"
		end
		if bar.healthLabel then
			bar.healthLabel.Text = string.format("%d / %d", health, maxHealth)
		end
		if bar.fill then
			local ratio = if maxHealth > 0 then health / maxHealth else 0
			bar.fill.Size = UDim2.new(math.clamp(ratio, 0, 1), 0, 1, 0)
			if ratio <= 0.25 then
				bar.fill.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
			end
		end
		if bar.holder then
			bar.holder.Visible = health > 0
		end
	end
	service.BossHealthChanged:Connect(updateCombinedHpBar)

	-- Hide the bar when the event ends.
	service.BossEventEnded:Connect(hideAllHpBars)

	-- Make sure the bar starts hidden once the UI is available.
	task.spawn(function()
		local player = Players.LocalPlayer
		local playerGui = player:WaitForChild("PlayerGui")
		local hud = playerGui:WaitForChild("Hud") :: ScreenGui
		local main = hud:WaitForChild("Main")
		local top = main:WaitForChild("Top")
		local bossHolder = top:WaitForChild("PaintBossHPBarHolder") :: GuiObject
		if bossHolder then
			bossHolder.Visible = false
		end
		local minionGui = playerGui:FindFirstChild("PaintMinionHPBar") :: ScreenGui?
		if minionGui then
			minionGui.Enabled = false
		end
	end)

	if notificationController then
		service.BossSpawned:Connect(function(data)
			-- Minions spawn right after the boss; don't spam a banner for each one.
			if data.behavior == "minion" then
				return
			end
			notificationController:Notify({
				text = data.displayName .. " Spawned",
				rich = `<b><font color="#FF5A5A">{escapeRich(data.displayName)} Spawned</font></b><br/><font color="#FFFFFF">Defeat the boss!</font>`,
				Duration = 5,
			})
		end)

		service.BossDied:Connect(function(data)
			-- Minions dying during the Painting Boss event were spamming "Boss Defeated".
			-- Only show the banner for actual bosses.
			if data.behavior == "minion" then
				return
			end
			notificationController:Notify({
				text = "Boss Defeated",
				rich = `<b><font color="#5AFF5A">Boss Defeated</font></b><br/><font color="#FFFFFF">{escapeRich(data.name or "")}</font>`,
				Duration = 5,
			})
		end)
	end
end

return BossController
