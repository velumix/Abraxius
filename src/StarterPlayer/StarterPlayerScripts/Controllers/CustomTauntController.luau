local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local MarketplaceService = game:GetService("MarketplaceService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local UISounds = require(ReplicatedStorage:WaitForChild("UISounds"))
local Constants = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Constants"))

local CustomTauntController = Knit.CreateController({
	Name = "CustomTauntController",
})

local GAMEPASS_ID = Constants.Gamepasses.CUSTOM_TAUNT

local COLORS = {
	dim = Color3.fromRGB(100, 100, 105),
	muted = Color3.fromRGB(120, 120, 125),
	ok = Color3.fromRGB(55, 150, 60),
	warn = Color3.fromRGB(255, 200, 90),
	error = Color3.fromRGB(255, 120, 120),
	accent = Color3.fromRGB(150, 190, 255),
}

function CustomTauntController:KnitInit()
	self.player = Players.LocalPlayer
	self.playerGui = self.player:WaitForChild("PlayerGui")
	self.service = Knit.GetService("CustomTauntService")

	self.status = { owner = false, soundId = "" }
	self.cachedNames = {}
	self.statusToken = 0

	self.previewSound = Instance.new("Sound")
	self.previewSound.Name = "CustomTauntPreview"
	self.previewSound.Volume = 0.6
	self.previewSound.Parent = SoundService

	self:_findUi()
	self:_connectSignals()
end

function CustomTauntController:KnitStart()
	self:_refreshStatus()
	self:_preload()
end

-- ===== UI discovery =====
function CustomTauntController:_findUi()
	local settingsGui = self.playerGui:WaitForChild("Settings", 10)
	if not settingsGui then
		warn("[CustomTaunt] Settings ScreenGui not found.")
		return
	end

	local holder = settingsGui:WaitForChild("HolderFrame", 5)
	local settingsFrame = holder and holder:WaitForChild("Settings", 5)
	local scroll = settingsFrame and settingsFrame:WaitForChild("ScrollingFrame", 5)
	local row = scroll and scroll:WaitForChild("CustomTaunt", 5)
	if not row then
		warn("[CustomTaunt] CustomTaunt row not found in Settings.")
		return
	end

	local content = row:WaitForChild("Content", 5)
	if not content then
		warn("[CustomTaunt] CustomTaunt Content frame not found.")
		return
	end

	self.settingsGui = settingsGui
	self.uiRow = row
	self.uiContent = content

	self.equippedCard = content:WaitForChild("EquippedCard", 5)
	self.equippedValue = self.equippedCard and self.equippedCard:WaitForChild("EquippedValue")

	local inputRow = content:WaitForChild("InputRow", 5)
	self.input = inputRow and inputRow:WaitForChild("SoundIdInput")
	self.previewBtn = inputRow and inputRow:WaitForChild("Preview")

	local buttonRow = content:WaitForChild("ButtonRow", 5)
	self.saveBtn = buttonRow and buttonRow:WaitForChild("Save")
	self.clearBtn = buttonRow and buttonRow:WaitForChild("Clear")

	self.hintLabel = content:WaitForChild("Hint", 5)
	self.hintDefaultText = self.hintLabel and self.hintLabel.Text or "Only nearby seekers will hear it."
	self.hintDefaultColor = self.hintLabel and self.hintLabel.TextColor3 or Color3.fromRGB(243, 243, 255)

	self:_validateUi()
	self:_bindInput()
	self:_bindSettingsClose()
	self:_bindSounds()
end

function CustomTauntController:_validateUi()
	local missing = {}
	if not self.equippedValue then table.insert(missing, "EquippedValue") end
	if not self.input then table.insert(missing, "SoundIdInput") end
	if not self.previewBtn then table.insert(missing, "Preview") end
	if not self.saveBtn then table.insert(missing, "Save") end
	if not self.clearBtn then table.insert(missing, "Clear") end
	if not self.hintLabel then table.insert(missing, "Hint") end
	if #missing > 0 then
		warn("[CustomTaunt] Missing UI elements:", table.concat(missing, ", "))
	end
end

function CustomTauntController:_bindButtonTweens(button)
	if not button then return end
	local TWEEN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local function getScale()
		local s = button:FindFirstChildOfClass("UIScale")
		if not s then
			s = Instance.new("UIScale")
			s.Scale = 1
			s.Parent = button
		end
		return s
	end
	button.MouseEnter:Connect(function() TweenService:Create(getScale(), TWEEN, { Scale = 1.04 }):Play() end)
	button.MouseLeave:Connect(function() TweenService:Create(getScale(), TWEEN, { Scale = 1 }):Play() end)
	button.MouseButton1Down:Connect(function() TweenService:Create(getScale(), TWEEN, { Scale = 0.96 }):Play() end)
	button.MouseButton1Up:Connect(function() TweenService:Create(getScale(), TWEEN, { Scale = 1.04 }):Play() end)
end

function CustomTauntController:_bindSounds()
	local function bind(button)
		if not button then return end
		UISounds.bindButton(button, { tween = false })
		self:_bindButtonTweens(button)
	end
	bind(self.saveBtn)
	bind(self.clearBtn)
	bind(self.previewBtn)
end

function CustomTauntController:_bindSettingsClose()
	if not self.settingsGui then return end
	self.settingsGui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if not self.settingsGui.Enabled then
			self:_stopPreview()
		end
	end)
end

function CustomTauntController:_bindInput()
	if self.previewBtn then
		self.previewBtn.MouseButton1Click:Connect(function()
			if not self.previewSound then return end
			self:_ensureOwnership(function()
				if self.previewSound.IsPlaying then
					self:_stopPreview()
					self:_setStatus("Preview stopped.", COLORS.dim)
				elseif self.input then
					self:_playPreview(self.input.Text)
				end
			end)
		end)
	end

	if self.previewSound then
		self.previewSound.Ended:Connect(function()
			if self.hintLabel and self.hintLabel.Text == "Playing preview..." then
				self:_setStatus("Preview finished.", COLORS.dim)
			end
		end)
	end

	if self.input then
		self.input.Focused:Connect(function()
			self:_ensureOwnership(function()
				-- owned: let them type
			end, function()
				-- cancelled: release focus so they can't type without owning
				if self.input then self.input:ReleaseFocus() end
			end)
		end)
	end

	if self.saveBtn then
		self.saveBtn.MouseButton1Click:Connect(function()
			if not self.input then return end
			self:_ensureOwnership(function()
				local raw = self.input.Text or ""
				local id = self:_formatSoundId(raw)
				if id == "" then
					self:_setStatus("Enter a Sound ID first.", COLORS.warn)
					return
				end
				if tonumber(id) == nil then
					self:_setStatus("Sound ID must be a number.", COLORS.error)
					return
				end
				self:_stopPreview()
				self:_sendSave(id)
			end)
		end)
	end

	if self.clearBtn then
		self.clearBtn.MouseButton1Click:Connect(function()
			self:_ensureOwnership(function()
				if self.input then self.input.Text = "" end
				self:_stopPreview()
				self:_sendSave("")
			end)
		end)
	end
end

function CustomTauntController:_connectSignals()
	self.service.OwnershipChanged:Connect(function(owns)
		self.status.owner = owns
	end)

	self.service.SoundIdChanged:Connect(function(soundId)
		self.status.soundId = soundId
		self:_updateEquippedDisplay()
		self:_preload()
		if self.input then
			self.input.Text = soundId or ""
		end
	end)
end

-- ===== logic =====
function CustomTauntController:_setStatus(text, color)
	if not self.hintLabel then return end
	self.statusToken += 1
	local token = self.statusToken
	self.hintLabel.Text = text
	self.hintLabel.TextColor3 = color or self.hintDefaultColor
	task.delay(3, function()
		if self.statusToken == token then
			self.hintLabel.Text = self.hintDefaultText
			self.hintLabel.TextColor3 = self.hintDefaultColor
		end
	end)
end

function CustomTauntController:_formatSoundId(rawId)
	return tostring(rawId or ""):gsub("rbxassetid://", ""):gsub("%s", "")
end

function CustomTauntController:_updateEquippedDisplay()
	if not self.equippedValue then return end
	local id = self.status.soundId or ""
	if id == "" then
		self.equippedValue.Text = "Random taunts"
		self.equippedValue.TextColor3 = COLORS.muted
		return
	end

	self.equippedValue.TextColor3 = COLORS.ok

	local cached = self.cachedNames[id]
	if cached then
		self.equippedValue.Text = cached
		return
	end

	self.equippedValue.Text = id .. " (loading...)"

	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfoAsync(tonumber(id), Enum.InfoType.Asset)
		end)

		local displayName
		if ok and info and info.Name and info.Name ~= "" then
			displayName = info.Name .. " (" .. id .. ")"
		else
			displayName = "Sound (" .. id .. ")"
		end

		self.cachedNames[id] = displayName
		if self.status.soundId == id then
			self.equippedValue.Text = displayName
		end
	end)
end

function CustomTauntController:_preloadSound(assetIds)
	if not assetIds then return end
	if typeof(assetIds) == "string" then
		assetIds = { assetIds }
	end
	if #assetIds == 0 then return end

	task.spawn(function()
		local ok, err = pcall(function()
			ContentProvider:PreloadAsync(assetIds)
		end)
		if not ok then
			warn("[CustomTaunt] preload failed:", tostring(err))
		end
	end)
end

function CustomTauntController:_preload()
	local tauntFolder = SoundService:FindFirstChild("TauntSounds")
	if tauntFolder then
		local ids = {}
		for _, s in ipairs(tauntFolder:GetChildren()) do
			if s:IsA("Sound") and s.SoundId ~= "" then
				table.insert(ids, s.SoundId)
			end
		end
		if #ids > 0 then
			self:_preloadSound(ids)
		end
	end

	local customId = self.status.soundId
	if customId and customId ~= "" then
		self:_preloadSound("rbxassetid://" .. customId)
	end
end

function CustomTauntController:_stopPreview()
	if not self.previewSound then return end
	self.previewSound:Stop()
	self.previewSound.SoundId = ""
end

function CustomTauntController:_playPreview(rawId)
	if not self.previewSound then return end
	local id = self:_formatSoundId(rawId)
	if id == "" or tonumber(id) == nil then
		self:_setStatus("Enter a valid Sound ID first.", COLORS.warn)
		return
	end

	self:_stopPreview()
	self.previewSound.SoundId = "rbxassetid://" .. id
	local loaded = false
	local loadConn
	loadConn = self.previewSound.Loaded:Connect(function()
		loaded = true
		if loadConn then loadConn:Disconnect() end
	end)

	local ok, err = pcall(function()
		self.previewSound:Play()
	end)
	if not ok then
		if loadConn then loadConn:Disconnect() end
		self:_setStatus("Preview failed.", COLORS.error)
		return
	end

	self:_setStatus("Playing preview...", COLORS.accent)

	task.delay(0.8, function()
		if not loaded then
			self:_setStatus("Sound couldn't load.", COLORS.error)
			self:_stopPreview()
		end
	end)
end

function CustomTauntController:_promptGamepass(): boolean
	local signal = Instance.new("BindableEvent")
	local purchased = false
	local conn
	conn = MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamepassId, wasPurchased)
		if player ~= self.player or gamepassId ~= GAMEPASS_ID then return end
		purchased = wasPurchased == true
		signal:Fire()
		if conn then conn:Disconnect() end
	end)

	MarketplaceService:PromptGamePassPurchase(self.player, GAMEPASS_ID)
	signal.Event:Wait()
	signal:Destroy()
	return purchased
end

function CustomTauntController:_ensureOwnership(onOwned, onCancelled)
	if self.status.owner then
		onOwned()
		return
	end
	if self._prompting then
		while self._prompting do task.wait() end
		if self.status.owner then
			onOwned()
		elseif onCancelled then
			onCancelled()
		end
		return
	end

	self._prompting = true
	self:_setStatus("Purchase the Custom Taunt gamepass to use this feature.", COLORS.warn)
	local purchased = self:_promptGamepass()
	self._prompting = false

	if purchased then
		self.status.owner = true
		onOwned()
	elseif onCancelled then
		onCancelled()
	end
end

function CustomTauntController:_sendSave(soundId)
	local ok, result = self.service:SetSoundId(soundId)
	if ok then
		self.status.soundId = soundId
		self:_updateEquippedDisplay()
		self:_setStatus(result or "Saved!", COLORS.ok)
		return
	end

	self:_setStatus(result or "Failed to save.", COLORS.error)
end

function CustomTauntController:_refreshStatus()
	local s = self.service:GetStatus()
	if s then
		self.status = s
	end
	if self.input and self.status.soundId then
		self.input.Text = self.status.soundId
	end
	self:_updateEquippedDisplay()
	self:_preload()
end

return CustomTauntController
