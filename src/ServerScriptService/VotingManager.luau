-- VotingManager: MM2-style map voting that stays OPEN continuously across all phases.
--
-- Model (driven by MatchManager):
--   * The vote is ALWAYS open. Players can step on a pad in ANY phase (intermission, hide, round,
--     resolve) and their vote counts toward the NEXT round's map.
--   * openVote()     -- opens the first vote (called once at startup). Picks up to 3 eligible
--                       candidates, populates the boards, wires the pads. Idempotent-ish: calling it
--                       again just refreshes/re-wires.
--   * resolveVote()  -- captures the current WINNER (most votes; tie / all-zero = random among the
--                       shown candidates) and returns it, but does NOT change the boards. The boards
--                       keep showing the resolved candidates through the map-load + hide phase.
--   * openNextVote() -- opens a FRESH vote for the next round (new candidates, tallies reset). Called
--                       once the round has begun and players are teleported in, so the boards only
--                       flip to the next options AFTER the round starts (not the instant the vote
--                       resolves). The vote stays open from then on so lobby players can keep voting.
--
-- One live, MOVABLE vote per player: touching a pad casts your vote; touching a different pad MOVES
-- it (-1 old, +1 new). Never voting = 0. A player's vote is cleared each time a vote rolls over, so
-- they vote fresh for each upcoming round.
--
-- The rig lives in Workspace.LobbyInteractives (a central folder holding every lobby object the
-- scripts rely on — move that folder's contents when the lobby changes and nothing needs re-pointing).
-- The rig is named MapVotingRig_NEW with 3 option Models (Option1/2/3). Each option Model has an
-- attribute "VoteOption" (1/2/3), a "Pad" BasePart (touch target), and a "Board" BasePart whose
-- "Display" SurfaceGui holds: Thumb (ImageLabel, fills the whole board), MapName (TextLabel, centered
-- across the top), VoteCount (TextLabel, just the number in the bottom-right). Real art parts can
-- replace these as long as those names + the VoteOption attribute are preserved. (getRig finds the
-- rig recursively by name, so it works wherever the rig is parented in Workspace.)
--

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapManager = require(script.Parent:WaitForChild("MapManager"))
local MapCatalog = require(ReplicatedStorage:WaitForChild("MapCatalog"))
local Constants = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Constants"))

local VotingManager = {}

local function mapThumb(template)
	if not template then return nil end
	local entry = MapCatalog.get(template.Name)
	return entry and entry.thumbnail or nil
end

local MarketplaceService = game:GetService("MarketplaceService")

local RIG_NAME = "MapVotingRig_NEW"
local NUM_OPTIONS = 3
local TOUCH_DEBOUNCE = 0.5  -- per-player seconds between accepted pad touches (anti-bounce)

-- "2x Map Vote" gamepass: owners' votes count DOUBLE. We cache ownership per userId (a yielding
-- UserOwnsGamePassAsync call) and the 2xMapVote pad script refreshes it on purchase via
-- VotingManager.refreshVoteGamepass. voteWeight(player) returns 2 for owners, else 1.
local DOUBLE_VOTE_GAMEPASS_ID = Constants.Gamepasses.DOUBLE_VOTE
local DOUBLE_VOTE_WEIGHT = 2

-- ===== Remotes =====
local Remotes = ReplicatedStorage:FindFirstChild("GameRemotes")
if not Remotes then
	Remotes = Instance.new("Folder"); Remotes.Name = "GameRemotes"; Remotes.Parent = ReplicatedStorage
end
-- server -> client: full board state when a vote opens/updates. Payload:
--   { open = true, options = { [1] = {name=, thumb=, votes=}, ... } }  (open=false hides UI)
local VoteState = Remotes:FindFirstChild("VoteState")
if not VoteState then
	VoteState = Instance.new("RemoteEvent"); VoteState.Name = "VoteState"; VoteState.Parent = Remotes
end

-- ===== Runtime state =====
local candidates = {}    -- [optionIndex] = map template instance (from MapManager.pickCandidates)
local votes = {}         -- [optionIndex] = integer vote count
local playerVote = {}    -- [player] = optionIndex they currently vote for (nil = hasn't voted)
local voteWeight = {}    -- [player] = the weight ADDED for their current vote (so moving/clearing subtracts the SAME amount even if their gamepass state changes mid-session)
local lastTouch = {}     -- [player] = os.clock() of their last accepted touch (debounce)
local touchConns = {}    -- active Touched connections (cleaned up when the vote closes)
local voteOpen = false

-- ===== 2x Map Vote gamepass ownership =====
local ownsDoubleVote = {}  -- [userId] = bool (cached)
local function refreshDoubleVote(plr)
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(plr.UserId, DOUBLE_VOTE_GAMEPASS_ID)
	end)
	if ok then ownsDoubleVote[plr.UserId] = owns end
end

-- How many vote points this player's touch is worth: 2 with the 2x Map Vote gamepass, else 1.
local function weightFor(plr)
	return ownsDoubleVote[plr.UserId] and DOUBLE_VOTE_WEIGHT or 1
end

-- Public: the 2xMapVote pad script calls this right after a successful gamepass purchase so the
-- buyer's next vote immediately counts double (no rejoin needed).
function VotingManager.refreshVoteGamepass(plr)
	refreshDoubleVote(plr)
end

-- ===== Rig lookup =====
-- Find the rig and return a map of optionIndex -> { model, pad, board, gui labels }. Tolerant of a
-- missing rig / missing parts (logs a warning and returns whatever it found) so a half-built rig
-- doesn't hard-crash the round loop. We search RECURSIVELY (the rig was moved under Lobby2), so the
-- lookup keeps working regardless of where in Workspace the rig is parented.
local function getRig()
	return Workspace:FindFirstChild(RIG_NAME, true)
end

local function getOptionParts(rig, index)
	if not rig then return nil end
	-- find the option Model whose VoteOption attribute == index (name-independent)
	local model
	for _, c in ipairs(rig:GetChildren()) do
		if c:GetAttribute("VoteOption") == index then model = c break end
	end
	-- fallback: by conventional name "Option<index>"
	if not model then model = rig:FindFirstChild("Option" .. index) end
	if not model then return nil end
	local pad = model:FindFirstChild("Pad")
	local board = model:FindFirstChild("Board")
	local gui = board and board:FindFirstChild("Display")
	return {
		model = model,
		pad = pad,
		board = board,
		mapName = gui and gui:FindFirstChild("MapName"),
		thumb = gui and gui:FindFirstChild("Thumb"),
		voteCount = gui and gui:FindFirstChild("VoteCount"),
	}
end

-- ===== Board display =====
local function refreshBoard(index)
	local rig = getRig()
	local parts = getOptionParts(rig, index)
	if not parts then return end
	local template = candidates[index]
	local count = votes[index] or 0
	if parts.mapName then
		parts.mapName.Text = template and template.Name or "---"
	end
	if parts.thumb then
		parts.thumb.Image = mapThumb(template) or ""
	end
	if parts.voteCount then
		parts.voteCount.Text = tostring(count)  -- just the number (bottom-right corner of the board image)
	end
end

local function refreshAllBoards()
	for i = 1, NUM_OPTIONS do refreshBoard(i) end
end

-- broadcast the full vote state to clients (for any screen UI mirroring the boards). We send PER
-- PLAYER (not FireAllClients) so each client also learns THEIR OWN current vote (myVote) -- used to
-- color that player's selected vote pad cyan while the others stay white.
local function broadcastState()
	local options = {}
	for i = 1, NUM_OPTIONS do
		local template = candidates[i]
		options[i] = {
			name = template and template.Name or nil,
			thumb = mapThumb(template),
			votes = votes[i] or 0,
		}
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		VoteState:FireClient(plr, { open = voteOpen, options = options, myVote = playerVote[plr] })
	end
end

-- ===== Voting logic =====
-- Cast or MOVE a player's vote to optionIndex. One live vote per player: -1 from their old option,
-- +1 to the new. Touching the SAME option they already voted for is a no-op. Returns true if the
-- tally changed (so we only refresh/broadcast on a real change).
local function castVote(player, optionIndex)
	if not voteOpen then return false end
	if not candidates[optionIndex] then return false end  -- empty slot (tiny map pool) can't be voted
	local prev = playerVote[player]
	if prev == optionIndex then return false end          -- already voting for this one
	-- remove their previous vote using the EXACT weight it was added with (not the current weight, in
	-- case their gamepass state changed since), so counts can never drift.
	if prev and votes[prev] then
		votes[prev] = math.max(0, votes[prev] - (voteWeight[player] or 1))
	end
	-- add the new vote at this player's current weight (2 with the 2x Map Vote gamepass, else 1)
	local w = weightFor(player)
	votes[optionIndex] = (votes[optionIndex] or 0) + w
	playerVote[player] = optionIndex
	voteWeight[player] = w
	return true
end

local function onPadTouched(optionIndex, hit)
	if not voteOpen then return end
	local char = hit and hit.Parent
	local player = char and Players:GetPlayerFromCharacter(char)
	if not player then return end
	-- debounce per player so a single step doesn't fire many touches
	local now = os.clock()
	if lastTouch[player] and (now - lastTouch[player]) < TOUCH_DEBOUNCE then return end
	lastTouch[player] = now
	if castVote(player, optionIndex) then
		refreshBoard(optionIndex)
		-- the previous option's count also dropped; cheap to just refresh all
		refreshAllBoards()
		broadcastState()
	end
end

local function disconnectTouches()
	for _, c in ipairs(touchConns) do
		if c then c:Disconnect() end
	end
	touchConns = {}
end

local function wirePads()
	disconnectTouches()
	local rig = getRig()
	if not rig then
		warn("[VotingManager] no " .. RIG_NAME .. " found in Workspace; voting will fall back to random pick")
		return
	end
	for i = 1, NUM_OPTIONS do
		local parts = getOptionParts(rig, i)
		if parts and parts.pad then
			local idx = i
			touchConns[#touchConns+1] = parts.pad.Touched:Connect(function(hit)
				onPadTouched(idx, hit)
			end)
		else
			warn("[VotingManager] option " .. i .. " has no Pad; that slot can't be voted")
		end
	end
end

-- ===== Public API =====

-- True if there are at least 2 distinct maps to vote between. With 0 or 1 map, voting is pointless
-- (MatchManager should just load the single/random map directly).
function VotingManager.canVote()
	return #MapManager.listMaps() >= 2
end

-- True if a vote is currently open (for MatchManager to decide whether to resolve vs. random-pick).
function VotingManager.isOpen()
	return voteOpen
end

-- (Re)open a vote: pick fresh candidates, reset tallies + per-player votes, populate + wire the
-- boards. Safe to call even if the rig is missing (it just won't have touch pads; resolveVote still
-- returns a random candidate). This is the single "open a new round's vote" primitive, used both for
-- the very first vote at startup and for the rollover after each resolve.
function VotingManager.openVote()
	candidates = MapManager.pickCandidates(NUM_OPTIONS)
	votes = {}
	playerVote = {}
	voteWeight = {}
	lastTouch = {}
	for i = 1, NUM_OPTIONS do votes[i] = 0 end
	voteOpen = true
	refreshAllBoards()
	wirePads()
	broadcastState()
	local names = {}
	for i = 1, NUM_OPTIONS do names[i] = candidates[i] and candidates[i].Name or "-" end
	print("[VotingManager] vote opened: " .. table.concat(names, ", "))
end

-- Back-compat alias: startVote == openVote (older call sites / clarity).
VotingManager.startVote = VotingManager.openVote

-- Capture the current WINNER and return it. Does NOT touch the boards or open a new vote — the
-- boards keep showing the just-resolved candidates (with their final counts) through the map-load
-- buffer and the hide phase. Call openNextVote() once the round has actually begun to roll the
-- boards over to the next round's options.
-- Winner = most votes; ties or all-zero resolve to a RANDOM pick among the shown candidates.
-- Returns the winning map template (a ServerStorage instance), or nil if there were no candidates.
function VotingManager.resolveVote()
	local valid = {}
	for i = 1, NUM_OPTIONS do
		if candidates[i] then table.insert(valid, i) end
	end
	if #valid == 0 then return nil end

	local best = -1
	for _, i in ipairs(valid) do
		if (votes[i] or 0) > best then best = votes[i] or 0 end
	end
	local topTied = {}
	for _, i in ipairs(valid) do
		if (votes[i] or 0) == best then table.insert(topTied, i) end
	end
	local winnerIndex = topTied[math.random(1, #topTied)]
	local winner = candidates[winnerIndex]
	print(string.format("[VotingManager] vote resolved: %s (%d votes%s)",
		winner and winner.Name or "?", best,
		#topTied > 1 and ", random tiebreak among " .. #topTied or ""))
	return winner
end

-- Open a FRESH vote for the next round: re-pick candidates (excluding the last-2 maps, which now
-- includes the just-loaded winner), reset tallies + per-player votes, repopulate + re-wire the
-- boards, and re-broadcast. MatchManager calls this AFTER the round has begun and players are
-- teleported in, so the boards only switch to the next options once the round is underway — not the
-- instant the previous vote resolved. (Internally identical to openVote; named for clarity at the
-- call site.)
function VotingManager.openNextVote()
	VotingManager.openVote()
end

-- Force-hide the voting UI / clear pad wiring without resolving (e.g. server shutting a vote down).
-- Rarely needed in the always-open model, but kept for completeness.
function VotingManager.cancelVote()
	voteOpen = false
	disconnectTouches()
	candidates = {}
	votes = {}
	playerVote = {}
	voteWeight = {}
	VoteState:FireAllClients({ open = false })
end

-- clean up a leaving player's vote (so their count doesn't linger)
Players.PlayerRemoving:Connect(function(plr)
	local prev = playerVote[plr]
	if prev and votes[prev] then
		votes[prev] = math.max(0, votes[prev] - (voteWeight[plr] or 1))
		if voteOpen then refreshAllBoards(); broadcastState() end
	end
	playerVote[plr] = nil
	voteWeight[plr] = nil
	lastTouch[plr] = nil
	ownsDoubleVote[plr.UserId] = nil
end)

-- A player who joins (or whose client loads after the last broadcast) gets the current state pushed
-- so their vote-pad coloring + boards are correct right away. Also covers a respawn-driven re-ask.
Players.PlayerAdded:Connect(function(plr)
	-- cache their 2x Map Vote gamepass ownership up front so their first vote is weighted correctly
	task.spawn(function() refreshDoubleVote(plr) end)
	task.spawn(function()
		task.wait(1)  -- let their client UI/scripts load before the first push
		local options = {}
		for i = 1, NUM_OPTIONS do
			local template = candidates[i]
			options[i] = {
				name = template and template.Name or nil,
				thumb = mapThumb(template),
				votes = votes[i] or 0,
			}
		end
		VoteState:FireClient(plr, { open = voteOpen, options = options, myVote = playerVote[plr] })
	end)
end)

-- Cache 2x-Map-Vote ownership for anyone ALREADY in the server when this module first loads (the
-- PlayerAdded handler above only covers future joins). Keeps first-vote weighting correct after a
-- live script reload / mid-session start.
for _, plr in ipairs(Players:GetPlayers()) do
	task.spawn(function() refreshDoubleVote(plr) end)
end

return VotingManager
