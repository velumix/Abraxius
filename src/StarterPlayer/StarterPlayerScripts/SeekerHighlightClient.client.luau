-- SeekerHighlightClient: shows a RED, see-through-walls Highlight on EVERY seeker so hiders always
-- know where the seekers are. Done CLIENT-SIDE and per-hider: each non-seeker client draws the
-- highlights locally, and the local player's OWN body is never highlighted (so a seeker doesn't get
-- a disturbing red wash over their own screen).
--
-- Supports MULTIPLE seekers (the Join As Seeker feature can add seekers mid-round): we reconcile the
-- full set of seekers from each RoleMap broadcast (userId -> "Hider"/"Seeker"), adding highlights for
-- new seekers and removing them for players who are no longer seekers / no longer in the map.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local RoleMap = Remotes:WaitForChild("RoleMap")

local HIGHLIGHT_NAME = "SeekerHighlight_Local"

-- [Player] = { charAddedConn = RBXScriptConnection } for each seeker we're currently highlighting
local highlighted = {}

local function makeHighlight(char)
	if not char then return end
	local existing = char:FindFirstChild(HIGHLIGHT_NAME)
	if existing then existing:Destroy() end
	local hl = Instance.new("Highlight")
	hl.Name = HIGHLIGHT_NAME
	hl.FillColor = Color3.fromRGB(255, 0, 0)
	hl.FillTransparency = 0.5             -- translucent red wash over the body
	hl.OutlineColor = Color3.fromRGB(255, 0, 0)
	hl.OutlineTransparency = 0
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop  -- renders THROUGH walls
	hl.Adornee = char
	hl.Parent = char
end

local function removeHighlightFrom(seeker)
	local char = seeker and seeker.Character
	if char then
		local hl = char:FindFirstChild(HIGHLIGHT_NAME)
		if hl then hl:Destroy() end
	end
end

local function startHighlight(seeker)
	if highlighted[seeker] then return end  -- already highlighting this seeker
	local entry = {}
	highlighted[seeker] = entry
	if seeker.Character then makeHighlight(seeker.Character) end
	-- re-apply if this seeker respawns mid-round (e.g. they reset)
	entry.charAddedConn = seeker.CharacterAdded:Connect(function(char)
		if highlighted[seeker] then makeHighlight(char) end
	end)
end

local function stopHighlight(seeker)
	local entry = highlighted[seeker]
	if not entry then return end
	if entry.charAddedConn then entry.charAddedConn:Disconnect() end
	highlighted[seeker] = nil
	removeHighlightFrom(seeker)
end

local function clearAll()
	for seeker in pairs(highlighted) do
		stopHighlight(seeker)
	end
end

RoleMap.OnClientEvent:Connect(function(map)
	map = map or {}
	-- Build the set of seeker Players from the map. NOTE: the server keys this table by numeric
	-- UserId, but Roblox serializes integer dict keys to STRINGS over a RemoteEvent, so normalize
	-- with tonumber. We never highlight the local player's own body.
	local wantSeekers = {}  -- [Player] = true
	for userId, role in pairs(map) do
		if role == "Seeker" then
			local uid = tonumber(userId)
			if uid and uid ~= player.UserId then
				local seeker = Players:GetPlayerByUserId(uid)
				if seeker then wantSeekers[seeker] = true end
			end
		end
	end

	-- remove highlights for anyone no longer a seeker (or gone from the map / round over)
	for seeker in pairs(highlighted) do
		if not wantSeekers[seeker] then stopHighlight(seeker) end
	end
	-- add highlights for any new seekers
	for seeker in pairs(wantSeekers) do
		startHighlight(seeker)
	end
end)

-- if a highlighted seeker leaves, clean up their entry
Players.PlayerRemoving:Connect(function(plr)
	if highlighted[plr] then stopHighlight(plr) end
end)

print("[SeekerHighlightClient] ready (multi-seeker)")
