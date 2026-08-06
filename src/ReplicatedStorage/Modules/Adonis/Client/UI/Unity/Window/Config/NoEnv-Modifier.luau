client,service = nil, nil

local function ignore(child)
--[[	if child.Parent and child.Parent.Parent then

	end


	if child.BackgroundTransparency == 1 then
		return true;
	end]]
	return false
end

local function CircleClick(Button, X, Y)
	local duration = 0.5
	task.spawn(function()
		local effect = Instance.new("ImageLabel", Button)
		effect.AnchorPoint = Vector2.new(0.5, 0.5)
		effect.BorderSizePixel = 0
		effect.ZIndex = Button.ZIndex + 2
		effect.BackgroundTransparency = 1
		effect.ImageTransparency = 0.96
		effect.Image = "rbxasset://textures/whiteCircle.png"
		local rounder = Instance.new("UICorner", effect); rounder.CornerRadius = UDim.new(0,8)
		effect.Position = UDim2.new(0.5, 0, 0.5, 0)
		effect:TweenSize(UDim2.new(0, Button.AbsoluteSize.X * 2.5, 0, Button.AbsoluteSize.X * 2.5), Enum.EasingDirection.Out, Enum.EasingStyle.Linear, duration)
		wait(duration)
		for i = 1, 10 do
			wait(0.04)
			effect.ImageTransparency += 0.1
		end
		effect:Destroy()
	end)

end


local function propChange(child, target, list)
	for i in next,list do
		if target[i] ~= child[i] then
			target[i] = child[i];
		end
	end--lollo was here yes my code is messy

	if child.ZIndex == 1 then
		child.ZIndex = 2;
	end

	target.ZIndex = child.ZIndex-1;
end

return function(data, env)
	if env then
		setfenv(1, env)
	end

	local gui = script.Parent.Parent;--data.GUI;


	local function apply(child)
		if not child then return end

		if child:IsA("TextButton") or child:IsA("ImageButton") then
			child.ClipsDescendants = true
			child.AutoButtonColor = false
			child.Activated:Connect(function()
				CircleClick(child:GetObject())
			end)
		end



		if not child:IsA("TextLabel") and not child:IsA("ImageLabel") and not child:FindFirstChildOfClass("UICorner") then
			local rounder = service.New("UICorner",{
				CornerRadius = UDim.new(0,5);
				Parent = child;
			});

		end


		if child:IsA("TextLabel") and not child:FindFirstChildOfClass("UICorner") then

			local rounder = service.New("UICorner",{
				CornerRadius = UDim.new(0,6);
				Parent = child;
			});
			-- well how do i convert size to precise offset because i am lazy
			child.BackgroundColor3 = Color3.fromRGB(18, 18, 18)

		end



		if child:IsA("ScrollingFrame") then
			if child.Parent and child.Parent.Name == "Frames" then child.BackgroundTransparency = 1; end
			child.BottomImage = "rbxasset://textures/ui/Scroll/scroll-bottom.png"
			child.MidImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
			child.TopImage = "rbxasset://textures/ui/Scroll/scroll-top.png"
			child.ScrollBarImageTransparency = 0.75
			child.ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255)

			--local propList = {
			--	Size = true;
			--	Visible = true;
			--	Position = true;
			--	BackgroundTransparency = true;
			--	BackgroundColor3 = true;
			--	BorderColor3 = true;
			--	Rotation = true;
			--	SizeConstraint = true;
			--}

			--local frame = service.New("Frame");
			--propChange(child, frame, propList)

			child.BackgroundTransparency = 1; --why not

			--child.Changed:Connect(function(p)
			--	if p ~= "BackgroundTransparency" then
			--		propChange(child, frame, propList);
			--	end
			--end)


			--frame.Parent = child.Parent;
		end
	end

	gui.DescendantAdded:Connect(function(child)
		if child:IsA("GuiObject") and not ignore(child) then
			apply(child);
		end
	end)
end