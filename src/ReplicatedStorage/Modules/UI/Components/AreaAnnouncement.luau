local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local UIColors = require(game.ReplicatedStorage.Modules.UI.UIColors)

local COLORS = {
	AreaText = UIColors.AreaText,
	SubtitleText = UIColors.AreaSubtitle
}

local ANIMATION_CONFIG = {
	AREA_LETTER_DELAY = 0.05,
	SUBTITLE_LETTER_DELAY = 0.03,
	EXIT_LETTER_DELAY = 0.02,
	SUBTITLE_START_DELAY = 0.3,
	EXIT_CLEANUP_DELAY = 1,

	ENTRANCE_SLIDE_OFFSET = 30,
	EXIT_SLIDE_OFFSET = -20,

	ENTRANCE_SLIDE_TIME = 0.4,
	ENTRANCE_FADE_TIME = 0.3,
	EXIT_FADE_TIME = 0.2,

	EASING_STYLE = Enum.EasingStyle.Quad,
	EASING_DIRECTION = Enum.EasingDirection.Out,
	ENTRANCE_EASING = Enum.EasingStyle.Back,

	LETTER_SPACING_MULTIPLIER = 0.1
}

local UI_CONFIG = {
	CONTAINER_HEIGHT = 120,
	CONTAINER_Y_OFFSET = 50,
	AREA_TEXT_HEIGHT = 60,
	SUBTITLE_HEIGHT = 30,
	SUBTITLE_Y_OFFSET = 70,

	AREA_FONT_SIZE = 36,
	SUBTITLE_FONT_SIZE = 18,
	FONT = Enum.Font.MontserratBold,

	DISPLAY_ORDER = 100,
	DEFAULT_DURATION = 3
}

local UI = {
	gui = nil,
	initialized = false
}

local currentAnnouncement = nil
local currentTasks = {}

local AreaAnnouncement = {}

local function initializeUI()
	if UI.initialized then return end

	local gui = Instance.new("ScreenGui")
	gui.Name = "AreaAnnouncementSystem"
	gui.DisplayOrder = UI_CONFIG.DISPLAY_ORDER
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

	UI.gui = gui
	UI.initialized = true
end

local function calculateLetterData(text, fontSize)
	if not text or text == "" then return {} end

	local letterData = {}
	local totalWidth = 0

	for i = 1, #text do
		local char = string.sub(text, i, i)
		local textBounds = TextService:GetTextSize(char, fontSize, UI_CONFIG.FONT, Vector2.new(math.huge, math.huge))
		local letterWidth = textBounds.X + (fontSize * ANIMATION_CONFIG.LETTER_SPACING_MULTIPLIER)

		letterData[i] = {
			char = char,
			width = letterWidth,
			x = totalWidth
		}

		totalWidth = totalWidth + letterWidth
	end

	return letterData, totalWidth
end

local function createLetterLabel(data, totalWidth, fontSize, color, parent)
	local letter = Instance.new("TextLabel")
	letter.Size = UDim2.new(0, data.width, 1, 0)
	letter.Position = UDim2.new(0.5, -totalWidth/2 + data.x, 0, 0)
	letter.AnchorPoint = Vector2.new(0, 0)
	letter.BackgroundTransparency = 1
	letter.Text = data.char
	letter.TextColor3 = color
	letter.TextSize = fontSize
	letter.TextXAlignment = Enum.TextXAlignment.Center
	letter.TextYAlignment = Enum.TextYAlignment.Center
	letter.Font = UI_CONFIG.FONT
	letter.TextTransparency = 1
	letter.TextScaled = false
	letter.Parent = parent

	local stroke = Instance.new("UIStroke")
	stroke.Color = UIColors.Accent
	stroke.Thickness = 2
	stroke.Transparency = 1
	stroke.Parent = letter

	return letter
end

local function createLettersForText(text, parent, fontSize, color, letterArray)
	if not text or text == "" then return end
	local letterData, totalWidth = calculateLetterData(text, fontSize)

	for i = 1, #text do
		local data = letterData[i]
		local letter = createLetterLabel(data, totalWidth, fontSize, color, parent)
		table.insert(letterArray, letter)
	end
end

local function createAnnouncementContainer()
	local container = Instance.new("Frame")
	container.Name = "AnnouncementContainer"
	container.Size = UDim2.new(1, 0, 0, UI_CONFIG.CONTAINER_HEIGHT)
	container.Position = UDim2.new(0, 0, 0, UI_CONFIG.CONTAINER_Y_OFFSET)
	container.BackgroundTransparency = 1
	container.Parent = UI.gui

	return container
end

local function createTextFrame(parent, yOffset, height)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, height)
	frame.Position = UDim2.new(0, 0, 0, yOffset)
	frame.BackgroundTransparency = 1
	frame.Parent = parent
	return frame
end

local function createAnnouncement(areaName, subtitle)
	initializeUI()

	local container = createAnnouncementContainer()

	local areaTextFrame = createTextFrame(container, 0, UI_CONFIG.AREA_TEXT_HEIGHT)
	local subtitleFrame = nil
	local subtitleLetters = {}

	local areaLetters = {}

	createLettersForText(areaName, areaTextFrame, UI_CONFIG.AREA_FONT_SIZE, COLORS.AreaText, areaLetters)

	if subtitle and subtitle ~= "" then
		subtitleFrame = createTextFrame(container, UI_CONFIG.SUBTITLE_Y_OFFSET, UI_CONFIG.SUBTITLE_HEIGHT)
		createLettersForText(subtitle, subtitleFrame, UI_CONFIG.SUBTITLE_FONT_SIZE, COLORS.SubtitleText, subtitleLetters)
	end

	return container, areaLetters, subtitleLetters
end

local function createTweenInfo(duration, easing, direction)
	return TweenInfo.new(duration, easing, direction)
end

local function createFadeTween(target, duration, transparency)
	return TweenService:Create(target, 
		createTweenInfo(duration, ANIMATION_CONFIG.EASING_STYLE, ANIMATION_CONFIG.EASING_DIRECTION),
		{TextTransparency = transparency}
	)
end

local function createSlideTween(target, duration, positionOffset, easing)
	return TweenService:Create(target,
		createTweenInfo(duration, easing or ANIMATION_CONFIG.ENTRANCE_EASING, ANIMATION_CONFIG.EASING_DIRECTION),
		{Position = target.Position + positionOffset}
	)
end

local function animateLetterEntrance(letter, index, isSubtitle)
	local delay = (index - 1) * (isSubtitle and ANIMATION_CONFIG.SUBTITLE_LETTER_DELAY or ANIMATION_CONFIG.AREA_LETTER_DELAY)

	return task.spawn(function()
		task.wait(delay)

		if not letter or not letter.Parent or not letter.Parent.Parent then return end

		letter.Position = letter.Position + UDim2.new(0, 0, 0, -ANIMATION_CONFIG.ENTRANCE_SLIDE_OFFSET)

		local slideDown = createSlideTween(letter, 
			ANIMATION_CONFIG.ENTRANCE_SLIDE_TIME, 
			UDim2.new(0, 0, 0, ANIMATION_CONFIG.ENTRANCE_SLIDE_OFFSET),
			ANIMATION_CONFIG.ENTRANCE_EASING
		)

		local fadeIn = TweenService:Create(letter, 
			createTweenInfo(ANIMATION_CONFIG.ENTRANCE_FADE_TIME, ANIMATION_CONFIG.EASING_STYLE, ANIMATION_CONFIG.EASING_DIRECTION),
			{TextTransparency = 0}
		)

		local stroke = letter:FindFirstChildOfClass("UIStroke")
		local strokeFadeIn = nil
		if stroke then
			strokeFadeIn = TweenService:Create(stroke,
				createTweenInfo(ANIMATION_CONFIG.ENTRANCE_FADE_TIME, ANIMATION_CONFIG.EASING_STYLE, ANIMATION_CONFIG.EASING_DIRECTION),
				{Transparency = 0.3}
			)
		end

		if letter.Parent and letter.Parent.Parent then
			slideDown:Play()
			fadeIn:Play()
			if strokeFadeIn then
				strokeFadeIn:Play()
			end
		end
	end)
end

local function animateLetterExit(letter, index)
	local delay = (index - 1) * ANIMATION_CONFIG.EXIT_LETTER_DELAY
	return task.spawn(function()
		task.wait(delay)
		if not letter or not letter.Parent or not letter.Parent.Parent then return end

		local fadeOut = TweenService:Create(letter,
			createTweenInfo(ANIMATION_CONFIG.EXIT_FADE_TIME, ANIMATION_CONFIG.EASING_STYLE, ANIMATION_CONFIG.EASING_DIRECTION),
			{TextTransparency = 1}
		)

		local stroke = letter:FindFirstChildOfClass("UIStroke")
		local strokeFadeOut = nil
		if stroke then
			strokeFadeOut = TweenService:Create(stroke,
				createTweenInfo(ANIMATION_CONFIG.EXIT_FADE_TIME, ANIMATION_CONFIG.EASING_STYLE, ANIMATION_CONFIG.EASING_DIRECTION),
				{Transparency = 1}
			)
		end

		if letter.Parent and letter.Parent.Parent then
			fadeOut:Play()
			if strokeFadeOut then
				strokeFadeOut:Play()
			end
		end
	end)
end

local function playEntranceEffects(container, areaLetters, subtitleLetters)
	local tasks = {}

	for i, letter in areaLetters do
		local task = animateLetterEntrance(letter, i, false)
		table.insert(tasks, task)
	end

	if #subtitleLetters > 0 then
		local subtitleDelayTask = task.spawn(function()
			task.wait(ANIMATION_CONFIG.SUBTITLE_START_DELAY)
			for i, letter in subtitleLetters do
				local subtitleTask = animateLetterEntrance(letter, i, true)
				table.insert(tasks, subtitleTask)
			end
		end)
		table.insert(tasks, subtitleDelayTask)
	end

	return tasks
end

local function cleanupLetters(letters)
	for _, letter in letters do
		if letter and letter.Parent then
			pcall(function()
				letter:Destroy()
			end)
		end
	end
end

local function playExitEffects(container, areaLetters, subtitleLetters)
	local tasks = {}

	for i, letter in areaLetters do
		local task = animateLetterExit(letter, i)
		table.insert(tasks, task)
	end

	for i, letter in subtitleLetters do
		local task = animateLetterExit(letter, i)
		table.insert(tasks, task)
	end

	local cleanupTask = task.spawn(function()
		task.wait(ANIMATION_CONFIG.EXIT_CLEANUP_DELAY)
		if container and container.Parent then
			pcall(function()
				container:Destroy()
			end)
		end
	end)

	table.insert(tasks, cleanupTask)

	return tasks
end


function AreaAnnouncement.Show(areaName, subtitle, duration)
	if not areaName or type(areaName) ~= "string" or areaName == "" then
		return nil
	end

	AreaAnnouncement.Hide()
	duration = duration or UI_CONFIG.DEFAULT_DURATION

	local container, areaLetters, subtitleLetters = createAnnouncement(areaName, subtitle)
	currentAnnouncement = {
		container = container,
		areaLetters = areaLetters,
		subtitleLetters = subtitleLetters
	}

	local mainTask = task.spawn(function()
		local entranceTasks = playEntranceEffects(container, areaLetters, subtitleLetters)
		for _, t in entranceTasks do
			table.insert(currentTasks, t)
		end

		task.wait(duration)

		if currentAnnouncement and currentAnnouncement.container == container then
			local exitTasks = playExitEffects(container, areaLetters, subtitleLetters)
			for _, t in exitTasks do
				table.insert(currentTasks, t)
			end
			currentAnnouncement = nil
		end
	end)

	table.insert(currentTasks, mainTask)
	return container
end

function AreaAnnouncement.Hide()
	for _, thread in currentTasks do
		pcall(function()
			task.cancel(thread)
		end)
	end

	currentTasks = {}

	if currentAnnouncement then
		if currentAnnouncement.container and currentAnnouncement.container.Parent then
			pcall(function()
				currentAnnouncement.container:Destroy()
			end)
		end
		currentAnnouncement = nil
	end

	if UI.gui then
		for _, child in UI.gui:GetChildren() do
			if child.Name == "AnnouncementContainer" then
				pcall(function()
					child:Destroy()
				end)
			end
		end
	end

end

return AreaAnnouncement
