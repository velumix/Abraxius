local userInputService = game:GetService("UserInputService")
---

local EnumTo = {
	TapIcon = "",
	TargetColor = "Dark",
	KeyImages = {
		Dark = {
			[Enum.KeyCode.E]          = "rbxassetid://92124062390999",
		},
		Light = {
			[Enum.KeyCode.Up]         = "rbxassetid://15127478131", 
			[Enum.KeyCode.Down]       = "rbxassetid://15127478524", 
			[Enum.KeyCode.R]          = "rbxassetid://18675283111", 
			[Enum.KeyCode.Left]       = "rbxassetid://15127478370", 
			[Enum.KeyCode.Right]      = "rbxassetid://15127478260",
			[Enum.KeyCode.Space]      = "rbxassetid://15434564201",
			[Enum.KeyCode.LeftShift]  = "rbxassetid://15434925385", 
			[Enum.KeyCode.RightShift] = "rbxassetid://15434925385",
			[Enum.UserInputType.Touch]= "rbxassetid://124284788826567",
		}, 
	},
	KeyCodeToTextMapping = {
		[Enum.KeyCode.LeftControl] = "Ctrl",
		[Enum.KeyCode.RightControl] = "Ctrl",
		[Enum.KeyCode.LeftAlt] = "Alt",
		[Enum.KeyCode.RightAlt] = "Alt",
		[Enum.KeyCode.F1] = "F1",
		[Enum.KeyCode.F2] = "F2",
		[Enum.KeyCode.F3] = "F3",
		[Enum.KeyCode.F4] = "F4",
		[Enum.KeyCode.F5] = "F5",
		[Enum.KeyCode.F6] = "F6",
		[Enum.KeyCode.F7] = "F7",
		[Enum.KeyCode.F8] = "F8",
		[Enum.KeyCode.F9] = "F9",
		[Enum.KeyCode.F10] = "F10",
		[Enum.KeyCode.F11] = "F11",
		[Enum.KeyCode.F12] = "F12",
		[Enum.UserInputType.Touch] = "Touch",
		[Enum.UserInputType.MouseButton1] = "LMB",
		[Enum.UserInputType.MouseButton2] = "RMB",
		[Enum.KeyCode.LeftShift] = "L-Shift",
		[Enum.KeyCode.RightShift] = "R-Shift",
		[Enum.UserInputType.MouseMovement] = "MouseMovement",
	}
} 

function EnumTo.SortProximityInputType(InputType,InputGamePad,InputKeyPad) 
	if InputType == Enum.ProximityPromptInputType.Touch then 
		return {
			Type = "Image", 
			Value = EnumTo.TapIcon 
		} 
	end
	if InputType == Enum.ProximityPromptInputType.Gamepad then 
		return EnumTo.GetObject(InputGamePad)
	end
	if InputType == Enum.ProximityPromptInputType.Keyboard then 
		return EnumTo.GetObject(InputKeyPad)
	end
	warn("[EnumTo]: Unable to sort the ProximityPromptInputType into a inputobject.")
end

function EnumTo.GetObject(KeyEnum, Color) 
	local ThisColor = Color or EnumTo.TargetColor
	local ButtonTextString = EnumTo.KeyCodeToTextMapping[KeyEnum] or userInputService:GetStringForKeyCode(KeyEnum)
	local ButtonTextImage = EnumTo.KeyImages[ThisColor][KeyEnum] or EnumTo.KeyImages[ThisColor][ButtonTextString]  

	if ButtonTextImage then 
		return {Type='Image', Value=ButtonTextImage}
	end

	return {Type="String", Value=ButtonTextString}
end

return EnumTo 