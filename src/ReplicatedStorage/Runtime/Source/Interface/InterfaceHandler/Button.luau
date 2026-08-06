-- Services // Modules 
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Mince = require(ReplicatedStorage.Modules.Mince)
local Signal = require(ReplicatedStorage.Modules.Signal)

local SoundHandler = Mince:Get("SoundHandler")

local InterfaceHandler
local Button, Super = {
	ScalePercentage = 1/14,
	Tween = true 
}, {
	Buttons = {} 
}  
Button.__index = Button 

function Button.new(First : Frame | ImageButton, Paramaters) 
	local ActualButton : Frame | ImageButton = First or (Paramaters and Paramaters.Button)
	assert(ActualButton, "Could not detect a button ")
	
	-- It will becoming the prototyping for the class 
	Paramaters = Paramaters or { } 
	Paramaters.ID = ActualButton
	
	local ExistingClass = Super.Buttons[Paramaters.ID]
	if ExistingClass then return ExistingClass end

	-- Detect what's going to tween, and what's goin to detect button presses.
	if ActualButton:IsA("Frame") then
		if Paramaters.Button == nil then 
			Paramaters.Button = ActualButton:FindFirstChild("Button") or ActualButton:FindFirstChildWhichIsA("GuiButton")
		end
		Paramaters.TweenFrame = ActualButton
	elseif ActualButton:IsA("GuiButton") then 
		Paramaters.Button = ActualButton
		Paramaters.TweenFrame = ActualButton
	else 
		error("Could not find a button.")
	end

	local NewButton = setmetatable(Paramaters, Button)
	NewButton:Init() 
	
	Super.Buttons[Paramaters.ID] = NewButton
	return NewButton 
end


function Button:Destroy()
	Super.Buttons[self.ID] = nil
	self = nil 
end

function Button:CreateTweens() 
	self.Tweens = {} 
	self.Tweens.Hover = TweenService:Create(self.UIScale, self.TweenHover, {
		Scale = 1 + self.ScalePercentage 
	})  
	self.Tweens.Press = TweenService:Create(self.UIScale, self.TweenIn, {
		Scale = 1 - self.ScalePercentage
	})
	self.Tweens.Default = TweenService:Create(self.UIScale, self.TweenOut, {
		Scale = 1  
	})	
end

function Button:Init() 
	self.Activated = Signal.new() 
	self.Triggered = Signal.new()
	self.UIScale = Instance.new("UIScale", self.TweenFrame)  
	self.TweenIn = self.TweenIn or TweenInfo.new(0.2,Enum.EasingStyle.Bounce)
	self.TweenOut = self.TweenOut or TweenInfo.new(0.1)
	self.TweenHover = self.TweenInfo or TweenInfo.new(0.1,Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	
	self:CreateTweens() 
	
	-- Easier to access theese evnets! 
	self.MouseEnter = self.Button.MouseEnter
	self.MouseLeave = self.Button.MouseLeave 
	self.MouseButton1Up = self.Button.MouseButton1Up
	self.MouseButton1Down = self.Button.MouseButton1Down
	
	self.Button.MouseEnter:Connect(function() 
		if not self.Tween then return end 
		self.Tweens.Hover:Play() 	
		SoundHandler:PlaySound("ButtonHover")
	end)
	
	self.Button.MouseLeave:Connect(function() 
		if not self.Tween then return end  
		self.Tweens.Default:Play() 
	end)
	
	self.Button.MouseButton1Down:Connect(function() 
		if not self.Tween then return end  
		self.Tweens.Press:Play()			
		SoundHandler:PlaySound("ClickDown")
	end)
	
	self.Button.MouseButton1Up:Connect(function(X, Y) 
		if not self.Tween then return end  
		self.Tweens.Default:Play()
		self.Triggered:Fire(Vector2.new(X, Y))
		self.Activated:Fire(Vector2.new(X, Y))	
		SoundHandler:PlaySound("ClickUp")
	end)

	self.Button.Activated:Connect(function(X, Y) 
		if not self.Tween then return end  
		if not UserInputService.TouchEnabled then return end 
			
		self.Triggered:Fire(Vector2.new(X, Y))
	end)

	
	self.Button.Destroying:Connect(function() 
		self:Destroy()
	end)
end

function Button.Register(InterfaceHandler) 
	InterfaceHandler = InterfaceHandler
end

return Button 