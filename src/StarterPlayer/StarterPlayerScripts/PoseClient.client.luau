local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

local Knit = require(ReplicatedStorage.Packages.Knit)
local SetPoseSignal = nil
local PoseSyncSignal = nil
local PoseRejectedSignal = nil
local pendingSetPose = {}

local function fireSetPose(poseName)
	if SetPoseSignal then
		SetPoseSignal:Fire(poseName)
	else
		table.insert(pendingSetPose, poseName)
	end
end

local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local RoleAnnounce = Remotes:WaitForChild("RoleAnnounce")
local InRound = Remotes:WaitForChild("InRound")
local InventoryUpdate = Remotes:WaitForChild("InventoryUpdate")
local PoseConfig = require(ReplicatedStorage:WaitForChild("PoseConfig"))
local UISounds = require(ReplicatedStorage:WaitForChild("UISounds"))

local slots = pg:WaitForChild("Hud"):WaitForChild("BottomButtons")
local poseBtn = slots:FindFirstChild("PoseButton", true)
if not poseBtn then
	repeat
		task.wait()
		poseBtn = slots:FindFirstChild("PoseButton", true)
	until poseBtn
end
local poseButtonGui = pg:WaitForChild("PoseButtonGui")
local poseMenu = poseButtonGui:WaitForChild("Pose")
local poseButtonsFrame = poseMenu:WaitForChild("PoseButtons")
local poseCloseBtn = poseMenu:FindFirstChild("CloseButton")

local menuScale = poseMenu:FindFirstChildOfClass("UIScale")
if not menuScale then
	menuScale = Instance.new("UIScale")
	menuScale.Parent = poseMenu
end
local MENU_TWEEN = TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local MENU_CLOSE_TWEEN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local menuTween = nil

local touchOnly = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
local emulatingTouch = RunService:IsStudio() and UserInputService.TouchEnabled
local isMobile = touchOnly or emulatingTouch

local function setLayered(label, text)
	if not label then
		return
	end
	label.Text = text
	local top = label:FindFirstChild("Top")
	if top and top:IsA("TextLabel") then
		top.Text = text
	end
end
local poseKeybind = poseBtn:FindFirstChild("Keybind")
if poseKeybind then
	if isMobile then
		poseKeybind.Visible = false
	else
		poseKeybind.Visible = true
		setLayered(poseKeybind, "(V)")
	end
end

local NAME_TO_ID = {
	["Default"] = "none",
	["Crouch"] = "crouch",
	["Crawl"] = "crawl",
	["Raise Hands"] = "raisehands",
	["T-Pose"] = "tpose",
}

local POSE_COOLDOWN = 1
local lastPoseChange = 0

local cooldownLabel = Instance.new("TextLabel")
cooldownLabel.Name = "PoseCooldownError"
cooldownLabel.AnchorPoint = Vector2.new(0.5, 1)
cooldownLabel.Position = UDim2.new(0.5, 0, 0, -6)
cooldownLabel.Size = UDim2.new(1, 0, 0, 28)
cooldownLabel.BackgroundTransparency = 1
cooldownLabel.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
cooldownLabel.TextScaled = true
cooldownLabel.TextColor3 = Color3.fromRGB(255, 70, 70)
cooldownLabel.Text = ""
cooldownLabel.Visible = false
cooldownLabel.ZIndex = 50
local cooldownStroke = Instance.new("UIStroke", cooldownLabel)
cooldownStroke.Color = Color3.fromRGB(60, 0, 0)
cooldownStroke.Thickness = 2
local cooldownTSC = Instance.new("UITextSizeConstraint", cooldownLabel)
cooldownTSC.MaxTextSize = 18
cooldownLabel.Parent = poseMenu

local cooldownConn = nil
local function showCooldownError()
	cooldownLabel.Visible = true
	if cooldownConn then
		cooldownConn:Disconnect()
	end
	cooldownConn = RunService.Heartbeat:Connect(function()
		local remaining = POSE_COOLDOWN - (os.clock() - lastPoseChange)
		if remaining <= 0 then
			cooldownLabel.Visible = false
			if cooldownConn then
				cooldownConn:Disconnect()
				cooldownConn = nil
			end
		else
			cooldownLabel.Text = "(" .. tostring(math.ceil(remaining)) .. "s)"
		end
	end)
end

local currentPose = nil
local prevPose = nil

local suppressLocalAnimations
local activePoseTargets = nil
local remotePoseTargetsByPlayer = {}

local function applyPoseTransforms()
	if not activePoseTargets then
		return
	end

	for _, pair in ipairs(activePoseTargets) do
		local joint = pair[1]
		local target = pair[2] or CFrame.identity
		if joint and joint.Parent then
			joint.Transform = target
		end
	end
end

local ACTIVE_IMAGE = "rbxassetid://134236090170398"
local IDLE_IMAGE = "rbxassetid://91994756048527"
local equippedLoadout = { table.unpack(PoseConfig.DEFAULT_EQUIPPED) }
local buttonTemplate
for _, b in ipairs(poseButtonsFrame:GetChildren()) do
	if b:IsA("ImageButton") then
		buttonTemplate = b:Clone()
		break
	end
end

local function refreshButtons()
	for _, btn in ipairs(poseButtonsFrame:GetChildren()) do
		if btn:IsA("ImageButton") then
			local id = btn:GetAttribute("PoseId")
			if id then
				local active = (id == "none") and (currentPose == nil) or (currentPose == id)
				btn.Image = active and ACTIVE_IMAGE or IDLE_IMAGE
			end
		end
	end
end

local function setButtonLabel(btn, text)
	local lbl = btn:FindFirstChild("PoseName")
	if not lbl then
		lbl = Instance.new("TextLabel")
		lbl.Name = "PoseName"
		lbl.Size = UDim2.fromScale(1, 1)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.FredokaOne
		lbl.TextScaled = true
		lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
		lbl.ZIndex = 5
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = Color3.fromRGB(0, 0, 0)
		stroke.Parent = lbl
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0.18, 0)
		pad.PaddingBottom = UDim.new(0.18, 0)
		pad.Parent = lbl
		lbl.Parent = btn
	end
	setLayered(lbl, text)
end

local myRole = nil
local inRound = false
local function canPose()
	return inRound and myRole == "Hider"
end

local function openMenu()
	if menuTween then
		menuTween:Cancel()
	end
	menuScale.Scale = 0
	poseMenu.Visible = true
	menuTween = TweenService:Create(menuScale, MENU_TWEEN, { Scale = 1 })
	menuTween:Play()
end

local function closeMenu()
	if not poseMenu.Visible then
		return
	end
	if menuTween then
		menuTween:Cancel()
	end
	menuTween = TweenService:Create(menuScale, MENU_CLOSE_TWEEN, { Scale = 0 })
	menuTween:Play()
	local thisTween = menuTween
	thisTween.Completed:Connect(function(state)
		if thisTween == menuTween and state == Enum.PlaybackState.Completed then
			poseMenu.Visible = false
		end
	end)
end
local function clearPose(reason)
	if currentPose then
		currentPose = nil
		fireSetPose("none")
		if suppressLocalAnimations then
			suppressLocalAnimations(false)
		end
		player:SetAttribute("Posed", false)
		refreshButtons()
	end
end
local function updateVisibility()
	local ok = canPose()
	poseBtn.Visible = ok
	if not ok then
		closeMenu()
		-- Reverse Race temporarily removes hider eligibility while handing the
		-- disguised character off between target and hunter roles. Keep the pose
		-- on that character until the mode has cloned/replaced it.
		if player:GetAttribute("ReverseRacePreserveDisguise") ~= true then
			clearPose("not eligible")
		end
	end
end

local function selectPose(id)
	local now = os.clock()
	if now - lastPoseChange < POSE_COOLDOWN then
		UISounds.error()
		showCooldownError()
		return
	end
	if id == "none" then
		if currentPose ~= nil then
			lastPoseChange = now
			currentPose = nil
			fireSetPose("none")
			if suppressLocalAnimations then
				suppressLocalAnimations(false)
			end
			player:SetAttribute("Posed", false)
			UISounds.click()
			refreshButtons()
			closeMenu()
		end
		return
	end
	lastPoseChange = now
	UISounds.click()
	prevPose = currentPose
	if currentPose == id then
		currentPose = nil
		fireSetPose("none")
		if suppressLocalAnimations then
			suppressLocalAnimations(false)
		end
		player:SetAttribute("Posed", false)
	else
		currentPose = id
		fireSetPose(id)
		if suppressLocalAnimations then
			suppressLocalAnimations(true)
		end
		player:SetAttribute("Posed", true)
	end
	refreshButtons()
end

local function rebuildPoseButtons()
	for _, b in ipairs(poseButtonsFrame:GetChildren()) do
		if b:IsA("ImageButton") then
			b:Destroy()
		end
	end
	local order = 0
	local function addButton(id, name)
		local btn = buttonTemplate and buttonTemplate:Clone() or Instance.new("ImageButton")
		btn.Name = "Pose_" .. id
		btn:SetAttribute("PoseId", id)
		btn.LayoutOrder = order
		btn.Image = IDLE_IMAGE
		btn.Active = true
		order += 1
		setButtonLabel(btn, name)
		btn.Parent = poseButtonsFrame
		UISounds.bindTween(btn)
		btn.MouseEnter:Connect(function()
			UISounds.hover()
		end)
		btn.Activated:Connect(function()
			if not canPose() then
				return
			end
			selectPose(id)
		end)
	end
	addButton("none", "Default")
	for _, id in ipairs(equippedLoadout) do
		if id ~= "none" then
			addButton(id, PoseConfig.displayName(id))
		end
	end
	refreshButtons()
end
rebuildPoseButtons()

InventoryUpdate.OnClientEvent:Connect(function(state)
	if type(state) ~= "table" or type(state.poses) ~= "table" then
		return
	end
	local loadout = state.poses.equipped
	if type(loadout) ~= "table" then
		return
	end
	local changed = (#loadout ~= #equippedLoadout)
	if not changed then
		for i = 1, #loadout do
			if loadout[i] ~= equippedLoadout[i] then
				changed = true
				break
			end
		end
	end
	if changed then
		equippedLoadout = loadout
		rebuildPoseButtons()
	end
end)

poseMenu.Visible = false
refreshButtons()

RoleAnnounce.OnClientEvent:Connect(function(role)
	myRole = role
	updateVisibility()
end)
InRound.OnClientEvent:Connect(function(active)
	inRound = active and true or false
	if not inRound then
		myRole = nil
	end
	updateVisibility()
end)
player:GetAttributeChangedSignal("ReverseRacePreserveDisguise"):Connect(function()
	if player:GetAttribute("ReverseRacePreserveDisguise") ~= true then
		updateVisibility()
	end
end)
updateVisibility()

local function togglePoseMenu()
	UISounds.click()
	if not canPose() then
		return
	end
	if poseMenu.Visible then
		closeMenu()
	else
		openMenu()
	end
end
poseBtn.MouseButton1Click:Connect(togglePoseMenu)
UISounds.bindTween(poseBtn)
poseBtn.MouseEnter:Connect(function()
	UISounds.hover()
end)

local gamepadPoseControl = Instance.new("BindableEvent")
gamepadPoseControl.Name = "GamepadPoseControl"
gamepadPoseControl.Parent = poseButtonGui
gamepadPoseControl.Event:Connect(function(cmd)
	if cmd == "open" then
		if canPose() and not poseMenu.Visible then
			openMenu()
		end
	elseif cmd == "close" then
		if poseMenu.Visible then
			closeMenu()
		end
	else
		togglePoseMenu()
	end
end)

if poseCloseBtn then
	UISounds.bindTween(poseCloseBtn)
	poseCloseBtn.MouseEnter:Connect(function()
		UISounds.hover()
	end)
	poseCloseBtn.MouseButton1Click:Connect(function()
		UISounds.close()
		closeMenu()
	end)
end

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then
		return
	end
	if input.KeyCode == Enum.KeyCode.V then
		togglePoseMenu()
	end
end)

local animSuppressConn = nil
suppressLocalAnimations = function(on)
	local char = player.Character
	local animate = char and char:FindFirstChild("Animate")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if on then
		if animate then
			animate.Disabled = true
		end

		local animator = hum and hum:FindFirstChildOfClass("Animator")
		if animator then
			for _, tr in ipairs(animator:GetPlayingAnimationTracks()) do
				tr:Stop(0)
			end
		end

		if not animSuppressConn then
			animSuppressConn = RunService.Stepped:Connect(function()
				if not currentPose then
					return
				end
				local c = player.Character
				local h = c and c:FindFirstChildOfClass("Humanoid")
				local a = h and h:FindFirstChildOfClass("Animator")
				if a then
					for _, tr in ipairs(a:GetPlayingAnimationTracks()) do
						tr:Stop(0)
					end
				end
				applyPoseTransforms()
			end)
		end
	else
		activePoseTargets = nil
		if animSuppressConn then
			animSuppressConn:Disconnect()
			animSuppressConn = nil
		end
		if animate and not player:GetAttribute("PositionLocked") then
			animate.Disabled = false
		end
	end
end

player.CharacterAdded:Connect(function()
	currentPose = nil
	if suppressLocalAnimations then
		suppressLocalAnimations(false)
	end
	player:SetAttribute("Posed", false)
	refreshButtons()
end)

Knit.OnStart()
	:andThen(function()
		local svc = Knit.GetService("PoseService")
		SetPoseSignal = svc.SetPose
		PoseSyncSignal = svc.PoseSync
		PoseRejectedSignal = svc.PoseRejected

		local function applyTargetsToCharacter(targets)
			for _, pair in ipairs(targets) do
				local joint = pair[1]
				local target = pair[2] or CFrame.identity
				if joint and joint.Parent then
					joint.Transform = target
				end
			end
		end

		PoseSyncSignal:Connect(function(targetPlayer, payload)
			if targetPlayer == player then
				activePoseTargets = payload
			elseif not payload or #payload == 0 then
				remotePoseTargetsByPlayer[targetPlayer] = nil
			else
				remotePoseTargetsByPlayer[targetPlayer] = payload
			end
		end)

		RunService.Stepped:Connect(function()
			for targetPlayer, targets in pairs(remotePoseTargetsByPlayer) do
				if targetPlayer == player or not targetPlayer.Character then
					continue
				end
				applyTargetsToCharacter(targets)
			end
		end)

		local function clearRemoteForPlayer(p)
			remotePoseTargetsByPlayer[p] = nil
		end
		Players.PlayerRemoving:Connect(clearRemoteForPlayer)
		local function hookCharacterCleanup(p)
			p.CharacterAdded:Connect(function()
				clearRemoteForPlayer(p)
			end)
		end
		for _, p in ipairs(Players:GetPlayers()) do
			hookCharacterCleanup(p)
		end
		Players.PlayerAdded:Connect(hookCharacterCleanup)

		PoseRejectedSignal:Connect(function(refusedId)
			if currentPose == refusedId then
				currentPose = prevPose

				if suppressLocalAnimations then
					suppressLocalAnimations(currentPose ~= nil)
				end
				player:SetAttribute("Posed", currentPose ~= nil)
				refreshButtons()
			end
			UISounds.error()
			cooldownLabel.Text = "No room to crawl here"
			cooldownLabel.Visible = true
			task.delay(2, function()
				if cooldownLabel.Text == "No room to crawl here" then
					cooldownLabel.Visible = false
				end
			end)
		end)

		for _, name in ipairs(pendingSetPose) do
			SetPoseSignal:Fire(name)
		end
		pendingSetPose = {}
	end)
	:catch(warn)
