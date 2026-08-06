local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local TitleDefinitions = require(ReplicatedStorage.TitleDefinitions)

local BillboardTemplate = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("UI"):WaitForChild("PlayerTitle")

local TAG_NAME = "PlayerTitle"

local PlayerTitleService = Knit.CreateService({
	Name = "PlayerTitleService",
	Client = {},
})

local buildTokenByUserId = {}

local function attachPartOf(character)
	return character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
end

local function equippedTitleId(player)
	local id = player:GetAttribute("EquippedTitle")
	if id == nil or id == "" then
		return nil
	end
	return id
end

-- Titles only show in the lobby, never during a round. MatchManager sets the "InMatch" attribute
-- true while a player is an active round participant (on the map) and false in the lobby / when
-- eliminated, so we gate the billboard's visibility on it.
local function inMatch(player)
	return player:GetAttribute("InMatch") == true
end

local function currentBillboard(player)
	local character = player.Character
	if not character then
		return nil
	end
	local attachPart = attachPartOf(character)
	local gui = attachPart and attachPart:FindFirstChild(TAG_NAME)
	return (gui and gui:IsA("BillboardGui")) and gui or nil
end

function PlayerTitleService:ApplyTitle(player)
	if not player or player.Parent ~= Players then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local attachPart = attachPartOf(character)
	if not attachPart then
		return
	end

	local userId = player.UserId
	local token = (buildTokenByUserId[userId] or 0) + 1
	buildTokenByUserId[userId] = token

	local existing = attachPart:FindFirstChild(TAG_NAME)
	if existing then
		existing:Destroy()
	end

	local id = equippedTitleId(player)
	if not id then
		return
	end

	local def = TitleDefinitions.get(id)
	if not def then
		return
	end

	local gui = BillboardTemplate:Clone()
	gui.Name = TAG_NAME

	local container = gui:WaitForChild("Container")
	local badge = container:WaitForChild("BadgeTemplate")
	badge.Visible = true
	badge.Text = def.Name or id
	badge.TextColor3 = TitleDefinitions.color(id)

	if buildTokenByUserId[userId] ~= token then
		gui:Destroy()
		return
	end

	gui.Enabled = not inMatch(player)
	gui.Parent = attachPart
end

function PlayerTitleService:RefreshVisibility(player)
	local gui = currentBillboard(player)
	if gui then
		gui.Enabled = not inMatch(player)
	end
end

function PlayerTitleService:OnCharacterAdded(player)
	local character = player.Character
	if not character then
		return
	end

	character:WaitForChild("Humanoid")
	self:ApplyTitle(player)
end

function PlayerTitleService:OnPlayerAdded(player)
	player:GetAttributeChangedSignal("EquippedTitle"):Connect(function()
		self:ApplyTitle(player)
	end)

	player:GetAttributeChangedSignal("InMatch"):Connect(function()
		self:RefreshVisibility(player)
	end)

	player.CharacterAdded:Connect(function()
		task.wait(0.1)
		self:OnCharacterAdded(player)
	end)

	if player.Character then
		self:OnCharacterAdded(player)
	end
end

function PlayerTitleService:KnitInit()
	--
end

function PlayerTitleService:KnitStart()
	for _, player in ipairs(Players:GetPlayers()) do
		self:OnPlayerAdded(player)
	end

	Players.PlayerAdded:Connect(function(player)
		self:OnPlayerAdded(player)
	end)
end

return PlayerTitleService
