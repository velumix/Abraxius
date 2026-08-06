-- LobbyMusicClient: plays the SERVER-CHOSEN lobby track (from SoundService.LobbyMusic) while THIS
-- player is in the lobby, and stops it while they're actively in a round. The TRACK and its shared
-- start time come from the server (MusicSync remote) so every player hears the SAME track at the
-- SAME position; this client only decides WHEN to play it (lobby vs round) and handles the fades.
--   * intermission / waiting for players  -> InRound false  -> music plays
--   * round begins (HIDE)                 -> InRound true   -> music stops (for active players)
--   * a hider is eliminated back to lobby -> InRound false  -> music resumes for them
--   * players skipped/AFK during a round  -> InRound false  -> music keeps playing (they're in lobby)
-- When we (re)start, we SEEK to (serverNow - startServerTime) % length so we drop in at the shared
-- position rather than restarting the track from 0.
--
-- The music FADES in/out rather than popping. When a hider dies the server fires InRound=false
-- immediately (while the "You have been found!" black screen is still up), so we wait a short beat
-- before starting so the music doesn't blare in under the death screen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local InRound = Remotes:WaitForChild("InRound")
local MusicSync = Remotes:WaitForChild("MusicSync")
local StateChanged = Remotes:WaitForChild("StateChanged")

local folder = SoundService:WaitForChild("LobbyMusic")  -- a Folder of lobby tracks
local musicGroup = SoundService:FindFirstChild("Music")  -- so lobby music obeys the Music volume slider

local FADE_IN = 0.8          -- seconds to ease the music in (kept snappy)
local FADE_OUT = 0.6         -- seconds to ease it out when a round starts
local START_DELAY = 2.2      -- wait this long before starting, so it doesn't play under the death black screen

local inRound = false
local resolving = false       -- true during the RESOLVE phase (round over, win sequence playing). The
                              -- round music has stopped, so the lobby music should play during RESOLVE
                              -- (in sync) even though in-round players still carry inRound=true until the
                              -- next intermission. We treat RESOLVE as a lobby-music phase.
local generation = 0         -- bumped on every state change to cancel stale fades/delayed starts
local fadeTween = nil
local currentTrack = nil     -- the Sound currently playing
local endedConn = nil        -- connection for "track finished -> resync"

-- latest server-dictated lobby track state (from MusicSync). trackName=nil means silent.
local serverState = { trackName = nil, startServerTime = 0, length = 0 }

local function findTrack(name)
	if not name then return nil end
	local s = folder:FindFirstChild(name)
	return (s and s:IsA("Sound")) and s or nil
end

-- where in the track the whole server currently is, in seconds (wraps for looped tracks)
local function sharedPosition()
	local elapsed = Workspace:GetServerTimeNow() - serverState.startServerTime
	if elapsed < 0 then elapsed = 0 end
	local len = serverState.length
	if len and len > 0 then elapsed = elapsed % len end
	return elapsed
end

local function cancelFade()
	if fadeTween then fadeTween:Cancel(); fadeTween = nil end
end

-- stop whatever's playing now; clears the ended handler
local function stopCurrent()
	if endedConn then endedConn:Disconnect(); endedConn = nil end
	if currentTrack then
		currentTrack:Stop()
		currentTrack = nil
	end
end

local function fadeOutAndStop(time)
	cancelFade()
	local track = currentTrack
	if not track then return end
	local myGen = generation
	fadeTween = TweenService:Create(track, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Volume = 0 })
	fadeTween.Completed:Connect(function(state)
		if myGen == generation and state == Enum.PlaybackState.Completed then
			if endedConn then endedConn:Disconnect(); endedConn = nil end
			track:Stop()
			if currentTrack == track then currentTrack = nil end
		end
	end)
	fadeTween:Play()
end

-- play the server's current lobby track, seeked to the shared position, fading up to its volume
local function playServerTrack()
	local track = findTrack(serverState.trackName)
	if not track then stopCurrent(); return end
	stopCurrent()
	currentTrack = track
	if musicGroup then track.SoundGroup = musicGroup end  -- obey the Music slider
	local targetVol = track:GetAttribute("BaseVolume")
	if not targetVol then
		targetVol = (track.Volume > 0) and track.Volume or 1
		track:SetAttribute("BaseVolume", targetVol)  -- remember authored volume across fades
	end
	-- loop locally so a single shared track keeps playing between server rebroadcasts; we always seek
	-- to the shared position on (re)start so everyone stays aligned.
	track.Looped = true
	track.Volume = 0
	track.TimePosition = math.min(sharedPosition(), math.max(0, (track.TimeLength or 0) - 0.05))
	track:Play()

	cancelFade()
	fadeTween = TweenService:Create(track, TweenInfo.new(FADE_IN, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Volume = targetVol })
	fadeTween:Play()
end

-- true if this client should currently be HEARING the lobby music: whenever they're not actively in
-- a round, OR during RESOLVE (the round music has ended and the win sequence plays over lobby music).
local function shouldPlayLobby()
	return (not inRound) or resolving
end

local function enterLobby()
	local myGen = generation
	-- short delay so a just-died player doesn't hear it under the black screen; if their state flips
	-- again before the delay elapses (myGen changes), we abort.
	task.delay(START_DELAY, function()
		if myGen ~= generation then return end       -- state changed during the wait; abort
		if not shouldPlayLobby() then return end      -- safety: only play if we should be hearing lobby music
		MusicSync:FireServer()  -- ask for the freshest shared position, then play on the reply
		playServerTrack()
	end)
end

local function enterRound()
	fadeOutAndStop(FADE_OUT)
end

local function refresh()
	generation += 1  -- invalidate any in-flight delayed start / fade from the previous state
	if shouldPlayLobby() then
		enterLobby()
	else
		enterRound()
	end
end

InRound.OnClientEvent:Connect(function(active)
	inRound = active and true or false
	refresh()
end)

-- Track the round phase so RESOLVE is treated as a lobby-music phase. During RESOLVE the round music
-- stops and the win sequence plays, so in-round players should hear the (synced) lobby music then,
-- not silence. Any non-RESOLVE state clears the flag; the inRound gate then takes over as normal.
StateChanged.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" or data.state == nil then return end
	local nowResolving = (data.state == "RESOLVE" or data.state == "REVEALING_HIDERS")
	if nowResolving ~= resolving then
		resolving = nowResolving
		refresh()
	end
end)

-- server tells us the current lobby track + shared start. Update our state; if we're in the lobby
-- and the track changed, re-sync to it.
MusicSync.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" or payload.channel ~= "lobby" then return end
	local changed = (payload.trackName ~= serverState.trackName)
	serverState.trackName = payload.trackName
	serverState.startServerTime = payload.startServerTime or 0
	serverState.length = payload.length or 0
	if shouldPlayLobby() then
		if changed or not currentTrack then
			-- (re)align to the server's track/position
			local myGen = generation
			if currentTrack and not changed then
				-- same track still playing; gently re-seek if we've drifted a lot
				local drift = math.abs((currentTrack.TimePosition or 0) - sharedPosition())
				if drift > 1.5 then currentTrack.TimePosition = sharedPosition() end
			else
				playServerTrack()
			end
		end
	end
end)

-- a freshly joined player starts in the lobby, so start the music (after the usual short delay)
refresh()
