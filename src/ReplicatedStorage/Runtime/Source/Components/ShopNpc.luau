local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Mince = require(ReplicatedStorage.Modules.Mince)
local Signal = require(ReplicatedStorage.Modules.Signal)
local UI = require(ReplicatedStorage.Modules.UI)

local LocalPlayer = Players.LocalPlayer
local nextShopNpcId = 0

local function getPromptBasePart(model)
	local proxy = model:FindFirstChild("Proxy")
	if proxy then
		if proxy:IsA("BasePart") then
			return proxy
		end

		if proxy:IsA("Attachment") and proxy.Parent and proxy.Parent:IsA("BasePart") then
			return proxy.Parent
		end
	end

	if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
		return model.PrimaryPart
	end

	return model:FindFirstChildWhichIsA("BasePart", true)
end

local ShopNpc = Mince.Component({
	Tag = "ShopNpc",
	CreationParents = { workspace },
})

ShopNpc.Focused = Signal.new()
ShopNpc.Released = Signal.new()

local InteractIndicator = Mince:Get("InteractIndicator")
local FocusCameraController = Mince:Get("FocusCameraController")

function ShopNpc:_connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(self.Connections, connection)
	return connection
end

function ShopNpc:_setPromptEnabled()
	if self.Prompt then
		self.Prompt.Enabled = not self.IsFocused and self.Model:GetAttribute("ShopEnabled") ~= false
	end
end

function ShopNpc:_disconnectCloseInput()
	if self.CloseConnection then
		self.CloseConnection:Disconnect()
		self.CloseConnection = nil
	end
end

function ShopNpc:Construct()
	self.Connections = {}
	self.IsFocused = false
	self.IsDestroyed = false

	if not self.Instance:IsA("Model") then
		return warn("ShopNpc component must be attached to a Model", self.Instance)
	end

	self.Model = self.Instance
	nextShopNpcId += 1
	self.OwnerId = "ShopNpc_" .. tostring(nextShopNpcId)

	self.PromptPart = getPromptBasePart(self.Model)
	if not self.PromptPart then
		return warn("ShopNpc requires a BasePart, PrimaryPart, or Proxy", self.Model)
	end

	self.InteractIndicator = InteractIndicator.new(self.PromptPart)
	self.Prompt = self.InteractIndicator.ProximityPrompt
	self.Prompt.Name = "ShopNpcPrompt"
	self.Prompt.ObjectText = self.Model:GetAttribute("ShopObjectText") or "Shop"
	self.Prompt.ActionText = self.Model:GetAttribute("ShopActionText") or "Browse"
	self.Prompt.HoldDuration = self.Model:GetAttribute("ShopHoldDuration") or 0.15
	self.Prompt.MaxActivationDistance = self.Model:GetAttribute("ShopInteractDistance") or 10
	-- Shop proxies commonly sit inside the NPC rig or behind a counter, which
	-- makes Roblox reject the prompt even when the player is standing beside it.
	self.Prompt.RequiresLineOfSight = self.Model:GetAttribute("ShopRequiresLineOfSight") == true
	self:_setPromptEnabled()

	self:_connect(self.Model:GetAttributeChangedSignal("ShopEnabled"), function()
		self:_setPromptEnabled()
	end)

	self:_connect(self.Prompt.Triggered, function(player)
		if player == LocalPlayer then
			self:Focus()
		end
	end)
end

function ShopNpc:GetCameraOptions()
	return {
		OwnerId = self.OwnerId,
		Context = "ShopNpc",
		Distance = self.Model:GetAttribute("ShopCameraDistance") or 7,
		Height = self.Model:GetAttribute("ShopCameraHeight") or 1.75,
		SideOffset = self.Model:GetAttribute("ShopCameraSideOffset") or 1.25,
		FocusHeight = self.Model:GetAttribute("ShopCameraFocusHeight") or 0.25,
		LookSideOffset = self.Model:GetAttribute("ShopCameraLookSideOffset") or 4.5,
		LookHeightOffset = self.Model:GetAttribute("ShopCameraLookHeightOffset") or 0,
		FieldOfView = self.Model:GetAttribute("ShopCameraFieldOfView") or 82,
		Behind = self.Model:GetAttribute("ShopCameraBehind") == true,
		LockCharacter = self.Model:GetAttribute("ShopLockCharacter") ~= false,
	}
end

function ShopNpc:Focus()
	if self.IsDestroyed or not self.Prompt or not self.Model.Parent then
		return false
	end

	if self.IsFocused then
		return true
	end

	local shouldOpenStore = self.Model:GetAttribute("ShopOpenStore") ~= false
		and UI.Store ~= nil
		and type(UI.Store.ShowDocked) == "function"
	local cameraOptions = self:GetCameraOptions()

	if shouldOpenStore then
		UI.Store.ShowDocked({
			Dock = self.Model:GetAttribute("ShopDock") or "Left",
			FocusModel = self.Model,
			Camera = cameraOptions,
			ReleaseFocusOnHide = true,
			OnHidden = function()
				self:Release(true)
			end,
		})
	else
		local focused = FocusCameraController:FocusModel(self.Model, cameraOptions)
		if not focused then
			return false
		end
	end

	self.IsFocused = true
	self:_setPromptEnabled()
	self.Model:SetAttribute("ShopFocused", true)
	ShopNpc.Focused:Fire(self, self.Model)

	self:_disconnectCloseInput()

	self.CloseConnection = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end

		if
			input.KeyCode == Enum.KeyCode.Escape
			or input.KeyCode == Enum.KeyCode.Backspace
			or input.KeyCode == Enum.KeyCode.ButtonB
			then
				local store = UI.Store
				local storeVisible = store and type(store.IsVisible) == "function" and store.IsVisible()
				if storeVisible and type(store.Hide) == "function" then
				store.Hide()
			else
				self:Release()
			end
		end
	end)

	return true
end

function ShopNpc:Release(instant)
	if not self.IsFocused then
		return false
	end

	self.IsFocused = false
	self.Model:SetAttribute("ShopFocused", false)
	FocusCameraController:Release(self.OwnerId, instant)
	ShopNpc.Released:Fire(self, self.Model)

	self:_disconnectCloseInput()
	self:_setPromptEnabled()
	return true
end

function ShopNpc:Removing()
	if self.IsDestroyed then
		return
	end
	self.IsDestroyed = true

	self:Release(true)
	self:_disconnectCloseInput()

	if self.InteractIndicator and self.InteractIndicator.Stop then
		self.InteractIndicator:Stop(true)
	end
	self.InteractIndicator = nil

	for _, connection in self.Connections do
		connection:Disconnect()
	end
	table.clear(self.Connections)
	self.Prompt = nil
	self.PromptPart = nil
end

function ShopNpc:Destroying()
	self:Removing()
end

function ShopNpc.FocusModel(model)
	local component = ShopNpc:Get(model)
	if not component then
		return false
	end

	return component:Focus()
end

function ShopNpc.ReleaseModel(model, instant)
	local component = ShopNpc:Get(model)
	if not component then
		return false
	end

	return component:Release(instant)
end

return ShopNpc
