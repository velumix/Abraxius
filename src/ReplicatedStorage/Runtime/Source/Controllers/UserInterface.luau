local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local function getCurrentCamera()
	return workspace.CurrentCamera
end

local Mince = require(ReplicatedStorage.Modules.Mince)
local UI = require(ReplicatedStorage.Modules.UI)

local TimeToComplete = 3
local CameraOffset = Vector3.new(.5, .5, -2)
local NpcOffset = Vector3.new(3, 1.5, 0)
local CONTROLLER_ACTION = "NpcDialogueSelectionNav"
local THUMBSTICK_DEADZONE = 0.3
local STROKE_COLOR = Color3.fromRGB(0, 170, 255)
local STROKE_THICKNESS = 1
local TEXT_GUI_CLASSES = {
	TextLabel = true,
	TextButton = true,
	TextBox = true,
}

local UserInterface = {}

function UserInterface:_isGamepad(inputType)
	if not inputType then
		return false
	end

	local value = inputType.Value
	return value >= Enum.UserInputType.Gamepad1.Value and value <= Enum.UserInputType.Gamepad8.Value
end

function UserInterface:_isGamepadInput(inputType)
	return self:_isGamepad(inputType)
end

function UserInterface:_onInputType(lastInputType)
	local usingGamepad = self:_isGamepad(lastInputType)
	self.GamepadInputActive = usingGamepad
	if usingGamepad then
		self:_ensureController()
	else
		self:_disableController()
	end
end

function UserInterface:_ensureController()
	if not self.Interface or not self.Interface.Enabled then
		return
	end

	if not self.GamepadInputActive then
		return
	end

	if #self.Selections == 0 then
		return
	end

	self:_enableController()
end

function UserInterface:_prepSelection(selection)
	local target = self:_strokeTarget(selection)
	local stroke = target and target:FindFirstChild("ControllerStroke")
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Name = "ControllerStroke"
		stroke.Thickness = STROKE_THICKNESS
		stroke.Color = STROKE_COLOR
		stroke.LineJoinMode = Enum.LineJoinMode.Round
		stroke.Enabled = false
		stroke.Parent = target or selection
	end
end

function UserInterface:_strokeTarget(selection)
	if not selection or not selection:IsA("GuiObject") then
		return selection
	end

	if TEXT_GUI_CLASSES[selection.ClassName] then
		return selection
	end

	local textChild = selection:FindFirstChildWhichIsA("TextButton", true)
		or selection:FindFirstChildWhichIsA("TextLabel", true)
		or selection:FindFirstChildWhichIsA("TextBox", true)

	if textChild then
		return textChild
	end

	return selection
end

function UserInterface:_bindController()
	if self.ControllerActionBound then
		return
	end

	ContextActionService:BindAction(CONTROLLER_ACTION, function(...)
		return self:_handlePad(...)
	end, false,
	Enum.KeyCode.DPadUp,
	Enum.KeyCode.DPadDown,
	Enum.KeyCode.Thumbstick1,
	Enum.KeyCode.ButtonA
	)
	self.ControllerActionBound = true
end

function UserInterface:_enableController()
	if #self.Selections == 0 then
		return
	end

	self:_bindController()

	if not self.GamepadInputActive then
		self.ControllerSelectionActive = false
		self:_updateHighlight()
		return
	end

	self.ControllerSelectionActive = true
	self.ControllerSelectionIndex = math.clamp(self.ControllerSelectionIndex or 1, 1, #self.Selections)
	self:_updateHighlight()
end

function UserInterface:_disableController(shouldUnbind)
	if shouldUnbind and self.ControllerActionBound then
		ContextActionService:UnbindAction(CONTROLLER_ACTION)
		self.ControllerActionBound = false
	end

	self.ControllerSelectionActive = false
	self.ControllerSelectionIndex = nil
	self._thumbstickNeutral = true
	self:_updateHighlight()
end

function UserInterface:_updateHighlight()
	for index, selection in ipairs(self.Selections) do
		if selection and selection.Parent then
			local holder = self:_strokeTarget(selection)
			local stroke = holder and holder:FindFirstChild("ControllerStroke")
			if stroke then
				stroke.Enabled = self.ControllerSelectionActive and index == self.ControllerSelectionIndex
			end
		end
	end
end

function UserInterface:_stepSelection(delta)
	if not self.ControllerSelectionActive then
		return
	end

	if #self.Selections == 0 then
		return
	end

	local newIndex = self.ControllerSelectionIndex + delta
	if newIndex < 1 then
		newIndex = #self.Selections
	elseif newIndex > #self.Selections then
		newIndex = 1
	end

	self.ControllerSelectionIndex = newIndex
	self:_updateHighlight()
end

function UserInterface:_activateSelection()
	if not self.ControllerSelectionActive then
		return
	end

	local selection = self.Selections[self.ControllerSelectionIndex]
	if not selection or not selection.Parent then
		return
	end

	local selectionValue = selection:GetAttribute("NpcSelectionValue") or selection.Text
	if selectionValue then
		self:HandleSelection(selectionValue, self.CurrentIndex, self.CurrentNpcData)
	end
end

function UserInterface:_handleStick(inputState, inputObject)
	if inputState == Enum.UserInputState.Change then
		local magnitude = math.abs(inputObject.Position.Y)
		if magnitude < THUMBSTICK_DEADZONE then
			self._thumbstickNeutral = true
			return Enum.ContextActionResult.Sink
		end

		if not self._thumbstickNeutral then
			return Enum.ContextActionResult.Sink
		end

		self._thumbstickNeutral = false
		if inputObject.Position.Y > 0 then
			self:_stepSelection(1)
		else
			self:_stepSelection(-1)
		end
	elseif inputState == Enum.UserInputState.End then
		self._thumbstickNeutral = true
	end

	return Enum.ContextActionResult.Sink
end


function UserInterface:_handlePad(_, inputState, inputObject)
	if #self.Selections == 0 then
		return Enum.ContextActionResult.Pass
	end

	if not self.GamepadInputActive then
		self.GamepadInputActive = true
		self.ControllerSelectionActive = true
		self.ControllerSelectionIndex = math.clamp(self.ControllerSelectionIndex or 1, 1, #self.Selections)
		self:_updateHighlight()
	end

	if inputObject.KeyCode == Enum.KeyCode.ButtonA then
		if inputState == Enum.UserInputState.Begin then
			self:_activateSelection()
		end
		return Enum.ContextActionResult.Sink
	elseif inputObject.KeyCode == Enum.KeyCode.DPadUp then
		if inputState == Enum.UserInputState.Begin then
			self:_stepSelection(-1)
		end
		return Enum.ContextActionResult.Sink
	elseif inputObject.KeyCode == Enum.KeyCode.DPadDown then
		if inputState == Enum.UserInputState.Begin then
			self:_stepSelection(1)
		end
		return Enum.ContextActionResult.Sink
	elseif inputObject.KeyCode == Enum.KeyCode.Thumbstick1 then
		return self:_handleStick(inputState, inputObject)
	end

	return Enum.ContextActionResult.Pass
end


function UserInterface:Leave(skipCameraReset, skipScreenShownEvent)
	self:_endNpcConversation()
	self.Interface.Enabled = false

	if self.CurrentPrompt then
		self.CurrentPrompt.Enabled = true
	end

	self:_setCharacterHidden(false)
	self:_setOtherCharactersHidden(false)

	if not skipCameraReset then
		self:FocusNpc()
	else
		self:_releaseCameraControl()
	end

	if self.CurrentSound then
		self.CurrentSound:Stop()
		self.CurrentSound = nil
	end

	if self.Radar then
		self.Radar.Enabled = true
		self.Radar = nil
	end

	self.ClearSelections()

	self.CurrentState = nil

	if not self.TaskTracker.waitingForTask then
		self.TaskTracker.tasks = {}
		self.TaskTracker.tutorialNpc = nil
		self.TaskTracker.tutorialIndex = nil
	end
end

function UserInterface:FocusNpc(Npc)
	local camera = getCurrentCamera()
	if not camera then
		warn("UserInterface:FocusNpc called without an active camera")
		return
	end

	if Npc then
		self._activeNpc = Npc
		self:_acquireCameraControl(Npc)
		self:_setCharacterHidden(true)
		self:_setOtherCharactersHidden(true)
		camera.CameraSubject = Npc
		camera.CameraType = Enum.CameraType.Scriptable
		local npcCFrame = Npc:GetPivot()
		local head = Npc:FindFirstChild("Head")
		local focusPosition = head and head.Position or npcCFrame.Position
		local adjustedNpcPosition = focusPosition + (npcCFrame.LookVector * NpcOffset.X) + (npcCFrame.RightVector * NpcOffset.Z) + (npcCFrame.UpVector * NpcOffset.Y)
		local offsetPosition = adjustedNpcPosition + npcCFrame:VectorToWorldSpace(CameraOffset)
		camera.CFrame = CFrame.new(offsetPosition, focusPosition)
	else
		self:_setCharacterHidden(false)
		self:_setOtherCharactersHidden(false)
		self._activeNpc = nil
		local character = Player.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				camera.CameraSubject = humanoid
			end
		end
		camera.CameraType = Enum.CameraType.Custom
		self:_releaseCameraControl()
	end
end

function UserInterface:Setup()
	self.ScanController = Mince:Get("ScanController")
	self.CCM = Mince:Get("CameraControlManager")
	self.ConversationEvent = Mince:GetEvent("LiveNpcConversation")
	self.ActiveConversationNpc = nil
	self._cameraControlId = nil
	self._cameraControlRequested = false
	self._activeNpc = nil
	self.OtherCharactersHidden = false
	self.OtherCharacterVisibilityCache = {}
	self._otherDescendantConns = {}
	self._otherPlayerCharacterConns = {}
	self._otherPlayersAddedConn = nil
	self._otherPlayersRemovingConn = nil
	self.Selections = {}
	self.GamepadInputActive = false
	self.ControllerSelectionIndex = nil
	self.ControllerSelectionActive = false
	self.ControllerActionBound = false
	self._thumbstickNeutral = true

	local ok, lastInputType = pcall(function()
		return UserInputService:GetLastInputType()
	end)

	if ok then
		self.GamepadInputActive = self:_isGamepadInput(lastInputType)
	else
		self.GamepadInputActive = UserInputService.GamepadEnabled
	end

	UserInputService.LastInputTypeChanged:Connect(function(lastInputType)
		self:_onInputType(lastInputType)
	end)
end

function UserInterface:GameStart()
	self.Interface = PlayerGui:WaitForChild("UserInterface")

	self.MainFrame = self.Interface:WaitForChild("MainFrame")
	self.TextBox = self.MainFrame:WaitForChild("TextBox")
	self.TextLabel = self.TextBox:WaitForChild("TextLabel")
	self.NameLabel = self.Interface:FindFirstChild("NameLabel", true)
	self.SelectionFrame = self.Interface:WaitForChild("SelectionFrame")
	self.SelectionTemplate = self.SelectionFrame:WaitForChild("SelectionTemplate")

	self.SelectionTemplate.Parent = nil

	self.Exit = self.MainFrame:FindFirstChild("Exit", true)

	self.Selections = self.Selections or {}
	self.CurrentState = {}
	self.TaskTracker = {
		tasks = {},
		waitingForTask = nil,
		tutorialNpc = nil,
		tutorialIndex = nil
	}

	self.CharacterHidden = false
	self.CharacterVisibilityCache = {}
	self.CharacterDescendantConn = nil
	self.CharacterAddedConn = Player.CharacterAdded:Connect(function(character)
		if self.CharacterHidden then
			task.defer(function()
				if character.Parent then
					self:_applyCharacterHiddenState(character, true)
				end
			end)
		end
	end)
	self.CharacterRemovingConn = Player.CharacterRemoving:Connect(function()
		if self.CharacterDescendantConn then
			self.CharacterDescendantConn:Disconnect()
			self.CharacterDescendantConn = nil
		end
	end)

	self.ClearSelections = function()
		for _, selection in self.Selections do
			selection:Destroy()
		end
		self.Selections = {}
		self:_disableController(true)
	end

	self.Exit.MouseButton1Click:Connect(function()
		self:Leave()
	end)

	task.spawn(function()
		repeat task.wait() until UI.Loaded
		UI.ScreenShown:Connect(function(componentName, isVisible)
			if not isVisible or componentName == "UserInterface" then
				return
			end

			if not self.Interface.Enabled then
				return
			end

			local skipCameraReset = componentName ~= "Encyclopedia"
			self:Leave(skipCameraReset, true)
		end)
	end)

end

function UserInterface:AnimateSelections()
	local delayTime = 0.2
	for i, selection in ipairs(self.Selections) do
		local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local goals = {
			TextTransparency = 0,
			BackgroundTransparency = 0.5,
		}
		local tween = TweenService:Create(selection, tweenInfo, goals)
		task.delay(delayTime * (i - 1), function()
			tween:Play()
		end)
	end
end

function UserInterface:SetupSelections(Option, NpcData, Index)
	self.ClearSelections()
	local Selections = NpcData.Options[Option]

	if not Selections then
		return warn("Options not found for", Option)
	end

	for i, selection in Selections do
		local Selection = self.SelectionTemplate:Clone()
		Selection.Name = i
		Selection.Text = selection
		Selection.LayoutOrder = i
		Selection.Parent = self.SelectionFrame
		Selection.TextTransparency = 1
		Selection.BackgroundTransparency = 1
		Selection:SetAttribute("NpcSelectionValue", selection)
		self:_prepSelection(Selection)

		Selection.MouseButton1Click:Connect(function()
			self:HandleSelection(selection, Index, NpcData)
		end)

		table.insert(self.Selections, Selection)
	end

	if #self.Selections > 0 then
		self:_bindController()
	end

	if self.GamepadInputActive then
		self:_ensureController()
	else
		self:_updateHighlight()
	end
end

function UserInterface:HandleSelection(selection, Index, NpcData)
	if selection == "Leave" then
		return self:Leave()
	end

	if NpcData.Behavior and NpcData.Behavior[selection] then
		print("Using behavior for:", selection)
		local behavior = NpcData.Behavior[selection]
		local nextIndex = behavior(self, Index, NpcData)
		if nextIndex then
			self.CurrentIndex = nextIndex
			local dialogueText, optionKey = self:GetText(nextIndex, NpcData)
			self:ComposeText(dialogueText, optionKey, NpcData, nextIndex)
		end
		return
	end

	if selection == "Continue" or selection == "Yes" then
		local nextIndex = Index + 1
		if self.CurrentInteraction[nextIndex] then
			self.CurrentIndex = nextIndex
			local dialogueText, optionKey = self:GetText(nextIndex, NpcData)
			self:ComposeText(dialogueText, optionKey, NpcData, nextIndex)
		else
			self:Leave()
		end
	elseif selection == "No" then
		self:Leave()
	end
end

function UserInterface:ReopenTutorial(npc, nextIndex)
	if not npc or not nextIndex then
		return
	end

	local proxy = npc:FindFirstChild("Proxy")
	local prompt = proxy and proxy:FindFirstChildOfClass("ProximityPrompt")

	if proxy and prompt then
		self:NpcInteraction(npc, prompt, nextIndex)
	else
		warn("Cannot reopen tutorial", npc.Name)
	end
end

function UserInterface:GetText(Index, NpcData)
	local CurrentText = self.CurrentInteraction[Index]

	if not CurrentText then
		warn("Text not found at index", Index)
		return nil, nil
	end

	local actualDialogue = CurrentText[1]
	if type(actualDialogue) ~= "table" then
		warn("Expected dialogue table, got:", type(actualDialogue))
		return "", nil
	end

	local npcSoundFolder = SoundService:FindFirstChild(NpcData.Name)
	local Sound = npcSoundFolder and npcSoundFolder:FindFirstChild(self.CurrentIndex..Index)

	if Sound then
		if self.CurrentSound then
			self.CurrentSound:Stop()
		end
		self.CurrentSound = Sound
		self.CurrentSound:Play()
	end

	local optionKey = actualDialogue[2]
	local dialogueText = actualDialogue[1]

	if type(dialogueText) ~= "string" then
		warn("Expected string dialogue, got:", type(dialogueText), dialogueText)
		return "", nil
	end

	return dialogueText, optionKey
end

function UserInterface:ComposeText(TextTarget, optionKey, NpcData, Index)
	if not TextTarget then
		return warn("Text target not provided")
	end

	if type(TextTarget) ~= "string" then
		return warn("Text target must be a string, got:", type(TextTarget), TextTarget)
	end

	self.ClearSelections()

	local Text = TextTarget
	local TextLength = string.len(Text)
	local TimePerCharacter = TimeToComplete / TextLength
	local TimeElapsed = 0
	local textIndex = 1
	local TextLabel = self.TextLabel

	local function UpdateText()
		if textIndex <= TextLength then
			TextLabel.Text = string.sub(Text, 1, textIndex)
			textIndex = textIndex + 1
		else
			return
		end
	end

	local function Update()
		TimeElapsed = TimeElapsed + 1
		if TimeElapsed >= TimePerCharacter then
			UpdateText()
			TimeElapsed = 0
		end
	end

	local function Finish()
		TextLabel.Text = Text
		if optionKey then
			self:SetupSelections(optionKey, NpcData, Index)
			self:AnimateSelections()
		end
	end

	local function Start()
		while textIndex <= TextLength do
			Update()
			task.wait()
		end
		Finish()
	end

	Start()
end

function UserInterface:NpcInteraction(Npc, Prompt, Index)
	local NpcName = Npc.Name
	local NpcData = ReplicatedStorage.Assets.Encyclopedia.Npcs[NpcName]
	if not NpcData then
		return warn("Npc data not found for", NpcName)
	end

	NpcData = require(NpcData)

	if Index == 1 and NpcData.OpenShopOnInteract == true then
		local selection = NpcData.OpenShopSelection
		if not selection and NpcData.Options and NpcData.Options.InitialChoice then
			selection = NpcData.Options.InitialChoice[1]
		end
		local behavior = selection and NpcData.Behavior and NpcData.Behavior[selection]
		if behavior then
			if self.CurrentPrompt and self.CurrentPrompt.Enabled == false then
				self.CurrentPrompt.Enabled = true
			end
			self.CurrentPrompt = Prompt
			self.CurrentPrompt.Enabled = false
			self.CurrentNpcData = NpcData
			self.CurrentIndex = Index
			behavior(self, Index, NpcData)
			return
		end
	end

	self.CurrentInteraction = NpcData.Interaction["Talk"]
	self.CurrentIndex = Index
	self.CurrentNpcData = NpcData
	self:_beginNpcConversation(Npc)

	self.NameLabel.Text = NpcName
	self.TextLabel.Text = ""

	self.Interface.Enabled = true

	if self.CurrentPrompt and self.CurrentPrompt.Enabled == false then
		self.CurrentPrompt.Enabled = true
	end

	self.CurrentPrompt = Prompt
	self.CurrentPrompt.Enabled = false
	self.CurrentProxy = Npc:FindFirstChild("Proxy")

	for _, radar in PlayerGui:GetChildren() do
		if radar:IsA("BillboardGui") then
			if radar.Adornee.Name == "Proxy" then
				self.Radar = radar
				radar.Enabled = false
				break
			end
		end
	end

	UI.ScreenShown:Fire("UserInterface", true)
	self:FocusNpc(Npc)

	local dialogueText, optionKey = self:GetText(Index, NpcData)
	if dialogueText then
		self:ComposeText(dialogueText, optionKey, NpcData, Index)
	end
end

function UserInterface:_acquireCameraControl(npc)
	if not self.CCM then
		self.CCM = Mince:Get("CameraControlManager")
	end

	if not self.CCM then
		return true
	end

	if not self._cameraControlId then
		self._cameraControlId = "NpcDialogue_" .. tostring(Player.UserId)
	end

	local granted = self.CCM:RequestControl(self._cameraControlId, self.CCM.Priority.EXHIBIT, {
		npc = npc,
		context = "NpcDialogue",
	})

	self._cameraControlRequested = true

	return granted
end

function UserInterface:_releaseCameraControl()
	if self.CCM and self._cameraControlId and self._cameraControlRequested then
		self.CCM:ReleaseControl(self._cameraControlId)
	end

	self._cameraControlRequested = false
	self._activeNpc = nil
end

function UserInterface:_getTransparencyState(instance)
	local ok, localValue = pcall(function()
		return instance.LocalTransparencyModifier
	end)

	if ok and typeof(localValue) == "number" then
		return "local", localValue
	end

	if instance:IsA("Decal") or instance:IsA("Texture") then
		return "global", instance.Transparency
	end

	return nil, nil
end

function UserInterface:_applyTransparency(instance, mode, value)
	if mode == "local" then
		pcall(function()
			instance.LocalTransparencyModifier = value
		end)
	elseif mode == "global" then
		instance.Transparency = value
	end
end

function UserInterface:_hideInstance(instance, cache)
	if not instance:IsA("BasePart") and not instance:IsA("Decal") and not instance:IsA("Texture") then
		return
	end

	local mode, current = self:_getTransparencyState(instance)
	if not mode then
		return
	end

	if not cache then
		self.CharacterVisibilityCache = self.CharacterVisibilityCache or {}
		cache = self.CharacterVisibilityCache
	end

	if not cache[instance] then
		cache[instance] = { mode = mode, value = current }
	end

	self:_applyTransparency(instance, mode, 1)
end

function UserInterface:_restoreInstance(instance, cache)
	cache = cache or self.CharacterVisibilityCache
	if not cache then
		return
	end
	local info = cache[instance]
	if not info then
		return
	end

	self:_applyTransparency(instance, info.mode, info.value)
	cache[instance] = nil
end

function UserInterface:_applyCharacterHiddenState(character, hidden)
	if hidden then
		self.CharacterVisibilityCache = self.CharacterVisibilityCache or {}
		for instance in pairs(self.CharacterVisibilityCache) do
			if not instance.Parent then
				self.CharacterVisibilityCache[instance] = nil
			end
		end

		for _, descendant in ipairs(character:GetDescendants()) do
			self:_hideInstance(descendant, self.CharacterVisibilityCache)
		end

		if self.CharacterDescendantConn then
			self.CharacterDescendantConn:Disconnect()
		end
		self.CharacterDescendantConn = character.DescendantAdded:Connect(function(desc)
			self:_hideInstance(desc, self.CharacterVisibilityCache)
		end)
	else
		if self.CharacterDescendantConn then
			self.CharacterDescendantConn:Disconnect()
			self.CharacterDescendantConn = nil
		end

		if self.CharacterVisibilityCache then
			local restoreQueue = {}
			for instance in pairs(self.CharacterVisibilityCache) do
				restoreQueue[#restoreQueue + 1] = instance
			end

			for _, instance in ipairs(restoreQueue) do
				if instance.Parent then
					self:_restoreInstance(instance, self.CharacterVisibilityCache)
				else
					self.CharacterVisibilityCache[instance] = nil
				end
			end
		end
	end
end

function UserInterface:_setCharacterHidden(hidden)
	if self.CharacterHidden == hidden then
		return
	end

	self.CharacterHidden = hidden

	local character = Player.Character
	if character then
		self:_applyCharacterHiddenState(character, hidden)
	end
end

function UserInterface:_hideCharacterModel(character, player)
	if not character or not self.OtherCharactersHidden then
		return
	end

	self.OtherCharacterVisibilityCache[player] = self.OtherCharacterVisibilityCache[player] or {}
	local cache = self.OtherCharacterVisibilityCache[player]

	for instance in pairs(cache) do
		if not instance.Parent then
			cache[instance] = nil
		end
	end

	for _, descendant in ipairs(character:GetDescendants()) do
		self:_hideInstance(descendant, cache)
	end

	if self._otherDescendantConns[player] then
		self._otherDescendantConns[player]:Disconnect()
	end

	self._otherDescendantConns[player] = character.DescendantAdded:Connect(function(desc)
		if self.OtherCharactersHidden then
			self:_hideInstance(desc, cache)
		end
	end)
end

function UserInterface:_restoreOtherCharacter(player)
	if not self.OtherCharacterVisibilityCache then
		return
	end

	local cache = self.OtherCharacterVisibilityCache[player]
	if cache then
		local restoreQueue = {}
		for instance in pairs(cache) do
			restoreQueue[#restoreQueue + 1] = instance
		end

		for _, instance in ipairs(restoreQueue) do
			if instance.Parent then
				self:_restoreInstance(instance, cache)
			else
				cache[instance] = nil
			end
		end

		if next(cache) == nil then
			self.OtherCharacterVisibilityCache[player] = nil
		end
	end

	if self._otherDescendantConns[player] then
		self._otherDescendantConns[player]:Disconnect()
		self._otherDescendantConns[player] = nil
	end
end

function UserInterface:_unbindOtherCharacter(player)
	local bundle = self._otherPlayerCharacterConns[player]
	if not bundle then
		return
	end

	if bundle.added then
		bundle.added:Disconnect()
		bundle.added = nil
	end

	if bundle.removing then
		bundle.removing:Disconnect()
		bundle.removing = nil
	end

	self._otherPlayerCharacterConns[player] = nil
end

function UserInterface:_bindOtherCharacter(player)
	if player == Player then
		return
	end

	self._otherPlayerCharacterConns[player] = self._otherPlayerCharacterConns[player] or {}
	local bundle = self._otherPlayerCharacterConns[player]

	if bundle.added then
		bundle.added:Disconnect()
	end

	bundle.added = player.CharacterAdded:Connect(function(character)
		if not self.OtherCharactersHidden then
			return
		end

		task.defer(function()
			if self.OtherCharactersHidden and character and character.Parent then
				self:_hideCharacterModel(character, player)
			end
		end)
	end)

	if bundle.removing then
		bundle.removing:Disconnect()
	end

	bundle.removing = player.CharacterRemoving:Connect(function()
		if self._otherDescendantConns[player] then
			self._otherDescendantConns[player]:Disconnect()
			self._otherDescendantConns[player] = nil
		end
		self.OtherCharacterVisibilityCache[player] = {}
	end)

	if player.Character then
		task.defer(function()
			if self.OtherCharactersHidden and player.Character then
				self:_hideCharacterModel(player.Character, player)
			end
		end)
	end
end

function UserInterface:_setOtherCharactersHidden(hidden)
	if self.OtherCharactersHidden == hidden then
		return
	end

	self.OtherCharactersHidden = hidden

	if hidden then
		for _, otherPlayer in ipairs(Players:GetPlayers()) do
			if otherPlayer ~= Player then
				self:_bindOtherCharacter(otherPlayer)
			end
		end

		if not self._otherPlayersAddedConn then
			self._otherPlayersAddedConn = Players.PlayerAdded:Connect(function(otherPlayer)
				if otherPlayer == Player or not self.OtherCharactersHidden then
					return
				end
				self:_bindOtherCharacter(otherPlayer)
			end)
		end

		if not self._otherPlayersRemovingConn then
			self._otherPlayersRemovingConn = Players.PlayerRemoving:Connect(function(otherPlayer)
				if otherPlayer == Player then
					return
				end
				self:_restoreOtherCharacter(otherPlayer)
				self:_unbindOtherCharacter(otherPlayer)
				self.OtherCharacterVisibilityCache[otherPlayer] = nil
			end)
		end
	else
		if self._otherPlayersAddedConn then
			self._otherPlayersAddedConn:Disconnect()
			self._otherPlayersAddedConn = nil
		end

		if self._otherPlayersRemovingConn then
			self._otherPlayersRemovingConn:Disconnect()
			self._otherPlayersRemovingConn = nil
		end

		for _, otherPlayer in ipairs(Players:GetPlayers()) do
			if otherPlayer ~= Player then
				self:_restoreOtherCharacter(otherPlayer)
				self:_unbindOtherCharacter(otherPlayer)
			end
		end

		self.OtherCharacterVisibilityCache = {}
	end
end

function UserInterface:_beginNpcConversation(npc)
	if not self.ConversationEvent or not npc then
		return false
	end

	if self.ActiveConversationNpc == npc then
		return true
	end

	if self.ActiveConversationNpc then
		self:_endNpcConversation()
	end

	self.ActiveConversationNpc = npc
	self.ConversationEvent:Fire("Start", npc)
	return true
end

function UserInterface:_endNpcConversation()
	if not self.ActiveConversationNpc or not self.ConversationEvent then
		self.ActiveConversationNpc = nil
		return
	end

	self.ConversationEvent:Fire("Stop", self.ActiveConversationNpc)
	self.ActiveConversationNpc = nil
end

return UserInterface