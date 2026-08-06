-- Services // Modules
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local Player : Player = Players.LocalPlayer 
local PlayerGui = Player:WaitForChild("PlayerGui")

local Mince = require(ReplicatedStorage.Modules.Mince) 
local Signal = require(ReplicatedStorage.Modules.Signal) 

local EnumTo = require(script.EnumTo)
local Button = require(script.Button)
local BindClass = require(script.BindClass) 
local KeyListener = require(script.KeyListener)


-- BindManager v2 - whim
local BindManager = {
	EnumTo = EnumTo,

	Button = Button, 

	CurrentMode = "Keyboard",
	ModeChanged = Signal.new(),

	MobileJump = Signal.new(), 
	MobileJumpOnAction = Signal.new(),

	Binds = {}, 

	InputMatch = { -- Removed Config for InputMatch because it's redudant. 
		[Enum.UserInputType.Keyboard] = "Keyboard",
		[Enum.UserInputType.TextInput] = "Ignore", 
		[Enum.UserInputType.Touch] = "Touch",
		[Enum.UserInputType.Gamepad1] = "Gamepad",
		[Enum.UserInputType.Gamepad2] = "Gamepad",
		[Enum.UserInputType.Gamepad3] = "Gamepad",
		[Enum.UserInputType.Gamepad4] = "Gamepad",
		[Enum.UserInputType.Gamepad5] = "Gamepad",
		[Enum.UserInputType.Gamepad6] = "Gamepad",
		[Enum.UserInputType.Gamepad7] = "Gamepad",
		[Enum.UserInputType.Gamepad8] = "Gamepad"
	}
} 


function BindManager:When(... : Enum.KeyCode) 
	return 	KeyListener.new(...)
end 

function BindManager:SetMobileBindButtonsEnabled(BindName, Boolean) 
	local ThisBindClass = BindManager:Get(BindName)

	if not ThisBindClass then return end 
	ThisBindClass:SetMobileVisibility(Boolean)
end

function BindManager:Get(BindName) 
	local ThisBindClass = BindManager.Binds[BindName] 
	if ThisBindClass then return ThisBindClass end  

	error(`'{BindName}' is not a valid bind!`)
end

function BindManager:GetObject(KeyEnum : Enum.KeyCode | Enum.UserInputType) 
	return EnumTo.GetObject(KeyEnum)
end

function BindManager:GetMode() 
	return BindManager.CurrentMode  
end

function BindManager.WhenModeChanges(CallbackFn) 
	CallbackFn(BindManager.CurrentMode)

	BindManager.ModeChanged:Connect(CallbackFn)
end

function BindManager.InputTypeChanged(LastInput) 
	local Determination = BindManager.InputMatch[LastInput] or "Ignore" 
	if Determination ~= "Ignore" then 
		if BindManager.CurrentMode ~= Determination then 
			warn(("[BindManager]: Detected mode switched to %s."):format(Determination))
			BindManager.CurrentMode = Determination
			BindManager.ModeChanged:Fire(BindManager.CurrentMode)
		end
	end
end

function BindManager.InputBegan(InputObject : InputObject) 
	KeyListener:ProcessKey(InputObject, Enum.UserInputState.Begin)
end

function BindManager.InputEnded(InputObject : InputObject) 
	KeyListener:ProcessKey(InputObject, Enum.UserInputState.End)

	if InputObject.UserInputType == BindManager.Button.InteractingButton.UserInputType then 
		task.wait() 
		BindManager.Button.InteractingButton.Ending(InputObject.Position.X, InputObject.Position.Y)
	end
end

function BindManager:SetupSpecialTouchStuff() 
	local TouchGui = PlayerGui:WaitForChild("TouchGui")
	local TouchControlFrame = TouchGui:WaitForChild("TouchControlFrame")
	local JumpButton : GuiButton = TouchControlFrame:WaitForChild("JumpButton")

	JumpButton.MouseButton1Up:Connect(function() 
		BindManager.MobileJumpOnAction:Fire(Enum.UserInputState.End)
	end)

	JumpButton.MouseButton1Down:Connect(function() 
		BindManager.MobileJump:Fire()
		BindManager.MobileJumpOnAction:Fire(Enum.UserInputState.Begin)
	end)

	for _,Button in BindManager.Button.Stack do 
		Button.Parent = TouchControlFrame
	end

	BindManager.Button.TouchControlFrame = TouchControlFrame
end

function BindManager:SetupBinds() 
	for Name, BindObject in Mince.Config.Binds do
		BindObject.Name = Name 

		BindManager.Binds[Name] = BindClass.new(BindObject)
	end 
end

-- So all binds can be accessed within Setup() Without any yeilding! 
function BindManager:Init() 
	if UserInputService.TouchEnabled then 
		BindManager.CurrentMode = "Touch"
	elseif UserInputService.VREnabled then 
		BindManager.CurrentMode = "VR" 
	elseif UserInputService.GamepadEnabled then 
		--BindManager.CurrentMode = "Gamepad"
		-- This is disabled because! of this being enabled with a controller pluged-in.
	end

	BindManager:SetupBinds()
end 

function BindManager:Setup() 
	if UserInputService.TouchEnabled then 
		task.defer(function() 
			BindManager:SetupSpecialTouchStuff() 
		end)
	end

	-- Connections 
	UserInputService.LastInputTypeChanged:Connect(BindManager.InputTypeChanged)
	UserInputService.InputEnded:Connect(BindManager.InputEnded)
	UserInputService.InputBegan:Connect(BindManager.InputBegan)
end

-- Intiliaze and return,.
BindManager.Init() ; return BindManager