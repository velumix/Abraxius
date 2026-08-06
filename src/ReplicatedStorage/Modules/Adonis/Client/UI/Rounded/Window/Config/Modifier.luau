service = nil;
client = nil;

local function ignore(child)
	if child.Parent and child.Parent.Parent then
		if child.Parent.Parent.Name == "TabFrame" then
			--return true;
		end
	end

	if child.BackgroundTransparency == 1 then
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
		local rounder = service.New("UICorner",{
			CornerRadius = UDim.new(0, 8);
			Parent = child;
		});
		
		if child.Name == "__TITLEBUTTON" then
			rounder.CornerRadius = UDim.new(1, 0);
		elseif child:IsA("ScrollingFrame") then
			child.BackgroundTransparency = 1;
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
		if child:IsA("GuiObject") and not child:FindFirstChildOfClass("UICorner") and not ignore(child) then
			apply(child);
		end
	end)
end