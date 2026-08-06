-- VotePadSoundClient: plays SoundService.MouseHover (locally, for THIS player) whenever they step
-- onto one of the map-vote pads. Purely cosmetic client feedback — the actual vote is still cast
-- server-side by VotingManager when the pad is Touched. We detect the step-on with the same
-- footprint check the other lobby pads use, and debounce per pad so the sound plays once per
-- entry (not every frame), re-arming when the player steps off.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local RIG_NAME = "MapVotingRig_NEW"   -- matches VotingManager.RIG_NAME
local NUM_OPTIONS = 3
local TRIGGER_PADDING = 1              -- studs of leeway beyond the pad edges (matches other pads)

-- vote-pad colors: white by default, cyan for the option THIS player currently votes for.
local PAD_WHITE = Color3.fromRGB(255, 255, 255)
local PAD_CYAN = Color3.fromRGB(80, 190, 181)  -- the rig's original cyan (0.313726, 0.745098, 0.709804)

-- Play MouseHover locally on a fresh clone so overlapping plays don't cut each other off.
local function playHover()
	local tmpl = SoundService:FindFirstChild("MouseHover")
	if not tmpl then return end
	local s = tmpl:Clone()
	local sfx = SoundService:FindFirstChild("SFX")
	if sfx then s.SoundGroup = sfx end   -- obey the SFX volume slider if present
	s.Parent = SoundService
	s:Play()
	task.delay((s.TimeLength > 0 and s.TimeLength or 2) + 0.2, function()
		if s then s:Destroy() end
	end)
end

-- resolve the rig + its Option pads (the rig lives in Workspace.LobbyInteractives and may stream in
-- slightly after the client starts). Recursive find = robust to wherever the rig is parented.
local function getPads()
	local rig = Workspace:FindFirstChild(RIG_NAME, true)
	if not rig then return nil end
	local pads = {}
	for i = 1, NUM_OPTIONS do
		-- prefer the option whose VoteOption attribute == i (name-independent), else Option<i>
		local model
		for _, c in ipairs(rig:GetChildren()) do
			if c:GetAttribute("VoteOption") == i then model = c break end
		end
		if not model then model = rig:FindFirstChild("Option" .. i) end
		local pad = model and model:FindFirstChild("Pad")
		if pad and pad:IsA("BasePart") then pads[#pads+1] = pad end
	end
	return pads
end

local pads
local waited = 0
while not pads and waited < 30 do
	pads = getPads()
	if pads and #pads > 0 then break end
	pads = nil
	task.wait(0.25); waited += 0.25
end
if not pads or #pads == 0 then
	warn("[VotePadSoundClient] no vote pads found in " .. RIG_NAME)
	return
end

-- ===== vote-pad coloring (white default; the player's selected option turns cyan) =====
-- The visible pads are the VotingPad1/2/3 models (VotingPad<i> sits on Option<i>'s pad). We color
-- all their BaseParts: white normally, cyan for the option the local player currently votes for.
-- The server tells us which option that is via VoteState.myVote (per-player), and we re-color on
-- every update. The rig may stream in after we start, so resolve the VotingPad models with a wait.
local function getVotingPads()
	local rig = Workspace:FindFirstChild(RIG_NAME, true)
	if not rig then return nil end
	local vps = {}
	for i = 1, NUM_OPTIONS do
		local vp = rig:FindFirstChild("VotingPad" .. i)
		if vp then vps[i] = vp end
	end
	return vps
end

local votingPads = getVotingPads() or {}

-- paint one VotingPad model's parts a color
local function paintPad(vp, color)
	if not vp then return end
	for _, p in ipairs(vp:GetDescendants()) do
		if p:IsA("BasePart") then p.Color = color end
	end
end

-- apply: the selected option (1..3) is cyan, all others white. nil selected = all white.
local function applySelection(selected)
	for i = 1, NUM_OPTIONS do
		paintPad(votingPads[i], (i == selected) and PAD_CYAN or PAD_WHITE)
	end
end

-- start all white
applySelection(nil)

-- the server pushes VoteState per player; myVote is the option index this player votes for (or nil).
-- A fresh vote rollover sends myVote = nil, which resets every pad back to white.
local VoteState = ReplicatedStorage:WaitForChild("GameRemotes"):WaitForChild("VoteState")
VoteState.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then return end
	-- re-resolve the pads in case they streamed in after startup (or the rig was re-imported)
	if not votingPads[1] and not votingPads[2] and not votingPads[3] then
		votingPads = getVotingPads() or {}
	end
	applySelection(data.myVote)
end)

-- per-pad "currently standing on it" flag, so we only play the sound on ENTRY
local onPad = {}  -- [pad] = bool

RunService.Heartbeat:Connect(function()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	for _, pad in ipairs(pads) do
		if pad and pad.Parent then
			-- footprint check against the pad's X/Z bounds (same as the shop pads)
			local localPos = pad.CFrame:PointToObjectSpace(hrp.Position)
			local halfX = pad.Size.X / 2 + TRIGGER_PADDING
			local halfZ = pad.Size.Z / 2 + TRIGGER_PADDING
			local nowOn = math.abs(localPos.X) <= halfX and math.abs(localPos.Z) <= halfZ
			if nowOn and not onPad[pad] then
				onPad[pad] = true
				playHover()         -- stepped on -> play once
			elseif not nowOn and onPad[pad] then
				onPad[pad] = false  -- stepped off -> re-arm
			end
		end
	end
end)

print("[VotePadSoundClient] ready (" .. #pads .. " vote pads)")
