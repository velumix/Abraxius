-- RightGamepassesHiderClient: wires the two HIDER-only HUD dev-product tiles (Become Tiny / Become
-- Giant) in the ChangeSizeHider ScreenGui, and manages when it (and the regular RightGamepasses panel)
-- is visible.
--
-- GUI structure (ChangeSizeHider ScreenGui -> ChangeSizeHider Frame): two ImageButton tiles, BOTH named
-- "RevealOneButton" (template leftover), told apart by their Title text ("Become Tiny!" / "Become
-- Giant!"). Each tile is itself the clickable button and holds: Title (+ Top drop-shadow), a layered
-- Robux price label pair, an Icon, and a sunburst67 shine. Clicking prompts the matching DEV PRODUCT.
-- The actual resize is applied SERVER-SIDE in MatchManager.ProcessReceipt, which validates the buyer is
-- an active hider in the seek phase and hasn't already bought that size THIS round -- so we only prompt.
--
-- ANIMATION (matches the shop's RightGamepassesClient): each tile hover/press-tweens its UIScale, its
-- sunburst67 spins a continuous 360 degrees, and the title's shine UIGradient sweeps 360 continuously.
--
-- VISIBILITY:
--   * ChangeSizeHider shows for an active HIDER during the HIDE phase AND the ROUND (seek) phase, so a
--     hider can resize early (while hiding) or mid-seek. Hidden otherwise.
--   * RightGamepasses (the seeker/coins gamepass panel) is HIDDEN whenever this hider panel is showing,
--     because it overlaps; it's restored otherwise.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local RoleAnnounce = Remotes:WaitForChild("RoleAnnounce")
local InRound = Remotes:WaitForChild("InRound")
local StateChanged = Remotes:WaitForChild("StateChanged")

-- dev product ids for the two sizes (server maps these in SIZE_PRODUCTS)
local TINY_PRODUCT = 3605258594
local GIANT_PRODUCT = 3605258716

local ROBUX_GLYPH = utf8.char(0xE002)  -- Roblox's built-in Robux glyph (matches the other panels)

-- optional shared helpers (reused from the rest of the UI); guarded so a missing one never errors
local UISounds
pcall(function() UISounds = require(ReplicatedStorage:WaitForChild("UISounds", 5)) end)
local PurchaseFX
pcall(function() PurchaseFX = require(player:WaitForChild("PlayerScripts"):WaitForChild("PurchaseFX", 5)) end)

-- ===== eligibility state =====
-- Unlike the Trolls UI (ROUND-only), the size panel is usable during BOTH playable phases: HIDE (the
-- hiders are placed and hiding) and ROUND (the seek phase). So we track the raw state string and treat
-- either HIDE or ROUND as "playable". The server's ProcessReceipt enforces the same HIDE-or-ROUND rule.
local isHider = false
local inRound = false
local playablePhase = false   -- true while state == "HIDE" or "ROUND"
local function eligible()
	return isHider and inRound and playablePhase
end

-- ===== tween feedback (matches RightGamepassesClient) =====
local HOVER_SCALE = 1.06
local PRESS_SCALE = 0.93
local TWEEN_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local function getScale(frame)
	local s = frame:FindFirstChildOfClass("UIScale")
	if not s then s = Instance.new("UIScale"); s.Scale = 1; s.Parent = frame end
	return s
end
local function tweenTo(frame, scale)
	TweenService:Create(getScale(frame), TWEEN_INFO, { Scale = scale }):Play()
end

-- write the live Robux price onto the tile's "Robux" labels (replacing the authored "29"). There are
-- TWO layered Robux labels per tile -- a front label and a nested drop-shadow duplicate INSIDE it -- so
-- we recurse over all descendants and set every one. We also enable RichText on each: the Roblox Robux
-- glyph (utf8 0xE002) only renders when RichText is on (it was off here, which is why the icon showed as
-- a blank space and the price stayed "29").
local function setPriceText(tile, text)
	for _, lbl in ipairs(tile:GetDescendants()) do
		if lbl:IsA("TextLabel") and lbl.Name == "Robux" then
			lbl.RichText = true
			lbl.Text = text
		end
	end
end

-- ===== title animation (gentle bob + spinning sunburst), like RightGamepassesClient =====
-- The title's shine UIGradient is left STATIC (no spin) per design; only the sunburst67 spins and the
-- title gently bobs. (The shop spins its title gradient, but here we keep it fixed.)
local BOB_DEGREES, BOB_TIME, SUNBURST_TIME = 4, 1.1, 12
local function animateTitle(tile)
	-- spin the sunburst shine forever (guarded so a re-bind doesn't stack tweens on the same instance)
	local sunburst = tile:FindFirstChild("sunburst67")
	if sunburst and sunburst:IsA("ImageLabel") and not sunburst:GetAttribute("RGSpin") then
		sunburst:SetAttribute("RGSpin", true)
		sunburst.Rotation = 0
		TweenService:Create(sunburst, TweenInfo.new(SUNBURST_TIME, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, false), { Rotation = 360 }):Play()
	end
	-- the title headline + its Top drop-shadow. We bob it gently but DO NOT animate the shine gradient
	-- (it stays at its authored static rotation).
	local label = tile:FindFirstChild("Title")
	if not label or not label:IsA("TextLabel") then return end
	if not label:GetAttribute("RGTitleAnim") then
		label:SetAttribute("RGTitleAnim", true)
		local baseRot = label.Rotation
		label.Rotation = baseRot - BOB_DEGREES
		TweenService:Create(label, TweenInfo.new(BOB_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Rotation = baseRot + BOB_DEGREES }):Play()
	end
end

-- ===== wire one tile =====
-- Here the tile IS the ImageButton (it directly holds Title/Robux/Icon/sunburst67), so the tile and the
-- button are the same instance.
local function wireTile(btn, productId)
	if not btn or not btn:IsA("GuiButton") then return end
	local tile = btn

	-- fetch the REAL dev-product Robux price and write it onto the layered RobuxPrice label (off-thread,
	-- since GetProductInfo yields; on failure the authored placeholder simply stays).
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
		end)
		if ok and info and info.PriceInRobux then
			setPriceText(tile, ROBUX_GLYPH .. " " .. info.PriceInRobux)
		end
	end)

	animateTitle(tile)

	-- bind click/tween handlers ONCE per button instance (guard against a re-cloned GUI re-binding)
	if btn:GetAttribute("RGHBound") then return end
	btn:SetAttribute("RGHBound", true)
	btn.Active = true
	btn.AutoButtonColor = false  -- feedback is the UIScale tween, not the default press tint
	getScale(tile)

	btn.MouseEnter:Connect(function()
		if UISounds then pcall(function() UISounds.play("hover") end) end
		tweenTo(tile, HOVER_SCALE)
	end)
	btn.MouseLeave:Connect(function() tweenTo(tile, 1) end)
	btn.MouseButton1Down:Connect(function() tweenTo(tile, PRESS_SCALE) end)
	btn.MouseButton1Up:Connect(function() tweenTo(tile, HOVER_SCALE) end)

	btn.MouseButton1Click:Connect(function()
		if UISounds then pcall(function() UISounds.click() end) end
		tweenTo(tile, PRESS_SCALE); task.delay(0.1, function() tweenTo(tile, 1) end)
		-- only prompt for an eligible hider-in-round (the server would refuse otherwise, this just avoids
		-- charging/prompting when it can't possibly apply).
		if not eligible() then return end
		if PurchaseFX then pcall(function() PurchaseFX.prompt() end) end
		MarketplaceService:PromptProductPurchase(player, productId)
	end)
end

-- ===== visibility control =====
-- Show the hider panel only for an eligible hider-in-round; hide the regular RightGamepasses panel
-- whenever the round is active (it overlaps this one).
local hiderGui  -- the ChangeSizeHider ScreenGui (resolved/bound below)

local function refreshVisibility()
	local show = eligible()
	if hiderGui and hiderGui.Parent then
		hiderGui.Enabled = show
	end
	-- hide the seeker/coins gamepass panel whenever the hider panel is up (they overlap); restore otherwise.
	local rg = pg:FindFirstChild("RightGamepasses")
	if rg and rg:IsA("ScreenGui") then
		rg.Enabled = not show
	end
end

-- ===== bind the ChangeSizeHider GUI (re-bind on a fresh copy after respawn) =====
-- The inner frame is also named "ChangeSizeHider". Both size tiles are ImageButtons named
-- "RevealOneButton"; we tell Tiny from Giant by their Title text and wire each to its dev product.
local function titleText(btn)
	local t = btn:FindFirstChild("Title")
	return (t and t:IsA("TextLabel") and t.Text) or ""
end
local function bindGui(gui)
	if not gui then return end
	hiderGui = gui
	local root = gui:FindFirstChild("ChangeSizeHider")  -- inner Frame
	if root then
		for _, btn in ipairs(root:GetChildren()) do
			if btn:IsA("GuiButton") then
				local title = string.lower(titleText(btn))
				if string.find(title, "tiny", 1, true) then
					wireTile(btn, TINY_PRODUCT)
				elseif string.find(title, "giant", 1, true) then
					wireTile(btn, GIANT_PRODUCT)
				end
			end
		end
	end
	refreshVisibility()
end

local existing = pg:FindFirstChild("ChangeSizeHider")
if existing then bindGui(existing) end
pg.ChildAdded:Connect(function(child)
	if child.Name == "ChangeSizeHider" and child:IsA("ScreenGui") then
		task.defer(bindGui, child)
	elseif child.Name == "RightGamepasses" and child:IsA("ScreenGui") then
		task.defer(refreshVisibility)  -- re-apply the round-time hide on a fresh RightGamepasses copy
	end
end)

-- ===== round/role tracking =====
RoleAnnounce.OnClientEvent:Connect(function(role)
	isHider = (role == "Hider")
	refreshVisibility()
end)
InRound.OnClientEvent:Connect(function(state)
	inRound = (state == true)
	if not inRound then isHider = false end
	refreshVisibility()
end)
StateChanged.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" or data.state == nil then return end
	playablePhase = (data.state == "HIDE" or data.state == "ROUND")
	refreshVisibility()
end)

refreshVisibility()
