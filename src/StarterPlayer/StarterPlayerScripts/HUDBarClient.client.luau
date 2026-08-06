-- HUDBarClient: wires the bottom button bar (BottomHUD).
-- Be Seeker (toggles next-round role), Shop/Crates/Settings (placeholder popups),
-- Spectate (toggles spectate view).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local InRound = Remotes:WaitForChild("InRound")
local UISounds = require(ReplicatedStorage:WaitForChild("UISounds"))

-- New consolidated HUD. The left-side launcher buttons now live in Hud.LeftButtons:
--   MainButtons: StoreButton / InventoryButton / CratesButton / SettingsButton
--   SubButtons:  SeekerButton ("Be Seeker") / SpectateButton
-- (Previously these were in a separate FullGameGUI, now removed.)
local gui = player:WaitForChild("PlayerGui"):WaitForChild("Hud")
local leftButtons = gui:WaitForChild("LeftButtons")
local mainButtons = leftButtons:WaitForChild("MainButtons")
local subButtons = leftButtons:WaitForChild("SubButtons")

local inventoryBtn = mainButtons:WaitForChild("InventoryButton")
local shopBtn = mainButtons:WaitForChild("StoreButton")
local cratesBtn = mainButtons:WaitForChild("CratesButton")
local coloringBtn = mainButtons:WaitForChild("ColoringBookButton")
local beSeekerLong = subButtons:WaitForChild("SeekerButton")
local spectateBtn = subButtons:WaitForChild("SpectateButton")
local questsTab = gui:FindFirstChild("Quests")

-- ===== Reusable popup (in its own ScreenGui BELOW the HUD, so the HUD stays
-- on top and clickable while a popup is open — same behavior as settings) =====
local popupGui = player.PlayerGui:FindFirstChild("PopupGui")
if not popupGui then
	popupGui = Instance.new("ScreenGui")
	popupGui.Name = "PopupGui"
	popupGui.ResetOnSpawn = false
	popupGui.IgnoreGuiInset = true
	popupGui.DisplayOrder = 65   -- below the HUD (100), above results (60)
	popupGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	popupGui.Parent = player.PlayerGui
end

local popup = Instance.new("Frame")
popup.Name = "Popup"
popup.Size = UDim2.new(1,0,1,0)
popup.BackgroundColor3 = Color3.fromRGB(0,0,0)
popup.BackgroundTransparency = 0.5
popup.BorderSizePixel = 0
popup.Active = false   -- don't sink clicks meant for the HUD above
popup.Visible = false
popup.Parent = popupGui

local card = Instance.new("Frame")
card.AnchorPoint = Vector2.new(0.5,0.5)
card.Position = UDim2.new(0.5,0,0.5,0)
card.Size = UDim2.new(0,420,0,280)
card.BackgroundColor3 = Color3.fromRGB(30,30,40)
card.BorderSizePixel = 0
card.ZIndex = 51
card.Parent = popup
Instance.new("UICorner", card).CornerRadius = UDim.new(0,16)

local popTitle = Instance.new("TextLabel")
popTitle.Size = UDim2.new(1,-40,0,50); popTitle.Position = UDim2.new(0,20,0,16)
popTitle.BackgroundTransparency = 1; popTitle.Font = Enum.Font.FredokaOne; popTitle.TextSize = 28
popTitle.TextColor3 = Color3.fromRGB(245,245,245); popTitle.TextXAlignment = Enum.TextXAlignment.Left
popTitle.Text = ""; popTitle.ZIndex = 52; popTitle.Parent = card

local popBody = Instance.new("TextLabel")
popBody.Size = UDim2.new(1,-40,1,-110); popBody.Position = UDim2.new(0,20,0,70)
popBody.BackgroundTransparency = 1; popBody.Font = Enum.Font.FredokaOne; popBody.TextSize = 18
popBody.TextWrapped = true; popBody.TextColor3 = Color3.fromRGB(180,180,195)
popBody.TextYAlignment = Enum.TextYAlignment.Top; popBody.Text = ""; popBody.ZIndex = 52; popBody.Parent = card

local popClose = Instance.new("TextButton")
popClose.AnchorPoint = Vector2.new(1,0); popClose.Position = UDim2.new(1,-16,0,16)
popClose.Size = UDim2.new(0,36,0,36); popClose.BackgroundColor3 = Color3.fromRGB(200,60,60)
popClose.Font = Enum.Font.FredokaOne; popClose.TextSize = 22; popClose.TextColor3 = Color3.fromRGB(255,255,255)
popClose.Text = "X"; popClose.ZIndex = 52; popClose.Parent = card
Instance.new("UICorner", popClose).CornerRadius = UDim.new(0,10)

local function openPopup(t, b) popTitle.Text = t; popBody.Text = b; popup.Visible = true end
local function closePopup() UISounds.close(); popup.Visible = false end
popClose.MouseButton1Click:Connect(closePopup)

-- click + hover sounds on all HUD buttons
for _, b in ipairs({inventoryBtn, beSeekerLong, shopBtn, cratesBtn, coloringBtn, spectateBtn}) do
	UISounds.bindButton(b)
end

-- ===== Store button background spin =====
-- Match the RightGamepasses tiles: continuously rotate the Store button's Sunray background a full
-- 360° on a slow linear loop (one revolution every 12s, one direction). It's square + center-anchored
-- so it spins cleanly in place. Guarded so it only starts once.
local SUNRAY_SPIN_TIME = 12  -- seconds per full revolution (matches the RightGamepasses sunburst)
local sunray = shopBtn:FindFirstChild("Sunray")
if sunray and sunray:IsA("ImageLabel") and not sunray:GetAttribute("HudSpin") then
	sunray:SetAttribute("HudSpin", true)
	sunray.Rotation = 0
	TweenService:Create(
		sunray,
		TweenInfo.new(SUNRAY_SPIN_TIME, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, false),
		{ Rotation = 360 }
	):Play()
end

-- ===== Universal panel management =====
-- Closes ANY open full-screen panel (settings, shop/crates popup, results) so that
-- clicking any HUD button smoothly switches context instead of stacking UIs.
local function settingsBits()
	local pg = player:FindFirstChild("PlayerGui")
	local sGui = pg and pg:FindFirstChild("Settings")
	if not sGui then return nil end
	-- the new Settings shows/hides via the ScreenGui's .Enabled (no "Dim" frame)
	return sGui, sGui:FindFirstChild("OpenSettings"), sGui:FindFirstChild("CloseSettings")
end

local function closeAllPanels()
	-- close settings
	local _, _, closeEvt = settingsBits()
	if closeEvt then closeEvt:Fire() end
	-- close the crates popup
	if popup then popup.Visible = false end
	-- close the shop (new consolidated Shop UI)
	local pg = player:FindFirstChild("PlayerGui")
	local shopGui = pg and pg:FindFirstChild("Shop")
	local shopClose = shopGui and shopGui:FindFirstChild("CloseShop")
	if shopClose then shopClose:Fire() end
	-- close the crate shop (CratesShop)
	local crateGui = pg and pg:FindFirstChild("CratesShop")
	local crateClose = crateGui and crateGui:FindFirstChild("CloseCrateShop")
	if crateClose then crateClose:Fire() end
	-- close the seeker queue shop
	local sqGui = pg and pg:FindFirstChild("SeekerQueueGui")
	local sqClose = sqGui and sqGui:FindFirstChild("CloseSeekerQueue")
	if sqClose then sqClose:Fire() end
	-- close the inventory
	local invGui = pg and pg:FindFirstChild("Inventory")
	if invGui then invGui.Enabled = false end
	-- close the coloring book
	local coloringGui = pg and pg:FindFirstChild("ColoringBook")
	if coloringGui then coloringGui.Enabled = false end
	-- close the results screen if open (new Results GUI toggles via .Enabled)
	local results = pg and pg:FindFirstChild("Results")
	if results then results.Enabled = false end
	-- close the StarterPack offer if open
	local starterPack = pg and pg:FindFirstChild("StarterPack")
	local starterPackClose = starterPack and starterPack:FindFirstChild("CloseStarterPack")
	if starterPackClose then
		starterPackClose:Fire()
	elseif starterPack then
		starterPack.Enabled = false
	end
end

-- ===== Be Seeker (long button, leftmost): opens the Seeker Queue shop =====
beSeekerLong.MouseButton1Click:Connect(function()
	local pg = player:FindFirstChild("PlayerGui")
	local sqGui = pg and pg:FindFirstChild("SeekerQueueGui")
	local openSQ = sqGui and sqGui:FindFirstChild("OpenSeekerQueue")
	-- the new SeekerQueue UI shows/hides via the ScreenGui's .Enabled (no "Dim" frame)
	local wasOpen = sqGui and sqGui.Enabled
	closeAllPanels()
	if not wasOpen and openSQ then openSQ:Fire() end  -- toggle
end)

-- ===== InventoryBT (square button): opens the Inventory =====
inventoryBtn.MouseButton1Click:Connect(function()
	local pg = player:FindFirstChild("PlayerGui")
	local invGui = pg and pg:FindFirstChild("Inventory")
	local wasOpen = invGui and invGui.Enabled
	closeAllPanels()
	if invGui and not wasOpen then invGui.Enabled = true end  -- toggle open
end)

-- ===== Store button: opens the consolidated Shop UI =====
shopBtn.MouseButton1Click:Connect(function()
	local pg = player:FindFirstChild("PlayerGui")
	local shopGui = pg and pg:FindFirstChild("Shop")
	local openShop = shopGui and shopGui:FindFirstChild("OpenShop")
	-- the new Shop shows/hides via the ScreenGui's .Enabled (no "Dim" frame)
	local wasOpen = shopGui and shopGui.Enabled
	closeAllPanels()
	if not wasOpen and openShop then openShop:Fire() end  -- toggle
end)
cratesBtn.MouseButton1Click:Connect(function()
	local pg = player:FindFirstChild("PlayerGui")
	local crateGui = pg and pg:FindFirstChild("CratesShop")
	local openCrate = crateGui and crateGui:FindFirstChild("OpenCrateShop")
	local wasOpen = crateGui and crateGui.Enabled
	closeAllPanels()
	if not wasOpen and openCrate then openCrate:Fire() end  -- toggle
end)
-- ===== Coloring Book button: opens the ColoringBook UI (toggles via .Enabled) =====
coloringBtn.MouseButton1Click:Connect(function()
	local pg = player:FindFirstChild("PlayerGui")
	local cbGui = pg and pg:FindFirstChild("ColoringBook")
	local wasOpen = cbGui and cbGui.Enabled
	closeAllPanels()
	if cbGui and not wasOpen then cbGui.Enabled = true end  -- toggle
end)

-- ===== Spectate (only available in the lobby; hidden during a round so players
-- can't use it to scout hider/seeker locations) =====
spectateBtn.MouseButton1Click:Connect(function()
	closeAllPanels()
	local pg = player:FindFirstChild("PlayerGui")
	local specGui = pg and pg:FindFirstChild("SpectateGui")
	local toggle = specGui and specGui:FindFirstChild("ToggleSpectate")
	if toggle then toggle:Fire() end
end)

-- Spectate and the Quests tab stay hidden during the active round (Spectate could otherwise be used
-- to scout hider/seeker locations). The launcher buttons (Store/Inventory/Crates/Coloring) now stay
-- available DURING the round too, so the first-knife-unbox tutorial (which points at the Inventory
-- button) can run mid-round.
InRound.OnClientEvent:Connect(function(inRound)
	spectateBtn.Visible = not inRound

	-- Be Seeker stays visible during a round (it queues the player for a FUTURE round, so it's
	-- still meaningful while one is in progress).
	if inRound then
		-- Don't tear down open panels mid-tutorial: the knife tutorial opens the Inventory during a
		-- round, so a blanket close here would abort it. Skip the cleanup while a tutorial is on screen.
		if player:GetAttribute("TutorialActive") ~= true then
			closeAllPanels()
		end
		-- stop spectating when a round starts for this player (dedicated STOP, never a toggle)
		local pg = player:FindFirstChild("PlayerGui")
		local specGui = pg and pg:FindFirstChild("SpectateGui")
		local stopEvt = specGui and specGui:FindFirstChild("StopSpectate")
		if stopEvt then stopEvt:Fire() end
	end
end)

-- Quests tab: hidden whenever the player is in an active match (any game mode), tracked by the
-- server-set "InMatch" attribute. Decoupled from the Spectate/Free Cam button so a frozen Reverse
-- Race target (InRound=false, so they keep Free Cam) doesn't get the quests tab back mid-round.
local function updateQuestsVisibility()
	if questsTab then
		questsTab.Visible = player:GetAttribute("InMatch") ~= true
	end
end
player:GetAttributeChangedSignal("InMatch"):Connect(updateQuestsVisibility)
updateQuestsVisibility()

print("[HUDBarClient] ready (Hud)")
