local TabBar = {}
TabBar.__index = TabBar

local RARITY_SELECTED_SCALE = 1.08
local RARITY_HOVER_SCALE = 1.05
local TAB_SELECTED_SCALE = 1.2
local TAB_HOVER_SCALE = 1.08

function TabBar.new(options)
	local self = setmetatable(options, TabBar)
	self.tweenInfo = options.tweenController:GetInfo(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	self.rarityButtons = {}
	self.tabButtons = {}
	self.selectedTabButton = nil
	return self
end

function TabBar:_playScale(button, scale)
	local scaleObject = button:FindFirstChildOfClass("UIScale")
	if not scaleObject then
		scaleObject = Instance.new("UIScale")
		scaleObject.Parent = button
	end
	self.tweenController:Play(scaleObject, self.tweenInfo, { Scale = scale }, "scale")
end

function TabBar:RefreshFilters()
	local selected = self.getRarity()
	for _, button in ipairs(self.rarityButtons) do
		local active = selected ~= nil and button.Name == selected
		local overlay = button:FindFirstChild("SelectedOverlay")
		if overlay then
			overlay.Visible = active
		end
		self:_playScale(button, active and RARITY_SELECTED_SCALE or 1)
	end
end

function TabBar:_filterBase(button)
	return (self.getRarity() == button.Name) and RARITY_SELECTED_SCALE or 1
end

function TabBar:_bindRarityButton(button)
	self.sounds.bindButton(button, { tween = false })
	local zParts = { { object = button, base = button.ZIndex } }
	for _, descendant in ipairs(button:GetDescendants()) do
		if descendant:IsA("GuiObject") then
			zParts[#zParts + 1] = { object = descendant, base = descendant.ZIndex }
		end
	end
	local function raise(raised)
		for _, part in ipairs(zParts) do
			part.object.ZIndex = raised and part.base + 50 or part.base
		end
	end
	button.MouseEnter:Connect(function()
		raise(true)
		self:_playScale(button, self:_filterBase(button) * RARITY_HOVER_SCALE)
	end)
	button.MouseLeave:Connect(function()
		raise(false)
		self:_playScale(button, self:_filterBase(button))
	end)
	button.MouseButton1Down:Connect(function()
		self:_playScale(button, self:_filterBase(button) * 0.96)
	end)
	button.MouseButton1Up:Connect(function()
		self:_playScale(button, self:_filterBase(button) * RARITY_HOVER_SCALE)
	end)
	button.MouseButton1Click:Connect(function()
		local rarity = if button.Name == "All" or self.getRarity() == button.Name then nil else button.Name
		self.setRarity(rarity)
		self.render()
	end)
end

function TabBar:_refreshCategories(activeButton)
	self.selectedTabButton = activeButton
	for _, button in ipairs(self.tabButtons) do
		local active = button == activeButton
		local overlay = button:FindFirstChild("SelectedOverlay")
		if overlay then
			overlay.Visible = active
		end
		self:_playScale(button, active and TAB_SELECTED_SCALE or 1)
	end
end

function TabBar:_selectCategory(name, button)
	if self.getActiveTab() == name then
		self.setRarity(nil)
		self.render()
	else
		self.setActiveTab(name)
	end
	self:_refreshCategories(button)
end

function TabBar:_bindCategory(name, button)
	if not button then
		return
	end
	self.tabButtons[#self.tabButtons + 1] = button
	self.sounds.bindButton(button, { tween = false })
	button.MouseEnter:Connect(function()
		local base = button == self.selectedTabButton and TAB_SELECTED_SCALE or 1
		self:_playScale(button, base * TAB_HOVER_SCALE)
	end)
	button.MouseLeave:Connect(function()
		self:_playScale(button, button == self.selectedTabButton and TAB_SELECTED_SCALE or 1)
	end)
	button.MouseButton1Click:Connect(function()
		self:_selectCategory(name, button)
	end)
end

function TabBar:Select(name)
	local button = self.categoryButtons[name]
	if button then
		self:_selectCategory(name, button)
	end
end

function TabBar:Start()
	for _, name in ipairs(self.rarityNames) do
		local button = self.tabsFrame:FindFirstChild(name)
		if button then
			self.rarityButtons[#self.rarityButtons + 1] = button
			self:_bindRarityButton(button)
		end
	end
	local allRarities = self.tabsFrame:FindFirstChild("All")
	if allRarities then
		self.rarityButtons[#self.rarityButtons + 1] = allRarities
		self:_bindRarityButton(allRarities)
	end

	for name, button in pairs(self.categoryButtons) do
		self:_bindCategory(name, button)
	end

	local selectEvent = self.gui:FindFirstChild("SelectInventoryTab")
	if not selectEvent then
		selectEvent = Instance.new("BindableEvent")
		selectEvent.Name = "SelectInventoryTab"
		selectEvent.Parent = self.gui
	end
	selectEvent.Event:Connect(function(name)
		self:Select(name)
	end)

	local initialButton = self.categoryButtons.all or self.categoryButtons.knives
	self:_refreshCategories(initialButton)
	self.tabsFrame.Visible = true
	self:RefreshFilters()
end

return TabBar
