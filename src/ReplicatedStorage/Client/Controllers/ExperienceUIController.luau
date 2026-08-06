--!strict
-- @author Velumix
-- @version 0.0.1
-- A lightweight, event-driven player shell for the reusable baseline.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Modules.Knit) :: any
local Trove = require(ReplicatedStorage.Modules.Trove)

local Controller = Knit.CreateController({ Name = "ExperienceUIController" })
Controller._trove = Trove.new()
Controller._refs = {} :: { [string]: GuiObject }
Controller._menuOpen = false
Controller._activePage = "Inventory"
Controller._data = {} :: { [any]: any }
Controller._toastVersion = 0

local C = {
	Canvas = Color3.fromRGB(9, 12, 20),
	Surface = Color3.fromRGB(20, 25, 38),
	Raised = Color3.fromRGB(30, 37, 54),
	Accent = Color3.fromRGB(95, 214, 180),
	Accent2 = Color3.fromRGB(121, 140, 255),
	Text = Color3.fromRGB(244, 247, 255),
	Muted = Color3.fromRGB(164, 175, 198),
	Danger = Color3.fromRGB(255, 112, 128),
}

local function create(className: string, props: { [any]: any }?, children: { Instance }?): any
	local object = Instance.new(className)
	if props then
		for key, value in pairs(props) do
			if key ~= "Parent" then
				(object :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in ipairs(children) do
			child.Parent = object
		end
	end
	if props and props.Parent then
		object.Parent = props.Parent
	end
	return object
end

local function corner(radius: number): UICorner
	return create("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function stroke(color: Color3?, transparency: number?): UIStroke
	return create("UIStroke", {
		Color = color or Color3.fromRGB(255, 255, 255),
		Transparency = transparency or 0.86,
		Thickness = 1,
	})
end

local function formatNumber(value: any): string
	local number = tonumber(value) or 0
	if number >= 1e9 then
		return string.format("%.1fB", number / 1e9)
	elseif number >= 1e6 then
		return string.format("%.1fM", number / 1e6)
	elseif number >= 1e3 then
		return string.format("%.1fK", number / 1e3)
	end
	return tostring(math.floor(number))
end

function Controller:_remember(name: string, object: GuiObject): GuiObject
	self._refs[name] = object
	return object
end

function Controller:_text(parent: Instance, text: string, size: number, muted: boolean?): TextLabel
	return create("TextLabel", {
		Parent = parent,
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Text = text,
		TextColor3 = if muted then C.Muted else C.Text,
		TextSize = size,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutomaticSize = Enum.AutomaticSize.XY,
	})
end

function Controller:_button(parent: Instance, name: string, text: string): TextButton
	local button = create("TextButton", {
		Parent = parent,
		Name = name,
		AutoButtonColor = false,
		BackgroundColor3 = C.Raised,
		Size = UDim2.fromOffset(132, 44),
		Font = Enum.Font.GothamBold,
		Text = text,
		TextColor3 = C.Text,
		TextSize = 14,
	}, { corner(12), stroke() })
	-- Page buttons own these connections; destroying a lazy page disconnects them.
	button.MouseEnter:Connect(function()
		button.BackgroundColor3 = C.Accent2
	end)
	button.MouseLeave:Connect(function()
		button.BackgroundColor3 = C.Raised
	end)
	return button
end

function Controller:_buildMetric(parent: Instance, name: string, label: string, color: Color3): Frame
	local card = create("Frame", {
		Parent = parent,
		BackgroundColor3 = C.Surface,
		Size = UDim2.fromOffset(126, 58),
	}, { corner(14), stroke() })
	create("Frame", {
		Parent = card,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(12, 13),
		Size = UDim2.fromOffset(4, 32),
	}, { corner(3) })
	local caption = self:_text(card, string.upper(label), 10, true)
	caption.Position = UDim2.fromOffset(25, 10)
	local value = self:_text(card, "—", 19)
	value.Font = Enum.Font.GothamBold
	value.Position = UDim2.fromOffset(25, 26)
	self:_remember(name, value)
	return card
end

function Controller:_build()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = create("ScreenGui", {
		Parent = playerGui,
		Name = "ExperienceUI",
		DisplayOrder = 20,
		IgnoreGuiInset = false,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	self._trove:Add(gui)

	local hud = create("Frame", {
		Parent = gui,
		Name = "HUD",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 18),
		Size = UDim2.new(1, -36, 0, 62),
	})
	local metrics = create("Frame", {
		Parent = hud,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 58),
	}, { create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }) })
	self:_buildMetric(metrics, "Coins", "Coins", C.Accent)
	self:_buildMetric(metrics, "Points", "Points", C.Accent2)
	self:_buildMetric(metrics, "Level", "Level", Color3.fromRGB(255, 192, 92))

	local menuButton = self:_button(hud, "MenuButton", "MENU   M")
	menuButton.AnchorPoint = Vector2.new(1, 0)
	menuButton.Position = UDim2.new(1, 0, 0, 7)
	menuButton.Size = UDim2.fromOffset(118, 46)

	local xp = create("Frame", {
		Parent = hud,
		BackgroundColor3 = C.Surface,
		Position = UDim2.fromOffset(0, 66),
		Size = UDim2.fromOffset(394, 8),
	}, { corner(4) })
	self:_remember("ExperienceTrack", xp)
	self:_remember(
		"ExperienceFill",
		create("Frame", {
			Parent = xp,
			BackgroundColor3 = C.Accent2,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(0, 1),
		}, { corner(4) })
	)

	local shade = create("TextButton", {
		Parent = gui,
		Name = "Shade",
		Visible = false,
		AutoButtonColor = false,
		BackgroundColor3 = C.Canvas,
		BackgroundTransparency = 0.28,
		Size = UDim2.fromScale(1, 1),
		Text = "",
	})
	self:_remember("Shade", shade)
	local panel = create("Frame", {
		Parent = shade,
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = C.Surface,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(720, 440),
	}, { corner(20), stroke() })
	self:_remember("Panel", panel)

	local title = self:_text(panel, "YOUR SPACE", 22)
	title.Font = Enum.Font.GothamBold
	title.Position = UDim2.fromOffset(24, 22)
	local hint = self:_text(panel, "Inventory and preferences, without leaving the action.", 12, true)
	hint.Position = UDim2.fromOffset(24, 51)

	local tabs = create("Frame", {
		Parent = panel,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(24, 88),
		Size = UDim2.fromOffset(150, 320),
	}, { create("UIListLayout", { Padding = UDim.new(0, 10) }) })
	local inventoryTab = self:_button(tabs, "InventoryTab", "INVENTORY   I")
	local settingsTab = self:_button(tabs, "SettingsTab", "SETTINGS")

	local content = create("Frame", {
		Parent = panel,
		BackgroundColor3 = C.Canvas,
		Position = UDim2.fromOffset(190, 88),
		Size = UDim2.new(1, -214, 1, -112),
	}, { corner(14), stroke() })
	self:_remember("Content", content)

	local toast = create("TextLabel", {
		Parent = gui,
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = C.Raised,
		Position = UDim2.new(0.5, 0, 1, 40),
		Size = UDim2.fromOffset(0, 48),
		Font = Enum.Font.GothamBold,
		Text = "",
		TextColor3 = C.Text,
		TextSize = 14,
	}, { corner(14), stroke(), create("UIPadding", { PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 20) }) })
	self:_remember("Toast", toast)

	local loading = create("Frame", {
		Parent = gui,
		Name = "Loading",
		BackgroundColor3 = C.Canvas,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 20,
	})
	local loadingText = self:_text(loading, "SYNCING YOUR PROFILE…", 18)
	loadingText.AnchorPoint = Vector2.new(0.5, 0.5)
	loadingText.Position = UDim2.fromScale(0.5, 0.5)
	loadingText.ZIndex = 21
	self:_remember("Loading", loading)

	self._trove:Connect(menuButton.Activated, function()
		self:_setMenu(not self._menuOpen)
	end)
	self._trove:Connect(shade.Activated, function(input)
		if
			input.UserInputType ~= Enum.UserInputType.MouseButton1
			or UserInputService:GetMouseLocation().X < panel.AbsolutePosition.X
		then
			self:_setMenu(false)
		end
	end)
	self._trove:Connect(inventoryTab.Activated, function()
		self:_showPage("Inventory")
	end)
	self._trove:Connect(settingsTab.Activated, function()
		self:_showPage("Settings")
	end)
end

function Controller:_clearContent()
	local content = self._refs.Content
	for _, child in ipairs(content:GetChildren()) do
		if not child:IsA("UICorner") and not child:IsA("UIStroke") then
			child:Destroy()
		end
	end
end

function Controller:_showPage(page: string)
	self._activePage = page
	self:_clearContent()
	local content = self._refs.Content
	local heading = self:_text(content, page, 20)
	heading.Font = Enum.Font.GothamBold
	heading.Position = UDim2.fromOffset(20, 18)
	if page == "Inventory" then
		local inventory = self._data.Inventory or {}
		local list = create("ScrollingFrame", {
			Parent = content,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(),
			Position = UDim2.fromOffset(20, 56),
			ScrollBarThickness = 3,
			Size = UDim2.new(1, -40, 1, -74),
		}, { create("UIListLayout", { Padding = UDim.new(0, 8) }) })
		local count = 0
		for itemId, amount in pairs(inventory) do
			count += 1
			local row = create(
				"Frame",
				{ Parent = list, BackgroundColor3 = C.Raised, Size = UDim2.new(1, -4, 0, 48) },
				{ corner(10) }
			)
			local label = self:_text(row, tostring(itemId), 14)
			label.Position = UDim2.fromOffset(14, 15)
			local value = self:_text(row, "×" .. formatNumber(amount), 14, true)
			value.AnchorPoint = Vector2.new(1, 0)
			value.Position = UDim2.new(1, -14, 0, 15)
		end
		if count == 0 then
			local empty = self:_text(content, "Nothing here yet. Your next find will appear automatically.", 13, true)
			empty.Position = UDim2.fromOffset(20, 64)
		end
	else
		local settings = self._data.Settings or {}
		local y = 62
		for _, setting in ipairs({ { "MusicEnabled", "Music" }, { "SfxEnabled", "Sound effects" } }) do
			local key, labelText = setting[1], setting[2]
			local row = create("Frame", {
				Parent = content,
				BackgroundColor3 = C.Raised,
				Position = UDim2.fromOffset(20, y),
				Size = UDim2.new(1, -40, 0, 58),
			}, { corner(12) })
			local label = self:_text(row, labelText, 14)
			label.Position = UDim2.fromOffset(14, 19)
			local toggle = self:_button(row, key, if settings[key] ~= false then "ON" else "OFF")
			toggle.AnchorPoint = Vector2.new(1, 0.5)
			toggle.Position = UDim2.new(1, -9, 0.5, 0)
			toggle.Size = UDim2.fromOffset(72, 40)
			toggle.Activated:Connect(function()
				local nextValue = settings[key] == false
				settings[key] = nextValue
				toggle.Text = if nextValue then "ON" else "OFF"
				self._profileService:SetSetting(key, nextValue):catch(function(err)
					warn(err)
				end)
			end)
			y += 68
		end
	end
end

function Controller:_setMenu(open: boolean)
	self._menuOpen = open
	self._refs.Shade.Visible = open
	if open then
		self:_showPage(self._activePage)
		GuiService.SelectedObject = self._refs.Panel:FindFirstChild("InventoryTab", true) :: GuiObject?
	else
		GuiService.SelectedObject = nil
	end
end

function Controller:_toast(message: string)
	self._toastVersion += 1
	local version = self._toastVersion
	local toast = self._refs.Toast :: TextLabel
	toast.Text = message
	self._tweens:Play(
		toast,
		"ToastPosition",
		TweenInfo.new(0.22, Enum.EasingStyle.Quint),
		{ Position = UDim2.new(0.5, 0, 1, -24) },
		{ Group = "ExperienceUI" }
	)
	task.delay(2.5, function()
		if version == self._toastVersion and toast.Parent then
			self._tweens:Play(
				toast,
				"ToastPosition",
				TweenInfo.new(0.22),
				{ Position = UDim2.new(0.5, 0, 1, 40) },
				{ Group = "ExperienceUI" }
			)
		end
	end)
end

function Controller:_render(data: { [any]: any })
	self._data = data
	local coins = self._refs.Coins :: TextLabel
	local points = self._refs.Points :: TextLabel
	local level = self._refs.Level :: TextLabel
	coins.Text = formatNumber(data.Coins)
	points.Text = formatNumber(data.Points)
	level.Text = formatNumber(data.Level)
	local progress = math.clamp((tonumber(data.Experience) or 0) / 100, 0, 1)
	self._refs.ExperienceFill.Size = UDim2.fromScale(progress, 1)
	self._refs.Loading.Visible = false
	if self._menuOpen then
		self:_showPage(self._activePage)
	end
end

function Controller:_adapt()
	local small = GuiService.ViewportDisplaySize == Enum.DisplaySize.Small
	local panel = self._refs.Panel
	panel.Size = if small then UDim2.new(1, -24, 1, -110) else UDim2.fromOffset(720, 440)
	for _, name in ipairs({ "Coins", "Points", "Level" }) do
		local card = self._refs[name].Parent :: Frame
		card.Size = if small then UDim2.fromOffset(94, 58) else UDim2.fromOffset(126, 58)
	end
	self._refs.ExperienceTrack.Size = if small then UDim2.fromOffset(298, 8) else UDim2.fromOffset(394, 8)
end

function Controller:KnitStart()
	self._tweens = Knit.GetController("TweenController")
	self:_build()
	self:_adapt()
	local profile = Knit.GetController("ProfileController")
	self._profileService = Knit.GetService("PlayerDataService")
	self._trove:Add(profile.Loaded:Connect(function(data)
		self:_render(data)
	end))
	self._trove:Add(profile.BatchChanged:Connect(function(patches, data)
		for _, patch in ipairs(patches) do
			if patch.Path == "Level" then
				self:_toast("LEVEL UP  •  " .. formatNumber(patch.Value))
			end
		end
		self:_render(data)
	end))
	self._trove:Add(profile.StateChanged:Connect(function(state, detail)
		if state == "Failed" then
			local loading = self._refs.Loading
			local label = loading:FindFirstChildWhichIsA("TextLabel")
			if label then
				label.Text = "PROFILE UNAVAILABLE  •  " .. tostring(detail or "Please rejoin")
			end
		end
	end))
	self._trove:Connect(UserInputService.InputBegan, function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.M or input.KeyCode == Enum.KeyCode.ButtonSelect then
			self:_setMenu(not self._menuOpen)
		elseif input.KeyCode == Enum.KeyCode.I then
			self._activePage = "Inventory"
			self:_setMenu(true)
		elseif input.KeyCode == Enum.KeyCode.Escape and self._menuOpen then
			self:_setMenu(false)
		end
	end)
	self._trove:Connect(GuiService:GetPropertyChangedSignal("ViewportDisplaySize"), function()
		self:_adapt()
	end)
	if profile:IsLoaded() then
		self:_render(profile:GetData())
	end
end

function Controller:Destroy()
	self._trove:Clean()
end

return Controller
