local InterfaceHandler 
local Tools = {}

function Tools.PlaceBeyond(Frame : Frame, Padding, Directions)
	local H = function(V)
		return 2 * (V - 0.5) 
	end
	
	Padding = Padding or 0.1
	Directions = Directions or Frame.AnchorPoint
	
	return UDim2.fromScale(
		Directions.X + (H(Directions.X) * (Frame.Size.X.Scale + Padding)), 
		Directions.Y + (H(Directions.Y) * (Frame.Size.Y.Scale + Padding)) 
	)
end

function Tools.SizeScrollingFrame(Scroll : ScrollingFrame, Axises)
	Axises = Axises or {"Y"}  

	local AxisValue = {X=0,Y=0} 

	local UIListLayout : UIListLayout = Scroll:FindFirstChildWhichIsA("UIListLayout")  
	if not UIListLayout then 
		error("No UIListLayout Child of ScrollingFrame")
	end
	
	local OrginalPadding = UIListLayout.Padding
	
	local UpdatePadding = function() 
		local Width = Scroll.AbsoluteSize.X * OrginalPadding.Scale 
		UIListLayout.Padding = UDim.new(0, Width)
	end
	
	local Update = function() 
		for _,Axis in Axises do 
			AxisValue[Axis] = UIListLayout.AbsoluteContentSize[Axis] + UIListLayout.Padding.Offset
		end 

		Scroll.CanvasSize = UDim2.fromOffset(AxisValue.X, AxisValue.Y)
	end
	
	task.spawn(UpdatePadding)	
	task.defer(Update) 
	Scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdatePadding)
	Scroll.ChildAdded:Connect(Update)
	Scroll.ChildRemoved:Connect(Update)
end

function Tools.AutoScaleLayout(UIListLayout, DontApplyPaddingScaling) 
	local ScrollingFrame : ScrollingFrame = UIListLayout.Parent

	local OrginalCanvasSize = ScrollingFrame.CanvasSize			

	local OriginalYScale = ScrollingFrame.CanvasSize.Y.Scale
	local OriginalYPadding = UIListLayout.Padding.Scale 

	if not ScrollingFrame:IsA("ScrollingFrame") then 
		error("Parent of UIListLayout must be a ScrollingFrame")
	end

	local UpdateExtension = function() 
		local FarthestY = 0 

		for _, Child in ScrollingFrame:GetChildren() do 
			if Child:IsA("GuiObject") and Child.Visible then 
				local GuiObject : GuiObject = Child 
				local ProjectY = GuiObject.AbsolutePosition.Y + (GuiObject.AbsoluteSize.Y * GuiObject.AnchorPoint.Y)

				if ProjectY > FarthestY then FarthestY = ProjectY end 
			end
		end

		local ScaleFactor = FarthestY/ScrollingFrame.AbsoluteSize.Y
		if ScaleFactor == ScaleFactor and ScaleFactor ~= math.inf and ScaleFactor > OriginalYScale then 
			ScrollingFrame.CanvasSize = UDim2.fromScale(0, ScaleFactor)
			
			if DontApplyPaddingScaling then return end 
			UIListLayout.Padding = UDim.new(OriginalYPadding * (1/ScaleFactor) , 0)
		else 
			ScrollingFrame.CanvasSize = UDim2.fromScale(0, OriginalYScale)
			
			if DontApplyPaddingScaling then return end 
			UIListLayout.Padding = UDim.new(OriginalYPadding,0)
		end
	end

	task.defer(UpdateExtension)
	ScrollingFrame.ChildAdded:Connect(UpdateExtension)
	ScrollingFrame:GetAttributeChangedSignal("Update"):Connect(UpdateExtension)
end

function Tools.AutoScaleGrid(UIGridLayout : UIGridLayout)
	local ScrollingFrame : ScrollingFrame = UIGridLayout.Parent
	local SisterPadding : UIPadding = UIGridLayout.Parent:FindFirstChild("UIPadding") 


	if UIGridLayout and SisterPadding and ScrollingFrame then 

		local NonGuiObjectCount = 0 
		for _,Child in ScrollingFrame:GetChildren() do 
			if Child:IsA("GuiObject") == false then 
				NonGuiObjectCount += 1 
			end
		end

		local OrginalCanvasSize = ScrollingFrame.CanvasSize
		local OrginalTopPadding = SisterPadding.PaddingTop
		local OrginalCellPadding = UIGridLayout.CellPadding

		SisterPadding:SetAttribute("OrginalTop", OrginalTopPadding.Scale)

		local DoUpdating = function() 
			local ItemGuiCount = #ScrollingFrame:GetChildren()-NonGuiObjectCount
			local Rows = math.ceil(ItemGuiCount/UIGridLayout.FillDirectionMaxCells)
			if UIGridLayout.FillDirectionMaxCells == 0 then Rows = 0 end

			local PaddingMultiplier = 1 - (SisterPadding.PaddingLeft.Scale + SisterPadding.PaddingRight.Scale)
			local XGridSize =  ScrollingFrame.AbsoluteCanvasSize.X * PaddingMultiplier * UIGridLayout.CellSize.X.Scale
			local YLength = ((XGridSize * 1.1  ) * Rows)/ScrollingFrame.AbsoluteSize.Y  
			local NewYSize = math.max(YLength, OrginalCanvasSize.Y.Scale)

			ScrollingFrame.CanvasSize = UDim2.fromScale(OrginalCanvasSize.X.Scale, NewYSize)

			local DifferenceMultiplier = OrginalCanvasSize.Y.Scale/ScrollingFrame.CanvasSize.Y.Scale
			local ScaleFactor = ScrollingFrame.CanvasSize.Y.Scale/OrginalCanvasSize.Y.Scale

			UIGridLayout.CellPadding = UDim2.fromScale(OrginalCellPadding.X.Scale,OrginalCellPadding.Y.Scale * DifferenceMultiplier)
			SisterPadding.PaddingTop = UDim.new(OrginalTopPadding.Scale * DifferenceMultiplier)	
		end

		ScrollingFrame.ChildAdded:Connect(DoUpdating)
		ScrollingFrame.ChildRemoved:Connect(DoUpdating)
		ScrollingFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(DoUpdating)
	end
end	

function Tools.CreateStrokeScaler(UIStroke: UIStroke) 
	if not UIStroke:GetAttribute("OrginalThickness") then 
		UIStroke:SetAttribute("OrginalThickness",UIStroke.Thickness)
	end
	local OrignalThickness = UIStroke:GetAttribute("OrginalThickness")
	return function() 
		local Size = InterfaceHandler.ScreeenGui.AbsoluteSize  

		local TotalSampled , Total  = 0,0
		for Index=1,#InterfaceHandler.ScalingSampleMode do 
			local SampleIndex = InterfaceHandler.ScalingSampleMode:sub(Index,Index)
			Total += Size[SampleIndex]/InterfaceHandler.TargetScreenSize[SampleIndex]
			TotalSampled += 1 
		end 
		
		
		local AdjustedUnit = Total/TotalSampled
		UIStroke.Thickness =  OrignalThickness * AdjustedUnit 
	end     
end

function Tools.GetScaleFromText(TextGui, FontSize)
	local TextSize = game:GetService("TextService"):GetTextSize(
		TextGui.Text, 
		math.round(FontSize or TextGui.AbsoluteSize.Y), 
		TextGui.Font, 
		Vector2.new(TextGui.AbsoluteSize.X, 1000)
	)

	local UseParentX = TextGui.SizeConstraint == Enum.SizeConstraint.RelativeXX
	return UDim2.new(TextGui.Size.X.Scale, 0, TextSize.Y/TextGui.Parent.AbsoluteSize[UseParentX and "X" or "Y"], 1)
end


function Tools.ScaleDescendantStrokes(ScreenGui, Maid) 
	for _, UIStroke : UIStroke in ScreenGui:GetDescendants() do 
		if UIStroke:IsA("UIStroke") then 
			local StrokeScaler = Tools.CreateStrokeScaler(UIStroke) 
			task.defer(StrokeScaler)

			InterfaceHandler.ScreenSizeChanged:Connect(StrokeScaler)
		end
	end 
end

function Tools.Register(...)
	InterfaceHandler = ... 
end

return Tools
