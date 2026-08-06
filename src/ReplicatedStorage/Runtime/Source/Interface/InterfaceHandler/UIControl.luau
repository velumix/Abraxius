local ReplicatedStorage = game:GetService('ReplicatedStorage')
local TweenService = game:GetService("TweenService")

local Signal = require(ReplicatedStorage.Modules.Signal)

local InterfaceController = {}

local UIControl, Super = {
	IsActive = false,
	ManualStack = false
}, {
	UIControls = {}
}

UIControl.__index = UIControl

function UIControl.new(First : string | UIBase, FirstName, ForceWait)
	if typeof(FirstName) == "boolean" and ForceWait == nil then
		ForceWait = FirstName
		FirstName = nil
	end
	assert(not FirstName or FirstName and typeof(FirstName) == "string", "new(_, string) proper usage.")
	local Type = typeof(First)
	local TweenFrame , Name
	if Type == "string" then 
		local ScreenGui = InterfaceController:GetScreenGui(First, ForceWait)
		local FirstItem : Frame = ScreenGui:FindFirstChild(FirstName or "MainFrame") or ScreenGui:FindFirstChild("Main") or ScreenGui:FindFirstChildWhichIsA("Frame") or ScreenGui:FindFirstChildWhichIsA("ImageLabel") or ScreenGui:FindFirstChildWhichIsA("UIBase")
		TweenFrame = FirstItem
		Name = First
		if FirstName then 
			Name = FirstName .. ":" .. Name
		end
	elseif Type == "Instance" then 
		if not First:IsA("GuiObject") then 
			error(`Instance type '{First.ClassName}' is not allowed! It must be a 'GuiObject'.`)
		end
		TweenFrame = First
		Name = First:GetFullName()
	else
		error("Invalid type! Param[1] check to make sure you are using : and not .")
	end

	if not TweenFrame then
		error("There is no UI by the name of '" ..Name.."'. ")
		return nil
	end

	local ExistingClass = Super.UIControls[Name]

	if ExistingClass then return ExistingClass end

	local ScreenGui = TweenFrame:FindFirstAncestorOfClass("ScreenGui")
	local NewControl = setmetatable({Name = Name}, UIControl)

	NewControl.CardStack = InterfaceController.DefaultStack 
	NewControl:Create(TweenFrame, ScreenGui)

	if Type ~= "Instance" and NewControl.TweenFrame.Visible then
		NewControl:Switch() 
	end

	Super.UIControls[Name] = NewControl
	return NewControl
end

function UIControl:Create(TweenFrame : Frame, ScreenGui : ScreenGui?) 
	self.Opened = Signal.new()
	self.Closed = Signal.new()

	self.TweenFrame = TweenFrame 
	self.ScreenGui = ScreenGui
	self.TweenStyles = self.TweenStyles or UIControl.DefaultTweenStyles
	
	
	self.Opened:Connect(function()
		if ScreenGui then
			InterfaceController.ScreenShown:Fire(self.ComponentName or ScreenGui.Name, true)
		end
	end)
	
	self.Closed:Connect(function()
		if ScreenGui then
			InterfaceController.ScreenShown:Fire(self.ComponentName or ScreenGui.Name, false)
		end
	end)

	self:CreateTweens()
end

function UIControl:CreateTweens()  
	local startPosition = self.StartPosition or self.TweenFrame.Position
	local hiddenPosition = self.HiddenPosition or UDim2.new(startPosition.X.Scale, 0,
		startPosition.Y.Scale+InterfaceController.HiddenOffset, 0)

	self.Positions = {
		Start = startPosition,
		Below = UDim2.new(startPosition.X.Scale, 0,
			startPosition.Y.Scale+InterfaceController.VerticalOffset, 0), 
		Above = UDim2.new(startPosition.Y.Scale, 0, 
			startPosition.Y.Scale-InterfaceController.VerticalOffset, 0),
		Hidden = hiddenPosition
	}

	self.Tweens = {
		Default = TweenService:Create(self.TweenFrame, self.TweenStyles.InTweenInfo, {
			Position = self.Positions.Start, 
		}), 
		Hidden = TweenService:Create(self.TweenFrame, self.TweenStyles.OutTweenInfo, {
			Position = self.Positions.Hidden,
		}), 
		Above = TweenService:Create(self.TweenFrame, self.TweenStyles.OutTweenInfo, {
			Position = self.Positions.Above,
		})
	}
end

function UIControl:IsOpen()
	return self.IsActive
end

function UIControl:Activate()
	if self.IsActive then return end
	self.IsActive = true

	self.TweenFrame.Visible = true
	self.Tweens.Default:Play()
	self.Opened:Fire()
end

function UIControl:Deactivate() 
	if not self.IsActive then return end
	self.IsActive = false

	self.Tweens.Hidden:Play()
	self.Tweens.Hidden.Completed:Wait()
	if not self.IsActive then 
		self.TweenFrame.Visible = false
	end
	self.Closed:Fire()
end

function UIControl:Trigger() 
	if self.ManualStack then
		return warn("You've used Show() on this, it's not in the stack so you cannot use Close(),Trigger(),Stack() or Switch().")
	end

	if self.IsActive then 
		self.CardStack:Remove()
	else
		self:Switch()
	end
end

function UIControl:Stack(Priority)
	if self.ManualStack then
		warn("This operation can't be done beause it is currently manually appeared.")
		return
	end

	local TopUIControl = self.CardStack:GetTop()
	if TopUIControl and TopUIControl.SuperPriority then 
		warn(`Can't switch '{self.Name}' because the CONTROL '{TopUIControl.Name}' has SuperPriority.`)
		return
	end

	self.Priority = Priority 
	self.CardStack:Add(self)
end

function UIControl:Switch() 
	if self.ManualStack then
		warn("This operation can't be done beause it is currently manually appeared.")
		return
	end

	local TopUIControl = self.CardStack:GetTop() 
	if TopUIControl and TopUIControl.Priority then 
		warn(`Can't switch '{self.Name}' because the CONTROL '{TopUIControl.Name}' is priority enabled.`)
		return 
	elseif TopUIControl == self then
		warn(`Preventing double stacking... Cannot switch when the topGuiObject is already shown.`)
		return 
	end

	self.CardStack:Switch(self)
end


function UIControl:Open()
	self:Switch()
end


function UIControl:Close()
	if self.ManualStack then
		warn("This operation can't be done beause it is currently manually appeared.")
		return
	end

	if self.IsActive then
		self.CardStack:Remove()
	end
end

function UIControl:Hide(Skip, Duration)
	if not self.ManualStack then
		warn("Sure you don't mean :Close? This hasn't been manually opened with :Show().")
		return
	end

	self.ManualStack = false

	if Skip then
		task.wait(Duration)
		self.TweenFrame.Visible = false
		return
	end

	self.Tweens.Hidden:Play()
	self.Tweens.Hidden.Completed:Wait()
	self.TweenFrame.Visible = false

	self.Closed:Fire()

	return
end

function UIControl:Show(Skip)
	self.ManualStack = true
	self.TweenFrame.Visible = true

	self.Opened:Fire()

	if Skip then
		return
	end

	self.Tweens.Default:Play()
end

function UIControl.Register(N)
	InterfaceController = N
	UIControl.DefaultTweenStyles = InterfaceController.TweenStyles
end

return UIControl 
