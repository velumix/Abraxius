local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local PurchaseFX = require(player:WaitForChild("PlayerScripts"):WaitForChild("PurchaseFX"))
local UI_ASSETS = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("UI")

local CASE_MODEL_NAME = "RobuxCase"
local PLAYER_GUI_PROMPT_NAME = "RobuxCasePurchaseOptions"

local function findCrate()
	local interactives = workspace:WaitForChild("LobbyInteractives")
	local crate = interactives:FindFirstChild(CASE_MODEL_NAME, true)
	local waited = 0
	while not crate and waited < 30 do
		task.wait(0.25)
		waited += 0.25
		crate = interactives:FindFirstChild(CASE_MODEL_NAME, true)
	end
	return crate
end

local function applyCrateLabels(crate)
	local crateName = crate:GetAttribute("CrateName")
	if type(crateName) ~= "string" or crateName == "" then
		return
	end
	local x1Text = "x1 " .. crateName
	local x3Text = "x3 " .. crateName .. "s"
	local x10Text = "x10 " .. crateName .. "s"

	local promptPart = crate:FindFirstChild("PromptPart", true)
	local p1Prompt = promptPart and promptPart:FindFirstChildWhichIsA("ProximityPrompt")
	if p1Prompt then p1Prompt.ObjectText = x1Text end
	local promptPart3 = crate:FindFirstChild("PromptPart3", true)
	local p3Prompt = promptPart3 and promptPart3:FindFirstChildWhichIsA("ProximityPrompt")
	if p3Prompt then p3Prompt.ObjectText = x3Text end
	local promptPart10 = crate:FindFirstChild("PromptPart10", true)
	local p10Prompt = promptPart10 and promptPart10:FindFirstChildWhichIsA("ProximityPrompt")
	if p10Prompt then p10Prompt.ObjectText = x10Text end

	local options = UI_ASSETS:FindFirstChild("RobuxCasePurchaseOptions")
	options = options and options:FindFirstChild("Options")
	if options then
		local top1 = options:FindFirstChild("Purchase1") and options.Purchase1:FindFirstChild("TopText")
		if top1 and top1:IsA("TextLabel") then top1.Text = x1Text end
		local top2 = options:FindFirstChild("Purchase2") and options.Purchase2:FindFirstChild("TopText")
		if top2 and top2:IsA("TextLabel") then top2.Text = x3Text end
		local top3 = options:FindFirstChild("Purchase3") and options.Purchase3:FindFirstChild("TopText")
		if top3 and top3:IsA("TextLabel") then top3.Text = x10Text end
	end
end

local function promptProduct(crate, attrName, sourceName)
	local productId = attrName and crate:GetAttribute(attrName)
	if type(productId) ~= "number" or productId <= 0 then
		warn(('[JurassicCratePromptClient] Missing dev product id for [RobuxCasePromptClient] ([RobuxCasePromptClient])'):format(tostring(sourceName), tostring(attrName)))
		return
	end
	PurchaseFX.prompt()
	MarketplaceService:PromptProductPurchase(player, productId)
end

local function bindPrompt(crate, prompt)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	prompt.Triggered:Connect(function(triggeringPlayer)
		if triggeringPlayer and triggeringPlayer ~= player then
			return
		end
		promptProduct(crate, prompt:GetAttribute("ProductAttribute"), prompt.Name)
	end)
end

local function connectRow(row, crate, attrName)
	if not row or not row:IsA("GuiObject") then
		return
	end

	row.Active = true
	local clickTarget = row:FindFirstChild("ClickTarget")
	if not clickTarget then
		clickTarget = Instance.new("TextButton")
		clickTarget.Name = "ClickTarget"
		clickTarget.AnchorPoint = Vector2.new(0.5, 0.5)
		clickTarget.Position = UDim2.fromScale(0.5, 0.5)
		clickTarget.Size = UDim2.fromScale(1, 1)
		clickTarget.BackgroundTransparency = 1
		clickTarget.BorderSizePixel = 0
		clickTarget.Text = ""
		clickTarget.AutoButtonColor = false
		clickTarget.Selectable = true
		clickTarget.ZIndex = row.ZIndex + 20
		clickTarget.Parent = row
	end

	clickTarget.Activated:Connect(function()
		promptProduct(crate, attrName, row.Name)
	end)
end

local function createClickablePromptBillboard(crate)
	local promptPart = crate:WaitForChild("PromptPart", 10)
	if not promptPart then
		warn("[JurassicCratePromptClient] PromptPart not found for clickable prompt billboard")
		return
	end

	local templateBillboard = UI_ASSETS:FindFirstChild("RobuxCasePurchaseOptions")
	if not templateBillboard or not templateBillboard:IsA("BillboardGui") then
		warn("[RobuxCasePromptClient] RobuxCasePurchaseOptions template not found in ReplicatedStorage.Assets.UI")
		return
	end

	local oldBillboard = playerGui:FindFirstChild(PLAYER_GUI_PROMPT_NAME)
	if oldBillboard then
		oldBillboard:Destroy()
	end

	local billboard = templateBillboard:Clone()
	billboard.Name = PLAYER_GUI_PROMPT_NAME
	billboard.Adornee = promptPart
	billboard.Enabled = true
	billboard.Active = true
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 22
	billboard.ResetOnSpawn = false
	billboard.Parent = playerGui

	local options = billboard:FindFirstChild("Options")
	if not options then
		warn("[JurassicCratePromptClient] PurchaseOptions.Options not found")
		return
	end

	connectRow(options:FindFirstChild("Purchase1"), crate, "ProductId1")
	connectRow(options:FindFirstChild("Purchase2"), crate, "ProductId3")
	connectRow(options:FindFirstChild("Purchase3"), crate, "ProductId10")
end

local crate = findCrate()
if not crate then
	warn("[RobuxCasePromptClient] RobuxCase not found")
	return
end

applyCrateLabels(crate)

local function bindPromptPart(partName)
	local promptPart = crate:WaitForChild(partName, 10)
	if not promptPart then
		warn(("[JurassicCratePromptClient] [RobuxCasePromptClient] not found"):format(partName))
		return
	end
	for _, child in ipairs(promptPart:GetChildren()) do
		bindPrompt(crate, child)
	end
	promptPart.ChildAdded:Connect(function(child)
		bindPrompt(crate, child)
	end)
end

bindPromptPart("PromptPart")
bindPromptPart("PromptPart3")
bindPromptPart("PromptPart10")
createClickablePromptBillboard(crate)
