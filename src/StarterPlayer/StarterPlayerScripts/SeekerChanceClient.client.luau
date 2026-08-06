-- SeekerChanceClient: shows the player's current % chance of being the seeker next round.
-- Driven by the server's SeekerChance remote (sent during intermission, on join, on AFK change).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local SeekerChance = Remotes:WaitForChild("SeekerChance")

local pg = player:WaitForChild("PlayerGui")
-- SeekerChance display now lives in the consolidated Hud. It's a layered label (a back TextLabel with
-- a "Top" overlay for the drop-shadow effect) and the authored format is "Seeker Chance: N%", so we
-- update both layers with the full phrase.
local hud = pg:WaitForChild("Hud")
local frame = hud:WaitForChild("SeekerChance")
local pctLabel = frame:WaitForChild("SeekerChance")
local pctTop = pctLabel:WaitForChild("Top")  -- overlay layer; keep in sync

SeekerChance.OnClientEvent:Connect(function(pct)
	pct = tonumber(pct) or 0
	-- round to a whole percent for a clean display
	local text = string.format("Seeker Chance: %d%%", math.floor(pct + 0.5))
	pctLabel.Text = text
	pctTop.Text = text
end)
