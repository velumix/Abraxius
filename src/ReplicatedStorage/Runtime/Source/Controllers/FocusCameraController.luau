local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local Mince = require(ReplicatedStorage.Modules.Mince)
local Signal = require(ReplicatedStorage.Modules.Signal)

local LocalPlayer = Players.LocalPlayer

local FocusCameraController = {
	Name = "FocusCameraController",

	FocusStarted = Signal.new(),
	FocusEnded = Signal.new(),

	DefaultTweenInfo = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	DefaultDistance = 7,
	DefaultHeight = 1.75,
	DefaultSideOffset = 1.25,
	DefaultFocusHeight = 0.25,
	DefaultLookSideOffset = 0,
	DefaultLookHeightOffset = 0,
	DefaultFieldOfView = 82,

	_activeFocus = nil,
	_activeTween = nil,
}

local function getCamera()
	return Workspace.CurrentCamera
end

local function getNumberOption(options, key, default)
	local value = options and options[key]
	if typeof(value) == "number" then
		return value
	end
	return default
end

local function getModelFocusPosition(model, focusHeight)
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head.Position + Vector3.new(0, focusHeight, 0)
	end

	local pivot = model:GetPivot()
	return pivot.Position + Vector3.new(0, focusHeight, 0)
end

function FocusCameraController:Setup()
	self.CameraControlManager = Mince:Get("CameraControlManager")
	self.CharacterController = Mince:Get("CharacterController")
end

function FocusCameraController:GetFocusCFrame(model, options)
	if not model or not model:IsA("Model") then
		return nil
	end

	local pivot = model:GetPivot()
	local distance = getNumberOption(options, "Distance", self.DefaultDistance)
	local height = getNumberOption(options, "Height", self.DefaultHeight)
	local sideOffset = getNumberOption(options, "SideOffset", self.DefaultSideOffset)
	local focusHeight = getNumberOption(options, "FocusHeight", self.DefaultFocusHeight)
	local lookSideOffset = getNumberOption(options, "LookSideOffset", self.DefaultLookSideOffset)
	local lookHeightOffset = getNumberOption(options, "LookHeightOffset", self.DefaultLookHeightOffset)
	local lookSign = options and options.Behind == true and -1 or 1

	local focusPosition = getModelFocusPosition(model, focusHeight)
	local lookPosition = focusPosition
		+ (pivot.RightVector * lookSideOffset)
		+ Vector3.new(0, lookHeightOffset, 0)
	local cameraPosition = focusPosition
		+ (pivot.LookVector * distance * lookSign)
		+ (pivot.RightVector * sideOffset)
		+ Vector3.new(0, height, 0)

	return CFrame.new(cameraPosition, lookPosition)
end

function FocusCameraController:IsFocused(ownerId)
	return self._activeFocus and self._activeFocus.OwnerId == ownerId
end

function FocusCameraController:FocusModel(model, options)
	options = options or {}

	local camera = getCamera()
	if not camera then
		return false
	end

	local targetCFrame = options.CFrame or self:GetFocusCFrame(model, options)
	if not targetCFrame then
		return false
	end

	local ownerId = options.OwnerId or "FocusCameraController"
	local priority = options.Priority or self.CameraControlManager.Priority.EXHIBIT

	local granted = self.CameraControlManager:RequestControl(ownerId, priority, {
		model = model,
		context = options.Context or "FocusCamera",
	})

	if not granted then
		return false
	end

	if self._activeTween then
		self._activeTween:Cancel()
		self._activeTween = nil
	end

	if self._activeFocus and self._activeFocus.OwnerId ~= ownerId then
		self:Release(self._activeFocus.OwnerId, true)
	end

	self._activeFocus = {
		OwnerId = ownerId,
		Model = model,
		PreviousCameraType = camera.CameraType,
		PreviousCameraSubject = camera.CameraSubject,
		PreviousCameraCFrame = camera.CFrame,
		PreviousFieldOfView = camera.FieldOfView,
		CharacterWasEnabled = self.CharacterController.IsEnabled,
	}

	if options.LockCharacter ~= false then
		self.CharacterController:SetEnabled(false)
	end

	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = options.FieldOfView or self.DefaultFieldOfView

	local tweenInfo = options.TweenInfo or self.DefaultTweenInfo
	if options.Instant == true then
		camera.CFrame = targetCFrame
	else
		self._activeTween = TweenService:Create(camera, tweenInfo, {
			CFrame = targetCFrame,
		})
		self._activeTween.Completed:Once(function()
			self._activeTween = nil
		end)
		self._activeTween:Play()
	end

	self.FocusStarted:Fire(ownerId, model)
	return true
end

function FocusCameraController:Release(ownerId, instant)
	local activeFocus = self._activeFocus
	if not activeFocus then
		return
	end

	if ownerId and activeFocus.OwnerId ~= ownerId then
		return
	end

	local camera = getCamera()

	if self._activeTween then
		self._activeTween:Cancel()
		self._activeTween = nil
	end

	self._activeFocus = nil
	self.CameraControlManager:ReleaseControl(activeFocus.OwnerId)

	if activeFocus.CharacterWasEnabled ~= false then
		self.CharacterController:SetEnabled(true)
	end

	if camera then
		local restoreSubject = activeFocus.PreviousCameraSubject
		if not restoreSubject or not restoreSubject.Parent then
			local character = LocalPlayer.Character
			restoreSubject = character and character:FindFirstChildOfClass("Humanoid")
		end

		if restoreSubject then
			camera.CameraSubject = restoreSubject
		end

		if instant == true then
			camera.CameraType = activeFocus.PreviousCameraType or Enum.CameraType.Custom
			camera.CFrame = activeFocus.PreviousCameraCFrame or camera.CFrame
			camera.FieldOfView = activeFocus.PreviousFieldOfView or 70
		else
			local restoreCFrame = activeFocus.PreviousCameraCFrame
			if restoreCFrame then
				local tween = TweenService:Create(camera, self.DefaultTweenInfo, {
					CFrame = restoreCFrame,
					FieldOfView = activeFocus.PreviousFieldOfView or 70,
				})
				self._activeTween = tween
				tween.Completed:Once(function()
					if self._activeTween == tween then
						self._activeTween = nil
					end
					camera.CameraType = activeFocus.PreviousCameraType or Enum.CameraType.Custom
				end)
				tween:Play()
			else
				camera.CameraType = activeFocus.PreviousCameraType or Enum.CameraType.Custom
				camera.FieldOfView = activeFocus.PreviousFieldOfView or 70
			end
		end
	end

	self.FocusEnded:Fire(activeFocus.OwnerId, activeFocus.Model)
end

return FocusCameraController
