local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local KnifeIcon = require(ReplicatedStorage:WaitForChild("KnifeIcon"))
local KnifeSkinManager = require(ReplicatedStorage:WaitForChild("KnifeSkinManager"))
local UI_ASSETS = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("UI")

local CRATE_NAME = "Sports Crate"
local GUI_NAME = "RobuxCaseOddsBillboard"
local CASE_MODEL_NAME = "RobuxCase"  -- the Sports Crate's physical lobby model (replaced the Jurassic Crate)

local function waitForCase()
	local interactives = workspace:WaitForChild("LobbyInteractives", 30)
	if not interactives then
		return nil
	end
	local case = interactives:FindFirstChild(CASE_MODEL_NAME, true)
	local waited = 0
	while not case and waited < 30 do
		task.wait(0.25)
		waited += 0.25
		case = interactives:FindFirstChild(CASE_MODEL_NAME, true)
	end
	return case
end

local function renderCardIcon(card)
	local icon = card:FindFirstChild("Icon")
	if not (icon and icon:IsA("ImageLabel")) then
		return
	end
	KnifeIcon.render(icon, card.Name)
	local viewport = icon:FindFirstChild("KnifeViewport")
	if viewport and viewport:IsA("ViewportFrame") then
		viewport.ZIndex = icon.ZIndex
		viewport.Ambient = Color3.fromRGB(255, 255, 255)
		viewport.LightColor = Color3.fromRGB(255, 255, 255)
		viewport.LightDirection = Vector3.new(-0.35, -0.65, -0.4).Unit
		local camera = viewport:FindFirstChildOfClass("Camera")
		if camera then
			camera.FieldOfView = 40
			local viewDir = Vector3.new(0.5, 0.28, 0.78).Unit
			camera.CFrame = CFrame.lookAt(viewDir * 3.5, Vector3.new(0, 0, 0))
		end
	end
end

local function fmtPct(chance)
	local pct = math.floor((chance * 100) * 10 + 0.5) / 10  -- 0..1 chance -> percent, rounded to 1 dp
	if pct == math.floor(pct) then
		return tostring(math.floor(pct)) .. "%"
	end
	return string.format("%.1f", pct) .. "%"
end

-- Point one tier card at a specific knife: its skin (via the card name renderCardIcon reads), display
-- name, chance %, and rarity label, then rerender the viewport icon.
local function fillCard(card, entry)
	card.Name = entry.id
	local nameLbl = card:FindFirstChild("KnifeName")
	if nameLbl and nameLbl:IsA("TextLabel") then
		nameLbl.Text = KnifeSkinManager.displayName(entry.id)
	end
	local chanceLbl = card:FindFirstChild("Chance")
	if chanceLbl and chanceLbl:IsA("TextLabel") then
		chanceLbl.Text = fmtPct(entry.chance)
	end
	local rarityLbl = card:FindFirstChild("Rarity")
	if rarityLbl and rarityLbl:IsA("TextLabel") then
		rarityLbl.Text = entry.rarity
	end
	renderCardIcon(card)
end

local function buildBillboard(adornee)
	local template = UI_ASSETS:FindFirstChild(GUI_NAME)
	if not (template and template:IsA("BillboardGui")) then
		warn("[RobuxCaseOddsBillboardClient] template " .. GUI_NAME .. " not found in ReplicatedStorage.Assets.UI")
		return
	end

	local playerGui = player:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild(GUI_NAME)
	if old then
		old:Destroy()
	end

	local gui = template:Clone()
	gui.Name = GUI_NAME
	gui.Adornee = adornee
	gui.Enabled = true
	gui.AlwaysOnTop = true
	gui.MaxDistance = 22
	gui.ResetOnSpawn = false
	gui.Parent = playerGui

	-- Title follows the current crate (the template ships titled for whichever crate it was authored on).
	local title = gui:FindFirstChild("Title", true)
	if title and title:IsA("TextLabel") then
		title.Text = string.upper(CRATE_NAME)
	end

	-- Drive the card contents from the current crate's REAL odds so the board always matches the crate
	-- that's actually loaded -- no manual template edit needed on the weekly swap. These RobuxCase crates
	-- have exactly one knife per rarity tier, so each card is matched to its tier's knife by rarity.
	local entryByRarity = {}
	for _, e in ipairs(KnifeSkinManager.getCrateOdds(CRATE_NAME)) do
		entryByRarity[e.rarity] = e
	end

	local grid = gui:FindFirstChild("Grid", true)
	if grid then
		for _, card in ipairs(grid:GetChildren()) do
			if card:IsA("GuiObject") then
				local rarityLbl = card:FindFirstChild("Rarity")
				local rarityName = (rarityLbl and rarityLbl:IsA("TextLabel")) and rarityLbl.Text or nil
				local entry = rarityName and entryByRarity[rarityName]
				if entry then
					fillCard(card, entry)
				else
					renderCardIcon(card)  -- fallback: leave the template's card as authored
				end
			end
		end
	end
end

local case = waitForCase()
if not case then
	warn("[RobuxCaseOddsBillboardClient] RobuxCase not found")
	return
end

-- Which crate this week comes from the RobuxCase model's CrateName attribute (set alongside the swapped
-- mesh), so the odds board + title always follow the current crate with no code change.
CRATE_NAME = case:GetAttribute("CrateName") or CRATE_NAME

-- RobuxCase is a single MeshPart (no PrimaryPart), so adorn straight to it. Fall back to a Model
-- PrimaryPart / any child BasePart in case the model form changes on a future weekly swap.
local adornee
if case:IsA("BasePart") then
	adornee = case
elseif case:IsA("Model") then
	adornee = case.PrimaryPart or case:FindFirstChildWhichIsA("BasePart", true)
end
if not adornee then
	warn("[RobuxCaseOddsBillboardClient] RobuxCase has no part to adorn to")
	return
end

buildBillboard(adornee)
