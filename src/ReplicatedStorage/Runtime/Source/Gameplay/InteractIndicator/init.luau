-- Modules // Services --
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService('TweenService')
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer 

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Maid = require(ReplicatedStorage.Modules.Maid)
local Mince = require(ReplicatedStorage.Modules.Mince)

local UpdateStream = Mince:Get("UpdateStream")
local RadarTemplate = script:FindFirstChild("Radar")
local warnedMissingRadar = false

local InteractIndicator =  {
	MaxVerticalHeight = 8,
	TweenInfos = {
		OpenQuick = TweenInfo.new(0.3, Enum.EasingStyle.Back),
		CloseRadial = TweenInfo.new(0.7, Enum.EasingStyle.Quint), 
		Loop = TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1)
	}  
} 

InteractIndicator.__index = InteractIndicator

function InteractIndicator.new(...) 
	local self = setmetatable({}, InteractIndicator) 
	self:Init(...) 
	return self 
end

function InteractIndicator:Init(BasePart) 
	self.ProximityPrompt = Instance.new("ProximityPrompt") :: ProximityPrompt
	self.RadarTemplate = RadarTemplate
	if self.RadarTemplate then
		self.ProximityPrompt.Style = Enum.ProximityPromptStyle.Custom
	else
		self.ProximityPrompt.Style = Enum.ProximityPromptStyle.Default
		if not warnedMissingRadar then
			warnedMissingRadar = true
			warn("InteractIndicator missing Radar template; default Roblox prompt UI will be used.")
		end
	end
	self.ProximityPrompt:SetAttribute("Type","Interact")
	self.ProximityPrompt.HoldDuration = 0.2
	self.ProximityPrompt.Parent = BasePart

	self.ProximityPrompt.PromptHidden:Connect(function()
		self.Disabled = false
		if self.InRange then
			self:Start(true)
		end
	end)
	self.ProximityPrompt.PromptShown:Connect(function()
		self.Disabled = true
		self:Stop(true)
	end)

	self.Maid = Maid.new()
	self.BasePart = BasePart
	self.IsRunning = false

	UpdateStream:Register(self, BasePart)
end

function InteractIndicator:Update(DeltaTime)
	if self.Disabled then return end

	if self.InRange and not self.IsRunning then
		if Mince.HumanoidRootPart then 
			local Distance = ((Mince.HumanoidRootPart.Position * Vector3.yAxis) - (self.BasePart.Position * Vector3.yAxis)).Magnitude

			if Distance < InteractIndicator.MaxVerticalHeight then 
				return self:Start(true)
			end
		end
	elseif self.InRange and self.IsRunning then 
		if Mince.HumanoidRootPart then 
			local Distance = ((Mince.HumanoidRootPart.Position * Vector3.yAxis) - (self.BasePart.Position * Vector3.yAxis)).Magnitude

			if Distance > InteractIndicator.MaxVerticalHeight then 
				return self:Stop(true)
			end
		end
	end
end


function InteractIndicator:ClearUpdate() 
	if self.UpdateEvent then self.UpdateEvent:Disconnect() self.UpdateEvent = nil  end
end

function InteractIndicator:StartUpdate() 
	self:ClearUpdate()
	self.UpdateEvent = RunService.Heartbeat:Connect(function(DeltaTime) 
		self:Update(DeltaTime) 
	end)
end

function InteractIndicator:Start(Ignore)  
	if not Ignore then self.InRange = true ; self:StartUpdate() end 
	if Mince.HumanoidRootPart then 
		local Distance = ((Mince.HumanoidRootPart.Position * Vector3.yAxis) - (self.BasePart.Position * Vector3.yAxis)).Magnitude

		if Distance > InteractIndicator.MaxVerticalHeight then
			return 
		end
	end

	if self.Disabled then return end 
	if self.IsRunning then return end
	if not self.RadarTemplate then
		return
	end
	self.IsRunning = true 

	local ThisRadar = self.RadarTemplate:Clone()
	ThisRadar.Parent = PlayerGui
	ThisRadar.Adornee = self.TargetPart or self.BasePart

	local RadialScale = ThisRadar.Container.Radial.UIScale
	local CenterScale = ThisRadar.Container.Center.UIScale 
	CenterScale.Scale = 0 
	RadialScale.Scale = 0 

	TweenService:Create(CenterScale :: UIScale, self.TweenInfos.OpenQuick, {
		Scale = 0.3
	}):Play()

	local LoopTweens : {Tween} = {} 
	table.insert(LoopTweens, TweenService:Create(RadialScale :: UIScale, self.TweenInfos.Loop, {
		Scale = 0.3,
	}))

	table.insert(LoopTweens, TweenService:Create(ThisRadar.Container.Radial, self.TweenInfos.Loop, {
		ImageTransparency = 1 
	}))

	for _, Tween : Tween in LoopTweens do Tween:Play() end

	self.Maid:Add(function()
		task.defer(function() 
			for _, Tween : Tween in LoopTweens do 
				Tween:Pause()
			end

			TweenService:Create(ThisRadar.Container.Radial, self.TweenInfos.CloseRadial, {
				ImageTransparency = 1   
			}):Play()

			TweenService:Create(CenterScale :: UIScale, self.TweenInfos.OpenQuick, {
				Scale = 0  
			}):Play()


			task.wait(3) 

			ThisRadar:Destroy()
		end) 
	end)
end

function InteractIndicator:Stop(Ignore)
	if not Ignore then self.InRange = false; self:ClearUpdate() end
	if not self.IsRunning then return end
	self.IsRunning = false
	self.Maid:Clean() 
end

return InteractIndicator