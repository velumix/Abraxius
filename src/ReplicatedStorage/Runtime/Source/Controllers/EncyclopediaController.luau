local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local Mince = require(ReplicatedStorage.Modules.Mince)
local UI = require(ReplicatedStorage.Modules.UI)
local Assets = ReplicatedStorage.Assets

local Player = game:GetService("Players").LocalPlayer

local DEFAULT_TOOL_NAME = "PDA"
local TOOL_EQUIP_LEAD_TIME = 0.5
local TOOL_STOW_DELAY = 0.25

local EncyclopediaController = {
	Name = "EncyclopediaController",
	ScannerConnection = nil,
	PendingScannerPayload = nil,
	PendingHighlightFishId = nil
}

local CATEGORY_TO_DISCOVERY = {
	["Corals & Plants"] = "Corals and Plants"
}

local function toDiscoveryCategory(categoryName)
	return CATEGORY_TO_DISCOVERY[categoryName] or categoryName
end

local DISCOVERY_TO_CATEGORY = {}
for categoryName, discoveryName in pairs(CATEGORY_TO_DISCOVERY) do
	DISCOVERY_TO_CATEGORY[discoveryName] = categoryName
end

local function toUICategoryName(discoveryType)
	return DISCOVERY_TO_CATEGORY[discoveryType] or discoveryType
end

local function highlightEncyclopediaEntry(fishId)
	if not fishId then
		return
	end

	if _G.UI and typeof(_G.UI) == "table" and _G.UI.HighlightEncyclopediaEntry then
		task.defer(function()
			_G.UI.HighlightEncyclopediaEntry(fishId)
		end)
	end
end

function EncyclopediaController:Setup()
	self.DiscoveryManager = Mince:Get("DiscoveryManager")
	self.TopbarManager = Mince:Get("TopbarManager")
	self.UIBlur = Lighting:FindFirstChild("UIBlurEffect")

	self.currentCategory = "Vertebrates"
	self.currentSelection = nil
	self.Data = {}
	self.DiscoveredFishLookup = {}

	self.toolState = "UNEQUIPPED" -- UNEQUIPPED, EQUIPPED, TRANSITIONING
	self.uiState = "HIDDEN" -- HIDDEN, VISIBLE, TRANSITIONING

	self.encyclopediaTool = nil
	self.stateChangeInProgress = false
	self.toolName = DEFAULT_TOOL_NAME
	self.tempTool = nil
	self.suppressAutoShow = false
	self.isStowingTool = false
	self.temporaryToolAttribute = "TemporaryPDA"
	self.toolEquipLeadTime = TOOL_EQUIP_LEAD_TIME
	self.toolStowDelay = TOOL_STOW_DELAY
	self.pendingStowToken = 0

	self.AnimationTrack = nil
	self.Animation = nil
	self.ANIMATION_ID = "rbxassetid://89978853791720"

	task.defer(function()
		self:connectScanner()
	end)
end

function EncyclopediaController:getUISystem()
	if not UI or not UI.Encyclopedia or not UI.Encyclopedia.System then
		print("Something went Wrong")
		return nil
	end
	return UI.Encyclopedia.System()
end

function EncyclopediaController:GameStart()
	self:loadData()
	self:setupToolEquipMonitoring()
	self:setupKeybinds()
	self:createAnimation()
	if self.DiscoveryManager then
		for _, discoveryType in ipairs(self.Data.DiscoveryTypes) do
			self.DiscoveryManager:RequestDiscoveries(discoveryType)
		end
	end
end

function EncyclopediaController:loadData()
	self.Data.Fish = {}
	self.Data.DiscoveryTypes = {
		"Corals and Plants",
		"Invertebrates",
		"Vertebrates"
	}

	local _Encyclopedia = Assets.Encyclopedia
	for _, Module in _Encyclopedia:GetChildren() do
		if Module:IsA("ModuleScript") then
			local ModuleData = require(Module)
			local ModuleName = Module.Name
			self.Data[ModuleName] = ModuleData

			if table.find(self.Data.DiscoveryTypes, ModuleName) then
				for Name, fishData in pairs(ModuleData) do
					if type(fishData) == "table" then
						self.Data.Fish[Name] = fishData
					end
				end
			end
		end
	end

	self.Data.Discoveries = {}
	for _, Type in self.Data.DiscoveryTypes do
		self.Data.Discoveries[Type] = self.DiscoveryManager.Discoveries[Type] or {}
	end
end

function EncyclopediaController:setupToolEquipMonitoring()
	local function onCharacterAdded(character)
		self.tempTool = nil
		self.isStowingTool = false

		local function onChildAdded(child)
			if child:IsA("Tool") and child.Name == (self.toolName or DEFAULT_TOOL_NAME) then
				self:playAnimation(character)
				if not self.suppressAutoShow and not self:IsVisible() then
					self:Show()
				end
			end
		end

		local function onChildRemoved(child)
			if child:IsA("Tool") and child.Name == (self.toolName or DEFAULT_TOOL_NAME) then
				self:stopAnimation()
				if not self.isStowingTool and self:IsVisible() then
					self:Hide()
				end
			end
		end

		character.ChildAdded:Connect(onChildAdded)
		character.ChildRemoved:Connect(onChildRemoved)

		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Tool") and child.Name == (self.toolName or DEFAULT_TOOL_NAME) then
				onChildAdded(child)
			end
		end

		task.defer(function()
			if self:IsVisible() then
				self:PrepareTool()
			end
		end)
	end

	if Player.Character then
		onCharacterAdded(Player.Character)
	end

	Player.CharacterAdded:Connect(onCharacterAdded)
end

function EncyclopediaController:setupKeybinds()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.Escape and self:IsVisible() then
			self:Hide()
		end
	end)
end

function EncyclopediaController:connectScanner()
	if self.ScannerConnection then
		return
	end

	if self._connectingScannerPending then
		return
	end

	local scanController = Mince:Get("ScanController")
	if not (scanController and scanController.EncyclopediaRequested and scanController.EncyclopediaRequested.Connect) then
		self._connectingScannerPending = true
		task.delay(0.1, function()
			self._connectingScannerPending = false
			if not self.ScannerConnection then
				self:connectScanner()
			end
		end)
		return
	end

	self.ScannerConnection = scanController.EncyclopediaRequested:Connect(function(payload)
		self:OnScannerEncyclopediaRequested(payload)
	end)
end

function EncyclopediaController:OnScannerEncyclopediaRequested(payload)
	if not payload then
		return
	end

	local fishId = payload.fishId or payload.id
	if not fishId then
		return
	end

	self.PendingScannerPayload = payload
	self.PendingHighlightFishId = fishId

	if Player then
		Player:SetAttribute("LastScannedFishId", fishId)
		Player:SetAttribute("LastScannedDiscoveryType", payload.discoveryType or nil)
	end

	if self:IsVisible() then
		self:ApplyLastScannedSelection()
		return
	end

	local toolEquipped = self:PrepareTool()

	if not self:IsVisible() then
		self:Show()
	end

	if toolEquipped then
		task.defer(function()
			self:ApplyLastScannedSelection()
		end)
	else
		self:ApplyLastScannedSelection()
	end
end

function EncyclopediaController:EquipEncyclopediaTool()
	if not Player then
		return false
	end

	local character = Player.Character
	if not character then
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end

	local toolName = self.toolName or DEFAULT_TOOL_NAME
	local tool = character:FindFirstChild(toolName)

	if not tool then
		local backpack = Player:FindFirstChildOfClass("Backpack") or Player:FindFirstChild("Backpack")
		if backpack then
			tool = backpack:FindFirstChild(toolName)
		end
	end

	if not (tool and tool:IsA("Tool")) then
		return false
	end

	if tool.Parent ~= character then
		tool.Parent = character
	end

	tool.CanBeDropped = false

	local ok = pcall(function()
		humanoid:EquipTool(tool)
	end)

	return ok
end

function EncyclopediaController:PrepareTool()
	if self:EquipEncyclopediaTool() then
		return true
	end

	if not Player then
		return false
	end

	local character = Player.Character
	if not character then
		return false
	end

	local toolName = self.toolName or DEFAULT_TOOL_NAME
	local toolAsset = Assets:FindFirstChild(toolName, true)

	if not (toolAsset and toolAsset:IsA("Tool")) then
		warn("EncyclopediaController: Unable to locate PDA tool '" .. toolName .. "' in Assets")
		return false
	end

	self.suppressAutoShow = true

	local toolClone = toolAsset:Clone()
	toolClone.Name = toolName
	toolClone.CanBeDropped = false
	if self.temporaryToolAttribute then
		toolClone:SetAttribute(self.temporaryToolAttribute, true)
	end
	toolClone.Parent = character
	self.tempTool = toolClone

	local equipped = self:EquipEncyclopediaTool()
	if not equipped then
		if toolClone.Parent then
			toolClone.Parent = nil
		end
		toolClone:Destroy()
		self.tempTool = nil
	end

	self.suppressAutoShow = false

	return equipped
end

function EncyclopediaController:CancelPendingStow()
	self.pendingStowToken += 1
end

function EncyclopediaController:ScheduleStowAfterDelay()
	self.pendingStowToken += 1
	local token = self.pendingStowToken
	local delayTime = self.toolStowDelay or 0

	task.spawn(function()
		if delayTime > 0 then
			task.wait(delayTime)
		end
		if self.pendingStowToken == token then
			self:StowTool()
		end
	end)
end

function EncyclopediaController:StowTool()
	if self.isStowingTool then
		return
	end

	self.isStowingTool = true

	local toolName = self.toolName or DEFAULT_TOOL_NAME
	local character = Player and Player.Character or nil

	local function isTemporaryTool(tool)
		if not (tool and tool:IsA("Tool")) then
			return false
		end
		if self.tempTool and self.tempTool == tool then
			return true
		end
		if self.temporaryToolAttribute then
			return tool:GetAttribute(self.temporaryToolAttribute) == true
		end
		return false
	end

	if character then
		local tool = character:FindFirstChild(toolName)
		if isTemporaryTool(tool) then
			tool.Parent = nil
			tool:Destroy()
		end
	end

	local backpack = nil
	if Player then
		backpack = Player:FindFirstChildOfClass("Backpack") or Player:FindFirstChild("Backpack")
	end

	if backpack then
		local tool = backpack:FindFirstChild(toolName)
		if isTemporaryTool(tool) then
			tool.Parent = nil
			tool:Destroy()
		end
	end

	if self.tempTool then
		if self.tempTool.Parent then
			self.tempTool.Parent = nil
		end
		if self.tempTool:IsDescendantOf(game) then
			self.tempTool:Destroy()
		end
		self.tempTool = nil
	end

	self.isStowingTool = false
	self:stopAnimation()
end

function EncyclopediaController:Show()
	self:CancelPendingStow()

	local leadTime = self.toolEquipLeadTime or 0
	local toolEquipped = self:PrepareTool()

	if toolEquipped and leadTime > 0 then
		task.wait(leadTime)
	end

	if toolEquipped then
		self:EquipEncyclopediaTool()
	end

	local sys = self:getUISystem()
	if not (UI and UI.Encyclopedia and sys) then
		return false
	end
	local result = UI.Encyclopedia.Show(sys)

	task.defer(function()
		if self:IsVisible() then
			self:ApplyLastScannedSelection()
		end
	end)

	return result
end

function EncyclopediaController:Hide()
	local sys = self:getUISystem()
	if not (UI and UI.Encyclopedia and sys) then
		return false
	end
	local result = UI.Encyclopedia.Hide(sys)
	self:ScheduleStowAfterDelay()
	return result
end

function EncyclopediaController:Toggle()
	local currentlyVisible = self:IsVisible()
	if currentlyVisible then
		self:Hide()
	else
		self:Show()
	end
	return not currentlyVisible
end

function EncyclopediaController:IsVisible()
	if not (UI and UI.Encyclopedia and UI.Encyclopedia.IsVisible) then
		return false
	end
	return UI.Encyclopedia.IsVisible()
end

function EncyclopediaController:SetCategory(categoryName)
	if not categoryName then return end
	self.currentCategory = categoryName
	local sys = self:getUISystem()
	if UI and UI.Encyclopedia and sys then
		UI.Encyclopedia.SetCategory(sys, categoryName)
	end
	if self.DiscoveryManager then
		self.DiscoveryManager:RequestDiscoveries(toDiscoveryCategory(categoryName))
	end
end

function EncyclopediaController:GetCurrentCategory()
	local sys = self:getUISystem()
	if UI and UI.Encyclopedia and sys then
		return UI.Encyclopedia.GetCurrentCategory(sys) or self.currentCategory
	end
	return self.currentCategory
end

function EncyclopediaController:SetSelection(fishName)
	self.currentSelection = fishName
	local sys = self:getUISystem()
	if UI and UI.Encyclopedia and sys then
		UI.Encyclopedia.SetSelection(sys, fishName)
	end
end

function EncyclopediaController:ClearSelection()
	self.currentSelection = nil
	local sys = self:getUISystem()
	if UI and UI.Encyclopedia and sys then
		UI.Encyclopedia.ClearSelection(sys)
	end
end

function EncyclopediaController:GetCurrentSelection()
	local sys = self:getUISystem()
	if UI and UI.Encyclopedia and sys then
		return UI.Encyclopedia.GetCurrentSelection(sys) or self.currentSelection
	end
	return self.currentSelection
end

function EncyclopediaController:refreshDiscoveries()
	local currentCategory = self:GetCurrentCategory() or "Vertebrates"
	if self.DiscoveryManager then
		local discoveryType = toDiscoveryCategory(currentCategory)
		self.DiscoveryManager:RequestDiscoveries(discoveryType)
		self.DiscoveredFishLookup = self.DiscoveryManager.Discoveries[discoveryType] or {}
	end
end

function EncyclopediaController:RecordDiscovery(discoveryType, discoveryName)
	if self.DiscoveryManager then
		return self.DiscoveryManager:RecordDiscovery(toDiscoveryCategory(discoveryType), discoveryName)
	end
	return false
end

function EncyclopediaController:HasDiscovered(discoveryType, discoveryName)
	if self.DiscoveryManager then
		return self.DiscoveryManager:HasDiscovered(toDiscoveryCategory(discoveryType), discoveryName)
	end
	return false
end

function EncyclopediaController:GetDiscoveryCount(discoveryType)
	if self.DiscoveryManager then
		return self.DiscoveryManager:GetDiscoveryCount(toDiscoveryCategory(discoveryType))
	end
	return 0
end

function EncyclopediaController:GetFishData()
	return self.Data.Fish or {}
end

function EncyclopediaController:FindFishByBrokenName(query)
	local function splitWords(str)
		local words = {}
		for word in str:gmatch("%S+") do
			table.insert(words, word:lower())
		end
		return words
	end

	local queryWords = splitWords(query)
	local bestMatch, bestScore = nil, 0

	for id, fish in pairs(self.Data.Fish) do
		local idWords = splitWords(id)
		local nameWords = splitWords(fish.Name or "")
		local score = 0
		for _, qWord in ipairs(queryWords) do
			for _, idWord in ipairs(idWords) do
				if qWord == idWord then score = score + 1 break end
			end
			for _, nameWord in ipairs(nameWords) do
				if qWord == nameWord then score = score + 1 break end
			end
		end

		if score > bestScore then
			bestScore = score
			bestMatch = fish
		end
	end

	if bestScore > 0 then
		return bestMatch
	end
	return nil
end

function EncyclopediaController:SelectFishAndCategory(fish)
	if not fish or not fish._id then return false end

	local foundCategory = nil
	if self.Data and self.Data.DiscoveryTypes then
		for _, discoveryType in ipairs(self.Data.DiscoveryTypes) do
			local categoryTable = self.Data[discoveryType]
			if categoryTable and categoryTable[fish._id] then
				foundCategory = discoveryType
				break
			end
		end
	end

	if foundCategory then
		self:SetCategory(foundCategory)
	end

	self:SetSelection(fish._id)
	return true
end

function EncyclopediaController:SelectFishById(fishId)
	if not fishId or not self.Data then
		return false
	end

	local fishTable = self.Data.Fish or {}
	local fish = fishTable[fishId]
	if not fish then
		return false
	end

	return self:SelectFishAndCategory(fish)
end

function EncyclopediaController:SelectFishByName(fishName)
	if not fishName then return false end

	local fish = self:FindFishByBrokenName(fishName)
	if fish then
		return self:SelectFishAndCategory(fish)
	end

	return false
end

function EncyclopediaController:GetMemoryStatus()
	return {
		currentCategory = self.currentCategory,
		currentSelection = self.currentSelection,
		componentStatus = (UI and UI.Encyclopedia and UI.Encyclopedia.GetMemoryStatus and UI.Encyclopedia.GetMemoryStatus()) or nil,
		isVisible = self:IsVisible()
	}
end

function EncyclopediaController:GetDiscoveryTypes()
	return self.Data.DiscoveryTypes or {}
end

function EncyclopediaController:GetCategoryData(categoryName)
	return self.Data[toDiscoveryCategory(categoryName)] or {}
end

function EncyclopediaController:UpdateDiscoveryCache()
	local currentCategory = self:GetCurrentCategory() or "Vertebrates"
	local discoveryType = toDiscoveryCategory(currentCategory)
	self.DiscoveryManager:RequestDiscoveries(discoveryType)
	self.DiscoveredFishLookup = self.DiscoveryManager.Discoveries[discoveryType] or {}
end

function EncyclopediaController:Cleanup()
	self:Hide()
	self:stopAnimation()

	if self.ScannerConnection then
		self.ScannerConnection:Disconnect()
		self.ScannerConnection = nil
	end

	self.PendingScannerPayload = nil
	self.PendingHighlightFishId = nil
end

function EncyclopediaController:ApplyLastScannedSelection()
	if not Player then
		return false
	end

	local lastFishId = Player:GetAttribute("LastScannedFishId")
	if not lastFishId then
		return false
	end

	local applied = self:SelectFishById(lastFishId)
	if not applied then
		return false
	end

	local discoveryType = Player:GetAttribute("LastScannedDiscoveryType")
	if discoveryType then
		self:SetCategory(toUICategoryName(discoveryType))
	end

	if self.PendingHighlightFishId == lastFishId then
		highlightEncyclopediaEntry(lastFishId)
		self.PendingHighlightFishId = nil
	end

	if self.PendingScannerPayload and self.PendingScannerPayload.fishId == lastFishId then
		self.PendingScannerPayload = nil
	end

	return true
end

function EncyclopediaController:createAnimation()
	if not self.Animation then
		self.Animation = Instance.new("Animation")
		self.Animation.AnimationId = self.ANIMATION_ID
	end
end

function EncyclopediaController:playAnimation(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and self.Animation then
		if self.AnimationTrack then
			self.AnimationTrack:Stop()
			self.AnimationTrack:Destroy()
			self.AnimationTrack = nil
		end
		self.AnimationTrack = humanoid:LoadAnimation(self.Animation)
		self.AnimationTrack.Priority = Enum.AnimationPriority.Action
		self.AnimationTrack.Looped = true
		self.AnimationTrack:Play()
	end
end

function EncyclopediaController:stopAnimation()
	if self.AnimationTrack then
		self.AnimationTrack:Stop()
		self.AnimationTrack:Destroy()
		self.AnimationTrack = nil
	end
end

return EncyclopediaController