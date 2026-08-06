local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local Player = Players.LocalPlayer
local Modules = ReplicatedStorage:WaitForChild("Modules")

local RecipeSelector = {}

local COLORS = {
	Background = Color3.fromRGB(15, 25, 45),
	Card = Color3.fromRGB(25, 40, 65),
	CardHover = Color3.fromRGB(35, 55, 85),
	Accent = Color3.fromRGB(45, 180, 220),
	AccentHover = Color3.fromRGB(65, 200, 240),
	Success = Color3.fromRGB(50, 200, 150),
	Text = Color3.fromRGB(220, 240, 255),
	SubText = Color3.fromRGB(150, 180, 200),
	Border = Color3.fromRGB(60, 90, 120),
	Shadow = Color3.fromRGB(5, 15, 30),
}

local currentGui = nil

local function createRecipeCard(recipe, onSelect)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, -20, 0, 120)
	card.BackgroundColor3 = COLORS.Card
	card.BorderSizePixel = 0

	local cardCorner = Instance.new("UICorner", card)
	cardCorner.CornerRadius = UDim.new(0, 12)

	local stroke = Instance.new("UIStroke", card)
	stroke.Color = COLORS.Border
	stroke.Thickness = 1
	stroke.Transparency = 0.2

	local glow = Instance.new("UIStroke", card)
	glow.Color = COLORS.Accent
	glow.Thickness = 0
	glow.Transparency = 0.8
	glow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

	local button = Instance.new("TextButton", card)
	button.Size = UDim2.new(1, 0, 1, 0)
	button.BackgroundTransparency = 1
	button.Text = ""

	local iconLabel = Instance.new("TextLabel", card)
	iconLabel.Size = UDim2.new(0, 40, 0, 40)
	iconLabel.Position = UDim2.new(0, 15, 0, 15)
	iconLabel.BackgroundTransparency = 1

	local recipeIcon = "🍹"
	local recipeName = (recipe.Name or recipe.Id or ""):lower()

	if recipeName:find("orange") then
		recipeIcon = "🍊"
	elseif recipeName:find("strawberry") then
		recipeIcon = "🍓"
	elseif recipeName:find("apple") then
		recipeIcon = "🍎"
	elseif recipeName:find("banana") then
		recipeIcon = "🍌"
	elseif recipeName:find("grape") then
		recipeIcon = "🍇"
	elseif recipeName:find("lemon") then
		recipeIcon = "🍋"
	elseif recipeName:find("coconut") then
		recipeIcon = "🥥"
	elseif recipeName:find("cherry") then
		recipeIcon = "🍒"
	elseif recipeName:find("pineapple") then
		recipeIcon = "🍍"
	elseif recipeName:find("peach") then
		recipeIcon = "🍑"
	elseif recipeName:find("watermelon") then
		recipeIcon = "🍉"
	elseif recipeName:find("milk") or recipeName:find("shake") then
		recipeIcon = "🥛"
	elseif recipeName:find("coffee") then
		recipeIcon = "☕"
	elseif recipeName:find("tea") then
		recipeIcon = "🍵"
	end

	iconLabel.Text = recipeIcon
	iconLabel.TextColor3 = COLORS.Accent
	iconLabel.TextSize = 24
	iconLabel.Font = Enum.Font.SourceSans

	local nameLabel = Instance.new("TextLabel", card)
	nameLabel.Size = UDim2.new(1, -75, 0, 30)
	nameLabel.Position = UDim2.new(0, 65, 0, 15)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = recipe.Name or recipe.Id
	nameLabel.TextColor3 = COLORS.Text
	nameLabel.TextSize = 20
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Font = Enum.Font.SourceSansBold

	local descLabel = Instance.new("TextLabel", card)
	descLabel.Size = UDim2.new(1, -75, 0, 25)
	descLabel.Position = UDim2.new(0, 65, 0, 45)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = recipe.Description or "A delicious drink recipe"
	descLabel.TextColor3 = COLORS.SubText
	descLabel.TextSize = 14
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.Font = Enum.Font.SourceSans
	descLabel.TextWrapped = true

	local ingredientsBadge = Instance.new("Frame", card)
	ingredientsBadge.Size = UDim2.new(0, 80, 0, 24)
	ingredientsBadge.Position = UDim2.new(1, -95, 0, 15)
	ingredientsBadge.BackgroundColor3 = COLORS.Accent
	ingredientsBadge.BorderSizePixel = 0
	local ingredientsBadgeCorner = Instance.new("UICorner", ingredientsBadge)
	ingredientsBadgeCorner.CornerRadius = UDim.new(0, 12)

	local ingredientsCount = 0
	if recipe.Ingredients and type(recipe.Ingredients) == "table" then
		for _ in pairs(recipe.Ingredients) do
			ingredientsCount = ingredientsCount + 1
		end
	end

	local ingredientsBadgeLabel = Instance.new("TextLabel", ingredientsBadge)
	ingredientsBadgeLabel.Size = UDim2.new(1, 0, 1, 0)
	ingredientsBadgeLabel.BackgroundTransparency = 1
	ingredientsBadgeLabel.Text = ingredientsCount .. " items"
	ingredientsBadgeLabel.TextColor3 = Color3.new(1, 1, 1)
	ingredientsBadgeLabel.TextSize = 12
	ingredientsBadgeLabel.Font = Enum.Font.SourceSansBold

	local ingredientsLabel = Instance.new("TextLabel", card)
	ingredientsLabel.Size = UDim2.new(1, -20, 0, 20)
	ingredientsLabel.Position = UDim2.new(0, 15, 0, 85)
	ingredientsLabel.BackgroundTransparency = 1

	local ingredientsText = "Tap to craft"
	if recipe.Ingredients and type(recipe.Ingredients) == "table" then
		local ingredientNames = {}
		for ingredientName, _ in pairs(recipe.Ingredients) do
			table.insert(ingredientNames, ingredientName)
		end
		if #ingredientNames > 0 then
			ingredientsText = "Requires: " .. table.concat(ingredientNames, ", ")
		end
	end

	ingredientsLabel.Text = ingredientsText
	ingredientsLabel.TextColor3 = COLORS.SubText
	ingredientsLabel.TextSize = 12
	ingredientsLabel.TextXAlignment = Enum.TextXAlignment.Left
	ingredientsLabel.Font = Enum.Font.SourceSansItalic

	button.MouseEnter:Connect(function()
		TweenService:Create(card, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
			BackgroundColor3 = COLORS.CardHover
		}):Play()
		TweenService:Create(stroke, TweenInfo.new(0.2), {
			Color = COLORS.AccentHover,
			Transparency = 0.1
		}):Play()
		TweenService:Create(glow, TweenInfo.new(0.3), {
			Thickness = 2,
			Transparency = 0.4
		}):Play()
		TweenService:Create(card, TweenInfo.new(0.2, Enum.EasingStyle.Back), {
			Size = UDim2.new(1, -15, 0, 120)
		}):Play()
		TweenService:Create(ingredientsBadge, TweenInfo.new(0.2), {
			BackgroundColor3 = COLORS.AccentHover
		}):Play()
	end)

	button.MouseLeave:Connect(function()
		TweenService:Create(card, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
			BackgroundColor3 = COLORS.Card
		}):Play()
		TweenService:Create(stroke, TweenInfo.new(0.2), {
			Color = COLORS.Border,
			Transparency = 0.2
		}):Play()
		TweenService:Create(glow, TweenInfo.new(0.3), {
			Thickness = 0,
			Transparency = 0.8
		}):Play()
		TweenService:Create(card, TweenInfo.new(0.2, Enum.EasingStyle.Back), {
			Size = UDim2.new(1, -20, 0, 120)
		}):Play()
		TweenService:Create(ingredientsBadge, TweenInfo.new(0.2), {
			BackgroundColor3 = COLORS.Accent
		}):Play()
	end)

	button.MouseButton1Click:Connect(function()
		TweenService:Create(card, TweenInfo.new(0.1, Enum.EasingStyle.Back), {
			Size = UDim2.new(1, -25, 0, 115)
		}):Play()
		task.wait(0.1)
		onSelect(recipe)
	end)

	return card
end

function RecipeSelector.Show(recipes, onRecipeSelected)
	if currentGui then
		RecipeSelector.Hide()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "RecipeSelector"
	gui.DisplayOrder = 100
	gui.ResetOnSpawn = false
	gui.Parent = Player:WaitForChild("PlayerGui")

	local overlay = Instance.new("Frame", gui)
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.5
	overlay.BorderSizePixel = 0

	local mainFrame = Instance.new("Frame", overlay)
	mainFrame.Size = UDim2.new(0, 450, 0, 600)
	mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	mainFrame.BackgroundColor3 = COLORS.Background
	mainFrame.BorderSizePixel = 0

	local mainCorner = Instance.new("UICorner", mainFrame)
	mainCorner.CornerRadius = UDim.new(0, 16)

	local shadow1 = Instance.new("Frame", mainFrame)
	shadow1.Size = UDim2.new(1, 40, 1, 40)
	shadow1.Position = UDim2.new(0, -20, 0, 20)
	shadow1.BackgroundColor3 = COLORS.Shadow
	shadow1.BackgroundTransparency = 0.9
	shadow1.ZIndex = mainFrame.ZIndex - 3
	shadow1.BorderSizePixel = 0
	local shadow1Corner = Instance.new("UICorner", shadow1)
	shadow1Corner.CornerRadius = UDim.new(0, 16)

	local shadow2 = Instance.new("Frame", mainFrame)
	shadow2.Size = UDim2.new(1, 20, 1, 20)
	shadow2.Position = UDim2.new(0, -10, 0, 10)
	shadow2.BackgroundColor3 = COLORS.Shadow
	shadow2.BackgroundTransparency = 0.7
	shadow2.ZIndex = mainFrame.ZIndex - 2
	shadow2.BorderSizePixel = 0
	local shadow2Corner = Instance.new("UICorner", shadow2)
	shadow2Corner.CornerRadius = UDim.new(0, 16)

	local shadow3 = Instance.new("Frame", mainFrame)
	shadow3.Size = UDim2.new(1, 10, 1, 10)
	shadow3.Position = UDim2.new(0, -5, 0, 5)
	shadow3.BackgroundColor3 = COLORS.Shadow
	shadow3.BackgroundTransparency = 0.5
	shadow3.ZIndex = mainFrame.ZIndex - 1
	shadow3.BorderSizePixel = 0
	local shadow3Corner = Instance.new("UICorner", shadow3)
	shadow3Corner.CornerRadius = UDim.new(0, 16)

	local header = Instance.new("Frame", mainFrame)
	header.Size = UDim2.new(1, 0, 0, 80)
	header.BackgroundTransparency = 1
	header.BorderSizePixel = 0

	local titleLabel = Instance.new("TextLabel", header)
	titleLabel.Size = UDim2.new(1, -80, 1, 0)
	titleLabel.Position = UDim2.new(0, 25, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "🍹 Recipe Selection"
	titleLabel.TextColor3 = COLORS.Accent
	titleLabel.TextSize = 28
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Font = Enum.Font.SourceSansBold

	local closeBtn = Instance.new("TextLabel", header)
	closeBtn.Size = UDim2.new(0, 24, 0, 20)
	closeBtn.Position = UDim2.new(1, -37, 0.5, 0)
	closeBtn.AnchorPoint = Vector2.new(0, 0.5)
	closeBtn.BackgroundTransparency = 1
	closeBtn.Text = "←"
	closeBtn.TextColor3 = COLORS.SubText
	closeBtn.TextSize = 22
	closeBtn.Font = Enum.Font.SourceSansBold
	closeBtn.BorderSizePixel = 0

	local closeHitBox = Instance.new("TextButton", header)
	closeHitBox.Size = UDim2.new(0, 40, 0, 40)
	closeHitBox.Position = UDim2.new(1, -45, 0.5, 0)
	closeHitBox.AnchorPoint = Vector2.new(0, 0.5)
	closeHitBox.BackgroundTransparency = 1
	closeHitBox.Text = ""
	closeHitBox.BorderSizePixel = 0

	closeHitBox.MouseEnter:Connect(function()
		TweenService:Create(closeBtn, TweenInfo.new(0.2), {
			TextColor3 = Color3.fromRGB(255, 100, 100)
		}):Play()
	end)

	closeHitBox.MouseLeave:Connect(function()
		TweenService:Create(closeBtn, TweenInfo.new(0.2), {
			TextColor3 = COLORS.SubText
		}):Play()
	end)

	local separator = Instance.new("Frame", mainFrame)
	separator.Size = UDim2.new(1, -40, 0, 1)
	separator.Position = UDim2.new(0, 20, 0, 75)
	separator.BackgroundColor3 = COLORS.Border
	separator.BackgroundTransparency = 0.3
	separator.BorderSizePixel = 0

	local scrollFrame = Instance.new("ScrollingFrame", mainFrame)
	scrollFrame.Size = UDim2.new(1, -30, 1, -95)
	scrollFrame.Position = UDim2.new(0, 15, 0, 85)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 8
	scrollFrame.ScrollBarImageColor3 = COLORS.Accent
	scrollFrame.ScrollBarImageTransparency = 0.3

	local padding = Instance.new("UIPadding", scrollFrame)
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 15)
	padding.PaddingRight = UDim.new(0, 15)

	local layout = Instance.new("UIListLayout", scrollFrame)
	layout.Padding = UDim.new(0, 15)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	if not recipes or #recipes == 0 then
		local noRecipesLabel = Instance.new("TextLabel", scrollFrame)
		noRecipesLabel.Size = UDim2.new(1, 0, 0, 100)
		noRecipesLabel.BackgroundTransparency = 1
		noRecipesLabel.Text = "No recipes available"
		noRecipesLabel.TextColor3 = COLORS.SubText
		noRecipesLabel.TextSize = 18
		noRecipesLabel.Font = Enum.Font.SourceSans
		scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 100)
	else
		for i, recipe in ipairs(recipes) do
			local card = createRecipeCard(recipe, function(selectedRecipe)
				if onRecipeSelected then
					onRecipeSelected(selectedRecipe)
				end
				RecipeSelector.Hide()
			end)
			card.LayoutOrder = i
			card.Parent = scrollFrame
		end

		layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			scrollFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 30)
		end)
	end

	closeHitBox.MouseButton1Click:Connect(function()
		RecipeSelector.Hide()
	end)

	overlay.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local mousePos = UserInputService:GetMouseLocation()
			local guiPos = mainFrame.AbsolutePosition
			local guiSize = mainFrame.AbsoluteSize

			if mousePos.X < guiPos.X or mousePos.X > guiPos.X + guiSize.X or
				mousePos.Y < guiPos.Y or mousePos.Y > guiPos.Y + guiSize.Y then
				RecipeSelector.Hide()
			end
		end
	end)

	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Escape then
			RecipeSelector.Hide()
		end
	end)

	mainFrame.Size = UDim2.new(0, 0, 0, 0)
	mainFrame.Position = UDim2.new(0.5, 0, 0.3, 0)
	TweenService:Create(mainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 450, 0, 600),
		Position = UDim2.new(0.5, 0, 0.5, 0)
	}):Play()

	TweenService:Create(overlay, TweenInfo.new(0.3), {
		BackgroundTransparency = 0.5
	}):Play()

	currentGui = gui
end

function RecipeSelector.Hide()
	if not currentGui then return end

	local overlay = currentGui:FindFirstChild("Frame")
	local mainFrame = overlay and overlay:FindFirstChild("Frame")

	if mainFrame and overlay then
		TweenService:Create(mainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
			Size = UDim2.new(0, 0, 0, 0),
			Position = UDim2.new(0.5, 0, 0.3, 0)
		}):Play()

		TweenService:Create(overlay, TweenInfo.new(0.25), {
			BackgroundTransparency = 1
		}):Play()

		task.delay(0.25, function()
			if currentGui then
				currentGui:Destroy()
				currentGui = nil
			end
		end)
	else
		currentGui:Destroy()
		currentGui = nil
	end
end

return RecipeSelector
