-- Services // Modules
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local UIFolder = Modules:WaitForChild("UI")
local UIComponents = UIFolder:WaitForChild("Components")

local Mince = require(Modules.Mince)
local Signal = require(Modules.Signal)
local CardStack = require(script.CardStack)

local InterfaceHandler = {
	Name = "InterfaceHandler",
	LoadOrder = -1000,
	TargetScreenSize = Vector2.new(1689, 992),
	ScalingSampleMode = "Y",

	PlayerGui = PlayerGui,
	VerticalOffset = 0,
	HiddenOffset = -1,

	TweenStyles = {
		InTweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
		OutTweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
	},

	DefaultStack = CardStack.new(),
	CardStack = CardStack,

	Sections = {"Tools", "PushPop"},
	Classes = {"Button", "Slider", "Hover", "UIControl", "ScreenConfiguration", "ScreenDownAnimation"},

	ScreenConfigurations = {},

	ScreenSizeChanged = Signal.new(),
	ScreenShown = Signal.new(),

	UIComponentOrder = {
		"Notification",
		"AreaAnnouncement",
		"DirectionalMarker",
		"PlacementButton",
		"RecipeSelector",
		"ExhibitViewer",
		"ElevatorScreen",
		"CurrencyBalance",
		"OxygenBalance",
		"HealthBalance",
		"QualitySelector",
		"Achievements",
		"Encyclopedia",
		"Settings",
		"Shop",
		"Store",
		"StarterPack",
		"SideMenu",
		"CameraAngles",
		"JukeboxInterface",
		"TipjarScreen",
		"EventBoard",
	},

	UI = {
		Loaded = false,
		LoadedSignal = Signal.new(),
		ScreenShown = nil,
		Components = {},
		Aliases = {},
	},

	Initialized = false,
}

InterfaceHandler.UI.ScreenShown = InterfaceHandler.ScreenShown

local UI_ALIAS_BINDINGS = {
	AnnounceArea = {"AreaAnnouncement", "Show"},
	HideAreaAnnouncement = {"AreaAnnouncement", "Hide"},
	ShowRecipeSelector = {"RecipeSelector", "Show"},
	HideRecipeSelector = {"RecipeSelector", "Hide"},
	CreatePlacementButton = {"PlacementButton", "Show"},
	HidePlacementButton = {"PlacementButton", "Hide"},
	ShowExhibitExitButton = {"ExhibitViewer", "ShowExitButton"},
	HideExhibitExitButton = {"ExhibitViewer", "HideExitButton"},
	FadeExhibitIn = {"ExhibitViewer", "FadeIn"},
	FadeExhibitOut = {"ExhibitViewer", "FadeOut"},
	IsExhibitViewerVisible = {"ExhibitViewer", "IsVisible"},
	ShowElevatorScreen = {"ElevatorScreen", "Show"},
	HideElevatorScreen = {"ElevatorScreen", "Hide"},
	IsElevatorScreenVisible = {"ElevatorScreen", "IsVisible"},
}

-- Get a new UIControl
function InterfaceHandler:Get(...)
	return InterfaceHandler.UIControl.new(...)
end

function InterfaceHandler.UI:Get(...)
	return InterfaceHandler:Get(...)
end

-- Fetch a ScreenGui if it exists
function InterfaceHandler:GetScreenGui(UIName, ForceWait)
	local ScreenConfiguration = InterfaceHandler.ScreenConfigurations[UIName]
	if ScreenConfiguration then
		return ScreenConfiguration.ScreenGui
	end

	warn(`UI by the name of  '{UIName}' may not exist..`)

	if ForceWait then 
		return PlayerGui:WaitForChild(UIName)
	end

	if StarterGui:FindFirstChild(UIName) then
		return PlayerGui:WaitForChild(UIName)
	end

	local ThisScreenGui = PlayerGui:FindFirstChild(UIName) 
	assert(ThisScreenGui, `Failed to retrive the PlayerGui in '{UIName}'.`) ; return ThisScreenGui
end

function InterfaceHandler:LoadScreenGui(ScreenGui : ScreenGui)
	local ScreenConfiguration = InterfaceHandler:NewScreenConfiguration(ScreenGui)
	InterfaceHandler.ScreenConfigurations[ScreenGui] = ScreenConfiguration
	if not InterfaceHandler.ScreenConfigurations[ScreenGui.Name] then
		InterfaceHandler.ScreenConfigurations[ScreenGui.Name] = ScreenConfiguration
	end
end

function InterfaceHandler:_setCoreGuiDefaults()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)
end

function InterfaceHandler:_registerUIComponent(name: string, component)
	local ui = InterfaceHandler.UI
	if ui[name] then
		return ui[name]
	end

	ui.Components[name] = component
	ui[name] = component
	return component
end

function InterfaceHandler:_callUIComponent(componentName: string, methodName: string, ...)
	local component = InterfaceHandler.UI.Components[componentName]
	if not component then
		error(`[InterfaceHandler] UI component '{componentName}' is not registered.`)
	end

	local method = component[methodName]
	if typeof(method) ~= "function" then
		error(`[InterfaceHandler] UI component '{componentName}' has no method '{methodName}'.`)
	end

	return method(...)
end

function InterfaceHandler:_bindUIAliases()
	local ui = InterfaceHandler.UI
	for aliasName, binding in pairs(UI_ALIAS_BINDINGS) do
		if ui.Aliases[aliasName] then
			continue
		end

		local componentName = binding[1]
		local methodName = binding[2]
		ui[aliasName] = function(...)
			return InterfaceHandler:_callUIComponent(componentName, methodName, ...)
		end
		ui.Aliases[aliasName] = binding
	end
end

function InterfaceHandler:LoadUIComponents()
	local ui = InterfaceHandler.UI
	if ui.Loaded then
		return ui
	end

	InterfaceHandler:_setCoreGuiDefaults()

	local initialized = {}
	for _, componentName in ipairs(InterfaceHandler.UIComponentOrder) do
		local componentScript = UIComponents:FindFirstChild(componentName)
		if not componentScript or not componentScript:IsA("ModuleScript") then
			warn("[InterfaceHandler] UI component missing:", componentName)
			continue
		end

		local success, result = pcall(require, componentScript)
		if not success then
			warn("[InterfaceHandler] Failed to load UI component:", componentName, result)
			continue
		end

		InterfaceHandler:_registerUIComponent(componentName, result)
		if typeof(result) == "table" and result.Init then
			table.insert(initialized, result)
		end
	end

	for _, componentScript in ipairs(UIComponents:GetChildren()) do
		if not componentScript:IsA("ModuleScript") or ui[componentScript.Name] then
			continue
		end

		local success, result = pcall(require, componentScript)
		if not success then
			warn("[InterfaceHandler] Failed to load UI component:", componentScript.Name, result)
			continue
		end

		InterfaceHandler:_registerUIComponent(componentScript.Name, result)
		if typeof(result) == "table" and result.Init then
			table.insert(initialized, result)
		end
	end

	InterfaceHandler:_bindUIAliases()

	ui.Loaded = true
	ui.LoadedSignal:Fire()

	for _, component in ipairs(initialized) do
		task.spawn(component.Init, ui)
	end

	return ui
end

function InterfaceHandler:GetUI()
	return InterfaceHandler.UI
end

function InterfaceHandler:CallUI(componentName: string, methodName: string, ...)
	InterfaceHandler:LoadUIComponents()
	return InterfaceHandler:_callUIComponent(componentName, methodName, ...)
end

function InterfaceHandler.UI.WaitUntilLoaded()
	if not InterfaceHandler.UI.Loaded then
		InterfaceHandler.UI.LoadedSignal:Wait()
	end
end

function InterfaceHandler.UI.Call(componentName: string, methodName: string, ...)
	return InterfaceHandler:CallUI(componentName, methodName, ...)
end

function InterfaceHandler.UI.Notify(message: string, kindOrConfig: any?, timeout: number?)
	local ui = InterfaceHandler.UI
	if typeof(kindOrConfig) == "table" then
		local config = table.clone(kindOrConfig)
		config.Message = config.Message or message
		config.Type = config.Type or "Info"
		return ui.Notification.Show(config)
	end

	local kind = kindOrConfig or "Info"
	local notifyFn = ui.Notification and ui.Notification[kind]
	if notifyFn then
		return notifyFn(message, timeout)
	end

	warn("Unknown notification kind:", kind)
	return nil
end

function InterfaceHandler.UI.ShowDaily(config)
	if InterfaceHandler.UI.DailyRewards then
		InterfaceHandler.UI.DailyRewards:Show(config)
	end
end

function InterfaceHandler.UI.UpdateDaily(config)
	if InterfaceHandler.UI.DailyRewards then
		InterfaceHandler.UI.DailyRewards:Update(config)
	end
end

function InterfaceHandler.UI.HideDaily()
	if InterfaceHandler.UI.DailyRewards then
		InterfaceHandler.UI.DailyRewards:Hide()
	end
end

function InterfaceHandler.UI.ShowQualityPrompt()
	local qualityScreen = InterfaceHandler.UI.QualityScreen or InterfaceHandler.UI.QualitySelector
	if qualityScreen and qualityScreen.Show then
		qualityScreen:Show()
	end
end

function InterfaceHandler.UI.HideQualityPrompt()
	local qualityScreen = InterfaceHandler.UI.QualityScreen or InterfaceHandler.UI.QualitySelector
	if qualityScreen and qualityScreen.Hide then
		qualityScreen:Hide()
	end
end

function InterfaceHandler.UI.ShowEncyclopediaDiscovery(discoveryType: string, discoveryId: string)
	InterfaceHandler.UI.Notify("New discovery recorded! Check your Encyclopedia!", "Success", 5)
	task.wait(1)
	InterfaceHandler.UI.Notify("Open the menu and select Encyclopedia to view your discovery!", "Info", 5)
end

function InterfaceHandler.UI.HighlightEncyclopediaEntry(entryId: string)
	InterfaceHandler.UI.Notify("Check out your new encyclopedia entry!", "Info", 4)
end

function InterfaceHandler:Setup()
	if InterfaceHandler.Initialized then
		return
	end
	InterfaceHandler.Initialized = true

	for _, SectionName in InterfaceHandler.Sections do
		local Section = require(script[SectionName])
		if Section.Register then Section.Register(InterfaceHandler) end
		InterfaceHandler[SectionName] = Section
	end

	for _, ClassName in InterfaceHandler.Classes do
		local Class = require(script[ClassName])
		if Class.Register then Class.Register(InterfaceHandler) end
		InterfaceHandler[`New{ClassName}`] = function(_, ...)  return Class.new(...) end
		InterfaceHandler[ClassName] = Class
		if Class.Register then
			Class.Register(InterfaceHandler)
		end
	end

	for _,Child in PlayerGui:GetChildren() do
		if not Child:IsA("ScreenGui") then continue end
		InterfaceHandler:LoadScreenGui(Child)
	end

	PlayerGui.ChildAdded:Connect(function(Child)
		if not Child:IsA("ScreenGui") then return end
		InterfaceHandler:LoadScreenGui(Child)
	end)

	local ScreenGui = Instance.new("ScreenGui", PlayerGui)
	ScreenGui.ResetOnSpawn = false
	ScreenGui.Name = "InterfaceHandlerHost"

	ScreenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		InterfaceHandler.ScreenSizeChanged:Fire()
	end)

	InterfaceHandler.ScreeenGui = ScreenGui
end

function InterfaceHandler:GameStart()
	if not InterfaceHandler.Initialized then
		InterfaceHandler:Setup()
	end

	InterfaceHandler:LoadUIComponents()
	_G.UI = InterfaceHandler.UI
end

return InterfaceHandler
