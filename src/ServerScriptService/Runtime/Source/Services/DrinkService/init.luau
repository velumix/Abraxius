local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Mince = require(ReplicatedStorage.Modules.Mince)
local Component = Mince.Component

local Recipes = require(script.Recipes)
local Ingredients = require(script.Ingredients)
local DrinkNameGenerator = require(script.DrinkNameGenerator)
local PlacedDrink = require(script.PlacedDrink)

local DrinkService = {
	Name = "DrinkService"
}

DrinkService.Blenders = {}
DrinkService.Ingredients = {}
DrinkService.Cups = {}
DrinkService.TrashBins = {}
DrinkService.DrinkCooldowns = {}

function DrinkService:Setup()
	self.DrinkEvents = Mince:GetEvent("DrinkService")
	self.DrinkRequests = Mince:GetEvent("DrinkRequests")

	self.DrinkMade = self.DrinkEvents:Extend("DrinkMade")
	self.ShowError = self.DrinkEvents:Extend("ShowError")
	self.IngredientCollected = self.DrinkEvents:Extend("IngredientCollected")
	self.DrinkReady = self.DrinkEvents:Extend("DrinkReady")
	self.DrinkConsumed = self.DrinkEvents:Extend("DrinkConsumed")
	self.TrashHighlight = self.DrinkEvents:Extend("TrashHighlight")

	self.DrinkRequests.Event:Connect(function(player, method, ...)
		local result = self:HandleClientRequest(player, method, ...)
		if result ~= nil then
			self.DrinkRequests:Fire(player, "Response", method, result)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:CleanupPlayerCups(player)
	end)


end

function DrinkService:CleanupPlayerCups(player: Player)
	local function cleanupContainer(container)
		if not container then
			return
		end
		for _, tool in pairs(container:GetChildren()) do
			if tool:IsA("Tool") and CollectionService:HasTag(tool, "Cup") then
				tool:Destroy()
			end
		end
	end

	cleanupContainer(player.Character)
	cleanupContainer(player:FindFirstChild("Backpack"))

	self.DrinkCooldowns[player.UserId] = nil
	self.DrinkCooldowns[player.UserId .. "_consume"] = nil
end

function DrinkService:GameStart()
end

local Ingredient = Component{Tag = "Ingredient"}
local Cup = Component{Tag = "Cup"}
local Trash = Component{Tag = "TrashBin"}

function Ingredient:Construct()
	local ingName = self.Instance.Name
	local ingData = Ingredients[ingName]
	assert(ingData, "Missing ingredient data for " .. ingName)

	self.IngredientName = ingName
	self.IngredientData = ingData
	DrinkService.Ingredients[self.Instance] = self
end

function Ingredient:Stop()
	DrinkService.Ingredients[self.Instance] = nil
end

function Trash:Construct()
	local model = self.Instance
	if not model:IsA("Model") then
		warn("Trash component can only be applied to Models")
		return
	end

	self.Highlight = Instance.new("Highlight")
	self.Highlight.FillColor = Color3.new(1, 0, 0)
	self.Highlight.OutlineColor = Color3.new(1, 0.2, 0.2)
	self.Highlight.FillTransparency = 0.5
	self.Highlight.OutlineTransparency = 0
	self.Highlight.Enabled = false
	self.Highlight.Parent = model

	DrinkService.TrashBins[self.Instance] = self
end

function Trash:Stop()
	if self.Highlight then
		self.Highlight:Destroy()
	end
	DrinkService.TrashBins[self.Instance] = nil
end

function Trash:ShowHighlight()
	if self.Highlight then
		self.Highlight.Enabled = true
	end
end

function Trash:HideHighlight()
	if self.Highlight then
		self.Highlight.Enabled = false
	end
end

function Cup:Construct()
	self.Tool = self.Instance
	self.Animations = self.Instance:FindFirstChild("Animations")
	self.Liquid = self.Instance:FindFirstChild("Content")
	self.Cream = self.Instance:FindFirstChild("Cream")
	assert(self.Animations, "Cup is missing Animations folder")
	assert(self.Liquid, "Cup is missing Content part")

	self.LoadedAnimations = {}
	self.IsEquipped = false
	self.EquippedPlayer = nil

	self.CupType = self.Instance:GetAttribute("CupType") or "Regular"
	self.OriginalName = self.Instance.Name

	self.Contents = {
		Ingredients = {},
		MixingOrder = {},
		TotalVolume = 0,
		MixedColor = Color3.new(1,1,1),
		DrinkName = "Empty Cup",
		DrinkDescription = "An empty cup ready to be filled",
		IsConsuming = false
	}

	self.LastMessageState = "empty"

	self.Tool.ToolTip = "Empty Cup"

	self:UpdateVisualContent()
	self:UpdateCreamVisibility()

	self.Connections = {
		Equipped = self.Tool.Equipped:Connect(function()
			local Character = self.Tool.Parent
			local player = Players:GetPlayerFromCharacter(Character)
			self.IsEquipped = true
			self.EquippedPlayer = player

			local Animator = Character:FindFirstChild("Animator", true)
			if not Animator then warn("No Animator found") return end
			for _, anim in ipairs(self.Animations:GetChildren()) do
				if anim:IsA("Animation") then
					local loadedAnim = Animator:LoadAnimation(anim)
					if anim.Name == "Idle" then
						loadedAnim.Priority = Enum.AnimationPriority.Idle
					elseif anim.Name == "Consume" or anim.Name == "Drink" then
						loadedAnim.Priority = Enum.AnimationPriority.Action
					else
						loadedAnim.Priority = Enum.AnimationPriority.Action
					end
					if anim.Name == "Drink" then
						self.LoadedAnimations["Consume"] = loadedAnim
					else
						self.LoadedAnimations[anim.Name] = loadedAnim
					end
				end
			end
			if self.LoadedAnimations["Idle"] then
				self.LoadedAnimations["Idle"].Looped = true
				self.LoadedAnimations["Idle"]:Play()
			else
				warn("Idle animation not found for cup: " .. self.Instance.Name)
			end
		end),

		Unequipped = self.Tool.Unequipped:Connect(function()
			self.IsEquipped = false
			self.EquippedPlayer = nil

			for _, anim in pairs(self.LoadedAnimations) do
				anim:Stop()
			end
		end),

		Activated = self.Tool.Activated:Connect(function()
			local player = self.EquippedPlayer
			if not player then return end

			local cooldownKey = player.UserId .. "_consume"
			if DrinkService.DrinkCooldowns[cooldownKey] then
				return
			end

			if self.Contents.TotalVolume > 0 and self:IsReadyToConsume() then
				self.LastMessageState = "consuming"
				if self.LoadedAnimations["Consume"] then
					local drinkAnim = self.LoadedAnimations["Consume"]
					drinkAnim:Play()

					DrinkService.DrinkCooldowns[cooldownKey] = true

					local connection
					connection = drinkAnim.Ended:Connect(function()
						DrinkService.DrinkCooldowns[cooldownKey] = nil
						connection:Disconnect()
					end)

					task.delay(drinkAnim.Length * 0.5, function()
						local success, message = self:ConsumePortion()
						if success then
							DrinkService.DrinkConsumed:Fire(player, message)
						end
					end)

					task.delay(drinkAnim.Length + 0.1, function()
						DrinkService.DrinkCooldowns[cooldownKey] = nil
					end)
				else
					local success, message = self:ConsumePortion()
					if success then
						DrinkService.DrinkConsumed:Fire(player, message)
					end
					DrinkService.DrinkCooldowns[cooldownKey] = true
					task.delay(0.5, function()
						DrinkService.DrinkCooldowns[cooldownKey] = nil
					end)
				end
			else
				local currentState
				if self.Contents.TotalVolume <= 0 then
					currentState = "empty"
				else
					currentState = "not_ready"
				end

				if self.LastMessageState ~= currentState then
					self.LastMessageState = currentState
					if currentState == "empty" then
						DrinkService.ShowError:Fire(player, "Cup is empty! Add ingredients first.")
					else
						DrinkService.ShowError:Fire(player, "Beverage is not ready! Need 100 volume to start consuming.")
					end
				end
			end
		end),
	}

	DrinkService.Cups[self.Instance] = self
end

function Cup:Stop()
	if self.Connections then
		for _, connection in pairs(self.Connections) do
			if connection then
				connection:Disconnect()
			end
		end
	end

	DrinkService.Cups[self.Instance] = nil
end

function Cup:CanUseIngredient(ingredientData, ingredientName)
	if not ingredientData then
		return false
	end

	if self.CupType == "Coffee" then
		return ingredientData.Type == "Coffee"
	elseif self.CupType == "Regular" then
		return true
	end

	return true
end

function Cup:AddIngredient(ingredientData, ingredientName)
	if self.Contents.IsConsuming then
		return false
	end

	local volume = ingredientData.Volume or 25
	local isTopping = ingredientData.IsTopping == true

	if isTopping then
		if self.Contents.Ingredients[ingredientName] and self.Contents.Ingredients[ingredientName] > 0 then
			return false
		end
	end

	if self.Contents.TotalVolume >= 100 then
		return false
	end

	local remaining = 100 - self.Contents.TotalVolume
	if remaining <= 0 then
		return false
	end

	local addVolume = math.min(volume, remaining)
	if addVolume <= 0 then
		return false
	end

	if not self:CanUseIngredient(ingredientData, ingredientName) then
		return false
	end

	if not self.Contents.Ingredients[ingredientName] then
		self.Contents.Ingredients[ingredientName] = 0
	end
	self.Contents.Ingredients[ingredientName] = self.Contents.Ingredients[ingredientName] + 1

	table.insert(self.Contents.MixingOrder, ingredientName)

	local color = ingredientData.LiquidColor or Color3.new(1, 1, 1)

	local oldVolume = self.Contents.TotalVolume
	local totalVolume = self.Contents.TotalVolume + addVolume
	local currentR, currentG, currentB = self.Contents.MixedColor.R, self.Contents.MixedColor.G, self.Contents.MixedColor.B

	local newR = (currentR * self.Contents.TotalVolume + color.R * addVolume) / totalVolume
	local newG = (currentG * self.Contents.TotalVolume + color.G * addVolume) / totalVolume
	local newB = (currentB * self.Contents.TotalVolume + color.B * addVolume) / totalVolume

	self.Contents.MixedColor = Color3.new(newR, newG, newB)
	self.Contents.TotalVolume = totalVolume

	if self.Contents.TotalVolume >= 100 then
		local liquidTypes = {}
		for ingredient, count in pairs(self.Contents.Ingredients) do
			local ingData = Ingredients[ingredient]
			if ingData and ingData.Type then
				if not liquidTypes[ingData.Type] then
					liquidTypes[ingData.Type] = 0
				end
				liquidTypes[ingData.Type] = liquidTypes[ingData.Type] + count
			end
		end

		local drinkName = DrinkNameGenerator.GenerateName(self.Contents.MixingOrder, liquidTypes, self.CupType)
		self.Tool.Name = drinkName
	else
		if self.Contents.TotalVolume > 0 then
			local ingredientList = {}
			for ingredient, count in pairs(self.Contents.Ingredients) do
				if count > 0 then
					table.insert(ingredientList, count > 1 and (ingredient .. " x" .. count) or ingredient)
				end
			end
			if #ingredientList > 0 then
				self.Tool.Name = table.concat(ingredientList, " + ")
			else
				self.Tool.Name = self.OriginalName
			end
		else
			self.Tool.Name = self.OriginalName
		end
	end

	self:TweenFill(oldVolume, totalVolume)

	self.LastMessageState = self.Contents.TotalVolume >= 100 and "ready" or "filling"

	return true
end

function Cup:TweenFill(oldVolume, newVolume)
	if not self.Liquid or not self.Liquid:IsA("MeshPart") then
		return
	end

	if not self.OriginalLiquidSize then
		self.OriginalLiquidSize = self.Liquid.Size
	end

	if not self.LiquidWeld or not self.OriginalWeldC0 then
		local liquidChildren = self.Liquid:GetChildren()
		for _, child in liquidChildren do
		end

		local toolChildren = self.Tool:GetChildren()
		for _, child in toolChildren do
			if child:IsA("Weld") then
				if child.Part1 == self.Liquid or child.Part0 == self.Liquid then
					self.LiquidWeld = child
					self.OriginalWeldC0 = child.C0
				end
			end
		end

		local handle = self.Tool:FindFirstChild("Handle")
		if handle then
			local handleChildren = handle:GetChildren()
			for _, child in handleChildren do
				if child:IsA("Weld") then
					if child.Part1 == self.Liquid or child.Part0 == self.Liquid then
						self.LiquidWeld = child
						self.OriginalWeldC0 = child.C0
					end
				end
			end
		end
	end

	if oldVolume == 0 then
		self.Liquid.Color = self.Contents.MixedColor
		self.Liquid.Transparency = 0.1
		self.Liquid.CanCollide = false
	end

	local fillDuration = 0.5
	local tweenInfo = TweenInfo.new(
		fillDuration,
		Enum.EasingStyle.Quart,
		Enum.EasingDirection.Out,
		0,
		false,
		0
	)

	local oldFillPercentage = math.min(oldVolume / 100, 1)
	local newFillPercentage = math.min(newVolume / 100, 1)

	local oldY = self.OriginalLiquidSize.Y * oldFillPercentage
	local newY = self.OriginalLiquidSize.Y * newFillPercentage

	local oldCircumferenceScale = 0.90 + (oldFillPercentage * 0.10)
	local newCircumferenceScale = 0.90 + (newFillPercentage * 0.10)

	local initialSize = Vector3.new(
		self.OriginalLiquidSize.X * oldCircumferenceScale,
		oldY,
		self.OriginalLiquidSize.Z * oldCircumferenceScale
	)
	self.Liquid.Size = initialSize

	local targetSize = Vector3.new(
		self.OriginalLiquidSize.X * newCircumferenceScale,
		newY,
		self.OriginalLiquidSize.Z * newCircumferenceScale
	)

	local sizeTween = TweenService:Create(self.Liquid, tweenInfo, {
		Size = targetSize,
		Color = self.Contents.MixedColor
	})

	local weldTween = nil
	if self.LiquidWeld and self.OriginalWeldC0 then
		local oldYOffset = -(self.OriginalLiquidSize.Y / 2) + (oldY / 2)
		local initialPosition = self.OriginalWeldC0.Position + Vector3.new(0, oldYOffset, 0)
		local initialC0 = CFrame.new(initialPosition) * CFrame.Angles(self.OriginalWeldC0:ToEulerAnglesXYZ())
		self.LiquidWeld.C0 = initialC0

		local yOffset = -(self.OriginalLiquidSize.Y / 2) + (newY / 2)
		local targetPosition = self.OriginalWeldC0.Position + Vector3.new(0, yOffset, 0)
		local targetC0 = CFrame.new(targetPosition) * CFrame.Angles(self.OriginalWeldC0:ToEulerAnglesXYZ())

		weldTween = TweenService:Create(self.LiquidWeld, tweenInfo, {
			C0 = targetC0
		})
	end

	local creamTween = nil
	if self.Cream and (self.Contents.Ingredients["Cream"] and self.Contents.Ingredients["Cream"] > 0) then
		if self.CreamWeld and self.OriginalCreamWeldC0 and self.OriginalLiquidSize then
			local newFillPercentage = math.min(newVolume / 100, 1)
			local newLiquidHeight = self.OriginalLiquidSize.Y * newFillPercentage
			local liquidTop = -(self.OriginalLiquidSize.Y / 2) + newLiquidHeight
			local creamOffset = liquidTop + (self.Cream.Size.Y / 4)

			local targetPosition = Vector3.new(self.OriginalCreamWeldC0.Position.X, creamOffset, self.OriginalCreamWeldC0.Position.Z)
			local targetC0 = CFrame.new(targetPosition) * CFrame.Angles(self.OriginalCreamWeldC0:ToEulerAnglesXYZ())

			creamTween = TweenService:Create(self.CreamWeld, tweenInfo, {
				C0 = targetC0
			})
		end
	end

	sizeTween:Play()
	if weldTween then
		weldTween:Play()
	end
	if creamTween then
		creamTween:Play()
	end
end

function Cup:UpdateCreamVisibility()
	if not self.Cream then return end

	local hasCream = self.Contents.Ingredients["Cream"] and self.Contents.Ingredients["Cream"] > 0

	if hasCream and self.Contents.TotalVolume > 0 then
		self.Cream.Transparency = 0
		self.Cream.CanCollide = false

		if not self.CreamWeld or not self.OriginalCreamWeldC0 then
			local toolChildren = self.Tool:GetChildren()
			for _, child in toolChildren do
				if child:IsA("Weld") then
					if child.Part1 == self.Cream or child.Part0 == self.Cream then
						self.CreamWeld = child
						self.OriginalCreamWeldC0 = child.C0
					end
				end
			end

			local handle = self.Tool:FindFirstChild("Handle")
			if handle then
				local handleChildren = handle:GetChildren()
				for _, child in handleChildren do
					if child:IsA("Weld") then
						if child.Part1 == self.Cream or child.Part0 == self.Cream then
							self.CreamWeld = child
							self.OriginalCreamWeldC0 = child.C0
						end
					end
				end
			end
		end

		if self.CreamWeld and self.OriginalCreamWeldC0 and self.OriginalLiquidSize then
			local fillPercentage = math.min(self.Contents.TotalVolume / 100, 1)
			local liquidHeight = self.OriginalLiquidSize.Y * fillPercentage
			local liquidTop = -(self.OriginalLiquidSize.Y / 2) + liquidHeight
			local creamOffset = liquidTop + (self.Cream.Size.Y / 4)

			local newPosition = Vector3.new(self.OriginalCreamWeldC0.Position.X, creamOffset, self.OriginalCreamWeldC0.Position.Z)
			local newC0 = CFrame.new(newPosition) * CFrame.Angles(self.OriginalCreamWeldC0:ToEulerAnglesXYZ())
			self.CreamWeld.C0 = newC0
		end
	else
		self.Cream.Transparency = 1
	end
end

function Cup:UpdateVisualContent()
	if not self.Liquid then
		warn("Cup Liquid (Content) not found for:", self.Instance.Name)
		return
	end

	if self.Liquid:IsA("MeshPart") then
		if self.Contents.TotalVolume > 0 then
			self.Liquid.Color = self.Contents.MixedColor
			self.Liquid.Transparency = 0.1
			self.Liquid.CanCollide = false

			local fillPercentage = math.min(self.Contents.TotalVolume / 100, 1)

			if not self.OriginalLiquidSize then
				self.OriginalLiquidSize = self.Liquid.Size
			end

			if not self.LiquidWeld or not self.OriginalWeldC0 then
				local liquidChildren = self.Liquid:GetChildren()
				for _, child in liquidChildren do
				end

				local toolChildren = self.Tool:GetChildren()
				for _, child in toolChildren do
					if child:IsA("Weld") then
						if child.Part1 == self.Liquid or child.Part0 == self.Liquid then
							self.LiquidWeld = child
							self.OriginalWeldC0 = child.C0
						end
					end
				end

				local handle = self.Tool:FindFirstChild("Handle")
				if handle then
					local handleChildren = handle:GetChildren()
					for _, child in handleChildren do
						if child:IsA("Weld") then
							if child.Part1 == self.Liquid or child.Part0 == self.Liquid then
								self.LiquidWeld = child
								self.OriginalWeldC0 = child.C0
							end
						end
					end
				end
			end

			local newY = self.OriginalLiquidSize.Y * fillPercentage

			local circumferenceScale = 0.90 + (fillPercentage * 0.10)

			local newSize = Vector3.new(
				self.OriginalLiquidSize.X * circumferenceScale,
				newY,
				self.OriginalLiquidSize.Z * circumferenceScale
			)

			self.Liquid.Size = newSize

			if self.LiquidWeld and self.OriginalWeldC0 then
				local yOffset = -(self.OriginalLiquidSize.Y / 2) + (newY / 2)
				local newPosition = self.OriginalWeldC0.Position + Vector3.new(0, yOffset, 0)
				local newC0 = CFrame.new(newPosition) * CFrame.Angles(self.OriginalWeldC0:ToEulerAnglesXYZ())
				self.LiquidWeld.C0 = newC0
			end
		else
			self.Liquid.Transparency = 1
		end
	else
		warn("Liquid (Content) is not a MeshPart in:", self.Instance.Name)
	end

	if self.Contents.TotalVolume == 0 then
		self.Tool.Name = self.OriginalName
		self.Tool.ToolTip = "Empty Cup - Click on ingredients to collect them!"
	elseif self.Contents.TotalVolume >= 100 then
		local ingredientList = {}
		for ingredient, count in pairs(self.Contents.Ingredients) do
			if count > 0 then
				table.insert(ingredientList, count > 1 and (ingredient .. " x" .. count) or ingredient)
			end
		end
		local contentsText = table.concat(ingredientList, ", ")
		self.Tool.ToolTip = string.format("Ready to consume! Contents: %s (%.1f/100 volume)", contentsText, self.Contents.TotalVolume)
	elseif self.Contents.IsConsuming then
		local ingredientList = {}
		for ingredient, count in pairs(self.Contents.Ingredients) do
			if count > 0 then
				table.insert(ingredientList, count > 1 and (ingredient .. " x" .. count) or ingredient)
			end
		end
		local contentsText = table.concat(ingredientList, ", ")
		self.Tool.ToolTip = string.format("Continue consuming! Contents: %s (%.1f/100 volume)", contentsText, self.Contents.TotalVolume)
	else
		local ingredientList = {}
		for ingredient, count in pairs(self.Contents.Ingredients) do
			if count > 0 then
				table.insert(ingredientList, count > 1 and (ingredient .. " x" .. count) or ingredient)
			end
		end
		local contentsText = table.concat(ingredientList, ", ")
		self.Tool.ToolTip = string.format("Keep adding ingredients! Contents: %s (%.1f/100 volume needed)", contentsText, self.Contents.TotalVolume)
	end

	self:UpdateCreamVisibility()
end

function Cup:GetContentsString()
	if self.Contents.TotalVolume == 0 then
		return "Empty cup"
	end

	local parts = {}
	for ingredient, count in pairs(self.Contents.Ingredients) do
		if count > 0 then
			table.insert(parts, count > 1 and (ingredient .. " x" .. count) or ingredient)
		end
	end

	return string.format("Cup contents: %s (Volume: %.1f)", table.concat(parts, ", "), self.Contents.TotalVolume)
end

function Cup:ConsumeDrink(amount)
	if self.Contents.TotalVolume <= 0 then return end

	local consumeAmount = math.min(amount, self.Contents.TotalVolume)
	self.Contents.TotalVolume = math.max(0, self.Contents.TotalVolume - consumeAmount)

	if self.Contents.TotalVolume <= 0 then
		self.Contents.Ingredients = {}
		self.Contents.MixedColor = Color3.new(1, 1, 1)
	end

	self:UpdateVisualContent()
end

function Cup:IsReadyToConsume()
	return self.Contents.TotalVolume >= 100 or (self.Contents.IsConsuming and self.Contents.TotalVolume > 0)
end

function Cup:ConsumePortion()
	if self.Contents.TotalVolume <= 0 then 
		return false, "Cup is empty!"
	end

	if not self:IsReadyToConsume() then
		return false, "Beverage is not ready! Need 100 volume to start consuming."
	end

	self.Contents.IsConsuming = true

	local sipAmount = 10
	local oldVolume = self.Contents.TotalVolume
	local newVolume = math.max(0, oldVolume - sipAmount)

	self.Contents.TotalVolume = newVolume

	if self.Contents.TotalVolume <= 0 then
		self.Contents.Ingredients = {}
		self.Contents.MixingOrder = {}
		self.Contents.MixedColor = Color3.new(1, 1, 1)
		self.Contents.DrinkName = "Empty Cup"
		self.Contents.DrinkDescription = "An empty cup ready to be filled"
		self.Contents.IsConsuming = false
		self.LastMessageState = "empty"
		self.Tool.Name = self.OriginalName
		self.Tool.ToolTip = "Empty Cup - Click on ingredients to collect them!"
	end

	self:TweenFill(oldVolume, newVolume)

	self:UpdateCreamVisibility()

	return true, string.format("Consumed! Remaining: %.1f/100", newVolume)
end

function Cup:DrinkEntireCup()
	if self.Contents.TotalVolume <= 0 then return end

	local drinkDuration = 1

	if not self.OriginalLiquidSize then
		warn("No original liquid size stored!")
		return
	end

	local tweenInfo = TweenInfo.new(
		drinkDuration,
		Enum.EasingStyle.Quart,
		Enum.EasingDirection.Out,
		0,
		false,
		0
	)

	local targetSize = Vector3.new(
		self.OriginalLiquidSize.X * 0.90,
		0.01,
		self.OriginalLiquidSize.Z * 0.90
	)

	local sizeTween = TweenService:Create(self.Liquid, tweenInfo, {
		Size = targetSize,
		Transparency = 1
	})

	local weldTween = nil
	if self.LiquidWeld and self.OriginalWeldC0 then
		local targetOffset = -(self.OriginalLiquidSize.Y / 2) + (0.01 / 2)
		local targetPosition = self.OriginalWeldC0.Position + Vector3.new(0, targetOffset, 0)
		local targetC0 = CFrame.new(targetPosition) * CFrame.Angles(self.OriginalWeldC0:ToEulerAnglesXYZ())

		weldTween = TweenService:Create(self.LiquidWeld, tweenInfo, {
			C0 = targetC0
		})
	end

	sizeTween.Completed:Connect(function()
		self.Contents.Ingredients = {}
		self.Contents.MixingOrder = {}
		self.Contents.TotalVolume = 0
		self.Contents.MixedColor = Color3.new(1, 1, 1)
		self.Contents.DrinkName = "Empty Cup"
		self.Contents.DrinkDescription = "An empty cup ready to be filled"
		self.Contents.IsConsuming = false
		self.LastMessageState = "empty"

		self.Tool.Name = self.OriginalName
		self.Tool.ToolTip = "Empty Cup - Click on ingredients to collect them!"

		self:UpdateVisualContent()
		self:UpdateCreamVisibility()
	end)

	sizeTween:Play()
	if weldTween then
		weldTween:Play()
	end
end

function DrinkService:GetEquippedCup(player)
	for cupTool, cupComponent in pairs(self.Cups) do
		if cupComponent.IsEquipped and cupComponent.EquippedPlayer == player then
			return cupComponent
		end
	end
	return nil
end

function DrinkService:_processCraftRequest(player: Player, recipeId: string)
	local recipe = Recipes[recipeId]
	if not recipe then
		self.ShowError:Fire(player, "Unknown recipe: " .. tostring(recipeId))
		return false
	end

	local backpack = player:FindFirstChild("Backpack")
	if not backpack then
		return false
	end

	local emptyGlass = nil
	for _, tool in ipairs(backpack:GetChildren()) do
		if tool:IsA("Tool") and tool.Name == "Empty Glass" then
			emptyGlass = tool
			break
		end
	end

	if not emptyGlass then
		self.ShowError:Fire(player, "You need an Empty Glass to make a drink.")
		return false
	end

	local missingCounts = {}
	for ing, count in pairs(recipe.Ingredients or {}) do
		missingCounts[ing] = count
	end

	local collectedTools = {}
	for _, tool in ipairs(backpack:GetChildren()) do
		if tool:IsA("Tool") and tool.Name ~= "Empty Glass" and missingCounts[tool.Name] and missingCounts[tool.Name] > 0 then
			table.insert(collectedTools, tool)
			missingCounts[tool.Name] -= 1
		end
	end

	local missingList = {}
	for ing, cnt in pairs(missingCounts) do
		if cnt > 0 then
			table.insert(missingList, string.format("%s x%d", ing, cnt))
		end
	end

	if #missingList > 0 then
		self.ShowError:Fire(player, "Missing ingredients: " .. table.concat(missingList, ", "))
		return false
	end

	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local nearBlender = false

	if root then
		for blenderInst, _ in pairs(DrinkService.Blenders) do
			local pos
			if blenderInst:IsA("Model") then
				pos = (blenderInst.PrimaryPart and blenderInst.PrimaryPart.Position) or blenderInst:GetPivot().Position
			elseif blenderInst:IsA("MeshPart") or blenderInst:IsA("Part") then
				pos = blenderInst.Position
			end
			if pos and (root.Position - pos).Magnitude <= 10 then
				nearBlender = true
				break
			end
		end
	end

	if not nearBlender then
		return false
	end

	local totalVolume = 0
	local mixedR, mixedG, mixedB = 0, 0, 0
	local liquidTypes = {}
	local ingredientNames = {}

	for _, tool in ipairs(collectedTools) do
		local ingredientData = Ingredients[tool.Name]
		if ingredientData then
			local volume = ingredientData.Volume or 25
			local color = ingredientData.LiquidColor or Color3.new(1, 1, 1)

			mixedR = mixedR + (color.R * volume)
			mixedG = mixedG + (color.G * volume) 
			mixedB = mixedB + (color.B * volume)
			totalVolume = totalVolume + volume

			if not liquidTypes[ingredientData.Type] then
				liquidTypes[ingredientData.Type] = 0
			end
			liquidTypes[ingredientData.Type] = liquidTypes[ingredientData.Type] + 1

			table.insert(ingredientNames, tool.Name)
		end
	end

	if totalVolume > 0 then
		mixedR = mixedR / totalVolume
		mixedG = mixedG / totalVolume
		mixedB = mixedB / totalVolume
	end

	local useDisplayName = recipe.UseDisplayName == true
	local drinkName = recipe.DisplayName
	local drinkDescription = "Blended drink"

	if not useDisplayName then
		local cupType = emptyGlass:GetAttribute("CupType") or "Regular"
		drinkName = DrinkNameGenerator.GenerateName(ingredientNames, liquidTypes, cupType)
		drinkDescription = DrinkNameGenerator.GenerateDescription(ingredientNames, totalVolume)
	elseif not recipe.DisplayName or recipe.DisplayName == "Custom Blend" then
		local cupType = emptyGlass:GetAttribute("CupType") or "Regular"
		drinkName = DrinkNameGenerator.GenerateName(ingredientNames, liquidTypes, cupType)
		drinkDescription = DrinkNameGenerator.GenerateDescription(ingredientNames, totalVolume)
	end

	local glassContent = emptyGlass:FindFirstChild("Content")

	if glassContent then

		if glassContent:IsA("MeshPart") then
			glassContent.Color = Color3.new(mixedR, mixedG, mixedB)
			glassContent.Transparency = math.max(0.2, 1 - (totalVolume / 100))

			local originalSize = glassContent:GetAttribute("OriginalSize")
			if not originalSize then
				originalSize = glassContent.Size
				glassContent:SetAttribute("OriginalSize", originalSize)
			end

			local fillPercentage = math.min(totalVolume / 80, 1)
			glassContent.Size = Vector3.new(originalSize.X, originalSize.Y * fillPercentage, originalSize.Z)
		end

		local contentValue = glassContent:FindFirstChild("DrinkData") or Instance.new("StringValue")
		contentValue.Name = "DrinkData"
		contentValue.Value = drinkDescription
		contentValue.Parent = glassContent

		local ingredientsValue = glassContent:FindFirstChild("Ingredients") or Instance.new("StringValue")
		ingredientsValue.Name = "Ingredients"
		ingredientsValue.Value = table.concat(ingredientNames, ", ")
		ingredientsValue.Parent = glassContent
	end

	emptyGlass.Name = drinkName

	self.DrinkMade:Fire(player, recipeId)
	return true
end

function DrinkService:HandleClientRequest(player, method, ...)
	if method == "GetRecipes" then
		return Recipes
	elseif method == "GetIngredientData" then
		return Ingredients
	elseif method == "CollectIngredient" then
		return self:CollectIngredient(player, ...)
	elseif method == "TrashCup" then
		return self:TrashCup(player, ...)
	elseif method == "RequestMakeDrink" then
		return self:RequestMakeDrink(player, ...)
	elseif method == "GetEquippedCupContents" then
		return self:GetEquippedCupContents(player)
	elseif method == "ConsumeCup" then
		return self:ConsumeCup(player)
	elseif method == "PlaceDrink" then
		return self:PlaceDrink(player, ...)
	end
end

function DrinkService:CollectIngredient(player, ingredientName)
	local equippedCup = self:GetEquippedCup(player)
	if not equippedCup then
		return false
	end

	local ingredientData = Ingredients[ingredientName]
	if not ingredientData then
		return false
	end

	local volume = ingredientData.Volume or 25
	if ingredientData.IsTopping and equippedCup.Contents.Ingredients[ingredientName] and equippedCup.Contents.Ingredients[ingredientName] > 0 then
		self.ShowError:Fire(player, "This drink already has " .. ingredientName .. "!")
		return false
	end

	if equippedCup.Contents.TotalVolume >= 100 then
		self.ShowError:Fire(player, "Your cup is full! Click to consume it.")
		return false
	end

	if not equippedCup:CanUseIngredient(ingredientData, ingredientName) then
		if equippedCup.CupType == "Coffee" then
			self.ShowError:Fire(player, "Coffee cups can only be used with coffee ingredients!")
		else
			self.ShowError:Fire(player, "This ingredient can't be used with this cup type!")
		end
		return false
	end

	local success = equippedCup:AddIngredient(ingredientData, ingredientName)

	if success then
		self.IngredientCollected:Fire(player, ingredientName, equippedCup.Contents.TotalVolume)

		if equippedCup:IsReadyToConsume() then
			self.DrinkReady:Fire(player)
		end

		return true
	else
		if equippedCup.Contents.IsConsuming then
			self.ShowError:Fire(player, "Cannot add ingredients while consuming!")
		elseif equippedCup.Contents.TotalVolume >= 100 then
			self.ShowError:Fire(player, "Your cup is full! Click to consume it.")
		else
			self.ShowError:Fire(player, "Cannot add ingredient to cup.")
		end
		return false
	end
end

function DrinkService:TrashCup(player, trashModel)
	local character = player.Character
	if not character then
		self.ShowError:Fire(player, "No character found")
		return false
	end

	local cupTool = nil
	local cupName = "Cup"
	local cupComponent = nil

	for _, tool in pairs(character:GetChildren()) do
		if tool:IsA("Tool") and CollectionService:HasTag(tool, "Cup") then
			cupTool = tool
			cupName = tool.Name
			cupComponent = self.Cups[tool]
			break
		end
	end

	if not cupTool then
		local backpack = player:FindFirstChild("Backpack")
		if backpack then
			for _, tool in pairs(backpack:GetChildren()) do
				if tool:IsA("Tool") and CollectionService:HasTag(tool, "Cup") then
					cupTool = tool
					cupName = tool.Name
					cupComponent = self.Cups[tool]
					break
				end
			end
		end
	end

	if not cupTool then
		self.ShowError:Fire(player, "No cup found to trash")
		return false
	end

	if cupComponent then
		for _, anim in pairs(cupComponent.LoadedAnimations or {}) do
			if anim then
				anim:Stop()
			end
		end
	end

	cupTool:Destroy()
	self.ShowError:Fire(player, "Trashed: " .. cupName)
	return true
end

function DrinkService:RequestMakeDrink(player, recipeId)
	return self:_processCraftRequest(player, recipeId)
end

function DrinkService:GetEquippedCupContents(player)
	local equippedCup = self:GetEquippedCup(player)
	if equippedCup then
		return {
			Ingredients = equippedCup.Contents.Ingredients,
			TotalVolume = equippedCup.Contents.TotalVolume,
			MixedColor = equippedCup.Contents.MixedColor,
			DrinkName = equippedCup.Tool.Name,
			ContentsString = equippedCup:GetContentsString()
		}
	end
	return nil
end

function DrinkService:ConsumeCup(player)
	local currentTime = tick()
	local lastDrinkTime = self.DrinkCooldowns[player.UserId] or 0

	if currentTime - lastDrinkTime < 3 then
		return false
	end

	local equippedCup = self:GetEquippedCup(player)
	if equippedCup and equippedCup:IsReadyToConsume() then
		self.DrinkCooldowns[player.UserId] = currentTime

		if equippedCup.LoadedAnimations["Consume"] then
			local drinkAnimation = equippedCup.LoadedAnimations["Consume"]
			drinkAnimation:Play()

			task.delay(drinkAnimation.Length * 0.5, function()
				local success, message = equippedCup:ConsumePortion()
				if success then
					self.DrinkConsumed:Fire(player, message)
				end
			end)

			task.delay(drinkAnimation.Length, function()
				if equippedCup.LoadedAnimations["Idle"] then
					equippedCup.LoadedAnimations["Idle"].Looped = true
					equippedCup.LoadedAnimations["Idle"]:Play()
				end
			end)

		else
			warn("Consume animation not found for cup: " .. equippedCup.Instance.Name)
			local success, message = equippedCup:ConsumePortion()
			if success then
				self.DrinkConsumed:Fire(player, message)
			end
		end
		return true
	end
	return false
end

function DrinkService:PlaceDrink(player, cframe, drinkData)
	return self:_processPlaceDrink(player, cframe, drinkData)
end

function DrinkService:_processPlaceDrink(player, cframe, drinkData)
	local character = player.Character
	if not character then return false end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return false end

	local distance = (cframe.Position - humanoidRootPart.Position).Magnitude
	if distance > 50 then
		return false
	end

	if not drinkData then
		return false
	end

	local equippedCup = self:GetEquippedCup(player)
	if not equippedCup then
		return false
	end

	local tool = equippedCup.Instance
	if tool then
		local character = player.Character
		if character and tool.Parent == character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid:UnequipTools()
			end
		end

		task.wait(0.1)

		local placedModel = Instance.new("Model")
		placedModel.Name = tool.Name
		placedModel.Parent = workspace

		local hasValidPart = false
		for _, child in pairs(tool:GetChildren()) do
			if child:IsA("Part") or child:IsA("MeshPart") or child:IsA("UnionOperation") then
				local clonedChild = child:Clone()
				clonedChild.Parent = placedModel
				hasValidPart = true
				if child.Name == "Handle" then
					placedModel.PrimaryPart = clonedChild
					clonedChild.Anchored = true
					clonedChild.CanCollide = true
				end
			elseif not child:IsA("Script") and not child:IsA("LocalScript") and not child:IsA("Animation") then
				local clonedChild = child:Clone()
				clonedChild.Parent = placedModel
			end
		end

		if not hasValidPart then
			placedModel:Destroy()
			return false
		end

		local primaryPart = placedModel.Handle
		if primaryPart then
			local offsetY = primaryPart.Size.Y / 6
			local adjustedCFrame = cframe + Vector3.new(0, offsetY, 0)
			placedModel:PivotTo(adjustedCFrame)
		else
			placedModel:PivotTo(cframe)
		end

		placedModel:SetAttribute("DrinkName", drinkData.DrinkName)
		placedModel:SetAttribute("TotalVolume", drinkData.TotalVolume)
		placedModel:SetAttribute("CupState", drinkData.CupState)
		placedModel:SetAttribute("DrinkDescription", drinkData.DrinkDescription)
		placedModel:SetAttribute("ContentsString", drinkData.ContentsString)

		local HttpService = game:GetService("HttpService")
		placedModel:SetAttribute("Ingredients", HttpService:JSONEncode(drinkData.Ingredients or {}))
		placedModel:SetAttribute("MixingOrder", HttpService:JSONEncode(drinkData.MixingOrder or {}))
		placedModel:SetAttribute("MixedColor", drinkData.MixedColor)

		local originalToolName = equippedCup.OriginalName or tool.Name
		placedModel:SetAttribute("OriginalToolName", originalToolName)

		CollectionService:AddTag(placedModel, "PlacedDrink")

		tool.Parent = placedModel
		tool.Name = "StoredTool"
		return true
	end

	return false
end

function DrinkService:PickupPlacedDrink(player, drinkInstance)
	if not drinkInstance or not drinkInstance.Parent then return end

	local equippedCup = self:GetEquippedCup(player)
	if equippedCup then
		self.ShowError:Fire(player, "You already have a drink! Finish it first.")
		return
	end

	if drinkInstance:IsA("Model") and CollectionService:HasTag(drinkInstance, "PlacedDrink") then
		local storedTool = drinkInstance:FindFirstChild("StoredTool")
		if storedTool and storedTool:IsA("Tool") then
			local backpack = player:FindFirstChild("Backpack")
			if backpack then
				local originalName = drinkInstance:GetAttribute("DrinkName") or "Cup"
				storedTool.Name = originalName
				storedTool.Parent = backpack

				CollectionService:RemoveTag(drinkInstance, "PlacedDrink")
				drinkInstance:Destroy()

				self.ShowError:Fire(player, "Picked up: " .. originalName)
			end
		else
			warn("No stored tool found in placed drink model")
		end
	end
end

return DrinkService
