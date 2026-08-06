-- Modules // Services 
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService('ReplicatedStorage') 
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer 

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Maid = require(ReplicatedStorage.Modules.Maid)
local Mince = require(ReplicatedStorage.Modules.Mince)
local Signal = require(ReplicatedStorage.Modules.Signal)
local Utility = require(ReplicatedStorage.Modules.Utility)

local BindManager = Mince:Get("BindManager")

-- ProxHand v2 - whim
local ProximityHandler = {
	CustomPrompts = {}, 
	WaitingThreads = {},
	Controllers = {},
	TranslateMethods = {
		["TriggerEnded"] = "TriggerEnded",
		["Triggered"]    = "Triggered",
		["HoldEnded"]    = "PromptButtonHoldEnded",
		["HoldBegan"]    = "PromptButtonHoldBegan"
	},
	ScreenGuiName = "__ProximityHandler",
	Enabled = true 
} 

local CustomPrompt = {} 
CustomPrompt.__index = CustomPrompt

function CustomPrompt.new(ProximityPrompt) 
	local NewPrompt = setmetatable({
		ProximityPrompt = ProximityPrompt, 

		ProxTable = {
			ProximityPrompt = ProximityPrompt,
			ScreenGui = ProximityHandler:GetScreenGui(),
			InputObjects = { 
				["Keyboard"] = BindManager:GetObject(ProximityPrompt.KeyboardKeyCode), 
				["Touch"] = BindManager:GetObject(Enum.UserInputType.Touch),
				["Gamepad"] = BindManager:GetObject(ProximityPrompt.GamepadKeyCode), 	
			}
		}, 
	}, CustomPrompt) 

	NewPrompt:Init() 

	ProximityHandler.CustomPrompts[ProximityPrompt] = NewPrompt	

	return NewPrompt
end

function CustomPrompt:GetProxTable() 
	return table.clone(self.ProxTable)
end

function CustomPrompt:Init() 
	self.InstancingMaid = Maid.new() 
	self.Maid = Maid.new() 

	self.InputsChanged = Signal.new() 

	self.TimesShown = 0 

	self.Maid:Add(self.ProximityPrompt.Destroying:Connect(function()
		self:Destroy()
	end))

	self.Maid:Add(self.ProximityPrompt:GetPropertyChangedSignal("KeyboardKeyCode"):Connect(function() 
		self.ProxTable.InputObjects["Keyboard"] = BindManager:GetObject(self.ProximityPrompt.KeyboardKeyCode)
		self:DetermineInputObject() 
		self.InputsChanged:Fire()
	end))

	self.Maid:Add(self.ProximityPrompt:GetPropertyChangedSignal("GamepadKeyCode"):Connect(function() 
		self.ProxTable.InputObjects["Gamepad"] = BindManager:GetObject(self.ProximityPrompt.GamepadKeyCode)
		self:DetermineInputObject() 
		self.InputsChanged:Fire()
	end))

	self.Maid:Add(BindManager.ModeChanged:Connect(function() 
		self:DetermineInputObject()
		self.InputsChanged:Fire()
	end))

	self.ProxTable.InstancingMaid = self.InstancingMaid
	self:DetermineInputObject() 
end

function CustomPrompt:DetermineInputObject() 
	self.ProxTable.InputObject = self.ProxTable.InputObjects[BindManager:GetMode()]
end

function CustomPrompt:Destroy() 
	self.Maid:Clean() 
end

function ProximityHandler:SetAllEnabled(Bool) 
	if Bool == ProximityHandler.Enabled then return end 
	ProximityHandler.Enabled = Bool 

	-- Resume any proximity prompts that are waiting to be hidden
	if not ProximityHandler.Enabled then 
		for _, YieldingThread : thread in ProximityHandler.WaitingThreads do 
			if coroutine.status(YieldingThread) == "suspended" then
				task.spawn(YieldingThread)
			end
		end
	end

end

function ProximityHandler:GetScreenGui() 
	local ScreenGui = PlayerGui:FindFirstChild(ProximityHandler.ScreenGuiName) 
	if not ScreenGui then 
		ScreenGui = Instance.new("ScreenGui", PlayerGui)
		ScreenGui.Name = ProximityHandler.ScreenGuiName
		ScreenGui.ResetOnSpawn = false
	end
	return ScreenGui
end

function ProximityHandler.PromptShown(ProximityPrompt : ProximityPrompt) 
	local ProximityType = ProximityPrompt:GetAttribute("Type") 
	local isHatchPrompt = ProximityPrompt:GetAttribute("IsHatchPrompt") or (ProximityPrompt.Parent and ProximityPrompt.Parent:GetAttribute("Hatch"))

	if not ProximityHandler.Enabled and not isHatchPrompt then return end 
	if ProximityPrompt.Style ~= Enum.ProximityPromptStyle.Custom then return end 
	if not ProximityType then return end 
	assert(Utility.AssertTypes(ProximityType, "string"))
	if ProximityPrompt.GamepadKeyCode ~= Enum.KeyCode.ButtonA then
		ProximityPrompt.GamepadKeyCode = Enum.KeyCode.ButtonA
	end
	local ProximityController = ProximityHandler.Controllers[ProximityType]
	if not ProximityController then return end 


	local PromptClass = ProximityHandler.CustomPrompts[ProximityPrompt] or CustomPrompt.new(ProximityPrompt)

	local NewPrompt = setmetatable(PromptClass:GetProxTable(), {__index = ProximityController})
	PromptClass.TimesShown += 1

	PromptClass.InstancingMaid:Add(PromptClass.InputsChanged:Connect(function() 
		if ProximityController.InputsChanged then 
			ProximityController.InputsChanged(NewPrompt)
		end
	end))


	NewPrompt.Simulate = function(self, MethodIndex) 
		if ProximityController[MethodIndex] then 
			ProximityController[MethodIndex](self)
		end
	end

	for ControlMethod,ProxMethod in ProximityHandler.TranslateMethods do 
		if ProximityController[ControlMethod] then 
			PromptClass.InstancingMaid:Add(ProximityPrompt[ProxMethod]:Connect(function(...)
				ProximityController[ControlMethod](NewPrompt, ...)
			end))
		end
	end	

	ProximityController.Appear(NewPrompt)

	local ThisWaitingThread = coroutine.running() 
	local PendingEvent = ProximityPrompt.PromptHidden:Once(function() 
		task.spawn(ThisWaitingThread)
	end) 

	ProximityHandler.WaitingThreads[ThisWaitingThread] = ThisWaitingThread 
	coroutine.yield()

	ProximityHandler.WaitingThreads[ThisWaitingThread] = nil
	PendingEvent:Disconnect() 

	PromptClass.InstancingMaid:Clean() 
	ProximityController.Hidden(NewPrompt)
end

function ProximityHandler.ValidateController(ProximityController)
	assert(ProximityController.Appear,"ProximityController.Appear is a required value.") 
	assert(ProximityController.Hidden,"ProximityController.Hidden is a required value.")
	return true 
end

function ProximityHandler:SetupScripts()
	for _, Child  in script:GetChildren() do 
		if Child:IsA("ModuleScript") then 
			local ModuleScript : ModuleScript = Child	 
			local ProximityControllerContents = require(ModuleScript) 


			if ProximityHandler.ValidateController(ProximityControllerContents) then 
				local Name = ProximityControllerContents.Name or ModuleScript.Name 
				-- Saving the controller
				ProximityHandler.Controllers[Name] = ProximityControllerContents
			end
		end
	end

end

function ProximityHandler:Setup() 
	ProximityPromptService.PromptShown:Connect(ProximityHandler.PromptShown)
	ProximityHandler:SetupScripts()
end

return ProximityHandler