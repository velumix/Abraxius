local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Mince = require(ReplicatedStorage.Modules.Mince)
local Component = Mince.Component
local UI = require(ReplicatedStorage.Modules.UI)

local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()

local DrinkController = {
	Name = "DrinkController",
	Ingredients = {},
	Cups = {},
	TrashBins = {},
	CurrentCup = nil,
	CurrentHighlightedIngredient = nil,
	CurrentHighlightedTrash = nil,

	PlacementMode = false,
	PlacementPreview = nil,
	PlacementValidation = false,
	PlacementConnection = nil,
	PlacementPreviewConnection = nil,
	LastClickTime = 0,

	TouchStartTime = 0,
	TouchStartPosition = Vector2.new(0, 0),
	LastTapTime = 0,
	LongPressThreshold = 0.5,
	DoubleTapThreshold = 0.3,
	TapMovementThreshold = 50,
}

function DrinkController:Setup()
	self.DrinkEvents = Mince:GetEvent("DrinkService")
	self.DrinkRequests = Mince:GetEvent("DrinkRequests")

	self.DrinkMade = self.DrinkEvents:Extend("DrinkMade")
	self.ShowError = self.DrinkEvents:Extend("ShowError")
	self.IngredientCollected = self.DrinkEvents:Extend("IngredientCollected")
	self.DrinkReady = self.DrinkEvents:Extend("DrinkReady")
	self.DrinkConsumed = self.DrinkEvents:Extend("DrinkConsumed")
	self.TrashHighlight = self.DrinkEvents:Extend("TrashHighlight")
end

function DrinkController:GameStart()
	self.Connections = {
		DrinkMade = self.DrinkMade.Event:Connect(function(recipeId)
			UI.Notify("You made " .. recipeId, "Success")
		end),
		ShowError = self.ShowError.Event:Connect(function(msg)

		end),
		IngredientCollected = self.IngredientCollected.Event:Connect(function(ingredientName, totalVolume)
			UI.Notify(string.format("Added %s (%.0f/100)", ingredientName, totalVolume), "Info")
			self:UpdateClientCupStateFromServer(ingredientName, totalVolume)
		end),
		DrinkReady = self.DrinkReady.Event:Connect(function()
			UI.Notify("Beverage is ready! Click to consume it!", "Success")
		end),
		DrinkConsumed = self.DrinkConsumed.Event:Connect(function()
			self:SyncCupFromServer()
		end),

		Response = self.DrinkRequests.Event:Connect(function(responseType, method, result)
			if responseType == "Response" then
				if method == "GetIngredientData" then
					self.IngredientData = result
				elseif method == "GetEquippedCupContents" then
					self:HandleCupContentsResponse(result)
				end
			end
		end),
	}

	self.ClickDetectionEnabled = false
	self.LastClickTime = 0

	self.DrinkRequests:Fire("GetIngredientData")

	self:SetupPlacementInput()
end

local Ingredient = Component{Tag = "Ingredient"}
local Cup = Component{Tag = "Cup"}
local Trash = Component{Tag = "TrashBin"}
local PlacedDrink = Component{Tag = "PlacedDrink"}

function Ingredient:Construct()
	DrinkController.Ingredients[self.Instance] = self
end

function Ingredient:Stop()
	DrinkController.Ingredients[self.Instance] = nil
end

function Cup:Construct()
	DrinkController.Cups[self.Instance] = self

	self.CupType = self.Instance:GetAttribute("CupType") or "Regular"

	self.Contents = {
		Ingredients = {},
		TotalVolume = 0,
		MixedColor = Color3.new(1, 1, 1),
	}

	local tool = self.Instance
	if tool:IsA("Tool") then
		tool.Equipped:Connect(function()
			DrinkController.CurrentCup = self
			DrinkController:StartCupClickDetection()
			DrinkController:SyncCupFromServer()
			if UserInputService.TouchEnabled then
				UI.CreatePlacementButton(function()
					DrinkController:TogglePlacementMode()
				end)
			end
		end)

		tool.Unequipped:Connect(function()
			if DrinkController.CurrentCup == self then
				DrinkController.CurrentCup = nil
				DrinkController:StopCupClickDetection()
				if UserInputService.TouchEnabled then
					UI.HidePlacementButton()
				end
			end
		end)

		tool.Activated:Connect(function()
			DrinkController:HandleCupActivation()
		end)
	end
end

function Cup:Stop()
	if DrinkController.CurrentCup == self then
		DrinkController.CurrentCup = nil
		DrinkController:StopCupClickDetection()
		if UserInputService.TouchEnabled then
			UI.HidePlacementButton()
		end
	end
	DrinkController.Cups[self.Instance] = nil
end

function Trash:Construct()
	DrinkController.TrashBins = DrinkController.TrashBins or {}
	DrinkController.TrashBins[self.Instance] = self

	local model = self.Instance
	if not model:IsA("Model") then
		warn("Trash component can only be applied to Models")
		return
	end
end

function Trash:Stop()
	if DrinkController.TrashBins then
		DrinkController.TrashBins[self.Instance] = nil
	end
end

function PlacedDrink:Construct()
	local handle

	if self.Instance:IsA("Model") then
		handle = self.Instance.PrimaryPart or 
			self.Instance:FindFirstChild("Handle") or 
			self.Instance:FindFirstChildOfClass("Part") or 
			self.Instance:FindFirstChildOfClass("MeshPart")
	else
		handle = self.Instance:FindFirstChild("Handle") or 
			self.Instance:FindFirstChildOfClass("Part") or 
			self.Instance:FindFirstChildOfClass("MeshPart")
	end

	if handle then
		self.ClickDetector = handle:FindFirstChildOfClass("ClickDetector")

		if self.ClickDetector then
			self:SetupHighlight()
		end
	end
end

function PlacedDrink:SetupHighlight()
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(45, 180, 220)
	highlight.OutlineColor = Color3.fromRGB(65, 200, 240)
	highlight.FillTransparency = 0.5
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Enabled = false
	highlight.Parent = self.Instance

	self.Highlight = highlight

	-- Show highlight on hover
	self.HoverEnterConnection = self.ClickDetector.MouseHoverEnter:Connect(function()
		highlight.Enabled = true
	end)

	self.HoverLeaveConnection = self.ClickDetector.MouseHoverLeave:Connect(function()
		highlight.Enabled = false
	end)
end

function PlacedDrink:Stop()
	if self.HoverEnterConnection then
		self.HoverEnterConnection:Disconnect()
		self.HoverEnterConnection = nil
	end

	if self.HoverLeaveConnection then
		self.HoverLeaveConnection:Disconnect()
		self.HoverLeaveConnection = nil
	end

	if self.Highlight then
		self.Highlight:Destroy()
		self.Highlight = nil
	end
end

function DrinkController:HighlightTrash(trashModel, shouldHighlight)
	if not trashModel or not trashModel:IsA("Model") then
		return
	end

	local highlight = trashModel:FindFirstChild("TrashHighlight")

	if shouldHighlight then
		if not highlight then
			highlight = Instance.new("Highlight")
			highlight.Name = "TrashHighlight"
			highlight.FillColor = Color3.new(1, 0, 0)
			highlight.OutlineColor = Color3.new(1, 0.2, 0.2)
			highlight.FillTransparency = 0.5
			highlight.OutlineTransparency = 0
			highlight.Parent = trashModel
		end
		highlight.Enabled = true
	else
		if highlight then
			highlight.Enabled = false
		end
	end
end

function DrinkController:CreateHighlight(part)
	local highlight = Instance.new("Highlight")
	highlight.Name = "IngredientHighlight"
	highlight.Adornee = part
	highlight.FillColor = Color3.fromRGB(45, 180, 220)
	highlight.OutlineColor = Color3.fromRGB(65, 200, 240)
	highlight.FillTransparency = 0.7
	highlight.OutlineTransparency = 0.3
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = part
	return highlight
end

function DrinkController:RemoveHighlight(part)
	local highlight = part:FindFirstChild("IngredientHighlight")
	if highlight then
		highlight:Destroy()
	end
end

function DrinkController:UpdateIngredientHighlight()
	if not self.CurrentCup or not self.ClickDetectionEnabled then 
		self:ClearAllHighlights()
		return 
	end

	local camera = workspace.CurrentCamera
	local unitRay = camera:ScreenPointToRay(Mouse.X, Mouse.Y)

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {Player.Character}

	local raycastResult = workspace:Raycast(unitRay.Origin, unitRay.Direction * 100, raycastParams)

	local hoveredIngredient = nil
	local hoveredTrash = nil
	if raycastResult then
		local hitPart = raycastResult.Instance
		hoveredTrash = self:FindTrashFromPart(hitPart)
		if not hoveredTrash then
			hoveredIngredient = self:FindIngredientFromPart(hitPart)
		end
	end

	if self.CurrentHighlightedIngredient and 
		(not hoveredIngredient or hoveredIngredient.Instance ~= self.CurrentHighlightedIngredient) then
		self:RemoveHighlight(self.CurrentHighlightedIngredient)
		self.CurrentHighlightedIngredient = nil
	end

	if self.CurrentHighlightedTrash and 
		(not hoveredTrash or hoveredTrash.Instance ~= self.CurrentHighlightedTrash) then
		self:HighlightTrash(self.CurrentHighlightedTrash, false)
		self.CurrentHighlightedTrash = nil
	end
	if hoveredTrash and hoveredTrash.Instance ~= self.CurrentHighlightedTrash then
		self:HighlightTrash(hoveredTrash.Instance, true)
		self.CurrentHighlightedTrash = hoveredTrash.Instance
	elseif hoveredIngredient and hoveredIngredient.Instance ~= self.CurrentHighlightedIngredient then
		if self:CanCollectIngredient(hoveredIngredient.Name) then
			self:CreateHighlight(hoveredIngredient.Instance)
			self.CurrentHighlightedIngredient = hoveredIngredient.Instance
		end
	end
end

function DrinkController:ClearAllHighlights()
	if self.CurrentHighlightedIngredient then
		self:RemoveHighlight(self.CurrentHighlightedIngredient)
		self.CurrentHighlightedIngredient = nil
	end

	if self.CurrentHighlightedTrash then
		self:HighlightTrash(self.CurrentHighlightedTrash, false)
		self.CurrentHighlightedTrash = nil
	end
end

function DrinkController:StartCupClickDetection()
	if self.ClickDetectionEnabled then return end

	self.ClickDetectionEnabled = true

	if not self.MouseConnection then
		self.MouseConnection = Mouse.Button1Down:Connect(function()
			self:HandleMouseClick()
		end)
	end

	if not self.HighlightConnection then
		self.HighlightConnection = RunService.Heartbeat:Connect(function()
			self:UpdateIngredientHighlight()
		end)
	end
end

function DrinkController:StopCupClickDetection()
	if not self.ClickDetectionEnabled then return end

	self.ClickDetectionEnabled = false

	if self.MouseConnection then
		self.MouseConnection:Disconnect()
		self.MouseConnection = nil
	end
	if self.HighlightConnection then
		self.HighlightConnection:Disconnect()
		self.HighlightConnection = nil
	end

	self:ClearAllHighlights()
end

function DrinkController:HandleMouseClick()
	if self.PlacementMode then return end

	if not self.CurrentCup or not self.ClickDetectionEnabled then return end

	local currentTime = tick()
	if currentTime - self.LastClickTime < 0.3 then return end
	self.LastClickTime = currentTime

	local camera = workspace.CurrentCamera
	local unitRay = camera:ScreenPointToRay(Mouse.X, Mouse.Y)

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {Player.Character}

	local raycastResult = workspace:Raycast(unitRay.Origin, unitRay.Direction * 100, raycastParams)

	if raycastResult then
		local hitPart = raycastResult.Instance

		local trashFound = self:FindTrashFromPart(hitPart)
		if trashFound then
			self.DrinkRequests:Fire("TrashCup", trashFound.Instance)
			return
		end

		local ingredientFound = self:FindIngredientFromPart(hitPart)
		if ingredientFound then
			if self:CanCollectIngredient(ingredientFound.Name) then
				self.DrinkRequests:Fire("CollectIngredient", ingredientFound.Name)
			end
		end
	end
end

function DrinkController:FindIngredientFromPart(hitPart)
	local ingredient = self.Ingredients[hitPart]
	if ingredient then
		return {Name = hitPart.Name, Instance = hitPart}
	end

	local parent = hitPart.Parent
	while parent and parent ~= workspace do
		local parentIngredient = self.Ingredients[parent]
		if parentIngredient then
			return {Name = parent.Name, Instance = parent}
		end
		parent = parent.Parent
	end

	return nil
end

function DrinkController:FindTrashFromPart(hitPart)
	if CollectionService:HasTag(hitPart, "Trash") then
		return {Name = hitPart.Name, Instance = hitPart}
	end

	local parent = hitPart.Parent
	while parent and parent ~= workspace do
		if CollectionService:HasTag(parent, "Trash") then
			return {Name = parent.Name, Instance = parent}
		end
		parent = parent.Parent
	end

	return nil
end

function DrinkController:IsHoveringOverIngredient()
	local camera = workspace.CurrentCamera
	local unitRay = camera:ScreenPointToRay(Mouse.X, Mouse.Y)

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {Player.Character}

	local raycastResult = workspace:Raycast(unitRay.Origin, unitRay.Direction * 100, raycastParams)

	if raycastResult then
		local hitPart = raycastResult.Instance
		local ingredientFound = self:FindIngredientFromPart(hitPart)

		if ingredientFound then
			return ingredientFound
		end
	end

	return nil
end

function DrinkController:HandleCupActivation()
	if not self.CurrentCup then return end
	if self.PlacementMode then return end

	local hoveredIngredient = self:IsHoveringOverIngredient()
	if hoveredIngredient then
		if hoveredIngredient.Name == "Cream" then
			if self.CurrentCup.Contents.Ingredients["Cream"] and self.CurrentCup.Contents.Ingredients["Cream"] > 0 then
				UI.Notify("This beverage already has cream!", "Warning")
			end
		else
			if self.CurrentCup.Contents.TotalVolume >= 100 then
				UI.Notify("Cup is full! Can't add more " .. hoveredIngredient.Name, "Warning")
			end
		end
		return
	end

	self:SyncCupFromServer()

	if self.CurrentCup.Contents.TotalVolume > 0 then
		self.DrinkRequests:Fire("ConsumeCup")
	end
end

function DrinkController:CanUseIngredientWithCup(cupType, ingredientData)
	if cupType == "Coffee" then
		return ingredientData.Type == "Coffee"
	elseif cupType == "Regular" then
		return true
	end
	return true
end

function DrinkController:CanCollectIngredient(ingredientName)
	if not self.CurrentCup then
		return false
	end

	if not self.IngredientData then
		return false
	end

	if not self.IngredientData[ingredientName] then
		return false
	end

	local ingredientData = self.IngredientData[ingredientName]
	local volume = ingredientData.Volume or 25
	local currentVolume = self.CurrentCup.Contents.TotalVolume

	if not self:CanUseIngredientWithCup(self.CurrentCup.CupType, ingredientData) then
		return false
	end

	if currentVolume >= 100 then
		return false
	end
	return true
end

function DrinkController:UpdateClientCupStateFromServer(ingredientName, totalVolume)
	if not self.CurrentCup or not self.IngredientData then return end

	local ingredientData = self.IngredientData[ingredientName]
	if not ingredientData then return end

	if not self.CurrentCup.Contents.Ingredients[ingredientName] then
		self.CurrentCup.Contents.Ingredients[ingredientName] = 0
	end
	self.CurrentCup.Contents.Ingredients[ingredientName] = self.CurrentCup.Contents.Ingredients[ingredientName] + 1

	self.CurrentCup.Contents.TotalVolume = totalVolume
end

function DrinkController:SyncCupFromServer()
	if not self.CurrentCup then return end
	self.DrinkRequests:Fire("GetEquippedCupContents")
end

function DrinkController:HandleCupContentsResponse(serverContents)
	if serverContents and self.CurrentCup then
		self.CurrentCup.Contents = {
			Ingredients = serverContents.Ingredients or {},
			TotalVolume = serverContents.TotalVolume or 0,
			MixedColor = serverContents.MixedColor or Color3.new(1, 1, 1),
		}
	end
end

function DrinkController:SetupPlacementInput()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.P then
			if not self.CurrentCup then
				return
			end
			self:TogglePlacementMode()
		elseif input.KeyCode == Enum.KeyCode.Escape and self.PlacementMode then
			self:ExitPlacementMode()
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 and self.PlacementMode then
			self:ExitPlacementMode()
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 and self.PlacementMode then
			self:AttemptPlacement()
		elseif input.UserInputType == Enum.UserInputType.Touch then
			if self.PlacementMode then
				self:HandleTouchBegan(input)
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType == Enum.UserInputType.Touch then
			if self.PlacementMode then
				self:HandleTouchEnded(input)
			end
		end
	end)
end

function DrinkController:HandleTouchBegan(input)
	self.TouchStartTime = tick()
	self.TouchStartPosition = input.Position
end

function DrinkController:HandleTouchEnded(input)
	local touchDuration = tick() - self.TouchStartTime
	local touchMovement = (input.Position - self.TouchStartPosition).Magnitude
	local currentTime = tick()

	if touchMovement > self.TapMovementThreshold then
		return
	end

	if touchDuration >= self.LongPressThreshold then
		self:HandleLongPress()
		return
	end

	if currentTime - self.LastTapTime <= self.DoubleTapThreshold then
		self:HandleDoubleTap()
		self.LastTapTime = 0
		return
	end

	self.LastTapTime = currentTime
	self:HandleSingleTap()
end

function DrinkController:HandleSingleTap()
	self:UpdatePlacementPreviewToTouch()
	UI.Notify("Tap preview positioned! Long press or double tap to place", "Info")
end

function DrinkController:HandleLongPress()
	self:AttemptPlacement()
end

function DrinkController:HandleDoubleTap()
	self:AttemptPlacement()
end

function DrinkController:UpdatePlacementPreviewToTouch()
	if not self.PlacementMode or not self.PlacementPreview then return end

	local camera = workspace.CurrentCamera
	local unitRay = camera:ScreenPointToRay(self.TouchStartPosition.X, self.TouchStartPosition.Y)

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {Player.Character, self.PlacementPreview}

	local raycastResult = workspace:Raycast(unitRay.Origin, unitRay.Direction * 100, raycastParams)
	if raycastResult then
		local hitPosition = raycastResult.Position

		local primaryPart = self.PlacementPreview.PrimaryPart or self.PlacementPreview:FindFirstChildOfClass("Part") or self.PlacementPreview:FindFirstChildOfClass("MeshPart")
		if primaryPart then
			local offsetY = primaryPart.Size.Y / 2
			self.PlacementPreview:SetPrimaryPartCFrame(CFrame.new(hitPosition + Vector3.new(0, offsetY, 0)))

			local isValid = self:ValidatePlacement(hitPosition, raycastResult.Instance)
			self.PlacementValidation = isValid
			self:UpdatePreviewAppearance(isValid)
		end
	end
end

function DrinkController:TogglePlacementMode()
	if self.PlacementMode then
		self:ExitPlacementMode()
	else
		self:EnterPlacementMode()
	end
end

function DrinkController:CanEnterPlacementMode()
	if not self.CurrentCup then
		return false, "You need to be holding a cup to place it"
	end

	return true, nil
end

function DrinkController:EnterPlacementMode()
	local canEnter, errorMsg = self:CanEnterPlacementMode()
	if not canEnter then
		UI.Notify(errorMsg, "Warning")
		return
	end

	self.PlacementMode = true

	local cupState = "empty"
	if self.CurrentCup.Contents.TotalVolume > 0 then
		if self.CurrentCup.Contents.TotalVolume >= 100 then
			cupState = "full"
		else
			cupState = "partial"
		end
	end

	local messages = {
		empty = "Placing empty cup: Tap to position preview, Long press or double tap to place, Right-click or ESC to cancel",
		partial = "Placing partial beverage: Tap to position preview, Long press or double tap to place, Right-click or ESC to cancel", 
		full = "Placing finished beverage: Tap to position preview, Long press or double tap to place, Right-click or ESC to cancel"
	}

	if UserInputService.TouchEnabled then
		messages = {
			empty = "Placing empty cup: Tap to position, Long press or double tap to place",
			partial = "Placing partial beverage: Tap to position, Long press or double tap to place", 
			full = "Placing finished beverage: Tap to position, Long press or double tap to place"
		}
	end

	UI.Notify(messages[cupState], "Info")

	self:CreatePlacementPreview()

	self.PlacementPreviewConnection = RunService.Heartbeat:Connect(function()
		self:UpdatePlacementPreview()
	end)
end

function DrinkController:ExitPlacementMode()
	if not self.PlacementMode then return end

	self.PlacementMode = false
	UI.Notify("Placement cancelled", "Info")

	if self.PlacementPreview then
		self.PlacementPreview:Destroy()
		self.PlacementPreview = nil
	end

	if self.PlacementPreviewConnection then
		self.PlacementPreviewConnection:Disconnect()
		self.PlacementPreviewConnection = nil
	end

	self.PlacementValidation = false
end

function DrinkController:CreatePlacementPreview()
	if not self.CurrentCup or not self.CurrentCup.Instance then return end

	local originalTool = self.CurrentCup.Instance
	if not originalTool:IsA("Tool") then return end

	self.PlacementPreview = originalTool:Clone()
	self.PlacementPreview.Name = "DrinkPreview"
	self.PlacementPreview.Parent = workspace

	local primaryPart = self.PlacementPreview.PrimaryPart or self.PlacementPreview:FindFirstChildOfClass("Part") or self.PlacementPreview:FindFirstChildOfClass("MeshPart")
	if primaryPart then
		self.PlacementPreview.PrimaryPart = primaryPart
	end

	for _, child in pairs(self.PlacementPreview:GetChildren()) do
		if child:IsA("Part") or child:IsA("MeshPart") then
			child.CanCollide = false
			child.Anchored = true
		end
	end

	self:UpdatePreviewAppearance(false)
end

function DrinkController:UpdatePreviewAppearance(isValid)
	if not self.PlacementPreview then return end

	for _, child in pairs(self.PlacementPreview:GetChildren()) do
		if child:IsA("Part") or child:IsA("MeshPart") then
			if child.Transparency >= 1 then
				continue
			end

			if isValid then
				child.Transparency = 0.5
				child.Color = Color3.fromRGB(0, 255, 0)
			else
				child.Transparency = 0.8
				child.Color = Color3.fromRGB(255, 0, 0)
			end
		end
	end
end

function DrinkController:UpdatePlacementPreview()
	if not self.PlacementMode or not self.PlacementPreview then return end

	local camera = workspace.CurrentCamera
	local unitRay = camera:ScreenPointToRay(Mouse.X, Mouse.Y)

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {Player.Character, self.PlacementPreview}

	local raycastResult = workspace:Raycast(unitRay.Origin, unitRay.Direction * 100, raycastParams)

	if raycastResult then
		local hitPosition = raycastResult.Position

		local primaryPart = self.PlacementPreview.PrimaryPart or self.PlacementPreview:FindFirstChildOfClass("Part") or self.PlacementPreview:FindFirstChildOfClass("MeshPart")
		if primaryPart then
			local offsetY = primaryPart.Size.Y / 2
			self.PlacementPreview:SetPrimaryPartCFrame(CFrame.new(hitPosition + Vector3.new(0, offsetY, 0)))

			local isValid = self:ValidatePlacement(hitPosition, raycastResult.Instance)
			self.PlacementValidation = isValid
			self:UpdatePreviewAppearance(isValid)
		end
	else
		self.PlacementValidation = false
		self:UpdatePreviewAppearance(false)
		if self.PlacementPreview.PrimaryPart then
			self.PlacementPreview:SetPrimaryPartCFrame(CFrame.new(0, -1000, 0))
		end
	end
end

function DrinkController:ValidatePlacement(position, hitPart)
	local playerPosition = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
	if not playerPosition then return false end

	local distance = (position - playerPosition.Position).Magnitude
	if distance > 50 then
		return false
	end

	if not hitPart or hitPart.CanCollide == false then
		return false
	end

	if not CollectionService:HasTag(hitPart, "Surface") then
		return false
	end

	return true
end

function DrinkController:AttemptPlacement()
	if not self.PlacementMode or not self.PlacementValidation then
		UI.Notify("Cannot place drink here!", "Warning")
		return
	end

	if not self.PlacementPreview then
		UI.Notify("No preview available!", "Warning")
		return
	end

	local previewCFrame = self.PlacementPreview:GetPivot()
	local cupData = self:GetCurrentCupData()
	if cupData then
		self.DrinkRequests:Fire("PlaceDrink", previewCFrame, cupData)

		local placementType = cupData.CupState or "cup"
		local messages = {
			empty = "Empty cup placed!",
			partial = "Partial beverage placed!",
			full = "Finished beverage placed!"
		}
		UI.Notify(messages[placementType] or "Cup placed successfully!", "Success")
		self:ExitPlacementMode()
	end
end

function DrinkController:GetCurrentCupData()
	if not self.CurrentCup or not self.CurrentCup.Contents then return nil end

	local cupState = "empty"
	if self.CurrentCup.Contents.TotalVolume > 0 then
		if self.CurrentCup.Contents.TotalVolume >= 100 then
			cupState = "full"
		else
			cupState = "partial"
		end
	end

	return {
		DrinkName = self.CurrentCup.Instance.Name or "Cup",
		Ingredients = self.CurrentCup.Contents.Ingredients or {},
		MixedColor = self.CurrentCup.Contents.MixedColor or Color3.new(1, 1, 1),
		TotalVolume = self.CurrentCup.Contents.TotalVolume or 0,
		ContentsString = self:GenerateContentsString(),
		CupState = cupState,
		MixingOrder = self.CurrentCup.Contents.MixingOrder or {},
		DrinkDescription = self.CurrentCup.Contents.DrinkDescription or "A cup"
	}
end

function DrinkController:GenerateContentsString()
	if not self.CurrentCup or not self.CurrentCup.Contents then return "Empty Cup" end

	local ingredients = self.CurrentCup.Contents.Ingredients
	local totalVolume = self.CurrentCup.Contents.TotalVolume or 0

	if not ingredients or totalVolume <= 0 then
		return "Empty Cup"
	end

	local ingredientList = {}
	for ingredientName, amount in pairs(ingredients) do
		if amount > 0 then
			table.insert(ingredientList, string.format("%dx %s", amount, ingredientName))
		end
	end

	if #ingredientList == 0 then
		return "Empty Cup"
	end

	local contentsText = table.concat(ingredientList, ", ")
	local volumeText = string.format("%.0f/100", totalVolume)

	if totalVolume >= 100 then
		return string.format("%s (Ready to consume!)", contentsText)
	else
		return string.format("%s (%s)", contentsText, volumeText)
	end
end

return DrinkController