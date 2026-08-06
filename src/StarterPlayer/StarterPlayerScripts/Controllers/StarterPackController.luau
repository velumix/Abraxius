local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local StarterPackController = Knit.CreateController({
	Name = "StarterPackController",
})

local PRODUCT_ID = 3606548877
local TIMER_TOTAL = 600
local REOPEN_AT_SECONDS = 300
local ROBUX_SYMBOL = utf8.char(0xE002)
local DEBUG = false

local State = {
	Idle = "idle",
	Prompting = "prompting",
	HudTimer = "hud_timer",
	Purchased = "purchased",
	Expired = "expired",
}

local TweenInfoConfig = {
	Open = TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	Close = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.In),
	Fade = TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	ButtonPop = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
}

local function log(fmt: string, ...)
	if DEBUG then
		print("[StarterPack] " .. string.format(fmt, ...))
	end
end

local function formatTime(seconds: number): string
	local mins = math.floor(seconds / 60)
	local secs = math.floor(seconds % 60)
	return string.format("%d:%02d", mins, secs)
end

function StarterPackController:KnitInit()
	self.player = Players.LocalPlayer
	self.service = Knit.GetService("StarterPackService")
	self.stateRemotes = ReplicatedStorage:WaitForChild("GameRemotes")

	self.lastState = nil
	self:_resetState()
	self:_initUi()
	self:_setupInput()
	self:_connectSignals()
end

function StarterPackController:KnitStart()
	task.spawn(function()
		self:_restoreFromServer()
		self.statusLoaded = true

		if self.pendingStatePayload then
			local payload = self.pendingStatePayload
			self.pendingStatePayload = nil
			self:_onStateChanged(payload)
		elseif self.player:GetAttribute("InMatch") then
			self:_hideAll("in match on load")
		else
			self:_autoShowPrompt()
		end
	end)
end

function StarterPackController:_resetState()
	self.state = {
		current = State.Idle,
		owned = false,
		dismissed = false,
		timeLeft = 0,
		expiresAt = 0,
		timerConn = nil,
		reopenedAtFive = false,
	}
	self.statusLoaded = false
	self.pendingStatePayload = nil
end

function StarterPackController:_initUi()
	local playerGui = self.player:WaitForChild("PlayerGui")
	local gui = playerGui:WaitForChild("StarterPack")
	gui.Enabled = true

	local holderFrame = gui:WaitForChild("HolderFrame")
	local promptFrame = holderFrame:WaitForChild("StarterPack")
	local hudBtn = gui:WaitForChild("StarterPackButton") :: ImageButton

	self.ui = {
		gui = gui,
		holderFrame = holderFrame,
		promptFrame = promptFrame,
		promptBg = promptFrame:WaitForChild("Background"),
		promptTimer = promptFrame:WaitForChild("Timer"),
		closeBtn = promptFrame:WaitForChild("CloseButton"),
		buyBtn = promptFrame:WaitForChild("BuyButton"),
		giftBtn = promptFrame:WaitForChild("GiftButton"),
		hudBtn = hudBtn,
		hudTimer = hudBtn:WaitForChild("Timer"),
		promptScale = self:_ensureUiScale(promptFrame),
		btnScale = self:_ensureUiScale(hudBtn),
	}

	self.layout = {
		promptFinalPos = promptFrame.Position,
		promptFinalSize = promptFrame.Size,
		btnFinalPos = hudBtn.Position,
	}

	self.defaultPromptTimerColor = self.ui.promptTimer.TextColor3
	self.defaultHudTimerColor = self.ui.hudTimer.TextColor3

	self.ui.hudBtn.Active = true
	self.ui.holderFrame.Visible = false
	self.ui.promptFrame.Visible = false
	self.ui.hudBtn.Visible = false

	self:_addButtonEffects(self.ui.closeBtn, true)
	self:_addButtonEffects(self.ui.buyBtn, false)
	self:_addButtonEffects(self.ui.giftBtn, false)

	-- External close hook so other UI managers can dismiss us.
	local closeEvent = gui:FindFirstChild("CloseStarterPack")
	if not closeEvent then
		closeEvent = Instance.new("BindableEvent")
		closeEvent.Name = "CloseStarterPack"
		closeEvent.Parent = gui
	end
	closeEvent.Event:Connect(function()
		-- Play the proper close animation instead of snapping off.
		self:_closePromptToHud()
	end)

	self:_renderStarterPackItems()
	self:_loadPrice()
end

function StarterPackController:_loadPrice()
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfoAsync(PRODUCT_ID, Enum.InfoType.Product)
		end)
		if not ok or typeof(info) ~= "table" or info.PriceInRobux == nil then
			warn("[StarterPack] failed to get product info:", info)
			return
		end

		local priceText = ROBUX_SYMBOL .. tostring(info.PriceInRobux)
		local priceLabel = self.ui.buyBtn:FindFirstChild("Price")
		if priceLabel and priceLabel:IsA("TextLabel") then
			priceLabel.Text = priceText
			local top = priceLabel:FindFirstChild("Top")
			if top and top:IsA("TextLabel") then
				top.Text = priceText
			end
		end
	end)
end

function StarterPackController:_closeOtherPanels()
	local playerGui = self.player:FindFirstChild("PlayerGui")
	if not playerGui then return end

	local function fireGuiEvent(guiName, eventName)
		local g = playerGui:FindFirstChild(guiName)
		local evt = g and g:FindFirstChild(eventName)
		if evt and evt:IsA("BindableEvent") then
			evt:Fire()
		end
	end

	fireGuiEvent("Settings", "CloseSettings")
	fireGuiEvent("Shop", "CloseShop")
	fireGuiEvent("CratesShop", "CloseCrateShop")
	fireGuiEvent("SeekerQueueGui", "CloseSeekerQueue")

	local inv = playerGui:FindFirstChild("Inventory")
	if inv then inv.Enabled = false end

	local results = playerGui:FindFirstChild("Results")
	if results then results.Enabled = false end
end

function StarterPackController:_renderStarterPackItems()
	local itemDisplay = self.ui.promptFrame:FindFirstChild("ItemDisplay")
	if not itemDisplay then
		return
	end

	for _, child in ipairs(itemDisplay:GetChildren()) do
		if child:IsA("Frame") and child.Name == "Template" and child.LayoutOrder == 2 then
			local content = child:FindFirstChild("Content")
			local icon = content and content:FindFirstChild("ItemIcon")
			if icon then
				-- Remove any legacy viewport frames so the set image render shows.
				for _, v in ipairs(icon:GetChildren()) do
					if v:IsA("ViewportFrame") then
						v:Destroy()
					end
				end
			end

			local nameLabel = child:FindFirstChild("ItemName")
			if nameLabel and nameLabel:IsA("TextLabel") then
				nameLabel.Text = "Darkrose Blade"
			end

			local rarityLabel = content and content:FindFirstChild("ItemName")
			if rarityLabel and rarityLabel:IsA("TextLabel") then
				rarityLabel.Text = "Exclusive"
			end
		end
	end
end

function StarterPackController:_ensureUiScale(instance: GuiObject): UIScale
	local scale = instance:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Parent = instance
	end
	return scale
end

function StarterPackController:_setupInput()
	self.ui.closeBtn.Activated:Connect(function()
		log("CloseButton activated")
		self:_closePromptToHud()
	end)

	self.ui.buyBtn.Activated:Connect(function()
		log("BuyButton activated")
		MarketplaceService:PromptProductPurchase(self.player, PRODUCT_ID)
	end)

	self.ui.giftBtn.Activated:Connect(function()
		log("GiftButton activated")
		local openGiftPicker = self.stateRemotes:FindFirstChild("OpenGiftPicker")
		if openGiftPicker then
			openGiftPicker:Fire(PRODUCT_ID, false)
		end
		self:_closePromptToHud()
	end)

	self.ui.hudBtn.Activated:Connect(function()
		log("HUD button activated | state=%s", self.state.current)
		if self.state.current == State.Prompting then
			self:_closePromptToHud()
		else
			self:_openPrompt()
		end
	end)

	self.player:GetAttributeChangedSignal("InMatch"):Connect(function()
		if self.player:GetAttribute("InMatch") then
			self:_hideAll("in match")
		end
	end)
	if self.player:GetAttribute("InMatch") then
		self:_hideAll("in match on load")
	end

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or input.KeyCode ~= Enum.KeyCode.P then
			return
		end
		self:_finishPurchase()
	end)
end

function StarterPackController:_connectSignals()
	self.stateRemotes:WaitForChild("StateChanged").OnClientEvent:Connect(function(payload)
		self:_onStateChanged(payload)
	end)

	self.service.Purchased:Connect(function()
		log("Server confirmed purchase")
		self:_finishPurchase()
	end)
end

function StarterPackController:_restoreFromServer()
	local ok, status = pcall(function()
		return self.service:GetStatus()
	end)
	if ok then
		print("[StarterPack] server status: " .. tostring(status and status.state))
		self:_handleServerStatus(status)
	else
		warn("[StarterPack] failed to get status: " .. tostring(status))
	end
end

function StarterPackController:_handleServerStatus(status)
	if not status then
		return
	end

	log("server status: %s", tostring(status.state))

	if status.state == "purchased" then
		self:_finishPurchase()
	elseif status.state == "expired" then
		self.state.current = State.Expired
		self:_hideAll("expired")
	elseif status.state == "active" then
		self.state.expiresAt = status.expiresAt
		self.state.timeLeft = math.max(0, self.state.expiresAt - os.time())
		self:_autoShowPrompt()
	elseif status.state == "not_started" then
		self.state.expiresAt = 0
	end
end

function StarterPackController:_onStateChanged(payload)
	local state = payload and payload.state
	if state == self.lastState then
		return
	end

	if not self.statusLoaded then
		self.pendingStatePayload = payload
		return
	end

	self.lastState = state

	local inMatch = self.player:GetAttribute("InMatch") == true

	if inMatch then
		self:_hideAll("in match")
	elseif state == "INTERMISSION" then
		self:_autoShowPrompt()
	else
		self:_hideAll(state or "not intermission")
	end
end

function StarterPackController:_autoShowPrompt()
	if not self.statusLoaded then return end
	if self.state.owned then return end
	if self.state.current == State.Purchased or self.state.current == State.Expired then return end
	if self.player:GetAttribute("InMatch") then return end

	-- Use the server deadline so the timer is real-time / datastore authoritative.
	if self.state.expiresAt == 0 then
		self.state.expiresAt = self.service:StartTimer()
	end
	if self.state.expiresAt == 0 then
		self.state.expiresAt = os.time() + TIMER_TOTAL
	end

	self.state.timeLeft = math.max(0, self.state.expiresAt - os.time())
	if self.state.timeLeft <= 0 then return end

	if self.state.timeLeft > REOPEN_AT_SECONDS then
		self.state.reopenedAtFive = false
	end

	if self.state.dismissed then
		if self.state.current ~= State.HudTimer then
			self.state.current = State.HudTimer
			self:_showHudButton()
		end
	else
		if self.state.current ~= State.Prompting then
			self:_openPrompt()
		end
	end

	self:_startTimer()
	self:_tryReopenAtFive()

	log("prompt shown")
end

function StarterPackController:_tryReopenAtFive()
	if self.state.owned then return end
	if self.state.current == State.Purchased or self.state.current == State.Expired then return end
	if self.player:GetAttribute("InMatch") then return end
	if self.state.timeLeft > REOPEN_AT_SECONDS then return end
	if self.state.current == State.Prompting then
		self.state.reopenedAtFive = true
		return
	end
	if self.state.reopenedAtFive then return end

	self.state.reopenedAtFive = true
	self.state.dismissed = false
	self:_openPrompt()
	log("re-opened at 5 minutes")
end

function StarterPackController:_openPrompt()
	if self.state.current == State.Purchased or self.state.current == State.Expired then
		return
	end
	if self.state.current == State.Prompting then
		return
	end

	self.state.current = State.Prompting
	self:_updateTimerLabels()
	log("openPrompt")

	self:_closeOtherPanels()
	self:_hideHudButton()

	local ui = self.ui
	ui.holderFrame.Visible = true
	ui.promptFrame.Position = self.layout.btnFinalPos
	ui.promptFrame.Size = self.layout.promptFinalSize
	ui.promptScale.Scale = 0
	ui.promptBg.ImageTransparency = 1
	ui.promptFrame.Visible = true

	TweenService:Create(ui.promptScale, TweenInfoConfig.Open, { Scale = 1 }):Play()
	TweenService:Create(ui.promptFrame, TweenInfoConfig.Open, { Position = self.layout.promptFinalPos }):Play()
	TweenService:Create(ui.promptBg, TweenInfoConfig.Fade, { ImageTransparency = 0 }):Play()
end

function StarterPackController:_closePromptToHud()
	if self.state.current ~= State.Prompting then
		return
	end

	self.state.dismissed = true
	self.state.current = State.HudTimer
	self:_updateTimerLabels()
	log("closePromptToHud")

	local ui = self.ui
	TweenService:Create(ui.promptBg, TweenInfoConfig.Fade, { ImageTransparency = 1 }):Play()

	local shrink = TweenService:Create(ui.promptScale, TweenInfoConfig.Close, { Scale = 0 })
	local move = TweenService:Create(ui.promptFrame, TweenInfoConfig.Close, { Position = self.layout.btnFinalPos })
	shrink:Play()
	move:Play()

	shrink.Completed:Once(function()
		ui.promptFrame.Visible = false
		ui.holderFrame.Visible = false
		ui.promptFrame.Position = self.layout.promptFinalPos
		ui.promptFrame.Size = self.layout.promptFinalSize
		ui.promptScale.Scale = 1
		ui.promptBg.ImageTransparency = 0
		self:_showHudButton()
	end)
end

function StarterPackController:_showHudButton()
	local scale = self.ui.btnScale
	scale.Scale = 0
	self.ui.hudBtn.Visible = true
	self.ui.hudBtn:SetAttribute("Enabled", true)
	TweenService:Create(scale, TweenInfoConfig.ButtonPop, { Scale = 1 }):Play()
	log("HUD button shown")
end

function StarterPackController:_hideHudButton()
	self.ui.hudBtn:SetAttribute("Enabled", false)
	local tween = TweenService:Create(self.ui.btnScale, TweenInfoConfig.Fade, { Scale = 0 })
	tween:Play()
	tween.Completed:Once(function()
		self.ui.hudBtn.Visible = false
		self.ui.btnScale.Scale = 1
	end)
end

function StarterPackController:_hideAll(reason: string)
	self.ui.holderFrame.Visible = false
	self.ui.promptFrame.Visible = false
	self.ui.hudBtn.Visible = false
	self.ui.hudBtn:SetAttribute("Enabled", false)

	if self.state.current ~= State.Purchased and self.state.current ~= State.Expired then
		self.state.current = State.Idle
	end

	log("hideAll: %s", reason)
end

function StarterPackController:_finishPurchase()
	if self.state.owned then
		return
	end

	self.state.owned = true
	self:_stopTimer()
	self.state.current = State.Purchased
	self.ui.holderFrame.Visible = false
	self.ui.promptFrame.Visible = false
	self.ui.hudBtn.Visible = false
	self.ui.hudBtn:SetAttribute("Enabled", false)
	log("purchased")
end

function StarterPackController:_startTimer()
	self:_stopTimer()

	self.state.timerConn = RunService.Heartbeat:Connect(function()
		local prev = self.state.timeLeft
		self.state.timeLeft = math.max(0, self.state.expiresAt - os.time())
		self:_updateTimerLabels()

		if prev > REOPEN_AT_SECONDS and self.state.timeLeft <= REOPEN_AT_SECONDS then
			self:_tryReopenAtFive()
		end

		if self.state.timeLeft <= 0 then
			self:_stopTimer()
			self.state.current = State.Expired
			self.ui.hudBtn.Visible = false
			self.ui.hudBtn:SetAttribute("Enabled", false)
		end
	end)
end

function StarterPackController:_stopTimer()
	if self.state.timerConn then
		self.state.timerConn:Disconnect()
		self.state.timerConn = nil
	end
end

function StarterPackController:_updateTimerLabels()
	local text = formatTime(self.state.timeLeft)
	self.ui.promptTimer.Text = text
	self.ui.hudTimer.Text = text

	local urgent = self.state.timeLeft <= 60
	local color = urgent and Color3.fromRGB(255, 0, 0) or self.defaultHudTimerColor
	self.ui.promptTimer.TextColor3 = color
	self.ui.hudTimer.TextColor3 = color
end

function StarterPackController:_addButtonEffects(button: GuiButton, isClose: boolean)
	local scale = self:_ensureUiScale(button)
	local baseRot = button.Rotation

	local hoverScale = 1.1
	local pressScale = 0.92
	local hoverRot = isClose and 12 or 0
	local clickRot = isClose and 22 or 0

	local activeTween = nil
	local function playTween(tween)
		if activeTween then
			activeTween:Cancel()
		end
		activeTween = tween
		tween:Play()
	end

	button.MouseEnter:Connect(function()
		playTween(TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = hoverScale }))
		if isClose then
			playTween(TweenService:Create(button, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = hoverRot }))
		end
	end)

	button.MouseLeave:Connect(function()
		playTween(TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }))
		if isClose then
			playTween(TweenService:Create(button, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Rotation = baseRot }))
		end
	end)

	button.MouseButton1Down:Connect(function()
		playTween(TweenService:Create(scale, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = pressScale }))
		if isClose then
			playTween(TweenService:Create(button, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Rotation = clickRot }))
		end
	end)

	button.MouseButton1Up:Connect(function()
		playTween(TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = hoverScale }))
		if isClose then
			playTween(TweenService:Create(button, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = hoverRot }))
		end
	end)
end

return StarterPackController
