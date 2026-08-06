local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Knit = require(ReplicatedStorage.Packages.Knit)
local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local InventoryUpdate = Remotes:WaitForChild("InventoryUpdate")
local InventoryAction = Remotes:WaitForChild("InventoryAction")
local KillEffectManager = require(ReplicatedStorage:WaitForChild("KillEffectManager"))
local KnifeIcon = require(ReplicatedStorage:WaitForChild("KnifeIcon"))
local KnifeSkinManager = require(ReplicatedStorage:WaitForChild("KnifeSkinManager"))
local PoseConfig = require(ReplicatedStorage:WaitForChild("PoseConfig"))
local TitleManager = require(ReplicatedStorage:WaitForChild("TitleManager"))
local UISounds = require(ReplicatedStorage:WaitForChild("UISounds"))
local GridMetrics = require(script.GridMetrics)
local NewItemTracker = require(script.NewItemTracker)
local Search = require(script.Search)
local SellFlow = require(script.SellFlow)
local TabBar = require(script.TabBar)

local InventoryController = Knit.CreateController({
	Name = "InventoryController",
})

function InventoryController:Open(tab)
	if not self._gui then
		return
	end
	self._gui.Enabled = true
	if tab and self._tabBar then
		self._tabBar:Select(tab)
	end
end

function InventoryController:Close()
	if self._gui then
		self._gui.Enabled = false
	end
	if self._confirmGui then
		self._confirmGui.Enabled = false
	end
end

function InventoryController:SelectTab(tab)
	if self._tabBar then
		self._tabBar:Select(tab)
	end
end

function InventoryController:KnitStart()
	local TweenController = Knit.GetController("TweenController")
	local SELECT_TWEEN = TweenController:GetInfo(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local search = Search.new({
		killEffects = KillEffectManager,
		knifeSkins = KnifeSkinManager,
		titles = TitleManager,
	})
	local newItemTracker = NewItemTracker.new()

	local pg = player:WaitForChild("PlayerGui")
	local gui = pg:WaitForChild("Inventory")
	local holderFrame = gui:WaitForChild("HolderFrame")
	local outerFrame = holderFrame:WaitForChild("Inventory")
	holderFrame.Visible = true
	local tabsFrame = outerFrame:WaitForChild("Inventory"):WaitForChild("ScrollingFilter")
	local panel = outerFrame:WaitForChild("Inventory")
	local actionButtons = panel:WaitForChild("Buttons")
	local equipBtn = actionButtons:WaitForChild("Equip")
	local sellBtn = actionButtons:WaitForChild("Sell")
	local closeBtn = panel:WaitForChild("CloseButton")
	local grid = panel:WaitForChild("ScrollingFrame")
	local tabsBar = outerFrame:WaitForChild("Buttons")
	local allTabBtn = tabsBar:FindFirstChild("All")
	local knivesTab = tabsBar:WaitForChild("Knives")
	local killEffectsTab = tabsBar:WaitForChild("KillEffects")
	local posesTab = tabsBar:WaitForChild("Poses")
	local titlesTab = tabsBar:WaitForChild("Titles")

	local gridLayout = grid:WaitForChild("UIGridLayout")
	local gridPadding = grid:FindFirstChildOfClass("UIPadding")
	local gridMetrics = GridMetrics.new(grid, gridLayout, gridPadding)
	gridMetrics:Start()

	local sourceItemFrame = grid:WaitForChild("ItemFrame")
	local template = sourceItemFrame:Clone()
	sourceItemFrame.Visible = false
	local sourcePoseFrame = grid:WaitForChild("PoseFrame")
	local poseTemplate = sourcePoseFrame:Clone()
	sourcePoseFrame.Visible = false
	local sourceTitleFrame = grid:WaitForChild("TitleFrame")
	local titleTemplate = sourceTitleFrame:Clone()
	sourceTitleFrame.Visible = false

	local confirmGui = pg:WaitForChild("ConfirmSellGui")
	local confirmFrame = confirmGui:WaitForChild("ConfirmSellFrame")
	local confirmQuestion = confirmFrame:WaitForChild("Question")
	local confirmAccept = confirmFrame:WaitForChild("AcceptBT")
	local confirmDecline = confirmFrame:WaitForChild("DeclineBT")
	self._gui = gui
	self._confirmGui = confirmGui

	local RARITY_TABS = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Secret", "Exclusive" }

	local lastState = { items = {}, equipped = nil }
	local selectedUid = nil
	local activeTab = "all"
	local otherSelectedId = nil
	local selectedKind = nil
	local rarityFilter = nil
	local reselectIndex = nil
	local cellByUid = {}
	local SELECTED_SCALE = 1.05
	local CELL_HOVER_SCALE = 1.06
	local SELECTED_BORDER_COLOR = Color3.fromRGB(255, 215, 0)
	local DEFAULT_BORDER_COLOR = Color3.fromRGB(0, 0, 0)
	local flashTweens = {}
	local FAVORITE_LAYOUT_BASE = -1_000_000

	local function setLayered(holder, text)
		if not holder then
			return
		end
		holder.Text = text
		local top = holder:FindFirstChild("Top") or holder:FindFirstChild("Equipped")
		if top and top:IsA("TextLabel") then
			top.Text = text
		end
	end

	local function buttonLabel(btn)
		return btn:FindFirstChildOfClass("TextLabel")
	end

	local DEFAULT_UID = "__default__"
	local function defaultItem()
		return {
			uid = DEFAULT_UID,
			name = "Default",
			rarity = "Common",
			skinId = nil,
			effect = "none",
			isDefault = true,
		}
	end

	local function selectedItem()
		if not selectedUid then
			return nil
		end
		if selectedUid == DEFAULT_UID then
			if search:IsActive() then
				return nil
			end
			return defaultItem()
		end
		for _, it in ipairs(lastState.items) do
			if it.uid == selectedUid then
				return it
			end
		end
		return nil
	end

	local function visibleItems()
		local list = {}
		for _, it in ipairs(lastState.items) do
			if rarityFilter == nil or it.rarity == rarityFilter then
				list[#list + 1] = it
			end
		end
		return list
	end

	local function refreshActionButtons()
		local it = selectedItem()
		if not it then
			setLayered(buttonLabel(equipBtn), "Equip")
			setLayered(buttonLabel(sellBtn), "Sell")
			sellBtn.Visible = true
			return
		end
		if it.isDefault then
			local isEquipped = (lastState.equipped == nil)
			setLayered(buttonLabel(equipBtn), isEquipped and "Equipped" or "Equip")
			sellBtn.Visible = false
			return
		end

		local isEquipped = (lastState.equipped == it.uid)
		setLayered(buttonLabel(equipBtn), isEquipped and "Unequip" or "Equip")

		if not SellFlow.CanSell(it) then
			sellBtn.Visible = false
			return
		end
		sellBtn.Visible = true
		local sellVal = KnifeSkinManager.sellValue(it.rarity)
		setLayered(buttonLabel(sellBtn), "Sell +" .. sellVal)
	end

	local function applySelectionVisual()
		local sel = (selectedKind == "knife") and selectedUid or otherSelectedId
		for uid, cell in pairs(cellByUid) do
			if cell and cell.Parent then
				local isSel = (uid == sel)
				local scale = cell:FindFirstChildOfClass("UIScale")
				if scale then
					TweenController:Play(scale, SELECT_TWEEN, { Scale = isSel and SELECTED_SCALE or 1 }, "scale")
				end

				local stroke = cell:FindFirstChildOfClass("UIStroke")
				if stroke then
					stroke.Color = isSel and SELECTED_BORDER_COLOR or DEFAULT_BORDER_COLOR
					stroke.Transparency = isSel and 0 or 1
				end
			end
		end
	end

	local function tintLayered(label, color)
		if not label then
			return
		end
		local top = label:FindFirstChild("Top")
		local grad = top and top:FindFirstChildOfClass("UIGradient")
		if grad then
			grad.Color = ColorSequence.new(color)
		else
			label.TextColor3 = color
			if top and top:IsA("TextLabel") then
				top.TextColor3 = color
			end
		end
	end

	local function updateFavoriteVisual(cell, it, layoutOrder)
		local favoriteButton = cell:FindFirstChild("Favorite")
		local isFavorite = it.isDefault ~= true and it.favorite == true
		cell:SetAttribute("IsFavoriteKnife", isFavorite)
		cell.LayoutOrder = if isFavorite then FAVORITE_LAYOUT_BASE + layoutOrder else layoutOrder
		if favoriteButton and favoriteButton:IsA("GuiButton") then
			favoriteButton.Visible = it.isDefault ~= true
			favoriteButton.Active = true
			favoriteButton.Interactable = true
			favoriteButton.Selectable = true
			local gradient = favoriteButton:FindFirstChildOfClass("UIGradient")
			if gradient then
				gradient.Enabled = not isFavorite
			end
		end
	end

	local function buildCell(it, layoutOrder)
		local isDefault = it.isDefault == true
		local cell = template:Clone()
		cell.Name = "Cell"
		cell.Visible = true
		updateFavoriteVisual(cell, it, layoutOrder)

		setLayered(cell:FindFirstChild("KnifeName"), KnifeSkinManager.displayName(it.name))
		local rarityLabel = cell:FindFirstChild("KnifeRarity")

		setLayered(rarityLabel, isDefault and "" or it.rarity)
		if rarityLabel then
			rarityLabel.Visible = not isDefault
			if not isDefault then
				tintLayered(rarityLabel, KnifeSkinManager.rarityColor(it.rarity))
			end
		end
		local effText = (not isDefault and it.effect and it.effect ~= "none") and (it.effectName or "") or ""
		local mut = cell:FindFirstChild("KnifeMutation")
		if mut then
			setLayered(mut, effText)
			mut.Visible = (effText ~= "")
			if effText ~= "" then
				tintLayered(mut, KnifeSkinManager.effectColor(it.effect))
			end
		end

		local icon = cell:FindFirstChild("Icon")
		if icon then
			if isDefault then
				KnifeIcon.renderDefault(icon)
			else
				KnifeIcon.render(icon, it.skinId)
			end
		end

		local equippedTag = cell:FindFirstChild("Equipped")
		if equippedTag then
			if isDefault then
				equippedTag.Visible = (lastState.equipped == nil)
			else
				equippedTag.Visible = (lastState.equipped == it.uid)
			end
		end

		local hit = cell:FindFirstChild("Background") or cell
		local favoriteButton = cell:FindFirstChild("Favorite")
		if favoriteButton and favoriteButton:IsA("GuiButton") and not isDefault then
			favoriteButton.Activated:Connect(function()
				UISounds.select()
				InventoryAction:FireServer("toggleFavorite", it.uid)
			end)
		end

		local scale = cell:FindFirstChildOfClass("UIScale")
		if not scale then
			scale = Instance.new("UIScale")
			scale.Parent = cell
		end
		local cellStroke = cell:FindFirstChildOfClass("UIStroke")
		if not cellStroke then
			cellStroke = Instance.new("UIStroke")
			cellStroke.Thickness = 3
			cellStroke.Color = DEFAULT_BORDER_COLOR
			cellStroke.Transparency = 1
			cellStroke.Parent = cell
		end
		local isSel = (it.uid == selectedUid)
		scale.Scale = isSel and SELECTED_SCALE or 1
		cellStroke.Color = isSel and SELECTED_BORDER_COLOR or DEFAULT_BORDER_COLOR
		cellStroke.Transparency = isSel and 0 or 1
		cellByUid[it.uid] = cell

		local function baseScale()
			return (selectedUid == it.uid) and SELECTED_SCALE or 1
		end
		hit.MouseEnter:Connect(function()
			if confirmGui.Enabled then
				return
			end
			UISounds.play("hover")
			TweenController:Play(scale, SELECT_TWEEN, { Scale = baseScale() * CELL_HOVER_SCALE }, "scale")
		end)
		hit.MouseLeave:Connect(function()
			if confirmGui.Enabled then
				return
			end
			TweenController:Play(scale, SELECT_TWEEN, { Scale = baseScale() }, "scale")
		end)
		hit.MouseButton1Down:Connect(function()
			if confirmGui.Enabled then
				return
			end
			TweenController:Play(scale, SELECT_TWEEN, { Scale = baseScale() * 0.97 }, "scale")
		end)
		hit.MouseButton1Up:Connect(function()
			if confirmGui.Enabled then
				return
			end
			TweenController:Play(scale, SELECT_TWEEN, { Scale = baseScale() * CELL_HOVER_SCALE }, "scale")
		end)
		hit.MouseButton1Click:Connect(function()
			if confirmGui.Enabled then
				return
			end
			UISounds.select()
			selectedKind = "knife"
			selectedUid = it.uid
			otherSelectedId = nil
			applySelectionVisual()
			refreshActionButtons()
		end)
		cell.Parent = grid
	end

	local refreshOtherButtons, onOtherEquip, refreshButtons, notifyWarn, attemptBuyPose, updateFilterVisuals

	local function listFor(kind)
		if kind == "killeffect" then
			return (lastState.killEffects and lastState.killEffects.items) or {}
		elseif kind == "pose" then
			return (lastState.poses and lastState.poses.items) or {}
		elseif kind == "title" then
			return (lastState.titles and lastState.titles.items) or {}
		end
		return {}
	end
	local function otherSelected()
		for _, it in ipairs(listFor(selectedKind)) do
			if it.id == otherSelectedId then
				return it
			end
		end
		return nil
	end

	local function bindCellHover(hit, scale, baseScaleFn)
		hit.MouseEnter:Connect(function()
			if confirmGui.Enabled then
				return
			end
			UISounds.play("hover")
			TweenController:Play(scale, SELECT_TWEEN, { Scale = baseScaleFn() * CELL_HOVER_SCALE }, "scale")
		end)
		hit.MouseLeave:Connect(function()
			if confirmGui.Enabled then
				return
			end
			TweenController:Play(scale, SELECT_TWEEN, { Scale = baseScaleFn() }, "scale")
		end)
		hit.MouseButton1Down:Connect(function()
			if confirmGui.Enabled then
				return
			end
			TweenController:Play(scale, SELECT_TWEEN, { Scale = baseScaleFn() * 0.97 }, "scale")
		end)
		hit.MouseButton1Up:Connect(function()
			if confirmGui.Enabled then
				return
			end
			TweenController:Play(scale, SELECT_TWEEN, { Scale = baseScaleFn() * CELL_HOVER_SCALE }, "scale")
		end)
	end

	local function buildOtherCell(it, order, kind)
		local cell = template:Clone()
		cell.Name = "Cell"
		cell.Visible = true
		cell.LayoutOrder = order
		local favoriteButton = cell:FindFirstChild("Favorite")
		if favoriteButton then
			favoriteButton.Visible = false
		end
		setLayered(cell:FindFirstChild("KnifeName"), it.name or it.id)

		local rarityColor = (kind == "killeffect") and KillEffectManager.rarityColor(it.rarity or "Common")
			or KnifeSkinManager.rarityColor(it.rarity or "Common")

		local rarityLabel = cell:FindFirstChild("KnifeRarity")
		if rarityLabel then
			rarityLabel.Visible = true
			setLayered(rarityLabel, it.rarity or "")
			tintLayered(rarityLabel, rarityColor)
		end

		local mut = cell:FindFirstChild("KnifeMutation")
		if mut then
			local txt, col
			if it.free then
				txt, col = "Free", Color3.fromRGB(120, 220, 140)
			elseif it.owned then
				txt, col = "", nil
			elseif kind == "pose" then
				txt, col = "Buy " .. tostring(it.price or 0), Color3.fromRGB(255, 215, 90)
			else
				txt, col = "Locked", Color3.fromRGB(255, 150, 150)
			end
			setLayered(mut, txt)
			mut.Visible = (txt ~= "")
			if col then
				tintLayered(mut, col)
			end
		end

		local icon = cell:FindFirstChild("Icon")
		if icon then
			icon:ClearAllChildren()
			local iconImage = (kind == "killeffect") and KillEffectManager.effectIcon(it.id) or nil
			if iconImage and iconImage ~= "" then
				pcall(function()
					icon.Image = iconImage
				end)
				icon.BackgroundTransparency = 1
			else
				pcall(function()
					icon.Image = ""
				end)
				icon.BackgroundTransparency = 0.8
				icon.BackgroundColor3 = rarityColor
			end
		end

		local equippedTag = cell:FindFirstChild("Equipped")
		if equippedTag then
			if kind == "killeffect" then
				equippedTag.Visible = (lastState.killEffects and lastState.killEffects.equipped == it.id) or false
			else
				equippedTag.Visible = it.equipped == true
			end
		end

		local hit = cell:FindFirstChild("Background") or cell
		if not it.owned and (hit:IsA("ImageButton") or hit:IsA("ImageLabel")) then
			pcall(function()
				hit.ImageTransparency = 0.5
			end)
		end

		local scale = cell:FindFirstChildOfClass("UIScale")
		if not scale then
			scale = Instance.new("UIScale")
			scale.Parent = cell
		end
		local cellStroke = cell:FindFirstChildOfClass("UIStroke")
		if not cellStroke then
			cellStroke = Instance.new("UIStroke")
			cellStroke.Thickness = 3
			cellStroke.Parent = cell
		end
		local isSel = (selectedKind == kind and it.id == otherSelectedId)
		scale.Scale = isSel and SELECTED_SCALE or 1
		cellStroke.Color = isSel and SELECTED_BORDER_COLOR or DEFAULT_BORDER_COLOR
		cellStroke.Transparency = isSel and 0 or 1
		cellByUid[it.id] = cell

		if hit:IsA("GuiButton") then
			bindCellHover(hit, scale, function()
				return (selectedKind == kind and it.id == otherSelectedId) and SELECTED_SCALE or 1
			end)
			hit.MouseButton1Click:Connect(function()
				UISounds.select()
				selectedKind = kind
				otherSelectedId = it.id
				selectedUid = nil
				applySelectionVisual()
				refreshButtons()
			end)
		end
		cell.Parent = grid
	end

	local function setPoseLabelBand(label, position, size, xAlignment)
		if not label then
			return
		end
		label.Position = position
		label.Size = size
		label.TextXAlignment = xAlignment
		local top = label:FindFirstChild("Top") or label:FindFirstChild("Equipped")
		if top and top:IsA("TextLabel") then
			top.Position = UDim2.fromScale(0.5, 0.441176474)
			top.Size = UDim2.fromScale(1, 1)
			top.TextXAlignment = xAlignment
		end
	end

	local function applyPoseCellLayout(cell)
		setPoseLabelBand(
			cell:FindFirstChild("KnifeName"),
			UDim2.fromScale(0.5, 0.825396836),
			UDim2.fromScale(0.833333373, 0.134920642),
			Enum.TextXAlignment.Center
		)
		setPoseLabelBand(
			cell:FindFirstChild("KnifeRarity"),
			UDim2.fromScale(0.5, 0.142857105),
			UDim2.fromScale(0.833333373, 0.134920642),
			Enum.TextXAlignment.Left
		)
		setPoseLabelBand(
			cell:FindFirstChild("Equipped"),
			UDim2.fromScale(0.5, 0.68),
			UDim2.fromScale(0.78, 0.12),
			Enum.TextXAlignment.Center
		)

		local purchaseBtn = cell:FindFirstChild("PurchaseButton")
		if purchaseBtn then
			setPoseLabelBand(
				purchaseBtn:FindFirstChild("Price"),
				UDim2.fromScale(0.5, 0.5),
				UDim2.fromScale(0.88, 0.58),
				Enum.TextXAlignment.Center
			)
		end
	end

	local function buildPoseCell(it, order)
		local owned = it.owned == true
		local purchasable = (not owned) and type(it.price) == "number" and it.price > 0
		local cell = poseTemplate:Clone()
		cell.Name = "Cell"
		cell.Visible = true
		cell.LayoutOrder = order
		applyPoseCellLayout(cell)

		setLayered(cell:FindFirstChild("KnifeName"), it.name or it.id)
		local rarityLabel = cell:FindFirstChild("KnifeRarity")
		if rarityLabel then
			setLayered(rarityLabel, it.rarity or "")
			rarityLabel.Visible = true
			tintLayered(rarityLabel, KnifeSkinManager.rarityColor(it.rarity or "Common"))
		end

		local icon = cell:FindFirstChild("Icon")
		if icon then
			local def = PoseConfig.getPose(it.id)
			local img = def and def.icon
			if type(img) == "string" and img ~= "" then
				icon.Image = img
				icon.Visible = true
			else
				icon.Visible = false
			end
		end

		local equippedTag = cell:FindFirstChild("Equipped")
		if equippedTag then
			equippedTag.Visible = (owned and it.equipped == true)
		end

		local lockTop = cell:FindFirstChild("LockIconTop")
		local lockBottom = cell:FindFirstChild("LockIconBottom")
		local purchaseBtn = cell:FindFirstChild("PurchaseButton")
		if lockTop then
			lockTop.Visible = not owned
		end
		if lockBottom then
			lockBottom.Visible = not owned
		end
		if purchaseBtn then
			purchaseBtn.Visible = purchasable
			local priceLabel = purchaseBtn:FindFirstChild("Price")
			if priceLabel then
				setLayered(priceLabel, tostring(it.price or 0))
			end
		end

		local scale = cell:FindFirstChildOfClass("UIScale")
		if not scale then
			scale = Instance.new("UIScale")
			scale.Parent = cell
		end
		local cellStroke = cell:FindFirstChildOfClass("UIStroke")
		if not cellStroke then
			cellStroke = Instance.new("UIStroke")
			cellStroke.Thickness = 3
			cellStroke.Parent = cell
		end
		local isSel = (selectedKind == "pose" and it.id == otherSelectedId)
		scale.Scale = isSel and SELECTED_SCALE or 1
		cellStroke.Color = isSel and SELECTED_BORDER_COLOR or DEFAULT_BORDER_COLOR
		cellStroke.Transparency = isSel and 0 or 1

		local bg = cell:FindFirstChild("Background")
		if owned then
			if bg and bg:IsA("GuiButton") then
				bindCellHover(bg, scale, function()
					return (selectedKind == "pose" and it.id == otherSelectedId) and SELECTED_SCALE or 1
				end)
				bg.MouseButton1Click:Connect(function()
					UISounds.select()
					selectedKind = "pose"
					otherSelectedId = it.id
					selectedUid = nil
					applySelectionVisual()
					refreshButtons()
				end)
			end
		else
			if bg then
				pcall(function()
					bg.AutoButtonColor = false
				end)
			end
		end

		cellByUid[it.id] = cell

		if purchasable and purchaseBtn and purchaseBtn:IsA("GuiButton") then
			UISounds.bindButton(purchaseBtn)
			purchaseBtn.MouseButton1Click:Connect(function()
				attemptBuyPose(it)
			end)
		end

		cell:SetAttribute("PoseInteractive", owned)
		cell.Parent = grid
	end

	local function buildTitleCell(it, order)
		local cell = titleTemplate:Clone()
		cell.Name = "Cell"
		cell.Visible = true
		cell.LayoutOrder = order
		setLayered(cell:FindFirstChild("TitleName"), it.name or it.id)
		local rarityLabel = cell:FindFirstChild("TitleRarity")
		if rarityLabel then
			rarityLabel.Visible = true
			setLayered(rarityLabel, it.rarity or "")
			tintLayered(rarityLabel, TitleManager.titleColor(it.id))
		end
		local equippedTag = cell:FindFirstChild("Equipped")
		if equippedTag then
			equippedTag.Visible = it.equipped == true
		end

		local hit = cell:FindFirstChild("Background") or cell
		if not it.owned and (hit:IsA("ImageButton") or hit:IsA("ImageLabel")) then
			pcall(function()
				hit.ImageTransparency = 0.5
			end)
		end

		local scale = cell:FindFirstChildOfClass("UIScale")
		if not scale then
			scale = Instance.new("UIScale")
			scale.Parent = cell
		end
		local cellStroke = cell:FindFirstChildOfClass("UIStroke")
		if not cellStroke then
			cellStroke = Instance.new("UIStroke")
			cellStroke.Thickness = 3
			cellStroke.Parent = cell
		end
		local isSel = (selectedKind == "title" and it.id == otherSelectedId)
		scale.Scale = isSel and SELECTED_SCALE or 1
		cellStroke.Color = isSel and SELECTED_BORDER_COLOR or DEFAULT_BORDER_COLOR
		cellStroke.Transparency = isSel and 0 or 1
		cellByUid[it.id] = cell

		if hit:IsA("GuiButton") then
			bindCellHover(hit, scale, function()
				return (selectedKind == "title" and it.id == otherSelectedId) and SELECTED_SCALE or 1
			end)
			hit.MouseButton1Click:Connect(function()
				UISounds.select()
				selectedKind = "title"
				otherSelectedId = it.id
				selectedUid = nil
				applySelectionVisual()
				refreshButtons()
			end)
		end
		cell.Parent = grid
	end

	refreshOtherButtons = function()
		sellBtn.Visible = false
		local it = otherSelected()
		if not it then
			setLayered(buttonLabel(equipBtn), "Equip")
			return
		end
		if selectedKind == "killeffect" then
			if not it.owned then
				setLayered(buttonLabel(equipBtn), "Locked")
			else
				local equipped = lastState.killEffects and lastState.killEffects.equipped == it.id
				setLayered(buttonLabel(equipBtn), equipped and "Unequip" or "Equip")
			end
		elseif selectedKind == "title" then
			if not it.owned then
				setLayered(buttonLabel(equipBtn), "Locked")
			else
				setLayered(buttonLabel(equipBtn), it.equipped and "Unequip" or "Equip")
			end
		else
			if not it.owned then
				setLayered(buttonLabel(equipBtn), "Buy " .. tostring(it.price or 0))
			else
				setLayered(buttonLabel(equipBtn), it.equipped and "Unequip" or "Equip")
			end
		end
	end

	onOtherEquip = function()
		local it = otherSelected()
		if not it then
			return
		end
		if selectedKind == "killeffect" then
			if not it.owned then
				UISounds.error()
				return
			end
			local equipped = lastState.killEffects and lastState.killEffects.equipped == it.id
			InventoryAction:FireServer(equipped and "unequipKillEffect" or "equipKillEffect", it.id)
		elseif selectedKind == "title" then
			if not it.owned then
				UISounds.error()
				return
			end
			InventoryAction:FireServer(it.equipped and "unequipTitle" or "equipTitle", it.id)
		else
			if not it.owned then
				InventoryAction:FireServer("buyPose", it.id)
			elseif it.equipped then
				InventoryAction:FireServer("unequipPose", it.id)
			else
				local equippedList = (lastState.poses and lastState.poses.equipped) or {}
				local maxEquipped = (lastState.poses and lastState.poses.maxEquipped) or 5
				if #equippedList >= maxEquipped then
					notifyWarn(("You can only equip %d poses at once."):format(maxEquipped))
					return
				end
				InventoryAction:FireServer("equipPose", it.id)
			end
		end
	end

	refreshButtons = function()
		if selectedKind == "killeffect" or selectedKind == "pose" or selectedKind == "title" then
			refreshOtherButtons()
		else
			refreshActionButtons()
		end
	end

	local function passesFilter(rarity)
		return rarityFilter == nil or rarity == rarityFilter
	end

	local function setCellSelection(cell, isSel)
		local scale = cell:FindFirstChildOfClass("UIScale")
		if scale then
			scale.Scale = isSel and SELECTED_SCALE or 1
		end
		local stroke = cell:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = isSel and SELECTED_BORDER_COLOR or DEFAULT_BORDER_COLOR
			stroke.Transparency = isSel and 0 or 1
		end
	end

	local function updateCell(it, cell, layoutOrder)
		updateFavoriteVisual(cell, it, layoutOrder)
		local equippedTag = cell:FindFirstChild("Equipped")
		if equippedTag then
			if it.isDefault then
				equippedTag.Visible = (lastState.equipped == nil)
			else
				equippedTag.Visible = (lastState.equipped == it.uid)
			end
		end
		local isSel = (selectedKind == "knife" and selectedUid == it.uid)
		setCellSelection(cell, isSel)
	end

	local function updateOtherCell(it, cell, layoutOrder, kind)
		cell.LayoutOrder = layoutOrder
		local equippedTag = cell:FindFirstChild("Equipped")
		if equippedTag then
			if kind == "killeffect" then
				equippedTag.Visible = (lastState.killEffects and lastState.killEffects.equipped == it.id) or false
			else
				equippedTag.Visible = it.equipped == true
			end
		end
		local hit = cell:FindFirstChild("Background") or cell
		if hit and (hit:IsA("ImageButton") or hit:IsA("ImageLabel")) then
			pcall(function()
				hit.ImageTransparency = (it.owned and 0 or 0.5)
			end)
		end
		local isSel = (selectedKind == kind and otherSelectedId == it.id)
		setCellSelection(cell, isSel)
	end

	local function updatePoseCell(it, cell, layoutOrder)
		cell.LayoutOrder = layoutOrder
		local owned = it.owned == true
		local equippedTag = cell:FindFirstChild("Equipped")
		if equippedTag then
			equippedTag.Visible = (owned and it.equipped == true)
		end
		local lockTop = cell:FindFirstChild("LockIconTop")
		local lockBottom = cell:FindFirstChild("LockIconBottom")
		local purchaseBtn = cell:FindFirstChild("PurchaseButton")
		if lockTop then
			lockTop.Visible = not owned
		end
		if lockBottom then
			lockBottom.Visible = not owned
		end
		if purchaseBtn then
			local poseBuyable = (not owned) and type(it.price) == "number" and it.price > 0
			purchaseBtn.Visible = poseBuyable
		end
		local isSel = (selectedKind == "pose" and otherSelectedId == it.id)
		setCellSelection(cell, isSel)
	end

	local function updateTitleCell(it, cell, layoutOrder)
		cell.LayoutOrder = layoutOrder
		local equippedTag = cell:FindFirstChild("Equipped")
		if equippedTag then
			equippedTag.Visible = it.equipped == true
		end
		local hit = cell:FindFirstChild("Background") or cell
		if hit and (hit:IsA("ImageButton") or hit:IsA("ImageLabel")) then
			pcall(function()
				hit.ImageTransparency = (it.owned and 0 or 0.5)
			end)
		end
		local isSel = (selectedKind == "title" and otherSelectedId == it.id)
		setCellSelection(cell, isSel)
	end

	local function startFlash(cell)
		if flashTweens[cell] then
			return
		end
		local f = Instance.new("Frame")
		f.Name = "NewFlash"
		f.BackgroundTransparency = 1
		f.Active = false
		f.Size = UDim2.fromScale(1, 1)
		f.ZIndex = 20
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = f
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Color = Color3.fromRGB(255, 255, 255)
		stroke.Transparency = 0
		stroke.Parent = f
		f.Parent = cell
		local info = TweenController:GetInfo(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
		local tw = TweenController:Play(stroke, info, { Transparency = 1 }, "new-item-flash")
		flashTweens[cell] = tw
	end

	local function stopFlash(cell)
		local tw = flashTweens[cell]
		if tw then
			tw:Cancel()
			flashTweens[cell] = nil
		end
		local f = cell:FindFirstChild("NewFlash")
		if f then
			f:Destroy()
		end
	end

	local function render()
		local order = 0
		local showKnives = (activeTab == "knives" or activeTab == "all")
		local showKills = (activeTab == "killeffects" or activeTab == "all")
		local showPoses = (activeTab == "poses" or activeTab == "all")
		local showTitles = (activeTab == "titles" or activeTab == "all")
		local desiredUids = {}

		if showKnives then
			local cell
			if not search:IsActive() then
				desiredUids[DEFAULT_UID] = true
				cell = cellByUid[DEFAULT_UID]
				if not cell then
					buildCell(defaultItem(), order)
				else
					updateCell(defaultItem(), cell, order)
				end
				order += 1
			end
			for _, it in ipairs(lastState.items) do
				if passesFilter(it.rarity) and search:Matches(it, "knife") then
					desiredUids[it.uid] = true
					cell = cellByUid[it.uid]
					if not cell then
						buildCell(it, order)
					else
						updateCell(it, cell, order)
					end
					order += 1
				end
			end
		end
		if showKills then
			for _, it in ipairs(listFor("killeffect")) do
				if it.owned and passesFilter(it.rarity) and search:Matches(it, "killeffect") then
					desiredUids[it.id] = true
					local cell = cellByUid[it.id]
					if not cell then
						buildOtherCell(it, order, "killeffect")
					else
						updateOtherCell(it, cell, order, "killeffect")
					end
					order += 1
				end
			end
		end
		if showPoses then
			for _, it in ipairs(listFor("pose")) do
				local poseBuyable = type(it.price) == "number" and it.price > 0
				if
					passesFilter(it.rarity)
					and search:Matches(it, "pose")
					and (it.owned or (activeTab == "poses" and poseBuyable))
				then
					desiredUids[it.id] = true
					local cell = cellByUid[it.id]
					if cell and it.owned and cell:GetAttribute("PoseInteractive") ~= true then
						cell:Destroy()
						cellByUid[it.id] = nil
						cell = nil
					end
					if not cell then
						buildPoseCell(it, order)
					else
						updatePoseCell(it, cell, order)
					end
					order += 1
				end
			end
		end
		if showTitles then
			for _, it in ipairs(listFor("title")) do
				if it.owned and passesFilter(it.rarity) and search:Matches(it, "title") then
					desiredUids[it.id] = true
					local cell = cellByUid[it.id]
					if not cell then
						buildTitleCell(it, order)
					else
						updateTitleCell(it, cell, order)
					end
					order += 1
				end
			end
		end

		for uid, cell in pairs(cellByUid) do
			if not desiredUids[uid] then
				local tw = flashTweens[cell]
				if tw then
					tw:Cancel()
					flashTweens[cell] = nil
				end
				cell:Destroy()
				cellByUid[uid] = nil
			end
		end

		for key, cell in pairs(cellByUid) do
			if cell and cell.Parent then
				local seq = newItemTracker:GetSequence(key)
				if seq then
					if cell:GetAttribute("IsFavoriteKnife") ~= true then
						cell.LayoutOrder = -seq
					end
					startFlash(cell)
				else
					stopFlash(cell)
				end
			end
		end

		refreshButtons()
		if updateFilterVisuals then
			updateFilterVisuals()
		end
		gridMetrics:SyncCanvas()
	end

	local function findSearchBox()
		local searchBar = panel:WaitForChild("SearchBar", 5)
		if searchBar and searchBar:IsA("TextBox") then
			return searchBar
		end
		if searchBar then
			local box = searchBar:FindFirstChildWhichIsA("TextBox", true)
			if box then
				return box
			end
		end

		local searchContainer = panel:FindFirstChild("Search")
		if searchContainer and searchContainer:IsA("TextBox") then
			return searchContainer
		end
		if searchContainer then
			local box = searchContainer:FindFirstChildWhichIsA("TextBox", true)
			if box then
				return box
			end
		end

		return panel:FindFirstChildWhichIsA("TextBox", true)
	end

	local function setupSearchBar()
		local box = findSearchBox()
		if not box then
			warn("[InventoryController] SearchBar TextBox not found")
			return
		end

		box.Text = search:GetQuery()
		box.ClearTextOnFocus = false
		box:GetPropertyChangedSignal("Text"):Connect(function()
			search:SetQuery(box.Text)
			render()
		end)
	end

	closeBtn.MouseButton1Click:Connect(function()
		self:Close()
	end)

	local openEvent = gui:FindFirstChild("OpenInventory")
	if openEvent and openEvent:IsA("BindableEvent") then
		openEvent.Event:Connect(function()
			self:Open()
		end)
	end

	gui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if not gui.Enabled and not newItemTracker:IsEmpty() then
			newItemTracker:Clear()
			render()
		end
	end)

	equipBtn.MouseButton1Click:Connect(function()
		if selectedKind == "killeffect" or selectedKind == "pose" or selectedKind == "title" then
			onOtherEquip()
			return
		end
		local it = selectedItem()
		if not it then
			return
		end
		if it.isDefault then
			if lastState.equipped ~= nil then
				InventoryAction:FireServer("unequip")
			end
			return
		end
		if lastState.equipped == it.uid then
			InventoryAction:FireServer("unequip")
		else
			InventoryAction:FireServer("equip", it.uid)
		end
	end)

	local sellFlow = SellFlow.new({
		player = player,
		playerGui = pg,
		confirmGui = confirmGui,
		confirmQuestion = confirmQuestion,
		confirmAccept = confirmAccept,
		confirmDecline = confirmDecline,
		inventoryAction = InventoryAction,
		knifeSkins = KnifeSkinManager,
		sounds = UISounds,
		tweenController = TweenController,
		userInput = UserInputService,
		onBeforeSell = function(uid)
			for index, item in ipairs(visibleItems()) do
				if item.uid == uid then
					reselectIndex = index
					break
				end
			end
			if selectedUid == uid then
				selectedUid = nil
			end
		end,
	})

	notifyWarn = function(text)
		sellFlow:Warn(text)
	end

	attemptBuyPose = function(item)
		sellFlow:BuyPose(item)
	end

	sellBtn.MouseButton1Click:Connect(function()
		if selectedKind == "knife" then
			sellFlow:Prompt(selectedItem(), lastState.equipped)
		end
	end)

	InventoryUpdate.OnClientEvent:Connect(function(state)
		if type(state) ~= "table" then
			return
		end
		lastState = state
		newItemTracker:Update(state)

		if reselectIndex then
			local vis = visibleItems()
			selectedKind = "knife"
			if #vis > 0 then
				local pick = math.min(reselectIndex, #vis)
				selectedUid = vis[pick].uid
			else
				selectedUid = DEFAULT_UID
			end
			reselectIndex = nil
		end

		local stillExists = (selectedUid == DEFAULT_UID)
		for _, it in ipairs(state.items) do
			if it.uid == selectedUid then
				stillExists = true
				break
			end
		end
		if not stillExists then
			selectedUid = nil
		end
		render()
	end)

	InventoryAction:FireServer("request")

	UISounds.bindButton(equipBtn)
	UISounds.bindButton(confirmAccept)
	UISounds.bindButton(confirmDecline)
	UISounds.bindButton(sellBtn)
	UISounds.bindButton(closeBtn)

	local tabBar
	local function setActiveTab(tab)
		if activeTab == tab then
			return
		end
		activeTab = tab
		otherSelectedId = nil
		selectedUid = nil
		selectedKind = nil
		rarityFilter = nil
		tabsFrame.Visible = true
		render()
	end

	tabBar = TabBar.new({
		tabsFrame = tabsFrame,
		gui = gui,
		rarityNames = RARITY_TABS,
		categoryButtons = {
			all = allTabBtn,
			knives = knivesTab,
			killeffects = killEffectsTab,
			poses = posesTab,
			titles = titlesTab,
		},
		tweenController = TweenController,
		sounds = UISounds,
		getActiveTab = function()
			return activeTab
		end,
		setActiveTab = setActiveTab,
		getRarity = function()
			return rarityFilter
		end,
		setRarity = function(rarity)
			rarityFilter = rarity
		end,
		render = render,
	})
	self._tabBar = tabBar
	updateFilterVisuals = function()
		tabBar:RefreshFilters()
	end
	tabBar:Start()

	setupSearchBar()
	render()
	gridMetrics:SyncCanvas()
	print("[InventoryController] ready")
end

return InventoryController
