local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local AnalyticsService = game:GetService("AnalyticsService")

local Mince = require(ReplicatedStorage.Modules.Mince)
local funnelComm = Mince:GetEvent("AnalyticsFunnel")

local AnalyticsFunnelService = {
	Name = "AnalyticsFunnelService",
}

local ONBOARDING_STEPS = {
	[1] = "Player Joined",
	[2] = "Tutorial Started",
	[3] = "Scanner Selected",
	[4] = "Locked On",
	[5] = "First Scan Complete",
	[6] = "Encyclopedia Opened",
	[7] = "Discovery Highlighted",
	[8] = "Reached Shop",
	[9] = "Starter Gear Purchased",
	[10] = "Reached Dive Door",
	[11] = "Tutorial Completed",
}

local function logOnboardingStep(player, stepNumber)
	local stepName = ONBOARDING_STEPS[stepNumber]
	if not stepName then
		return
	end

	if RunService:IsStudio() then
		return
	end

	AnalyticsService:LogOnboardingFunnelStepEvent(player, stepNumber, stepName)
end

function AnalyticsFunnelService:Setup()

	self.OnboardingStepEvent = funnelComm:Extend("OnboardingStep")

	self.OnboardingStepEvent.Event:Connect(function(player, stepNumber)
		print("Received step payload", player and player.Name or "Unknown", stepNumber)
		local step = tonumber(stepNumber)
		if not step then
			print("invalid step payload")
			return
		end

		if step < 1 or step > #ONBOARDING_STEPS then
			print("Ignored out-of-range step", step)
			return
		end

		logOnboardingStep(player, step)
	end)

	Players.PlayerAdded:Connect(function(player)
		logOnboardingStep(player, 1)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		logOnboardingStep(player, 1)
	end
end

return AnalyticsFunnelService
