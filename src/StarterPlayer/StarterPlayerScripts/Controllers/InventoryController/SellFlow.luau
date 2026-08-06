local SellFlow = {}
SellFlow.__index = SellFlow

local RARITY_RANK = {
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
	Legendary = 5,
	Secret = 6,
	Exclusive = 7,
}
local CONFIRM_MIN_RANK = RARITY_RANK.Epic
local UNSELLABLE_SKINS = { vip = true, galaxyseer = true, frozen = true, darkrose = true }
local GLOBAL_FONT =
	Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)

local function colorToHex(color)
	return string.format(
		"#%02X%02X%02X",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5)
	)
end

local function escapeRich(text)
	return text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&apos;")
end

local function readableOnDark(color)
	local luminance = 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
	if luminance >= 0.45 then
		return color
	end
	if luminance <= 0.001 then
		return Color3.fromRGB(210, 210, 215)
	end
	local scale = 0.45 / luminance
	return Color3.new(math.min(color.R * scale, 1), math.min(color.G * scale, 1), math.min(color.B * scale, 1))
end

function SellFlow.CanSell(item)
	return item ~= nil and item.isDefault ~= true and item.favorite ~= true and not UNSELLABLE_SKINS[item.skinId]
end

function SellFlow.new(options)
	local fxGui = Instance.new("ScreenGui")
	fxGui.Name = "SellFX"
	fxGui.ResetOnSpawn = false
	fxGui.IgnoreGuiInset = false
	fxGui.DisplayOrder = 200
	fxGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	fxGui.Parent = options.playerGui

	local self = setmetatable({
		player = options.player,
		confirmGui = options.confirmGui,
		confirmQuestion = options.confirmQuestion,
		inventoryAction = options.inventoryAction,
		knifeSkins = options.knifeSkins,
		sounds = options.sounds,
		tweenController = options.tweenController,
		userInput = options.userInput,
		onBeforeSell = options.onBeforeSell,
		fxGui = fxGui,
		pendingItem = nil,
	}, SellFlow)

	options.confirmAccept.MouseButton1Click:Connect(function()
		local item = self.pendingItem
		self:CloseConfirmation()
		if item then
			self:_perform(item)
		end
	end)
	options.confirmDecline.MouseButton1Click:Connect(function()
		self:CloseConfirmation()
	end)

	return self
end

function SellFlow:_setQuestion(item)
	local color = readableOnDark(self.knifeSkins.rarityColor(item.rarity))
	local name = self.knifeSkins.displayName(tostring(item.name))
	local coloredName = string.format('<font color="%s">%s</font>', colorToHex(color), escapeRich(name))
	local mutation = ""
	if item.effect and item.effect ~= "none" then
		mutation = string.format(
			' <font color="%s">[%s]</font>',
			colorToHex(self.knifeSkins.effectColor(item.effect)),
			escapeRich(self.knifeSkins.effectName(item.effect))
		)
	end
	local value = self.knifeSkins.sellValue(item.rarity)
	local price = string.format(' for <font color="%s">+%d</font>', colorToHex(Color3.fromRGB(255, 215, 90)), value)
	local text = "Are you sure you want to sell " .. coloredName .. mutation .. price .. "?"

	self.confirmQuestion.RichText = true
	self.confirmQuestion.Text = text
	local top = self.confirmQuestion:FindFirstChild("Top")
	if top and top:IsA("TextLabel") then
		top.RichText = true
		top.Text = text
	end
end

function SellFlow:_floatingText(text, color, duration)
	local mouse = self.userInput:GetMouseLocation()
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromOffset(320, 40)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromOffset(mouse.X, mouse.Y)
	label.BackgroundTransparency = 1
	label.Text = text
	label.FontFace = GLOBAL_FONT
	label.TextColor3 = color
	label.TextSize = 28
	label.ZIndex = 10
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 2
	stroke.Parent = label
	label.Parent = self.fxGui

	duration = duration or 0.9
	local tweenInfo = self.tweenController:GetInfo(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	self.tweenController:Play(label, tweenInfo, {
		Position = UDim2.fromOffset(mouse.X, mouse.Y - 70),
		TextTransparency = 1,
	}, "floating-text")
	self.tweenController:Play(stroke, tweenInfo, { Transparency = 1 }, "floating-text")
	task.delay(duration + 0.05, function()
		label:Destroy()
	end)
end

function SellFlow:Warn(text)
	self.sounds.error()
	self:_floatingText(text, Color3.fromRGB(235, 70, 70), 2.5)
end

function SellFlow:_perform(item)
	self.onBeforeSell(item.uid)
	self.inventoryAction:FireServer("sell", item.uid)
	self.sounds.play("PurchaseSound")
	local value = self.knifeSkins.sellValue(item.rarity)
	if value and value > 0 then
		self:_floatingText("+" .. value, Color3.fromRGB(255, 215, 90))
	end
end

function SellFlow:Prompt(item, equippedUid)
	if not SellFlow.CanSell(item) then
		self:Warn("You can't sell this!")
		return
	end
	if equippedUid == item.uid then
		return
	end

	local rank = RARITY_RANK[item.rarity] or 1
	if item.rarity == "Exclusive" or rank >= CONFIRM_MIN_RANK then
		self.pendingItem = item
		self:_setQuestion(item)
		self.confirmGui.Enabled = true
	else
		self:_perform(item)
	end
end

function SellFlow:BuyPose(item)
	if not item or item.owned then
		return
	end
	local price = item.price
	if type(price) ~= "number" or price <= 0 then
		self.sounds.error()
		return
	end
	local leaderstats = self.player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")
	if coins and coins.Value < price then
		self:Warn("Not enough coins!")
		return
	end

	self.inventoryAction:FireServer("buyPose", item.id)
	self.sounds.play("PurchaseSound")
	self:_floatingText("-" .. price, Color3.fromRGB(255, 215, 90))
end

function SellFlow:CloseConfirmation()
	self.confirmGui.Enabled = false
	self.pendingItem = nil
end

return SellFlow
