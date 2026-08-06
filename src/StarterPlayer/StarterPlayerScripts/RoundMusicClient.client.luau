-- RoundMusicClient: plays the SERVER-CHOSEN round track (SoundService.RoundMusic) to THIS player
-- while they're actively in a round, and stops it in the lobby. The TRACK and its shared start time
-- come from the server (MusicSync remote) so every player in the round hears the SAME track at the
-- SAME position; this client only decides WHEN to play (the inverse InRound gate of the lobby music)
-- and handles fades + the role-reveal hold.
--   * round begins (HIDE)        -> InRound true  -> the server's round track starts (seeked to shared pos)
--   * round ends / eliminated    -> InRound false -> the music fades out and stops
-- We SEEK to (serverNow - startServerTime) so a player entering the round mid-track (or a join-as-
-- seeker convert) drops in where everyone else is.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local InRound = Remotes:WaitForChild("InRound")
local MusicSync = Remotes:WaitForChild("MusicSync")
-- MatchManager publishes the phase as the first token of MatchTelemetry.Value ("HIDE ...",
-- "ROUND ...", etc). We use it to tell a genuine round START (HIDE, with its role-reveal black
-- screen) apart from entering an ALREADY-RUNNING round mid-way (ROUND), e.g. a Join-As-Seeker
-- convert: the reveal hold should only apply to the former.
local MatchTelemetry = ReplicatedStorage:WaitForChild("MatchTelemetry")

local folder = SoundService:WaitForChild("RoundMusic")
local musicGroup = SoundService:FindFirstChild("Music")  -- so round music obeys the Settings Music slider

local FADE_IN = 1.0    -- ease a new track in
local FADE_OUT = 1.0   -- ease the current track out (on round end or before the next track)
-- The round starts with a ~6s role-reveal BLACK SCREEN, under which DuringBlackScreen.Track1 plays
-- (handled by TimerClient). We hold the round music until that black screen has faded, so the two
-- don't overlap. REVEAL_HOLD(6) + the 0.5s fade-out ≈ 6.5s after the round starts.
local REVEAL_DELAY = 6.6
local ROUND_VOL_MULT = 0.52  -- round music sits at 52% of authored volume (was 0.65, lowered a further 20%)

local inRound = false
local generation = 0       -- bumped on every state change; cancels stale fades / handlers
local currentTrack = nil   -- the Sound currently playing
local fadeTween = nil

-- latest server-dictated round track state (from MusicSync). trackName=nil means silent.
local serverState = { trackName = nil, startServerTime = 0, length = 0 }

local function findTrack(name)
	if not name then return nil end
	local s = folder:FindFirstChild(name)
	return (s and s:IsA("Sound")) and s or nil
end

-- where in the track the whole server currently is, in seconds
local function sharedPosition()
	local elapsed = Workspace:GetServerTimeNow() - serverState.startServerTime
	if elapsed < 0 then elapsed = 0 end
	local len = serverState.length
	if len and len > 0 and elapsed > len then elapsed = len end
	return elapsed
end

local function cancelFade()
	if fadeTween then fadeTween:Cancel(); fadeTween = nil end
end

-- stop whatever's playing now (optionally fading first)
local function stopCurrent(fade)
	local track = currentTrack
	currentTrack = nil
	if not track then return end
	cancelFade()
	if fade and track.IsPlaying then
		local t = TweenService:Create(track, TweenInfo.new(FADE_OUT, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Volume = 0 })
		t.Completed:Connect(function() track:Stop() end)
		t:Play()
	else
		track:Stop()
	end
end

-- play the server's current round track, seeked to the shared position, fading up
local function playServerTrack()
	if not inRound then return end
	local track = findTrack(serverState.trackName)
	if not track then stopCurrent(false); return end
	stopCurrent(false)
	currentTrack = track
	if musicGroup then track.SoundGroup = musicGroup end
	local target = track:GetAttribute("BaseVolume")
	if target == nil then
		target = track.Volume > 0 and track.Volume or 0.5
		track:SetAttribute("BaseVolume", target)  -- remember the authored volume across fades
	end
	target = target * ROUND_VOL_MULT
	track.Looped = false
	track.Volume = 0
	track.TimePosition = math.min(sharedPosition(), math.max(0, (track.TimeLength or 0) - 0.05))
	track:Play()

	cancelFade()
	fadeTween = TweenService:Create(track, TweenInfo.new(FADE_IN, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Volume = target })
	fadeTween:Play()
end

-- true if the seek phase is already underway, i.e. we're ENTERING a round that's already running
-- (a mid-round join or a Join-As-Seeker convert) rather than starting one fresh from the lobby.
local function isSeekAlreadyUnderway()
	local v = MatchTelemetry.Value or ""
	return v:sub(1, 5) == "ROUND"
end

local function refresh()
	generation += 1  -- invalidate any in-flight fade / delayed start from the previous state
	if inRound then
		stopCurrent(false)  -- clear anything lingering
		if isSeekAlreadyUnderway() then
			-- Mid-round entrant (e.g. Join-As-Seeker convert): there is NO role-reveal black screen for
			-- them, and the song is already playing for everyone else. Start immediately, seeked to the
			-- shared position, so they drop in where the rest of the server is instead of sitting in
			-- silence for the reveal-hold duration.
			MusicSync:FireServer()  -- request the freshest shared state
			playServerTrack()
		else
			-- Genuine round start (HIDE): wait out the role-reveal black screen (DuringBlackScreen.Track1
			-- plays under it) before starting the round music, so they don't overlap. If the round ends
			-- during the wait, the generation check aborts the start. We seek to the shared position so
			-- even after this hold we're aligned with everyone else.
			local myGen = generation
			task.delay(REVEAL_DELAY, function()
				if myGen ~= generation then return end  -- state changed during the wait; abort
				if not inRound then return end
				MusicSync:FireServer()  -- request the freshest shared state
				playServerTrack()
			end)
		end
	else
		stopCurrent(true)   -- leaving the round: fade out and stop
	end
end

InRound.OnClientEvent:Connect(function(active)
	local nowIn = active and true or false
	if nowIn == inRound then return end  -- no change; don't restart the track
	inRound = nowIn
	refresh()
end)

-- server tells us the current round track + shared start. Update state; if we're in a round and the
-- track changed, switch to it (seeked to the shared position).
MusicSync.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" or payload.channel ~= "round" then return end
	local changed = (payload.trackName ~= serverState.trackName)
	serverState.trackName = payload.trackName
	serverState.startServerTime = payload.startServerTime or 0
	serverState.length = payload.length or 0
	if inRound then
		if serverState.trackName == nil then
			stopCurrent(true)
		elseif changed or not currentTrack then
			playServerTrack()
		end
	end
end)
