-- Modules // Services -- 
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local ContextActionService = game:GetService("ContextActionService")

local Mince = require(ReplicatedStorage.Modules.Mince) 
local Utility = require(ReplicatedStorage.Modules.Utility)

local EnumTo = require(script.Parent.EnumTo)
local ButtonConfig = require(script.Parent.Button)

local BindManager = Mince:Get("BindManager")

export type BindClass = {
	GetName : () -> string, 
	OnAction : RBXScriptSignal, 
	ContextActionResult : Enum.ContextActionResult 
} 


local BindClass = {} 
BindClass.__index = BindClass 

function BindClass.new(Registry) 
	local self = setmetatable(Registry, BindClass) 
	self:init() 
	return self 
end

function BindClass:init() 
	self.ScreenButtons = {} 
	self.VisualObjects = {} 
	self.BindList = {} 
	
	for BindKey, Bind in self.Binds do 
		self.VisualObjects[BindKey] = EnumTo.GetObject(Bind)
		table.insert(self.BindList, Bind)
	end
	
	for _, ButtonConfiguration in self.Buttons or {} do 
		self:AddButton(ButtonConfiguration) 
	end
	
	
	self.OnAction = Mince.Signal.new() 
	self.ContextActionResult = Enum.ContextActionResult.Pass
	
	ContextActionService:BindAction(self.Name, function(...) 
		return self:HandleAction(...)
	end, false, table.unpack(self.BindList))
end

function BindClass:ChangeAllButtonsIcon(AssetID : Content) 
	for _, GuiButton in ipairs(self.ScreenButtons) do 
		GuiButton.Icon.Image = AssetID
	end
end

function BindClass:AddGuiButton(GuiButton : GuiButton, ButtonConfiguration) 
	local UponEnding = function(X, Y) 
		local InputObject : InputObject = {
			Position = Vector2.new(X, Y),
			UserInputState = Enum.UserInputState.End, 
			UserInputType = Enum.UserInputType.Touch,
		}

		self:HandleAction(self.Name, InputObject.UserInputState, InputObject)

		GuiButton.Image = ButtonConfig.Static
		if not ButtonConfiguration.DontMorphInner then 
			GuiButton.ImageTransparency = 0.55
			GuiButton.Icon.ImageColor3 = ButtonConfig.StaticColor
			GuiButton.ButtonText.TextColor = BrickColor.new(ButtonConfig.StaticColor)
		end

		ButtonConfig.InteractingButton = {}
	end

	local UponStarting = function(X, Y) 
		local InputObject : InputObject = {
			Position = Vector2.new(X, Y),
			UserInputState = Enum.UserInputState.Begin, 
			UserInputType = Enum.UserInputType.Touch,
		}

		self:HandleAction(self.Name, InputObject.UserInputState, InputObject)

		ButtonConfig.InteractingButton = {
			UserInputType = InputObject.UserInputType,
			Ending = UponEnding
		}

		GuiButton.Image = ButtonConfig.Pressed
		if not ButtonConfiguration.DontMorphInner then 
			GuiButton.ImageTransparency = 0.77 
			GuiButton.Icon.ImageColor3 = ButtonConfig.PressedColor
			GuiButton.ButtonText.TextColor = BrickColor.new(ButtonConfig.PressedColor)
		end
	end


	-- Connect the button to actual 
	GuiButton.MouseButton1Down:Connect(UponStarting)
	GuiButton.MouseButton1Up:Connect(UponEnding)

	table.insert(ButtonConfig.Stack, GuiButton)
	table.insert(self.ScreenButtons, GuiButton)
end

function BindClass:CreateButtonFromConfiguration(ButtonConfiguration)
	local Button = script.Button:Clone()

	Button.Name = `{self.Name}.ScreenButton`


	local Position = ButtonConfiguration.Position or Vector2.new(0.5,0.5)
	local Alignment = ButtonConfiguration.Align or "BottomRight"
	local AlignmentTable = ButtonConfig.ButtonAligments[Alignment] or {} 
	local DisplayText = ButtonConfiguration.Name or "Button.Name"
	local Scale = AlignmentTable.Position or Vector2.new(0,0)
	local AnchorPoint = AlignmentTable.Anchor or Vector2.new(0,0)
	local PositionMult = AlignmentTable.Multiplier or 1 
	local HasIcon = ButtonConfiguration.Icon ~= nil 

	Position *= PositionMult

	-- Setup Texts!
	local NewIconSize = ButtonConfig.BaseIconSize * (ButtonConfiguration.IconSize or 1)
	if HasIcon then  
		Button.Icon.Image = ButtonConfiguration.Icon
	end
	-------------------------------------------------------
	local TextSize = ButtonConfiguration.TextSize or 1 
	local ButtonSize = ButtonConfiguration.ButtonSize or 1 
	Button.Size = UDim2.fromOffset(Button.Size.X.Offset * ButtonSize, Button.Size.Y.Offset * ButtonSize)
	Button.ButtonText.Size = UDim2.fromScale(Button.ButtonText.Size.X.Scale * TextSize, Button.ButtonText.Size.Y.Scale * TextSize)
	Button.Icon.Size = UDim2.fromScale(NewIconSize,NewIconSize)
	Button.AnchorPoint = AnchorPoint
	Button.ButtonText.Text = DisplayText
	Button.Icon.Visible = HasIcon 
	Button.ButtonText.Visible = not HasIcon
	Button.Position = UDim2.new(Scale.X, Position.X,
		Scale.Y, Position.Y )
	Button.Active = true 
	Button.Visible = not (self.HideButtons or false) 
	Button.Parent = ButtonConfig.TouchControlFrame
	-------------------------------------
	return Button
end

function BindClass:AddButton(ButtonConfiguration) 
	self:AddGuiButton(self:CreateButtonFromConfiguration(ButtonConfiguration), ButtonConfiguration)
end

function BindClass:ControlAction(ControlFn : () -> Enum.ContextActionResult)  
	assert(Utility.AssertTypes(ControlFn, "function"))
	self.ControlActionFn = ControlFn
end

function BindClass:HandleAction(_, InputState : Enum.UserInputState, InputObject) 
	if self.ControlActionFn then
		local Success, Result = pcall(function() 
			return self.ControlActionFn() 
		end)
		
		if not Success then 
			return Enum.ContextActionResult.Pass 
		end
		
		return Result
	end 
	
	self.OnAction:FireImmediate(InputState, InputObject)
	return self.ContextActionResult
end

function BindClass:SetButtonsVisibility(Boolean) 
	for _, Button : ImageButton in  self.ScreenButtons do 
		Button.Visible = Boolean
	end
end

function BindClass:SetMobileVisibility(Boolean) 
	for _, Button : ImageButton in  self.ScreenButtons do 
		Button.Visible = Boolean
	end
end

function BindClass:GetVisualObject() 
	return self.VisualObjects[BindManager.CurrentMode]
end

function BindClass:GetPrimaryVisualObject() 
	return self.VisualObjects[BindManager.CurrentMode] or next(self.VisualObjects)
end

function BindClass:GetPrimaryString() 
	local KeyCode = self:GetPrimaryKeyCode() 
	return EnumTo.KeyCodeToTextMapping[KeyCode] or UserInputService:GetStringForKeyCode(KeyCode)
end

function BindClass:GetPrimaryKeyCode() 
	return self.BindsIndex[BindManager.CurrentMode] or self.Binds[1]
end

function BindClass:GetName() 
	return self.Config.BindFormattedText or self.Name 
end 


return BindClass