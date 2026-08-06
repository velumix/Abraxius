-- MusicDirector (server): single source of truth for which music track is playing, so EVERY player
-- in the server hears the SAME lobby/round track at the SAME position. Previously each client picked
-- its own random track locally (RoundMusicClient / LobbyMusicClient), so players were out of sync.
--
-- Model: there are two "channels" — "lobby" and "round". For each channel the server decides the
-- current track and the server-clock timestamp it started at, and broadcasts that via the MusicSync
-- remote. Clients PLAY whichever channel matches their own state (in lobby vs in round, gated by the
-- existing InRound remote) and SEEK to (now - startTime) so they drop in at the shared position —
-- including late joiners and players who just entered/left a round.
--
-- The server advances a channel to its next track on a timer sized to the track length, so the whole
-- server moves to the next song together. Track SELECTION is server-side (random, no immediate
-- repeat); the clients no longer choose. Per-channel hearing/fades/state-gating still live on the
-- clients (so e.g. a hider only HEARS round music while actually in the round).

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Packages.Knit)

local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local MusicSync = Remotes:FindFirstChild("MusicSync")
if not MusicSync then
	MusicSync = Instance.new("RemoteEvent")
	MusicSync.Name = "MusicSync"
	MusicSync.Parent = Remotes
end

local lobbyFolder = SoundService:WaitForChild("LobbyMusic")
local roundFolder = SoundService:WaitForChild("RoundMusic")
local PAINTING_BOSS_TRACK = "Final Boss (a)"

-- MatchManager publishes the phase as the first token of MatchTelemetry.Value ("INTERMISSION ...",
-- "HIDE ...", "ROUND ...", "RESOLVE ..."). We use it only to know when a round's music should be
-- running vs when the lobby music should be. (The clients still gate what they HEAR via InRound.)
local MatchTelemetry = ReplicatedStorage:WaitForChild("MatchTelemetry")

-- ===== channel state =====
-- Each channel tracks: the current track name, the server time it started, and its length so we know
-- when to advance. nil track = silent.
local channels = {
	lobby = { track = nil, startTime = 0, length = 0 },
	round = { track = nil, startTime = 0, length = 0 },
}

local function listTracks(folder)
	local t = {}
	for _, c in ipairs(folder:GetChildren()) do
		if c:IsA("Sound") then t[#t + 1] = c end
	end
	return t
end

local function getTrack(folder, trackName)
	local track = folder:FindFirstChild(trackName)
	return (track and track:IsA("Sound")) and track or nil
end

-- pick a random track from `folder`, avoiding `excludeName` when there's more than one option
local function pickTrack(folder, excludeName)
	local tracks = listTracks(folder)
	if #tracks == 0 then return nil end
	if #tracks == 1 then return tracks[1] end
	local choice
	repeat
		choice = tracks[math.random(1, #tracks)]
	until choice.Name ~= excludeName
	return choice
end

-- Broadcast a channel's current state to one client (or everyone if `target` is nil). The client uses
-- startServerTime with Workspace:GetServerTimeNow() to seek to the shared position.
local function broadcastChannel(channelName, target)
	local ch = channels[channelName]
	local payload = {
		channel = channelName,
		trackName = ch.track and ch.track.Name or nil,
		startServerTime = ch.startTime,
		length = ch.length,
	}
	if target then
		MusicSync:FireClient(target, payload)
	else
		MusicSync:FireAllClients(payload)
	end
end

-- Set a channel to a specific track NOW (server clock), broadcast it, and return the chosen track.
local function setChannelTrack(channelName, folder, excludeName, preferredName)
	local ch = channels[channelName]
	local track = if preferredName then getTrack(folder, preferredName) else nil
	if not track then
		track = pickTrack(folder, excludeName)
	end
	ch.track = track
	ch.startTime = Workspace:GetServerTimeNow()
	ch.length = track and (track.TimeLength > 0 and track.TimeLength or 0) or 0
	broadcastChannel(channelName)
	return track
end

local function clearChannel(channelName)
	local ch = channels[channelName]
	if ch.track == nil then return end
	ch.track = nil
	ch.startTime = 0
	ch.length = 0
	broadcastChannel(channelName)
end

-- ===== per-channel director loops =====
-- Each loop keeps its channel populated with a current track and advances to the next one when the
-- current track's duration elapses (by the server clock). A generation counter lets us cancel a
-- loop cleanly if the channel is reset.

-- LOBBY: always has a track playing (the lobby music plays continuously server-wide; clients only
-- HEAR it while in the lobby). If the lobby folder has a single looped track, we still rebroadcast
-- its shared start so late joiners sync to the same loop position.
local function runLobbyChannel()
	while true do
		local track = setChannelTrack("lobby", lobbyFolder, channels.lobby.track and channels.lobby.track.Name)
		if not track then
			task.wait(2)  -- no tracks; idle and retry
		else
			local waitTime = (track.TimeLength > 0 and track.TimeLength or 30)
			task.wait(waitTime)
		end
	end
end

-- ROUND: a track set is active only while a round is running (HIDE/ROUND phase). When the round
-- music should be on, we keep advancing through random tracks; when it should be off, we clear the
-- channel and wait. We detect the phase from MatchTelemetry.
local function isRoundPhase()
	local v = MatchTelemetry.Value or ""
	return v:sub(1, 5) == "ROUND" or v:sub(1, 4) == "HIDE"
end

local paintingBossService = nil
local function isPaintingBossActive()
	if not paintingBossService then
		local ok, service = pcall(function()
			return Knit.GetService("PaintingBossService")
		end)
		if ok then
			paintingBossService = service
		end
	end

	if not paintingBossService then
		return false
	end

	local ok, active = pcall(function()
		return paintingBossService:IsEventActive()
	end)
	return ok and active == true
end

local function runRoundChannel()
	local lastName = nil
	while true do
		if isRoundPhase() then
			-- start (or continue) the round playlist
			local preferredTrack = if isPaintingBossActive() then PAINTING_BOSS_TRACK else nil
			local track = setChannelTrack("round", roundFolder, lastName, preferredTrack)
			if track then lastName = track.Name end
			local waitTime = track and (track.TimeLength > 0 and track.TimeLength or 30) or 2
			-- wait out the track, but bail early if the round ends or a boss event needs its music.
			local elapsed = 0
			while elapsed < waitTime do
				if not isRoundPhase() then break end
				if isPaintingBossActive() and channels.round.track and channels.round.track.Name ~= PAINTING_BOSS_TRACK then
					break
				end
				task.wait(1)
				elapsed += 1
			end
			if not isRoundPhase() then
				clearChannel("round")
				lastName = nil
			end
		else
			if channels.round.track ~= nil then clearChannel("round") end
			task.wait(1)
		end
	end
end

-- ===== late-joiner sync: send both channels' current state to a newly joined player =====
Players.PlayerAdded:Connect(function(plr)
	task.spawn(function()
		task.wait(1)  -- give their client a moment to set up its MusicSync listener
		broadcastChannel("lobby", plr)
		broadcastChannel("round", plr)
	end)
end)

-- A client can request a resync on demand (e.g. when it transitions lobby<->round and wants the
-- current shared position immediately rather than waiting for the next broadcast).
MusicSync.OnServerEvent:Connect(function(plr)
	broadcastChannel("lobby", plr)
	broadcastChannel("round", plr)
end)

task.spawn(runLobbyChannel)
task.spawn(runRoundChannel)

print("[MusicDirector] ready (server-synced music)")
