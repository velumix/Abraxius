local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Player = Players.LocalPlayer
local Modules = ReplicatedStorage:WaitForChild("Modules")

local Mince = require(Modules.Mince)
local UIFactory = require(Modules.UI.UIFactory)
local UIColors = require(Modules.UI.UIColors)

local Assets = ReplicatedStorage:WaitForChild("Assets")
local SoundsFolder = Assets:FindFirstChild("Sounds")
local JukeboxLibrary = SoundsFolder and SoundsFolder:FindFirstChild("Jukebox")

local PlayerGui = Player:WaitForChild("PlayerGui")

local function getSoundsFolder()
	if not SoundsFolder or not SoundsFolder.Parent then
		SoundsFolder = Assets:FindFirstChild("Sounds")
	end
	return SoundsFolder
end

local function getJukeboxLibrary()
	local sounds = getSoundsFolder()
	if not sounds then
		return nil
	end

	if not JukeboxLibrary or not JukeboxLibrary.Parent then
		JukeboxLibrary = sounds:FindFirstChild("Jukebox")
	end

	return JukeboxLibrary
end

local JukeboxEvent = Mince:GetEvent("Jukebox")
local SetGenreEvent = JukeboxEvent:Extend("SetGenre")
local TogglePlaybackEvent = JukeboxEvent:Extend("TogglePlayback")
local SetShuffleEvent = JukeboxEvent:Extend("SetShuffle")
local NextTrackEvent = JukeboxEvent:Extend("NextTrack")
local RequestTracksEvent = JukeboxEvent:Extend("RequestTracks")
local PlayTrackEvent = JukeboxEvent:Extend("PlayTrack")

local Interface = {
	GenreButtons = {},
	TrackButtons = {},
	AttributeConnections = {},
	ActiveComponent = nil,
	ActiveInstance = nil,
	ShuffleEnabled = false,
	Playing = false,
	TrackCount = 0,
	Scale = nil,
	GenreTrackCache = {},
	PendingTrackRequests = {},
	ActiveTrackName = nil,
}

local HEADER_HEIGHT = 72
local PANEL_PADDING = 20
local SECTION_GAP = 16
local NOWPLAYING_HEIGHT = 96
local CONTROL_HEIGHT = 56

local function sanitizeTrackNames(trackNames)
	local results = {}
	if typeof(trackNames) ~= "table" then
		return results
	end

	for _, name in ipairs(trackNames) do
		if typeof(name) == "string" and name ~= "" then
			table.insert(results, name)
		end
	end

	table.sort(results)
	return results
end

local function styleControlButton(button)
	button.AutoButtonColor = false
	button.BackgroundColor3 = UIColors.Button
	button.TextColor3 = UIColors.White
	UIFactory.applyButtonStates(button, {
		Default = UIColors.Button,
		Hover = UIColors.ButtonHover,
		Pressed = UIColors.ButtonPressed,
	})
	UIFactory.applyCorner(button, UDim.new(0, 10))
	UIFactory.applyStroke(button, {
		Color = UIColors.Stroke,
		Thickness = 1,
		Transparency = 0.6,
	})
end

local function styleTrackButton(button)
	button.AutoButtonColor = false
	button.BackgroundColor3 = UIColors.Card
	button.TextColor3 = UIColors.Text
	button.ClipsDescendants = true
	UIFactory.applyCorner(button, UDim.new(0, 8))
	UIFactory.applyStroke(button, {
		Color = UIColors.Stroke,
		Thickness = 1,
		Transparency = 0.75,
	})
	UIFactory.createUIPadding(button, {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	})
end

function Interface:ClearTrackButtons()
	if not self.TrackButtons then
		self.TrackButtons = {}
		return
	end

	for _, info in pairs(self.TrackButtons) do
		if info.Connections then
			for _, connection in ipairs(info.Connections) do
				connection:Disconnect()
			end
		end
		if info.Button then
			info.Button:Destroy()
		end
	end

	self.TrackButtons = {}
end

function Interface:ResetTrackCaches()
	self.GenreTrackCache = {}
	self.PendingTrackRequests = {}
	self:ClearTrackButtons()
end

function Interface:SendPlayTrackRequest(genreName, trackName)
	if not self.ActiveInstance then
		return
	end

	if typeof(genreName) ~= "string" or genreName == "" then
		return
	end

	if typeof(trackName) ~= "string" or trackName == "" then
		return
	end

	PlayTrackEvent:Fire(self.ActiveInstance, genreName, trackName)
end

function Interface:UpdateTrackSelectionState()
	for trackName, info in pairs(self.TrackButtons or {}) do
		local isSelected = (self.ActiveTrackName ~= nil) and (trackName == self.ActiveTrackName)
		local button = info.Button
		if button then
			button:SetAttribute("IsSelected", isSelected)
			button.TextColor3 = isSelected and UIColors.White or UIColors.Text
			button.BackgroundColor3 = isSelected and UIColors.ButtonPressed or UIColors.Card
		end
		if info.Highlight then
			info.Highlight.Visible = isSelected
		end
	end
end

function Interface:GetCachedTracks(genreName)
	if not genreName then
		return nil
	end

	return self.GenreTrackCache and self.GenreTrackCache[genreName] or nil
end

function Interface:SetCachedTracks(genreName, trackNames)
	if not genreName then
		return
	end

	self.GenreTrackCache = self.GenreTrackCache or {}
	self.GenreTrackCache[genreName] = trackNames
end

function Interface:GetLibraryTracks(genreName)
	if not genreName then
		return nil
	end

	local library = getJukeboxLibrary()
	if not library then
		return nil
	end

	local folder = library:FindFirstChild(genreName)
	if not folder then
		return nil
	end

	local tracks = {}
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Sound") then
			table.insert(tracks, child.Name)
		end
	end

	if #tracks == 0 then
		return nil
	end

	table.sort(tracks)
	return tracks
end

function Interface:RenderTrackEntries(genreName, trackNames)
	local list = sanitizeTrackNames(trackNames)
	if #list == 0 then
		local message
		if genreName then
			message = string.format("%q has no songs.", genreName)
		else
			message = "No tracks available."
		end
		self:CreatePlaceholder(self.TrackList, message)
		self.TrackCount = 0
		self:UpdateNextButtonState()
		return
	end

	self.TrackCount = #list
	self.TrackButtons = self.TrackButtons or {}
	for _, trackName in ipairs(list) do
		local button = UIFactory.createTextButton(self.TrackList, {
			Name = "TrackButton_" .. trackName,
			Text = "• " .. trackName,
			Font = Enum.Font.Gotham,
			TextSize = 15,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 34),
		})
		styleTrackButton(button)
		button:SetAttribute("IsSelected", false)

		local indicator = UIFactory.createFrame(button, {
			Name = "Highlight",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.new(0, 4, 1, -8),
			ZIndex = button.ZIndex - 1,
			BackgroundColor3 = UIColors.Accent,
			Visible = false,
		})
		UIFactory.applyCorner(indicator, UDim.new(1, 0))

		local connections = {}
		connections[1] = button.MouseButton1Click:Connect(function()
			self:SendPlayTrackRequest(genreName, trackName)
		end)
		connections[2] = button.MouseEnter:Connect(function()
			if button:GetAttribute("IsSelected") then
				return
			end
			button.BackgroundColor3 = UIColors.ButtonHover
		end)
		connections[3] = button.MouseLeave:Connect(function()
			if button:GetAttribute("IsSelected") then
				return
			end
			button.BackgroundColor3 = UIColors.Card
		end)

		self.TrackButtons[trackName] = {
			Button = button,
			Highlight = indicator,
			Connections = connections,
		}
	end

	self:UpdateTrackSelectionState()
	self:UpdateNextButtonState()
end

function Interface:RequestTrackList(genreName)
	if not self.ActiveInstance or not genreName then
		return
	end

	self.PendingTrackRequests = self.PendingTrackRequests or {}
	if self.PendingTrackRequests[genreName] then
		return
	end

	self.PendingTrackRequests[genreName] = true
	RequestTracksEvent:Fire(self.ActiveInstance, genreName)
end

function Interface:HandleTrackListResponse(targetInstance, genreName, trackNames)
	if not genreName then
		return
	end

	if not self.ActiveComponent or self.ActiveComponent.Instance ~= targetInstance then
		return
	end

	if self.PendingTrackRequests then
		self.PendingTrackRequests[genreName] = nil
	end

	local sanitized = sanitizeTrackNames(trackNames)
	self:SetCachedTracks(genreName, sanitized)

	if self.SelectedGenre == genreName then
		self:RefreshTrackList(genreName)
	end
end

function Interface:Init()
	if self.Gui then
		return
	end

	local shell = UIFactory.createSidebar(PlayerGui, {
		Name = "JukeboxInterface",
		DisplayOrder = 40,
		RootSize = UDim2.new(0.34, 0, 0.72, 0),
		RootPosition = UDim2.new(1, -24, 0.18, 0),
		Colors = {
			Background = UIColors.Card,
			Header = UIColors.Header,
			ContainerStroke = UIColors.Stroke,
			Shadow = UIColors.Shadow,
		},
		HeaderHeight = HEADER_HEIGHT,
		Title = {
			Text = "Jukebox",
			Font = Enum.Font.GothamBold,
			TextSize = 28,
			TextColor3 = UIColors.White,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -140, 0, 32),
			Position = UDim2.new(0, PANEL_PADDING, 0, 12),
		},
		CloseButton = {
			AnchorPoint = Vector2.new(1, 0.5),
			Size = UDim2.new(0, 36, 0, 36),
			Position = UDim2.new(1, -PANEL_PADDING, 0.5, 0),
			BackgroundColor3 = UIColors.Button,
			Text = "X",
			TextSize = 20,
		},
	})

	self.Gui = shell.Gui
	self.Root = shell.Root
	self.Container = shell.Container
	self.Header = shell.Header
	self.CloseButton = shell.CloseButton
	self.Shadow = shell.Shadow
	self.TitleLabel = shell.TitleLabel
	self.Scale = shell.Scale

	self.Gui.Enabled = false
	self.Root.Visible = false
	if self.Shadow then
		self.Shadow.Visible = false
	end
	if self.Scale then
		self.Scale.Scale = 0
	end

	if self.CloseButton then
		styleControlButton(self.CloseButton)
		self.CloseButton.MouseButton1Click:Connect(function()
			self:Hide()
		end)
	end

	self.DeviceLabel = UIFactory.createTextLabel(self.Header, {
		Name = "DeviceLabel",
		Size = UDim2.new(1, -160, 0, 18),
		Position = UDim2.new(0, PANEL_PADDING, 0, 44),
		BackgroundTransparency = 1,
		Text = "",
		TextSize = 16,
		Font = Enum.Font.Gotham,
		TextColor3 = UIColors.TextSecondary,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	local headerHeight = (self.Header and self.Header.Size.Y.Offset) or HEADER_HEIGHT
	local topOffset = headerHeight + PANEL_PADDING
	local controlsOffset = topOffset + NOWPLAYING_HEIGHT + SECTION_GAP
	local bodyOffset = controlsOffset + CONTROL_HEIGHT + SECTION_GAP

	self.NowPlayingFrame = UIFactory.createFrame(self.Container, {
		Name = "NowPlaying",
		Size = UDim2.new(1, -(PANEL_PADDING * 2), 0, NOWPLAYING_HEIGHT),
		Position = UDim2.new(0, PANEL_PADDING, 0, topOffset),
		BackgroundColor3 = UIColors.BackgroundAlt,
	}, {
		Corner = UDim.new(0, 12),
	})

	self.NowPlayingLabel = UIFactory.createTextLabel(self.NowPlayingFrame, {
		Name = "Label",
		Text = "Now Playing",
		TextSize = 16,
		TextColor3 = UIColors.TextSecondary,
		Size = UDim2.new(1, -16, 0, 22),
		Position = UDim2.new(0, 12, 0, 8),
	})

	self.TrackLabel = UIFactory.createTextLabel(self.NowPlayingFrame, {
		Name = "Track",
		Text = "--",
		TextSize = 24,
		Font = Enum.Font.GothamBold,
		TextWrapped = true,
		Size = UDim2.new(1, -16, 0, 42),
		Position = UDim2.new(0, 12, 0, 34),
	})

	self.ControlBar = UIFactory.createFrame(self.Container, {
		Name = "Controls",
		Size = UDim2.new(1, -(PANEL_PADDING * 2), 0, CONTROL_HEIGHT),
		Position = UDim2.new(0, PANEL_PADDING, 0, controlsOffset),
		BackgroundColor3 = UIColors.BackgroundAlt,
	}, {
		Corner = UDim.new(0, 12),
	})

	self.ControlLayout = UIFactory.createUIListLayout(self.ControlBar, {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 12),
	})

	self.PlayButton = UIFactory.createTextButton(self.ControlBar, {
		Name = "Play",
		Size = UDim2.new(0, 120, 0, 38),
		Text = "Play",
	})
	styleControlButton(self.PlayButton)
	self.PlayButton.MouseButton1Click:Connect(function()
		if not self.ActiveInstance then
			return
		end
		TogglePlaybackEvent:Fire(self.ActiveInstance)
	end)

	self.NextButton = UIFactory.createTextButton(self.ControlBar, {
		Name = "Next",
		Size = UDim2.new(0, 120, 0, 38),
		Text = "Next",
	})
	styleControlButton(self.NextButton)
	self.NextButton.MouseButton1Click:Connect(function()
		if not self.ActiveInstance or not self.NextButton.Active then
			return
		end
		NextTrackEvent:Fire(self.ActiveInstance)
	end)

	self.ShuffleButton = UIFactory.createTextButton(self.ControlBar, {
		Name = "Shuffle",
		Size = UDim2.new(0, 120, 0, 38),
		Text = "Shuffle",
	})
	styleControlButton(self.ShuffleButton)
	self.ShuffleButton.MouseButton1Click:Connect(function()
		if not self.ActiveInstance then
			return
		end
		SetShuffleEvent:Fire(self.ActiveInstance, not self.ShuffleEnabled)
	end)

	self.Body = UIFactory.createFrame(self.Container, {
		Name = "Body",
		Position = UDim2.new(0, PANEL_PADDING, 0, bodyOffset),
		Size = UDim2.new(1, -(PANEL_PADDING * 2), 1, -(bodyOffset + PANEL_PADDING)),
		BackgroundTransparency = 1,
	})

	self.GenreColumn = UIFactory.createFrame(self.Body, {
		Name = "Genres",
		Size = UDim2.new(0.45, -6, 1, 0),
		BackgroundColor3 = UIColors.BackgroundAlt,
	}, {
		Corner = UDim.new(0, 12),
	})

	self.GenreLabel = UIFactory.createTextLabel(self.GenreColumn, {
		Text = "Genres",
		TextSize = 16,
		TextColor3 = UIColors.TextSecondary,
		Size = UDim2.new(1, -16, 0, 22),
		Position = UDim2.new(0, 12, 0, 8),
	})

	self.GenreList = UIFactory.createScrollingFrame(self.GenreColumn, {
		Name = "GenreList",
		Size = UDim2.new(1, -24, 1, -44),
		Position = UDim2.new(0, 12, 0, 36),
		BackgroundColor3 = UIColors.Card,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	})
	UIFactory.createUIPadding(self.GenreList, {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
	})
	self.GenreLayout = UIFactory.createUIListLayout(self.GenreList, {
		Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	})
	self.GenreLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		self.GenreList.CanvasSize = UDim2.new(0, 0, 0, self.GenreLayout.AbsoluteContentSize.Y + 12)
	end)

	self.TrackColumn = UIFactory.createFrame(self.Body, {
		Name = "Tracks",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0.55, -6, 1, 0),
		BackgroundColor3 = UIColors.BackgroundAlt,
	}, {
		Corner = UDim.new(0, 12),
	})

	self.TrackLabelHeader = UIFactory.createTextLabel(self.TrackColumn, {
		Text = "Tracks",
		TextSize = 16,
		TextColor3 = UIColors.TextSecondary,
		Size = UDim2.new(1, -16, 0, 22),
		Position = UDim2.new(0, 12, 0, 8),
	})

	self.TrackList = UIFactory.createScrollingFrame(self.TrackColumn, {
		Name = "TrackList",
		Size = UDim2.new(1, -24, 1, -44),
		Position = UDim2.new(0, 12, 0, 36),
		BackgroundColor3 = UIColors.Card,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	})
	UIFactory.createUIPadding(self.TrackList, {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
	})
	self.TrackLayout = UIFactory.createUIListLayout(self.TrackList, {
		Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
	})
	self.TrackLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		self.TrackList.CanvasSize = UDim2.new(0, 0, 0, self.TrackLayout.AbsoluteContentSize.Y + 12)
	end)

	local library = getJukeboxLibrary()
	if library then
		library.ChildAdded:Connect(function()
			if self.Gui.Enabled then
				self:RefreshGenres(self.SelectedGenre)
			end
		end)
		library.ChildRemoved:Connect(function()
			if self.Gui.Enabled then
				self:RefreshGenres(self.SelectedGenre)
			end
		end)
	end
end

function Interface:DisconnectAttributeConnections()
	for _, connection in ipairs(self.AttributeConnections) do
		connection:Disconnect()
	end
	self.AttributeConnections = {}
end

function Interface:BindToInstance(instance)
	self:DisconnectAttributeConnections()
	self.ActiveInstance = instance

	if not instance then
		self:SetTrackName(nil)
		self:SetPlaybackState(false)
		self:SetShuffleState(false)
		return
	end

	local function bindAttribute(attribute, callback)
		local connection = instance:GetAttributeChangedSignal(attribute):Connect(function()
			callback(instance:GetAttribute(attribute))
		end)
		table.insert(self.AttributeConnections, connection)
		callback(instance:GetAttribute(attribute))
	end

	bindAttribute("JukeboxTrack", function(value)
		self:SetTrackName(value)
	end)

	bindAttribute("JukeboxGenre", function(value)
		self:SetActiveGenre(value)
	end)

	bindAttribute("JukeboxEnabled", function(value)
		self:SetPlaybackState(value == true)
	end)

	bindAttribute("JukeboxShuffle", function(value)
		self:SetShuffleState(value == true)
	end)
end

function Interface:ClearGenreButtons()
	for _, info in pairs(self.GenreButtons) do
		if info.Connections then
			for _, connection in ipairs(info.Connections) do
				connection:Disconnect()
			end
		end
		if info.Button then
			info.Button:Destroy()
		end
	end
	self.GenreButtons = {}
end

function Interface:AddGenreButton(genreName)
	local button = UIFactory.createTextButton(self.GenreList, {
		Name = genreName,
		Size = UDim2.new(1, 0, 0, 34),
		Text = genreName,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UIColors.TextSecondary,
		BackgroundColor3 = UIColors.Button,
		AutoButtonColor = false,
		ClipsDescendants = true,
	})
	button:SetAttribute("IsSelected", false)
	button.Active = true
	UIFactory.applyCorner(button, UDim.new(0, 10))
	UIFactory.applyStroke(button, {
		Color = UIColors.Stroke,
		Thickness = 1,
		Transparency = 0.6,
	})
	UIFactory.createUIPadding(button, {
		PaddingLeft = UDim.new(0, 12),
	})

	local indicator = UIFactory.createFrame(button, {
		Name = "Highlight",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(0, 4, 1, -8),
		ZIndex = button.ZIndex - 1,
		BackgroundColor3 = UIColors.Accent,
		Visible = false,
	}, {
		Corner = UDim.new(1, 0),
	})

	local connections = {}
	connections[1] = button.MouseButton1Click:Connect(function()
		if not self.ActiveInstance then
			return
		end
		self:SetActiveGenre(genreName)
		SetGenreEvent:Fire(self.ActiveInstance, genreName)
	end)
	connections[2] = button.MouseEnter:Connect(function()
		if not button.Active or button:GetAttribute("IsSelected") then
			return
		end
		button.BackgroundColor3 = UIColors.ButtonHover
	end)
	connections[3] = button.MouseLeave:Connect(function()
		if not button.Active or button:GetAttribute("IsSelected") then
			return
		end
		button.BackgroundColor3 = UIColors.Button
	end)

	self.GenreButtons[genreName] = {
		Button = button,
		Highlight = indicator,
		Connections = connections,
	}
end

function Interface:CreatePlaceholder(parent, text)
	local placeholder = UIFactory.createTextLabel(parent, {
		Name = "Placeholder",
		Text = text,
		TextWrapped = true,
		TextSize = 14,
		TextColor3 = UIColors.TextSecondary,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 0, 60),
	})
	return placeholder
end

function Interface:RefreshGenres(preferredGenre)
	self:ClearGenreButtons()
	self:ResetTrackCaches()

	for _, child in ipairs(self.GenreList:GetChildren()) do
		if child:IsA("GuiObject") and child.Name == "Placeholder" then
			child:Destroy()
		end
	end

	local library = getJukeboxLibrary()

	if not library then
		self:CreatePlaceholder(self.GenreList, "No jukebox assets found.")
		self:SetActiveGenre(nil)
		return
	end

	local genreNames = {}
	for _, folder in ipairs(library:GetChildren()) do
		if folder:IsA("Folder") then
			table.insert(genreNames, folder.Name)
		end
	end

	table.sort(genreNames)

	if #genreNames == 0 then
		self:CreatePlaceholder(self.GenreList, "Drop folders into Assets/Sounds/Jukebox to add playlists.")
		self:SetActiveGenre(nil)
		return
	end

	for _, name in ipairs(genreNames) do
		self:AddGenreButton(name)
	end

	local initialGenre = preferredGenre
	if not initialGenre or not self.GenreButtons[initialGenre] then
		initialGenre = genreNames[1]
	end

	self:SetActiveGenre(initialGenre)
end

function Interface:RefreshTrackList(genreName)
	self:ClearTrackButtons()
	for _, child in ipairs(self.TrackList:GetChildren()) do
		if child:IsA("GuiObject") and child.Name ~= "UIListLayout" then
			child:Destroy()
		end
	end

	self.TrackCount = 0

	if not genreName then
		self:CreatePlaceholder(self.TrackList, "Select a genre to preview songs.")
		self:UpdateNextButtonState()
		return
	end

	local cachedTracks = self:GetCachedTracks(genreName)
	if cachedTracks then
		self:RenderTrackEntries(genreName, cachedTracks)
		return
	end

	local libraryTracks = self:GetLibraryTracks(genreName)
	if libraryTracks then
		self:SetCachedTracks(genreName, libraryTracks)
		self:RenderTrackEntries(genreName, libraryTracks)
		return
	end

	if not self.ActiveInstance then
		self:CreatePlaceholder(self.TrackList, "Loading track list...")
		self:UpdateNextButtonState()
		return
	end

	self:CreatePlaceholder(self.TrackList, string.format("Fetching tracks for \"%s\"...", genreName))
	self:UpdateNextButtonState()
	self:RequestTrackList(genreName)
end

function Interface:SetActiveGenre(genreName)
	self.SelectedGenre = genreName

	for name, info in pairs(self.GenreButtons) do
		local isSelected = (name == genreName)
		if info.Highlight then
			info.Highlight.Visible = isSelected
		end
		if info.Button then
			info.Button:SetAttribute("IsSelected", isSelected)
			info.Button.TextColor3 = isSelected and UIColors.White or UIColors.TextSecondary
			info.Button.BackgroundColor3 = isSelected and UIColors.ButtonPressed or UIColors.Button
		end
	end

	self:RefreshTrackList(genreName)
end

function Interface:SetTrackName(trackName)
	if trackName == "" then
		trackName = nil
	end

	self.ActiveTrackName = trackName
	self.TrackLabel.Text = trackName or "--"
	self:UpdateTrackSelectionState()
end

function Interface:UpdateNextButtonState()
	local enabled = self.Playing and self.TrackCount > 1
	self.NextButton.Active = enabled
	self.NextButton.AutoButtonColor = enabled
	self.NextButton.TextTransparency = enabled and 0 or 0.3
	self.NextButton.BackgroundTransparency = enabled and 0 or 0.2
end

function Interface:SetPlaybackState(isEnabled)
	self.Playing = isEnabled
	self.PlayButton.Text = isEnabled and "Pause" or "Play"
	self:UpdateNextButtonState()
end

function Interface:SetShuffleState(isEnabled)
	self.ShuffleEnabled = isEnabled
	self.ShuffleButton.Text = isEnabled and "Shuffle • On" or "Shuffle • Off"
	self.ShuffleButton.TextColor3 = isEnabled and UIColors.Accent or UIColors.White
end

function Interface:Show(component)
	if not component or not component.Instance then
		return
	end

	self:Init()

	self.ActiveComponent = component
	self:ResetTrackCaches()
	self.Gui.Enabled = true
	self.Root.Visible = true
	if self.Shadow then
		self.Shadow.Visible = true
	end
	if self.Scale then
		self.Scale.Scale = 1
	end

	local label = component.Instance:GetAttribute("JukeboxLabel") or component.Instance.Name
	self.DeviceLabel.Text = label

	self:BindToInstance(component.Instance)
	self:RefreshGenres(component.Instance:GetAttribute("JukeboxGenre"))
end

function Interface:Hide()
	if not self.Gui then
		return
	end

	self.Gui.Enabled = false
	self.Root.Visible = false
	if self.Shadow then
		self.Shadow.Visible = false
	end
	if self.Scale then
		self.Scale.Scale = 0
	end
	self.ActiveComponent = nil
	self.SelectedGenre = nil
	self.ActiveTrackName = nil
	self:ResetTrackCaches()
	self:BindToInstance(nil)
end

function Interface:IsActive(component)
	return self.Gui and self.Gui.Enabled and self.ActiveComponent == component
end

RequestTracksEvent.Event:Connect(function(targetInstance, genreName, trackNames)
	Interface:HandleTrackListResponse(targetInstance, genreName, trackNames)
end)

return Interface
