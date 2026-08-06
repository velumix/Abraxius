local UIColors = require(game.ReplicatedStorage.Modules.UI.UIColors)

type PropertyTable = {[string]: any}

type CornerTable = {
	Radius: UDim?,
	CornerRadius: UDim?,
}

type StrokeTable = {
	Color: Color3?,
	Thickness: number?,
	Transparency: number?,
	ApplyStrokeMode: Enum.ApplyStrokeMode?,
	LineJoinMode: Enum.LineJoinMode?,
	Enabled: boolean?,
}

type GradientTable = {
	Color: ColorSequence?,
	ColorSequence: ColorSequence?,
	Rotation: number?,
	Transparency: NumberSequence?,
}

type PaddingTable = {
	PaddingTop: UDim?,
	PaddingBottom: UDim?,
	PaddingLeft: UDim?,
	PaddingRight: UDim?,
}

type SizeConstraintTable = {
	MinSize: Vector2?,
	MaxSize: Vector2?,
}

type Decorators = {
	Corner: UDim | CornerTable?,
	Stroke: Color3 | StrokeTable?,
	Gradient: ColorSequence | GradientTable?,
	Padding: PaddingTable?,
	SizeConstraint: SizeConstraintTable?,
	CornerInstance: UICorner?,
	StrokeInstance: UIStroke?,
	GradientInstance: UIGradient?,
	PaddingInstance: UIPadding?,
	SizeConstraintInstance: UISizeConstraint?,
}

type ButtonStateColors = {
	Default: Color3?,
	Hover: Color3?,
	Pressed: Color3?,
}

type SidebarComponents = {
	Gui: ScreenGui,
	Root: Frame,
	Shadow: Frame,
	Container: Frame,
	Header: Frame?,
	HeaderFix: Frame?,
	TitleLabel: TextLabel?,
	CloseButton: TextButton?,
	Scale: UIScale,
}

export type UIFactory = {
	createFrame: (Instance?, PropertyTable?, Decorators?) -> Frame,
	createTextLabel: (Instance?, PropertyTable?, Decorators?) -> TextLabel,
	createImageLabel: (Instance?, PropertyTable?, Decorators?) -> ImageLabel,
	createTextButton: (Instance?, PropertyTable?, Decorators?) -> TextButton,
	createScrollingFrame: (Instance?, PropertyTable?, Decorators?) -> ScrollingFrame,
	createUIListLayout: (Instance?, PropertyTable?) -> UIListLayout,
	createUIPadding: (Instance?, PropertyTable?) -> UIPadding,
	createUITweenScale: (Instance?, PropertyTable?) -> UIScale,
	applyButtonStates: (TextButton?, ButtonStateColors?) -> {RBXScriptConnection},
	createSidebar: (Instance, {[string]: any}?) -> SidebarComponents,
	applyCorner: (GuiObject, (UDim | CornerTable)?) -> UICorner?,
	applyStroke: (GuiObject, (Color3 | StrokeTable)?) -> UIStroke?,
	applyGradient: (GuiObject, (Color3 | GradientTable)?) -> UIGradient?,
	applyPadding: (GuiObject, PaddingTable?) -> UIPadding?,
}

local UIFactory = {} :: UIFactory

local function applyProperties(instance: Instance, props: PropertyTable?)
	if not props then
		return
	end

	for key, value in pairs(props) do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
end

local function applyCorner(instance: GuiObject, config: (UDim | CornerTable)?): UICorner?
	if not config then
		return nil
	end

	local corner = Instance.new("UICorner")
	if typeof(config) == "UDim" then
		corner.CornerRadius = config
	else
		corner.CornerRadius = config.Radius or config.CornerRadius or UDim.new(0, 12)
	end
	corner.Parent = instance
	return corner
end

local function applyStroke(instance: GuiObject, config: (Color3 | StrokeTable)?): UIStroke?
	if not config then
		return nil
	end

	local stroke = Instance.new("UIStroke")
	if typeof(config) == "Color3" then
		stroke.Color = config
	else
		stroke.Color = config.Color or stroke.Color
		stroke.Thickness = config.Thickness or stroke.Thickness
		stroke.Transparency = config.Transparency or stroke.Transparency
		stroke.ApplyStrokeMode = config.ApplyStrokeMode or stroke.ApplyStrokeMode
		stroke.LineJoinMode = config.LineJoinMode or stroke.LineJoinMode
		stroke.Enabled = if config.Enabled == nil then stroke.Enabled else config.Enabled
	end
	stroke.Parent = instance
	return stroke
end

local function applyGradient(instance: GuiObject, config: (ColorSequence | GradientTable)?): UIGradient?
	if not config then
		return nil
	end

	local gradient = Instance.new("UIGradient")
	if typeof(config) == "ColorSequence" then
		gradient.Color = config
	else
		gradient.Color = config.Color or config.ColorSequence or gradient.Color
		gradient.Rotation = config.Rotation or gradient.Rotation
		gradient.Transparency = config.Transparency or gradient.Transparency
	end
	gradient.Parent = instance
	return gradient
end

local function applyPadding(instance: GuiObject, config: PaddingTable?): UIPadding?
	if not config then
		return nil
	end

	local padding = Instance.new("UIPadding")
	for key, value in pairs(config) do
		padding[key] = value
	end
	padding.Parent = instance
	return padding
end

local function applySizeConstraint(instance: GuiObject, config: SizeConstraintTable?): UISizeConstraint?
	if not config then
		return nil
	end

	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = config.MinSize or constraint.MinSize
	constraint.MaxSize = config.MaxSize or constraint.MaxSize
	constraint.Parent = instance
	return constraint
end

local function createLayout(parent: Instance?, layoutType: string, props: PropertyTable?): Instance
	local layout = Instance.new(layoutType)
	applyProperties(layout, props)
	layout.Parent = parent
	return layout
end

local function decorate(instance: GuiObject, decorators: Decorators?)
	if not decorators then
		return
	end

	if decorators.Corner then
		decorators.CornerInstance = applyCorner(instance, decorators.Corner)
	end

	if decorators.Stroke then
		decorators.StrokeInstance = applyStroke(instance, decorators.Stroke)
	end

	if decorators.Gradient then
		decorators.GradientInstance = applyGradient(instance, decorators.Gradient)
	end

	if decorators.Padding then
		decorators.PaddingInstance = applyPadding(instance, decorators.Padding)
	end

	if decorators.SizeConstraint then
		decorators.SizeConstraintInstance = applySizeConstraint(instance, decorators.SizeConstraint)
	end
end

local function createInstance(className: string, parent: Instance?, props: PropertyTable?, decorators: Decorators?): Instance
	local instance = Instance.new(className)
	applyProperties(instance, props)
	if instance:IsA("GuiObject") then
		decorate(instance, decorators)
	end
	instance.Parent = parent or props and props.Parent or instance.Parent
	return instance
end

function UIFactory.createFrame(parent: Instance?, props: PropertyTable?, decorators: Decorators?): Frame
	props = props or {}
	if props.BorderSizePixel == nil then
		props.BorderSizePixel = 0
	end
	if props.BackgroundColor3 == nil then
		props.BackgroundColor3 = UIColors.Card
	end
	return createInstance("Frame", parent, props, decorators) :: Frame
end

function UIFactory.createTextLabel(parent: Instance?, props: PropertyTable?, decorators: Decorators?): TextLabel
	props = props or {}
	if props.BorderSizePixel == nil then
		props.BorderSizePixel = 0
	end
	if props.BackgroundTransparency == nil then
		props.BackgroundTransparency = 1
	end
	if props.Font == nil then
		props.Font = Enum.Font.Gotham
	end
	if props.TextColor3 == nil then
		props.TextColor3 = UIColors.White
	end
	if props.TextSize == nil then
		props.TextSize = 14
	end
	if props.TextXAlignment == nil then
		props.TextXAlignment = Enum.TextXAlignment.Left
	end
	return createInstance("TextLabel", parent, props, decorators) :: TextLabel
end

function UIFactory.createImageLabel(parent: Instance?, props: PropertyTable?, decorators: Decorators?): ImageLabel
	props = props or {}
	if props.BorderSizePixel == nil then
		props.BorderSizePixel = 0
	end
	if props.BackgroundTransparency == nil then
		props.BackgroundTransparency = 1
	end
	return createInstance("ImageLabel", parent, props, decorators) :: ImageLabel
end

function UIFactory.createTextButton(parent: Instance?, props: PropertyTable?, decorators: Decorators?): TextButton
	props = props or {}
	if props.BorderSizePixel == nil then
		props.BorderSizePixel = 0
	end
	if props.AutoButtonColor == nil then
		props.AutoButtonColor = false
	end
	if props.BackgroundColor3 == nil then
		props.BackgroundColor3 = UIColors.Button
	end
	if props.Font == nil then
		props.Font = Enum.Font.GothamBold
	end
	if props.TextColor3 == nil then
		props.TextColor3 = UIColors.White
	end
	if props.TextSize == nil then
		props.TextSize = 14
	end
	return createInstance("TextButton", parent, props, decorators) :: TextButton
end

function UIFactory.createScrollingFrame(parent: Instance?, props: PropertyTable?, decorators: Decorators?): ScrollingFrame
	props = props or {}
	if props.BorderSizePixel == nil then
		props.BorderSizePixel = 0
	end
	if props.BackgroundColor3 == nil then
		props.BackgroundColor3 = UIColors.Card
	end
	if props.ScrollBarThickness == nil then
		props.ScrollBarThickness = 4
	end
	if props.ScrollBarImageColor3 == nil then
		props.ScrollBarImageColor3 = UIColors.Stroke
	end
	return createInstance("ScrollingFrame", parent, props, decorators) :: ScrollingFrame
end

function UIFactory.createUIListLayout(parent: Instance?, props: PropertyTable?): UIListLayout
	return createLayout(parent, "UIListLayout", props) :: UIListLayout
end

function UIFactory.createUIPadding(parent: Instance?, props: PropertyTable?): UIPadding
	return createLayout(parent, "UIPadding", props) :: UIPadding
end

function UIFactory.createUITweenScale(parent: Instance?, props: PropertyTable?): UIScale
	return createInstance("UIScale", parent, props) :: UIScale
end

function UIFactory.applyButtonStates(button: TextButton?, stateColors: ButtonStateColors?): {RBXScriptConnection}
	if not button or not stateColors then
		return {}
	end

	local defaultColor = stateColors.Default or button.BackgroundColor3
	local hoverColor = stateColors.Hover or defaultColor
	local pressedColor = stateColors.Pressed or hoverColor
	button.BackgroundColor3 = defaultColor

	local connections = {}

	if hoverColor then
		table.insert(connections, button.MouseEnter:Connect(function()
			button.BackgroundColor3 = hoverColor
		end))
		table.insert(connections, button.MouseLeave:Connect(function()
			button.BackgroundColor3 = defaultColor
		end))
	end

	if pressedColor then
		table.insert(connections, button.MouseButton1Down:Connect(function()
			button.BackgroundColor3 = pressedColor
		end))
		table.insert(connections, button.MouseButton1Up:Connect(function()
			button.BackgroundColor3 = hoverColor
		end))
	end

	return connections
end

local function shouldCreateConstraint(minSize: Vector2?, maxSize: Vector2?)
	if not minSize and not maxSize then
		return false
	end

	local defaultMin = minSize or Vector2.new(0, 0)
	local defaultMax = maxSize or Vector2.new(math.huge, math.huge)
	return defaultMin.X > 0 or defaultMin.Y > 0 or defaultMax.X < math.huge or defaultMax.Y < math.huge
end

function UIFactory.createSidebar(parent: Instance, options: {[string]: any}?): SidebarComponents
	assert(parent, "UIFactory.createSidebar requires a parent")

	local opts = options or {}
	local colors = opts.Colors or {}

	local gui = Instance.new("ScreenGui")
	gui.Name = opts.Name or "SidebarInterface"
	gui.ResetOnSpawn = opts.ResetOnSpawn or false
	gui.IgnoreGuiInset = opts.IgnoreGuiInset ~= false
	gui.DisplayOrder = opts.DisplayOrder or 0
	gui.Enabled = opts.Enabled or false
	gui.Parent = parent

	local root = Instance.new("Frame")
	root.Name = opts.RootName or "Root"
	root.AnchorPoint = opts.RootAnchorPoint or Vector2.new(1, 0)
	root.Size = opts.RootSize or UDim2.new(0.32, 0, 0.72, 0)
	root.Position = opts.RootPosition or UDim2.new(1, -24, 0.14, 0)
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Visible = false
	root.Parent = gui

	local scale = UIFactory.createUITweenScale(root, {
		Name = "Scale",
		Scale = opts.InitialScale or 0,
	})

	local minSize = opts.MinSize
	local maxSize = opts.MaxSize
	if shouldCreateConstraint(minSize, maxSize) then
		applySizeConstraint(root, {
			MinSize = minSize or Vector2.new(0, 0),
			MaxSize = maxSize or Vector2.new(math.huge, math.huge),
		})
	end

	local shadow = UIFactory.createFrame(root, {
		Name = "Shadow",
		AnchorPoint = opts.ShadowAnchorPoint or Vector2.new(1, 0),
		Size = opts.ShadowSize or UDim2.new(1, 16, 1, 16),
		Position = opts.ShadowPosition or UDim2.new(1, 10, 0, 12),
		BackgroundColor3 = colors.Shadow or UIColors.Shadow,
		BackgroundTransparency = opts.ShadowTransparency or 0.35,
		BorderSizePixel = 0,
		ZIndex = opts.ShadowZIndex or 0,
		Visible = false,
	}, {
		Corner = opts.ShadowCornerRadius or UDim.new(0, 16),
	})

	local container = UIFactory.createFrame(root, {
		Name = opts.ContainerName or "Container",
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		BackgroundColor3 = colors.Background or UIColors.BackgroundAlt,
		BackgroundTransparency = opts.ContainerBackgroundTransparency or 0,
		BorderSizePixel = 0,
		ZIndex = opts.ContainerZIndex or 1,
	}, {
		Corner = opts.ContainerCornerRadius or UDim.new(0, 12),
		Stroke = {
			Color = colors.ContainerStroke,
			Thickness = opts.ContainerStrokeThickness,
			Transparency = opts.ContainerStrokeTransparency,
		},
	})

	local header
	local headerFix
	local titleLabel
	local closeButton

	if opts.Header ~= false then
		header = UIFactory.createFrame(container, {
			Name = opts.HeaderName or "Header",
			Size = UDim2.new(1, 0, 0, opts.HeaderHeight or 64),
			BackgroundColor3 = colors.Header or UIColors.Header,
			BorderSizePixel = 0,
			ZIndex = opts.HeaderZIndex or (container.ZIndex + 1),
		}, {
			Corner = opts.HeaderCornerRadius or UDim.new(0, 12),
		})

		local fixHeight = opts.HeaderFixHeight
		if fixHeight == nil then
			fixHeight = math.clamp((opts.HeaderHeight or 64) * 0.18, 0, 12)
		end

		headerFix = UIFactory.createFrame(header, {
			Name = "HeaderFix",
			Size = UDim2.new(1, 0, 0, fixHeight),
			Position = UDim2.new(0, 0, 1, -fixHeight),
			BackgroundColor3 = header.BackgroundColor3,
			BorderSizePixel = 0,
			ZIndex = header.ZIndex,
		})

		local title = opts.Title
		if title then
			titleLabel = UIFactory.createTextLabel(header, {
				Name = title.Name or "Title",
				Size = title.Size or UDim2.new(1, -120, 0, 32),
				Position = title.Position or UDim2.new(0, 20, 0.5, -16),
				BackgroundTransparency = 1,
				Font = title.Font or Enum.Font.GothamBold,
				TextSize = title.TextSize or 26,
				TextColor3 = title.TextColor3 or UIColors.White,
				TextXAlignment = title.TextXAlignment or Enum.TextXAlignment.Left,
				TextYAlignment = title.TextYAlignment or Enum.TextYAlignment.Center,
				Text = title.Text or "",
				ZIndex = title.ZIndex or (header.ZIndex + 1),
			})
		end

		local closeConfig = opts.CloseButton
		if closeConfig ~= false then
			closeConfig = closeConfig or {}
			closeButton = UIFactory.createTextButton(header, {
				Name = closeConfig.Name or "CloseButton",
				AnchorPoint = closeConfig.AnchorPoint or Vector2.new(1, 0.5),
				Size = closeConfig.Size or UDim2.new(0, 32, 0, 32),
				Position = closeConfig.Position or UDim2.new(1, -20, 0.5, 0),
				BackgroundColor3 = closeConfig.BackgroundColor3 or UIColors.Button,
				BorderSizePixel = 0,
				Font = closeConfig.Font or Enum.Font.GothamBold,
				Text = closeConfig.Text or "✕",
				TextSize = closeConfig.TextSize or 20,
				TextColor3 = closeConfig.TextColor3 or UIColors.White,
				ZIndex = closeConfig.ZIndex or (header.ZIndex + 1),
			}, {
				Corner = closeConfig.CornerRadius or UDim.new(0, 8),
			})
		end
	end

	return {
		Gui = gui,
		Root = root,
		Shadow = shadow,
		Container = container,
		Header = header,
		HeaderFix = headerFix,
		TitleLabel = titleLabel,
		CloseButton = closeButton,
		Scale = scale,
	}
end

UIFactory.applyCorner = applyCorner
UIFactory.applyStroke = applyStroke
UIFactory.applyGradient = applyGradient
UIFactory.applyPadding = applyPadding

return UIFactory
