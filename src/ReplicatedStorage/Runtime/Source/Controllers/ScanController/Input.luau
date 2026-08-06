local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Modules.Trove)

local function toVector2(position)
	if not position then
		return nil
	end

	local positionType = typeof(position)
	if positionType == "Vector2" then
		return position
	elseif positionType == "Vector3" then
		return Vector2.new(position.X, position.Y)
	end

	return nil
end

local Input = {}
Input.__index = Input

local PRIMARY_USER_INPUT_TYPES = {
	[Enum.UserInputType.MouseButton1] = true,
	[Enum.UserInputType.Touch] = true,
}

local SECONDARY_USER_INPUT_TYPES = {
	[Enum.UserInputType.MouseButton2] = true,
}

local PRIMARY_GAMEPAD_KEYS = {
	[Enum.KeyCode.ButtonR2] = true,
}

local SECONDARY_GAMEPAD_KEYS = {
	[Enum.KeyCode.ButtonR1] = true,
}

local DEADZONE = 0.1

function Input.new(controller)
	local self = setmetatable({}, Input)

	self.Controller = controller
	self.Device = "pc"
	self.Trove = Trove.new()

	self.Events = {
		DeviceChange = Instance.new("BindableEvent"),
		Tap = Instance.new("BindableEvent"),
		Button = Instance.new("BindableEvent"),
	}

	return self
end

function Input:GetDevice()
	return self.Device
end

function Input:GetEvents()
	return self.Events
end

function Input:Start()
	self:Stop()
	self:DetectDevice(UserInputService:GetLastInputType())
	self:BindDeviceWatchers()
	self:BindInputEvents()
end

function Input:Stop()
	if self.Trove then
		self.Trove:Clean()
	end
end

function Input:Destroy()
	self:Stop()
	for _, bindable in pairs(self.Events) do
		bindable:Destroy()
	end
	self.Events = nil
	self.Controller = nil
end

function Input:BindDeviceWatchers()
	self.Trove:Connect(UserInputService.LastInputTypeChanged, function(newType)
		self:DetectDevice(newType)
	end)

	self.Trove:Connect(UserInputService.GamepadConnected, function()
		self:DetectDevice(Enum.UserInputType.Gamepad1)
	end)

	self.Trove:Connect(UserInputService.GamepadDisconnected, function()
		self:DetectDevice(UserInputService:GetLastInputType())
	end)
end

function Input:IsPrimary(inputObject)
	if PRIMARY_USER_INPUT_TYPES[inputObject.UserInputType] then
		return true
	end

	return PRIMARY_GAMEPAD_KEYS[inputObject.KeyCode] or false
end

function Input:IsSecondary(inputObject)
	if SECONDARY_USER_INPUT_TYPES[inputObject.UserInputType] then
		return true
	end

	return SECONDARY_GAMEPAD_KEYS[inputObject.KeyCode] or false
end

function Input:BindInputEvents()
	self.Trove:Connect(UserInputService.InputChanged, function(inputObject)
		self:OnInputChanged(inputObject)
	end)

	self.Trove:Connect(UserInputService.InputBegan, function(inputObject)
		self:OnInputBegan(inputObject)
	end)

	self.Trove:Connect(UserInputService.InputEnded, function(inputObject)
		self:OnInputEnded(inputObject)
	end)
end

function Input:OnInputChanged(inputObject)
	local controller = self.Controller
	if not controller or not controller.Enabled then
		return
	end

	local inputType = inputObject.UserInputType

	if inputType == Enum.UserInputType.MouseMovement or inputType == Enum.UserInputType.Touch then
		local controller = self.Controller
		if controller then
			local position = toVector2(inputObject.Position) or toVector2(UserInputService:GetMouseLocation())
			if inputType == Enum.UserInputType.Touch and position then
				local lastTouchPosition = controller.LastTouchPosition
				if lastTouchPosition then
					controller.TouchDelta = position - lastTouchPosition
				else
					controller.TouchDelta = Vector2.zero
				end
				controller.LastTouchPosition = position
			end
			if inputType == Enum.UserInputType.Touch and controller.NormalizePointerPosition then
				position = controller:NormalizePointerPosition(position) or position
			end
			if position then
				controller.LastPointerPosition = position
				if inputType == Enum.UserInputType.Touch and controller.CursorManager and controller.CursorManager.SetScannerCursorPosition then
					controller.CursorManager:SetScannerCursorPosition(position)
				end
			end
		end
		controller:MouseMove("ScannerPointer", Enum.UserInputState.Change, inputObject)
	elseif inputType == Enum.UserInputType.MouseWheel then
		controller:OnScroll("ScannerZoom", Enum.UserInputState.Change, inputObject)
	elseif inputType == Enum.UserInputType.Gamepad1 and inputObject.KeyCode == Enum.KeyCode.Thumbstick1 then
		self:HandleThumbstick(inputObject)
	end
end

function Input:OnInputBegan(inputObject)
	local controller = self.Controller
	if not controller or not controller.Enabled then
		return
	end

	if self:IsPrimary(inputObject) then
		controller:Trigger("ScannerTrigger", Enum.UserInputState.Begin, inputObject)
		self.Events.Button:Fire("primary", true)
		if not controller.SkeletonMode and not controller.Locked then
			controller.LockRequested = true
		end
	elseif self:IsSecondary(inputObject) then
		controller:Hold("ScannerHold", Enum.UserInputState.Begin, inputObject)
		self.Events.Button:Fire("secondary", true)
	end

	if inputObject.UserInputType == Enum.UserInputType.Touch then
		local position = toVector2(inputObject.Position) or toVector2(UserInputService:GetMouseLocation())
		if self.Controller and self.Controller.NormalizePointerPosition then
			position = self.Controller:NormalizePointerPosition(position) or position
		end
		if position then
			self.Controller.LastPointerPosition = position
			self.Controller.LastTouchPosition = position
			self.Controller.TouchDelta = Vector2.zero
			if self.Controller.CursorManager and self.Controller.CursorManager.SetScannerCursorPosition then
				self.Controller.CursorManager:SetScannerCursorPosition(position)
			end
			self.Events.Tap:Fire(position)
		end
	end
end

function Input:OnInputEnded(inputObject)
	local controller = self.Controller
	if not controller or not controller.Enabled then
		return
	end

	if self:IsPrimary(inputObject) then
		controller:Trigger("ScannerTrigger", Enum.UserInputState.End, inputObject)
		self.Events.Button:Fire("primary", false)

		if not controller.SkeletonMode then
			local mouseBehavior = UserInputService.MouseBehavior
			if mouseBehavior == Enum.MouseBehavior.LockCenter or mouseBehavior == Enum.MouseBehavior.LockCurrentPosition then
				local cursorManager = controller.CursorManager
				if cursorManager and cursorManager.CenterScannerCursor then
					cursorManager:CenterScannerCursor()
				end
			end
		end
	elseif self:IsSecondary(inputObject) then
		controller:Hold("ScannerHold", Enum.UserInputState.End, inputObject)
		self.Events.Button:Fire("secondary", false)
	end

	if inputObject.UserInputType == Enum.UserInputType.Touch then
		controller.LastTouchPosition = nil
		controller.TouchDelta = Vector2.zero
	end

end

function Input:HandleThumbstick(inputObject)
	local controller = self.Controller
	if not controller or not controller.Enabled then
		return
	end

	local magnitude = inputObject.Position.Magnitude
	if magnitude < DEADZONE then
		return
	end

	controller:MouseMove("ScannerThumbstick", Enum.UserInputState.Change, inputObject)
end

function Input:DetectDevice(lastInputType)
	local device = "pc"
	local inputType = lastInputType or UserInputService:GetLastInputType()

	if GuiService:IsTenFootInterface() or inputType == Enum.UserInputType.Gamepad1 then
		device = "xbox"
	elseif UserInputService.TouchEnabled and inputType == Enum.UserInputType.Touch then
		device = "phone"
	end

	local localPlayer = Players.LocalPlayer
	if device == "xbox" and localPlayer then
		local consoleType = localPlayer:GetAttribute("ConsoleType")
		if typeof(consoleType) == "string" then
			device = consoleType:lower()
		end
	end

	if device ~= self.Device then
		self.Device = device
		self.Events.DeviceChange:Fire(device)
	end

	return device
end

return Input