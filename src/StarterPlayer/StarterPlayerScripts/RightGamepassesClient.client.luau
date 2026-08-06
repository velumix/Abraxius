-- RightGamepassesClient: previously wired two HUD gamepass tiles (2xSeeker, 2xCoins) in the
-- RightGamepasses ScreenGui. Those tiles have been REMOVED, so the panel is now empty and there is
-- nothing to wire. The wiring helpers below are kept (currently unused) so the tiles can be re-added
-- later by restoring the wireTile calls in bindGui; the bind hook itself is now a no-op.
--
-- RESILIENCE: the ScreenGui is set ResetOnSpawn=false so it persists across respawns. But if it is
-- ever re-cloned (ResetOnSpawn flipped back, or other code replacing it), the old button refs would
-- be dead and the new tiles would be unwired (clicks dead) AND owned tiles would show again (the
-- ownership check never re-ran). So we bind through a function that re-runs on every fresh copy,
-- re-resolving the tiles, re-checking ownership, and re-wiring clicks.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Constants = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Constants"))

-- gamepass IDs: single source of truth in Config.Constants.Gamepasses
local SEEKER_GAMEPASS_ID = Constants.Gamepasses.SEEKER
local DOUBLE_COINS_GAMEPASS_ID = Constants.Gamepasses.DOUBLE_COINS

local ROBUX_GLYPH = utf8.char(0xE002)  -- Roblox's built-in Robux glyph (matches ShopClient)

-- Set the price text on a tile's layered RobuxPrice label. The authored label is a Frame named
-- "RobuxPrice" holding TWO TextLabels (a back + front drop-shadow pair, both shipped reading
-- "R$49"); we update BOTH so the layered look stays intact. The "R$49" in the GUI is only a
-- placeholder -- the real price is fetched live (see wireTile) and written here.
local function setPriceText(tile, text)
	local info = tile:FindFirstChild("Info")
	local robuxPrice = info and info:FindFirstChild("RobuxPrice")
	if not robuxPrice then return end
	for _, lbl in ipairs(robuxPrice:GetChildren()) do
		if lbl:IsA("TextLabel") then lbl.Text = text end
	end
end

-- optional shared helpers (reused from the shop); fall back gracefully if absent
local UISounds
pcall(function()
	UISounds = require(ReplicatedStorage:WaitForChild("UISounds", 5))
end)
local PurchaseFX
pcall(function()
	PurchaseFX = require(player:WaitForChild("PlayerScripts"):WaitForChild("PurchaseFX", 5))
end)

local pg = player:WaitForChild("PlayerGui")

-- ===== tween settings =====
local HOVER_SCALE = 1.06   -- grow a touch on hover
local PRESS_SCALE = 0.93   -- dip on press
local TWEEN_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Tween the tile's UIScale (created at runtime if missing) so we don't fight the UIListLayout
-- that positions the tiles.
local function getScale(frame)
	local s = frame:FindFirstChildOfClass("UIScale")
	if not s then
		s = Instance.new("UIScale")
		s.Scale = 1
		s.Parent = frame
	end
	return s
end

local function tweenTo(frame, scale)
	TweenService:Create(getScale(frame), TWEEN_INFO, { Scale = scale }):Play()
end

-- ===== title animation: gentle left-right text bob + a continuously rotating shine =====
-- The title is the "OP DEAL" TextLabel inside Info.TitleText ("2x Seeker!" / "2x Coins!"). It has a
-- baseline Rotation (a slight built-in tilt) and a UIGradient "shine". We:
--   * BOB: oscillate the label's Rotation a few degrees either side of its ORIGINAL rotation (so it
--     sways around its designed tilt, not around 0 — starting from 0 would snap it straight first).
--   * SHINE 360: spin the UIGradient's Rotation through a full circle on a loop, so the sheen sweeps
--     all the way around continuously instead of sitting at a fixed angle.
-- Guarded by a "RGTitleAnim" attribute so a re-bind (respawn re-clone) doesn't stack tweens; a fresh
-- label instance has no attribute, so it animates; the same instance never double-animates.
local BOB_DEGREES = 4      -- how far the text sways to each side of its base rotation
local BOB_TIME = 1.1       -- seconds for one side of the sway
local SHINE_TIME = 2.5     -- seconds for the shine to complete a full 360° sweep
local SUNBURST_TIME = 12   -- seconds for the background sunburst to complete one full revolution
local function animateTitle(tile)
	-- BACKGROUND: slowly spin the radial sunburst behind the tile a full 360°, forever. It's square and
	-- center-anchored, so it rotates cleanly in place. Guarded by its own attribute so a re-bind
	-- (respawn re-clone) doesn't stack tweens on the same instance.
	local sunburst = tile:FindFirstChild("sunburst67")
	if sunburst and sunburst:IsA("ImageLabel") and not sunburst:GetAttribute("RGSpin") then
		sunburst:SetAttribute("RGSpin", true)
		sunburst.Rotation = 0
		TweenService:Create(
			sunburst,
			TweenInfo.new(SUNBURST_TIME, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, false),
			{ Rotation = 360 }
		):Play()
	end

	local info = tile:FindFirstChild("Info")
	local titleHolder = info and info:FindFirstChild("TitleText")
	local label = titleHolder and titleHolder:FindFirstChild("OP DEAL")
	if not label or not label:IsA("TextLabel") then return end
	if label:GetAttribute("RGTitleAnim") then return end  -- already animating this instance
	label:SetAttribute("RGTitleAnim", true)

	-- BOB: tween rotation to base+BOB, reversing (auto-reverse) and repeating forever. RepeatCount -1
	-- with Reverses=true gives a smooth back-and-forth around the start; we offset start to base-BOB so
	-- it sways symmetrically around the original tilt.
	local baseRot = label.Rotation
	label.Rotation = baseRot - BOB_DEGREES
	TweenService:Create(
		label,
		TweenInfo.new(BOB_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Rotation = baseRot + BOB_DEGREES }
	):Play()

	-- SHINE 360: a UIGradient.Rotation only spans 0..360 and wraps, so a single tween 0->360 with a
	-- Linear style and RepeatCount -1 (NO reverse) sweeps the sheen around endlessly in one direction.
	local grad = label:FindFirstChildOfClass("UIGradient")
	if grad then
		grad.Rotation = 0
		TweenService:Create(
			grad,
			TweenInfo.new(SHINE_TIME, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, false),
			{ Rotation = 360 }
		):Play()
	end
end

-- ===== wire one tile (within a given root) =====
local function wireTile(root, tileName, gamepassId)
	local tile = root:FindFirstChild(tileName)
	if not tile then
		warn("[RightGamepassesClient] tile not found: " .. tileName)
		return
	end
	-- the button shares the tile's name
	local btn = tile:FindFirstChild(tileName)
	if not btn or not btn:IsA("GuiButton") then
		warn("[RightGamepassesClient] button not found in tile: " .. tileName)
		return
	end

	-- ownership: hide the tile once the player owns the pass. This runs EVERY bind (including on a
	-- re-cloned GUI after respawn), so an owned tile is correctly hidden on the fresh copy too.
	local owns = false
	local function applyOwned()
		if owns then tile.Visible = false else tile.Visible = true end
	end
	local function refreshOwned()
		local ok, result = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamepassId)
		end)
		if ok then owns = result end
		applyOwned()
	end
	refreshOwned()

	-- Fetch the REAL Robux price and write it onto the layered RobuxPrice label, replacing the
	-- authored "R$49" placeholder. GetProductInfo yields, so do it off the main thread; if it fails
	-- (web error), the authored placeholder simply stays. Skipped when owned (the tile is hidden).
	task.spawn(function()
		if owns then return end
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(gamepassId, Enum.InfoType.GamePass)
		end)
		if ok and info and info.PriceInRobux and not owns then
			setPriceText(tile, ROBUX_GLYPH .. " " .. info.PriceInRobux)
		end
	end)

	-- start the title bob + rotating shine (guarded internally so a re-bind won't stack tweens)
	animateTitle(tile)

	-- guard: only attach the click/tween/finished handlers ONCE per button instance (a re-cloned GUI
	-- gets a fresh button, so it binds again; the same button never double-binds).
	if btn:GetAttribute("RGBound") then return end
	btn:SetAttribute("RGBound", true)

	btn.Active = true            -- allow controller selection too
	btn.AutoButtonColor = false  -- we handle feedback via the tween
	getScale(tile)               -- ensure a UIScale exists up front

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(plr, passId, wasPurchased)
		if plr == player and passId == gamepassId and wasPurchased then
			owns = true
			applyOwned()
		end
	end)

	-- ===== tween feedback =====
	btn.MouseEnter:Connect(function()
		if UISounds then pcall(function() UISounds.play("hover") end) end
		tweenTo(tile, HOVER_SCALE)
	end)
	btn.MouseLeave:Connect(function()
		tweenTo(tile, 1)
	end)
	btn.MouseButton1Down:Connect(function()
		tweenTo(tile, PRESS_SCALE)
	end)
	btn.MouseButton1Up:Connect(function()
		tweenTo(tile, HOVER_SCALE)
	end)

	-- ===== purchase =====
	btn.MouseButton1Click:Connect(function()
		if UISounds then pcall(function() UISounds.click() end) end
		-- quick bounce on tap so touch users get feedback too
		tweenTo(tile, PRESS_SCALE)
		task.delay(0.1, function() tweenTo(tile, 1) end)

		if owns then return end  -- already owned: nothing to prompt
		if PurchaseFX then pcall(function() PurchaseFX.prompt() end) end
		MarketplaceService:PromptGamePassPurchase(player, gamepassId)
	end)
end

-- Resolve the tiles container in a RightGamepasses ScreenGui and wire its tiles.
-- NOTE: the 2x Seeker and 2x Coins tiles were removed from this panel, so there is nothing to wire
-- here anymore. The bind hook is kept (a no-op) in case tiles are re-added later.
local function bindGui(gui)
	if not gui then return end
	local hud = gui:FindFirstChild("HUDFrame")
	local root = hud and hud:FindFirstChild("RightGamepasses")
	if not root then return end
	-- (no tiles to wire: 2xSeeker / 2xCoins were removed)
end

-- bind the current copy, and re-bind any future copy added to PlayerGui (e.g. a respawn re-clone)
local existing = pg:FindFirstChild("RightGamepasses")
if existing then bindGui(existing) end
pg.ChildAdded:Connect(function(child)
	if child.Name == "RightGamepasses" and child:IsA("ScreenGui") then
		task.defer(bindGui, child)  -- defer so its descendants exist before we resolve them
	end
end)
