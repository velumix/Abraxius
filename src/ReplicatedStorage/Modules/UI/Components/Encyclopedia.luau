local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local PlayerGui = Players.LocalPlayer.PlayerGui

local GUI = PlayerGui:WaitForChild("Encyclopedia", 20) or error("Encyclopedia GUI not found")
local Main = GUI:FindFirstChild("Main")

local Mince = require(ReplicatedStorage.Modules.Mince)
local Signal = require(ReplicatedStorage.Modules.Signal)
local Trove = require(ReplicatedStorage.Modules.Trove)
local UIColors = require(game.ReplicatedStorage.Modules.UI.UIColors)
local RarityUtil = require(ReplicatedStorage.Modules.RarityUtil)

local Controller = Mince:Get("EncyclopediaController")
local Interface = Mince:Get("InterfaceHandler")

local Encyclopedia = {}

local MAIN_SHOW_DURATION = 0.28
local MAIN_HIDE_DURATION = 0.2
local INFO_SHOW_DURATION = 0.35
local INFO_HIDE_DURATION = 0.25
local SCROLL_DURATION = 0.2
local CATEGORY_SELECT_DURATION = 0.2
local CATEGORY_DESELECT_DURATION = 0.15
local FISH_HOVER_DURATION = 0.15
local FISH_SELECT_STROKE_DURATION = 0.3
local FISH_DESELECT_STROKE_DURATION = 0.2
local FISH_SELECT_SCALE_DURATION = 0.15

local TWEEN_INFO_IN = TweenInfo.new(MAIN_SHOW_DURATION, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local TWEEN_INFO_OUT = TweenInfo.new(MAIN_HIDE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local BACKING_TWEEN_INFO_IN = TweenInfo.new(MAIN_SHOW_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local BACKING_TWEEN_INFO_OUT = TweenInfo.new(MAIN_HIDE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local INFO_TWEEN_IN = TweenInfo.new(INFO_SHOW_DURATION, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local INFO_TWEEN_OUT = TweenInfo.new(INFO_HIDE_DURATION, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
local SCROLL_TWEEN_INFO = TweenInfo.new(SCROLL_DURATION, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local CATEGORY_SELECT_TWEEN_INFO = TweenInfo.new(CATEGORY_SELECT_DURATION, Enum.EasingStyle.Quart,
    Enum.EasingDirection.Out)
local CATEGORY_DESELECT_COLOR_TWEEN_INFO = TweenInfo.new(CATEGORY_DESELECT_DURATION, Enum.EasingStyle.Quad,
    Enum.EasingDirection.Out)
local CATEGORY_DESELECT_SCALE_TWEEN_INFO = TweenInfo.new(CATEGORY_DESELECT_DURATION, Enum.EasingStyle.Quart,
    Enum.EasingDirection.Out)
local FISH_HOVER_TWEEN_INFO = TweenInfo.new(FISH_HOVER_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FISH_SELECT_STROKE_TWEEN_INFO = TweenInfo.new(FISH_SELECT_STROKE_DURATION, Enum.EasingStyle.Quint,
    Enum.EasingDirection.Out)
local FISH_DESELECT_STROKE_TWEEN_INFO = TweenInfo.new(FISH_DESELECT_STROKE_DURATION, Enum.EasingStyle.Quint,
    Enum.EasingDirection.Out)
local FISH_SCALE_TWEEN_INFO = TweenInfo.new(FISH_SELECT_SCALE_DURATION, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local ZERO_SIZE = UDim2.new(0, 0, 0, 0)
local CENTER_POSITION = UDim2.new(0.5, 0, 0.5, 0)

local CATEGORIES = { "Vertebrates", "Invertebrates", "Corals & Plants" }
local DEFAULT_CATEGORY = "Vertebrates"

local UNDISCOVERED_TEXT = "?????"
local UNDISCOVERED_SCIENTIFIC_TEXT = "????"
local NOT_DISCOVERED_CATEGORY = "Not Discovered"
local SELECTION_NONE = "None"

local CATEGORY_TO_DISCOVERY = {
    ["Corals & Plants"] = "Corals and Plants"
}

local DISCOVERY_TO_CATEGORY = {}
for categoryName, discoveryName in pairs(CATEGORY_TO_DISCOVERY) do
    DISCOVERY_TO_CATEGORY[discoveryName] = categoryName
end

local function toDiscoveryCategoryName(categoryName)
    return CATEGORY_TO_DISCOVERY[categoryName] or categoryName
end

local function toUICategoryName(discoveryType)
    return DISCOVERY_TO_CATEGORY[discoveryType] or discoveryType
end

local VIEWPORT_ROTATION_SPEED = 0.005
local VIEWPORT_ZOOM_MULTIPLIER = 1.5
local VIEWPORT_ZOOM_MIN_MULTIPLIER = 2.5
local VIEWPORT_ZOOM_MAX_MULTIPLIER = 0.5
local VIEWPORT_ZOOM_FACTOR_MULTIPLIER = 0.05
local VIEWPORT_TOUCH_SENSITIVITY = 0.003
local VIEWPORT_TOUCH_ZOOM_SENSITIVITY = 0.2
local VIEWPORT_TOUCH_ROTATION_SENSITIVITY = 0.01
local VIEWPORT_MOUSE_PAN_SENSITIVITY = 0.005
local VIEWPORT_TOUCH_PAN_SENSITIVITY = 0.0025
local VIEWPORT_INITIAL_ROTATION_X = math.rad(5)
local VIEWPORT_INITIAL_ROTATION_Y = math.rad(65)
local VIEWPORT_DEFAULT_ROTATION_Y = math.rad(30)
local VIEWPORT_ROTATION_CLAMP = math.pi / 2 - 0.1

local FACT_MAX_CHARACTERS_PER_LINE = 25

local FISH_BOX_STROKE_THICKNESS_NORMAL = 1
local FISH_BOX_STROKE_THICKNESS_HOVER = 2
local FISH_BOX_STROKE_THICKNESS_SELECTED = 3
local FISH_BOX_SCALE_OFFSET = UDim2.new(0, 4, 0, 4)
local FISH_BOX_CORNER_RADIUS = UDim.new(0, 8)

local LAST_SCANNED_PULSE_DURATION = 0.35
local LAST_SCANNED_STROKE_THICKNESS = 4
local LAST_SCANNED_COLOR_OFFSET = 40
local LAST_SCANNED_SCROLL_PADDING = 24
local AUTO_SELECT_PREVIEW_DELAY = 0.35

local categoryImages = {
    ["Vertebrates"] = "rbxassetid://126595809139502",
    ["Invertebrates"] = "rbxassetid://108397479380733",
    ["Corals & Plants"] = "rbxassetid://97022312839248",
    ["Not Discovered"] = "rbxassetid://92627976350708"
}

local SELECTED_CATEGORY_COLOR = UIColors.Selected
local DESELECTED_CATEGORY_COLOR = UIColors.Deselected
local CATEGORY_SCALE_MULTIPLIER = 1.1

local EXIT_BUTTON_HOVER_COLOR = UIColors.ExitHover
local EXIT_BUTTON_CLICK_COLOR = UIColors.ExitClick
local EXIT_BUTTON_HOVER_SCALE = 1.15
local EXIT_BUTTON_CLICK_SCALE = 0.85
local EXIT_BUTTON_HOVER_DURATION = 0.2
local EXIT_BUTTON_CLICK_DURATION = 0.1

local EXIT_BUTTON_HOVER_TWEEN_INFO = TweenInfo.new(EXIT_BUTTON_HOVER_DURATION, Enum.EasingStyle.Sine,
    Enum.EasingDirection.Out)
local EXIT_BUTTON_CLICK_TWEEN_INFO = TweenInfo.new(EXIT_BUTTON_CLICK_DURATION, Enum.EasingStyle.Sine,
    Enum.EasingDirection.InOut)

local MAIN_EXIT_BUTTON_VISIBILITY_DURATION = 0.4
local MAIN_EXIT_BUTTON_SHOW_TWEEN_INFO = TweenInfo.new(MAIN_EXIT_BUTTON_VISIBILITY_DURATION, Enum.EasingStyle.Back,
    Enum.EasingDirection.Out)
local MAIN_EXIT_BUTTON_HIDE_TWEEN_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.In)

local FISH_BOX_COLORS = {
    discovered = {
        backgroundColor = UIColors.EncyclopediaBackground,
        imageColor = UIColors.White,
        nameTextColor = UIColors.White,
        scientificTextColor = UIColors.EncyclopediaScientific,
        strokeColor = UIColors.Stroke,
        strokeColorHover = UIColors.StrokeHover,
        strokeColorSelected = UIColors.StrokeSelected
    },
    undiscovered = {
        backgroundColor = UIColors.EncyclopediaLocked,
        imageColor = UIColors.EncyclopediaLockedImage,
        nameTextColor = UIColors.EncyclopediaLockedName,
        scientificTextColor = UIColors.EncyclopediaLockedScientific,
        strokeColor = UIColors.EncyclopediaLockedStroke,
        strokeColorHover = UIColors.EncyclopediaLockedStrokeHover,
        strokeColorSelected = UIColors.EncyclopediaLockedStroke
    }
}

local originalSizes = {}
local originalPositions = {}
local originalCategorySizes = {}

local currentTweens = {}
local connectionTrove = Trove.new()
local connections = {}
local encyclopediaSystem

function Encyclopedia.CleanupTweens(...)
    local specificKeys = { ... }

    if #specificKeys > 0 then
        for _, key in ipairs(specificKeys) do
            if currentTweens[key] then
                currentTweens[key]:Cancel()
                currentTweens[key] = nil
            end
        end
    else
        for key, tween in pairs(currentTweens) do
            if tween and typeof(tween) == "Instance" then
                tween:Cancel()
            end
            currentTweens[key] = nil
        end

        currentTweens = {}
    end
end

function Encyclopedia.AddConnection(connection)
    if connection and typeof(connection) == "RBXScriptConnection" then
        table.insert(connections, connection)
        connectionTrove:Add(connection)
    end
end

local fishBoxes = {}
local categoryCache = {}
local currentCategory = "Vertebrates"

local currentSelection = nil
local pendingHoverId = nil
local isInfoContainerVisible = false
local currentFactIndex = 1
local currentFacts = {}
local lastScannedFishId = nil
local discoveryListenerSetup = false
local encyclopediaInitialized = false

local factTemplate = nil
local currentFactClones = {}

local function getBox(fishId)
    if fishId == nil then
        return nil
    end

    local entry = fishBoxes[fishId]
    if entry then
        return entry
    end

    local idString = tostring(fishId)
    entry = fishBoxes[idString]
    if entry then
        return entry
    end

    local idNumber = tonumber(fishId)
    if idNumber then
        return fishBoxes[idNumber]
    end

    return nil
end

local function getCurrentDiscoveryType()
    return toDiscoveryCategoryName(currentCategory)
end

local function isFishDiscovered(categoryName, fishId)
    if not Controller then
        return false
    end

    return Controller:HasDiscovered(toDiscoveryCategoryName(categoryName), fishId)
end

local function getCategoryData(categoryName)
    if not Controller then
        return nil
    end

    local discoveryName = toDiscoveryCategoryName(categoryName)
    if categoryCache[discoveryName] then
        return categoryCache[discoveryName]
    end

    local data = Controller:GetCategoryData(discoveryName)
    categoryCache[discoveryName] = data
    return data
end

local function requestDiscoveriesForCategory(categoryName)
    if Controller and Controller.DiscoveryManager then
        Controller.DiscoveryManager:RequestDiscoveries(toDiscoveryCategoryName(categoryName))
    end
end

local function findCategoryForFish(fishId)
    if not Controller or not fishId then
        return nil, nil
    end

    if getBox(fishId) then
        return currentCategory, getCurrentDiscoveryType()
    end

    if Controller.GetDiscoveryTypes then
        local discoveryTypes = Controller:GetDiscoveryTypes()
        for _, discoveryType in ipairs(discoveryTypes) do
            local categoryData = Controller:GetCategoryData(discoveryType)
            local fishKey = tostring(fishId)
            if categoryData and (categoryData[fishId] or categoryData[fishKey]) then
                return toUICategoryName(discoveryType), discoveryType
            end
        end
    end

    return nil, nil
end

local function selectBox(fishId, force)
    local sys = encyclopediaSystem
    if not sys or not fishId then
        return false
    end

    local entry = getBox(fishId)
    if entry and entry.data and (entry.discovered or force) then
        Encyclopedia.SelectFish(entry.data)
        return true
    end

    return false
end

local function attemptAutoSelectLastScanned()
    local sys = encyclopediaSystem
    if not sys or not lastScannedFishId then
        return false
    end

    local uiCategory, discoveryType = findCategoryForFish(lastScannedFishId)
    if not uiCategory then
        local player = Players.LocalPlayer
        if player then
            local attributeDiscoveryType = player:GetAttribute("LastScannedDiscoveryType")
            if attributeDiscoveryType then
                discoveryType = attributeDiscoveryType
                uiCategory = toUICategoryName(attributeDiscoveryType)
            end
        end
    end

    if not uiCategory then
        if discoveryType and Controller and Controller.DiscoveryManager then
            Controller.DiscoveryManager:RequestDiscoveries(discoveryType)
        end
        return false
    end

    if uiCategory ~= currentCategory then
        currentCategory = uiCategory
        sys.GUI:SetAttribute("CurrentCategory", uiCategory)
        Encyclopedia.UpdateCategoryTabs(uiCategory)
        requestDiscoveriesForCategory(uiCategory)
        Encyclopedia.LoadCategory(uiCategory)
    end

    local fishBoxEntry = getBox(lastScannedFishId)
    if not fishBoxEntry then
        local categoryData = getCategoryData(uiCategory)
        local fishKey = tostring(lastScannedFishId)
        local fishData = categoryData and (categoryData[lastScannedFishId] or categoryData[fishKey])
        if fishData then
            local isDiscovered = isFishDiscovered(uiCategory, fishData._id)
            Encyclopedia.CreateFishBox(fishData, isDiscovered)
            Encyclopedia.UpdateLayoutOrder()
            fishBoxEntry = getBox(lastScannedFishId)
        end
    end

    if fishBoxEntry and fishBoxEntry.data then
        local targetId = tostring(lastScannedFishId)
        Encyclopedia.ClearSelectionVisuals()
        Encyclopedia.ScrollToFishBox(fishBoxEntry.box)
        Encyclopedia.PulseLastScanned(fishBoxEntry)
        task.delay(AUTO_SELECT_PREVIEW_DELAY, function()
            if not sys or not fishBoxEntry or not fishBoxEntry.data then
                return
            end
            if tostring(lastScannedFishId) ~= targetId then
                return
            end
            if selectBox(targetId, true) then
                Encyclopedia.PulseLastScanned(fishBoxEntry)
            end
            if tostring(lastScannedFishId) == targetId then
                lastScannedFishId = nil
            end
        end)
        return true
    end

    return false
end

function Encyclopedia.ScrollToFishBox(fishBox)
    local sys = encyclopediaSystem
    if not sys or not sys.ScrollingFrame or not fishBox or not fishBox.Parent then
        return
    end

    local scrollingFrame = sys.ScrollingFrame
    local framePosition = scrollingFrame.AbsolutePosition
    local boxPosition = fishBox.AbsolutePosition
    local relativeY = boxPosition.Y - framePosition.Y
    local centerOffset = relativeY - (scrollingFrame.AbsoluteSize.Y - fishBox.AbsoluteSize.Y) * 0.5
    local padding = LAST_SCANNED_SCROLL_PADDING
    local targetY = centerOffset + scrollingFrame.CanvasPosition.Y - padding
    local maxY = math.max(0, scrollingFrame.AbsoluteCanvasSize.Y - scrollingFrame.AbsoluteSize.Y)
    local clampedY = math.clamp(targetY, 0, maxY)

    Encyclopedia.CleanupTweens("scrollToLastScanned")
    local scrollTween = TweenService:Create(scrollingFrame, SCROLL_TWEEN_INFO, {
        CanvasPosition = Vector2.new(scrollingFrame.CanvasPosition.X, clampedY)
    })
    currentTweens.scrollToLastScanned = scrollTween
    Encyclopedia.AddConnection(scrollTween.Completed:Connect(function()
        currentTweens.scrollToLastScanned = nil
    end))
    scrollTween:Play()
end

function Encyclopedia.PulseLastScanned(entry)
    if not entry or not entry.box then
        return
    end

    local fishBox = entry.box
    local pulseKey = "lastScannedPulse_" .. tostring(entry.data and entry.data._id or fishBox.Name)
    Encyclopedia.CleanupTweens(pulseKey)

    local originalColor = fishBox.BackgroundColor3
    local glowColor = Color3.fromRGB(
        math.min(255, originalColor.R * 255 + LAST_SCANNED_COLOR_OFFSET),
        math.min(255, originalColor.G * 255 + LAST_SCANNED_COLOR_OFFSET),
        math.min(255, originalColor.B * 255 + LAST_SCANNED_COLOR_OFFSET)
    )

    fishBox.BackgroundColor3 = glowColor
    local bgTween = TweenService:Create(fishBox,
        TweenInfo.new(LAST_SCANNED_PULSE_DURATION, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
        BackgroundColor3 = originalColor
    })
    currentTweens[pulseKey] = bgTween
    Encyclopedia.AddConnection(bgTween.Completed:Connect(function()
        if currentTweens[pulseKey] == bgTween then
            currentTweens[pulseKey] = nil
        end
    end))
    bgTween:Play()

    local stroke = fishBox:FindFirstChild("UIStroke")
    if stroke then
        local originalThickness = stroke.Thickness
        local originalTransparency = stroke.Transparency
        stroke.Transparency = 0
        local upTween = TweenService:Create(stroke,
            TweenInfo.new(LAST_SCANNED_PULSE_DURATION * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Thickness = math.max(originalThickness, LAST_SCANNED_STROKE_THICKNESS)
        })
        local downTween = TweenService:Create(stroke,
            TweenInfo.new(LAST_SCANNED_PULSE_DURATION * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Thickness = originalThickness,
            Transparency = originalTransparency
        })

        upTween.Completed:Connect(function(state)
            if state == Enum.PlaybackState.Completed then
                downTween:Play()
            end
        end)
        upTween:Play()
    end
end

local function applyHover(fishId)
    local entry = getBox(fishId)
    if not entry or not entry.box then
        return
    end

    local stroke = entry.box:FindFirstChild("UIStroke")
    if not stroke then
        return
    end

    local colors = entry.discovered and FISH_BOX_COLORS.discovered or FISH_BOX_COLORS.undiscovered
    local hoverKey = "fishHover_" .. tostring(fishId)
    Encyclopedia.CleanupTweens(hoverKey)
    local hoverTween = TweenService:Create(stroke, FISH_HOVER_TWEEN_INFO, {
        Color = colors.strokeColorHover,
        Thickness = FISH_BOX_STROKE_THICKNESS_HOVER
    })
    currentTweens[hoverKey] = hoverTween
    hoverTween:Play()
end

local function clearHover(fishId)
    local entry = getBox(fishId)
    if not entry or not entry.box then
        return
    end

    local stroke = entry.box:FindFirstChild("UIStroke")
    if not stroke then
        return
    end

    local colors = entry.discovered and FISH_BOX_COLORS.discovered or FISH_BOX_COLORS.undiscovered
    local hoverKey = "fishHover_" .. tostring(fishId)
    Encyclopedia.CleanupTweens(hoverKey)
    local leaveTween = TweenService:Create(stroke, FISH_HOVER_TWEEN_INFO, {
        Color = colors.strokeColor,
        Thickness = FISH_BOX_STROKE_THICKNESS_NORMAL
    })
    currentTweens[hoverKey] = leaveTween
    leaveTween:Play()
end


local function cleanupConnections()
    connectionTrove:Clean()
    table.clear(connections)
end

local function cleanupFactClones()
    for i = #currentFactClones, 1, -1 do
        local clone = currentFactClones[i]
        if clone then
            clone:Destroy()
            currentFactClones[i] = nil
        end
    end
    currentFactClones = {}
end

local function createFactClones(text, factContainer, maxCharactersPerLine)
    if not factTemplate or not factContainer then return {} end

    cleanupFactClones()

    local factElement = factContainer:FindFirstChild("Fact")
    if not factElement then return {} end

    local lines = {}
    if maxCharactersPerLine and #text > maxCharactersPerLine then
        local words = string.split(text, " ")
        local currentLine = ""

        for _, word in ipairs(words) do
            local testLine = currentLine == "" and word or currentLine .. " " .. word
            if #testLine <= maxCharactersPerLine then
                currentLine = testLine
            else
                if currentLine ~= "" then
                    table.insert(lines, currentLine)
                end
                currentLine = word
            end
        end

        if currentLine ~= "" then
            table.insert(lines, currentLine)
        end
    else
        table.insert(lines, text or "")
    end

    for i, lineText in ipairs(lines) do
        local clone = factTemplate:Clone()
        clone.Text = lineText
        clone.Name = "FactLine_" .. i
        clone.Parent = factElement
        table.insert(currentFactClones, clone)
    end

    return currentFactClones
end

local function buildEncyclopediaSystem()
    if encyclopediaSystem then return encyclopediaSystem end

    Encyclopedia.Register()

    local mainContainer = Main:FindFirstChild("MainContainer")
    local infoContainer = Main:FindFirstChild("InfoContainer")

    if not infoContainer then
        error("Encyclopedia: Required UI element 'InfoContainer' not found")
    end

    local topBar = mainContainer and mainContainer:FindFirstChild("TopBar")
    local searchContainer = mainContainer and mainContainer:FindFirstChild("Search")
    local fishContainer = mainContainer and mainContainer:FindFirstChild("FishContainer")
    local scrollingFrame = fishContainer and fishContainer:FindFirstChild("ScrollingFrame")
    local fishBox = scrollingFrame and scrollingFrame:FindFirstChild("FishBox")

    local categories = mainContainer and mainContainer:FindFirstChild("Categories")

    local info = infoContainer:FindFirstChild("Info")
    local infoElements = info and info:FindFirstChild("InfoElements")
    local viewportFrame = info and info:FindFirstChild("ViewportFrame")
    local depthContainer = infoElements and infoElements:FindFirstChild("DepthContainer")
    local factContainer = infoElements and infoElements:FindFirstChild("FactContainer")
    local nameElements = info:FindFirstChild("NameElements")
    local fishBoxElements = fishBox and {
        ImageLabel = fishBox:FindFirstChild("ImageLabel"),
        NameLabel = fishBox:FindFirstChild("NameLabel"),
        ScientificNameLabel = fishBox:FindFirstChild("ScientificNameLabel")
    }

    local textBox = searchContainer and searchContainer:FindFirstChild("TextBox")

    local imageButton = fishBox and fishBox:FindFirstChild("ImageButton")
    local titleFrame = infoContainer and infoContainer:FindFirstChild("Title")
    local exitButtonFrame = titleFrame and titleFrame:FindFirstChild("ExitButton")
    local infoCloseButton = exitButtonFrame and exitButtonFrame:FindFirstChild("Exit")

    local mainExitButtonFrame = topBar and topBar:FindFirstChild("ExitButton")
    local mainExitButton = mainExitButtonFrame and mainExitButtonFrame:FindFirstChild("Exit")

    local mainBacking = mainContainer and mainContainer:FindFirstChild("Backing")
    local infoBacking = infoContainer and infoContainer:FindFirstChild("Backing")

    if not originalSizes.main then
        originalSizes.main = Main.Size
        originalPositions.main = UDim2.new(0.5, 0, 0.5, 0)
    end
    if mainBacking and not originalSizes.mainBacking then
        originalSizes.mainBacking = mainBacking.Size
        originalPositions.mainBacking = UDim2.new(0.52, 0, 0.51, 0)
    end
    if infoBacking and not originalSizes.infoBacking then
        originalSizes.infoBacking = infoBacking.Size
        originalPositions.infoBacking = UDim2.new(0.506, 0, 0.508, 0)
    end

    if not factTemplate and factContainer then
        local factElement = factContainer:FindFirstChild("Fact")
        if factElement then
            local templateElement = factElement:FindFirstChild("Template")
            if templateElement then
                factTemplate = templateElement
                factTemplate.Parent = nil
            end
        end
    end

    encyclopediaSystem = {
        GUI = GUI,
        Main = Main,
        MainContainer = mainContainer,
        InfoContainer = infoContainer,
        MainBacking = mainBacking,
        InfoBacking = infoBacking,
        TopBar = topBar,
        TextBox = textBox,
        FishContainer = fishContainer,
        ScrollingFrame = scrollingFrame,
        FishBox = fishBox,
        FishBoxElements = fishBoxElements,
        ImageButton = imageButton,
        InfoCloseButton = infoCloseButton,
        MainExitButton = mainExitButton,
        Categories = categories,
        Info = info,
        InfoElements = infoElements,
        ViewportFrame = viewportFrame,
        WorldModel = viewportFrame and viewportFrame:FindFirstChild("WorldModel"),
        DepthContainer = depthContainer,
        Depth = depthContainer and depthContainer:FindFirstChild("Depth"),
        FactContainer = factContainer,
        LeftButton = (function()
            if not factContainer then return nil end
            local leftBtn = factContainer:FindFirstChild("LeftButton")
            if not leftBtn then return nil end
            if leftBtn:IsA("ImageButton") then
                return leftBtn
            else
                return leftBtn:FindFirstChildWhichIsA("ImageButton")
            end
        end)(),
        RightButton = (function()
            if not factContainer then return nil end
            local rightBtn = factContainer:FindFirstChild("RightButton")
            if not rightBtn then return nil end
            if rightBtn:IsA("ImageButton") then
                return rightBtn
            else
                return rightBtn:FindFirstChildWhichIsA("ImageButton")
            end
        end)(),
        Fact = factContainer and factContainer:FindFirstChild("Fact"),
        FamilyContainer = infoElements and infoElements:FindFirstChild("Familycontainer"),
        SizeContainer = infoElements and infoElements:FindFirstChild("SizeContainer"),
        NameElements = nameElements,
        FishName = nameElements and nameElements:FindFirstChild("FishName"),
        ScientificName = nameElements and nameElements:FindFirstChild("ScientificName"),
        Backing = infoContainer:FindFirstChild("Backing"),
        InfoContainerChild = infoContainer:FindFirstChild("InfoContainer"),
        Title = infoContainer:FindFirstChild("Title"),
        Tweens = {
            Show = {
                Main = TweenService:Create(Main, TWEEN_INFO_IN, {
                    Size = originalSizes.main,
                    Position = originalPositions.main
                }),
                MainBacking = mainBacking and TweenService:Create(mainBacking, BACKING_TWEEN_INFO_IN, {
                    Size = originalSizes.mainBacking,
                    Position = originalPositions.mainBacking
                }),
                InfoBacking = infoBacking and TweenService:Create(infoBacking, BACKING_TWEEN_INFO_IN, {
                    Size = originalSizes.infoBacking,
                    Position = originalPositions.infoBacking
                })
            },
            Hide = {
                Main = TweenService:Create(Main, TWEEN_INFO_OUT, {
                    Size = ZERO_SIZE,
                    Position = CENTER_POSITION
                }),
                MainBacking = mainBacking and TweenService:Create(mainBacking, BACKING_TWEEN_INFO_OUT, {
                    Size = ZERO_SIZE,
                    Position = CENTER_POSITION
                }),
                InfoBacking = infoBacking and TweenService:Create(infoBacking, BACKING_TWEEN_INFO_OUT, {
                    Size = ZERO_SIZE,
                    Position = CENTER_POSITION
                })
            }
        }
    }

    Encyclopedia.AddConnection(Players.LocalPlayer.AncestryChanged:Connect(function()
        if not Players.LocalPlayer.Parent then Encyclopedia.Cleanup() end
    end))

    if fishBox then
        fishBox.Parent = nil
    end

    return encyclopediaSystem
end

function Encyclopedia.InitSystem()
    if encyclopediaSystem then
        return encyclopediaSystem
    end
    return buildEncyclopediaSystem()
end

local function hasRunningTweens()
    local runningTweens = {
        "showMain", "showMainBacking", "showInfoBacking",
        "hideMain", "hideMainBacking", "hideInfoBacking"
    }

    for _, tweenKey in ipairs(runningTweens) do
        local tween = currentTweens[tweenKey]
        if tween and tween.PlaybackState == Enum.PlaybackState.Playing then
            return true
        end
    end

    for key, tween in pairs(currentTweens) do
        if tween and typeof(tween) == "Instance" and tween.PlaybackState == Enum.PlaybackState.Playing then
            return true
        end
    end

    return false
end

function Encyclopedia.SetCategory(categoryName)
    if not categoryName then
        warn("Encyclopedia: Cannot set nil category")
        return false
    end

    local sys = encyclopediaSystem
    if not sys then
        warn("Encyclopedia: System not initialized")
        return false
    end
    sys.GUI:SetAttribute("CurrentCategory", categoryName)

    return true
end

function Encyclopedia.GetCurrentCategory()
    local sys = encyclopediaSystem
    if not sys then
        return nil
    end
    return sys.GUI:GetAttribute("CurrentCategory")
end

function Encyclopedia.SetSelection(fishName)
    if not fishName then
        warn("Encyclopedia: Cannot set nil selection")
        return false
    end

    local sys = encyclopediaSystem
    if not sys then
        warn("Encyclopedia: System not initialized")
        return false
    end
    sys.GUI:SetAttribute("Selection", fishName)
    return true
end

function Encyclopedia.ClearSelection()
    local sys = encyclopediaSystem
    if not sys then
        warn("Encyclopedia: System not initialized")
        return false
    end

    currentSelection = nil
    sys.GUI:SetAttribute("Selection", SELECTION_NONE)
    Encyclopedia.UpdateFishBoxSelection()
    Encyclopedia.HideInfoContainer()
    return true
end

function Encyclopedia.ClearSelectionVisuals()
    local sys = encyclopediaSystem
    if not sys then
        return false
    end

    currentSelection = nil
    sys.GUI:SetAttribute("Selection", SELECTION_NONE)
    if pendingHoverId then
        clearHover(pendingHoverId)
        pendingHoverId = nil
    end
    Encyclopedia.UpdateFishBoxSelection()
    return true
end

function Encyclopedia.GetCurrentSelection()
    local sys = encyclopediaSystem
    if not sys then
        return nil
    end
    local selection = sys.GUI:GetAttribute("Selection")
    return selection ~= SELECTION_NONE and selection or nil
end

function Encyclopedia.GetLastScannedFishId()
    return lastScannedFishId
end

function Encyclopedia.GetFishBox(fishId)
    if not fishId then
        return nil
    end
    return getBox(fishId)
end

function Encyclopedia.GetLastScannedFishBox()
    if not lastScannedFishId then
        return nil
    end
    return getBox(lastScannedFishId)
end

function Encyclopedia.Cleanup()
    Encyclopedia.CleanupTweens()
    cleanupConnections()
    table.clear(categoryCache)

    if encyclopediaSystem and encyclopediaSystem.ViewportTrove then
        encyclopediaSystem.ViewportTrove:Destroy()
        encyclopediaSystem.ViewportTrove = nil
    end

    encyclopediaSystem = nil
end

function Encyclopedia.Dispose()
    if Encyclopedia.IsDisposed() then
        warn("Encyclopedia: Already disposed")
        return false
    end

    Encyclopedia.Cleanup()

    currentTweens = {}
    connectionTrove:Destroy()
    connectionTrove = Trove.new()
    connections = {}

    return true
end

function Encyclopedia.IsDisposed()
    return encyclopediaSystem == nil
end

local function countActive(items, checkFunction)
    local count = 0
    for _, item in pairs(items) do
        if item and checkFunction(item) then
            count = count + 1
        end
    end
    return count
end

function Encyclopedia.GetConnectionCount()
    return countActive(connections, function(conn)
        return conn.Connected
    end)
end

function Encyclopedia.GetTweenCount()
    return countActive(currentTweens, function(tween)
        return tween.PlaybackState == Enum.PlaybackState.Playing
    end)
end

function Encyclopedia.GetMemoryStatus()
    return {
        encyclopediaSystemExists = encyclopediaSystem ~= nil,
        connectionCount = #connections,
        activeConnectionCount = Encyclopedia.GetConnectionCount(),
        tweenCount = Encyclopedia.GetTweenCount(),
        runningTweenCount = hasRunningTweens() and 1 or 0,
        currentTweensKeys = function()
            local keys = {}
            for key, tween in pairs(currentTweens) do
                if tween then
                    table.insert(keys, key)
                end
            end
            return keys
        end,
        isDisposed = Encyclopedia.IsDisposed(),
        isVisible = Encyclopedia.IsVisible()
    }
end

function Encyclopedia.GetDebugInfo()
    return {
        guiEnabled = GUI.Enabled,
        mainVisible = Main.Visible,
        mainPosition = Main.Position,
        mainSize = Main.Size,
        originalMainSize = originalSizes.main,
        originalMainPosition = originalPositions.main,
        hasSystemCache = encyclopediaSystem ~= nil,
        runningTweens = hasRunningTweens(),
        currentTweens = function()
            local tweenStates = {}
            for key, tween in pairs(currentTweens) do
                if tween and typeof(tween) == "Instance" then
                    tweenStates[key] = tween.PlaybackState.Name
                end
            end
            return tweenStates
        end,
        tweenStates = function()
            local sys = encyclopediaSystem
            if sys and sys.Tweens then
                return {
                    showMainTweenState = sys.Tweens.Show.Main.PlaybackState.Name,
                    hideMainTweenState = sys.Tweens.Hide.Main.PlaybackState.Name,
                    hasMainBacking = sys.MainBacking ~= nil,
                    hasInfoBacking = sys.InfoBacking ~= nil
                }
            end
            return { error = "Cannot access system tweens" }
        end
    }
end

function Encyclopedia.InitializeInterface()
    local sys = encyclopediaSystem
    if not sys then
        sys = Encyclopedia.InitSystem()
    end
    if not sys then return end

    if not lastScannedFishId then
        local player = Players.LocalPlayer
        local attributeId = player and player:GetAttribute("LastScannedFishId")
        if attributeId then
            lastScannedFishId = tostring(attributeId)
        end
    end

    if not encyclopediaInitialized then
        Encyclopedia.ResetToDefault()
        Encyclopedia.SetupCategoryTabs()
        Encyclopedia.SetupSearch()
        Encyclopedia.SetupCloseButtons()

        if Controller and Controller.DiscoveryManager then
            requestDiscoveriesForCategory(currentCategory)
        end

        Encyclopedia.LoadCategory(currentCategory)
        Encyclopedia.SetupInfoContainer()
        if not lastScannedFishId then
            Encyclopedia.HideInfoContainer()
        end
        Encyclopedia.SetupDiscoveryListener()

        if sys.MainExitButton then
            sys.MainExitButton.Visible = true
            if not originalSizes.MainExitButton then
                originalSizes.MainExitButton = sys.MainExitButton.Size
                originalPositions.MainExitButton = sys.MainExitButton.Position
            end
            sys.MainExitButtonOriginalSize = originalSizes.MainExitButton
            sys.MainExitButtonOriginalColor = sys.MainExitButton.BackgroundColor3
        end

        encyclopediaInitialized = true
    end
end

function Encyclopedia.ResetToDefault()
    local sys = encyclopediaSystem
    if not sys then return end
    Encyclopedia.ClearFishBoxes()
    currentCategory = DEFAULT_CATEGORY
    currentSelection = nil
    Encyclopedia.HideInfoContainer()
    Encyclopedia.ShowMainExitButton()
end

function Encyclopedia.SetupCategoryTabs()
    local sys = encyclopediaSystem
    if not sys.Categories then
        warn("Categories container not found")
        return
    end

    local existingButtons = {}
    for _, child in ipairs(sys.Categories:GetChildren()) do
        if child:IsA("ImageButton") then
            for _, categoryName in ipairs(CATEGORIES) do
                if child.Name == categoryName:gsub(" ", "") then
                    existingButtons[categoryName] = child
                end
            end
        end
    end

    local allExist = true
    for _, categoryName in ipairs(CATEGORIES) do
        if not existingButtons[categoryName] then
            allExist = false
            break
        end
    end

    if allExist then
        Encyclopedia.UpdateCategoryTabs(currentCategory)
        return
    end

    local templateButton = nil
    for _, child in ipairs(sys.Categories:GetChildren()) do
        if child:IsA("ImageButton") then
            local isExistingButton = false
            for _, categoryName in ipairs(CATEGORIES) do
                if child.Name == categoryName:gsub(" ", "") then
                    isExistingButton = true
                    break
                end
            end
            if not isExistingButton then
                templateButton = child
                break
            end
        end
    end

    if not templateButton then
        warn("No template button found for categories")
        return
    end

    for i, categoryName in ipairs(CATEGORIES) do
        if not existingButtons[categoryName] then
            local categoryButton = templateButton:Clone()
            categoryButton.Parent = sys.Categories
            categoryButton.Name = categoryName:gsub(" ", "")
            categoryButton.LayoutOrder = i

            local imageLabel = categoryButton:FindFirstChild("ImageLabel")
            if imageLabel and categoryImages[categoryName] then
                imageLabel.Image = categoryImages[categoryName]
            end

            local textBox = categoryButton:FindFirstChild("TextBox")
            if textBox then
                textBox.Text = categoryName
            end

            originalCategorySizes[categoryName:gsub(" ", "")] = categoryButton.Size

            Encyclopedia.AddConnection(categoryButton.MouseButton1Click:Connect(function()
                Encyclopedia.SwitchCategory(categoryName)
            end))
        else
            if not originalCategorySizes[categoryName:gsub(" ", "")] then
                originalCategorySizes[categoryName:gsub(" ", "")] = existingButtons[categoryName].Size
            end
        end
    end

    templateButton:Destroy()

    Encyclopedia.UpdateCategoryTabs(currentCategory)
end

function Encyclopedia.SwitchCategory(categoryName)
    local sys = encyclopediaSystem
    currentCategory = categoryName
    sys.GUI:SetAttribute("CurrentCategory", categoryName)
    Encyclopedia.UpdateCategoryTabs(categoryName)
    requestDiscoveriesForCategory(categoryName)

    if sys.ScrollingFrame then
        Encyclopedia.CleanupTweens("scrollToTop")
        local scrollTween = TweenService:Create(sys.ScrollingFrame, SCROLL_TWEEN_INFO, {
            CanvasPosition = Vector2.new(0, 0)
        })
        currentTweens["scrollToTop"] = scrollTween
        scrollTween:Play()
    end

    Encyclopedia.LoadCategory(categoryName)
    Encyclopedia.ClearSelection()
end

function Encyclopedia.UpdateCategoryTabs(selectedCategory)
    local sys = encyclopediaSystem
    if not sys.Categories then return end

    for _, categoryName in ipairs(CATEGORIES) do
        local categoryButton = sys.Categories:FindFirstChild(categoryName:gsub(" ", ""))

        if categoryButton and categoryButton:IsA("ImageButton") then
            local buttonKey = categoryName:gsub(" ", "")
            local isSelected = categoryName == selectedCategory

            if not originalCategorySizes[buttonKey] then
                originalCategorySizes[buttonKey] = categoryButton.Size
            end

            Encyclopedia.CleanupTweens("categoryButton_" .. buttonKey)

            if isSelected then
                local imageLabel = categoryButton:FindFirstChild("ImageLabel")
                if imageLabel then
                    imageLabel.ImageColor3 = SELECTED_CATEGORY_COLOR
                end

                local textBox = categoryButton:FindFirstChild("TextBox")
                if textBox then
                    textBox.TextColor3 = SELECTED_CATEGORY_COLOR
                end

                local targetSize = UDim2.new(
                    originalCategorySizes[buttonKey].X.Scale * CATEGORY_SCALE_MULTIPLIER,
                    originalCategorySizes[buttonKey].X.Offset,
                    originalCategorySizes[buttonKey].Y.Scale * CATEGORY_SCALE_MULTIPLIER,
                    originalCategorySizes[buttonKey].Y.Offset
                )

                local scaleTween = TweenService:Create(categoryButton, CATEGORY_SELECT_TWEEN_INFO, {
                    Size = targetSize
                })

                currentTweens["categoryButton_" .. buttonKey] = scaleTween

                Encyclopedia.AddConnection(scaleTween.Completed:Connect(function()
                    currentTweens["categoryButton_" .. buttonKey] = nil
                end))

                scaleTween:Play()
            else
                local colorKey = "categoryColor_" .. buttonKey
                local scaleKey = "categoryScale_" .. buttonKey

                Encyclopedia.CleanupTweens(colorKey, scaleKey)

                local imageLabel = categoryButton:FindFirstChild("ImageLabel")
                local imageTween = nil
                if imageLabel then
                    imageTween = TweenService:Create(imageLabel, CATEGORY_DESELECT_COLOR_TWEEN_INFO, {
                        ImageColor3 = DESELECTED_CATEGORY_COLOR
                    })
                end

                local textBox = categoryButton:FindFirstChild("TextBox")
                local textTween = nil
                if textBox then
                    textTween = TweenService:Create(textBox, CATEGORY_DESELECT_COLOR_TWEEN_INFO, {
                        TextColor3 = DESELECTED_CATEGORY_COLOR
                    })
                end

                local scaleTween = TweenService:Create(categoryButton, CATEGORY_DESELECT_SCALE_TWEEN_INFO, {
                    Size = originalCategorySizes[buttonKey]
                })

                currentTweens[scaleKey] = scaleTween

                if imageTween then
                    currentTweens[colorKey .. "_image"] = imageTween
                    Encyclopedia.AddConnection(imageTween.Completed:Connect(function()
                        currentTweens[colorKey .. "_image"] = nil
                    end))
                    imageTween:Play()
                end

                if textTween then
                    currentTweens[colorKey .. "_text"] = textTween
                    Encyclopedia.AddConnection(textTween.Completed:Connect(function()
                        currentTweens[colorKey .. "_text"] = nil
                    end))
                    textTween:Play()
                end

                Encyclopedia.AddConnection(scaleTween.Completed:Connect(function()
                    currentTweens[scaleKey] = nil
                end))

                scaleTween:Play()
            end
        end
    end
end

function Encyclopedia.LoadCategory(categoryName)
    local sys = encyclopediaSystem
    if not sys.ScrollingFrame then return end
    Encyclopedia.ClearFishBoxes()
    requestDiscoveriesForCategory(categoryName)
    local categoryData = getCategoryData(categoryName)

    if not categoryData then
        warn("No data found for category:", categoryName)
        return
    end

    local fishList = {}
    for fishId, fishData in pairs(categoryData) do
        if type(fishData) == "table" and fishData._id then
            local isDiscovered = isFishDiscovered(categoryName, fishData._id)
            table.insert(fishList, {
                data = fishData,
                discovered = isDiscovered,
                sortKey = isDiscovered and ("0_" .. (fishData.Name or fishData._id)) or
                ("1_" .. (fishData.Name or fishData._id))
            })
        end
    end

    table.sort(fishList, function(a, b)
        if a.discovered ~= b.discovered then
            return a.discovered
        end
        return a.sortKey < b.sortKey
    end)

    for _, fishEntry in ipairs(fishList) do
        Encyclopedia.CreateFishBox(fishEntry.data, fishEntry.discovered)
    end

    Encyclopedia.UpdateLayoutOrder()
end

function Encyclopedia.CreateFishBox(fishData, isDiscovered)
    local sys = encyclopediaSystem
    if not sys.FishBox or not sys.ScrollingFrame then return end

    if isDiscovered == nil then
        isDiscovered = Controller and isFishDiscovered(currentCategory, fishData._id) or false
    end

    local fishBox = sys.FishBox:Clone()
    fishBox.Name = fishData._id .. "Box"
    fishBox.Parent = sys.ScrollingFrame
    fishBox.Visible = true

    local colors = isDiscovered and FISH_BOX_COLORS.discovered or FISH_BOX_COLORS.undiscovered

    fishBox.BackgroundColor3 = colors.backgroundColor

    local imageLabel = fishBox:FindFirstChild("ImageLabel")
    local nameLabel = fishBox:FindFirstChild("NameLabel")
    local scientificLabel = fishBox:FindFirstChild("ScientificNameLabel")
    local categoryLabel = fishBox:FindFirstChild("CategoryLabel")

    if imageLabel then
        imageLabel.Image = isDiscovered and (fishData.Icon or "") or ""
        imageLabel.ImageColor3 = colors.imageColor
    end

    if nameLabel then
        nameLabel.Text = isDiscovered and fishData.Name or UNDISCOVERED_TEXT
        nameLabel.TextColor3 = colors.nameTextColor
    end

    if scientificLabel then
        scientificLabel.Text = isDiscovered and (fishData.Aliases and fishData.Aliases[1] or "") or
        UNDISCOVERED_SCIENTIFIC_TEXT
        scientificLabel.TextColor3 = colors.scientificTextColor
    end

    if categoryLabel then
        if categoryLabel:IsA("TextLabel") then
            categoryLabel.Text = isDiscovered and currentCategory or NOT_DISCOVERED_CATEGORY
            categoryLabel.Visible = true
        elseif categoryLabel:IsA("ImageLabel") then
            if isDiscovered and categoryImages[currentCategory] then
                categoryLabel.Image = categoryImages[currentCategory]
            elseif not isDiscovered and categoryImages[NOT_DISCOVERED_CATEGORY] then
                categoryLabel.Image = categoryImages[NOT_DISCOVERED_CATEGORY]
            else
                categoryLabel.Image = ""
            end

            local textLabel = categoryLabel:FindFirstChild("TextLabel")
            if textLabel then
                textLabel.Text = isDiscovered and currentCategory or NOT_DISCOVERED_CATEGORY
            end
            categoryLabel.Visible = true
        end
    end

    local uiCorner = fishBox:FindFirstChild("UICorner")
    if uiCorner then
        uiCorner.CornerRadius = FISH_BOX_CORNER_RADIUS
    end

    local uiStroke = fishBox:FindFirstChild("UIStroke")
    if uiStroke then
        uiStroke.Color = colors.strokeColor
        uiStroke.Transparency = 1
    end

    Encyclopedia.AddConnection(fishBox.MouseButton1Click:Connect(function()
        selectBox(fishData._id, false)
    end))

    Encyclopedia.AddConnection(fishBox.MouseEnter:Connect(function()
        if isDiscovered and fishData._id ~= currentSelection then
            if pendingHoverId and pendingHoverId ~= fishData._id then
                clearHover(pendingHoverId)
            end
            pendingHoverId = fishData._id
            applyHover(fishData._id)
        end
    end))

    Encyclopedia.AddConnection(fishBox.MouseLeave:Connect(function()

    end))

    local entry = {
        box = fishBox,
        data = fishData,
        discovered = isDiscovered
    }

    fishBoxes[fishData._id] = entry
    local idString = tostring(fishData._id)
    fishBoxes[idString] = entry
    local idNumber = tonumber(fishData._id)
    if idNumber then
        fishBoxes[idNumber] = entry
    end
end

function Encyclopedia.SelectFish(fishData)
    local sys = encyclopediaSystem
    if pendingHoverId and pendingHoverId ~= fishData._id then
        clearHover(pendingHoverId)
    end
    pendingHoverId = nil

    if currentSelection == fishData._id then
        Encyclopedia.ClearSelection()
        return
    end

    currentSelection = fishData._id
    sys.GUI:SetAttribute("Selection", fishData._id)

    Encyclopedia.UpdateFishBoxSelection()
    Encyclopedia.DisplayFishInfo(fishData)

    if not isInfoContainerVisible then
        Encyclopedia.ShowInfoContainer()
    end
end

function Encyclopedia.UpdateFishBoxSelection()
    local sys = encyclopediaSystem
    for fishId, fishBox in pairs(fishBoxes) do
        local stroke = fishBox.box:FindFirstChild("UIStroke")
        local isSelected = (fishId == currentSelection)
        local isPendingHover = (fishId == pendingHoverId) and not isSelected
        local colors = fishBox.discovered and FISH_BOX_COLORS.discovered or FISH_BOX_COLORS.undiscovered

        if fishBox.box then
            fishBox.box.BackgroundColor3 = colors.backgroundColor
        end

        if stroke then
            if isSelected and fishBox.discovered then
                stroke.Transparency = 0
                local strokeKey = "fishStroke_" .. fishId
                Encyclopedia.CleanupTweens(strokeKey)

                local strokeTween = TweenService:Create(stroke, FISH_SELECT_STROKE_TWEEN_INFO, {
                    Color = colors.strokeColorSelected,
                    Thickness = FISH_BOX_STROKE_THICKNESS_SELECTED
                })
                currentTweens[strokeKey] = strokeTween
                strokeTween:Play()

                local scaleInKey = "fishScaleIn_" .. fishId
                local scaleOutKey = "fishScaleOut_" .. fishId
                Encyclopedia.CleanupTweens(scaleInKey, scaleOutKey)

                local scaleIn = TweenService:Create(fishBox.box, FISH_SCALE_TWEEN_INFO, {
                    Size = fishBox.box.Size + FISH_BOX_SCALE_OFFSET
                })
                local scaleOut = TweenService:Create(fishBox.box, FISH_SCALE_TWEEN_INFO, {
                    Size = fishBox.box.Size
                })

                currentTweens[scaleInKey] = scaleIn
                currentTweens[scaleOutKey] = scaleOut

                scaleIn:Play()
                scaleIn.Completed:Connect(function()
                    currentTweens[scaleInKey] = nil
                    scaleOut:Play()
                end)

                Encyclopedia.AddConnection(scaleOut.Completed:Connect(function()
                    currentTweens[scaleOutKey] = nil
                end))
            elseif isPendingHover then
                stroke.Transparency = 0
                local hoverKey = "fishHover_" .. fishId
                Encyclopedia.CleanupTweens(hoverKey)
                local hoverTween = TweenService:Create(stroke, FISH_HOVER_TWEEN_INFO, {
                    Color = colors.strokeColorHover,
                    Thickness = FISH_BOX_STROKE_THICKNESS_HOVER
                })
                currentTweens[hoverKey] = hoverTween
                hoverTween:Play()
            else
                stroke.Transparency = 1
                local strokeKey = "fishStroke_" .. fishId
                Encyclopedia.CleanupTweens(strokeKey)

                local strokeTween = TweenService:Create(stroke, FISH_DESELECT_STROKE_TWEEN_INFO, {
                    Color = colors.strokeColor,
                    Thickness = FISH_BOX_STROKE_THICKNESS_NORMAL
                })
                currentTweens[strokeKey] = strokeTween
                strokeTween:Play()
            end
        end
    end
end

function Encyclopedia.DisplayFishInfo(fishData)
    local sys = encyclopediaSystem
    if not sys.InfoContainer then return end
    sys.InfoContainer.Visible = true

    local nameContainer = sys.InfoContainer:FindFirstChild("NameContainer", true)
    if nameContainer then
        local fishName = nameContainer:FindFirstChild("FishName")
        if fishName then
            fishName.Text = fishData.Name or "Unknown Fish"
        end

        local scientificName = nameContainer:FindFirstChild("ScientificName")
        if scientificName then
            scientificName.Text = (fishData.Aliases and fishData.Aliases[1]) or "Unknown"
        end

        local starsFrame = nameContainer:FindFirstChild("Stars")
        if starsFrame then
            local eventRarity = fishData.EventRarity or fishData.Rarity
            local eventController = Mince:Get("GlobalEventController")
            local registry = eventController and eventController.EventRegistry
            if not eventRarity and registry then
                local fishId = fishData._id
                for _, eventInfo in pairs(registry) do
                    if eventInfo and (eventInfo.ScanId == fishId or eventInfo.Id == fishId or eventInfo.Name == fishData.Name) then
                        eventRarity = eventInfo.Rarity
                        break
                    end
                end
            end

            local rarityCount = 1
            if eventRarity then
                local rarityInfo = RarityUtil.GetRarity(eventRarity)
                if rarityInfo and rarityInfo.Order then
                    rarityCount = math.clamp(math.floor(rarityInfo.Order), 1, 5)
                end
            end

            local rarityColor = UIColors.White
            if eventRarity then
                local rarityInfo = RarityUtil.GetRarity(eventRarity)
                if rarityInfo and rarityInfo.PrimaryColor then
                    rarityColor = rarityInfo.PrimaryColor
                end
            else
                local commonInfo = RarityUtil.GetRarity("Common")
                if commonInfo and commonInfo.PrimaryColor then
                    rarityColor = commonInfo.PrimaryColor
                end
            end

            local stars = {}
            for _, child in ipairs(starsFrame:GetChildren()) do
                if child:IsA("ImageLabel") then
                    stars[#stars + 1] = child
                end
            end

            table.sort(stars, function(a, b)
                return a.Name < b.Name
            end)

            for index, star in ipairs(stars) do
                star.LayoutOrder = index
                if star:GetAttribute("DefaultColor") == nil then
                    star:SetAttribute("DefaultColor", star.ImageColor3)
                end
                local defaultColor = star:GetAttribute("DefaultColor") or star.ImageColor3
                if index <= rarityCount then
                    star.ImageColor3 = defaultColor
                else
                    star.ImageColor3 = Color3.new(0, 0, 0)
                end
            end

            if fishName then
                fishName.TextColor3 = rarityColor
            end

            if scientificName then
                scientificName.TextColor3 = rarityColor
            end
        end
    else
        warn("NameContainer not found in InfoContainer")
    end

    local depth = sys.DepthContainer and sys.DepthContainer:FindFirstChild("Depth")
    if depth then
        depth.Text = fishData.Depths or "Unknown depth"
    end

    local family = sys.FamilyContainer and sys.FamilyContainer:FindFirstChild("Family")
    if family then
        family.Text = fishData.Family or "Unknown family"
    end

    local size = sys.SizeContainer and sys.SizeContainer:FindFirstChild("Size")
    if size then
        size.Text = fishData.Size or "Unknown size"
    end

    if sys.FactContainer then
        currentFacts = fishData.Facts or {}
        currentFactIndex = 1
        if #currentFacts > 0 then
            createFactClones(currentFacts[1], sys.FactContainer, FACT_MAX_CHARACTERS_PER_LINE)
        else
            createFactClones("No facts available", sys.FactContainer, FACT_MAX_CHARACTERS_PER_LINE)
        end
    end

    Encyclopedia.SetupViewport(fishData)
end

function Encyclopedia.SetupFacts(facts)
    local sys = encyclopediaSystem
    currentFacts = facts or {}
    currentFactIndex = 1

    if sys.FactContainer then
        if #currentFacts > 0 then
            createFactClones(currentFacts[1], sys.FactContainer, FACT_MAX_CHARACTERS_PER_LINE)
        else
            createFactClones("No facts available", sys.FactContainer, FACT_MAX_CHARACTERS_PER_LINE)
        end
    end
end

function Encyclopedia.SetupViewport(fishData)
    local sys = encyclopediaSystem
    if not sys.ViewportFrame or not sys.WorldModel then return end

    if sys.ViewportTrove then
        sys.ViewportTrove:Destroy()
    end
    sys.ViewportTrove = Trove.new()

    for _, child in pairs(sys.WorldModel:GetChildren()) do
        child:Destroy()
    end

    if not fishData.Model then return end

    local model = fishData.Model:Clone()
    model.Parent = sys.WorldModel
    sys.ViewportTrove:Add(model)

    local animationController = model:FindFirstChildWhichIsA("AnimationController", true)
    if animationController then
        local animator = animationController:FindFirstChildOfClass("Animator")
        if not animator then
            animator = Instance.new("Animator")
            animator.Parent = animationController
        end

        for _, descendant in ipairs(model:GetDescendants()) do
            if descendant:IsA("Animation") then
                local track = animator:LoadAnimation(descendant)
                track:Play()
                sys.ViewportTrove:Add(track)
                break
            end
        end
    end

    local boundsCFrame, boundsSize = model:GetBoundingBox()
    local modelSize = boundsSize

    local maxDimension = math.max(modelSize.X, modelSize.Y, modelSize.Z)
    local initialZoom = -maxDimension * VIEWPORT_ZOOM_MULTIPLIER
    local targetCFrame = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(90), 0, 0)

    model:PivotTo(targetCFrame)

    local centeredBoundsCFrame = model:GetBoundingBox()
    local modelCenter = centeredBoundsCFrame.Position

    if not sys.ViewportFrame.CurrentCamera then
        local camera = Instance.new("Camera")
        camera.Parent = sys.ViewportFrame
        sys.ViewportFrame.CurrentCamera = camera
    end

    local camera = sys.ViewportFrame.CurrentCamera
    camera.CFrame = CFrame.new(0, 0, initialZoom)

    sys.ViewportData = {
        model = model,
        modelSize = modelSize,
        maxDimension = maxDimension,
        modelCenter = modelCenter,
        currentRotationX = VIEWPORT_INITIAL_ROTATION_X,
        currentRotationY = VIEWPORT_INITIAL_ROTATION_Y,
        currentRotationZ = 0,
        zoomDistance = initialZoom,
        minZoom = -maxDimension * VIEWPORT_ZOOM_MIN_MULTIPLIER,
        maxZoom = -maxDimension * VIEWPORT_ZOOM_MAX_MULTIPLIER,
        zoomFactor = maxDimension * VIEWPORT_ZOOM_FACTOR_MULTIPLIER,
        isDragging = false,
        lastMousePosition = Vector2.new(0, 0),
        isPanning = false,
        lastPanPosition = Vector2.new(0, 0),
        panOffset = Vector3.new(0, 0, 0),
        panSpeed = VIEWPORT_MOUSE_PAN_SENSITIVITY,
        lastTouchPanTranslation = nil,
        activeTouchCount = 0,
        rotationSpeed = VIEWPORT_ROTATION_SPEED
    }

    Encyclopedia.SetupViewportControls()
    Encyclopedia.UpdateViewportCamera()
end

function Encyclopedia.SetupViewportControls()
    local sys = encyclopediaSystem
    if not sys or not sys.ViewportFrame or not sys.ViewportData or not sys.ViewportTrove then return end

    if sys.ViewportFrame:IsA("GuiObject") then
        sys.ViewportFrame.Active = true
    end

    local function applyPanDelta(deltaPosition, sensitivity)
        if deltaPosition.Magnitude == 0 then return end
        local rotationX = CFrame.Angles(sys.ViewportData.currentRotationX, 0, 0)
        local rotationY = CFrame.Angles(0, sys.ViewportData.currentRotationY, 0)
        local rotationZ = CFrame.Angles(0, 0, sys.ViewportData.currentRotationZ or 0)
        local rotation = rotationY * rotationX * rotationZ
        local rightVector = rotation:VectorToWorldSpace(Vector3.new(1, 0, 0))
        local upVector = rotation:VectorToWorldSpace(Vector3.new(0, 1, 0))
        local panOffset = sys.ViewportData.panOffset or Vector3.new(0, 0, 0)
        panOffset = panOffset + rightVector * deltaPosition.X * sensitivity
        panOffset = panOffset + upVector * deltaPosition.Y * sensitivity
        sys.ViewportData.panOffset = panOffset
        Encyclopedia.UpdateViewportCamera()
    end

    local function handleMouseMovement(input)
        if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end

        local currentPosition = Vector2.new(input.Position.X, input.Position.Y)

        if sys.ViewportData.isDragging then
            local deltaPosition = currentPosition - sys.ViewportData.lastMousePosition
            sys.ViewportData.currentRotationY = sys.ViewportData.currentRotationY -
            deltaPosition.X * sys.ViewportData.rotationSpeed
            sys.ViewportData.currentRotationX = math.clamp(
                sys.ViewportData.currentRotationX + deltaPosition.Y * sys.ViewportData.rotationSpeed,
                -VIEWPORT_ROTATION_CLAMP,
                VIEWPORT_ROTATION_CLAMP
            )
            sys.ViewportData.lastMousePosition = currentPosition
            Encyclopedia.UpdateViewportCamera()
        end

        if sys.ViewportData.isPanning then
            local deltaPan = currentPosition - sys.ViewportData.lastPanPosition
            sys.ViewportData.lastPanPosition = currentPosition
            applyPanDelta(deltaPan, sys.ViewportData.panSpeed)
        end
    end

    sys.ViewportTrove:Connect(sys.ViewportFrame.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            sys.ViewportData.isDragging = true
            sys.ViewportData.lastMousePosition = Vector2.new(input.Position.X, input.Position.Y)
        elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
            sys.ViewportData.isPanning = true
            sys.ViewportData.lastPanPosition = Vector2.new(input.Position.X, input.Position.Y)
        end
    end)

    sys.ViewportTrove:Connect(sys.ViewportFrame.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            sys.ViewportData.isDragging = false
        elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
            sys.ViewportData.isPanning = false
        end
    end)

    sys.ViewportTrove:Connect(UserInputService.InputChanged, function(input)
        handleMouseMovement(input)
    end)

    sys.ViewportTrove:Connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            sys.ViewportData.isDragging = false
        elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
            sys.ViewportData.isPanning = false
        end
    end)

    sys.ViewportTrove:Connect(sys.ViewportFrame.InputChanged, function(input)
        if input.UserInputType == Enum.UserInputType.MouseWheel then
            local scrollDirection = input.Position.Z
            sys.ViewportData.zoomDistance = math.clamp(
                sys.ViewportData.zoomDistance + scrollDirection * sys.ViewportData.zoomFactor,
                sys.ViewportData.minZoom,
                sys.ViewportData.maxZoom
            )
            Encyclopedia.UpdateViewportCamera()
        end
    end)

    sys.ViewportTrove:Connect(sys.ViewportFrame.TouchPan, function(touchPositions, totalTranslation, velocity, state)
        if state == Enum.UserInputState.Begin then
            sys.ViewportData.activeTouchCount = #touchPositions
            sys.ViewportData.lastTouchPanTranslation = totalTranslation
            return
        end

        if state == Enum.UserInputState.Change then
            if sys.ViewportData.activeTouchCount ~= #touchPositions then
                sys.ViewportData.activeTouchCount = #touchPositions
                sys.ViewportData.lastTouchPanTranslation = totalTranslation
            end

            local lastTranslation = sys.ViewportData.lastTouchPanTranslation or Vector2.new(0, 0)
            local deltaTranslation = totalTranslation - lastTranslation
            sys.ViewportData.lastTouchPanTranslation = totalTranslation

            if #touchPositions >= 2 then
                applyPanDelta(deltaTranslation, VIEWPORT_TOUCH_PAN_SENSITIVITY)
            else
                sys.ViewportData.currentRotationY = sys.ViewportData.currentRotationY -
                deltaTranslation.X * VIEWPORT_TOUCH_SENSITIVITY
                sys.ViewportData.currentRotationX = math.clamp(
                    sys.ViewportData.currentRotationX + deltaTranslation.Y * VIEWPORT_TOUCH_SENSITIVITY,
                    -VIEWPORT_ROTATION_CLAMP,
                    VIEWPORT_ROTATION_CLAMP
                )
                Encyclopedia.UpdateViewportCamera()
            end
        elseif state == Enum.UserInputState.End then
            sys.ViewportData.lastTouchPanTranslation = nil
            sys.ViewportData.activeTouchCount = 0
        end
    end)

    sys.ViewportTrove:Connect(sys.ViewportFrame.TouchPinch, function(touchPositions, scale, velocity, state)
        if state == Enum.UserInputState.Change then
            local zoomSensitivity = sys.ViewportData.zoomFactor * VIEWPORT_TOUCH_ZOOM_SENSITIVITY
            local zoomDelta = (1 - scale) * zoomSensitivity

            sys.ViewportData.zoomDistance = math.clamp(
                sys.ViewportData.zoomDistance + zoomDelta,
                sys.ViewportData.minZoom,
                sys.ViewportData.maxZoom
            )
            Encyclopedia.UpdateViewportCamera()
        end
    end)

    sys.ViewportTrove:Connect(sys.ViewportFrame.TouchRotate, function(touchPositions, rotation, velocity, state)
        if state == Enum.UserInputState.Change then
            sys.ViewportData.currentRotationZ = (sys.ViewportData.currentRotationZ or 0) +
            rotation * VIEWPORT_TOUCH_ROTATION_SENSITIVITY
            Encyclopedia.UpdateViewportCamera()
        end
    end)

    sys.ViewportTrove:Connect(sys.ViewportFrame.TouchTap, function(touchPositions)
        if #touchPositions == 1 then
        elseif #touchPositions == 2 then
            Encyclopedia.ResetViewportCamera()
        end
    end)

    sys.ViewportTrove:Connect(sys.ViewportFrame.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            sys.ViewportData.isDragging = true
            sys.ViewportData.lastMousePosition = Vector2.new(input.Position.X, input.Position.Y)
        end
    end)

    sys.ViewportTrove:Connect(sys.ViewportFrame.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            sys.ViewportData.isDragging = false
        end
    end)
end

function Encyclopedia.UpdateViewportCamera()
    local sys = encyclopediaSystem
    if not sys or not sys.ViewportFrame or not sys.ViewportData then return end

    local camera = sys.ViewportFrame.CurrentCamera
    if not camera then return end

    local rotationX = CFrame.Angles(sys.ViewportData.currentRotationX, 0, 0)
    local rotationY = CFrame.Angles(0, sys.ViewportData.currentRotationY, 0)
    local rotationZ = CFrame.Angles(0, 0, sys.ViewportData.currentRotationZ or 0)

    local combinedRotation = rotationY * rotationX * rotationZ
    local zoomPosition = Vector3.new(0, 0, sys.ViewportData.zoomDistance)
    local panOffset = sys.ViewportData.panOffset or Vector3.new(0, 0, 0)
    local modelCenter = sys.ViewportData.modelCenter or Vector3.new(0, 0, 0)

    local focusPoint = modelCenter + panOffset
    local finalPosition = focusPoint + combinedRotation:VectorToWorldSpace(zoomPosition)

    camera.CFrame = CFrame.lookAt(finalPosition, focusPoint, Vector3.new(0, 1, 0))
end

function Encyclopedia.ResetViewportCamera()
    local sys = encyclopediaSystem
    if not sys or not sys.ViewportData then return end

    sys.ViewportData.currentRotationX = 0
    sys.ViewportData.currentRotationY = VIEWPORT_DEFAULT_ROTATION_Y
    sys.ViewportData.currentRotationZ = 0
    sys.ViewportData.zoomDistance = -sys.ViewportData.maxDimension * VIEWPORT_ZOOM_MULTIPLIER
    sys.ViewportData.panOffset = Vector3.new(0, 0, 0)
    sys.ViewportData.lastTouchPanTranslation = nil
    sys.ViewportData.activeTouchCount = 0

    Encyclopedia.UpdateViewportCamera()
end

function Encyclopedia.ShowInfoContainer()
    local sys = encyclopediaSystem
    if not sys or not sys.InfoContainer then return end

    Encyclopedia.CleanupTweens("showInfoContainer", "hideInfoContainer")

    sys.InfoContainer.Visible = true
    isInfoContainerVisible = true

    Encyclopedia.HideMainExitButton()

    if not originalSizes.InfoContainer then
        originalSizes.InfoContainer = sys.InfoContainer.Size
        originalPositions.InfoContainer = sys.InfoContainer.Position
    end

    sys.InfoContainer.Size = ZERO_SIZE
    sys.InfoContainer.Position = CENTER_POSITION

    local showTween = TweenService:Create(sys.InfoContainer, INFO_TWEEN_IN, {
        Size = originalSizes.InfoContainer,
        Position = originalPositions.InfoContainer
    })

    currentTweens.showInfoContainer = showTween
    Encyclopedia.AddConnection(showTween.Completed:Connect(function()
        currentTweens.showInfoContainer = nil
    end))

    showTween:Play()
end

function Encyclopedia.HideInfoContainer()
    local sys = encyclopediaSystem
    if not sys or not sys.InfoContainer then return end

    Encyclopedia.CleanupTweens("showInfoContainer", "hideInfoContainer")
    cleanupFactClones()

    if sys.ViewportTrove then
        sys.ViewportTrove:Destroy()
        sys.ViewportTrove = nil
    end

    Encyclopedia.ShowMainExitButton()

    if not originalSizes.InfoContainer then
        originalSizes.InfoContainer = sys.InfoContainer.Size
        originalPositions.InfoContainer = sys.InfoContainer.Position
    end

    local hideTween = TweenService:Create(sys.InfoContainer, INFO_TWEEN_OUT, {
        Size = ZERO_SIZE,
        Position = CENTER_POSITION
    })

    currentTweens.hideInfoContainer = hideTween
    Encyclopedia.AddConnection(hideTween.Completed:Connect(function()
        sys.InfoContainer.Visible = false
        isInfoContainerVisible = false
        currentTweens.hideInfoContainer = nil
    end))

    hideTween:Play()
end

function Encyclopedia.ShowMainExitButton()
    local sys = encyclopediaSystem
    if not sys or not sys.MainExitButton then return end
    local mainExitButtonFrame = sys.MainExitButton.Parent
    if mainExitButtonFrame then
        mainExitButtonFrame.Visible = true
        if sys.MainExitButtonOriginalColor then
            sys.MainExitButton.BackgroundColor3 = sys.MainExitButtonOriginalColor
        end
    end
end

function Encyclopedia.HideMainExitButton()
    local sys = encyclopediaSystem
    if not sys or not sys.MainExitButton then return end
    Encyclopedia.CleanupTweens("mainExitHoverIn", "mainExitHoverOut", "mainExitClickDown", "mainExitClickUp")
    local mainExitButtonFrame = sys.MainExitButton.Parent
    if mainExitButtonFrame then
        mainExitButtonFrame.Visible = false
        if sys.MainExitButtonOriginalColor then
            sys.MainExitButton.BackgroundColor3 = sys.MainExitButtonOriginalColor
        end
        if sys.MainExitButtonOriginalSize then
            sys.MainExitButton.Size = sys.MainExitButtonOriginalSize
        end
    end
end

function Encyclopedia.SetupSearch()
    local sys = encyclopediaSystem
    if not sys or not sys.TextBox then
        warn("TextBox not found in sys!")
        return
    end

    Encyclopedia.AddConnection(sys.TextBox:GetPropertyChangedSignal("Text"):Connect(function()
        local query = sys.TextBox.Text
        Encyclopedia.SearchFish(query)
    end))

    Encyclopedia.AddConnection(sys.TextBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            local query = sys.TextBox.Text
            Encyclopedia.SearchFish(query)
        end
    end))
end

function Encyclopedia.SetupCloseButtons()
    local sys = encyclopediaSystem
    if not sys then
        return
    end
    if sys.InfoCloseButton then
        local originalSize = sys.InfoCloseButton.Size
        local originalColor = sys.InfoCloseButton.BackgroundColor3
        local hoverSize = UDim2.new(
            originalSize.X.Scale * EXIT_BUTTON_HOVER_SCALE,
            originalSize.X.Offset,
            originalSize.Y.Scale * EXIT_BUTTON_HOVER_SCALE,
            originalSize.Y.Offset
        )
        local clickSize = UDim2.new(
            originalSize.X.Scale * EXIT_BUTTON_CLICK_SCALE,
            originalSize.X.Offset,
            originalSize.Y.Scale * EXIT_BUTTON_CLICK_SCALE,
            originalSize.Y.Offset
        )

        Encyclopedia.AddConnection(sys.InfoCloseButton.MouseEnter:Connect(function()
            Encyclopedia.CleanupTweens("exitHoverOut")
            sys.InfoCloseButton.BackgroundColor3 = EXIT_BUTTON_HOVER_COLOR

            currentTweens.exitHoverIn = TweenService:Create(sys.InfoCloseButton, EXIT_BUTTON_HOVER_TWEEN_INFO, {
                Size = hoverSize
            })

            Encyclopedia.AddConnection(currentTweens.exitHoverIn.Completed:Connect(function()
                currentTweens.exitHoverIn = nil
            end))
            currentTweens.exitHoverIn:Play()
        end))

        Encyclopedia.AddConnection(sys.InfoCloseButton.MouseLeave:Connect(function()
            Encyclopedia.CleanupTweens("exitHoverIn", "exitClickUp")
            sys.InfoCloseButton.BackgroundColor3 = originalColor

            currentTweens.exitHoverOut = TweenService:Create(sys.InfoCloseButton, EXIT_BUTTON_HOVER_TWEEN_INFO, {
                Size = originalSize
            })

            Encyclopedia.AddConnection(currentTweens.exitHoverOut.Completed:Connect(function()
                currentTweens.exitHoverOut = nil
            end))
            currentTweens.exitHoverOut:Play()
        end))

        Encyclopedia.AddConnection(sys.InfoCloseButton.MouseButton1Down:Connect(function()
            Encyclopedia.CleanupTweens("exitHoverIn")
            sys.InfoCloseButton.BackgroundColor3 = EXIT_BUTTON_CLICK_COLOR

            currentTweens.exitClickDown = TweenService:Create(sys.InfoCloseButton, EXIT_BUTTON_CLICK_TWEEN_INFO, {
                Size = clickSize
            })

            Encyclopedia.AddConnection(currentTweens.exitClickDown.Completed:Connect(function()
                currentTweens.exitClickDown = nil
            end))
            currentTweens.exitClickDown:Play()
        end))

        Encyclopedia.AddConnection(sys.InfoCloseButton.MouseButton1Up:Connect(function()
            Encyclopedia.CleanupTweens("exitClickDown")
            sys.InfoCloseButton.BackgroundColor3 = EXIT_BUTTON_HOVER_COLOR

            currentTweens.exitClickUp = TweenService:Create(sys.InfoCloseButton, EXIT_BUTTON_CLICK_TWEEN_INFO, {
                Size = hoverSize
            })

            Encyclopedia.AddConnection(currentTweens.exitClickUp.Completed:Connect(function()
                currentTweens.exitClickUp = nil
            end))
            currentTweens.exitClickUp:Play()
        end))

        Encyclopedia.AddConnection(sys.InfoCloseButton.MouseButton1Click:Connect(function()
            Encyclopedia.Hide()
        end))
    end

    if sys.MainExitButton then
        local originalSize = sys.MainExitButtonOriginalSize or sys.MainExitButton.Size
        local originalColor = sys.MainExitButtonOriginalColor or sys.MainExitButton.BackgroundColor3
        local hoverSize = UDim2.new(
            originalSize.X.Scale * EXIT_BUTTON_HOVER_SCALE,
            originalSize.X.Offset,
            originalSize.Y.Scale * EXIT_BUTTON_HOVER_SCALE,
            originalSize.Y.Offset
        )
        local clickSize = UDim2.new(
            originalSize.X.Scale * EXIT_BUTTON_CLICK_SCALE,
            originalSize.X.Offset,
            originalSize.Y.Scale * EXIT_BUTTON_CLICK_SCALE,
            originalSize.Y.Offset
        )

        Encyclopedia.AddConnection(sys.MainExitButton.MouseEnter:Connect(function()
            Encyclopedia.CleanupTweens("mainExitHoverOut")
            sys.MainExitButton.BackgroundColor3 = EXIT_BUTTON_HOVER_COLOR

            currentTweens.mainExitHoverIn = TweenService:Create(sys.MainExitButton, EXIT_BUTTON_HOVER_TWEEN_INFO, {
                Size = hoverSize
            })

            Encyclopedia.AddConnection(currentTweens.mainExitHoverIn.Completed:Connect(function()
                currentTweens.mainExitHoverIn = nil
            end))
            currentTweens.mainExitHoverIn:Play()
        end))

        Encyclopedia.AddConnection(sys.MainExitButton.MouseLeave:Connect(function()
            Encyclopedia.CleanupTweens("mainExitHoverIn", "mainExitClickUp")
            sys.MainExitButton.BackgroundColor3 = originalColor

            currentTweens.mainExitHoverOut = TweenService:Create(sys.MainExitButton, EXIT_BUTTON_HOVER_TWEEN_INFO, {
                Size = originalSize
            })

            Encyclopedia.AddConnection(currentTweens.mainExitHoverOut.Completed:Connect(function()
                currentTweens.mainExitHoverOut = nil
            end))
            currentTweens.mainExitHoverOut:Play()
        end))

        Encyclopedia.AddConnection(sys.MainExitButton.MouseButton1Down:Connect(function()
            Encyclopedia.CleanupTweens("mainExitHoverIn")
            sys.MainExitButton.BackgroundColor3 = EXIT_BUTTON_CLICK_COLOR

            currentTweens.mainExitClickDown = TweenService:Create(sys.MainExitButton, EXIT_BUTTON_CLICK_TWEEN_INFO, {
                Size = clickSize
            })

            Encyclopedia.AddConnection(currentTweens.mainExitClickDown.Completed:Connect(function()
                currentTweens.mainExitClickDown = nil
            end))
            currentTweens.mainExitClickDown:Play()
        end))

        Encyclopedia.AddConnection(sys.MainExitButton.MouseButton1Up:Connect(function()
            Encyclopedia.CleanupTweens("mainExitClickDown")
            sys.MainExitButton.BackgroundColor3 = EXIT_BUTTON_HOVER_COLOR

            currentTweens.mainExitClickUp = TweenService:Create(sys.MainExitButton, EXIT_BUTTON_CLICK_TWEEN_INFO, {
                Size = hoverSize
            })

            Encyclopedia.AddConnection(currentTweens.mainExitClickUp.Completed:Connect(function()
                currentTweens.mainExitClickUp = nil
            end))
            currentTweens.mainExitClickUp:Play()
        end))

        local player = Players.LocalPlayer

        Encyclopedia.AddConnection(sys.MainExitButton.MouseButton1Click:Connect(function()
            if player.Character then
                local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    humanoid:UnequipTools()
                end
            end
            Encyclopedia.Hide()
        end))

        Encyclopedia.AddConnection(Encyclopedia.UI.ScreenShown:Connect(function(componentName, isVisible)
            if componentName == "Settings" and isVisible then
                if player.Character then
                    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
                    if humanoid then
                        humanoid:UnequipTools()
                    end
                end
            end

            if isVisible and componentName ~= "Encyclopedia" and Encyclopedia.IsVisible() then
                if player.Character then
                    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
                    if humanoid then
                        humanoid:UnequipTools()
                    end
                end
            end
        end))
    end
end

function Encyclopedia.SearchFish(query)
    local sys = encyclopediaSystem
    if not sys then
        return
    end

    if not query or query == "" then
        Encyclopedia.LoadCategory(currentCategory)
        return
    end

    Encyclopedia.ClearFishBoxes()
    local searchResults = Encyclopedia.FindFishByQuery(query)

    local sortedResults = {}
    for _, fishData in ipairs(searchResults) do
        local isDiscovered = Controller:HasDiscovered(currentCategory, fishData._id)
        table.insert(sortedResults, {
            data = fishData,
            discovered = isDiscovered,
            sortKey = fishData.Name or fishData._id
        })
    end

    table.sort(sortedResults, function(a, b)
        return a.sortKey < b.sortKey
    end)

    for _, fishEntry in ipairs(sortedResults) do
        Encyclopedia.CreateFishBox(fishEntry.data, fishEntry.discovered)
    end

    Encyclopedia.UpdateLayoutOrder()
end

function Encyclopedia.FindFishByQuery(query)
    local results = {}

    if not Controller then
        warn("EncyclopediaController not found")
        return results
    end

    local categoryData = getCategoryData(currentCategory)
    if not categoryData then
        warn("No data found for current category:", currentCategory)
        return results
    end

    query = query:lower()

    for fishId, fish in pairs(categoryData) do
        if type(fish) == "table" and fish._id then
            local isDiscovered = isFishDiscovered(currentCategory, fish._id)

            if isDiscovered then
                if fish.Name and fish.Name:lower():find(query) then
                    table.insert(results, fish)
                elseif fishId:lower():find(query) then
                    table.insert(results, fish)
                elseif fish.Aliases then
                    for _, alias in ipairs(fish.Aliases) do
                        if alias:lower():find(query) then
                            table.insert(results, fish)
                            break
                        end
                    end
                end
            end
        end
    end

    return results
end

function Encyclopedia.ClearFishBoxes()
    local sys = encyclopediaSystem
    for fishId, fishBox in pairs(fishBoxes) do
        Encyclopedia.CleanupTweens(
            "fishHover_" .. fishId,
            "fishStroke_" .. fishId,
            "fishScaleIn_" .. fishId,
            "fishScaleOut_" .. fishId
        )
        if fishBox.box then
            fishBox.box:Destroy()
        end
    end
    fishBoxes = {}
    if sys and sys.ScrollingFrame then
        for _, child in ipairs(sys.ScrollingFrame:GetChildren()) do
            if child:IsA("GuiObject") and child.Name ~= "FishBox" then
                child:Destroy()
            end
        end
    end
end

function Encyclopedia.UpdateLayoutOrder()
    local sys = encyclopediaSystem
    if not sys or not sys.ScrollingFrame then return end

    local children = sys.ScrollingFrame:GetChildren()
    table.sort(children, function(a, b)
        if a:IsA("GuiObject") and b:IsA("GuiObject") then
            local fishIdA = a.Name:gsub("Box$", "")
            local fishIdB = b.Name:gsub("Box$", "")

            local fishBoxA = fishBoxes[fishIdA]
            local fishBoxB = fishBoxes[fishIdB]

            if fishBoxA and fishBoxB then
                if fishBoxA.discovered ~= fishBoxB.discovered then
                    return fishBoxA.discovered
                end
                return (fishBoxA.data.Name or fishIdA) < (fishBoxB.data.Name or fishIdB)
            end

            return a.Name < b.Name
        end
        return false
    end)

    for i, child in ipairs(children) do
        if child:IsA("GuiObject") then
            child.LayoutOrder = i
        end
    end
end

function Encyclopedia.SetupInfoContainer()
    local sys = encyclopediaSystem
    if not sys or not sys.LeftButton or not sys.RightButton then
        warn("Encyclopedia: Fact navigation buttons not found. LeftButton:", sys and sys.LeftButton, "RightButton:",
            sys and sys.RightButton)
        return
    end

    Encyclopedia.AddConnection(sys.LeftButton.MouseButton1Click:Connect(function()
        Encyclopedia.PreviousFact()
    end))

    Encyclopedia.AddConnection(sys.RightButton.MouseButton1Click:Connect(function()
        Encyclopedia.NextFact()
    end))
end

function Encyclopedia.PreviousFact()
    local sys = encyclopediaSystem
    if #currentFacts == 0 then return end

    currentFactIndex = currentFactIndex - 1
    if currentFactIndex < 1 then
        currentFactIndex = #currentFacts
    end

    if sys and sys.FactContainer then
        createFactClones(currentFacts[currentFactIndex] or "", sys.FactContainer, FACT_MAX_CHARACTERS_PER_LINE)
    end
end

function Encyclopedia.NextFact()
    local sys = encyclopediaSystem
    if #currentFacts == 0 then return end

    currentFactIndex = currentFactIndex + 1
    if currentFactIndex > #currentFacts then
        currentFactIndex = 1
    end

    if sys and sys.FactContainer then
        createFactClones(currentFacts[currentFactIndex] or "", sys.FactContainer, FACT_MAX_CHARACTERS_PER_LINE)
    end
end

function Encyclopedia.RefreshCurrentCategory()
    local sys = encyclopediaSystem
    local previousSelection = currentSelection
    Encyclopedia.UpdateFishBoxDiscoveryStates()
    if lastScannedFishId and attemptAutoSelectLastScanned() then
        return
    end
    if previousSelection and fishBoxes[previousSelection] and fishBoxes[previousSelection].discovered then
        Encyclopedia.SelectFish(fishBoxes[previousSelection].data)
    end
end

function Encyclopedia.UpdateFishBoxDiscoveryStates()
    local sys = encyclopediaSystem
    if not Controller then return end
    local hasChanges = false

    for fishId, fishBoxEntry in pairs(fishBoxes) do
        local isNowDiscovered = isFishDiscovered(currentCategory, fishId)
        if fishBoxEntry.discovered ~= isNowDiscovered then
            Encyclopedia.TransitionFishBoxToDiscovered(fishBoxEntry, isNowDiscovered)
            hasChanges = true
        end
    end

    local categoryData = getCategoryData(currentCategory)
    if categoryData then
        for fishId, fishData in pairs(categoryData) do
            if type(fishData) == "table" and fishData._id and not fishBoxes[fishData._id] then
                local isDiscovered = isFishDiscovered(currentCategory, fishData._id)
                Encyclopedia.CreateFishBox(fishData, isDiscovered)
                hasChanges = true
            end
        end
    end

    if hasChanges then
        Encyclopedia.UpdateLayoutOrder()
    end
end

function Encyclopedia.TransitionFishBoxToDiscovered(fishBoxEntry, isDiscovered)
    local fishBox = fishBoxEntry.box
    local fishData = fishBoxEntry.data

    if not fishBox or not fishData then return end

    local wasDiscovered = fishBoxEntry.discovered
    fishBoxEntry.discovered = isDiscovered

    local colors = isDiscovered and FISH_BOX_COLORS.discovered or FISH_BOX_COLORS.undiscovered

    local transitionDuration = 0.5
    local transitionInfo = TweenInfo.new(transitionDuration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

    if isDiscovered and not wasDiscovered then
        local originalBackgroundColor = colors.backgroundColor
        local glowColor = Color3.fromRGB(
            math.min(255, originalBackgroundColor.R * 255 + 50),
            math.min(255, originalBackgroundColor.G * 255 + 50),
            math.min(255, originalBackgroundColor.B * 255 + 50)
        )

        fishBox.BackgroundColor3 = glowColor

        local pulseTween = TweenService:Create(fishBox,
            TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
            BackgroundColor3 = originalBackgroundColor
        })
        pulseTween:Play()
    end

    local backgroundTween = TweenService:Create(fishBox, transitionInfo, {
        BackgroundColor3 = colors.backgroundColor
    })
    backgroundTween:Play()

    local imageLabel = fishBox:FindFirstChild("ImageLabel")
    local nameLabel = fishBox:FindFirstChild("NameLabel")
    local scientificLabel = fishBox:FindFirstChild("ScientificNameLabel")
    local stroke = fishBox:FindFirstChild("UIStroke")

    if imageLabel then
        local fadeOutTween = TweenService:Create(imageLabel,
            TweenInfo.new(transitionDuration / 2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            ImageTransparency = 1
        })

        fadeOutTween.Completed:Connect(function()
            imageLabel.Image = isDiscovered and (fishData.Icon or "") or ""
            imageLabel.ImageColor3 = colors.imageColor

            local fadeInTween = TweenService:Create(imageLabel,
                TweenInfo.new(transitionDuration / 2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                ImageTransparency = 0
            })
            fadeInTween:Play()
        end)

        fadeOutTween:Play()
    end

    if nameLabel then
        nameLabel.Text = isDiscovered and fishData.Name or UNDISCOVERED_TEXT
        local textColorTween = TweenService:Create(nameLabel, transitionInfo, {
            TextColor3 = colors.nameTextColor
        })
        textColorTween:Play()
    end

    if scientificLabel then
        scientificLabel.Text = isDiscovered and (fishData.Aliases and fishData.Aliases[1] or "") or
        UNDISCOVERED_SCIENTIFIC_TEXT
        local textColorTween = TweenService:Create(scientificLabel, transitionInfo, {
            TextColor3 = colors.scientificTextColor
        })
        textColorTween:Play()
    end

    if stroke then
        local strokeTween = TweenService:Create(stroke, transitionInfo, {
            Color = colors.strokeColor
        })
        strokeTween:Play()
    end
end

function Encyclopedia.SetupDiscoveryListener()
    if discoveryListenerSetup then
        return
    end

    if not Controller or not Controller.DiscoveryManager then
        warn("DiscoveryManager not found - encyclopedia won't auto-update on discoveries")
        return
    end

    discoveryListenerSetup = true

    Encyclopedia.AddConnection(Controller.DiscoveryManager.GetDiscoveries.Event:Connect(function(discoveryType)
        local uiCategory = toUICategoryName(discoveryType)
        if uiCategory == currentCategory then
            Encyclopedia.RefreshCurrentCategory()
        end
    end))

    local scanController = Mince:Get("ScanController")
    if scanController and scanController.FishScanned then
        Encyclopedia.AddConnection(scanController.FishScanned:Connect(function(fishId)
            lastScannedFishId = tostring(fishId)
            local uiCategory, discoveryType = findCategoryForFish(fishId)
            local targetCategory = uiCategory or currentCategory

            if Controller and Controller.DiscoveryManager and discoveryType then
                Controller.DiscoveryManager:RequestDiscoveries(discoveryType)
            else
                requestDiscoveriesForCategory(targetCategory)
            end

            if targetCategory == currentCategory then
                Encyclopedia.RefreshCurrentCategory()
            end
        end))
    end
end

function Encyclopedia.IsDiscovered(fishId)
    if not Controller then
        warn("EncyclopediaController not found")
        return false
    end

    return isFishDiscovered(currentCategory, fishId)
end

function Encyclopedia.Show()
    Encyclopedia.CleanupTweens()
    local sys = Encyclopedia.InitSystem()

    if not sys.Tweens or not sys.Tweens.Show then
        error("Encyclopedia tweens not properly initialized")
    end

    Encyclopedia.InitializeInterface()

    GUI.Enabled = true
    Main.Visible = true

    if not originalSizes.Main then
        originalSizes.Main = Main.Size
        originalPositions.Main = Main.Position
    end

    Main.Size = ZERO_SIZE
    Main.Position = CENTER_POSITION

    if not originalSizes.MainBacking then
        originalSizes.MainBacking = sys.MainBacking.Size
        originalPositions.MainBacking = sys.MainBacking.Position
    end

    sys.MainBacking.Size = ZERO_SIZE
    sys.MainBacking.Position = CENTER_POSITION

    if not originalSizes.InfoBacking then
        originalSizes.InfoBacking = sys.InfoBacking.Size
        originalPositions.InfoBacking = sys.InfoBacking.Position
    end

    sys.InfoBacking.Size = ZERO_SIZE
    sys.InfoBacking.Position = CENTER_POSITION

    currentTweens.showMain = sys.Tweens.Show.Main

    Encyclopedia.AddConnection(sys.Tweens.Show.Main.Completed:Connect(function()
        currentTweens.showMain = nil
        if lastScannedFishId then
            attemptAutoSelectLastScanned()
        end
    end))

    currentTweens.showMainBacking = sys.Tweens.Show.MainBacking
    Encyclopedia.AddConnection(sys.Tweens.Show.MainBacking.Completed:Connect(function()
        currentTweens.showMainBacking = nil
    end))

    sys.Tweens.Show.MainBacking:Play()

    currentTweens.showInfoBacking = sys.Tweens.Show.InfoBacking

    Encyclopedia.AddConnection(sys.Tweens.Show.InfoBacking.Completed:Connect(function()
        currentTweens.showInfoBacking = nil
    end))

    sys.Tweens.Show.InfoBacking:Play()
    sys.Tweens.Show.Main:Play()

    Encyclopedia.UI.ScreenShown:Fire("Encyclopedia", true)
    return true
end

function Encyclopedia.Hide()
    Encyclopedia.CleanupTweens()
    Encyclopedia.ClearSelectionVisuals()

    local sys = encyclopediaSystem
    if not sys then
        error("Failed to get encyclopedia system during hide")
    end

    if not sys.Tweens or not sys.Tweens.Hide then
        error("Encyclopedia hide tweens not properly initialized")
    end

    if sys.Tweens.Hide.MainBacking then
        currentTweens.hideMainBacking = sys.Tweens.Hide.MainBacking
        Encyclopedia.AddConnection(sys.Tweens.Hide.MainBacking.Completed:Connect(function()
            currentTweens.hideMainBacking = nil
        end))
        sys.Tweens.Hide.MainBacking:Play()
    end

    if sys.Tweens.Hide.InfoBacking then
        currentTweens.hideInfoBacking = sys.Tweens.Hide.InfoBacking
        Encyclopedia.AddConnection(sys.Tweens.Hide.InfoBacking.Completed:Connect(function()
            currentTweens.hideInfoBacking = nil
        end))
        sys.Tweens.Hide.InfoBacking:Play()
    end

    currentTweens.hideMain = sys.Tweens.Hide.Main

    Encyclopedia.AddConnection(sys.Tweens.Hide.Main.Completed:Connect(function()
        if currentTweens.hideMain == sys.Tweens.Hide.Main then
            GUI.Enabled = false
            Main.Visible = false
        end
        currentTweens.hideMain = nil
    end))

    lastScannedFishId = nil

    sys.Tweens.Hide.Main:Play()

    Encyclopedia.UI.ScreenShown:Fire("Encyclopedia", false)

    return true
end

function Encyclopedia.Toggle()
    Encyclopedia.CleanupTweens()

    local isCurrentlyVisible = Encyclopedia.IsVisible()

    if isCurrentlyVisible then
        Encyclopedia.Hide()
    else
        Encyclopedia.Show()
    end

    return not isCurrentlyVisible
end

function Encyclopedia.IsVisible()
    return GUI.Enabled and Main.Visible
end

function Encyclopedia.System()
    return encyclopediaSystem
end

function Encyclopedia.Init(UI)
    Encyclopedia.UI = UI
    Encyclopedia.InitSystem()
end

function Encyclopedia.Register()
    if not Interface then
        Interface = Mince:Get("InterfaceHandler")
    end

    -- InterfaceHandler may not be loaded yet if Encyclopedia initializes early.
    -- Wait briefly for Mince to finish setting it up instead of failing permanently.
    local attempts = 0
    while (not Interface or not Interface.Get) and attempts < 60 do
        task.wait(0.05)
        if not Interface then
            Interface = Mince:Get("InterfaceHandler")
        end
        attempts += 1
    end

    if not Interface or not Interface.Get then
        warn("InterfaceHandler not available during Register")
        return nil
    end
    Encyclopedia.UIControl = Interface:Get("Encyclopedia", "Main")
    return Encyclopedia.UIControl
end

return Encyclopedia

