service = nil;
client = nil;

local function ignore(child)
	--if child.Parent and child.Parent.Parent then
	--	if child.Parent.Parent.Name == "TabFrame" then
			--return true;
	--	end
	--end

	--if child.BackgroundTransparency == 1 then
		--return true;
	--end
	if child.Name == "Title" then
		return true;
	end
end

local function propChange(child, target, list)
	for i in next,list do
		if target[i] ~= child[i] then
			target[i] = child[i];
		end
	end

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

		if child:IsA("TextButton") then
			child.BackgroundColor3 = Color3.fromRGB(150, 150, 150);
			child.BorderColor3 = Color3.fromRGB(50, 70, 160);--child.BorderColor3 = Color3.fromRGB(00, 50, 220);
			child.BorderSizePixel = 1;

			--[[local rounder = service.New("UICorner",{
				CornerRadius = UDim.new(0, 8);
				Parent = child;
			});--]]

		elseif child:IsA("GuiObject") then
			child.BackgroundColor3 = Color3.fromRGB(170, 170, 170);
			child.BorderColor3 = Color3.fromRGB(100, 100, 100);
			child.BorderSizePixel = 1;
		end

		if child:IsA("TextButton") or child:IsA("TextLabel") or child:IsA("TextBox") then
			child.TextColor3 = Color3.fromRGB(10, 10, 10);
			child.TextStrokeTransparency = 1;
			
			if child:IsA("TextBox") then
				child.PlaceholderColor3 = Color3.fromRGB(100, 100, 100)
			end
		end

		if child.Parent and child.Parent.Parent then
			if child.Parent.Parent.Name == "TabFrame" then
				child.BackgroundColor3 = Color3.fromRGB(150, 150, 150);
			end
		end

		if child:IsA("ScrollingFrame") then
			--child.BackgroundTransparency = 1;
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

			--child.BackgroundTransparency = 1;

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

	for i,child in ipairs(gui:GetDescendants()) do
		if child:IsA("GuiObject") and not ignore(child) then
			apply(child);
		end
	end
end