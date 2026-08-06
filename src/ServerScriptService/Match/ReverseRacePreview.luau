local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ReverseRacePreview = {}

local function getHUDRemote()
	local remotes = ReplicatedStorage:FindFirstChild("GameRemotes")
	local remote = remotes and remotes:FindFirstChild("ReverseRaceHUD")
	return (remote and remote:IsA("RemoteEvent")) and remote or nil
end

local function setHunterRoomLighting(players, enabled)
	local remote = getHUDRemote()
	if not remote then
		return
	end
	
	for _, player in ipairs(players) do
		if player.Parent then
			remote:FireClient(player, { hunterRoomLighting = enabled })
		end
	end
end

local function getRoom()
	local room = Workspace:FindFirstChild("HuntersRoom")
	if not room then
		return nil, nil
	end
	local pedestal = room.PrimaryPart or room:FindFirstChildWhichIsA("BasePart", true)
	return room, pedestal
end

local function hunterSpots(pedestal, count)
	local spots = {}
	local center = pedestal.Position
	local baseY = center.Y - pedestal.Size.Y / 2
	local radius = math.max(14, pedestal.Size.X, pedestal.Size.Z) + 10
	for i = 1, count do
		local angle = (i - 1) / math.max(count, 1) * math.pi * 2
		local pos = Vector3.new(center.X + math.cos(angle) * radius, baseY + 3, center.Z + math.sin(angle) * radius)
		spots[i] = CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z))
	end
	return spots
end

local function makeClone(target)
	local char = target.Character
	if not char then
		return nil
	end
	local wasArchivable = char.Archivable
	char.Archivable = true
	local clone = char:Clone()
	char.Archivable = wasArchivable
	if not clone then
		return nil
	end
	clone.Name = "PreviewClone"
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		elseif d:IsA("BaseScript") or d:IsA("Highlight") then
			d:Destroy()
		end
	end
	local hum = clone:FindFirstChildOfClass("Humanoid")
	if hum then
		hum:ChangeState(Enum.HumanoidStateType.Physics)
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	
	local head = clone:FindFirstChild("Head") or clone:FindFirstChild("HumanoidRootPart")
	if head then
		local bb = Instance.new("BillboardGui")
		bb.Name = "PreviewNameTag"
		bb.Adornee = head
		bb.Size = UDim2.fromScale(7, 1.6)
		bb.StudsOffset = Vector3.new(0, 2.5, 0)
		bb.AlwaysOnTop = true
		bb.MaxDistance = 150
		bb.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = target.DisplayName
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextScaled = true
		label.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2.5
		stroke.Color = Color3.fromRGB(0, 0, 0)
		stroke.Parent = label
		label.Parent = bb
		bb.Parent = head
	end
	
	return clone
end

local function placeHunterInRoom(player, cframe, isActive)
	for _ = 1, 6 do
		if not (player and player.Parent) or (isActive and not isActive()) then
			return
		end
		
		local char, root
		local deadline = os.clock() + 6
		while os.clock() < deadline do
			if isActive and not isActive() then
				return
			end
			local c = player.Character
			local r = c and c:FindFirstChild("HumanoidRootPart")
			local h = c and c:FindFirstChildOfClass("Humanoid")
			if r and h and h.Health > 0 then
				char, root = c, r
				break
			end
			if not player.Parent then
				return
			end
			task.wait(0.1)
		end
		if not (char and root and root.Parent) then
			task.wait(0.2)
			continue
		end
		
		local streamed = false
		task.spawn(function()
			pcall(function()
				player:RequestStreamAroundAsync(cframe.Position, 48)
			end)
			streamed = true
		end)
		local streamDeadline = os.clock() + 5
		while not streamed and os.clock() < streamDeadline do
			task.wait(0.1)
		end
		
		if isActive and not isActive() then
			return
		end
		
		if player.Character == char and root.Parent then
			local wasAnchored = root.Anchored
			root.Anchored = true
			pcall(function()
				char:PivotTo(cframe)
			end)
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			root.Anchored = wasAnchored
			task.wait(0.25)
			if player.Character == char and root.Parent and (root.Position - cframe.Position).Magnitude <= 16 then
				return true
			end
		else
			task.wait(0.2)
		end
	end
	return false
end

function ReverseRacePreview.showTarget(target, hunters, placedSet)
	local room, pedestal = getRoom()
	if not pedestal then
		warn("[ReverseRacePreview] workspace.HuntersRoom with a PrimaryPart not found")
		return function() end
	end
	
	local clone = makeClone(target)
	if clone then
		clone.Parent = room
		local ok = pcall(function()
			local bboxCF, size = clone:GetBoundingBox()
			local desiredBottomY = pedestal.Position.Y + pedestal.Size.Y / 2
			local currentBottomY = bboxCF.Position.Y - size.Y / 2
			local delta =
				Vector3.new(pedestal.Position.X - bboxCF.Position.X, desiredBottomY - currentBottomY, pedestal.Position.Z - bboxCF.Position.Z)
			clone:PivotTo(clone:GetPivot() + delta)
		end)
		if not ok then
			clone:PivotTo(pedestal.CFrame * CFrame.new(0, pedestal.Size.Y / 2 + 3, 0))
		end
	end
	
	local active = true
	local spots = hunterSpots(pedestal, #hunters)
	for i, h in ipairs(hunters) do
		local spot = spots[i]
		if spot then
			task.spawn(function()
				local placed = placeHunterInRoom(h, spot, function()
					return active
				end)
				if placed and placedSet then
					placedSet[h] = true
				end
				if not placed and active and h.Parent then
					warn("[ReverseRacePreview] failed to place hunter in preview room: " .. h.Name)
				end
			end)
		end
	end
	setHunterRoomLighting(hunters, true)
	
	return function()
		active = false
		setHunterRoomLighting(hunters, false)
		if clone then
			clone:Destroy()
		end
	end
end

return ReverseRacePreview
