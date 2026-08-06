export type BackpackConfig = {
	ModuleName: string,
	KeepVRTopbarOpen: boolean,
	VRIsExclusive: boolean,
	VRClosesNonExclusive: boolean,
}

export type SlotData = {
	Tool: Tool?,
	Frame: GuiObject,
	ToolIcon: ImageLabel?,
	ModelPreview: ViewportFrame?,
	ToolName: TextLabel,
	ToolTip: TextLabel?,
	Index: number,
	IsEquipped: boolean,
}

export type BackpackState = {
	IsOpen: boolean,
	OpenClose: (() -> ())?,
	StateChanged: BindableEvent,
	Slots: {[number]: SlotData},
	HotbarSlots: {[number]: SlotData},
	InventorySlots: {[number]: SlotData},
}

export type UIConstants = {
	ICON_SIZE: number,
	FONT_SIZE: number,
	ICON_BUFFER: number,
	BACKGROUND_FADE: number,
	BACKGROUND_COLOR: Color3,
	HOTBAR_SLOTS_FULL: number,
	HOTBAR_SLOTS_VR: number,
	HOTBAR_SLOTS_MINI: number,
	INVENTORY_ROWS_FULL: number,
	INVENTORY_ROWS_VR: number,
	INVENTORY_ROWS_MINI: number,
}

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local UserInputService = game:GetService('UserInputService')
local PlayersService = game:GetService('Players')
local StarterGui = game:GetService('StarterGui')
local GuiService = game:GetService('GuiService')
local CollectionService = game:GetService('CollectionService')
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService')
local VRService = game:GetService('VRService')

local Modules = ReplicatedStorage.Modules

local UIColors = require(Modules.UI.UIColors)
local UIFactory = require(Modules.UI.UIFactory)
local UI = require(Modules.UI)

local BackpackScript: BackpackState = {
	IsOpen = false,
	OpenClose = nil,
	StateChanged = Instance.new("BindableEvent"),
	Slots = {},
	HotbarSlots = {},
	InventorySlots = {},
}

local Config: BackpackConfig = {
	ModuleName = "Backpack",
	KeepVRTopbarOpen = true,
	VRIsExclusive = true,
	VRClosesNonExclusive = true,
}

local UIConstants: UIConstants = {
	ICON_SIZE = 60,
	FONT_SIZE = 14,
	ICON_BUFFER = 5,
	BACKGROUND_FADE = 0.2,
	BACKGROUND_COLOR = UIColors.Card,
	HOTBAR_SLOTS_FULL = 10,
	HOTBAR_SLOTS_VR = 3,
	HOTBAR_SLOTS_MINI = 3,
	INVENTORY_ROWS_FULL = 4,
	INVENTORY_ROWS_VR = 3,
	INVENTORY_ROWS_MINI = 2,
}

local VR_FADE_TIME = 1
local VR_PANEL_RESOLUTION = 100

local SLOT_DRAGGABLE_COLOR = UIColors.ButtonHover
local SLOT_EQUIPPED_TINT = UIColors.TextLight
local SLOT_SELECTED_TINT = UIColors.Text
local SLOT_IDLE_TINT = UIColors.TextSecondary
local SLOT_FADE_LOCKED = 0.7
local SLOT_BORDER_COLOR = UIColors.Stroke
local SLOT_EQUIPPED_STROKE_COLOR = Color3.new(1, 1, 1)
local SLOT_EQUIPPED_STROKE_THICKNESS = 1.25
local SLOT_SELECTED_BG_TRANSPARENCY = 0.15
local SLOT_EQUIPPED_BG_TRANSPARENCY = 0.05
local SLOT_BACKGROUND_COLOR = Color3.fromRGB(10, 16, 28)
local SLOT_SELECTED_BG_COLOR = Color3.fromRGB(14, 24, 40)
local SLOT_EQUIPPED_BG_COLOR = Color3.fromRGB(14, 30, 50)
local SLOT_PULSE_SIZE = 6
local SLOT_PULSE_IN_TIME = 0.08
local SLOT_PULSE_OUT_TIME = 0.12

local DPV_BLOCKED_MESSAGE = "You must be swimming to use the DPV."
local DPV_NOTIFY_COOLDOWN = 1.5

local TOOLTIP_BUFFER = 24
local TOOLTIP_HEIGHT = 24
local TOOLTIP_OFFSET = -28

local ARROW_IMAGE_OPEN = 'rbxasset://textures/ui/TopBar/inventoryOn.png'
local ARROW_IMAGE_CLOSE = 'rbxasset://textures/ui/TopBar/inventoryOff.png'
local ARROW_HOTKEY = {Enum.KeyCode.Backquote, Enum.KeyCode.DPadUp}

local HOTBAR_SLOTS_WIDTH_CUTOFF = 1024
local HOTBAR_OFFSET_FROMBOTTOM = -30
local INVENTORY_HEADER_SIZE = 40
local INVENTORY_ARROWS_BUFFER_VR = 40

local SEARCH_BUFFER = 5
local SEARCH_WIDTH = 200
local SEARCH_TEXT = "Search"

local SEARCH_TEXT_OFFSET_FROMLEFT = 0
local SEARCH_BACKGROUND_COLOR = UIColors.BackgroundAlt
local SEARCH_TEXT_COLOR = UIColors.Text
local SEARCH_BACKGROUND_FADE = 0.1

local DOUBLE_CLICK_TIME = 0.5
local ZERO_KEY_VALUE = Enum.KeyCode.Zero.Value
local DROP_HOTKEY_VALUE = Enum.KeyCode.Backspace.Value

local GAMEPAD_INPUT_TYPES = {
	[Enum.UserInputType.Gamepad1] = true,
	[Enum.UserInputType.Gamepad2] = true,
	[Enum.UserInputType.Gamepad3] = true,
	[Enum.UserInputType.Gamepad4] = true,
	[Enum.UserInputType.Gamepad5] = true,
	[Enum.UserInputType.Gamepad6] = true,
	[Enum.UserInputType.Gamepad7] = true,
	[Enum.UserInputType.Gamepad8] = true,
}

local function GetScreenResolution(): Vector2
	local screenGui = Instance.new("ScreenGui", game.Players.LocalPlayer.PlayerGui)
	local frame = Instance.new("Frame", screenGui)
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 1, 0)
	local absoluteSize = frame.AbsoluteSize
	screenGui:Destroy()
	return absoluteSize
end

local Player = PlayersService.LocalPlayer
local CoreGui = Player.PlayerGui

local ICON_MODULE = script:WaitForChild("Icon")
local TopbarPlusReference = ReplicatedStorage:FindFirstChild("TopbarPlusReference")
if TopbarPlusReference then
	ICON_MODULE = TopbarPlusReference.Value
end

local RobloxGui = Instance.new("ScreenGui", CoreGui)
RobloxGui.DisplayOrder = 120
RobloxGui.IgnoreGuiInset = true
RobloxGui.ResetOnSpawn = false
RobloxGui.Name = "BackpackGui"

local Utility = require(script.Utility)
local GameTranslator = require(script.GameTranslator)

local Themes = nil
local Icon = nil

if ICON_MODULE and ICON_MODULE:FindFirstChild("Features") and ICON_MODULE.Features:FindFirstChild("Themes") then
	Themes = require(ICON_MODULE.Features.Themes)
else
	warn("BackpackController: Icon Themes module not found, using fallback")
	Themes = {}
end

if ICON_MODULE then
	Icon = require(ICON_MODULE)
else
	error("BackpackController: Icon module not found")
end


local BackpackEnabled = true
local FFlagBackpackScriptUseFormatByKey = true
local FFlagCoreScriptTranslateGameText2 = true
local FFlagRobloxGuiSiblingZindexs = true
local IsTenFootInterface = GuiService:IsTenFootInterface()
local GamepadActionsBound = false

if IsTenFootInterface then
	UIConstants.ICON_SIZE = 100
	UIConstants.FONT_SIZE = 24
end

local IS_PHONE = UserInputService.TouchEnabled and GetScreenResolution().X < HOTBAR_SLOTS_WIDTH_CUTOFF

local MainFrame: Frame? = nil
local HotbarFrame: Frame? = nil
local InventoryFrame: Frame? = nil
local VRInventorySelector: Frame? = nil
local ScrollingFrame: ScrollingFrame? = nil
local UIGridFrame: Frame? = nil
local UIGridLayout: UIGridLayout? = nil
local ScrollUpInventoryButton: GuiButton? = nil
local ScrollDownInventoryButton: GuiButton? = nil

local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:FindFirstChildOfClass("Humanoid")
local Backpack = Player:WaitForChild("Backpack")

local InventoryIcon = Icon.new()
InventoryIcon:setImage(ARROW_IMAGE_CLOSE, "deselected")
InventoryIcon:setImage(ARROW_IMAGE_OPEN, "selected")
InventoryIcon:bindToggleKey(ARROW_HOTKEY[1], ARROW_HOTKEY[2])
InventoryIcon:setName("InventoryIcon")
InventoryIcon:setImageScale(1.12)
InventoryIcon:setOrder(-5)
InventoryIcon:setCaption("Toggle the backpack.")
InventoryIcon.deselectWhenOtherIconSelected = false

if ICON_MODULE and ICON_MODULE.Features and ICON_MODULE.Features.Themes and ICON_MODULE.Features.Themes:FindFirstChild("RecipeUI") then
	local RecipeUITheme = require(ICON_MODULE.Features.Themes.RecipeUI)
end

local Slots = {}
local LowestEmptySlot = nil
local SlotsByTool = {}
local HotkeyFns = {}
local Dragging = {}
local FullHotbarSlots = 0
local StarterToolFound = false
local WholeThingEnabled = false
local TextBoxFocused = false
local ViewingSearchResults = false
local HotkeyStrings = {}
local CharConns = {}
local GamepadEnabled = false
local TimeOfLastToolChange = 0
local ForceHideHotbar = false

local function IsSpectating()
	return ForceHideHotbar
end

local IsVR = VRService.VREnabled
local NumberOfHotbarSlots = IsVR and UIConstants.HOTBAR_SLOTS_VR or (IS_PHONE and UIConstants.HOTBAR_SLOTS_MINI or UIConstants.HOTBAR_SLOTS_FULL)
local NumberOfInventoryRows = IsVR and UIConstants.INVENTORY_ROWS_VR or (IS_PHONE and UIConstants.INVENTORY_ROWS_MINI or UIConstants.INVENTORY_ROWS_FULL)

local BackpackPanel = nil
local lastEquippedSlot = nil
local SelectionState = {
	LastDpvNotify = 0,
	LastSelectedSlotIndex = nil,
	LastSelectedSlot = nil,
}

local function isDpvTool(tool)
	if not tool then
		return false
	end
	if tool:GetAttribute("DoubleDPV") == true then
		return true
	end
	return CollectionService:HasTag(tool, "DoubleDPV") or CollectionService:HasTag(tool, "SingleDPV")
end

local function isDpvBlocked(tool)
	return isDpvTool(tool) and Player:GetAttribute("Swimming") ~= true
end

local function canEquipTool(tool)
	return tool and not isDpvBlocked(tool)
end

local function updateSelectedSlot(slot)
	if SelectionState.LastSelectedSlot and SelectionState.LastSelectedSlot ~= slot then
		SelectionState.LastSelectedSlot:SetSelected(false)
	end
	if slot then
		slot:SetSelected(true)
		SelectionState.LastSelectedSlot = slot
		SelectionState.LastSelectedSlotIndex = slot.Index
	else
		SelectionState.LastSelectedSlot = nil
		SelectionState.LastSelectedSlotIndex = nil
	end
end

local function EvaluateBackpackPanelVisibility(enabled)
	return enabled and InventoryIcon.enabled and BackpackEnabled and VRService.VREnabled
end

local function ShowVRBackpackPopup()
	if BackpackPanel and EvaluateBackpackPanelVisibility(true) then
		BackpackPanel:ForceShowForSeconds(2)
	end
end

local function NewGui(className, objectName)
	local newGui = Instance.new(className)
	newGui.Name = objectName
	newGui.BackgroundColor3 = UIColors.Card
	newGui.BackgroundTransparency = 1
	newGui.BorderColor3 = UIColors.Black
	newGui.BorderSizePixel = 0
	newGui.Size = UDim2.new(1, 0, 1, 0)
	if className:match('Text') then
		newGui.TextColor3 = UIColors.Text
		newGui.Text = ''
		newGui.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
		newGui.TextSize = UIConstants.FONT_SIZE
		newGui.TextWrapped = true
		if className == 'TextButton' then
			newGui.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
		end
	end
	return newGui
end

local function FindLowestEmpty()
	for i = 1, NumberOfHotbarSlots do
		local slot = Slots[i]
		if not slot.Tool then
			return slot
		end
	end
	return nil
end

local function isInventoryEmpty()
	for i = NumberOfHotbarSlots + 1, #Slots do
		local slot = Slots[i]
		if slot and slot.Tool then
			return false
		end
	end
	return true
end

local function UseGazeSelection()
	return UserInputService.VREnabled
end

local function AdjustHotbarFrames()
	local inventoryOpen = InventoryFrame.Visible
	local visualTotal = inventoryOpen and NumberOfHotbarSlots or FullHotbarSlots
	local visualIndex = 0
	local hotbarHasContent = (visualTotal >= 1)
	local shouldDisplayHotbar = hotbarHasContent and not ForceHideHotbar

	HotbarFrame.Visible = shouldDisplayHotbar

	for i = 1, NumberOfHotbarSlots do
		local slot = Slots[i]
		local slotHasContent = slot.Tool or inventoryOpen
		if slotHasContent then
			visualIndex = visualIndex + 1
			slot:Readjust(visualIndex, visualTotal)
		end
		slot.Frame.Visible = shouldDisplayHotbar and slotHasContent
	end
end

local function UpdateScrollingFrameCanvasSize()
	local countX = math.floor(ScrollingFrame.AbsoluteSize.X/(UIConstants.ICON_SIZE + UIConstants.ICON_BUFFER))
	local maxRow = math.ceil((#UIGridFrame:GetChildren() - 1)/countX)
	local canvasSizeY = maxRow*(UIConstants.ICON_SIZE + UIConstants.ICON_BUFFER) + UIConstants.ICON_BUFFER
	ScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, canvasSizeY)
end

local function AdjustInventoryFrames()
	for i = NumberOfHotbarSlots + 1, #Slots do
		local slot = Slots[i]
		slot.Frame.LayoutOrder = slot.Index
		slot.Frame.Visible = (slot.Tool ~= nil)
	end
	UpdateScrollingFrameCanvasSize()
end

local function UpdateBackpackLayout()
	local hotbarWidth = UIConstants.ICON_BUFFER + (NumberOfHotbarSlots * (UIConstants.ICON_SIZE + UIConstants.ICON_BUFFER))
	local hotbarHeight = UIConstants.ICON_BUFFER + UIConstants.ICON_SIZE + UIConstants.ICON_BUFFER

	HotbarFrame.Size = UDim2.new(0, hotbarWidth, 0, hotbarHeight)
	HotbarFrame.Position = UDim2.new(0.5, -hotbarWidth / 2, 1, -hotbarHeight)
	HotbarFrame.AnchorPoint = Vector2.new(0, 0)

	local inventoryHeight = (hotbarHeight * NumberOfInventoryRows) + INVENTORY_HEADER_SIZE + (IsVR and 2*INVENTORY_ARROWS_BUFFER_VR or 0)
	InventoryFrame.Size = UDim2.new(0, hotbarWidth, 0, inventoryHeight)
	InventoryFrame.Position = UDim2.new(0.5, -hotbarWidth / 2, 1, -hotbarHeight - inventoryHeight)
	InventoryFrame.AnchorPoint = Vector2.new(0, 0)

	ScrollingFrame.Size = UDim2.new(1, ScrollingFrame.ScrollBarThickness + 1, 1, -INVENTORY_HEADER_SIZE - (IsVR and 2*INVENTORY_ARROWS_BUFFER_VR or 0))
	ScrollingFrame.Position = UDim2.new(0, 0, 0, INVENTORY_HEADER_SIZE + (IsVR and INVENTORY_ARROWS_BUFFER_VR or 0))
	AdjustHotbarFrames()
	AdjustInventoryFrames()
end

local function Clamp(low, high, num)
	return math.min(high, math.max(low, num))
end

local function CheckBounds(guiObject, x, y)
	local pos = guiObject.AbsolutePosition
	local size = guiObject.AbsoluteSize
	return (x > pos.X and x <= pos.X + size.X and y > pos.Y and y <= pos.Y + size.Y)
end

local function GetOffset(guiObject, point)
	local centerPoint = guiObject.AbsolutePosition + (guiObject.AbsoluteSize / 2)
	return (centerPoint - point).magnitude
end

local function UnequipAllTools()
	if Humanoid then
		Humanoid:UnequipTools()
	end
end

local function EquipNewTool(tool)
	if IsSpectating() then
		UnequipAllTools()
		return
	end
	UnequipAllTools()
	tool.Parent = Character
end

local function IsEquipped(tool)
	return tool and tool.Parent == Character
end

local function MakeSlot(parent, index)
	index = index or (#Slots + 1)

	local slot = {}
	slot.Tool = nil
	slot.Index = index
	slot.Frame = nil
	slot.IsSelected = false

	local LocalizedName = nil
	local LocalizedToolTip = nil

	local SlotFrameParent = nil
	local SlotFrame = nil
	local FakeSlotFrame = nil
	local ToolIcon = nil
	local ModelPreview = nil
	local ModelPreviewWorld = nil
	local ModelPreviewCamera = nil
	local previewModelClone: Instance? = nil
	local ToolName = nil
	local ToolChangeConn = nil
	local SelectionObj = nil
	local SlotStroke = nil
	local pulseTween = nil
	local pulseBackTween = nil
	local equipGlowFrame = nil
	local equipGlowTween = nil
	local unequipTween = nil
	local unequipRotateTween = nil
	local baseSlotSize = UDim2.new(0, UIConstants.ICON_SIZE, 0, UIConstants.ICON_SIZE)
	local baseSlotPosition = UDim2.new(0, 0, 0, UIConstants.ICON_BUFFER)
	slot.IsEquippedState = false

	local clearModelPreview = function() end
	local MAX_PREVIEW_DESCENDANTS = 600

	local function updateModelPreview(_: Tool?)
		return false
	end

	local ToolTip = nil
	local SlotNumber = nil

	local function playEquipEffect()
		if not SlotFrame or not SlotFrame.Parent then
			return
		end

		if equipGlowTween then
			equipGlowTween:Cancel()
			equipGlowTween = nil
		end

		if not equipGlowFrame then
			equipGlowFrame = NewGui('Frame', 'EquipGlow')
			equipGlowFrame.ZIndex = SlotFrame.ZIndex - 1
			equipGlowFrame.Size = UDim2.fromScale(1, 1)
			equipGlowFrame.Position = UDim2.fromScale(0, 0)
			equipGlowFrame.BackgroundColor3 = SLOT_EQUIPPED_BG_COLOR
			equipGlowFrame.BackgroundTransparency = 1
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 8)
			corner.Parent = equipGlowFrame
			equipGlowFrame.Parent = SlotFrame
		end

		equipGlowFrame.BackgroundTransparency = 0.2
		equipGlowFrame.Visible = true
		equipGlowTween = TweenService:Create(
			equipGlowFrame,
			TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{BackgroundTransparency = 1}
		)
		equipGlowTween:Play()
		equipGlowTween.Completed:Once(function()
			if equipGlowFrame then
				equipGlowFrame.Visible = false
			end
		end)
	end

	local function playUnequipEffect()
		if not SlotFrame or not SlotFrame.Parent then
			return
		end

		if unequipTween then
			unequipTween:Cancel()
			unequipTween = nil
		end
		if unequipRotateTween then
			unequipRotateTween:Cancel()
			unequipRotateTween = nil
		end
		if pulseTween then
			pulseTween:Cancel()
			pulseTween = nil
		end
		if pulseBackTween then
			pulseBackTween:Cancel()
			pulseBackTween = nil
		end

		SlotFrame.Size = baseSlotSize
		SlotFrame.Position = baseSlotPosition
		local size = baseSlotSize
		local position = baseSlotPosition
		local shrink = UDim2.fromOffset(-4, -4)
		local shrinkPos = UDim2.fromOffset(2, 2)

		unequipTween = TweenService:Create(
			SlotFrame,
			TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Size = size + shrink, Position = position + shrinkPos}
		)
		unequipRotateTween = TweenService:Create(
			SlotFrame,
			TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Rotation = -3}
		)
		unequipTween:Play()
		unequipRotateTween:Play()
		unequipTween.Completed:Once(function()
			if not SlotFrame or not SlotFrame.Parent then
				return
			end
			TweenService:Create(
				SlotFrame,
				TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{Size = size, Position = position, Rotation = 0}
			):Play()
		end)
	end

	local function playSelectionPulse()
		if not SlotFrame or not SlotFrame.Parent then
			return
		end

		if pulseTween then
			pulseTween:Cancel()
			pulseTween = nil
		end
		if pulseBackTween then
			pulseBackTween:Cancel()
			pulseBackTween = nil
		end
		if unequipTween then
			unequipTween:Cancel()
			unequipTween = nil
		end
		if unequipRotateTween then
			unequipRotateTween:Cancel()
			unequipRotateTween = nil
		end

		SlotFrame.Size = baseSlotSize
		SlotFrame.Position = baseSlotPosition
		local size = baseSlotSize
		local position = baseSlotPosition
		local bump = UDim2.fromOffset(SLOT_PULSE_SIZE, SLOT_PULSE_SIZE)
		local bumpPos = UDim2.fromOffset(-SLOT_PULSE_SIZE * 0.5, -SLOT_PULSE_SIZE * 0.5)

		pulseTween = TweenService:Create(
			SlotFrame,
			TweenInfo.new(SLOT_PULSE_IN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Size = size + bump, Position = position + bumpPos}
		)

		pulseTween:Play()
		pulseTween.Completed:Once(function()
			if not SlotFrame or not SlotFrame.Parent then
				return
			end
			pulseBackTween = TweenService:Create(
				SlotFrame,
				TweenInfo.new(SLOT_PULSE_OUT_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{Size = size, Position = position}
			)
			pulseBackTween:Play()
		end)
	end

	local function UpdateSlotFading()
		local previewTransparency = 1
		local isEquipped = IsEquipped(slot.Tool)
		local tint = SLOT_IDLE_TINT
		if isEquipped then
			tint = SLOT_EQUIPPED_TINT
		elseif slot.IsSelected then
			tint = SLOT_SELECTED_TINT
		end
		if VRService.VREnabled and BackpackPanel then
			local panelTransparency = BackpackPanel.transparency
			local slotTransparency = SLOT_FADE_LOCKED

			local finalTransparency = panelTransparency + slotTransparency - panelTransparency * slotTransparency

			SlotFrame.BackgroundTransparency = finalTransparency
			if slot.IsSelected and slot.Tool then
				SlotFrame.BackgroundTransparency = math.min(finalTransparency, SLOT_SELECTED_BG_TRANSPARENCY)
			end
			if isEquipped and slot.Tool then
				SlotFrame.BackgroundTransparency = math.min(SlotFrame.BackgroundTransparency, SLOT_EQUIPPED_BG_TRANSPARENCY)
			end
			SlotFrame.TextTransparency = finalTransparency
			if ToolIcon then
				ToolIcon.ImageTransparency = InventoryFrame.Visible and 0 or panelTransparency
			end
			if ModelPreview and ModelPreview.Visible then
				previewTransparency = 0
			end
			SlotFrame.SelectionImageObject = SelectionObj
		else
			SlotFrame.SelectionImageObject = nil
			if not slot.Tool then
				SlotFrame.BackgroundTransparency = 1
			else
				local inventoryOpenTransparency = InventoryFrame.Visible and 0.3 or SLOT_FADE_LOCKED
				SlotFrame.BackgroundTransparency = (SlotFrame.Draggable) and 0.1 or inventoryOpenTransparency
				if slot.IsSelected then
					SlotFrame.BackgroundTransparency = math.min(SlotFrame.BackgroundTransparency, SLOT_SELECTED_BG_TRANSPARENCY)
				end
				if isEquipped then
					SlotFrame.BackgroundTransparency = math.min(SlotFrame.BackgroundTransparency, SLOT_EQUIPPED_BG_TRANSPARENCY)
				end
			end
			if ModelPreview and ModelPreview.Visible then
				previewTransparency = 0
			end
		end
		if ModelPreview then
			ModelPreview.ImageTransparency = previewTransparency
		end
		local backgroundColor = SLOT_BACKGROUND_COLOR
		if slot.IsSelected then
			backgroundColor = SLOT_SELECTED_BG_COLOR
		end
		if isEquipped then
			backgroundColor = SLOT_EQUIPPED_BG_COLOR
		end
		SlotFrame.BackgroundColor3 = (SlotFrame.Draggable) and SLOT_DRAGGABLE_COLOR or backgroundColor
		if slot.Tool then
			if ToolIcon then
				ToolIcon.ImageColor3 = tint
			end
			if ToolName then
				ToolName.TextColor3 = tint
			end
			if SlotStroke then
				if isEquipped then
					SlotStroke.Thickness = SLOT_EQUIPPED_STROKE_THICKNESS
					SlotStroke.Color = SLOT_EQUIPPED_STROKE_COLOR
					SlotStroke.Transparency = 0
				else
					SlotStroke.Thickness = 0
				end
			end
		elseif SlotStroke then
			SlotStroke.Thickness = 0
		end
	end

	function slot:Readjust(visualIndex, visualTotal)
		local centered = HotbarFrame.Size.X.Offset / 2
		local sizePlus = UIConstants.ICON_BUFFER + UIConstants.ICON_SIZE
		local midpointish = (visualTotal / 2) + 0.5
		local factor = visualIndex - midpointish
		local xPosition = centered - (UIConstants.ICON_SIZE / 2) + (sizePlus * factor)
		baseSlotPosition = UDim2.new(0, xPosition, 0, UIConstants.ICON_BUFFER)
		SlotFrame.Position = baseSlotPosition
		SlotFrame.AnchorPoint = Vector2.new(0, 0)
	end

	function slot:Fill(tool)
		if not tool then
			return self:Clear()
		end

		self.Tool = tool

		local function assignToolData()
			local has3DModel = updateModelPreview(tool)

			if has3DModel then
				if ToolIcon then
					ToolIcon.Visible = false
				end
				if ModelPreview then
					ModelPreview.Visible = true
				end
				ToolName.Visible = true
				ToolName.Text = tool.Name
			else
				if ToolIcon then
					ToolIcon.Visible = true
					ToolIcon.ImageTransparency = 0
				end

				if FFlagCoreScriptTranslateGameText2 then
					local icon = tool.TextureId
					ToolIcon.Image = icon

					if icon ~= "" then
						ToolIcon.Visible = true
					else
						ToolIcon.Visible = false
					end

					ToolName.Visible = true
					ToolName.Text = tool.Name

					if ToolTip and tool:IsA('Tool') then
						ToolTip.Text = tool.ToolTip
						local width = ToolTip.TextBounds.X + TOOLTIP_BUFFER
						ToolTip.Size = UDim2.new(0, width, 0, TOOLTIP_HEIGHT)
						ToolTip.Position = UDim2.new(0.5, -width / 2, 0, TOOLTIP_OFFSET)
					end
				else
					LocalizedName = tool.Name
					LocalizedToolTip = nil

					local icon = tool.TextureId
					ToolIcon.Image = icon
					if icon ~= '' then
						ToolIcon.Visible = true
					else
						ToolIcon.Visible = false
					end
					ToolName.Visible = true
					ToolName.Text = LocalizedName
					if ToolTip and tool:IsA('Tool') then
						LocalizedToolTip = GameTranslator:TranslateGameText(tool, tool.ToolTip)
						ToolTip.Text = tool.ToolTip
						local width = ToolTip.TextBounds.X + TOOLTIP_BUFFER
						ToolTip.Size = UDim2.new(0, width, 0, TOOLTIP_HEIGHT)
						ToolTip.Position = UDim2.new(0.5, -width / 2, 0, TOOLTIP_OFFSET)
					end
				end
			end
		end

		assignToolData()

		if ToolChangeConn then
			ToolChangeConn:Disconnect()
			ToolChangeConn = nil
		end

		ToolChangeConn = tool.Changed:Connect(function(property)
			if property == 'TextureId' or property == 'Name' or property == 'ToolTip' then
				assignToolData()
			end
		end)

		local hotbarSlot = (self.Index <= NumberOfHotbarSlots)
		local inventoryOpen = InventoryFrame.Visible

		if (not hotbarSlot or inventoryOpen) and not UserInputService.VREnabled then
			SlotFrame.Draggable = true
			SlotFrame.BackgroundTransparency = 0.2
		end

		self:UpdateEquipView()

		if hotbarSlot then
			FullHotbarSlots = FullHotbarSlots + 1
			if WholeThingEnabled then
				if FullHotbarSlots >= 1 and not GamepadActionsBound then
					GamepadActionsBound = true
					ContextActionService:BindAction("RBXHotbarEquip", changeToolFunc, false, Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1)
				end
			end
		end

		SlotsByTool[tool] = self
		LowestEmptySlot = FindLowestEmpty()
	end

	function slot:Clear()
		if not self.Tool then return end

		if SelectionState.LastSelectedSlot == slot then
			updateSelectedSlot(nil)
		end

		if ToolChangeConn then
			ToolChangeConn:disconnect()
			ToolChangeConn = nil
		end

		clearModelPreview()

		ToolIcon.Image = ''
		ToolIcon.Visible = false
		ToolName.Text = ''
		if ToolTip then
			ToolTip.Text = ''
			ToolTip.Visible = false
		end
		SlotFrame.Draggable = false

		self:UpdateEquipView(true)

		if self.Index <= NumberOfHotbarSlots then
			FullHotbarSlots = FullHotbarSlots - 1
			if FullHotbarSlots < 1 then
				GamepadActionsBound = false
				ContextActionService:UnbindAction("RBXHotbarEquip")
			end
		end

		SlotsByTool[self.Tool] = nil
		self.Tool = nil
		LowestEmptySlot = FindLowestEmpty()
	end

	function slot:UpdateEquipView(unequippedOverride)
		local isEquipped = IsEquipped(self.Tool)
		if not unequippedOverride and isEquipped then
			lastEquippedSlot = slot
		end
		if slot.IsEquippedState ~= isEquipped then
			slot.IsEquippedState = isEquipped
			if isEquipped then
				playEquipEffect()
			else
				playUnequipEffect()
			end
		end
		UpdateSlotFading()
	end

	function slot:SetSelected(isSelected)
		slot.IsSelected = isSelected == true
		UpdateSlotFading()
		if slot.IsSelected then
			playSelectionPulse()
		end
	end

	function slot:IsEquipped()
		return IsEquipped(self.Tool)
	end

	function slot:Delete()
		clearModelPreview()
		if SelectionState.LastSelectedSlot == slot then
			updateSelectedSlot(nil)
		end
		SlotFrame:Destroy()
		table.remove(Slots, self.Index)
		local newSize = #Slots

		for i = self.Index, newSize do
			Slots[i]:SlideBack()
		end

		UpdateScrollingFrameCanvasSize()
	end

	function slot:Swap(targetSlot)
		local myTool, otherTool = self.Tool, targetSlot.Tool
		self:Clear()
		if otherTool then
			targetSlot:Clear()
			self:Fill(otherTool)
		end
		if myTool then
			targetSlot:Fill(myTool)
		else
			targetSlot:Clear()
		end
	end

	function slot:SlideBack()
		self.Index = self.Index - 1
		SlotFrame.Name = self.Index
		SlotFrame.LayoutOrder = self.Index
	end

	function slot:TurnNumber(on)
		if SlotNumber then
			SlotNumber.Visible = on
		end
	end

	function slot:SetClickability(on)
		if self.Tool then
			if UserInputService.VREnabled then
				SlotFrame.Draggable = false
			else
				SlotFrame.Draggable = not on
			end
			UpdateSlotFading()
		end
	end

	function slot:CheckTerms(terms)
		local hits = 0
		local function checkEm(str, term)
			local _, n = str:lower():gsub(term, '')
			hits = hits + n
		end
		local tool = self.Tool
		if tool then
			for term in pairs(terms) do
				if FFlagCoreScriptTranslateGameText2 then
					checkEm(ToolName.Text, term)
					if tool:IsA('Tool') then
						local toolTipText = ToolTip and ToolTip.Text or ""
						checkEm(toolTipText, term)
					end
				else
					checkEm(LocalizedName, term)
					if tool:IsA('Tool') then
						checkEm(LocalizedToolTip, term)
					end
				end
			end
		end
		return hits
	end

	function slot:Select()
		local tool = slot.Tool
		if tool then
			updateSelectedSlot(slot)
			if IsEquipped(tool) then
				UnequipAllTools()
			elseif tool.Parent == Backpack and not IsSpectating() then
				if not canEquipTool(tool) then
					UnequipAllTools()
					lastEquippedSlot = nil
					local now = os.clock()
					if now - (SelectionState.LastDpvNotify or 0) >= DPV_NOTIFY_COOLDOWN then
						SelectionState.LastDpvNotify = now
						UI.Notify(DPV_BLOCKED_MESSAGE, "Info", 2)
					end
					return
				end
				UnequipAllTools()
				EquipNewTool(tool)
			end
		end
	end

	SlotFrame = NewGui('TextButton', index)
	local newStroke = Instance.new("UIStroke")
	newStroke.Parent = SlotFrame
	SlotStroke = newStroke
	newStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	newStroke.Transparency = 0
	local newRadius = Instance.new("UICorner")
	newRadius.CornerRadius = UDim.new(0, 8)
	newRadius.Parent = SlotFrame
	newStroke.Thickness = 0
	SlotFrame.BackgroundColor3 = UIConstants.BACKGROUND_COLOR
	newStroke.Color = SLOT_BORDER_COLOR

	SlotFrame.Text = ""
	SlotFrame.AutoButtonColor = false
	SlotFrame.BorderSizePixel = 0
	SlotFrame.Size = baseSlotSize
	SlotFrame.Position = baseSlotPosition
	SlotFrame.AnchorPoint = Vector2.new(0, 0)
	SlotFrame.Active = true
	SlotFrame.Draggable = false
	SlotFrame.BackgroundTransparency = 0.3
	SlotFrame.MouseButton1Click:connect(function() changeSlot(slot) end)
	slot.Frame = SlotFrame

	do
		local selectionObjectClipper = NewGui('Frame', 'SelectionObjectClipper')
		selectionObjectClipper.Visible = false
		selectionObjectClipper.Parent = SlotFrame

		SelectionObj = NewGui('ImageLabel', 'Selector')
		SelectionObj.Size = UDim2.new(1, 0, 1, 0)
		SelectionObj.Image = "rbxasset://textures/ui/Keyboard/key_selection_9slice.png"
		SelectionObj.ScaleType = Enum.ScaleType.Slice
		SelectionObj.SliceCenter = Rect.new(12,12,52,52)
		SelectionObj.Parent = selectionObjectClipper
	end

	ModelPreview = Instance.new("ViewportFrame")
	ModelPreview.Name = "ModelPreview"
	ModelPreview.BackgroundTransparency = 1
	ModelPreview.Size = UDim2.new(1, 0, 1, 0)
	ModelPreview.Visible = false
	ModelPreview.ZIndex = 2
	ModelPreview.Ambient = UIColors.TextDark
	ModelPreview.LightColor = UIColors.TextLight
	ModelPreview.LightDirection = Vector3.new(-1, -1, -1)
	ModelPreview.Parent = SlotFrame

	ModelPreviewWorld = Instance.new("WorldModel")
	ModelPreviewWorld.Name = "PreviewWorld"
	ModelPreviewWorld.Parent = ModelPreview

	ModelPreviewCamera = Instance.new("Camera")
	ModelPreviewCamera.Name = "PreviewCamera"
	ModelPreviewCamera.Parent = ModelPreview
	ModelPreview.CurrentCamera = ModelPreviewCamera

	clearModelPreview = function()
		if previewModelClone then
			previewModelClone:Destroy()
			previewModelClone = nil
		end
		if ModelPreviewWorld then
			ModelPreviewWorld:ClearAllChildren()
		end
		if ModelPreview then
			ModelPreview.Visible = false
			ModelPreview.ImageTransparency = 1
		end
	end

	local function sanitizePreviewModel(model, descendants)
		descendants = descendants or model:GetDescendants()
		for _, descendant in ipairs(descendants) do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = false
			elseif descendant:IsA("ParticleEmitter") or descendant:IsA("Trail") then
				descendant.Enabled = false
			elseif descendant:IsA("Script") or descendant:IsA("LocalScript") then
				descendant:Destroy()
			end
		end
	end

	updateModelPreview = function(tool: Tool?)
		clearModelPreview()
		if not tool or not ModelPreview or not ModelPreviewWorld or not ModelPreviewCamera then
			return false
		end
		if not (tool:IsA("Tool") or tool:IsA("Model")) then
			return false
		end
		if tool:IsA("Model") then
			local sourceDescendants = tool:GetDescendants()
			if #sourceDescendants > MAX_PREVIEW_DESCENDANTS then
				return false
			end
		end
		local hasGeometry = tool:FindFirstChildWhichIsA("BasePart", true)
		if not hasGeometry then
			return false
		end

		local modelClone
		if tool:IsA("Model") then
			modelClone = tool:Clone()
			modelClone.Name = tool.Name .. "_Preview"
		else
			modelClone = Instance.new("Model")
			modelClone.Name = tool.Name .. "_Preview"

			for _, child in ipairs(tool:GetChildren()) do
				if not child:IsA("Script") and not child:IsA("LocalScript") then
					local cloned = child:Clone()
					cloned.Parent = modelClone
				end
			end
		end

		if #modelClone:GetChildren() == 0 then
			modelClone:Destroy()
			return false
		end

		local descendants = modelClone:GetDescendants()
		if #descendants > MAX_PREVIEW_DESCENDANTS then
			modelClone:Destroy()
			return false
		end

		sanitizePreviewModel(modelClone, descendants)

		local primary = modelClone.PrimaryPart or modelClone:FindFirstChildWhichIsA("BasePart", true)
		if primary then
			modelClone.PrimaryPart = primary
			modelClone:PivotTo(CFrame.new())
		end

		modelClone.Parent = ModelPreviewWorld
		previewModelClone = modelClone

		local cf, size = modelClone:GetBoundingBox()
		local largest = math.max(size.X, size.Y, size.Z)
		if largest <= 0 then
			largest = 1
		end
		local cameraDistance = largest * 1.6
		ModelPreviewCamera.CFrame = CFrame.new(cf.Position + Vector3.new(cameraDistance, cameraDistance * 0.5, cameraDistance), cf.Position)
		ModelPreviewCamera.Focus = CFrame.new(cf.Position)
		ModelPreviewCamera.FieldOfView = 40

		ModelPreview.Visible = true
		return true
	end

	ToolIcon = NewGui('ImageLabel', 'Icon')
	ToolIcon.Size = UDim2.new(0.8, 0, 0.8, 0)
	ToolIcon.Position = UDim2.new(0.1, 0, 0.1, 0)
	ToolIcon.Parent = SlotFrame

	ToolName = NewGui('TextLabel', 'ToolName')
	ToolName.Size = UDim2.new(1, -4, 0, 16)
	ToolName.Position = UDim2.new(0, 2, 1, -18)
	ToolName.AnchorPoint = Vector2.new(0, 0)
	ToolName.TextColor3 = UIColors.Text
	ToolName.TextXAlignment = Enum.TextXAlignment.Center
	ToolName.TextYAlignment = Enum.TextYAlignment.Center
	ToolName.BackgroundTransparency = 1
	ToolName.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
	ToolName.TextSize = 10
	ToolName.Parent = SlotFrame
	UIFactory.applyStroke(ToolName, UIColors.Black, 1)

	slot.Frame.LayoutOrder = slot.Index

	if index <= NumberOfHotbarSlots then
		ToolTip = NewGui('TextLabel', 'ToolTip')
		ToolTip.ZIndex = 2
		ToolTip.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
		ToolTip.TextWrapped = false
		ToolTip.TextYAlignment = Enum.TextYAlignment.Center
		ToolTip.BackgroundColor3 = UIColors.Header
		ToolTip.BackgroundTransparency = 0
		ToolTip.TextColor3 = UIColors.TextLight
		ToolTip.Visible = false
		ToolTip.Parent = SlotFrame
		UIFactory.applyCorner(ToolTip, UDim.new(0, 8))
		UIFactory.applyStroke(ToolTip, {
			Color = UIColors.Stroke,
			Transparency = 0.4,
			Thickness = 1,
		})
		SlotFrame.MouseEnter:connect(function()
			if ToolTip.Text ~= '' then
				ToolTip.Visible = true
			end
		end)
		SlotFrame.MouseLeave:connect(function() ToolTip.Visible = false end)

		function slot:MoveToInventory()
			if slot.Index <= NumberOfHotbarSlots then
				local tool = slot.Tool
				self:Clear()
				local newSlot = MakeSlot(UIGridFrame)
				newSlot:Fill(tool)
				if IsEquipped(tool) then
					UnequipAllTools()
				end
				if ViewingSearchResults then
					newSlot.Frame.Visible = false
					newSlot.Parent = InventoryFrame
				end
			end
		end

		if index < 10 or index == NumberOfHotbarSlots then
			local slotNum = (index < 10) and index or 0
			SlotNumber = NewGui('TextLabel', 'Number')
			SlotNumber.Text = slotNum
			SlotNumber.Size = UDim2.new(0, 15, 0, 15)
			SlotNumber.TextColor3 = UIColors.TextSecondary
			SlotNumber.Visible = false
			SlotNumber.Parent = SlotFrame
			HotkeyFns[ZERO_KEY_VALUE + slotNum] = slot.Select
		end
	end

	do
		local startPoint = SlotFrame.Position
		local lastUpTime = 0
		local startParent = nil

		SlotFrame.DragBegin:connect(function(dragPoint)
			Dragging[SlotFrame] = true
			startPoint = dragPoint

			newStroke.Thickness = 2
			InventoryIcon:lock()

			SlotFrame.ZIndex = 2
			ToolIcon.ZIndex = 2
			if ModelPreview then
				ModelPreview.ZIndex = 2
			end
			ToolName.ZIndex = 2
			if FFlagRobloxGuiSiblingZindexs then
				SlotFrame.Parent.ZIndex = 2
			end
			if SlotNumber then
				SlotNumber.ZIndex = 2
			end
			if HighlightFrame then
				HighlightFrame.ZIndex = 2
				for _, child in pairs(HighlightFrame:GetChildren()) do
					if not child:IsA("UICorner") and not child:IsA("UIStroke") then
						child.ZIndex = 2
					end
				end
			end

			startParent = SlotFrame.Parent
			if startParent == UIGridFrame then
				local newPosition = UDim2.new(0, SlotFrame.AbsolutePosition.X - InventoryFrame.AbsolutePosition.X, 0, SlotFrame.AbsolutePosition.Y - InventoryFrame.AbsolutePosition.Y)
				SlotFrame.Parent = InventoryFrame
				SlotFrame.Position = newPosition

				FakeSlotFrame = NewGui('Frame', 'FakeSlot')
				FakeSlotFrame.LayoutOrder = SlotFrame.LayoutOrder
				FakeSlotFrame.Size = SlotFrame.Size
				FakeSlotFrame.BackgroundTransparency = 1
				FakeSlotFrame.Parent = UIGridFrame
			end
		end)

		SlotFrame.DragStopped:connect(function(x, y)
			if FakeSlotFrame then
				FakeSlotFrame:Destroy()
			end

			local now = tick()
			SlotFrame.Position = startPoint
			SlotFrame.Parent = startParent

			newStroke.Thickness = 0
			InventoryIcon:unlock()

			SlotFrame.ZIndex = 1
			ToolIcon.ZIndex = 1
			if ModelPreview then
				ModelPreview.ZIndex = 1
			end
			ToolName.ZIndex = 1
			if FFlagRobloxGuiSiblingZindexs then
				startParent.ZIndex = 1
			end
			if SlotNumber then
				SlotNumber.ZIndex = 1
			end
			if HighlightFrame then
				HighlightFrame.ZIndex = 1
				for _, child in pairs(HighlightFrame:GetChildren()) do
					if not child:IsA("UICorner") and not child:IsA("UIStroke") then
						child.ZIndex = 1
					end
				end
			end

			Dragging[SlotFrame] = nil

			if not slot.Tool then
				return
			end

			if CheckBounds(InventoryFrame, x, y) then
				if slot.Index <= NumberOfHotbarSlots then
					slot:MoveToInventory()
				end
				if slot.Index > NumberOfHotbarSlots and now - lastUpTime < DOUBLE_CLICK_TIME then
					if LowestEmptySlot then
						local myTool = slot.Tool
						slot:Clear()
						LowestEmptySlot:Fill(myTool)
						slot:Delete()
					end
					now = 0
				end
			elseif CheckBounds(HotbarFrame, x, y) then
				local closest = {math.huge, nil}
				for i = 1, NumberOfHotbarSlots do
					local otherSlot = Slots[i]
					local offset = GetOffset(otherSlot.Frame, Vector2.new(x, y))
					if offset < closest[1] then
						closest = {offset, otherSlot}
					end
				end
				local closestSlot = closest[2]
				if closestSlot ~= slot then
					slot:Swap(closestSlot)
					if slot.Index > NumberOfHotbarSlots then
						local tool = slot.Tool
						if not tool then
							slot:Delete()
						else
							if IsEquipped(tool) then
								UnequipAllTools()
							end
							if ViewingSearchResults then
								slot.Frame.Visible = false
								slot.Frame.Parent = InventoryFrame
							end
						end
					end
				end
			else
				if slot.Index <= NumberOfHotbarSlots then
					slot:MoveToInventory()
				end
			end

			lastUpTime = now
		end)
	end

	SlotFrame.Parent = parent
	Slots[index] = slot
	slot.ToolIcon = ToolIcon
	slot.ModelPreview = ModelPreview
	slot.ToolName = ToolName
	slot.ToolTip = ToolTip

	if index > NumberOfHotbarSlots then
		UpdateScrollingFrameCanvasSize()
		if InventoryFrame.Visible and not ViewingSearchResults then
			local offset = ScrollingFrame.CanvasSize.Y.Offset - ScrollingFrame.AbsoluteSize.Y
			ScrollingFrame.CanvasPosition = Vector2.new(0, math.max(0, offset))
		end
	end

	return slot
end

local function OnChildAdded(child)
	if not child:IsA('Tool') then
		if child:IsA('Humanoid') and child.Parent == Character then
			Humanoid = child
		end
		return
	end
	local tool = child

	if tool.Parent == Character then
		ShowVRBackpackPopup()
		TimeOfLastToolChange = tick()
	end

	if not StarterToolFound and tool.Parent == Character and not SlotsByTool[tool] then
		local starterGear = Player:FindFirstChild('StarterGear')
		if starterGear then
			if starterGear:FindFirstChild(tool.Name) then
				StarterToolFound = true
				local slot = LowestEmptySlot or MakeSlot(UIGridFrame)
				for i = slot.Index, 1, -1 do
					local curr = Slots[i]
					local pIndex = i - 1
					if pIndex > 0 then
						local prev = Slots[pIndex]
						prev:Swap(curr)
					else
						curr:Fill(tool)
					end
				end
				for _, child in pairs(Character:GetChildren()) do
					if child:IsA('Tool') and child ~= tool then
						child.Parent = Backpack
					end
				end
				AdjustHotbarFrames()
				return
			end
		end
	end

	local slot = SlotsByTool[tool]
	if slot then
		slot:UpdateEquipView()
	else
		slot = LowestEmptySlot or MakeSlot(UIGridFrame)
		slot:Fill(tool)
		if slot.Index <= NumberOfHotbarSlots and not InventoryFrame.Visible then
			AdjustHotbarFrames()
		end
	end
end

local function OnChildRemoved(child)
	if not child:IsA('Tool') then
		return
	end
	local tool = child

	ShowVRBackpackPopup()
	TimeOfLastToolChange = tick()

	local newParent = tool.Parent
	if newParent == Character or newParent == Backpack then
		return
	end

	local slot = SlotsByTool[tool]
	if slot then
		slot:Clear()
		if slot.Index > NumberOfHotbarSlots then
			slot:Delete()
		elseif not InventoryFrame.Visible then
			AdjustHotbarFrames()
		end
	end
end

local function OnCharacterAdded(character)
	for i = #Slots, 1, -1 do
		local slot = Slots[i]
		if slot.Tool then
			slot:Clear()
		end
		if i > NumberOfHotbarSlots then
			slot:Delete()
		end
	end

	for _, conn in pairs(CharConns) do
		conn:Disconnect()
	end

	CharConns = {}

	Character = character
	table.insert(CharConns, character.ChildRemoved:Connect(OnChildRemoved))
	table.insert(CharConns, character.ChildAdded:Connect(OnChildAdded))
	for _, child in pairs(character:GetChildren()) do
		OnChildAdded(child)
	end

	Backpack = Player:WaitForChild('Backpack')
	table.insert(CharConns, Backpack.ChildRemoved:Connect(OnChildRemoved))
	table.insert(CharConns, Backpack.ChildAdded:Connect(OnChildAdded))
	for _, child in pairs(Backpack:GetChildren()) do
		OnChildAdded(child)
	end

	AdjustHotbarFrames()
end

local function OnInputBegan(input, isProcessed)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		if isProcessed or TextBoxFocused then
			return
		end
		if input.KeyCode == Enum.KeyCode.Tab then
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, not StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.PlayerList))
			return
		end

		if WholeThingEnabled or input.KeyCode.Value == DROP_HOTKEY_VALUE then
			local hotkeyBehavior = HotkeyFns[input.KeyCode.Value]
			if hotkeyBehavior then
				hotkeyBehavior(isProcessed)
			end
		end
	end

	local inputType = input.UserInputType
	if not isProcessed then
		if inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.Touch then
			if InventoryFrame.Visible then
				InventoryIcon:deselect()
			end
		end
	end
end

local function OnUISChanged(property)
	if property == 'KeyboardEnabled' or property == "VREnabled" then
		local on = UserInputService.KeyboardEnabled and not UserInputService.VREnabled
		for i = 1, NumberOfHotbarSlots do
			Slots[i]:TurnNumber(on)
		end
	end
end

local lastChangeToolInputObject = nil
local lastChangeToolInputTime = nil
local maxEquipDeltaTime = 0.06
local noOpFunc = function() end
local selectDirection = Vector2.new(0,0)
local hotbarVisible = false

function unbindAllGamepadEquipActions()
	ContextActionService:UnbindAction("RBXBackpackHasGamepadFocus")
	ContextActionService:UnbindAction("RBXCloseInventory")
end

local function setHotbarVisibility(visible, isInventoryScreen)
	for i = 1, NumberOfHotbarSlots do
		local hotbarSlot = Slots[i]
		if hotbarSlot and hotbarSlot.Frame and (isInventoryScreen or hotbarSlot.Tool) then
			hotbarSlot.Frame.Visible = visible
		end
	end
end

local function getInputDirection(inputObject)
	local buttonModifier = 1
	if inputObject.UserInputState == Enum.UserInputState.End then
		buttonModifier = -1
	end

	if inputObject.KeyCode == Enum.KeyCode.Thumbstick1 then

		local magnitude = inputObject.Position.magnitude

		if magnitude > 0.98 then
			local normalizedVector = Vector2.new(inputObject.Position.x / magnitude, -inputObject.Position.y / magnitude)
			selectDirection =  normalizedVector
		else
			selectDirection = Vector2.new(0,0)
		end
	elseif inputObject.KeyCode == Enum.KeyCode.DPadLeft then
		selectDirection = Vector2.new(selectDirection.x - 1 * buttonModifier, selectDirection.y)
	elseif inputObject.KeyCode == Enum.KeyCode.DPadRight then
		selectDirection = Vector2.new(selectDirection.x + 1 * buttonModifier, selectDirection.y)
	elseif inputObject.KeyCode == Enum.KeyCode.DPadUp then
		selectDirection = Vector2.new(selectDirection.x, selectDirection.y - 1 * buttonModifier)
	elseif inputObject.KeyCode == Enum.KeyCode.DPadDown then
		selectDirection = Vector2.new(selectDirection.x, selectDirection.y + 1 * buttonModifier)
	else
		selectDirection = Vector2.new(0,0)
	end

	return selectDirection
end

local selectToolExperiment = function(actionName, inputState, inputObject)
	local inputDirection = getInputDirection(inputObject)

	if inputDirection == Vector2.new(0,0) then
		return
	end

	local angle = math.atan2(inputDirection.y, inputDirection.x) - math.atan2(-1, 0)
	if angle < 0 then
		angle = angle + (math.pi * 2)
	end

	local quarterPi = (math.pi * 0.25)

	local index = (angle/quarterPi) + 1
	index = math.floor(index + 0.5) -- round index to whole number
	if index > NumberOfHotbarSlots then
		index = 1
	end

	if index > 0 then
		local selectedSlot = Slots[index]
		if selectedSlot and selectedSlot.Tool and not selectedSlot:IsEquipped() then
			selectedSlot:Select()
		end
	else
		UnequipAllTools()
	end
end

changeToolFunc = function(actionName, inputState, inputObject)
	if inputState ~= Enum.UserInputState.Begin then return end

	if lastChangeToolInputObject then
		if (lastChangeToolInputObject.KeyCode == Enum.KeyCode.ButtonR1 and
			inputObject.KeyCode == Enum.KeyCode.ButtonL1) or
			(lastChangeToolInputObject.KeyCode == Enum.KeyCode.ButtonL1 and
				inputObject.KeyCode == Enum.KeyCode.ButtonR1) then
			if (tick() - lastChangeToolInputTime) <= maxEquipDeltaTime then
				UnequipAllTools()
				lastChangeToolInputObject = inputObject
				lastChangeToolInputTime = tick()
				return
			end
		end
	end

	lastChangeToolInputObject = inputObject
	lastChangeToolInputTime = tick()

	delay(maxEquipDeltaTime, function()
		if lastChangeToolInputObject ~= inputObject then return end

		local moveDirection = 0
		if (inputObject.KeyCode == Enum.KeyCode.ButtonL1) then
			moveDirection = -1
		else
			moveDirection = 1
		end

		local currentIndex = nil
		for i = 1, NumberOfHotbarSlots do
			local hotbarSlot = Slots[i]
			if hotbarSlot:IsEquipped() then
				currentIndex = i
				break
			end
		end

		if SelectionState.LastSelectedSlotIndex and (not currentIndex or (SelectionState.LastSelectedSlot and not SelectionState.LastSelectedSlot:IsEquipped())) then
			currentIndex = math.clamp(SelectionState.LastSelectedSlotIndex, 1, NumberOfHotbarSlots)
		end

		if currentIndex then
			local newSlotPosition = currentIndex + moveDirection
			local hitEdge = false
			if newSlotPosition > NumberOfHotbarSlots then
				newSlotPosition = 1
				hitEdge = true
			elseif newSlotPosition < 1 then
				newSlotPosition = NumberOfHotbarSlots
				hitEdge = true
			end

			local attempts = 0
			while attempts < NumberOfHotbarSlots do
				local candidate = Slots[newSlotPosition]
				if candidate and candidate.Tool then
					candidate:Select()
					if hitEdge and candidate:IsEquipped() then
						UnequipAllTools()
						lastEquippedSlot = nil
					end
					return
				end
				newSlotPosition = newSlotPosition + moveDirection
				attempts += 1
				if newSlotPosition > NumberOfHotbarSlots then
					newSlotPosition = 1
					hitEdge = true
				elseif newSlotPosition < 1 then
					newSlotPosition = NumberOfHotbarSlots
					hitEdge = true
				end
			end
			return
		end

		local startIndex = moveDirection == -1 and NumberOfHotbarSlots or 1
		local endIndex = moveDirection == -1 and 1 or NumberOfHotbarSlots
		for i = startIndex, endIndex, moveDirection do
			local candidate = Slots[i]
			if candidate and candidate.Tool then
				candidate:Select()
				return
			end
		end
	end)
end

function getGamepadSwapSlot()
	for i = 1, #Slots do
		if Slots[i].Frame:WaitForChild("UIStroke").Thickness > 0 then
			return Slots[i]
		end
	end
end

function changeSlot(slot)
	local swapInVr = not VRService.VREnabled or InventoryFrame.Visible

	if slot.Frame == GuiService.SelectedObject and swapInVr then
		local currentlySelectedSlot = getGamepadSwapSlot()

		if currentlySelectedSlot then
			currentlySelectedSlot.Frame:WaitForChild("UIStroke").Thickness = 0
			if currentlySelectedSlot ~= slot then
				slot:Swap(currentlySelectedSlot)
				VRInventorySelector.SelectionImageObject.Visible = false

				if slot.Index > NumberOfHotbarSlots and not slot.Tool then
					if GuiService.SelectedObject == slot.Frame then
						GuiService.SelectedObject = currentlySelectedSlot.Frame
					end
					slot:Delete()
				end

				if currentlySelectedSlot.Index > NumberOfHotbarSlots and not currentlySelectedSlot.Tool then
					if GuiService.SelectedObject == currentlySelectedSlot.Frame then
						GuiService.SelectedObject = slot.Frame
					end
					currentlySelectedSlot:Delete()
				end
			end
		else
			local startSize = baseSlotSize
			local startPosition = baseSlotPosition
			slot.Frame.Size = startSize
			slot.Frame.Position = startPosition
			slot.Frame:TweenSizeAndPosition(startSize + UDim2.new(0, 10, 0, 10), startPosition - UDim2.new(0, 5, 0, 5), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, .1, true, function() slot.Frame:TweenSizeAndPosition(startSize, startPosition, Enum.EasingDirection.In, Enum.EasingStyle.Quad, .1, true) end)
			slot.Frame:WaitForChild("UIStroke").Thickness = 3
			VRInventorySelector.SelectionImageObject.Visible = true
		end
	else
		slot:Select()
		VRInventorySelector.SelectionImageObject.Visible = false
	end
end

function vrMoveSlotToInventory()
	if not VRService.VREnabled then
		return
	end

	local currentlySelectedSlot = getGamepadSwapSlot()
	if currentlySelectedSlot and currentlySelectedSlot.Tool then
		currentlySelectedSlot:WaitForChild("UIStroke").Thickness = 0
		currentlySelectedSlot:MoveToInventory()
		VRInventorySelector.SelectionImageObject.Visible = false
	end
end

function enableGamepadInventoryControl()
	local goBackOneLevel = function(_actionName, inputState, _inputObject)
		if inputState ~= Enum.UserInputState.Begin then return end

		local selectedSlot = getGamepadSwapSlot()
		if selectedSlot then
			local selectedSlot = getGamepadSwapSlot()
			if selectedSlot then
				selectedSlot:WaitForChild("UIStroke").Thickness = 0
				return
			end
		elseif InventoryFrame.Visible then
			InventoryIcon:deselect()
		end
	end

	ContextActionService:BindAction("RBXBackpackHasGamepadFocus", noOpFunc, false, Enum.UserInputType.Gamepad1)
	ContextActionService:BindAction("RBXCloseInventory", goBackOneLevel, false, Enum.KeyCode.ButtonB, Enum.KeyCode.ButtonStart)

	-- Gaze select will automatically select the object for us!
	if not UseGazeSelection() then
		GuiService.SelectedObject = HotbarFrame:FindFirstChild("1")
	end
end


function disableGamepadInventoryControl()
	unbindAllGamepadEquipActions()

	for i = 1, NumberOfHotbarSlots do
		local hotbarSlot = Slots[i]
		if hotbarSlot and hotbarSlot.Frame then
			hotbarSlot.Frame:WaitForChild("UIStroke").Thickness = 0
		end
	end

	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(MainFrame) then
		GuiService.SelectedObject = nil
	end
end


local function bindBackpackHotbarAction()
	if WholeThingEnabled and not GamepadActionsBound then
		GamepadActionsBound = true
		ContextActionService:BindAction("RBXHotbarEquip", changeToolFunc, false, Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1)
	end
end

local function unbindBackpackHotbarAction()
	disableGamepadInventoryControl()
	GamepadActionsBound = false
	ContextActionService:UnbindAction("RBXHotbarEquip")
end

function gamepadDisconnected()
	GamepadEnabled = false
	disableGamepadInventoryControl()
end

function gamepadConnected()
	GamepadEnabled = true

	if FullHotbarSlots >= 1 then
		bindBackpackHotbarAction()
	end

	if InventoryFrame.Visible then
		enableGamepadInventoryControl()
	end
end

local function OnIconChanged(enabled)
	-- Check for enabling/disabling the whole thing
	enabled = enabled and StarterGui:GetCore("TopbarEnabled")
	InventoryIcon:setEnabled(enabled and not GuiService.MenuIsOpen)
	WholeThingEnabled = enabled
	MainFrame.Visible = enabled

	for _ in pairs(HotkeyStrings) do
		if enabled then
		else
		end
	end

	if enabled then
		if FullHotbarSlots >=1 then
			bindBackpackHotbarAction()
		end
	else
		unbindBackpackHotbarAction()
	end
end


local function MakeVRRoundButton(name, image)
	local newButton = NewGui('ImageButton', name)
	newButton.Size = UDim2.new(0, 40, 0, 40)
	newButton.Image = "rbxasset://textures/ui/Keyboard/close_button_background.png";

	local buttonIcon = NewGui('ImageLabel', 'Icon')
	buttonIcon.Size = UDim2.new(0.5,0,0.5,0);
	buttonIcon.Position = UDim2.new(0.25,0,0.25,0);
	buttonIcon.Image = image;
	buttonIcon.Parent = newButton;

	local buttonSelectionObject = NewGui('ImageLabel', 'Selection')
	buttonSelectionObject.Size = UDim2.new(0.9,0,0.9,0);
	buttonSelectionObject.Position = UDim2.new(0.05,0,0.05,0);
	buttonSelectionObject.Image = "rbxasset://textures/ui/Keyboard/close_button_selection.png";
	newButton.SelectionImageObject = buttonSelectionObject

	return newButton, buttonIcon, buttonSelectionObject
end

MainFrame = NewGui('Frame', 'Backpack')
MainFrame.Visible = false
MainFrame.Parent = RobloxGui

HotbarFrame = NewGui('Frame', 'Hotbar')
HotbarFrame.BackgroundColor3 = UIColors.BackgroundAlt
HotbarFrame.BackgroundTransparency = 1
HotbarFrame.BorderSizePixel = 0
UIFactory.applyCorner(HotbarFrame, UDim.new(0, 8))
HotbarFrame.Parent = MainFrame

for i = 1, NumberOfHotbarSlots do
	local slot = MakeSlot(HotbarFrame, i)
	slot.Frame.Visible = false

	if not LowestEmptySlot then
		LowestEmptySlot = slot
	end
end

InventoryIcon.selected:Connect(function()
	if not GuiService.MenuIsOpen then
		BackpackScript.OpenClose()
	end
end)
InventoryIcon.deselected:Connect(function()
	if InventoryFrame.Visible then
		BackpackScript.OpenClose()
	end
end)

LeftBumperButton = NewGui('ImageLabel', 'LeftBumper')
LeftBumperButton.Size = UDim2.new(0, 40, 0, 40)
LeftBumperButton.Position = UDim2.new(0, -LeftBumperButton.Size.X.Offset, 0.5, -LeftBumperButton.Size.Y.Offset/2)

RightBumperButton = NewGui('ImageLabel', 'RightBumper')
RightBumperButton.Size = UDim2.new(0, 40, 0, 40)
RightBumperButton.Position = UDim2.new(1, 0, 0.5, -RightBumperButton.Size.Y.Offset/2)

InventoryFrame = NewGui('Frame', 'Inventory')
UIFactory.applyCorner(InventoryFrame, UDim.new(0, 12))
UIFactory.applyStroke(InventoryFrame, {
	Color = UIColors.Stroke,
	Transparency = 0.5,
	Thickness = 1,
})
InventoryFrame.BackgroundTransparency = UIConstants.BACKGROUND_FADE
InventoryFrame.BackgroundColor3 = UIColors.Card
InventoryFrame.Active = true
InventoryFrame.Visible = false
InventoryFrame.Parent = MainFrame

VRInventorySelector = NewGui('TextButton', 'VRInventorySelector')
VRInventorySelector.Position = UDim2.new(0, 0, 0, 0)
VRInventorySelector.Size = UDim2.new(1, 0, 1, 0)
VRInventorySelector.BackgroundTransparency = 1
VRInventorySelector.Text = ""
VRInventorySelector.Parent = InventoryFrame

local selectorImage = NewGui('ImageLabel', 'Selector')
selectorImage.Size = UDim2.new(1, 0, 1, 0)
selectorImage.Image = "rbxasset://textures/ui/Keyboard/key_selection_9slice.png"
selectorImage.ScaleType = Enum.ScaleType.Slice
selectorImage.SliceCenter = Rect.new(12,12,52,52)
selectorImage.Visible = false
VRInventorySelector.SelectionImageObject = selectorImage

VRInventorySelector.MouseButton1Click:Connect(function()
	vrMoveSlotToInventory()
end)

ScrollingFrame = NewGui('ScrollingFrame', 'ScrollingFrame')
ScrollingFrame.Selectable = false
ScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ScrollingFrame.Parent = InventoryFrame

UIGridFrame = NewGui('Frame', 'UIGridFrame')
UIGridFrame.Selectable = false
UIGridFrame.Size = UDim2.new(1, -(UIConstants.ICON_BUFFER*2), 1, 0)
UIGridFrame.Position = UDim2.new(0, UIConstants.ICON_BUFFER, 0, 0)
UIGridFrame.Parent = ScrollingFrame

UIGridLayout = Instance.new("UIGridLayout")
UIGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIGridLayout.CellSize = UDim2.new(0, UIConstants.ICON_SIZE, 0, UIConstants.ICON_SIZE)
UIGridLayout.CellPadding = UDim2.new(0, UIConstants.ICON_BUFFER, 0, UIConstants.ICON_BUFFER)
UIGridLayout.Parent = UIGridFrame

ScrollUpInventoryButton = MakeVRRoundButton('ScrollUpButton', 'rbxasset://textures/ui/Backpack/ScrollUpArrow.png')
ScrollUpInventoryButton.Size = UDim2.new(0, 34, 0, 34)
ScrollUpInventoryButton.Position = UDim2.new(0.5, -ScrollUpInventoryButton.Size.X.Offset/2, 0, INVENTORY_HEADER_SIZE + 3)
ScrollUpInventoryButton.Icon.Position = ScrollUpInventoryButton.Icon.Position - UDim2.new(0,0,0,2)
ScrollUpInventoryButton.MouseButton1Click:Connect(function()
	ScrollingFrame.CanvasPosition = Vector2.new(
		ScrollingFrame.CanvasPosition.X,
		Clamp(0, ScrollingFrame.CanvasSize.Y.Offset - ScrollingFrame.AbsoluteWindowSize.Y, ScrollingFrame.CanvasPosition.Y - (UIConstants.ICON_BUFFER + UIConstants.ICON_SIZE)))
end)

ScrollDownInventoryButton = MakeVRRoundButton('ScrollDownButton', 'rbxasset://textures/ui/Backpack/ScrollUpArrow.png')
ScrollDownInventoryButton.Rotation = 180
ScrollDownInventoryButton.Icon.Position = ScrollDownInventoryButton.Icon.Position - UDim2.new(0,0,0,2)
ScrollDownInventoryButton.Size = UDim2.new(0, 34, 0, 34)
ScrollDownInventoryButton.Position = UDim2.new(0.5, -ScrollDownInventoryButton.Size.X.Offset/2, 1, -ScrollDownInventoryButton.Size.Y.Offset - 3)
ScrollDownInventoryButton.MouseButton1Click:Connect(function()
	ScrollingFrame.CanvasPosition = Vector2.new(
		ScrollingFrame.CanvasPosition.X,
		Clamp(0, ScrollingFrame.CanvasSize.Y.Offset - ScrollingFrame.AbsoluteWindowSize.Y, ScrollingFrame.CanvasPosition.Y + (UIConstants.ICON_BUFFER + UIConstants.ICON_SIZE)))
end)

ScrollingFrame.Changed:Connect(function(prop)
	if prop == 'AbsoluteWindowSize' or prop == 'CanvasPosition' or prop == 'CanvasSize' then
		local canScrollUp = ScrollingFrame.CanvasPosition.Y ~= 0
		local canScrollDown = ScrollingFrame.CanvasPosition.Y < ScrollingFrame.CanvasSize.Y.Offset - ScrollingFrame.AbsoluteWindowSize.Y

		ScrollUpInventoryButton.Visible = canScrollUp
		ScrollDownInventoryButton.Visible = canScrollDown
	end
end)

UpdateBackpackLayout()

local function updateHotbarForCameraAngles()
	if not HotbarFrame then
		return
	end

	ForceHideHotbar = Player:GetAttribute("ViewingCameraAngles") and true or false
	if ForceHideHotbar and InventoryFrame.Visible then
		InventoryIcon:deselect()
	end

	if ForceHideHotbar then
		UnequipAllTools()
	end

	AdjustHotbarFrames()
end

local function updateSelectedSlotForSwimming()
	local selectedSlot = SelectionState.LastSelectedSlot
	if not selectedSlot or not selectedSlot.Tool then
		return
	end

	local tool = selectedSlot.Tool
	if isDpvBlocked(tool) then
		if IsEquipped(tool) then
			UnequipAllTools()
			lastEquippedSlot = nil
		end
	else
		if isDpvTool(tool) and not IsEquipped(tool) and tool.Parent == Backpack and not IsSpectating() then
			EquipNewTool(tool)
		end
	end

	updateSelectedSlot(selectedSlot)
	selectedSlot:UpdateEquipView()
end

if Player then
	Player:GetAttributeChangedSignal("ViewingCameraAngles"):Connect(updateHotbarForCameraAngles)
	Player:GetAttributeChangedSignal("Swimming"):Connect(updateSelectedSlotForSwimming)
	updateHotbarForCameraAngles()
end

local gamepadHintsFrame = Utility:Create'Frame'
{
	Name = "GamepadHintsFrame",
	Size = UDim2.new(0, HotbarFrame.Size.X.Offset, 0, (IsTenFootInterface and 95 or 60)),
	BackgroundTransparency = 1,
	Visible = false,
	Parent = MainFrame
}

local function addGamepadHint(hintImage, hintImageLarge, hintText)
	local hintFrame = Utility:Create'Frame'
	{
		Name = "HintFrame",
		Size = UDim2.new(1, 0, 1, -5),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = 1,
		Parent = gamepadHintsFrame
	}

	local hintImage = Utility:Create'ImageLabel'
	{
		Name = "HintImage",
		Size = (IsTenFootInterface and UDim2.new(0,90,0,90) or UDim2.new(0,60,0,60)),
		BackgroundTransparency = 1,
		Image = (IsTenFootInterface and hintImageLarge or hintImage),
		Parent = hintFrame
	}

	local hintText = Utility:Create'TextLabel'
	{
		Name = "HintText",
		Position = UDim2.new(0, (IsTenFootInterface and 100 or 70), 0, 0),
		Size = UDim2.new(1, -(IsTenFootInterface and 100 or 70), 1, 0),
		Font = Enum.Font.SourceSansBold,
		FontSize = (IsTenFootInterface and Enum.FontSize.Size36 or Enum.FontSize.Size24),
		BackgroundTransparency = 1,
		Text = hintText,
		TextColor3 = Color3.new(1,1,1),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Parent = hintFrame
	}
	local textSizeConstraint = Instance.new("UITextSizeConstraint", hintText)
	textSizeConstraint.MaxTextSize = math.max(textSizeConstraint.MinTextSize, hintText.TextSize)
end

local function resizeGamepadHintsFrame()
	gamepadHintsFrame.Size = UDim2.new(HotbarFrame.Size.X.Scale, HotbarFrame.Size.X.Offset, 0, (IsTenFootInterface and 95 or 60))
	gamepadHintsFrame.Position = UDim2.new(HotbarFrame.Position.X.Scale, HotbarFrame.Position.X.Offset, InventoryFrame.Position.Y.Scale, InventoryFrame.Position.Y.Offset - gamepadHintsFrame.Size.Y.Offset)

	local spaceTaken = 0

	local gamepadHints = gamepadHintsFrame:GetChildren()
	for i = 1, #gamepadHints do
		gamepadHints[i].Size = UDim2.new(1, 0, 1, -5)
		gamepadHints[i].Position = UDim2.new(0, 0, 0, 0)
		spaceTaken = spaceTaken + (gamepadHints[i].HintText.Position.X.Offset + gamepadHints[i].HintText.TextBounds.X)
	end

	local spaceBetweenElements = (gamepadHintsFrame.AbsoluteSize.X - spaceTaken)/(#gamepadHints - 1)
	for i = 1, #gamepadHints do
		gamepadHints[i].Position = (i == 1 and UDim2.new(0, 0, 0, 0) or UDim2.new(0, gamepadHints[i-1].Position.X.Offset + gamepadHints[i-1].Size.X.Offset + spaceBetweenElements, 0, 0))
		gamepadHints[i].Size = UDim2.new(0, (gamepadHints[i].HintText.Position.X.Offset + gamepadHints[i].HintText.TextBounds.X), 1, -5)
	end
end

addGamepadHint("rbxasset://textures/ui/Settings/Help/XButtonDark.png", "rbxasset://textures/ui/Settings/Help/XButtonDark@2x.png", "Remove From Hotbar")
addGamepadHint("rbxasset://textures/ui/Settings/Help/AButtonDark.png", "rbxasset://textures/ui/Settings/Help/AButtonDark@2x.png", "Select/Swap")
addGamepadHint("rbxasset://textures/ui/Settings/Help/BButtonDark.png", "rbxasset://textures/ui/Settings/Help/BButtonDark@2x.png", "Close Backpack")

do
	local searchFrame = NewGui('Frame', 'Search')
	UIFactory.applyCorner(searchFrame, UDim.new(0, 8))
	UIFactory.applyStroke(searchFrame, {
		Color = UIColors.Stroke,
		Transparency = 0.55,
		Thickness = 1,
	})
	searchFrame.BackgroundColor3 = SEARCH_BACKGROUND_COLOR
	searchFrame.BackgroundTransparency = SEARCH_BACKGROUND_FADE
	searchFrame.Size = UDim2.new(0, SEARCH_WIDTH - (SEARCH_BUFFER * 2), 0, INVENTORY_HEADER_SIZE - (SEARCH_BUFFER * 2))
	searchFrame.Position = UDim2.new(1, -searchFrame.Size.X.Offset - SEARCH_BUFFER, 0, SEARCH_BUFFER)
	searchFrame.Parent = InventoryFrame

	local searchBox = NewGui('TextBox', 'TextBox')
	searchBox.PlaceholderText = SEARCH_TEXT
	searchBox.TextColor3 = SEARCH_TEXT_COLOR
	searchBox.PlaceholderColor3 = UIColors.TextDark
	searchBox.ClearTextOnFocus = false
	searchBox.FontSize = Enum.FontSize.Size24
	searchBox.TextXAlignment = Enum.TextXAlignment.Left
	searchBox.BackgroundTransparency = 1
	local uipadding = Instance.new("UIPadding")
	uipadding.Parent = searchBox
	uipadding.PaddingLeft = UDim.new(0, 8)
	searchBox.Size = searchFrame.Size - UDim2.fromOffset(0, SEARCH_TEXT_OFFSET_FROMLEFT)
	searchBox.Position = UDim2.new(0, SEARCH_TEXT_OFFSET_FROMLEFT, 0, 0)
	searchBox.Parent = searchFrame

	local xButton = NewGui('TextButton', 'X')
	UIFactory.applyCorner(xButton, UDim.new(0, 6))
	UIFactory.applyStroke(xButton, {
		Color = UIColors.Stroke,
		Transparency = 0.4,
		Thickness = 1,
	})
	xButton.Font = Enum.Font.Arial
	xButton.Text = 'x'
	xButton.ZIndex = 10
	xButton.TextColor3 = UIColors.Accent
	xButton.FontSize = Enum.FontSize.Size24
	xButton.TextYAlignment = Enum.TextYAlignment.Bottom
	xButton.BackgroundColor3 = UIColors.Button
	xButton.BackgroundTransparency = 0
	xButton.Size = UDim2.new(0, searchFrame.Size.Y.Offset - (SEARCH_BUFFER * 2), 0, searchFrame.Size.Y.Offset - (SEARCH_BUFFER * 2))
	xButton.Position = UDim2.new(1, -xButton.Size.X.Offset - (SEARCH_BUFFER * 2), 0.5, -xButton.Size.Y.Offset / 2)
	xButton.Visible = false
	xButton.BorderSizePixel = 0
	xButton.Parent = searchFrame

	local function search()
		local terms = {}
		for word in searchBox.Text:gmatch('%S+') do
			terms[word:lower()] = true
		end

		local hitTable = {}
		for i = NumberOfHotbarSlots + 1, #Slots do -- Only search inventory slots
			local slot = Slots[i]
			local hits = slot:CheckTerms(terms)
			table.insert(hitTable, {slot, hits})
			slot.Frame.Visible = false
			slot.Frame.Parent = InventoryFrame
		end

		table.sort(hitTable, function(left, right)
			return left[2] > right[2]
		end)
		ViewingSearchResults = true

		local hitCount = 0
		for _, data in ipairs(hitTable) do
			local slot, hits = data[1], data[2]
			if hits > 0 then
				slot.Frame.Visible = true
				slot.Frame.Parent = UIGridFrame
				slot.Frame.LayoutOrder = NumberOfHotbarSlots + hitCount
				hitCount = hitCount + 1
			end
		end

		ScrollingFrame.CanvasPosition = Vector2.new(0, 0)
		UpdateScrollingFrameCanvasSize()

		xButton.ZIndex = 3
	end

	local function clearResults()
		if xButton.ZIndex > 0 then
			ViewingSearchResults = false
			for i = NumberOfHotbarSlots + 1, #Slots do
				local slot = Slots[i]
				slot.Frame.LayoutOrder = slot.Index
				slot.Frame.Parent = UIGridFrame
				slot.Frame.Visible = true
			end
			xButton.ZIndex = 0
		end
		UpdateScrollingFrameCanvasSize()
	end

	local function reset()
		clearResults()
		searchBox.Text = ''
	end

	local function onChanged(property)
		if property == 'Text' then
			local text = searchBox.Text
			if text == '' then
				clearResults()
			elseif text ~= SEARCH_TEXT then
				search()
			end
			xButton.Visible = false
		end
	end

	local function focusLost(enterPressed)
		if enterPressed then
			search()
		end
	end

	xButton.MouseButton1Click:Connect(reset)
	searchBox.Changed:Connect(onChanged)
	searchBox.FocusLost:Connect(focusLost)

	BackpackScript.StateChanged.Event:Connect(function(isNowOpen)

		if not isNowOpen then
			reset()
			if not InventoryFrame.Visible then
				InventoryIcon:deselect()
			end
		end
	end)

	HotkeyFns[Enum.KeyCode.Escape.Value] = function(isProcessed)
		if isProcessed then
			reset()
		elseif InventoryFrame.Visible then
			InventoryIcon:deselect()
		end
	end

	local function detectGamepad(lastInputType)
		if lastInputType == Enum.UserInputType.Gamepad1 and not UserInputService.VREnabled then
			searchFrame.Visible = false
		else
			searchFrame.Visible = true
		end
	end
	UserInputService.LastInputTypeChanged:Connect(detectGamepad)
end

GuiService.MenuOpened:Connect(function()
	if InventoryFrame.Visible then
		InventoryIcon:deselect()
	end
end)


do -- Make the Inventory expand/collapse arrow (unless TopBar)
	local removeHotBarSlot = function(_name, state, _input)
		if state ~= Enum.UserInputState.Begin then return end
		if not GuiService.SelectedObject then return end

		for i = 1, NumberOfHotbarSlots do
			if Slots[i].Frame == GuiService.SelectedObject and Slots[i].Tool then
				Slots[i]:MoveToInventory()
				return
			end
		end
	end

	local function openClose()
		if not next(Dragging) then
			InventoryFrame.Visible = not InventoryFrame.Visible
			local nowOpen = InventoryFrame.Visible
			AdjustHotbarFrames()
			HotbarFrame.Active = not HotbarFrame.Active
			for i = 1, NumberOfHotbarSlots do
				Slots[i]:SetClickability(not nowOpen)
			end
		end

		if InventoryFrame.Visible then
			if GamepadEnabled then
				if GAMEPAD_INPUT_TYPES[UserInputService:GetLastInputType()] then
					resizeGamepadHintsFrame()
					gamepadHintsFrame.Visible = not UserInputService.VREnabled
				end
				enableGamepadInventoryControl()
			end
			if BackpackPanel and VRService.VREnabled then
				BackpackPanel:SetVisible(true)
				BackpackPanel:RequestPositionUpdate()
			end
		else
			if GamepadEnabled then
				gamepadHintsFrame.Visible = false
			end
			disableGamepadInventoryControl()
		end

		if InventoryFrame.Visible then
			ContextActionService:BindAction("RBXRemoveSlot", removeHotBarSlot, false, Enum.KeyCode.ButtonX)
		else
			ContextActionService:UnbindAction("RBXRemoveSlot")
		end

		BackpackScript.IsOpen = InventoryFrame.Visible
		BackpackScript.StateChanged:Fire(InventoryFrame.Visible)
	end

	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	BackpackScript.OpenClose = openClose
end

while not Player do
	wait()
	Player = PlayersService.LocalPlayer
end

-- Listen to current and all future characters of our player
Player.CharacterAdded:Connect(OnCharacterAdded)
if Player.Character then
	OnCharacterAdded(Player.Character)
end

do
	UserInputService.InputBegan:Connect(OnInputBegan)

	UserInputService.TextBoxFocused:Connect(function() TextBoxFocused = true end)
	UserInputService.TextBoxFocusReleased:Connect(function() TextBoxFocused = false end)

	HotkeyFns[DROP_HOTKEY_VALUE] = function()
		UnequipAllTools()
	end

	UserInputService.Changed:Connect(OnUISChanged)
	OnUISChanged('KeyboardEnabled')

	if UserInputService:GetGamepadConnected(Enum.UserInputType.Gamepad1) then
		gamepadConnected()
	end
	UserInputService.GamepadConnected:Connect(function(gamepadEnum)
		if gamepadEnum == Enum.UserInputType.Gamepad1 then
			gamepadConnected()
		end
	end)
	UserInputService.GamepadDisconnected:Connect(function(gamepadEnum)
		if gamepadEnum == Enum.UserInputType.Gamepad1 then
			gamepadDisconnected()
		end
	end)
end

function BackpackScript:SetBackpackEnabled(Enabled)
	BackpackEnabled = Enabled
end

function BackpackScript:IsOpened()
	return BackpackScript.IsOpen
end

function BackpackScript:GetBackpackEnabled()
	return BackpackEnabled
end

function BackpackScript:GetStateChangedEvent()
	return BackpackScript.StateChanged
end

function BackpackScript:GetSlotFrameByToolName(toolName)
	if not toolName then
		return nil
	end

	for _, slot in ipairs(Slots) do
		if slot and slot.Tool and slot.Tool.Name == toolName then
			return slot.Frame
		end
	end

	return nil
end

RunService.Heartbeat:Connect(function()
	OnIconChanged(BackpackEnabled)
end)
local APIRemote = Instance.new("BindableFunction")
APIRemote.Parent = game.ReplicatedStorage
APIRemote.Name = "CustomPackAPI"
local apifunctions = {
	SetBackpackEnabled = function(enabled :boolean)
		BackpackScript:SetBackpackEnabled(enabled)
	end,
	SetInventoryOpen = function(enabled :boolean)
		BackpackScript.IsOpen = enabled
	end,
	ToggleInventoryOpen = function()
		BackpackScript.OpenClose()
	end,
	IsInventoryOpen = function()
		return BackpackScript:IsInventoryOpen()
	end,
	GetBackpackEnabled = function()
		return BackpackEnabled
	end,
	GetStateChangedEvent = function()
		return BackpackScript:GetStateChangedEvent()
	end,
	GetSlotFrameByToolName = function(toolName)
		return BackpackScript:GetSlotFrameByToolName(toolName)
	end,
}

APIRemote.OnInvoke = function (name, data)
	assert(apifunctions[name], ("API Function \"%s\" doesn't exist."):format(tostring(name)))
	if apifunctions[name] then
		return apifunctions[name](table.unpack(data or {}))
	end
end

BackpackScript.ModuleName = Config.ModuleName
BackpackScript.KeepVRTopbarOpen = Config.KeepVRTopbarOpen
BackpackScript.VRIsExclusive = Config.VRIsExclusive
BackpackScript.VRClosesNonExclusive = Config.VRClosesNonExclusive

export type BackpackController = typeof(BackpackScript)

return BackpackScript

