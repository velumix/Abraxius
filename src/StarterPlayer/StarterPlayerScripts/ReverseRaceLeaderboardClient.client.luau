-- Populates Hud.RoundLeaderboard (a horizontal top bar) from the ReverseRaceLeaderboard broadcast.
-- Shows the top 8 by points; if the local player isn't in the top 8, shows the top 7 plus the local
-- player in the 8th slot with their ACTUAL placement. Shown at round end, hidden when the next starts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local leaderboardRemote = Remotes:WaitForChild("ReverseRaceLeaderboard")
local InRound = Remotes:WaitForChild("InRound")

local hud = pg:WaitForChild("Hud")
local root = hud:WaitForChild("Main"):WaitForChild("Top"):WaitForChild("RoundLeaderboard")
local leaderboard = root:WaitForChild("Leaderboard")
local template = leaderboard:WaitForChild("Template")
template.Visible = false

local FALLBACK_USER_IDS = { 1, 156, 261, 1103712, 2032622, 13365322, 968108950, 261 }
local function headshot(userId)
	if userId < 0 then
		userId = FALLBACK_USER_IDS[math.random(1, #FALLBACK_USER_IDS)]
	end
	return string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", userId)
end

-- ===== populate =====
local spawnedSlots = {}
local function clearSlots()
	for _, s in ipairs(spawnedSlots) do
		s:Destroy()
	end
	spawnedSlots = {}
end

local function setText(label, text)
	if not (label and label:IsA("TextLabel")) then
		return
	end
	label.Text = text
	-- These labels are layered (a nested "Name"/"Top" TextLabel drawn on top for a shadow); set every
	-- nested TextLabel too or the visible layer keeps the template's placeholder.
	for _, c in ipairs(label:GetDescendants()) do
		if c:IsA("TextLabel") then
			c.Text = text
		end
	end
end

local function makeSlot(entry, rank, order)
	local slot = template:Clone()
	slot.Name = "Slot" .. order
	slot.LayoutOrder = order
	slot.Visible = true
	local pic = slot:FindFirstChild("PlayerIcon", true)
	if pic and pic:IsA("ImageLabel") then
		pic.Image = headshot(entry.userId or 1)
	end
	setText(slot:FindFirstChild("PlacementLabel", true), "#" .. rank)
	setText(slot:FindFirstChild("Points", true), tostring(entry.points or 0))
	slot.Parent = leaderboard
	table.insert(spawnedSlots, slot)
end

local function render(payload)
	if type(payload) ~= "table" then
		return
	end
	if payload.hide then
		root.Visible = false
		return
	end
	if type(payload.rows) ~= "table" then
		return
	end
	clearSlots()
	local rows = payload.rows
	local myRank
	for i, e in ipairs(rows) do
		if e.userId == player.UserId then
			myRank = i
			break
		end
	end
	local order = 0
	if not myRank or myRank <= 8 then
		for i = 1, math.min(8, #rows) do
			order += 1
			makeSlot(rows[i], i, order)
		end
	else
		-- not in the top 8: show the top 7, then the local player in slot 8 at their real placement
		for i = 1, 7 do
			order += 1
			makeSlot(rows[i], i, order)
		end
		order += 1
		makeSlot(rows[myRank], myRank, order)
	end
	root.Visible = true
end

leaderboardRemote.OnClientEvent:Connect(render)

root.Visible = false
print("[ReverseRaceLeaderboardClient] ready")
