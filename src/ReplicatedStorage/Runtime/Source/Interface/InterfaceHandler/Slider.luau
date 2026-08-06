-- Services // Modules 
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Signal = require(ReplicatedStorage.Modules.Signal)
local Utility = require(ReplicatedStorage.Modules.Utility)

local InterfaceHandler 
local Slider, Super = {
	InteractSliderInputsPress = {Enum.UserInputType.MouseButton1, Enum.UserInputType.Touch},
	InteractSliderInputsChange = {Enum.UserInputType.MouseMovement, Enum.UserInputType.Touch}
}, {
	Sliders = {} 
}  
Slider.__index = Slider 

function Slider.new(SliderFrame : GuiObject, Proto) 

	local ExistingClass = Super.Sliders[SliderFrame]
	if ExistingClass then return ExistingClass end

	local NewSlider = setmetatable(Proto or {} , Slider)
	NewSlider:Init(SliderFrame) 

	Super.Sliders[SliderFrame] = NewSlider
	return NewSlider 
end


function Slider:Init(GuiObject) 
	self.Changed = Signal.new() 
	
	self.GuiObject = GuiObject 
	
	self.Slide = GuiObject:WaitForChild("Slide")
	self.Button = GuiObject:WaitForChild("Button") 
	
	assert(self.Button:IsA("GuiButton"), "Slider.Button must be a GuiButton!")
	
	self.Targeted = false
	self.Padding = self.Padding or 0
	
	self.ButtonClass = InterfaceHandler:NewButton(self.Button) 
	
	
	self.ButtonClass.MouseButton1Up:Connect(function() 
		self.Targeted = false
	end)
	
	self.ButtonClass.MouseButton1Down:Connect(function() 
		warn("down")
		self.Targeted = true
	end)
		
	self.GuiObject.Destroying:Connect(function() 
		self:Destroy()
	end)
end

function Slider:SetPosition(Value) 
	local Position = math.clamp(Value, 0, 1)

	local Padding = self.Padding
	local InversePadding = 1 - Padding
	self.Button.Position = UDim2.fromScale(Position,0.5)
	self.Slide.Size = UDim2.fromScale(Position,1)
	self.Changed:Fire(Position)
end

function Slider:Destroy() 
	Super.Sliders[self.GuiObject] = nil 
	self = nil 
end


function Super.EndInput() 
	for _, Slider in Super.Sliders do
		Slider.Targeted = false 
	end
end

function Super.InputChanged(InputObject) 
	local Position = InputObject.Position 
	for _, Slider in Super.Sliders do
		if Slider.Targeted then 

			local MouseX, SliderSize = Position.X or 0, Slider.GuiObject.AbsoluteSize.X

			-- Calculate effective range considering padding
			local EffectiveRange = SliderSize * (1 - Slider.Padding)
			local SliderStart = Slider.GuiObject.AbsolutePosition.X + (SliderSize * Slider.Padding * 0.5)
			local PaddedPosition = (MouseX - SliderStart) / EffectiveRange

			
			local Position 
			if Slider.Step == 0 or not Slider.Step then
				Position = math.clamp(PaddedPosition, 0, 1)
			else
				local StepCount = 1 / Slider.Step
				Position = math.clamp(math.round(PaddedPosition * StepCount) / StepCount, 0, 1)
			end


			local Padding = Slider.Padding
			local UIPosition = (Position * (1 - Slider.Padding)) + Slider.Padding / 2
			Slider.GuiObject.Button.Position = UDim2.fromScale(UIPosition, 0.5)
			Slider.GuiObject.Slide.Size = UDim2.fromScale(UIPosition, 1)

			Slider.Changed:Fire(Position)
		end
	end
end


function Slider.Register(...) 
	InterfaceHandler = ... 
	
	Super.SliderInputsLookupChange = Utility.CreateFuzzyFinder(Slider.InteractSliderInputsChange) 
	Super.SliderInputsLookupPress = Utility.CreateFuzzyFinder(Slider.InteractSliderInputsPress) 
	UserInputService.InputChanged:Connect(function(InputObject)
		if Super.SliderInputsLookupChange[InputObject.UserInputType] then 
			Super.InputChanged(InputObject)	
		end 
	end)
	UserInputService.InputEnded:Connect(function(InputObject)
		if Super.SliderInputsLookupPress[InputObject.UserInputType] then 
			Super.EndInput(InputObject)
		end
	end)
	-- WHY? This doesn't work bcuz GUIs sink input and you can't undo it. And if you try to turn .Acitve = false it doesnt work on mobile. ;/
	--[[ContextActionService:BindActionAtPriority("SliderActions", function(_, InputState : Enum.UserInputState , InputObject) 
		if InputState == Enum.UserInputState.End then 
			Super.EndInput(InputObject)
		end

		return Enum.ContextActionResult.Pass
	end, false, table.unpack(Slider.InteractSliderInputsPress))]]
end

return Slider