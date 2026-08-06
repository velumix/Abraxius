-- Drives the ChooseMode vote UI (Classic vs Reverse Race) from the ModeVoteState broadcast, and
-- casts votes via ModeVoteCast. Shown only in the lobby (not while in a match).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local ModeVoteState = Remotes:WaitForChild("ModeVoteState")
local ModeVoteCast = Remotes:WaitForChild("ModeVoteCast")

local gui = pg:WaitForChild("ChooseMode")
gui.ResetOnSpawn = false

local holder = gui:WaitForChild("ChooseModeHolder")
local reverseBtn = holder:WaitForChild("ReverseRace")
local classicBtn = holder:WaitForChild("Classic")

local buttonById = {
	reverserace = reverseBtn,
	hideandseek = classicBtn,
}

local function setSelected(button, selected)
	local overlay = button:FindFirstChild("SelectedOverlay")
	if overlay then
		overlay.Visible = selected
	end
end

local function setCount(button, count)
	local vc = button:FindFirstChild("VoteCounter")
	local label = vc and vc:FindFirstChild("VoteCountLabel")
	if label then
		label.Text = tostring(count)
	end
end

local function inMatch()
	return player:GetAttribute("InMatch") == true
end

local lastState = nil
local function render(state)
	if state then
		lastState = state
	end
	local s = lastState
	if not s or not s.open or inMatch() then
		gui.Enabled = false
		return
	end
	gui.Enabled = true
	for _, opt in ipairs(s.options or {}) do
		local btn = buttonById[opt.id]
		if btn then
			setCount(btn, opt.votes or 0)
			setSelected(btn, s.myVote == opt.id)
		end
	end
end

ModeVoteState.OnClientEvent:Connect(render)

reverseBtn.MouseButton1Click:Connect(function()
	print("[ChooseModeClient] clicked ReverseRace -> casting reverserace")
	ModeVoteCast:FireServer("reverserace")
end)
classicBtn.MouseButton1Click:Connect(function()
	print("[ChooseModeClient] clicked Classic -> casting hideandseek")
	ModeVoteCast:FireServer("hideandseek")
end)

player:GetAttributeChangedSignal("InMatch"):Connect(function()
	render(nil)
end)

gui.Enabled = false
print("[ChooseModeClient] ready")
