-- PoseTuner: a dev-only panel to dial in a knife skin's INVENTORY VIEWPORT pose (rx/ry/rz/dist used by
-- ReplicatedStorage.KnifeIcon). Toggle with K (or the on-screen button). Studio-only.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

if not RunService:IsStudio() then return end  -- dev-only, never for live players

local KnifeSkinManager = require(ReplicatedStorage:WaitForChild("KnifeSkinManager"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ===== state: the pose being edited, and which skin =====
local DEFAULT_SKIN = "blackholedagger"
local state = { rx = 95, ry = 221, rz = -240, dist = 3.5 }
local currentSkinId = DEFAULT_SKIN

local function seedFromSkin(skinId)
	local def = KnifeSkinManager.getSkin(skinId)
	local p = def and def.pose
	state.rx = (p and p.rx) or 95
	state.ry = (p and p.ry) or 221
	state.rz = (p and p.rz) or -240
	state.dist = (p and p.dist) or 3.5
end

local gui = Instance.new("ScreenGui")
gui.Name = "PoseTunerGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 200
gui.Parent = playerGui

local toggleBtn = Instance.new("TextButton")
toggleBtn.Name = "ToggleBtn"
toggleBtn.Size = UDim2.fromOffset(150, 40)
toggleBtn.Position = UDim2.new(1, -162, 0, 90)
toggleBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
toggleBtn.BackgroundTransparency = 0.1
toggleBtn.Text = "Pose Tuner (K)"
toggleBtn.TextColor3 = Color3.fromRGB(235, 235, 245)
toggleBtn.TextSize = 18
toggleBtn.Font = Enum.Font.GothamMedium
toggleBtn.ZIndex = 10
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 6)
toggleBtn.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.fromScale(0.92, 0.92)
panel.Position = UDim2.fromScale(0.04, 0.04)
panel.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
panel.BackgroundTransparency = 0.05
panel.BorderSizePixel = 0
panel.Visible = false
panel.ZIndex = 10
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
panel.Parent = gui

local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseBtn"
closeBtn.Size = UDim2.fromOffset(40, 40)
closeBtn.Position = UDim2.new(1, -48, 0, 8)
closeBtn.BackgroundColor3 = Color3.fromRGB(170, 60, 70)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize = 24
closeBtn.Font = Enum.Font.GothamBold
closeBtn.ZIndex = 20
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
closeBtn.Parent = panel
closeBtn.Activated:Connect(function() panel.Visible = false end)

local pad = Instance.new("UIPadding", panel)
pad.PaddingTop = UDim.new(0, 18); pad.PaddingBottom = UDim.new(0, 18)
pad.PaddingLeft = UDim.new(0, 18); pad.PaddingRight = UDim.new(0, 18)

local layout = Instance.new("UIListLayout", panel)
layout.FillDirection = Enum.FillDirection.Vertical
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 8)

local order = 0
local function nextOrder() order += 1; return order end

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 34)
title.BackgroundTransparency = 1
title.Text = "Knife Viewport Pose Tuner"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 26
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 11
title.LayoutOrder = nextOrder()
title.Parent = panel

local idBox = Instance.new("TextBox")
idBox.Size = UDim2.new(1, 0, 0, 40)
idBox.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
idBox.TextColor3 = Color3.fromRGB(235, 235, 245)
idBox.PlaceholderText = "skin id (e.g. blackholedagger)"
idBox.Text = currentSkinId
idBox.TextSize = 20
idBox.Font = Enum.Font.Gotham
idBox.ClearTextOnFocus = false
idBox.ZIndex = 11
idBox.LayoutOrder = nextOrder()
Instance.new("UICorner", idBox).CornerRadius = UDim.new(0, 6)
idBox.Parent = panel

local preview = Instance.new("ImageLabel")
preview.Name = "Preview"
preview.Size = UDim2.new(1, 0, 0.38, 0)
preview.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
preview.BorderSizePixel = 0
preview.Image = ""
preview.ZIndex = 11
preview.LayoutOrder = nextOrder()
Instance.new("UICorner", preview).CornerRadius = UDim.new(0, 8)
preview.Parent = panel

local VIEW_DIR = Vector3.new(0.5, 0.32, 0.78).Unit
local function renderPreview()
	local existing = preview:FindFirstChild("KnifeViewport")
	if existing then existing:Destroy() end
	local template = KnifeSkinManager.getTemplate(currentSkinId)
	if not template then return end
	local srcHandle = template:FindFirstChild("Handle")
	if not srcHandle or not srcHandle:IsA("BasePart") then return end
	local vp = Instance.new("ViewportFrame")
	vp.Name = "KnifeViewport"
	vp.Size = UDim2.fromScale(1, 1)
	vp.BackgroundTransparency = 1
	vp.ZIndex = 12
	vp.Parent = preview
	local handle = srcHandle:Clone()
	handle.Anchored = true
	handle.CanCollide = false
	for _, c in ipairs(handle:GetChildren()) do
		if not (c:IsA("SpecialMesh") or c:IsA("Decal") or c:IsA("Texture") or c:IsA("DataModelMesh")) then
			c:Destroy()
		end
	end
	handle.CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(state.rx), math.rad(state.ry), math.rad(state.rz))
	handle.Parent = vp
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.CFrame = CFrame.lookAt(VIEW_DIR * state.dist, Vector3.new(0, 0, 0))
	cam.Parent = vp
	vp.CurrentCamera = cam
	vp.Ambient = Color3.fromRGB(180, 180, 190)
	vp.LightColor = Color3.fromRGB(255, 255, 255)
	vp.LightDirection = Vector3.new(-0.4, -1, -0.6).Unit
end

local outBox = Instance.new("TextBox")
outBox.Name = "OutBox"
outBox.Size = UDim2.new(1, 0, 0, 56)
outBox.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
outBox.TextColor3 = Color3.fromRGB(150, 230, 150)
outBox.TextSize = 20
outBox.Font = Enum.Font.Code
outBox.TextWrapped = true
outBox.TextXAlignment = Enum.TextXAlignment.Left
outBox.TextYAlignment = Enum.TextYAlignment.Top
outBox.ClearTextOnFocus = false
outBox.TextEditable = false
outBox.Text = ""
outBox.ZIndex = 11
outBox.LayoutOrder = nextOrder()
Instance.new("UICorner", outBox).CornerRadius = UDim.new(0, 6)
outBox.Parent = panel

local function updateOutput()
	outBox.Text = string.format("pose = { rx = %d, ry = %d, rz = %d, dist = %.2f },",
		math.floor(state.rx + 0.5), math.floor(state.ry + 0.5), math.floor(state.rz + 0.5), state.dist)
end

local function makeRow(field, min, max, coarse, fine, isFloat)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 64)
	row.BackgroundTransparency = 1
	row.ZIndex = 11
	row.LayoutOrder = nextOrder()
	row.Parent = panel
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0.5, 0, 0, 28)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = Color3.fromRGB(220, 220, 230)
	lbl.TextSize = 22
	lbl.Font = Enum.Font.GothamMedium
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.ZIndex = 12
	lbl.Parent = row
	local function refreshLabel()
		if isFloat then
			lbl.Text = string.format("%s:  %.2f", field, state[field])
		else
			lbl.Text = string.format("%s:  %d", field, math.floor(state[field] + 0.5))
		end
	end
	local function setValue(v)
		v = math.clamp(v, min, max)
		state[field] = v
		refreshLabel()
		renderPreview()
		updateOutput()
	end
	local btnDefs = {
		{ t = "--", d = -coarse }, { t = "-", d = -fine },
		{ t = "+", d = fine }, { t = "++", d = coarse },
	}
	local bw = 0.12
	for i, def in ipairs(btnDefs) do
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(bw, -3, 0, 30)
		b.Position = UDim2.new(0.52 + (i - 1) * bw, 0, 0, 0)
		b.BackgroundColor3 = Color3.fromRGB(55, 55, 72)
		b.TextColor3 = Color3.fromRGB(235, 235, 245)
		b.Text = def.t
		b.TextSize = 22
		b.Font = Enum.Font.GothamBold
		b.ZIndex = 12
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
		b.Parent = row
		b.Activated:Connect(function() setValue(state[field] + def.d) end)
	end
	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, 0, 0, 12)
	track.Position = UDim2.new(0, 0, 0, 44)
	track.BackgroundColor3 = Color3.fromRGB(60, 60, 78)
	track.BorderSizePixel = 0
	track.ZIndex = 12
	Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
	track.Parent = row
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Color3.fromRGB(120, 170, 255)
	fill.BorderSizePixel = 0
	fill.ZIndex = 13
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
	fill.Parent = track
	local function refreshFill()
		local a = (state[field] - min) / (max - min)
		fill.Size = UDim2.new(math.clamp(a, 0, 1), 0, 1, 0)
	end
	local dragging = false
	local function setFromX(px)
		local abs = track.AbsolutePosition.X
		local w = track.AbsoluteSize.X
		local a = math.clamp((px - abs) / math.max(w, 1), 0, 1)
		local v = min + a * (max - min)
		if not isFloat then v = math.floor(v + 0.5) end
		setValue(v)
		refreshFill()
	end
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true; setFromX(input.Position.X)
		end
	end)
	track.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFromX(input.Position.X)
		end
	end)
	refreshLabel(); refreshFill()
	return { refresh = function() refreshLabel(); refreshFill() end }
end

local rows = {}
rows.rx = makeRow("rx", -360, 360, 15, 1, false)
rows.ry = makeRow("ry", -360, 360, 15, 1, false)
rows.rz = makeRow("rz", -360, 360, 15, 1, false)
rows.dist = makeRow("dist", 1, 12, 0.5, 0.1, true)

local function loadSkin(skinId)
	local def = KnifeSkinManager.getSkin(skinId)
	if not def then
		outBox.Text = "no skin with id '" .. tostring(skinId) .. "'"
		return
	end
	currentSkinId = skinId
	seedFromSkin(skinId)
	for _, r in pairs(rows) do r.refresh() end
	renderPreview()
	updateOutput()
end

idBox.FocusLost:Connect(function(enter)
	local id = idBox.Text:lower():gsub("%s", "")
	if not KnifeSkinManager.getSkin(id) then
		for _, s in ipairs(KnifeSkinManager.SKINS) do
			if s.name:lower() == idBox.Text:lower() then id = s.id; break end
		end
	end
	idBox.Text = id
	loadSkin(id)
end)

local function setOpen(open)
	panel.Visible = open
end
toggleBtn.Activated:Connect(function() setOpen(not panel.Visible) end)
UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.K then setOpen(not panel.Visible) end
end)

loadSkin(DEFAULT_SKIN)
setOpen(true)

print("[PoseTuner] ready -- press K to toggle. Edits the inventory viewport pose (rx/ry/rz/dist).")
