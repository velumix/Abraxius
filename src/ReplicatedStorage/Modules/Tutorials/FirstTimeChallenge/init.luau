local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local TutorialManager = require(Modules:WaitForChild("TutorialManager"))
local Mince = require(Modules:WaitForChild("Mince"))
local UI = require(Modules:WaitForChild("UI"))
local UIBlip = require(Modules:WaitForChild("UIBlip"))
local UserProfile = require(ReplicatedStorage.Runtime.Source.UserProfile)

local LocalPlayer = Players.LocalPlayer

local Encyclopedia = require(Modules.UI.Components.Encyclopedia)
local SideMenu = require(Modules.UI.Components.SideMenu)
local Store = require(Modules.UI.Components.Store)

local PATHS_FOLDER_NAME = "TutorialPaths"

local AnalyticsFunnelEvent = Mince:GetEvent("AnalyticsFunnel")
local OnboardingStepEvent = AnalyticsFunnelEvent:Extend("OnboardingStep")

local FirstTimeChallenge = {}

local scanController = nil
local cached = {
	Npc = nil,
	Elevator = nil,
	SwimEvent = nil,
}

local function initializeCache()
	scanController = Mince:Get("ScanController")
	cached.SwimEvent = Mince:GetEvent("Swim")

	if Mince.Component and Mince.Component.Get then
		pcall(function()
			cached.Npc = Mince.Component.Get("Npc")
			cached.Elevator = Mince.Component.Get("Elevator")
		end)
	end
end

local function fireOnboardingStep(stepNumber)
	if OnboardingStepEvent then
		OnboardingStepEvent:Fire(stepNumber)
	end
end

local function getTagged(tagName: string)
	local tagged = CollectionService:GetTagged(tagName)
	for _, instance in ipairs(tagged) do
		if instance:IsDescendantOf(Workspace) then
			return instance
		end
	end
	return nil
end

local function getComponent(name)
	if Mince.Component and Mince.Component.Get then
		local ok, component = pcall(function()
			return Mince.Component.Get(name)
		end)
		if ok and component then
			return component
		end
	end

	local ok, component = pcall(function()
		return Mince:Get(name)
	end)

	if ok then
		return component
	end

	return nil
end

local function resolveBasePart(target)
	if not target then
		return nil
	end

	if target:IsA("BasePart") then
		return target
	end

	if target:IsA("Model") then
		return target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart", true)
	end

	return nil
end

local function getPromptFromTarget(target)
	if not target then
		return nil
	end

	if target:IsA("ProximityPrompt") then
		return target
	end

	if target:IsA("Instance") and target.FindFirstChildWhichIsA then
		return target:FindFirstChildWhichIsA("ProximityPrompt", true)
	end

	return nil
end

local function getCharacterRoot()
	local character = LocalPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function selectClosest(components, resolveTarget)
	local root = getCharacterRoot()
	if not root then
		return nil
	end

	local nearest = nil
	local nearestDistance = math.huge

	for _, component in ipairs(components or {}) do
		local candidate = resolveTarget(component)
		local part = resolveBasePart(candidate)
		if part then
			local distance = (part.Position - root.Position).Magnitude
			if distance < nearestDistance then
				nearestDistance = distance
				nearest = part
			end
		end
	end

	return nearest
end

local function getCharacter()
	return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function isNearTarget(target, distance)
	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not target or not root then
		return false
	end
	return (root.Position - target.Position).Magnitude <= (distance or 12)
end

local function findNearestFish()
	local character = LocalPlayer.Character
	if not character or not character.PrimaryPart then
		return nil
	end

	local nearestFish = nil
	local nearestDistance = math.huge
	local playerPos = character.PrimaryPart.Position

	local discoverables = CollectionService:GetTagged("DiscoveryInjector")
	for _, part in ipairs(discoverables) do
		if part:IsA("BasePart") then
			local distance = (part.Position - playerPos).Magnitude
			if distance < nearestDistance and distance < 200 then
				nearestDistance = distance
				nearestFish = part
			end
		end
	end

	return nearestFish
end

local function getScannerTool()
	local character = LocalPlayer.Character
	if character then
		local tool = character:FindFirstChild("Scanner")
		if tool then
			return tool
		end
	end

	local backpack = LocalPlayer:FindFirstChild("Backpack")
	if backpack then
		return backpack:FindFirstChild("Scanner")
	end

	return nil
end

local function getScannerSlotFrame()
	local api = ReplicatedStorage:FindFirstChild("CustomPackAPI")
	if not api or not api:IsA("BindableFunction") then
		return nil
	end

	local ok, result = pcall(function()
		return api:Invoke("GetSlotFrameByToolName", {"Scanner"})
	end)

	if ok then
		return result
	end

	return nil
end

local function spawnPath(pathName, color)
	if not RunService:IsClient() then
		return nil
	end
	local folder = Workspace:FindFirstChild(PATHS_FOLDER_NAME)
	local path = folder and folder:FindFirstChild(pathName)
	if not path then
		return nil
	end

	local attachments = {}
	local beams = {}
	for _, node in ipairs(path:GetChildren()) do
		if node:IsA("BasePart") then
			local attachment = Instance.new("Attachment")
			attachment.Name = "TutorialPathAttachment"
			attachment.Parent = node
			table.insert(attachments, attachment)
		end
	end

	for index = 1, #attachments - 1 do
		local beam = Instance.new("Beam")
		beam.Name = "TutorialPathBeam"
		beam.Width0 = 0.4
		beam.Width1 = 0.4
		beam.Color = ColorSequence.new(color or Color3.fromRGB(90, 220, 255))
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.FaceCamera = true
		beam.TextureSpeed = 3
		beam.Attachment0 = attachments[index]
		beam.Attachment1 = attachments[index + 1]
		beam.Parent = attachments[index]
		table.insert(beams, beam)
	end

	return {
		Destroy = function()
			for _, beam in ipairs(beams) do
				beam:Destroy()
			end
			for _, attachment in ipairs(attachments) do
				attachment:Destroy()
			end
		end
	}
end

local function createBillboard(target, text)
	if not target or not target:IsA("BasePart") then
		return nil
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "TutorialBillboard"
	gui.Size = UDim2.new(0, 140, 0, 40)
	gui.StudsOffset = Vector3.new(0, 2, 0)
	gui.AlwaysOnTop = true
	gui.Parent = target

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 0.2
	label.BackgroundColor3 = Color3.fromRGB(15, 25, 35)
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = text or "Scan this!"
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	return gui
end

local function createHighlight(target, color, alwaysOnTop)
	if not target then
		return nil
	end

	local highlightParent = target
	local highlightAdornee = target

	if target:IsA("Model") then
		highlightParent = target
		highlightAdornee = target
	elseif target:IsA("BasePart") then
		local model = target:FindFirstAncestorOfClass("Model")
		if model then
			highlightParent = model
			highlightAdornee = model
		end
	else
		return nil
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "TutorialHighlight"
	highlight.Adornee = highlightAdornee
	highlight.FillTransparency = 0.6
	highlight.OutlineTransparency = 0.5
	highlight.FillColor = color or Color3.fromRGB(120, 230, 255)
	highlight.OutlineColor = color or Color3.fromRGB(120, 230, 255)
	highlight.DepthMode = alwaysOnTop and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
	highlight.Parent = highlightParent

	local tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local tween = TweenService:Create(highlight, tweenInfo, { FillTransparency = 0.2, OutlineTransparency = 0 })
	tween:Play()

	return highlight
end

local function createCrosshairPrompt(text)
	local gui = LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("ScannerUI")
	if not gui then
		return nil
	end

	local prompt = Instance.new("TextLabel")
	prompt.Name = "TutorialCrosshairPrompt"
	prompt.AnchorPoint = Vector2.new(0.5, 0.5)
	prompt.Position = UDim2.new(0.5, 0, 0.5, 60)
	prompt.Size = UDim2.new(0, 220, 0, 28)
	prompt.BackgroundTransparency = 0.3
	prompt.BackgroundColor3 = Color3.fromRGB(10, 15, 20)
	prompt.TextColor3 = Color3.fromRGB(255, 255, 255)
	prompt.Font = Enum.Font.GothamBold
	prompt.TextSize = 16
	prompt.Text = text or "Click and hold"
	prompt.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = prompt

	return prompt
end

local function getTutorialArrowGui()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	return playerGui:FindFirstChild("TutorialArrowGui")
end

local function createTutorialArrow(target, options)
	if not target or not target:IsA("GuiObject") then
		return nil
	end

	local opts = options or {}
	local gui = getTutorialArrowGui()
	if not gui then
		return nil
	end

	local useSideways = opts.Sideways == true
	if not useSideways then
		local sideMenuGui = target:FindFirstAncestor("SideMenu")
		if sideMenuGui and sideMenuGui:IsA("ScreenGui") then
			useSideways = true
		end
	end

	local frame
	if useSideways then
		frame = gui:FindFirstChild("FrameSideways", true)
	else
		frame = gui:FindFirstChild("Frame", true)
	end
	frame = frame or gui:FindFirstChildWhichIsA("Frame") or gui:FindFirstChild("Frame")
	if not frame then
		return nil
	end

	gui.Enabled = true
	frame.Visible = true
	if useSideways then
		frame.AnchorPoint = opts.AnchorPoint or Vector2.new(0, 0.5)
	else
		frame.AnchorPoint = opts.AnchorPoint or frame.AnchorPoint
	end
	local scale = opts.Scale
	if scale then
		local uiScale = frame:FindFirstChildWhichIsA("UIScale") or frame:FindFirstChild("UIScale")
		if uiScale then
			uiScale.Scale = scale
		end
	end

	local bobAmplitude = opts.BobAmplitude or 6
	local bobDuration = opts.BobDuration or 0.8
	local bobValue = Instance.new("NumberValue")
	bobValue.Name = "TutorialArrowBob"
	bobValue.Value = -bobAmplitude
	local bobTween = TweenService:Create(
		bobValue,
		TweenInfo.new(bobDuration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Value = bobAmplitude }
	)
	bobTween:Play()

	local offset = opts.Offset or Vector2.new(0, 0)
	local attach
	if useSideways then
		offset = opts.SidewaysOffset or offset
		attach = opts.SidewaysAttach or "Right"
	else
		attach = opts.Attach or "Center"
	end
	local sidePadding = opts.SidePadding or 12
	local bobAxis = useSideways and Vector2.new(1, 0) or Vector2.new(0, 1)

	local function updatePosition()
		if not target or not target.Parent then
			if frame then
				frame.Visible = false
			end
			return
		end

		if frame and not frame.Visible then
			frame.Visible = true
		end

		local absPos = target.AbsolutePosition
		local absSize = target.AbsoluteSize
		local pos

		if attach == "Top" then
			pos = Vector2.new(absPos.X + absSize.X / 2, absPos.Y) + Vector2.new(0, -6)
		elseif attach == "Right" then
			pos = Vector2.new(absPos.X + absSize.X + sidePadding, absPos.Y + absSize.Y / 2)
		else
			pos = Vector2.new(absPos.X + absSize.X / 2, absPos.Y + absSize.Y / 2)
		end

		if useSideways then
			pos = pos + Vector2.new(opts.SidewaysXOffset or (absSize.X), opts.SidewaysYOffset or (absSize.Y * 1.4))
		end

		pos = pos + offset + Vector2.new(bobValue.Value * bobAxis.X, bobValue.Value * bobAxis.Y)
		frame.Position = UDim2.fromOffset(pos.X, pos.Y)
	end

	updatePosition()
	local connection = RunService.RenderStepped:Connect(updatePosition)

	return {
		Hide = function()
			if connection then
				connection:Disconnect()
				connection = nil
			end
			if bobTween then
				bobTween:Cancel()
				bobTween = nil
			end
			if bobValue then
				bobValue:Destroy()
				bobValue = nil
			end
			if frame then
				frame.Visible = false
			end
			if gui then
				gui.Enabled = false
			end
		end,
	}
end

local function getEncyclopediaCloseButton()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local gui = playerGui:FindFirstChild("Encyclopedia")
	if not gui then
		return nil
	end
	local main = gui:FindFirstChild("Main")
	local infoContainer = main and main:FindFirstChild("InfoContainer")
	local title = infoContainer and infoContainer:FindFirstChild("Title")
	local exitFrame = title and title:FindFirstChild("ExitButton")
	return exitFrame and exitFrame:FindFirstChild("Exit")
end

local function getBeamTemplate()
	local anyBeam = script:FindFirstChildWhichIsA("Beam", true)
	if anyBeam then
		return anyBeam
	end

	return nil
end

local function createBeamToTarget(fromPart, toPart)
	if not RunService:IsClient() then
		return nil
	end
	if not fromPart or not toPart or not fromPart:IsA("BasePart") or not toPart:IsA("BasePart") then
		return nil
	end

	local a0 = Instance.new("Attachment")
	a0.Name = "TutorialBeamSource"
	a0.Parent = fromPart

	local a1 = Instance.new("Attachment")
	a1.Name = "TutorialBeamTarget"
	a1.Parent = toPart

	local template = getBeamTemplate()
	local beam = template and template:Clone() or Instance.new("Beam")
	beam.Name = "TutorialBeam"
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.TextureMode = Enum.TextureMode.Stretch
	if not template then
		beam.Width0 = 0.15
		beam.Width1 = 0.15
		beam.Color = ColorSequence.new(Color3.fromRGB(100, 220, 255))
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.FaceCamera = true
	end
	local function updateTextureLength()
		if not (fromPart and toPart and fromPart.Parent and toPart.Parent) then
			return
		end
		local distance = (fromPart.Position - toPart.Position).Magnitude
		beam.TextureLength = math.max(distance * 3.3, 0.1)
	end

	updateTextureLength()
	local heartbeatConnection = RunService.Heartbeat:Connect(updateTextureLength)
	beam.Parent = fromPart

	return {
		Destroy = function()
			if heartbeatConnection then
				heartbeatConnection:Disconnect()
				heartbeatConnection = nil
			end
			beam:Destroy()
			a0:Destroy()
			a1:Destroy()
		end
	}
end

local function hasStoreKeyword(text)
	if type(text) ~= "string" then
		return false
	end
	local lower = text:lower()
	return lower:find("store") ~= nil or lower:find("shop") ~= nil or lower:find("gear") ~= nil
end

local function isStoreNpc(component)
	if not component then
		return false
	end

	local data = component.NpcData
	local instance = component.Instance

	if data and data.Name == "Eyekoruu" then
		return true
	end

	if instance and instance.Name == "Eyekoruu" then
		return true
	end

	if data and data.Options then
		for _, option in pairs(data.Options) do
			if type(option) == "table" then
				for _, text in ipairs(option) do
					if hasStoreKeyword(text) then
						return true
					end
				end
			elseif hasStoreKeyword(option) then
				return true
			end
		end
	end

	if data and data.Interaction and data.Interaction.Talk then
		for _, group in pairs(data.Interaction.Talk) do
			if type(group) == "table" then
				for _, entry in pairs(group) do
					if type(entry) == "table" and hasStoreKeyword(entry[1]) then
						return true
					end
				end
			end
		end
	end

	return false
end

local function getShopTarget()
	local npcComponent = cached.Npc or getComponent("Npc")
	if npcComponent and npcComponent.GetAll then
		local storeNpcs = {}
		for _, component in ipairs(npcComponent:GetAll()) do
			if isStoreNpc(component) then
				table.insert(storeNpcs, component)
			end
		end

		local target = selectClosest(storeNpcs, function(component)
			return component.PromptPart or component.Root or component.Instance
		end)

		if target then
			return target
		end
	end

	return getTagged("Tutorial_Shop")
		or Workspace:FindFirstChild("Shop")
		or Workspace:FindFirstChild("Store")
		or Workspace:FindFirstChild("GearShop")
end

local function getDiveDoorTarget()
	local elevatorComponent = cached.Elevator or getComponent("Elevator")
	if elevatorComponent and elevatorComponent.GetAll then
		local target = selectClosest(elevatorComponent:GetAll(), function(component)
			return component.Instance
		end)
		if target then
			return target
		end
	end

	return getTagged("Elevator")
end

local function getElevatorDiveButton()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local gui = playerGui:FindFirstChild("ElevatorSystem")
	if not gui then
		return nil
	end

	local container = gui:FindFirstChild("ElevatorContainer")
	local content = container and container:FindFirstChild("Content")
	local floorContainer = content and content:FindFirstChild("FloorContainer")
	return floorContainer and floorContainer:FindFirstChild("DiveButton")
end

local function hasStarterSet(ownedItems)
	local entry = ownedItems and ownedItems["Starter Diving Set"]
	return entry and entry.Owned
end

function FirstTimeChallenge.Create()
	local scanCompleted = false
	local scannerSelected = false
	local shopPromptUsed = false
	local swimCompleted = false

	local tutorial = TutorialManager.new({
		Id = "FirstTimeChallenge",
		Name = "First Steps",
		Steps = {
			{
				Type = "notification",
				Message = "Welcome! Let\'s scan your first creature.",
				Duration = 4,
			},
			{
				Type = "notification",
				Message = "Select your scanner tool from the hotbar.",
				Duration = 6,
				OnStart = function(tut)
					local slotFrame = getScannerSlotFrame()
					local blip = slotFrame and UIBlip.new(slotFrame)
					if blip then
						table.insert(tut.Connections, function()
							blip:Destroy()
						end)
					end

					local arrow = slotFrame and createTutorialArrow(slotFrame, {
						Attach = "Top",
						Offset = Vector2.new(0, 8),
						Scale = 0.75,
					})
					if arrow then
						table.insert(tut.Connections, function()
							arrow:Hide()
						end)
					end

					scannerSelected = false
					local character = getCharacter()
					local fired = false

					local function checkEquipped()
						if character and character:FindFirstChild("Scanner") then
							scannerSelected = true
							if not fired then
								fired = true
								fireOnboardingStep(3)
							end
						end
					end

					checkEquipped()
					local connection = character.ChildAdded:Connect(function(child)
						if child:IsA("Tool") and child.Name == "Scanner" then
							scannerSelected = true
							if not fired then
								fired = true
								fireOnboardingStep(3)
							end
						end
					end)
					table.insert(tut.Connections, connection)
				end,
				Condition = function()
					return scannerSelected == true
				end,
			},
			{
				Type = "notification",
				Message = "Aim at the nearest fish. Scan this!",
				Duration = 6,
				OnStart = function(tut)
					local fish = findNearestFish()
					local character = getCharacter()
					local source = character:FindFirstChild("HumanoidRootPart")
					local beam = fish and source and createBeamToTarget(source, fish)
					local billboard = fish and createBillboard(fish, "Scan this!")
					local highlight = fish and createHighlight(fish, Color3.fromRGB(120, 230, 255))
					local prompt = createCrosshairPrompt("Click and hold")

					if beam then
						table.insert(tut.Connections, function()
							beam:Destroy()
						end)
					end

					if billboard then
						table.insert(tut.Connections, function()
							billboard:Destroy()
						end)
					end

					if highlight then
						table.insert(tut.Connections, function()
							highlight:Destroy()
						end)
					end

					if prompt then
						table.insert(tut.Connections, function()
							prompt:Destroy()
						end)
					end
				end,
				Condition = function()
					local scan = scanController
					return scan and scan.Locked
				end,
			},
			{
				Type = "notification",
				Message = "Lock on, then connect the dots!",
				Duration = 6,
				OnStart = function(tut)
					local scan = scanController
					local beam = nil
					local billboard = nil
					local highlight = nil
					local active = true

					local function destroyBeam()
						if beam then
							beam:Destroy()
							beam = nil
						end
						if billboard then
							billboard:Destroy()
							billboard = nil
						end
						if highlight then
							highlight:Destroy()
							highlight = nil
						end
					end

					local function refreshBeam()
						if beam then
							return
						end
						local fish = findNearestFish()
						local character = getCharacter()
						local source = character:FindFirstChild("HumanoidRootPart")
						local targetPart = resolveBasePart(fish)
						if source and targetPart then
							beam = createBeamToTarget(source, targetPart)
							billboard = createBillboard(targetPart, "Scan this!")
							highlight = createHighlight(targetPart, Color3.fromRGB(120, 230, 255))
						end
					end

					table.insert(tut.Connections, function()
						active = false
						destroyBeam()
					end)

					task.spawn(function()
						while active and not scanCompleted do
							local currentScan = scanController
							local locked = currentScan and currentScan.Locked
							local enabled = currentScan and currentScan.Enabled
							local tool = getScannerTool()
							if not locked and enabled and tool then
								refreshBeam()
							else
								destroyBeam()
							end
							task.wait(0.25)
						end
						destroyBeam()
					end)

					if scan and scan.CreatureLocked then
						local fired = false
						local connection = scan.CreatureLocked:Connect(function()
							UI.Notify("Now connect the dots in order!", "Info", 5)
							if not fired then
								fired = true
								fireOnboardingStep(4)
							end
						end)
						table.insert(tut.Connections, connection)
					end

					scanCompleted = false
					lastScannedId = nil
					if scan and scan.FishScanned then
						local connection = scan.FishScanned:Connect(function(fishId)
							lastScannedId = fishId
							scanCompleted = true
						end)
						table.insert(tut.Connections, connection)
					end
				end,
				Condition = function()
					return scanCompleted == true
				end,
			},
			{
				Type = "notification",
				Message = "First scan complete! Achievement unlocked.",
				Duration = 4,
				NotificationType = "Success",
				OnStart = function()
					fireOnboardingStep(5)
					task.delay(1, function()
						local character = LocalPlayer.Character
						local humanoid = character and character:FindFirstChild("Humanoid")
						if humanoid then
							humanoid:UnequipTools()
						end
					end)
				end,
			},
			{
				Type = "notification",
				Message = "Open your Encyclopedia to see your discovery.",
				Duration = 6,
				OnStart = function(tut)
					local sideButton = SideMenu.GetButtonInstance and SideMenu.GetButtonInstance("Encyclopedia")
					local target = sideButton
					if not target then
						local scan = scanController
						target = scan and scan.Buttons and scan.Buttons.Encyclopedia
					end

					local fired = false
					local blip = target and UIBlip.new(target)
					if blip then
						table.insert(tut.Connections, function()
							blip:Destroy()
						end)
					end

					local arrow = target and createTutorialArrow(target, {
						Attach = "Top",
						Offset = Vector2.new(0, 15),
						Scale = 0.45,
					})
					if arrow then
						table.insert(tut.Connections, function()
							arrow:Hide()
						end)
					end

					if Encyclopedia.IsVisible and Encyclopedia.IsVisible() then
						fired = true
						fireOnboardingStep(6)
					else
						local connection = UI.ScreenShown:Connect(function(name, isVisible)
							if name == "Encyclopedia" and isVisible and not fired then
								fired = true
								fireOnboardingStep(6)
							end
						end)
						table.insert(tut.Connections, connection)
					end
				end,
				Condition = function()
					return Encyclopedia.IsVisible and Encyclopedia.IsVisible()
				end,
			},
			{
				Type = "notification",
				Message = "Great! Close the Encyclopedia to continue.",
				Duration = 5,
				OnStart = function(tut)
					fireOnboardingStep(7)

					local closeButton = getEncyclopediaCloseButton()
					if closeButton then
						local blip = UIBlip.new(closeButton)
						if blip then
							table.insert(tut.Connections, function()
								blip:Destroy()
							end)
						end
					end
				end,
				Condition = function()
					return not (Encyclopedia.IsVisible and Encyclopedia.IsVisible())
				end,
			},
			{
				Type = "marker",
				Message = "Head to the shop to upgrade your gear.",
				Target = getShopTarget,
				MarkerIcon = "rbxassetid://16911678024",
				MarkerColor = Color3.fromRGB(120, 230, 255),
				OnStart = function(tut)
					shopPromptUsed = false
					local fired = false

					local path = spawnPath("FirstTimeToShop", Color3.fromRGB(120, 230, 255))
					if path then
						table.insert(tut.Connections, function()
							path:Destroy()
						end)
					end

					local target = getShopTarget()
					local root = getCharacterRoot()
					local targetPart = resolveBasePart(target)
					local beam = root and targetPart and createBeamToTarget(root, targetPart)
					local highlight = targetPart and createHighlight(targetPart, Color3.fromRGB(120, 230, 255), true)

					if beam then
						table.insert(tut.Connections, function()
							beam:Destroy()
						end)
					end
					if highlight then
						table.insert(tut.Connections, function()
							highlight:Destroy()
						end)
					end
					local prompt = getPromptFromTarget(target)
					if prompt then
						local connection = prompt.Triggered:Connect(function(player)
							if player == LocalPlayer then
								shopPromptUsed = true
								if not fired then
									fired = true
									fireOnboardingStep(8)
								end
							end
						end)
						table.insert(tut.Connections, connection)
					end

					task.spawn(function()
						while not fired do
							if (Store.IsVisible and Store.IsVisible()) or shopPromptUsed then
								fired = true
								fireOnboardingStep(8)
								return
							end
							task.wait(0.25)
						end
					end)
				end,
				Condition = function()
					return (Store.IsVisible and Store.IsVisible()) or shopPromptUsed
				end,
			},
			{
				Type = "notification",
				Message = "Buy the Starter Diving Set.",
				Duration = 8,
				OnStart = function(tut)
					local fired = false
					local button = Store.GetItemButton and Store.GetItemButton("Starter Diving Set")
					local blip = button and UIBlip.new(button)
					if blip then
						table.insert(tut.Connections, function()
							blip:Destroy()
						end)
					end

					task.spawn(function()
						while not fired do
							local profile = UserProfile.LocalProfile
							local owned = profile and profile.OwnedItems
							if hasStarterSet(owned) then
								fired = true
								return
							end
							task.wait(0.5)
						end
					end)
				end,
				Condition = function()
					local profile = UserProfile.LocalProfile
					local owned = profile and profile.OwnedItems
					return hasStarterSet(owned)
				end,
			},
			{
				Type = "notification",
				Message = "First gear unlocked!",
				Duration = 4,
				NotificationType = "Success",
				OnStart = function()
					fireOnboardingStep(9)
				end,
			},
			{
				Type = "marker",
				Message = "Head to the elevator to continue exploring.",
				Target = getDiveDoorTarget,
				MarkerIcon = "rbxassetid://16911678024",
				MarkerColor = Color3.fromRGB(90, 200, 255),
				OnStart = function(tut)
					local fired = false

					local target = getDiveDoorTarget()
					local root = getCharacterRoot()
					local targetPart = resolveBasePart(target)
					local beam = root and targetPart and createBeamToTarget(root, targetPart)
					local highlight = targetPart and createHighlight(targetPart, Color3.fromRGB(90, 200, 255))

					if beam then
						table.insert(tut.Connections, function()
							beam:Destroy()
						end)
					end
					if highlight then
						table.insert(tut.Connections, function()
							highlight:Destroy()
						end)
					end

					local swimConnection = LocalPlayer:GetAttributeChangedSignal("Swimming"):Connect(function()
						if LocalPlayer:GetAttribute("Swimming") and not fired then
							fired = true
							fireOnboardingStep(10)
						end
					end)
					table.insert(tut.Connections, swimConnection)

					if cached.SwimEvent and cached.SwimEvent.Event then
						local swimEventConnection = cached.SwimEvent.Event:Connect(function()
							if not fired then
								fired = true
								fireOnboardingStep(10)
							end
						end)
						table.insert(tut.Connections, swimEventConnection)
					end
				end,
				Condition = function()
					return LocalPlayer:GetAttribute("Swimming") == true
				end,
			},

			{
				Type = "notification",
				Message = "Select 'Dive' to enter the water.",
				Duration = 6,
				OnStart = function(tut)
					if LocalPlayer:GetAttribute("Swimming") then
						swimCompleted = true
						return
					end

					local button = getElevatorDiveButton()
					local blip = button and UIBlip.new(button)
					if blip then
						table.insert(tut.Connections, function()
							blip:Destroy()
						end)
					end

					local arrow = button and createTutorialArrow(button, {
						Attach = "Top",
						Offset = Vector2.new(0, 15),
						Scale = 0.45,
					})
					if arrow then
						local function hideArrow()
							arrow:Hide()
						end

						table.insert(tut.Connections, hideArrow)

						if button then
							if button.Activated then
								table.insert(tut.Connections, button.Activated:Connect(hideArrow))
							elseif button.MouseButton1Click then
								table.insert(tut.Connections, button.MouseButton1Click:Connect(hideArrow))
							end
						end
					end

					local swimAttributeConnection = LocalPlayer:GetAttributeChangedSignal("Swimming"):Connect(function()
						if LocalPlayer:GetAttribute("Swimming") then
							swimCompleted = true
						end
					end)
					table.insert(tut.Connections, swimAttributeConnection)

					if cached.SwimEvent and cached.SwimEvent.Event then
						local connection = cached.SwimEvent.Event:Connect(function()
							swimCompleted = true
						end)
						table.insert(tut.Connections, connection)
					elseif Mince.GetEvent then
						local evt = Mince:GetEvent("Swim")
						if evt and evt.Event then
							local connection = evt.Event:Connect(function()
								swimCompleted = true
							end)
							table.insert(tut.Connections, connection)
						end
					end
				end,

				Condition = function()
					return swimCompleted or LocalPlayer:GetAttribute("Swimming") == true
				end,

			},
		}
	})

	return tutorial
end

function FirstTimeChallenge.Start()
	initializeCache()
	local tutorial = FirstTimeChallenge.Create()
	if tutorial and tutorial.TutorialCompleted then
		tutorial.TutorialCompleted:Connect(function()
			fireOnboardingStep(11)
			local settings = UI and UI.Settings
			if settings and settings.SetFirstTimeChallengeCompleted then
				settings:SetFirstTimeChallengeCompleted(true)
			end
		end)
	end
	fireOnboardingStep(2)
	tutorial:Start()
	return tutorial
end

return FirstTimeChallenge
