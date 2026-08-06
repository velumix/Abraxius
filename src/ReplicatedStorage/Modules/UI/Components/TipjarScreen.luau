local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local UIColors = require(Modules.UI.UIColors)
local UIAudio = require(Modules.UI.UIAudio)
local UIFactory = require(Modules.UI.UIFactory)

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local ROBUX_PREFIX = ""
local MAX_ACTIVITY_ENTRIES = 10
local SHOW_TWEEN = TweenInfo.new(0.34, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local HIDE_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local OVERLAY_TWEEN = TweenInfo.new(0.24, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local ROW_TWEEN = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local ROW_STAGGER = 0.035
local SHOW_OFFSET_Y = 28

local function formatRobux(amount)
	local value = math.floor(tonumber(amount) or 0)
	local formatted = tostring(value)
	while true do
		local updated, replacements = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		formatted = updated
		if replacements == 0 then
			break
		end
	end
	return formatted
end

local function cloneArray(values)
	local copy = {}
	if values then
		for index, value in ipairs(values) do
			copy[index] = value
		end
	end
	return copy
end

local function defaultLedger()
	return {
		totalReceived = 0,
		viewerTotal = 0,
		recent = {},
	}
end

local function bindButtonEffects(button)
	if not button or not button:IsA("GuiButton") then
		return
	end

	local defaultColor = button.BackgroundColor3
	local hoverColor = UIColors.ButtonHover or defaultColor
	local pressedColor = UIColors.ButtonPressed or defaultColor

	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = hoverColor,
		}):Play()
	end)

	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = defaultColor,
		}):Play()
	end)

	button.MouseButton1Down:Connect(function()
		button.BackgroundColor3 = pressedColor
	end)

	button.MouseButton1Up:Connect(function()
		button.BackgroundColor3 = hoverColor
	end)
end

local function offsetPosition(position: UDim2, yOffset: number): UDim2
	return UDim2.new(position.X.Scale, position.X.Offset, position.Y.Scale, position.Y.Offset + yOffset)
end

local function getOrCreateScale(parent: Instance, name: string, defaultScale: number): UIScale
	local scale = parent:FindFirstChild(name)
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = name
		scale.Parent = parent
	end
	scale.Scale = defaultScale
	return scale
end

local function trackTween(screen, tween)
	screen.ActiveTweens = screen.ActiveTweens or {}
	table.insert(screen.ActiveTweens, tween)
	tween.Completed:Once(function()
		local activeTweens = screen.ActiveTweens
		if not activeTweens then
			return
		end
		local index = table.find(activeTweens, tween)
		if index then
			table.remove(activeTweens, index)
		end
	end)
	tween:Play()
	return tween
end

local function cancelActiveTweens(screen)
	if not screen.ActiveTweens then
		return
	end
	for _, tween in ipairs(screen.ActiveTweens) do
		tween:Cancel()
	end
	table.clear(screen.ActiveTweens)
end

local TipjarScreen = {
	Showing = false,
	ListingCards = {},
	ActivityEntries = {},
	State = {
		listings = {},
		ledger = defaultLedger(),
		loading = false,
		target = nil,
		editing = false,
	},
}

function TipjarScreen:BuildInterface()
	if self.Gui and self.CustomAddFrame then
		return
	end

	local gui = PlayerGui:FindFirstChild("TipjarScreen") or PlayerGui:WaitForChild("TipjarScreen", 5)
	if not gui then
		warn("TipjarScreen: missing ScreenGui in PlayerGui")
		return
	end

	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	if gui.DisplayOrder == 0 then
		gui.DisplayOrder = 75
	end
	gui.Enabled = false

	local overlay = gui:FindFirstChild("Overlay")
	local container = gui:FindFirstChild("Container")
	if not container then
		warn("TipjarScreen: missing Container frame")
		return
	end
	container.Visible = false
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.Position = UDim2.new(0.5, 0, 0.5, 0)
	if overlay then
		overlay.BackgroundTransparency = 1
	end

	local header = container:FindFirstChild("Header")
	local summaryFrame = container:FindFirstChild("Summary")
	local statusLabel = container:FindFirstChild("Status")
	local bodyFrame = container:FindFirstChild("Body")
	local listingsFrame = bodyFrame and bodyFrame:FindFirstChild("Listings")
	local activityFrame = bodyFrame and bodyFrame:FindFirstChild("Activity")

	local listingsLayout
	if listingsFrame then
		listingsLayout = listingsFrame:FindFirstChild("Layout")
		if not listingsLayout then
			local layout = Instance.new("UIListLayout")
			layout.Name = "Layout"
			layout.SortOrder = Enum.SortOrder.LayoutOrder
			layout.Padding = UDim.new(0, 10)
			layout.Parent = listingsFrame
			listingsLayout = layout
		end
	end

	local activityLayout
	if activityFrame then
		activityLayout = activityFrame:FindFirstChild("Layout")
		if not activityLayout then
			local layout = Instance.new("UIListLayout")
			layout.Name = "Layout"
			layout.SortOrder = Enum.SortOrder.LayoutOrder
			layout.Padding = UDim.new(0, 6)
			layout.Parent = activityFrame
			activityLayout = layout
		end
		if not activityFrame:FindFirstChild("ActivityTitle") then
			UIFactory.createTextLabel(activityFrame, {
				Name = "ActivityTitle",
				Text = "Recent",
				Font = Enum.Font.GothamBold,
				TextSize = 15,
				LayoutOrder = 0,
				TextColor3 = UIColors.Text,
			})
		end
	end

	local loadingLabel
	if listingsFrame then
		loadingLabel = listingsFrame:FindFirstChild("Loading")
		if not loadingLabel then
			loadingLabel = UIFactory.createTextLabel(listingsFrame, {
				Name = "Loading",
				Size = UDim2.new(1, -10, 0, 40),
				Font = Enum.Font.GothamSemibold,
				TextSize = 16,
				Text = "Fetching donations...",
				TextColor3 = UIColors.TextSecondary,
				TextXAlignment = Enum.TextXAlignment.Center,
				LayoutOrder = -1,
				Visible = false,
			})
		end
	end

	local customAddFrame
	local customAddInput
	local customAddButton
	if listingsFrame then
		customAddFrame = listingsFrame:FindFirstChild("CustomAdd")
		if not customAddFrame then
			customAddFrame = UIFactory.createFrame(listingsFrame, {
				Name = "CustomAdd",
				Size = UDim2.new(1, -10, 0, 42),
				BackgroundColor3 = UIColors.Card,
				BackgroundTransparency = 0.2,
				LayoutOrder = -2,
				Visible = false,
			}, {
				Corner = UDim.new(0, 10),
				Stroke = {
					Color = UIColors.Border,
					Transparency = 0.4,
				},
				Padding = {
					PaddingLeft = UDim.new(0, 10),
					PaddingRight = UDim.new(0, 10),
				},
			})
		end

		customAddInput = customAddFrame:FindFirstChild("Input") :: TextBox
		if not customAddInput then
			customAddInput = Instance.new("TextBox")
			customAddInput.Name = "Input"
			customAddInput.Size = UDim2.new(1, -110, 1, 0)
			customAddInput.Position = UDim2.new(0, 0, 0, 0)
			customAddInput.BackgroundTransparency = 1
			customAddInput.ClearTextOnFocus = false
			customAddInput.PlaceholderText = "Enter game pass ID"
			customAddInput.Text = ""
			customAddInput.Font = Enum.Font.Gotham
			customAddInput.TextSize = 14
			customAddInput.TextColor3 = UIColors.Text
			customAddInput.PlaceholderColor3 = UIColors.TextSecondary
			customAddInput.TextXAlignment = Enum.TextXAlignment.Left
			customAddInput.Parent = customAddFrame
		end

		customAddButton = customAddFrame:FindFirstChild("AddButton") :: TextButton
		if not customAddButton then
			customAddButton = UIFactory.createTextButton(customAddFrame, {
				Name = "AddButton",
				AnchorPoint = Vector2.new(1, 0.5),
				Size = UDim2.new(0, 90, 0, 28),
				Position = UDim2.new(1, 0, 0.5, 0),
				BackgroundColor3 = UIColors.Accent,
				Text = "Add",
				TextSize = 14,
			}, {
				Corner = UDim.new(0, 8),
			})
		end
	end

	local closeButton = header and header:FindFirstChild("CloseButton")
	if closeButton and closeButton:IsA("GuiButton") and not self.CloseButtonBound then
		bindButtonEffects(closeButton)
		closeButton.MouseButton1Click:Connect(function()
			UIAudio.PlayNotification("Close")
			TipjarScreen.Hide("CloseButton")
		end)
		self.CloseButtonBound = true
	end

	self.Gui = gui
	self.Overlay = overlay
	self.Container = container
	self.ContainerDefaultPosition = container and container.Position or UDim2.new(0.5, -290, 0.5, -220)
	self.ContainerDefaultSize = container and container.Size or UDim2.new(0, 580, 0, 440)
	self.ContainerScale = container and getOrCreateScale(container, "PresentationScale", 1)

	if container then
		self.ContainerHiddenPosition = offsetPosition(self.ContainerDefaultPosition, SHOW_OFFSET_Y)
	else
		self.ContainerHiddenPosition = offsetPosition(self.ContainerDefaultPosition, SHOW_OFFSET_Y)
	end
	self.HeaderTitle = header and header:FindFirstChild("Title")
	self.HeaderSubtitle = header and header:FindFirstChild("Subtitle")
	self.SummaryFrame = summaryFrame
	self.TotalValue = summaryFrame and summaryFrame:FindFirstChild("TotalValue")
	self.ViewerValue = summaryFrame and summaryFrame:FindFirstChild("ViewerValue")
	self.StatusLabel = statusLabel
	self.ListingsFrame = listingsFrame
	self.ListingsLayout = listingsLayout
	self.ActivityFrame = activityFrame
	self.ActivityLayout = activityLayout
	self.LoadingLabel = loadingLabel
	self.CustomAddFrame = customAddFrame
	self.CustomAddInput = customAddInput
	self.CustomAddButton = customAddButton
	self.CustomAddConnections = self.CustomAddConnections or {}
	self.ListingCards = {}

	if self.CustomAddButton and self.CustomAddInput and #self.CustomAddConnections == 0 then
		table.insert(self.CustomAddConnections, self.CustomAddButton.MouseButton1Click:Connect(function()
			UIAudio.PlayNotification("Click")
			if TipjarScreen.OnAddListing then
				TipjarScreen.OnAddListing(self.CustomAddInput.Text)
			end
		end))

		table.insert(self.CustomAddConnections, self.CustomAddInput.FocusLost:Connect(function(enterPressed)
			if not enterPressed then
				return
			end
			if TipjarScreen.OnAddListing then
				TipjarScreen.OnAddListing(self.CustomAddInput.Text)
			end
		end))
	end

	if self.CustomAddFrame then
		self.CustomAddFrame.Visible = self.State.editing == true
	end
end

function TipjarScreen:SetStatus(text, statusType)
	if not self.StatusLabel then
		return
	end

	local label = self.StatusLabel
	label.Text = text or ""
	if statusType == "error" then
		label.TextColor3 = UIColors.Error
	elseif statusType == "success" then
		label.TextColor3 = UIColors.Success
	else
		label.TextColor3 = UIColors.TextSecondary
	end
end

function TipjarScreen:SetLedger(ledger)
	local current = ledger or defaultLedger()
	self.State.ledger = current

	if self.TotalValue then
		self.TotalValue.Text = ROBUX_PREFIX .. formatRobux(current.totalReceived or 0)
	end

	if self.ViewerValue then
		self.ViewerValue.Text = "You: " .. ROBUX_PREFIX .. formatRobux(current.viewerTotal or 0)
	end

	if current.recent then
		self:RenderActivity(current.recent)
	else
		self:RenderActivity({})
	end
end

function TipjarScreen:SetTarget(target)
	self.State.target = target
	if not self.HeaderSubtitle then
		return
	end

	if target then
		local name = target.name or ("User " .. target.userId)
		self.HeaderSubtitle.Text = string.format("Donating to %s", name)
	else
		self.HeaderSubtitle.Text = ""
	end
end

function TipjarScreen:SetLoading(isLoading)
	self.State.loading = isLoading
	if self.LoadingLabel then
		self.LoadingLabel.Visible = not not isLoading
	end
end

function TipjarScreen:SetEditing(isEditing)
	self.State.editing = not not isEditing
	if self.CustomAddFrame then
		self.CustomAddFrame.Visible = self.State.editing and TipjarScreen.OnAddListing ~= nil
	end
end

function TipjarScreen:SetAddListingPending(isPending)
	if self.CustomAddButton then
		self.CustomAddButton.Active = not isPending
		self.CustomAddButton.AutoButtonColor = not isPending
		self.CustomAddButton.Text = isPending and "Adding..." or "Add"
	end
	if self.CustomAddInput then
		self.CustomAddInput.Active = not isPending
	end
end

function TipjarScreen:ClearAddListingInput()
	if self.CustomAddInput then
		self.CustomAddInput.Text = ""
	end
end

function TipjarScreen:ClearListings()
	for _, card in ipairs(self.ListingCards) do
		if card.Connections then
			for _, connection in ipairs(card.Connections) do
				connection:Disconnect()
			end
		end
		if card.Frame then
			card.Frame:Destroy()
		end
	end
	self.ListingCards = {}
end

function TipjarScreen:RenderListings(listings)
	self.State.listings = listings or {}
	if not self.ListingsFrame then
		return
	end

	self:ClearListings()
	if self.LoadingLabel then
		self.LoadingLabel.Visible = false
	end

	if not listings or #listings == 0 then
		self:SetStatus("No donation products were found", "info")
		return
	end

	if self.State.editing then
		self:SetStatus("Click a tier to toggle its visibility", "info")
	else
		self:SetStatus("Select a tier to donate", "info")
	end

	for index, listing in ipairs(listings) do
		local isEditing = self.State.editing
		local isVisible = listing.Visible ~= false
		local frame = UIFactory.createTextButton(self.ListingsFrame, {
			Name = "Listing" .. listing.Id,
			Size = UDim2.new(1, -10, 0, 78),
			BackgroundColor3 = UIColors.Button,
			AutoButtonColor = false,
			Text = "",
			LayoutOrder = index,
		}, {
			Corner = UDim.new(0, 10),
			Stroke = {
				Color = UIColors.Border,
				Transparency = 0.35,
			},
		})
		local rowScale = getOrCreateScale(frame, "PresentationScale", TipjarScreen.Showing and 0.965 or 1)

		local nameLabel = UIFactory.createTextLabel(frame, {
			Name = "Name",
			Size = UDim2.new(0.6, -10, 0, 24),
			Position = UDim2.new(0, 14, 0, 10),
			Font = Enum.Font.GothamSemibold,
			TextSize = 18,
			Text = listing.Name or ("Pass " .. listing.Id),
			TextColor3 = UIColors.Text,
		})

		local priceLabel = UIFactory.createTextLabel(frame, {
			Name = "Price",
			Size = UDim2.new(0.4, -10, 0, 32),
			Position = UDim2.new(0.6, 0, 0, 20),
			Font = Enum.Font.GothamSemibold,
			TextSize = 20,
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = ROBUX_PREFIX .. formatRobux(listing.Price),
			TextColor3 = UIColors.Accent,
		})

		local stateTag
		if isEditing then
			stateTag = UIFactory.createTextLabel(frame, {
				Name = "State",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -14, 0, 10),
				Size = UDim2.new(0, 80, 0, 20),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamSemibold,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = UIColors.TextSecondary,
				Text = isVisible and "Visible" or "Hidden",
			})
		end

		local card = {
			Frame = frame,
			Listing = listing,
			ProductType = listing.ProductType,
			Connections = {},
			StateTag = stateTag,
			Scale = rowScale,
		}

		local function updateState()
			local owned = listing.Owned
			local visibleState = listing.Visible ~= false
			if owned then
				frame.Active = false
				frame.BackgroundColor3 = UIColors.Disabled
				priceLabel.TextColor3 = UIColors.TextDark
				nameLabel.TextColor3 = UIColors.TextDark
				priceLabel.Text = "Owned"
				if stateTag then
					stateTag.Text = "Owned"
				end
			elseif isEditing then
				frame.Active = true
				if visibleState then
					frame.BackgroundColor3 = UIColors.Button
					priceLabel.TextColor3 = UIColors.Accent
					priceLabel.Text = ROBUX_PREFIX .. formatRobux(listing.Price)
					nameLabel.TextColor3 = UIColors.Text
					if stateTag then
						stateTag.Text = "Visible"
						stateTag.TextColor3 = UIColors.Success
					end
				else
					frame.BackgroundColor3 = UIColors.Disabled
					priceLabel.TextColor3 = UIColors.TextDark
					priceLabel.Text = "Hidden"
					nameLabel.TextColor3 = UIColors.TextSecondary
					if stateTag then
						stateTag.Text = "Hidden"
						stateTag.TextColor3 = UIColors.TextSecondary
					end
				end
			else
				frame.Active = true
				frame.BackgroundColor3 = UIColors.Button
				priceLabel.TextColor3 = UIColors.Accent
				nameLabel.TextColor3 = UIColors.Text
				priceLabel.Text = ROBUX_PREFIX .. formatRobux(listing.Price)
				if stateTag then
					stateTag.Text = "Visible"
				end
			end
		end

		local function setPending(isPending)
			card.Pending = isPending
			if isPending then
				frame.Active = false
				if stateTag then
					stateTag.Text = "Saving..."
					stateTag.TextColor3 = UIColors.TextSecondary
				end
			else
				updateState()
			end
		end

		updateState()

		local hoverEnter = frame.MouseEnter:Connect(function()
			if not frame.Active then
				return
			end
			TweenService:Create(frame, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundColor3 = UIColors.ButtonHover,
			}):Play()
			TweenService:Create(rowScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Scale = 1.015,
			}):Play()
		end)

		local hoverLeave = frame.MouseLeave:Connect(function()
			if not frame.Active then
				return
			end
			TweenService:Create(frame, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundColor3 = UIColors.Button,
			}):Play()
			TweenService:Create(rowScale, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Scale = 1,
			}):Play()
		end)

		local activated = frame.MouseButton1Click:Connect(function()
			if not frame.Active then
				return
			end
			UIAudio.PlayNotification("Click")
			if TipjarScreen.OnDonate then
				TipjarScreen.OnDonate(listing)
			end
		end)

		card.Connections = {hoverEnter, hoverLeave, activated}
		card.UpdateState = updateState
		card.SetPending = setPending
		table.insert(self.ListingCards, card)

		if self.Showing then
			task.delay((index - 1) * ROW_STAGGER, function()
				if frame.Parent and rowScale.Parent and self.Showing then
					trackTween(self, TweenService:Create(rowScale, ROW_TWEEN, {
						Scale = 1,
					}))
				end
			end)
		end
	end
end

function TipjarScreen:MarkListingOwned(listingId)
	for _, card in ipairs(self.ListingCards) do
		if card.Listing and card.Listing.Id == listingId then
			card.Listing.Owned = true
			if card.UpdateState then
				card.UpdateState()
			end
		end
	end
end

function TipjarScreen:SetListingVisibility(listingId, productType, isVisible)
	for _, card in ipairs(self.ListingCards) do
		if card.Listing and card.Listing.Id == listingId and card.ProductType == productType then
			card.Listing.Visible = isVisible ~= false
			if card.UpdateState then
				card.UpdateState()
			end
			break
		end
	end
end

function TipjarScreen:SetListingPending(listingId, productType, isPending)
	for _, card in ipairs(self.ListingCards) do
		if card.Listing and card.Listing.Id == listingId and card.ProductType == productType then
			if card.SetPending then
				card.SetPending(isPending)
			else
				card.Frame.Active = not isPending
			end
			break
		end
	end
end

function TipjarScreen:RenderActivity(entries)
	entries = entries or {}
	self.ActivityEntries = entries

	if not self.ActivityFrame then
		return
	end

	for _, child in ipairs(self.ActivityFrame:GetChildren()) do
		if child:IsA("TextLabel") and child.Name == "Entry" then
			child:Destroy()
		end
	end

	local layoutOrder = 1
	for _, entry in ipairs(entries) do
		local donorName = entry.donorName or ("User " .. entry.donorUserId)
		local shortName = (#donorName > 20) and (donorName:sub(1, 18) .. "…") or donorName
		local amount = ROBUX_PREFIX .. formatRobux(entry.amount or 0)

		UIFactory.createTextLabel(self.ActivityFrame, {
			Name = "Entry",
			LayoutOrder = layoutOrder,
			Text = string.format("%s gave %s", shortName, amount),
			Font = Enum.Font.Gotham,
			TextSize = 14,
			TextColor3 = UIColors.TextSecondary,
		})

		layoutOrder += 1
	end

	if layoutOrder == 1 then
		UIFactory.createTextLabel(self.ActivityFrame, {
			Name = "Entry",
			LayoutOrder = layoutOrder,
			Text = "No recent donations",
			Font = Enum.Font.Gotham,
			TextSize = 14,
			TextColor3 = UIColors.TextSecondary,
			TextTransparency = 0.35,
		})
	end
end

function TipjarScreen:PushActivity(entry)
	local entries = cloneArray(self.ActivityEntries)
	table.insert(entries, 1, entry)
	while #entries > MAX_ACTIVITY_ENTRIES do
		table.remove(entries)
	end
	self:RenderActivity(entries)
end

function TipjarScreen.Show(options)
	options = options or {}
	TipjarScreen:BuildInterface()

	TipjarScreen.OnDonate = options.onDonate
	TipjarScreen.OnClose = options.onClose
	TipjarScreen.OnAddListing = options.onAddListing
	TipjarScreen:SetEditing(options.editing)

	TipjarScreen:SetTarget(options.target)
	TipjarScreen:SetLedger(options.ledger)
	TipjarScreen:SetLoading(options.isLoading)

	if options.status then
		TipjarScreen:SetStatus(options.status.text, options.status.kind)
	else
		TipjarScreen:SetStatus("Select a tier to donate", "info")
	end

	if options.listings then
		TipjarScreen:RenderListings(options.listings)
	else
		TipjarScreen:ClearListings()
	end

	if not TipjarScreen.Gui or not TipjarScreen.Container then
		return
	end

	local container = TipjarScreen.Container
	if not TipjarScreen.ContainerDefaultSize then
		TipjarScreen.ContainerDefaultSize = container.Size
	end
	if not TipjarScreen.ContainerDefaultPosition then
		TipjarScreen.ContainerDefaultPosition = container.Position
	end
	local defaultSize = TipjarScreen.ContainerDefaultSize or container.Size
	local defaultPosition = TipjarScreen.ContainerDefaultPosition or container.Position
	local hiddenPosition = TipjarScreen.ContainerHiddenPosition or UDim2.new(0.5, 0, 0.5, 0)
	local containerScale = TipjarScreen.ContainerScale or getOrCreateScale(container, "PresentationScale", 1)

	cancelActiveTweens(TipjarScreen)
	TipjarScreen.Gui.Enabled = true
	container.Visible = true
	container.Size = defaultSize
	container.Position = hiddenPosition
	containerScale.Scale = 0.94

	trackTween(TipjarScreen, TweenService:Create(container, SHOW_TWEEN, {
		Position = defaultPosition,
	}))
	trackTween(TipjarScreen, TweenService:Create(containerScale, SHOW_TWEEN, {
		Scale = 1,
	}))

	if TipjarScreen.Overlay then
		TipjarScreen.Overlay.BackgroundTransparency = 1
		trackTween(TipjarScreen, TweenService:Create(TipjarScreen.Overlay, OVERLAY_TWEEN, {
			BackgroundTransparency = 0.35,
		}))
	end

	TipjarScreen.Showing = true
	for index, card in ipairs(TipjarScreen.ListingCards) do
		local scale = card.Scale
		if scale then
			scale.Scale = 0.965
			task.delay((index - 1) * ROW_STAGGER, function()
				if card.Frame and card.Frame.Parent and scale.Parent and TipjarScreen.Showing then
					trackTween(TipjarScreen, TweenService:Create(scale, ROW_TWEEN, {
						Scale = 1,
					}))
				end
			end)
		end
	end

	if TipjarScreen.Interface and TipjarScreen.Interface.ScreenShown then
		TipjarScreen.Interface.ScreenShown:Fire("TipjarScreen", true)
	end
end

function TipjarScreen.Update(options)
	if not TipjarScreen.Showing then
		return
	end
	options = options or {}

	if options.target then
		TipjarScreen:SetTarget(options.target)
	end
	if options.ledger then
		TipjarScreen:SetLedger(options.ledger)
	end
	if options.listings then
		TipjarScreen:RenderListings(options.listings)
	end
	if options.status then
		TipjarScreen:SetStatus(options.status.text, options.status.kind)
	end
	if options.isLoading ~= nil then
		TipjarScreen:SetLoading(options.isLoading)
	end
end

function TipjarScreen.Hide(reason)
	if not TipjarScreen.Gui or not TipjarScreen.Container then
		return
	end

	TipjarScreen.Showing = false
	TipjarScreen.OnDonate = nil
	TipjarScreen.OnAddListing = nil
	local closeCallback = TipjarScreen.OnClose
	TipjarScreen.OnClose = nil

	local container = TipjarScreen.Container
	if not TipjarScreen.ContainerDefaultSize then
		TipjarScreen.ContainerDefaultSize = container.Size
	end
	if not TipjarScreen.ContainerDefaultPosition then
		TipjarScreen.ContainerDefaultPosition = container.Position
	end
	local defaultSize = TipjarScreen.ContainerDefaultSize or (container and container.Size)
	local defaultPosition = TipjarScreen.ContainerDefaultPosition or (container and container.Position)
	local hiddenPosition = TipjarScreen.ContainerHiddenPosition or UDim2.new(0.5, 0, 0.5, 0)
	local containerScale = TipjarScreen.ContainerScale or getOrCreateScale(container, "PresentationScale", 1)

	cancelActiveTweens(TipjarScreen)
	local hideTween = TweenService:Create(container, HIDE_TWEEN, {
		Position = hiddenPosition,
	})

	hideTween.Completed:Connect(function()
		if TipjarScreen.Gui then
			TipjarScreen.Gui.Enabled = false
		end
		if container then
			container.Visible = false
			container.Size = defaultSize or container.Size
			container.Position = defaultPosition or container.Position
		end
		if containerScale then
			containerScale.Scale = 1
		end
		if TipjarScreen.Overlay then
			TipjarScreen.Overlay.BackgroundTransparency = 0.35
		end
	end)

	trackTween(TipjarScreen, hideTween)
	trackTween(TipjarScreen, TweenService:Create(containerScale, HIDE_TWEEN, {
		Scale = 0.96,
	}))

	if TipjarScreen.Overlay then
		trackTween(TipjarScreen, TweenService:Create(TipjarScreen.Overlay, OVERLAY_TWEEN, {
			BackgroundTransparency = 1,
		}))
	end

	if TipjarScreen.Interface and TipjarScreen.Interface.ScreenShown then
		TipjarScreen.Interface.ScreenShown:Fire("TipjarScreen", false)
	end

	if closeCallback then
		closeCallback(reason or "Hide")
	end
end

TipjarScreen.Destroying = TipjarScreen.Hide

function TipjarScreen.Init(UI)
	TipjarScreen.Interface = UI
	TipjarScreen:BuildInterface()

	if UI and UI.ScreenShown then
		UI.ScreenShown:Connect(function(componentName, isVisible)
			if isVisible and componentName ~= "TipjarScreen" and TipjarScreen.Showing then
				TipjarScreen.Hide("ScreenChanged")
			end
		end)
	end

end

return TipjarScreen
