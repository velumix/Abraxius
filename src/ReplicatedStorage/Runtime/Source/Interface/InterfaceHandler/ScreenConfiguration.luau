-- Services // Moduels
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Maid = require(ReplicatedStorage.Modules.Maid)
local Mince = require(ReplicatedStorage.Modules.Mince) 
local Signal = require(ReplicatedStorage.Modules.Signal)

local BindManager = Mince:Get("BindManager")

local InterfaceHandler
local ScreenConfiguration = {
	ByDefaultScaleAllStrokes = true,
	ByDefaultScaleForMobile = false 
} 
ScreenConfiguration.__index = ScreenConfiguration

function ScreenConfiguration.new(...) 
	local NewConfig = setmetatable({}, ScreenConfiguration)
	NewConfig:Init(...)

	return NewConfig 
end

function ScreenConfiguration:Init(ScreenGui : ScreenGui) 
	for Index, Value in ScreenGui:GetAttributes() do 
		if not self[Index] then 
			self[Index] = Value
		end
	end
	
	self.ScreenGui = ScreenGui
	
	self.MobileScaling = self.MobileScaling or 1.3 
	
	self.Maid = Maid.new() 
	self.Destroying = Signal.new() 
	
	self:CaptureForRescaling()
	
	self.Maid:Add(ScreenGui.Destroying:Connect(function() 
		self:Destroy()
	end))
	
	self.Maid:Add(BindManager.ModeChanged:Connect(function(BindMode) 
		self:WhenInputModeChanged(BindMode)
	end))
	
	if BindManager.CurrentMode then 
		self:WhenInputModeChanged(BindManager.CurrentMode)
	end
		
	if self.ScaleStrokes or ScreenConfiguration.ByDefaultScaleAllStrokes then 
		self:ScaleAllStrokes() 
	end
end

function ScreenConfiguration:WhenInputModeChanged(BindMode : string) 
	if ScreenConfiguration.ByDefaultScaleForMobile or self.ScaleForMobile then 
		if BindMode == "Touch" then 
			-- Rescale tall of the frames to be rescaled to the big one [2]
			for GuiObject, SizeArray in self.RescaleGuiObjects do 
				GuiObject.Size = SizeArray[2]
			end

			-- Add more......
		else 
			-- Rescale to default [] 
			for GuiObject, SizeArray in self.RescaleGuiObjects do 
				GuiObject.Size = SizeArray[1]
			end	

			-- Add more.....
		end
	end
end

function ScreenConfiguration:CaptureForRescaling()
	self.RescaleGuiObjects = {} 
	local HandleChangeGuiObject = function(ChildGuiObject : ChildGuiObject) 
		local DefaultSize = ChildGuiObject.Size
		local AdjustedSize = UDim2.new(
			ChildGuiObject.Size.X.Scale * self.MobileScaling, 
			ChildGuiObject.Size.X.Offset * self.MobileScaling,
			ChildGuiObject.Size.Y.Scale * self.MobileScaling, 
			ChildGuiObject.Size.Y.Offset * self.MobileScaling
		)
		
		self.RescaleGuiObjects[ChildGuiObject] = {DefaultSize, AdjustedSize}
	end
	
	for _, GuiObject : GuiObject in self.ScreenGui:GetChildren() do 
		if GuiObject:IsA("GuiObject") then 
			if not GuiObject:GetAttribute("IgnoreScaling") then
				HandleChangeGuiObject(GuiObject)			
			end
		end
	end
end

function ScreenConfiguration:Destroy() 
	if self.Destroyed then return end 
	self.Destroyed = true
	self.Destroying:Fire()
	self.Maid:Clean()
end

function ScreenConfiguration:ScaleAllStrokes() 
	for _, UIStroke : UIStroke in self.ScreenGui:GetDescendants() do 
		if UIStroke:IsA("UIStroke") then 
			local StrokeScaler = InterfaceHandler.Tools.CreateStrokeScaler(UIStroke) 
			task.defer(StrokeScaler)
			
			self.Maid:Add(InterfaceHandler.ScreenSizeChanged:Connect(StrokeScaler))
		end
	end 
end

function ScreenConfiguration.Register(...) 
	InterfaceHandler = ... 
end

return ScreenConfiguration