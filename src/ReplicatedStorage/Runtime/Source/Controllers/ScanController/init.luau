local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets
local Sounds = Assets.Sounds.Scanner

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Lighting = game:GetService("Lighting")

local Mince = require(ReplicatedStorage.Modules.Mince)
local DiscoveryManager = Mince:Get("DiscoveryManager")

local CurrentCamera = workspace.CurrentCamera
local Signal = Mince.Signal
local Trove = require(ReplicatedStorage.Modules.Trove)
local DiscoveryEvent = Mince:GetEvent("DiscoverySystem")
local GuiInset = GuiService:GetGuiInset()

local Encyclopedia = Assets.Encyclopedia

local DiscoveryTypes = {
	["Vertebrates"] = require(Encyclopedia.Vertebrates),
	["Invertebrates"] = require(Encyclopedia.Invertebrates),
	["Corals and Plants"] = require(Encyclopedia["Corals and Plants"])
}

local SkeletonManager = require(script.SkeletonManager)
local CursorManager = require(script.CursorManager)
local EffectsManager = require(script.EffectsManager)
local TargetManager = require(script.TargetManager)
local InputModule = require(script.Input)

local Config = require(script.Config)

local HIGHLIGHT_COLOR_A = Color3.fromRGB(80, 200, 255)
local HIGHLIGHT_COLOR_B = Color3.new(1, 1, 1)

local function toVector2(position)
	if not position then
		return nil
	end

	local positionType = typeof(position)
	if positionType == "Vector2" then
		return position
	elseif positionType == "Vector3" then
		return Vector2.new(position.X, position.Y)
	end

	return nil
end

local function shouldUseMouseLock(controller)
	if UserInputService.TouchEnabled then
		return false
	end
	if UserInputService.GamepadEnabled then
		return false
	end
	if controller and controller.ActiveDevice and controller.ActiveDevice ~= "pc" then
		return false
	end
	return true
end

local RaycastParameters = RaycastParams.new()
RaycastParameters.FilterType = Enum.RaycastFilterType.Exclude

local ScanController = {
	Name = "ScanController",

	Locked = false,
	LockedTo = nil,
	CanExit = true,

	Character = nil,
	Humanoid = nil,
	HumanoidRootPart = nil,

	Enabled = false,
	IsEnabling = false,
	IsDisabling = false,

	FishScanned = Signal.new(),
	ScanStarted = Signal.new(),
	CreatureLocked = Signal.new(),
	SessionReset = Signal.new(),

	CursorSize = nil,
	CameraSpeed = 0,
	OriginalSpeed = nil,
	LastCameraCFrame = nil,
	LastScan = 0,
	CursorSpeed = 0,
	MouseUnlockScore = 0,
	LockRequested = false,

	OriginalFOV = nil,
	FOVTween = nil,

	SmartCursorInteractables = {},

	SmartCursorLocked = false,
	SmartCursorLockedTo = nil,
	SmartCursorAllowList = {},
	CurrentConnectableFrames = {},
	AutoCursorTarget = nil,
	SmartCursorLastLock = os.clock(),
	SmartCursorStickyNode = nil,
	SelectedDotObject = nil,
	LastCursorMove = os.clock(),
	LastSkeletonClick = 0,
	LastSelection = nil,

	LockedIntoTarget = false,
	TargetLockProgress = 0,
	RightClickHeld = false,
	MouseDelta = Vector3.zero,
	CameraAngle = { X = 0, Y = 0, Z = 0, Zt = 0, Side = 0},
	LockedFishSize = 0,
	OriginalCameraCF = nil,
	LastShoulderTarget = nil,

	DiscoveredAnimals = {},
	TotalScans = 0,
	Discoverables = {},
	Events = {
		OnDiscovery = DiscoveryEvent:Extend("OnDiscovery"),
		RecordDiscovery = DiscoveryEvent:Extend("RecordDiscovery"),
		GetDiscoveries = Mince:GetFunction("GetDiscoveries")
	},

	Sounds = {
		Hover = Sounds.UI_Scanner_Hover,
		Scanning = Sounds.UI_Scanner_Scanning,
		Discovered = Sounds.UI_Scanner_Discovered,
		Click = Sounds.UI_Scanner_Click
	},

	CCM = nil,
	_cameraControlRequests = 0,

	SkeletonMode = false,
	SkeletonConnectionLine = nil,
	SelectedSkeletalNode = nil,
	SkeletalTracker = {},
	SkeletalTrove = Trove.new(),
	SkeletalGuide = Trove.new(),
	InputHandler = nil,
	MainTrove = Trove.new(),
	NavigatorTooltip = nil,
	DiscoveryTriggered = false,
	PendingDelays = {},
	BiographyNameLabel = nil,
	BiographyScientificLabel = nil,

	SkeletonManager = nil,
	CursorManager = nil,
	EffectsManager = nil,
	TargetManager = nil,

	MinimumDistance = 0,
	LastNoTargetNotify = 0,
	CheckNoTargetOnRelease = false,
	LastShoulderYaw = nil,
	LastPointerPosition = nil,
	ActiveDevice = "pc",

	DepthOfField = nil,
	DoFTween = nil,
}

function ScanController:UpdateDepthOfField()
	if not self.DepthOfField or not self.DepthOfField.Enabled then
		return
	end

	local target = self.LockedTo
	if not target then
		return
	end

	local dist = (CurrentCamera.CFrame.Position - target:GetPivot().Position).Magnitude
	self.DepthOfField.FocusDistance = dist
end

function ScanController:SetDepthOfField(enabled)
	if enabled then
		if not self.DepthOfField then
			self.DepthOfField = Lighting:FindFirstChild("ScannerDOF")
			if not self.DepthOfField then
				self.DepthOfField = Instance.new("DepthOfFieldEffect")
				self.DepthOfField.Name = "ScannerDOF"
				self.DepthOfField.Parent = Lighting
				self.DepthOfField.FarIntensity = 0
				self.DepthOfField.NearIntensity = 0
				self.DepthOfField.InFocusRadius = 50
			end
		end

		self.DepthOfField.Enabled = true

		if self.DoFTween then self.DoFTween:Cancel() end
		self.DoFTween = TweenService:Create(self.DepthOfField, Config.DOF_TWEEN_INFO, {
			FarIntensity = Config.DOF_INTENSITY,
			NearIntensity = Config.DOF_INTENSITY * 0.5,
			InFocusRadius = Config.DOF_RADIUS
		})
		self.DoFTween:Play()

		self:UpdateDepthOfField()
	else
		if self.DepthOfField then
			if self.DoFTween then self.DoFTween:Cancel() end

			self.DoFTween = TweenService:Create(self.DepthOfField, Config.DOF_TWEEN_INFO, {
				FarIntensity = 0,
				NearIntensity = 0,
				InFocusRadius = 50
			})
			self.DoFTween:Play()

			task.delay(Config.DOF_TWEEN_INFO.Time, function()
				if self.DepthOfField and not self.Locked then -- Check lock status just in case
					self.DepthOfField.Enabled = false
				end
			end)
		end
	end
end

function ScanController:NormalizePointerPosition(position)
	local pos = toVector2(position)
	if not pos then
		return nil
	end

	local gui = self.ScannerGui
	if gui and gui.IgnoreGuiInset == false then
		local inset = GuiService:GetGuiInset()
		pos = pos - inset
	end

	if UserInputService.TouchEnabled then
		local cursor = self.ScannerCursor
		local cursorSize = nil
		if cursor then
			if cursor.AbsoluteSize then
				cursorSize = cursor.AbsoluteSize.Y
			elseif cursor.Size then
				cursorSize = cursor.Size.Y.Offset
			end
		end
		if cursorSize then
			pos = pos - Vector2.new(0, cursorSize * 0.5)
		end
	end

	return pos
end

function ScanController:ResetCursorTargets()
	local cursorManager = self:GetModule("CursorManager")
	if cursorManager and cursorManager.ResetCursorTargets then
		cursorManager:ResetCursorTargets()
	end
end

function ScanController:CancelPendingDelays()
	for _, thread in ipairs(self.PendingDelays) do
		if thread then
			pcall(task.cancel, thread)
		end
	end
	table.clear(self.PendingDelays)
end

function ScanController:_hasDiscovery(discoveryType, fishId)
	if not fishId then
		return false
	end

	local sessionScans = self.DiscoveredAnimals and self.DiscoveredAnimals[fishId]
	if sessionScans and sessionScans > 0 then
		return true
	end

	if discoveryType and DiscoveryManager and DiscoveryManager.HasDiscovered then
		return DiscoveryManager:HasDiscovered(discoveryType, fishId)
	end

	return false
end

function ScanController:_resolveScanViewLabels()
	if self.BiographyNameLabel then
		local invalidParent = not self.BiographyNameLabel.Parent
		local detachedFromScanView = self.ScanViewFrame and not self.BiographyNameLabel:IsDescendantOf(self.ScanViewFrame)
		if invalidParent or detachedFromScanView then
			self.BiographyNameLabel = nil
		end
	end

	if self.BiographyScientificLabel then
		local invalidParent = not self.BiographyScientificLabel.Parent
		local detachedFromScanView = self.ScanViewFrame and not self.BiographyScientificLabel:IsDescendantOf(self.ScanViewFrame)
		if invalidParent or detachedFromScanView then
			self.BiographyScientificLabel = nil
		end
	end

	if not self.ScanViewFrame then
		return
	end

	local informationFrame = self.ScanViewFrame:FindFirstChild("Information")
	if not informationFrame then
		return
	end

	local biographyFrame = informationFrame:FindFirstChild("Biography")
	if not biographyFrame then
		return
	end

	if not self.BiographyNameLabel then
		local fishNameFrame = biographyFrame:FindFirstChild("FishName")
		if fishNameFrame then
			self.BiographyNameLabel = fishNameFrame:FindFirstChild("TextLabel") or fishNameFrame:FindFirstChildWhichIsA("TextLabel")
		end
	end

	if not self.BiographyScientificLabel then
		local scientificFrame = biographyFrame:FindFirstChild("ScientificName")
		if scientificFrame then
			self.BiographyScientificLabel = scientificFrame:FindFirstChild("TextLabel") or scientificFrame:FindFirstChildWhichIsA("TextLabel")
		end
	end
end

function ScanController:_updateCreatureLabels(fishConfiguration, discoveryType, fishId)
	self:_resolveScanViewLabels()
	local hasDiscovery = self:_hasDiscovery(discoveryType, fishId)
	local creatureName = "?????"
	local scientificName = ""

	if hasDiscovery and fishConfiguration then
		creatureName = fishConfiguration.Name or creatureName
		if fishConfiguration.Aliases then
			scientificName = fishConfiguration.Aliases[1] or scientificName
		elseif fishConfiguration.ScientificName then
			scientificName = fishConfiguration.ScientificName
		end
	end

	if self.CreatureName then
		self.CreatureName.Text = creatureName
	end

	if self.ScientificName then
		self.ScientificName.Text = scientificName
	end

	if self.BiographyNameLabel then
		self.BiographyNameLabel.Text = creatureName
	end

	if self.BiographyScientificLabel then
		self.BiographyScientificLabel.Text = scientificName
	end
end

function ScanController:StopScanningSound()
	if not self.Sounds or not self.Sounds.Scanning then
		return
	end

	local scanningSound = self.Sounds.Scanning
	if scanningSound.Playing then
		scanningSound:Stop()
	end
end

function ScanController:_acquireCameraControl(data)
	if not self.CCM then
		return
	end

	self._cameraControlRequests = (self._cameraControlRequests or 0) + 1
	self.CCM:RequestControl(self.Name, self.CCM.Priority.SCAN, data)
end

function ScanController:_releaseCameraControl()
	if not self.CCM then
		self._cameraControlRequests = 0
		return
	end

	if not self._cameraControlRequests or self._cameraControlRequests <= 0 then
		self._cameraControlRequests = 0
		return
	end

	self._cameraControlRequests -= 1
	if self._cameraControlRequests <= 0 then
		self._cameraControlRequests = 0
		self.CCM:ReleaseControl(self.Name)
	end
end

function ScanController:_forceReleaseCameraControl()
	if not self.CCM then
		self._cameraControlRequests = 0
		return
	end

	if self._cameraControlRequests and self._cameraControlRequests > 0 then
		self._cameraControlRequests = 0
		self.CCM:ReleaseControl(self.Name)
	end
end

function ScanController:ResetScannerSession()
	self:CancelPendingDelays()
	self:SetHighlight(nil)

	if self.Locked then
		self:Unlock()
	end

	if self.OriginalFOV then
		if self.FOVTween then
			self.FOVTween:Cancel()
		end
		self.FOVTween = TweenService:Create(CurrentCamera, Config.FOV_TRANSITION_INFO, {FieldOfView = self.OriginalFOV})
		self.FOVTween:Play()
		self.OriginalFOV = nil
	end

	RunService:UnbindFromRenderStep("ScannerMouseLock")
	self:StopScanningSound()
	self:_forceReleaseCameraControl()

	self.Locked = false
	self.LockedTo = nil
	self.TargetLockProgress = 0
	self.LockedIntoTarget = false
	self.SkeletonMode = false
	self.SkeletonConnectionLine = nil
	self.SelectedSkeletalNode = nil
	self.SelectedDotObject = nil
	self.MouseHeld = false
	self.MouseUnlockScore = 0
	self.MouseDelta = Vector3.zero
	self.LastNoTargetNotify = 0
	self.CheckNoTargetOnRelease = false
	self.LastShoulderTarget = nil
	self.LastShoulderYaw = nil
	self.SmartCursorStickyNode = nil
	self.AutoCursorTarget = nil
	self.SmartCursorLocked = false
	self.SmartCursorLockedTo = nil
	self.SmartCursorAllowList = {}
	self.CurrentConnectableFrames = {}
	self.LastSelection = nil
	self.SmartCursorLastLock = os.clock()
	self.SkeletalTracker = {}
	self.LockedCameraOffset = nil
	self.OriginalCameraCF = nil

	if self.CursorManager and self.CursorManager.ResetCursorTargets then
		self.CursorManager:ResetCursorTargets()
	else
		self:ResetCursorTargets()
	end

	if self.CursorManager and self.CursorManager.CenterSmartCursor then
		self.CursorManager:CenterSmartCursor()
	end

	if self.NavigatorTooltip then
		self.NavigatorTooltip.Text = Config.DEFAULT_GUIDE_MESSAGE
		self.NavigatorTooltip.TextTransparency = 1
		self.NavigatorTooltip.Visible = false
	end

	if self.CursorManager and self.CursorManager.ResetSmartCursorAppearance then
		self.CursorManager:ResetSmartCursorAppearance()
	end

	if self.SessionReset then
		if self.SkeletalTrove then
			self.SkeletalTrove:Clean()
		end

		if self.SkeletalGuide then
			self.SkeletalGuide:Clean()
		end

		self.SessionReset:Fire()
	end

end

function ScanController:NotifyDiscovery(name, isNew)
	local category = isNew and "Success" or "Info"
	local message

	if isNew then
		message = "New discovery: " .. name
	else
		message = "Already cataloged: " .. name
	end

	_G.UI.Notify(message, category, 4)
end

function ScanController:NotifyNoTargetsInRange()
	local cooldown = Config.NO_TARGET_NOTIFY_COOLDOWN or 0
	if os.clock() - (self.LastNoTargetNotify or 0) < cooldown then
		return
	end

	self.LastNoTargetNotify = os.clock()

	if not _G or not _G.UI or not _G.UI.Notify then
		return
	end

	_G.UI.Notify("No scannable targets in range.", "Info", 3)
end

function ScanController:BindUiButton(button, callback)
	if not (button and callback) then
		return
	end

	local cursorManager = self.CursorManager
	if cursorManager and cursorManager.RegisterInteractable then
		cursorManager:RegisterInteractable(button, callback)
	else
		button.MouseButton1Click:Connect(callback)
	end
end

function ScanController:TryDiscover()
	if self.DiscoveryTriggered then
		return false
	end

	local ready, missingDot = self.SkeletonManager:IsScanComplete()
	if not ready then
		return false
	end

	self.DiscoveryTriggered = true
	self:Discover()
	return true
end

function ScanController:Discover()
	local id = self.TargetManager:GetScanId(self.LockedTo)

	if not id then
		id = self.TargetManager:GetScanId(self.LockedTo.Parent)
	end

	if not id then
		warn("Discover called without a scan id on the locked target")
		return
	end

	local fishConfiguration = nil
	local discoveryType = nil

	for dtype, catalog in pairs(DiscoveryTypes) do
		local entry = catalog and catalog[id]
		if entry then
			fishConfiguration = entry
			discoveryType = dtype
			break
		end
	end

	local fishName = fishConfiguration and fishConfiguration.Name or "Unknown Creature"
	local alreadyKnown = discoveryType and DiscoveryManager:HasDiscovered(discoveryType, id) or false
	local previousScanCount = self.DiscoveredAnimals[id] or 0
	local wasPreviouslyScanned = previousScanCount > 0
	local isNewScan = not alreadyKnown and not wasPreviouslyScanned
	local scanViewFrame = self.ScanViewFrame
	if not scanViewFrame then
		warn("Discover called without ScanViewFrame")
		return
	end

	local informationFrame = scanViewFrame:FindFirstChild("Information")
	if not informationFrame then
		warn("Discover could not find Information frame")
		return
	end

	local biographyFrame = informationFrame:FindFirstChild("Biography")
	if not biographyFrame then
		warn("Discover could not find Biography frame")
		return
	end

	local nameFrame = biographyFrame:FindFirstChild("FishName")
	if not nameFrame then
		warn("Discover could not find FishName frame")
		return
	end

	self:_resolveScanViewLabels()
	if not self.BiographyNameLabel then
		self.BiographyNameLabel = nameFrame:FindFirstChild("TextLabel") or nameFrame:FindFirstChildWhichIsA("TextLabel")
	end

	if self.BiographyNameLabel then
		self.BiographyNameLabel.Text = fishName
	end
	if self.Sounds and self.Sounds.Discovered then
		local sound = self.Sounds.Discovered:Clone()
		sound.Parent = self.ScannerGui
		sound:Play()
		game:GetService("Debris"):AddItem(sound, sound.TimeLength)
	else
		warn("Discovered sound not found or Sounds table is nil")
	end
	self.EffectsManager:PlayDiscoveryEffect(scanViewFrame)

	if discoveryType then
		self.Events.RecordDiscovery:Fire(discoveryType, id)
	else
		warn("Could not determine discovery type for creature with id:", id)
	end

	self.DiscoveredAnimals[id] = previousScanCount + 1
	self.TotalScans = (self.TotalScans or 0) + 1
	self.FishScanned:Fire(id, fishName, self.TotalScans, self.DiscoveredAnimals[id], isNewScan)
	self:NotifyDiscovery(fishName, isNewScan)
	self:_updateCreatureLabels(fishConfiguration, discoveryType, id)

	if self.CursorManager and self.CursorManager.GetSmartCursor then
		local smartCursor = self.CursorManager:GetSmartCursor()
		if smartCursor then
			local defaultBgTransparency = smartCursor:GetAttribute("DefaultBackgroundTransparency")
			if defaultBgTransparency == nil then
				smartCursor:SetAttribute("DefaultBackgroundTransparency", smartCursor.BackgroundTransparency)
			end
			smartCursor.BackgroundTransparency = 0.8
		end
	end

	if not self.SkeletonMode and self.Locked then
		self:Unlock()
	end

	if LocalPlayer then
		local lastId = fishConfiguration and fishConfiguration._id or id
		if lastId then
			LocalPlayer:SetAttribute("LastScannedFishId", lastId)
		end
		if discoveryType then
			LocalPlayer:SetAttribute("LastScannedDiscoveryType", discoveryType)
		else
			LocalPlayer:SetAttribute("LastScannedDiscoveryType", nil)
		end
	end

	if self.SkeletonMode then
		self:_releaseCameraControl()
		local delayThread = task.delay(Config.ENABLE_INITIAL_WAIT, function()
			if self.Enabled and self.SkeletonMode then
				if self.SkeletonManager and self.SkeletonManager.ExitSkeletonMode then
					self.SkeletonManager:ExitSkeletonMode()
				else
					self:Close(false)
				end
			end
		end)
		table.insert(self.PendingDelays, delayThread)
	end
end

function ScanController:OnLock(LockedTo)
	if not self.Enabled or self.IsDisabling then
		return
	end

	if not LockedTo or not LockedTo.Instance or not LockedTo.Instance:IsDescendantOf(workspace) then
		warn("OnLock: Invalid or destroyed target")
		return
	end

	if self.Locked and self.LockedTo ~= LockedTo.Instance then
		self:Unlock()
	end

	if self.Locked then
		return
	end

	self.Locked = true
	self.LockedTo = LockedTo.Instance
	self.LastScan = os.clock()
	self.MouseHeld = false
	self.MouseUnlockScore = 0
	self.DiscoveryTriggered = false
	self.CheckNoTargetOnRelease = false

	if self.Humanoid then
		self.OriginalSpeed = self.Humanoid.WalkSpeed
	else
		self.OriginalSpeed = nil
	end
	print("Attemp to lock on:", LockedTo.Instance)
	local id = self.TargetManager:GetScanId(LockedTo.Instance)

	if not id then
		id = self.TargetManager:GetScanId(LockedTo.Instance.Parent)
	end

	if not id then
		warn("OnLock: Could not resolve scan id for locked target")
		self:Unlock()
		return
	end

	local fishConfiguration = nil
	local discoveryType = nil

	for dtype, catalog in pairs(DiscoveryTypes) do
		local entry = catalog and catalog[id]
		if entry then
			fishConfiguration = entry
			discoveryType = dtype
			break
		end
	end

	local targetCFrame = LockedTo.Instance:GetPivot()
	local cameraCFrame = CurrentCamera.CFrame

	self.OriginalFOV = CurrentCamera.FieldOfView
	if self.FOVTween then
		self.FOVTween:Cancel()
	end
	self.FOVTween = TweenService:Create(CurrentCamera, Config.FOV_TRANSITION_INFO, {FieldOfView = Config.SCAN_ZOOM_FOV})
	self.FOVTween:Play()

	self.OriginalCameraCF = cameraCFrame
	self:_acquireCameraControl({
		mode = "Lock",
		target = LockedTo.Instance,
		targetId = id,
	})

	self:_updateCreatureLabels(fishConfiguration, discoveryType, id)

	if shouldUseMouseLock(self) then
		UserInputService.MouseDeltaSensitivity = Config.MOUSE_DELTA_SENSITIVITY
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
	end

	local humanoidRootPart = self.Character and self.Character:FindFirstChild("HumanoidRootPart")
	local lockedInstance = LockedTo.Instance

	RunService:BindToRenderStep("ScannerMouseLock", Enum.RenderPriority.Camera.Value - 1, function(deltaTime)
		if not self.Enabled or not self.Locked or self.SkeletonMode or self.LockedTo ~= lockedInstance then
			return
		end

		if not lockedInstance or not lockedInstance:IsDescendantOf(workspace) then
			self:Unlock()
			return
		end

		local targetPosition = lockedInstance:GetPivot().Position

		if humanoidRootPart and humanoidRootPart:IsDescendantOf(workspace) then
			local rootCFrame = humanoidRootPart.CFrame
			local cameraOffset = rootCFrame * CFrame.new(Config.LOCKED_CAMERA_OFFSET)
			local lookAtCFrame = CFrame.lookAt(cameraOffset.Position, targetPosition)
			CurrentCamera.CFrame = CurrentCamera.CFrame:Lerp(lookAtCFrame, deltaTime * Config.CAMERA_LERP_SPEED)
		else
			local lookAtCFrame = CFrame.lookAt(CurrentCamera.CFrame.Position, targetPosition)
			CurrentCamera.CFrame = CurrentCamera.CFrame:Lerp(lookAtCFrame, deltaTime * Config.CAMERA_LERP_SPEED)
		end
		self:UpdateDepthOfField()
	end)

	if self.Sounds and self.Sounds.Hover then
		local sound = self.Sounds.Hover:Clone()
		sound.Parent = self.ScannerGui
		sound:Play()
		game:GetService("Debris"):AddItem(sound, sound.TimeLength)
	else
		warn("UI_Scanner_Hover sound not found or Sounds table is nil")
	end

	self:ToggleCircle(true)
	self:ToggleScanView(true)
	self:SetDepthOfField(true)

	local delayThread = task.delay(Config.ENABLE_DELAY, function()
		if self.Enabled and self.NavigatorTooltip and self.Locked and self.LockedTo == LockedTo.Instance and not self.SkeletonMode then
			self.NavigatorTooltip.Text = "Click again to start scanning"
			self.NavigatorTooltip.TextTransparency = 0
			self.NavigatorTooltip.Visible = true
		end
	end)
	table.insert(self.PendingDelays, delayThread)
end

function ScanController:Unlock()
	if not self.Locked then
		return
	end

	if self.FOVTween then
		self.FOVTween:Cancel()
	end
	local targetFOV = self.OriginalFOV or 70
	self.FOVTween = TweenService:Create(CurrentCamera, Config.FOV_TRANSITION_INFO, {FieldOfView = targetFOV})
	self.FOVTween:Play()
	self.OriginalFOV = nil

	self:CancelPendingDelays()
	self:StopScanningSound()
	self:_releaseCameraControl()

	if shouldUseMouseLock(self) then
		UserInputService.MouseDeltaSensitivity = 1
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
	RunService:UnbindFromRenderStep("ScannerMouseLock")
	if self.RightShoulder and self.RightShoulderC0 then
		self.RightShoulder.C0 = self.RightShoulderC0
	end

	self.MouseHeld = false
	self.RightClickHeld = false
	self.MouseDelta = Vector3.zero
	self.Locked = false
	self.LockedTo = nil
	self.MouseUnlockScore = 0

	self.LastShoulderTarget = nil
	self.LockedCameraOffset = nil
	self.LastShoulderYaw = nil

	self:ToggleCircle(false)
	self:ToggleScanView(false)
	self:SetDepthOfField(false)

	if self.CursorManager then
		self.CursorManager:ResetScannerCursorSize()
		if self.CursorManager.ResetSmartCursorAppearance then
			self.CursorManager:ResetSmartCursorAppearance()
		end
	end

	self.CheckNoTargetOnRelease = false
end


function ScanController:BindInputEvents()
	if not self.InputHandler then
		self.InputHandler = InputModule.new(self)
	end

	self.InputHandler:Start()

	if self.InputHandler.GetEvents then
		local events = self.InputHandler:GetEvents()
		if events and events.DeviceChange then
			events.DeviceChange.Event:Connect(function(device)
				self:OnDeviceChanged(device)
			end)
		end
		if events and events.Tap then
			events.Tap.Event:Connect(function(position)
				self.LastPointerPosition = position
			end)
		end
	end
end

function ScanController:OnDeviceChanged(device)
	self.ActiveDevice = device or "pc"

	if not self.Enabled then
		return
	end

	if self.CursorManager then
		if self.SkeletonMode then
			self.CursorManager:HideScannerCursor()
			self.CursorManager:SetSmartCursorVisible(not UserInputService.TouchEnabled)
			self.CursorManager:CenterSmartCursor()
		else
			self.CursorManager:ShowScannerCursor()
			self.CursorManager:SetSmartCursorVisible(false)
		end
	end

	UserInputService.MouseIconEnabled = false
end

function ScanController:Enable()
	if self.Enabled or self.IsEnabling then
		return
	end

	self.IsEnabling = true
	self.Enabled = true

	self:CancelPendingDelays()

	if self.Locked then
		self:Unlock()
	end

	self.MouseHeld = false
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = false
	UserInputService.MouseDeltaSensitivity = 1

	if self.CursorManager then
		self.CursorManager:ShowScannerCursor()
		self.CursorManager:SetSmartCursorVisible(false)
		self.CursorManager:CenterSmartCursor()
		if self.CursorManager.CenterScannerCursor then
			self.CursorManager:CenterScannerCursor()
			task.defer(function()
				if not self.Enabled then
					return
				end
				local mouseBehavior = UserInputService.MouseBehavior
				if mouseBehavior == Enum.MouseBehavior.LockCenter or mouseBehavior == Enum.MouseBehavior.LockCurrentPosition then
					self.CursorManager:CenterScannerCursor()
				end
			end)
		end
	else
		if self.ScannerCursor then
			self.ScannerCursor.Visible = true
		end
		if self.SmartCursor then
			self.SmartCursor.Visible = false
		end
	end

	if self.TargetManager and self.TargetManager.ShowAllTargets then
		self.TargetManager:ShowAllTargets()
	end

	ProximityPromptService.Enabled = false
	self:BindInputEvents()

	self.IsEnabling = false
end

function ScanController:Disable()
	if not self.Enabled or self.IsDisabling then
		return
	end

	self.IsDisabling = true

	if self.Locked then
		self:Unlock()
	end

	if self.OriginalFOV then
		if self.FOVTween then
			self.FOVTween:Cancel()
		end
		self.FOVTween = TweenService:Create(CurrentCamera, Config.FOV_TRANSITION_INFO, {FieldOfView = self.OriginalFOV})
		self.FOVTween:Play()
		self.OriginalFOV = nil
	end

	ProximityPromptService.Enabled = true

	self:SetHighlight(nil)
	self.Enabled = false
	self:StopScanningSound()
	self:_forceReleaseCameraControl()

	if self.InputHandler then
		self.InputHandler:Stop()
	end

	self:CancelPendingDelays()

	RunService:UnbindFromRenderStep("ScannerMouseLock")
	if self.RightShoulder and self.RightShoulderC0 then
		self.RightShoulder.C0 = self.RightShoulderC0
	end

	self.Locked = false
	self.LockedTo = nil
	self.MouseHeld = false
	self.RightClickHeld = false
	self.MouseDelta = Vector3.zero
	self.LastShoulderYaw = nil

	if self.SkeletonMode then
		if self.SkeletonManager and self.SkeletonManager.ExitSkeletonMode then
			self.SkeletonManager:ExitSkeletonMode()
		end
		self.SkeletonMode = false
	end

	if self.CursorManager then
		self.CursorManager:ResetScannerCursorSize()
		self.CursorManager:ResetSmartCursorAppearance()
	end

	UserInputService.MouseDeltaSensitivity = 1
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true

	if self.TargetManager and self.TargetManager.HideAllTargets then
		self.TargetManager:HideAllTargets()
	end

	if self.CCM and self.CCM.Enable then
		self.CCM:Enable()
	end

	local viewingExhibit = LocalPlayer:GetAttribute("ViewingExhibit") == true
	local currentOwner = self.CCM and select(1, self.CCM:GetCurrentOwner())
	if self.Character and self.Character.PrimaryPart and not viewingExhibit then
		if not currentOwner or currentOwner == self.Name then
			CurrentCamera.CameraSubject = self.Character.Humanoid
			CurrentCamera.CameraType = Enum.CameraType.Custom
		end
	end

	if self.ScannerCursor then
		self.ScannerCursor.Visible = false
	end

	if self.SmartCursor then
		self.SmartCursor.Visible = false
	end

	if self.ScanViewFrame then
		self.ScanViewFrame.Visible = false
	end

	if self.CursorManager and self.CursorManager.HideScannerCursor then
		self.CursorManager:HideScannerCursor()
	end

	self.IsDisabling = false
end

function ScanController:CharacterAdded(character)
	local humanoid: Humanoid = character:WaitForChild("Humanoid")
	local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
	local function findRightShoulderMotor()
		local upperTorso = character:FindFirstChild("UpperTorso")
		local torso = character:FindFirstChild("Torso")
		local rightUpperArm = character:FindFirstChild("RightUpperArm")
		local rightArm = character:FindFirstChild("Right Arm")

		local function findMotor(parent)
			if not parent then
				return nil
			end
			return parent:FindFirstChild("RightShoulder") or parent:FindFirstChild("Right Shoulder")
		end

		local motor = findMotor(upperTorso) or findMotor(torso)
		if motor and motor:IsA("Motor6D") then
			return motor
		end

		local candidateTorso = upperTorso or torso
		local candidateArm = rightUpperArm or rightArm
		if candidateTorso and candidateArm then
			for _, joint in ipairs(candidateTorso:GetChildren()) do
				if joint:IsA("Motor6D") and joint.Part1 == candidateArm then
					return joint
				end
			end
		end

		for _, joint in ipairs(character:GetDescendants()) do
			if joint:IsA("Motor6D") and joint.Part1 == rightUpperArm then
				return joint
			end
			if joint:IsA("Motor6D") and joint.Part1 == rightArm then
				return joint
			end
		end

		return nil
	end

	local rightShoulder = findRightShoulderMotor()

	humanoid.Died:Once(function()
		if self.Enabled then
			self:Disable()
		end
		self.Character = nil
	end)

	RaycastParameters.FilterDescendantsInstances = {character}

	self.Humanoid = humanoid
	self.HumanoidRootPart = humanoidRootPart
	self.RightShoulder = rightShoulder
	self.RightShoulderC0 = rightShoulder and rightShoulder.C0 or nil
	self.Character = character
	self.LastShoulderYaw = nil
end

function ScanController:CursorMove(actionName, inputState, inputObject: InputObject)
	if inputObject.UserInputType == Enum.UserInputType.MouseMovement and self.LastCameraCFrame then
		local speed = (self.LastCameraCFrame.Position - CurrentCamera.CFrame.Position).Magnitude
		self.CameraSpeed = speed
	end

	self.LastCameraCFrame = CurrentCamera.CFrame
	return Enum.ContextActionResult.Pass
end

function ScanController:ScanTargets(mouseLocation, deltaTime)
	if not self.CursorManager then
		return
	end
	return self.CursorManager:UpdateScannerCursor(mouseLocation, deltaTime)
end

function ScanController:UpdateShoulders(targetPosition, deltaTime)
	if not self.RightShoulder or not self.RightShoulderC0 then
		return
	end

	local shoulderCFrame = self.RightShoulder.Part0.CFrame * self.RightShoulderC0
	local shoulderPosition = shoulderCFrame.Position

	local direction = targetPosition - shoulderPosition
	local distance = direction.Magnitude

	if distance < 1e-3 then
		return
	end

	direction = direction / distance

	local forward = shoulderCFrame.LookVector
	local dotForward = forward:Dot(direction)

	if dotForward < 0 then
		direction = direction - forward * dotForward
		local dirMag = direction.Magnitude
		if dirMag < 1e-3 then
			direction = (forward + shoulderCFrame.RightVector * 0.1).Unit
		else
			direction = direction / dirMag
		end
		targetPosition = shoulderPosition + direction * distance
	end

	local lookAtCFrame = CFrame.lookAt(shoulderPosition, targetPosition)
	local desiredC0 = self.RightShoulder.Part0.CFrame:ToObjectSpace(lookAtCFrame)
	local relative = self.RightShoulderC0:ToObjectSpace(desiredC0)

	local yawRaw, pitch, roll = relative:ToEulerAnglesYXZ()
	local minYaw = math.rad(Config.SHOULDER_MIN_YAW)
	local maxYaw = math.rad(Config.SHOULDER_MAX_YAW)
	local maxStep = math.rad(32) * deltaTime * 12

	local targetYaw = math.clamp(yawRaw, minYaw, maxYaw)
	local yaw

	if self.LastShoulderYaw then
		local last = self.LastShoulderYaw
		local diff = targetYaw - last
		if last > 0 and targetYaw < 0 then
			diff = diff - 2 * math.pi
		elseif last < 0 and targetYaw > 0 then
			diff = diff + 2 * math.pi
		end
		diff = math.clamp(diff, -maxStep, maxStep)
		yaw = math.clamp(last + diff, minYaw, maxYaw)
	else
		yaw = targetYaw
	end

	self.LastShoulderYaw = yaw

	pitch = math.clamp(pitch, math.rad(Config.SHOULDER_MIN_PITCH), math.rad(Config.SHOULDER_MAX_PITCH))
	roll = math.clamp(roll, math.rad(-Config.SHOULDER_MAX_ROLL), math.rad(Config.SHOULDER_MAX_ROLL))

	local constrainedC0 = self.RightShoulderC0 * CFrame.fromEulerAnglesYXZ(yaw, pitch, roll)

	self.RightShoulder.C0 = self.RightShoulder.C0:Lerp(constrainedC0, math.min(deltaTime * 10, 1))
end

function ScanController:Update(deltaTime)
	if not self.Enabled or self.IsEnabling or self.IsDisabling then
		return
	end

	if self.ScannerHighlight and self.ScannerHighlight.Enabled then
		local alpha = (math.sin(os.clock() * 3.5) + 1) * 0.5
		self.ScannerHighlight.OutlineColor = HIGHLIGHT_COLOR_A:Lerp(HIGHLIGHT_COLOR_B, alpha)
		self.ScannerHighlight.OutlineTransparency = 0.8 - (alpha * 0.4)
	end

	local mouseLocation = toVector2(self:NormalizePointerPosition(UserInputService:GetMouseLocation()))
	if UserInputService.TouchEnabled or self.ActiveDevice == "phone" then
		local pointer = self.LastPointerPosition or self:NormalizePointerPosition(UserInputService:GetMouseLocation())
		mouseLocation = toVector2(pointer) or mouseLocation
	end
	if not mouseLocation and CurrentCamera then
		mouseLocation = Vector2.new(CurrentCamera.ViewportSize.X * 0.5, CurrentCamera.ViewportSize.Y * 0.5)
	end
	if not mouseLocation then
		return
	end
	local mouseRay = CurrentCamera:ScreenPointToRay(mouseLocation.X, mouseLocation.Y)
	local mouseCast = workspace:Raycast(mouseRay.Origin, mouseRay.Direction * Config.RAYCAST_DISTANCE, RaycastParameters)
	local targetPosition = mouseCast and mouseCast.Position or (mouseRay.Origin + mouseRay.Direction * Config.RAYCAST_DISTANCE)

	if not self.MouseHeld then
		if self.Sounds and self.Sounds.Scanning then
			self.Sounds.Scanning.Playing = false
		else
			warn("Scanning sound not found or Sounds table is nil")
		end
	end

	if self.SkeletonMode then
		if self.SkeletonManager and self.SkeletonManager.Update then
			self.SkeletonManager:Update(mouseLocation, deltaTime)
		end
		if not UserInputService.TouchEnabled and self.CursorManager and self.CursorManager.Update then
			self.CursorManager:Update(deltaTime, self.SmartCursor)
		end
		self:UpdateDepthOfField()
		self.MouseDelta = Vector3.zero
		return
	end

	local cursorAction, cursorTarget = self:ScanTargets(mouseLocation, deltaTime)
	if cursorAction == "Unlock" then
		self:Unlock()
	elseif cursorAction == "Lock" and cursorTarget then
		self:OnLock(cursorTarget)
	end

	if not self.Locked and targetPosition then
		self:UpdateShoulders(targetPosition, deltaTime)
	end

	self.MouseDelta = Vector3.zero
end

function ScanController:SetHighlight(target)
	if not self.ScannerHighlight then
		return
	end

	if target then
		local adornee = target
		if CollectionService:HasTag(target, "Selectable") and target.Parent:IsA("Model") then
			adornee = target.Parent
		end
		self.ScannerHighlight.Adornee = adornee
		self.ScannerHighlight.Enabled = true
	else
		self.ScannerHighlight.Adornee = nil
		self.ScannerHighlight.Enabled = false
	end
end

function ScanController:GameStart()
	local GUI = LocalPlayer.PlayerGui:WaitForChild("ScannerUI")

	self.ScannerHighlight = Instance.new("Highlight")
	self.ScannerHighlight.Name = "ScannerHighlight"
	self.ScannerHighlight.FillTransparency = 0.85
	self.ScannerHighlight.FillColor = Color3.fromRGB(100, 255, 150)
	self.ScannerHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	self.ScannerHighlight.OutlineTransparency = 0.2
	self.ScannerHighlight.Parent = GUI
	self.ScannerHighlight.Enabled = false

	self.SmartCursor = GUI.SmartCursor
	self.ScannerCursor = GUI.Frame
	self.ScanViewFrame = GUI.ScanView
	self.SkeletalMap = { Off = self.ScanViewFrame.SkeletalMap, On = self.ScanViewFrame.SkeletalMapHighlighter }

	self.ScannerGui = GUI
	self.SmartCursor = GUI.SmartCursor
	self.ScannerCursor = GUI.Frame
	self.ScanViewFrame = GUI.ScanView

	if self.ScanViewFrame then
		local informationFrame = self.ScanViewFrame:FindFirstChild("Information")
		if informationFrame then
			local biographyFrame = informationFrame:FindFirstChild("Biography")
			if biographyFrame then
				local fishNameFrame = biographyFrame:FindFirstChild("FishName")
				if fishNameFrame then
					self.BiographyNameLabel = fishNameFrame:FindFirstChild("TextLabel") or fishNameFrame:FindFirstChildWhichIsA("TextLabel")
				end

				local scientificFrame = biographyFrame:FindFirstChild("ScientificName")
				if scientificFrame then
					self.BiographyScientificLabel = scientificFrame:FindFirstChild("TextLabel") or scientificFrame:FindFirstChildWhichIsA("TextLabel")
				end
			end
		end
	end

	self.Main = self.ScannerGui.Main
	self.Container = self.Main.Container
	self.TopFrame = self.Container.Top
	self.BottomFrame = self.Container.Bottom

	self.NameFrame = self.TopFrame.NameFrame
	self.EncyclopediaFrame = self.TopFrame.EncyclopediaFrame
	self.ExitFrame = self.TopFrame.ExitFrame

	self.Buttons = {
		Encyclopedia = self.EncyclopediaFrame:FindFirstChild("Button", true) :: ImageButton,
		Exit = self.ExitFrame:FindFirstChild("Button", true) :: ImageButton,
	}

	self.CategoryLabel = self.NameFrame:FindFirstChild("CategoryLabel", true) :: ImageLabel
	self.CreatureName = self.NameFrame:FindFirstChild("CreatureName", true) :: TextLabel
	self.ScientificName = self.NameFrame:FindFirstChild("ScientificName", true) :: TextLabel

	self.SkeletonManager = SkeletonManager.new(self)
	self.CursorManager = CursorManager.new(self)
	self.EffectsManager = EffectsManager.new(self)
	self.TargetManager = TargetManager.new(self)

	local onExit = function()
		self:Close(true)
	end

	self:BindUiButton(self.Buttons.Exit, onExit)

	local scannerCursor = self.ScannerCursor
	if scannerCursor then
		self.CircleTween = TweenService:Create(
			scannerCursor,
			Config.CURSOR_TWEEN,
			{
				Size = UDim2.new(0, 0, 0, 0)
			}
		)
		self.CursorSize = scannerCursor.Size.Y.Offset
	else
		self.CircleTween = nil
		self.CursorSize = nil
	end
end

function ScanController:Setup()
	self.CCM = Mince:Get("CameraControlManager")

	LocalPlayer.CharacterAdded:Connect(function(...) self:CharacterAdded(...) end)
	if LocalPlayer.Character then
		self:CharacterAdded(LocalPlayer.Character)
	end

	RunService:BindToRenderStep("ScanControllerUpdate", Enum.RenderPriority.Camera.Value + 1, function(...)
		self:Update(...)
	end)

	self.MainTrove:Add(function()
		RunService:UnbindFromRenderStep("ScanControllerUpdate")
	end)

	ScanController.Discoverables = CollectionService:GetTagged("DiscoveryInjector")
	CollectionService:GetInstanceAddedSignal("DiscoveryInjector"):Connect(function(BasePart)
		table.insert(ScanController.Discoverables, BasePart)
	end)

	self.MainTrove:Connect(ContextActionService.LocalToolEquipped, function(Tool)
		if Tool.Name == "Scanner" then
			self:Enable()
		end
	end)

	self.MainTrove:Connect(ContextActionService.LocalToolUnequipped, function(Tool)
		if Tool.Name == "Scanner" then
			self:Disable()
		end
	end)
end

function ScanController:GetModule(name)
	if name == "SkeletonManager" then return self.SkeletonManager
	elseif name == "CursorManager" then return self.CursorManager
	elseif name == "EffectsManager" then return self.EffectsManager
	elseif name == "TargetManager" then return self.TargetManager
	end
end

function ScanController:MouseMove(actionName, inputState, inputObject)
	if not self.SkeletonManager then
		return Enum.ContextActionResult.Pass
	end
	return self.SkeletonManager:MouseMove(actionName, inputState, inputObject)
end

function ScanController:Trigger(actionName, inputState, inputObject)
	if not self.SkeletonManager then
		return Enum.ContextActionResult.Pass
	end
	return self.SkeletonManager:Trigger(actionName, inputState, inputObject)
end

function ScanController:Hold(actionName, inputState, inputObject)
	if not self.SkeletonManager then
		return Enum.ContextActionResult.Pass
	end
	return self.SkeletonManager:Hold(actionName, inputState, inputObject)
end

function ScanController:OnScroll(action, inputState, inputObject)
	if not self.SkeletonManager then
		return Enum.ContextActionResult.Pass
	end
	return self.SkeletonManager:OnScroll(action, inputState, inputObject)
end

function ScanController:ToggleCircle(bool)
	if not self.SkeletonManager then
		return
	end
	return self.SkeletonManager:ToggleCircle(bool)
end

function ScanController:ToggleScanView(bool)
	if not self.SkeletonManager then
		return
	end
	return self.SkeletonManager:ToggleScanView(bool)
end

function ScanController:Close(fully)
	local result
	if self.SkeletonManager then
		result = self.SkeletonManager:Close(fully)
	end

	return result
end

return ScanController