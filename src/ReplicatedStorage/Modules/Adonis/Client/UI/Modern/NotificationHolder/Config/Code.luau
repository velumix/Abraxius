client = nil
Pcall = nil
Routine = nil
service = nil
gTable = nil

return function(data, env)
	if env then
		setfenv(1, env)
	end
	
	local gui = script.Parent.Parent
	local ScrollingFrame = gui.ScrollingFrame
	local UIListLayout = ScrollingFrame.UIListLayout
	local currentChildren = 0 -- A surprisingly good way to do it in terms of lag.
	
	ScrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	
	--local function UpdateCanvasSize()
	--	ScrollingFrame.CanvasSize = UDim2.new(0, UIListLayout.AbsoluteContentSize.X, 0, UIListLayout.AbsoluteContentSize.Y)
	--end
	
	--ScrollingFrame.ChildAdded:Connect(function(child)
	--	currentChildren += 1
	--	local textSize = service.TextService:GetTextSize(child.Frame.Main.Text, child.Frame.Main.TextSize, child.Frame.Main.Font, Vector2.new(229,2147483647)).Y
	--	child.Size = child.Size + UDim2.new(0, 0, 0, textSize + 5)
	--	child.Frame.Main.Size = child.Frame.Main.Size + UDim2.new(0, 0, 0, textSize + 5)
	--	--[[
	--	It works. Makes the scroll bar snap to the bottom of the screen,
	--	only if it was already on the bottom of the scrollingframe,
	--	but has to account for the canvas size being 0,
	--	which occurs when there is no room to scoll
	--	(all notifications total size with padding less than 300).
		
	--	This took me about a quater of an hour to perfect.
		
	--	It's just basic arithmatic...
		
	--	I hate math.
	--	]]--
	--	UpdateCanvasSize()
	--	if ScrollingFrame.CanvasPosition.Y + child.AbsoluteSize.Y + 5 == ScrollingFrame.AbsoluteCanvasSize.Y - ScrollingFrame.AbsoluteWindowSize.Y then
	--		ScrollingFrame.CanvasPosition = ScrollingFrame.CanvasPosition + child.AbsoluteSize + Vector2.new(0,5)
	--	elseif child.AbsoluteSize.Y > ScrollingFrame.AbsoluteCanvasSize.Y - ScrollingFrame.AbsoluteWindowSize.Y then
	--		ScrollingFrame.CanvasPosition = ScrollingFrame.CanvasPosition + child.AbsoluteSize + Vector2.new(0,5)
	--	end
	--end)
	
	--ScrollingFrame.ChildRemoved:Connect(function(child)
	--	currentChildren -= 1
	--	UpdateCanvasSize()
	--	if currentChildren == 0 then
	--		gui:Destroy()
	--	end
	--end)
	
	
	gTable:Ready()
end