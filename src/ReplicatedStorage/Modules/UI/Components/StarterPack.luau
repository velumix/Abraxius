local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local UIAudio = require(Modules.UI.UIAudio)

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local GAMEPASS_ID = 1699543975

local SHOW_TWEEN = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local HIDE_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In)

local BUTTON_HOVER_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local BUTTON_CLICK_TWEEN = TweenInfo.new(0.15, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)

local BUTTON_HOVER_SCALE = 1.1
local BUTTON_CLICK_SCALE = 0.95

local StarterPack = {
	ComponentName = "Starterpack",
	Gui = nil,
	Main = nil,
	MainContainer = nil,
	BuyButton = nil,
	ExitButton = nil,
	Scale = nil,
	Control = nil,
	Initialized = false,
	IsOpen = false,
	_activeTween = nil,
	_activeTweenConnection = nil,
}

local function bindConnection(self, connection)
	self._connections = self._connections or {}
	if connection then
		table.insert(self._connections, connection)
	end
end

local function disconnectAll(self)
	if not self._connections then
		return
	end

	for _, connection in ipairs(self._connections) do
		if connection and connection.Connected then
			connection:Disconnect()
		end
	end
	self._connections = {}
end

local function stopActiveTween(self)
	if self._activeTween then
		self._activeTween:Cancel()
		self._activeTween = nil
	end
	if self._activeTweenConnection then
		self._activeTweenConnection:Disconnect()
		self._activeTweenConnection = nil
	end
end

local function playScaleTween(self, targetScale, tweenInfo, onComplete)
	if not self.Scale then
		if onComplete then
			onComplete()
		end
		return
	end

	stopActiveTween(self)

	local tween = TweenService:Create(self.Scale, tweenInfo, {
		Scale = targetScale,
	})
	self._activeTween = tween
	self._activeTweenConnection = tween.Completed:Connect(function()
		if self._activeTween == tween then
			stopActiveTween(self)
			if onComplete then
				onComplete()
			end
		end
	end)

	tween:Play()
end

local function configureControl(self)
	if not self.UI or not self.Main then
		return nil
	end

	local control = self.Control
	if not control then
		control = self.UI:Get(self.Main)
		self.Control = control
	end

	local startPosition = self.Main.Position
	control.ComponentName = self.ComponentName
	control.StartPosition = startPosition
	control.HiddenPosition = UDim2.new(startPosition.X.Scale, startPosition.X.Offset, startPosition.Y.Scale - 1, startPosition.Y.Offset)
	control.TweenStyles = {
		InTweenInfo = SHOW_TWEEN,
		OutTweenInfo = HIDE_TWEEN,
	}
	control:CreateTweens()

	return control
end

local function setupButtonEffects(button)
	if not button then return end

	button.AutoButtonColor = false

	local originalSize = button.Size
	local hoverSize = UDim2.new(
		originalSize.X.Scale * BUTTON_HOVER_SCALE,
		originalSize.X.Offset ~= 0 and math.floor(originalSize.X.Offset * BUTTON_HOVER_SCALE + 0.5) or originalSize.X.Offset,
		originalSize.Y.Scale * BUTTON_HOVER_SCALE,
		originalSize.Y.Offset ~= 0 and math.floor(originalSize.Y.Offset * BUTTON_HOVER_SCALE + 0.5) or originalSize.Y.Offset
	)
	local clickSize = UDim2.new(
		originalSize.X.Scale * BUTTON_CLICK_SCALE,
		originalSize.X.Offset ~= 0 and math.floor(originalSize.X.Offset * BUTTON_CLICK_SCALE + 0.5) or originalSize.X.Offset,
		originalSize.Y.Scale * BUTTON_CLICK_SCALE,
		originalSize.Y.Offset ~= 0 and math.floor(originalSize.Y.Offset * BUTTON_CLICK_SCALE + 0.5) or originalSize.Y.Offset
	)

	local activeTweens = {}

	local function cleanupTweens(...)
		local specificKeys = {...}
		if #specificKeys > 0 then
			for _, key in specificKeys do
				if activeTweens[key] then
					activeTweens[key]:Cancel()
					activeTweens[key] = nil
				end
			end
		end
	end

	local function createTween(object, tweenInfo, properties, key)
		cleanupTweens(key)
		local tween = TweenService:Create(object, tweenInfo, properties)
		activeTweens[key] = tween
		tween.Completed:Connect(function()
			activeTweens[key] = nil
		end)
		return tween
	end

	local isHovered = false

	button.MouseEnter:Connect(function()
		isHovered = true
		createTween(button, BUTTON_HOVER_TWEEN, {Size = hoverSize}, "hover"):Play()
	end)

	button.MouseLeave:Connect(function()
		isHovered = false
		createTween(button, BUTTON_HOVER_TWEEN, {Size = originalSize}, "leave"):Play()
	end)

	button.MouseButton1Down:Connect(function()
		createTween(button, BUTTON_CLICK_TWEEN, {Size = clickSize}, "click"):Play()
	end)

	button.MouseButton1Up:Connect(function()
		if isHovered then
			createTween(button, BUTTON_HOVER_TWEEN, {Size = hoverSize}, "hover"):Play()
		else
			createTween(button, BUTTON_HOVER_TWEEN, {Size = originalSize}, "leave"):Play()
		end
	end)
end

function StarterPack:Build()
	if self.Initialized then
		return
	end

	self.Gui = PlayerGui:FindFirstChild("Starterpack") or PlayerGui:WaitForChild("Starterpack", 5)
	if not self.Gui then
		warn("missing Starterpack ScreenGui in PlayerGui")
		return
	end

	self.Main = self.Gui:FindFirstChild("Main")
	if not self.Main then
		warn("missing Main frame")
		return
	end

	self.MainContainer = self.Main:FindFirstChild("MainContainer", true)
	self.BuyButton = self.Main:FindFirstChild("Buy", true)
	self.ExitButton = self.Main:FindFirstChild("Exit", true)
	self.Scale = self.Main:FindFirstChild("Scale")

	if self.Gui.Enabled == nil then
		self.Gui.Enabled = false
	else
		self.Gui.Enabled = false
	end

	self.Main.Visible = false
	if self.Scale then
		self.Scale.Scale = 0
	end

	if self.BuyButton and self.BuyButton:IsA("GuiButton") then
		setupButtonEffects(self.BuyButton)
		bindConnection(self, self.BuyButton.Activated:Connect(function()
			MarketplaceService:PromptGamePassPurchase(LocalPlayer, GAMEPASS_ID)
			if UIAudio and UIAudio.PlayNotification then
				UIAudio.PlayNotification("Click")
			end
		end))
	end

	if self.ExitButton and self.ExitButton:IsA("GuiButton") then
		bindConnection(self, self.ExitButton.Activated:Connect(function()
			self:Hide()
		end))
	end

	self.Initialized = true
end

function StarterPack:Show()
	self:Build()
	if not self.Gui or not self.Main then
		return
	end

	if self.IsOpen then
		self.Gui.Enabled = true
		return
	end

	self.Gui.Enabled = true
	local control = configureControl(self)
	if self.Scale then
		self.Scale.Scale = 1
	end
	if control then
		self.Main.Position = control.Positions.Hidden
		control:Show()
	else
		self.Main.Visible = true
	end

	self.IsOpen = true

	if UIAudio and UIAudio.PlayNotification then
		UIAudio.PlayNotification("Open")
	end
end

function StarterPack:Hide()
	if not self.Gui or not self.Main then
		return
	end

	if not self.IsOpen and not self.Gui.Enabled then
		return
	end

	local finalize = function()
		if self.Gui then
			self.Gui.Enabled = false
		end
		if self.Main then
			self.Main.Visible = false
		end
		if self.Scale then
			self.Scale.Scale = 1
		end
	end

	local wasOpen = self.IsOpen
	self.IsOpen = false

	if wasOpen then
		if UIAudio and UIAudio.PlayNotification then
			UIAudio.PlayNotification("Close")
		end
		local control = configureControl(self)
		if control then
			control:Hide()
			finalize()
		else
			finalize()
		end
	else
		finalize()
	end
end

function StarterPack:Toggle()
	if self:IsVisible() then
		self:Hide()
	else
		self:Show()
	end
end

function StarterPack:IsVisible()
	return self.IsOpen == true
end

function StarterPack.Init(UI)
	StarterPack.UI = UI
	StarterPack:Build()

	if LocalPlayer:GetAttribute("StarterPackPass") == true then
		return
	end

	bindConnection(StarterPack, LocalPlayer:GetAttributeChangedSignal("StarterPackPass"):Connect(function()
		if LocalPlayer:GetAttribute("StarterPackPass") == true then
			StarterPack:Hide()
		end
	end))
end

function StarterPack.Destroy()
	stopActiveTween(StarterPack)
	disconnectAll(StarterPack)
	StarterPack.Gui = nil
	StarterPack.Main = nil
	StarterPack.MainContainer = nil
	StarterPack.BuyButton = nil
	StarterPack.ExitButton = nil
	StarterPack.Scale = nil
	StarterPack.Control = nil
	StarterPack.Initialized = false
	StarterPack.IsOpen = false
end

return StarterPack
