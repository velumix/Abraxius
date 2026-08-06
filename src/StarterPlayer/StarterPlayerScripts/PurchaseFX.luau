-- PurchaseFX: client-side purchase visuals (rainbow spin-in + camera zoom on prompt,
-- confetti + "thank you" celebration on a successful purchase).
--
-- Ported from the Kawaii Kitty Tower MonetizationExtra script. In this game the purchase
-- prompts are fired client-side (each shop button calls MarketplaceService:Prompt...),
-- so there is no server->client bridge: just require this module and call
-- PurchaseFX.prompt() immediately BEFORE each Prompt... call.
--
--   local PurchaseFX = require(ReplicatedStorage... PurchaseFX)
--   PurchaseFX.prompt()
--   MarketplaceService:PromptProductPurchase(player, productId)
--
-- The finished-event handlers are wired ONCE (globally) on first require, so the
-- celebration fires for any purchase regardless of which button started it.

local PurchaseFX = {}

local SPIN_SPEED = 50    -- gradient rotation speed (deg/sec) for the rainbow swirl
local OPEN_TIMEOUT = 60   -- safety: clear the open effect if no finished event ever arrives

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local plr = Players.LocalPlayer

-- ===== UI refs =====
local pg = plr:WaitForChild("PlayerGui")
local screenGui = pg:WaitForChild("PurchaseFX")
local purchasingFrame = screenGui:WaitForChild("BuyTransition")
local rainbow = purchasingFrame:WaitForChild("Shadow")
local gradient = rainbow:FindFirstChildOfClass("UIGradient")
local icon = purchasingFrame:WaitForChild("Icon")
local label = purchasingFrame:WaitForChild("Loading")

local confetti = require(ReplicatedStorage:WaitForChild("Confetti"))

local cam = workspace.CurrentCamera
local fov = cam.FieldOfView

local c               -- RenderStepped spin connection
local openActive = false
local watchdogToken = 0

-- initial hidden state
icon.ImageTransparency = 1
label.TextTransparency = 1

-- remember the rainbow's authored opacity so we can fade back to it (not to fully opaque)
local shadowOpacity = rainbow.ImageTransparency
rainbow.ImageTransparency = 1

purchasingFrame.Visible = true

-- Clears the "prompt is open" visuals (camera zoom + rainbow + spin). Safe to call repeatedly.
local function clearOpenEffect()
	if not openActive then return end
	openActive = false
	TweenService:Create(cam, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
		FieldOfView = fov
	}):Play()
	TweenService:Create(rainbow, TweenInfo.new(0.2), {
		ImageTransparency = 1
	}):Play()
	if c then
		c:Disconnect()
		c = nil
	end
end

-- Plays the "thank you for purchasing" celebration (confetti + icon + label).
local function celebrate()
	local ok = pcall(function() confetti.Emit(2) end)
	if not ok then
		-- confetti needs a character; ignore if unavailable so the rest still plays
	end
	TweenService:Create(icon, TweenInfo.new(0.2), { ImageTransparency = 0 }):Play()
	TweenService:Create(label, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()
	TweenService:Create(purchasingFrame, TweenInfo.new(0.2), { BackgroundTransparency = 0.2 }):Play()
	TweenService:Create(icon, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 4, false, 0.5), {
		Rotation = icon.Rotation + 180
	}):Play()
	task.wait(3)
	TweenService:Create(icon, TweenInfo.new(0.5), { ImageTransparency = 1 }):Play()
	TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
	TweenService:Create(purchasingFrame, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
end

-- Call this right before any MarketplaceService:Prompt... call to play the open effect.
function PurchaseFX.prompt()
	openActive = true
	TweenService:Create(rainbow, TweenInfo.new(0.2), {
		ImageTransparency = shadowOpacity
	}):Play()
	TweenService:Create(cam, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
		FieldOfView = fov - 20
	}):Play()
	if c then c:Disconnect() end
	if gradient then
		c = RunService.RenderStepped:Connect(function(dt)
			gradient.Rotation += SPIN_SPEED * dt
			if gradient.Rotation >= 360 then
				gradient.Rotation = 0
			end
		end)
	end

	-- Safety watchdog: if no finished event fires (already owns the pass, or the prompt is
	-- dismissed without an event), clear the open effect automatically so it never sticks.
	watchdogToken = watchdogToken + 1
	local myToken = watchdogToken
	task.delay(OPEN_TIMEOUT, function()
		if myToken == watchdogToken and openActive then
			clearOpenEffect()
		end
	end)
end

-- ===== finished-event handlers (wired once) =====
-- Product IDs that should NOT trigger the confetti celebration (e.g. the Reveal Hiders products,
-- which have their own seeker-side banner). Other client scripts add to this set on load.
PurchaseFX.suppressProducts = {}

local function onFinished(plrid, id, purchased)
	if plrid ~= plr.UserId and plrid ~= plr then return end
	watchdogToken = watchdogToken + 1
	clearOpenEffect()
	if purchased then
		-- skip the confetti celebration for products that opt out (they show their own feedback)
		if PurchaseFX.suppressProducts[id] then return end
		task.spawn(celebrate)
	end
end

MarketplaceService.PromptProductPurchaseFinished:Connect(onFinished)
MarketplaceService.PromptPurchaseFinished:Connect(onFinished)
MarketplaceService.PromptGamePassPurchaseFinished:Connect(onFinished)
MarketplaceService.PromptBundlePurchaseFinished:Connect(onFinished)

return PurchaseFX
