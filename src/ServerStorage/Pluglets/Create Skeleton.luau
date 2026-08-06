return function(plugin)
	-- Write any code here, don't worry about returning anything.
	local CoreGui = game:GetService("CoreGui")
	local Selection = game:GetService("Selection")
	local SelectedFish = Selection:Get()[1]
	
	
	local Attachments = {}
	local BoneCount = 0
	local PrimaryPart = SelectedFish.PrimaryPart
	local Conn
	
	for _, v in SelectedFish:GetDescendants() do
		
		if v:HasTag("DiscoveryInjector") then
			PrimaryPart = v
		end
	end
	
	local function onChildAdded(Child)
		if Child:IsA("Attachment") then
			Child:ClearAllChildren()
	
			BoneCount += 1
			local OldName = Child.Name
			Child.Name = tostring(BoneCount)
	
			if BoneCount > 1 then
				local PreviousBone = PrimaryPart:FindFirstChild(OldName)
				if PreviousBone then
					local ObjectValue = Instance.new("ObjectValue")
					ObjectValue.Name = "Link"
					ObjectValue.Value = PreviousBone
					ObjectValue.Parent = Child
				end
			end
	
			table.insert(Attachments, Child)
		end
	end
	
	local FirstAttachment = Instance.new("Attachment")
	FirstAttachment.Visible = true
	FirstAttachment.Name = "1"
	FirstAttachment.Parent = PrimaryPart
	table.insert(Attachments, FirstAttachment)
	BoneCount = 1
	
	Conn = PrimaryPart.ChildAdded:Connect(onChildAdded)
	
	local ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = "ScreenGui"
	ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	ScreenGui.Parent = CoreGui
	
	local TextButton = Instance.new("TextButton")
	TextButton.Name = "TextButton"
	TextButton.Position = UDim2.new(0.432341, 0, 0.888789, 0)
	TextButton.Size = UDim2.new(0, 200, 0, 50)
	TextButton.BackgroundColor3 = Color3.new(1, 1, 1)
	TextButton.BorderSizePixel = 0
	TextButton.Text = "SAVE"
	TextButton.TextColor3 = Color3.new(0, 0, 0)
	TextButton.TextSize = 14
	TextButton.FontFace = Font.new(
		"rbxasset://fonts/families/SourceSansPro.json",
		Enum.FontWeight.Regular,
		Enum.FontStyle.Normal
	)
	TextButton.Parent = ScreenGui
	
	local function printTable(tbl, indent)
		indent = indent or 0
		local indentStr = string.rep("  ", indent)
		local output = "{\n"
		local isEmpty = true
	
		for key, value in tbl do
			isEmpty = false
			local keyStr = string.format("[\"%s\"]", tostring(key))
			if typeof(key) == "number" then
				keyStr = ("[%d]"):format(key)
			end
	
			local lineIndent = string.rep("  ", indent + 1)
	
			if type(value) == "table" then
				local isSubEmpty = next(value) == nil
				if isSubEmpty then
					output = output .. lineIndent .. keyStr .. " = {},\n"
				else
					output = output .. lineIndent .. keyStr .. " = " .. printTable(value, indent + 1) .. ",\n"
				end
			else
				if typeof(value) == "Vector3" then
					output = output .. lineIndent .. keyStr .. " = Vector3.new(" .. tostring(value) .. "),\n"
				else
					output = output .. lineIndent .. keyStr .. " = " .. tostring(value) .. ",\n"
				end
			end
		end
	
		if isEmpty then
			return "{}"
		end
	
		output = output .. indentStr .. "}"
		if indent == 0 then
			print(output)
		end
		return output
	end
	
	TextButton.MouseButton1Click:Connect(function()
		local SkeletalData = {}
		for i, attachment in Attachments do
			local links = attachment:GetChildren()
			local bone = {
				Position = attachment.Position,
				Links = {}
			}
	
			for _, link in ipairs(links) do
				if link:IsA("ObjectValue") and link.Value then
					table.insert(bone.Links, link.Value.Name)
				end
			end
	
			table.insert(SkeletalData, bone)
		end
	
		for i, currentBone in SkeletalData do
			for otherBoneIndex, crossBone in SkeletalData do
				for _, linkName in crossBone.Links do
					if linkName == tostring(i) then
						table.insert(currentBone.Links, otherBoneIndex)
					end
				end
			end
		end
		print(("\n"):rep(30))
		printTable(SkeletalData)
	
		Conn:Disconnect()
		for _, attachment in Attachments do
			if attachment and attachment.Parent then
				attachment:Destroy()
			end
		end
		ScreenGui:Destroy()
	end)
end
