local Signal = require(game.ReplicatedStorage.Modules.Signal)
local Hover, Super = {}, {
	Hovers = {} 
}  
Hover.__index = Hover 

function Hover.new(EventFrame : GuiObject, HoverFrame : GuiObject) 

	local ExistingClass = Super.Hovers[HoverFrame]
	if ExistingClass then return ExistingClass end
	
	local NewHover = setmetatable({}, Hover)  
	NewHover:Init(EventFrame, HoverFrame)
	
	return NewHover
end

function Hover:Init(EventFrame : GuiObject, HoverFrame : GuiObject) 
	assert(EventFrame, "[1]:GuiObject EventFrame reuqired!") 
	assert(HoverFrame, "[2]:GuiObject HoverFrame reuqired!") 
	self.Focused = Signal.new() 
	self.Text = "Hover.Text"
	self.EventFrame = EventFrame 
	self.Frame = HoverFrame
	self.Offset = UDim2.fromOffset(20,0)
	
	self.EventFrame.MouseEnter:Connect(function() 
		self.Focused:Fire()
		task.wait()
		self.Frame.Visible = true
		self.Frame.TextLabel.Text = ` {self.Text} `
	end)
	
	self.EventFrame.MouseLeave:Connect(function() 
		self.Frame.Visible = false 
	end)
	
	self.EventFrame.MouseMoved:Connect(function(...)
		local PositionUDim2 = UDim2.fromOffset(...) 
		self.Frame.Position = PositionUDim2 + self.Offset
	end)
end

function Hover:SetText(NewText : string) 
	self.Text = NewText 
	self.Frame.TextLabel.Text = ` {self.Text} `
end

return Hover	