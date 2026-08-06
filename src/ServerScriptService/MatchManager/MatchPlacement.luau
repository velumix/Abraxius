local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local StudsConverter = require(ServerStorage:WaitForChild("StudsConverter"))
local MapManager = require(script.Parent.Parent:WaitForChild("MapManager"))

local Placement = {}

local SPAWN_LIFT = 2

local function getLobbyTarget()
	local spawns = {}
	local fixtures = Workspace:FindFirstChild("LobbyFixtures")
	if fixtures then
		for _, d in ipairs(fixtures:GetDescendants()) do
			if d.Name == "LobbySpawn" and d:IsA("BasePart") then
				table.insert(spawns, d)
			end
		end
	end
	if #spawns == 0 then
		for _, d in ipairs(Workspace:GetDescendants()) do
			if d.Name == "LobbySpawn" and d:IsA("BasePart") then
				table.insert(spawns, d)
			end
		end
	end
	if #spawns > 0 then
		local spawn = spawns[math.random(1, #spawns)] -- pick a random pad
		local top = spawn.Position.Y + spawn.Size.Y / 2
		local hx = math.max(0, math.floor(spawn.Size.X / 2 - 4))
		local hz = math.max(0, math.floor(spawn.Size.Z / 2 - 4))
		return CFrame.new(spawn.Position.X + math.random(-hx, hx), top + 0.5, spawn.Position.Z + math.random(-hz, hz))
	end
	return CFrame.new(0, 50, 0)
end

local function mapTarget(i)
	return MapManager.getPlayerSpawnCFrame()
end

-- True if this character is already standing on (or right next to) a valid lobby pad. Used to avoid a
-- REDUNDANT settle-teleport: when a player resets/dies between rounds, Roblox already respawns them on
-- their RespawnLocation (a lobby pad, pinned by setLobbyRespawn), so the CharacterAdded settle-pivot
-- would yank an already-in-lobby player to a DIFFERENT random pad -- the visible "teleported to lobby
-- again even though I'm already in the lobby" bug. We only settle-pivot when they're genuinely NOT on
-- a pad (e.g. a reset that somehow landed them off the pads).
local function isOnLobbyPad(char)
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local pos = root.Position
	local pads = {}
	local fixtures = Workspace:FindFirstChild("LobbyFixtures")
	local searchRoot = fixtures or Workspace
	for _, d in ipairs(searchRoot:GetDescendants()) do
		if d.Name == "LobbySpawn" and d:IsA("BasePart") then
			pads[#pads + 1] = d
		end
	end
	for _, pad in ipairs(pads) do
		-- horizontal distance to the pad, allowing for the pad's own footprint + a generous margin, and a
		-- vertical band so a body resting on the pad counts (but one fallen far below does not).
		local dx = math.abs(pos.X - pad.Position.X) - pad.Size.X / 2
		local dz = math.abs(pos.Z - pad.Position.Z) - pad.Size.Z / 2
		local dy = math.abs(pos.Y - pad.Position.Y)
		if dx <= 6 and dz <= 6 and dy <= 12 then
			return true
		end
	end
	return false
end

-- ===== Canonical respawn control (Player.RespawnLocation) =====
-- Roblox's own round-based pattern controls WHERE a respawning body lands by setting each player's
-- RespawnLocation to a specific SpawnLocation, rather than letting the engine pick a random enabled
-- pad. With four enabled lobby pads, a mid-round respawn (a reset, or a streaming-fall death) used to
-- land on a RANDOM pad before our code could react — the root of the "respawned onto a lobby pad
-- mid-placement" races. Pinning RespawnLocation to ONE lobby pad makes every lobby respawn land in a
-- known spot, so our placement worker re-places map-bound players from a predictable location instead
-- of a scramble. Eligibility rules (from the SpawnLocation docs): RespawnLocation is honored only if
-- it's an enabled SpawnLocation in Workspace and is Neutral (or team-matched). Our pads are enabled +
-- neutral, so they qualify.
local function pickLobbySpawn()
	local spawns = {}
	local fixtures = Workspace:FindFirstChild("LobbyFixtures")
	if fixtures then
		for _, d in ipairs(fixtures:GetDescendants()) do
			if d:IsA("SpawnLocation") and d.Enabled then
				table.insert(spawns, d)
			end
		end
	end
	if #spawns == 0 then
		for _, d in ipairs(Workspace:GetDescendants()) do
			if d:IsA("SpawnLocation") and d.Enabled and d.Name == "LobbySpawn" then
				table.insert(spawns, d)
			end
		end
	end
	if #spawns == 0 then
		return nil
	end
	return spawns[math.random(1, #spawns)]
end

-- Pin a player's respawns to a lobby pad (so a reset / death lands them in the lobby deterministically,
-- not on a random enabled pad). Call this whenever a player SHOULD respawn into the lobby: on join, at
-- intermission, and on elimination. For map-bound players (hiders/seekers placed on the map) we still
-- rely on the placement worker, since the map has no SpawnLocation for RespawnLocation to target.
local function setLobbyRespawn(player)
	local spawn = pickLobbySpawn()
	if spawn then
		player.Neutral = true -- neutral so the neutral lobby pad is always eligible
		player.RespawnLocation = spawn
	end
end

-- forward declaration: pivot()'s retry wrapper calls waitUntilPlaceable, which is defined further
-- below (it needs isPlaceable). Declaring it here lets pivot reference it without reordering.
local waitUntilPlaceable

local function pivotOnce(player, cframe)
	if cframe == nil then
		return false, "nil target"
	end
	local char = player.Character
	local root = char and (char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart", 5))
	if char and root then
		-- STREAMING GUARD: this game runs with StreamingEnabled, so the destination may not exist on the
		-- player's client yet (streaming loads geometry around the CHARACTER, who is in the lobby — the
		-- far interior of an enclosed map like Map2 may never have streamed in). Teleporting a client
		-- into unstreamed geometry is the documented cause of players falling through the floor (then
		-- dying -> eliminated -> back in the lobby, looking like they "never teleported") or being held
		-- floating and settling on the streamed outer shell (the ROOF). RequestStreamAroundAsync asks the
		-- client to stream in the destination and yields until it has (or the timeout passes), so by the
		-- time we snap them there the floor genuinely exists on their client. pcall: it can error if the
		-- player is leaving. This must run BEFORE the unanchor below — it yields, and a position-Locked
		-- hider must stay locked until the moment we actually move them.
		-- HANG-PROOF STREAMING GUARD: RequestStreamAroundAsync is supposed to honor its timeout, but a
		-- live-server log showed the round loop freezing FOREVER at exactly this kind of engine yield
		-- (last print "hiders hiding", then 4+ hours of silence, zero errors — a hung yield, not a crash).
		-- pcall does NOT bound a yield: if the engine call never returns, every caller of pivot() —
		-- including the MAIN ROUND LOOP — freezes for the rest of the server's life. So the request runs
		-- on a SIDE thread and we wait on a completion flag with a hard deadline: pivot() is GUARANTEED
		-- to proceed within ~7s no matter what the engine call does. (A timed-out client simply gets the
		-- snap without pre-streaming; StreamingIntegrity / the recovery paths cover them.)
		local streamed = false
		task.spawn(function()
			pcall(function()
				-- Request a generous radius (was 15 — barely the player's own footprint). 15 studs covers
				-- almost none of the surrounding floor, so the pre-stream often "completed" having loaded
				-- too little, OR (with PauseOutsideLoadedArea integrity) the body still arrived faster than
				-- the real play area streamed and got PAUSED in place — the stuck-hider symptom. Asking for a
				-- larger radius around the destination gives the client a real chance to load the actual
				-- ground + nearby geometry before we snap them, so the stream genuinely confirms instead of
				-- timing out, and the body lands on loaded floor rather than pausing.
				player:RequestStreamAroundAsync(cframe.Position, 64)
			end)
			streamed = true
		end)
		local streamDeadline = os.clock() + 7
		while not streamed and os.clock() < streamDeadline do
			task.wait(0.1)
		end
		-- Did the pre-stream actually FINISH, or did we hit the 7s deadline and proceed anyway? This is
		-- threaded out to the caller as `streamConfirmed`. A timed-out stream means we moved the body but
		-- the destination geometry may STILL not exist on the client — with StreamingIntegrity that body
		-- is PAUSED at the target, not falling (so no death fires) but also not truly "there." The caller
		-- uses this to refuse marking the placement CONFIRMED, so the worker keeps retrying until a stream
		-- genuinely completes — closing the "placed=true but the hider is desynced/paused, no ForceField,
		-- nothing re-checks" gap. (The body is still moved each attempt, so they're never left in the lobby.)
		local streamConfirmed = streamed
		-- the request yields, so re-validate: the character may have died/respawned/left meanwhile.
		-- THE SWAPPED-CHARACTER RACE: a fresh respawn (at a lobby SpawnLocation, hence the ForceField)
		-- can replace the body we captured at the top of this call DURING the streaming yield above. If
		-- we proceeded we'd PivotTo the old, about-to-be-discarded body while the live one stays in the
		-- lobby — the player looks un-teleported (and keeps the spawn ForceField). Returning false here
		-- hands control back to pivot()'s retry wrapper, which re-resolves player.Character and tries
		-- again against the NEW body. (Previously every caller treated this false as terminal.)
		if not (player.Parent and char.Parent and root.Parent and player.Character == char) then
			return false, "character swapped/removed during stream wait"
		end
		for _, p in ipairs(char:GetChildren()) do
			if p:IsA("BasePart") and p.Anchored then
				p.Anchored = false
			end
		end
		local _, size = char:GetBoundingBox()
		local targetCF = cframe + Vector3.new(0, size.Y / 2, 0)

		-- INSTANT teleport (no client-interpolated "drag"). A player's own character is network-OWNED by
		-- their client, so a bare server-side PivotTo is treated as a target the client smoothly
		-- reconciles toward — the body visibly slides through the air to the destination and can snag on
		-- geometry (e.g. the roof) on the way. Anchoring the HumanoidRootPart for the move makes the
		-- server's CFrame authoritative so it SNAPS instantly; we unanchor again immediately so the
		-- player can walk. We also zero the assembly velocity so leftover momentum doesn't fling the body
		-- after it lands. PivotTo moves the whole rig rigidly (the documented, non-deprecated method;
		-- unlike moving the HRP alone it doesn't break ragdoll/joint systems).
		local groundParams = RaycastParams.new()
		groundParams.FilterType = Enum.RaycastFilterType.Exclude
		groundParams.FilterDescendantsInstances = { char }
		groundParams.IgnoreWater = true
		if not Workspace:Raycast(targetCF.Position + Vector3.new(0, 2, 0), Vector3.new(0, -1000, 0), groundParams) then
			return false, "target over void; refusing teleport"
		end
		local wasAnchored = root.Anchored
		root.Anchored = true
		char:PivotTo(targetCF)
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		root.Anchored = wasAnchored -- normally false, so the player can move immediately after the snap
		if player.Character ~= char then
			return false, "character swapped right after pivot"
		end
		-- third return: whether the destination was CONFIRMED streamed before we moved them. true = safe
		-- to mark the placement confirmed; false = body was moved but the stream timed out, so the caller
		-- should keep retrying until a future attempt confirms (the body isn't stranded meanwhile).
		return true, nil, streamConfirmed
	end
	return false, (char and "no HumanoidRootPart after wait" or "no character")
end

local function pivot(player, cframe)
	for attempt = 1, 4 do
		if pivotOnce(player, cframe) then
			return true
		end
		if not (player and player.Parent) then
			return false
		end
		-- pivotOnce failed (no body yet, or the character was swapped under us). Wait for the current
		-- character to become placeable again, then retry against whatever body is live now.
		waitUntilPlaceable(player, 4)
	end
	return false
end

local function setHumanoidStateEnabledSafe(humanoid, state, enabled)
	pcall(function()
		humanoid:SetStateEnabled(state, enabled)
	end)
end

local function safeRestore(player)
	local char = player.Character
	if char and StudsConverter.isConverted(char) then
		pcall(StudsConverter.restore, char)
	end

	-- Fully reset any pose/shift-lock humanoid state before teleporting back to the lobby.
	-- Without this, disabled states / PlatformStand / AutoRotate from poses or mobile shift lock
	-- can survive the round-end teleport and cause the character to float after jumping.
	char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.PlatformStand = false
		hum.AutoRotate = true
		hum.CameraOffset = Vector3.zero
		for _, state in ipairs(Enum.HumanoidStateType:GetEnumItems()) do
			-- None is an unusable sentinel, not a state SetStateEnabled accepts on live humanoids.
			if state ~= Enum.HumanoidStateType.None then
				setHumanoidStateEnabledSafe(hum, state, true)
			end
		end
	end
	if char then
		local animate = char:FindFirstChild("Animate")
		if animate then
			animate.Disabled = false
		end
		for _, name in ipairs({ "HumanoidRootPart", "UpperTorso", "LowerTorso", "Torso", "Head" }) do
			local part = char:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				part.CanCollide = true
			end
		end
	end
end

local function isPlaceable(player)
	if not player or not player.Parent then
		return false
	end
	local char = player.Character
	if not char or not char.Parent then
		return false
	end
	local root = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	return root ~= nil and hum ~= nil and hum.Health > 0
end

-- Wait until the player is placeable (see isPlaceable) or the timeout elapses. Returns true if they
-- became ready. Used to gate a mid-round conversion so we only proceed once the player is fully
-- loaded/respawned, rather than retry-teleporting a not-yet-ready character.
-- (declared local above so pivot() can call it; this assigns the body.)
function waitUntilPlaceable(player, timeout)
	local deadline = os.clock() + (timeout or 8)
	while os.clock() < deadline do
		if isPlaceable(player) then
			return true
		end
		if not player or not player.Parent then
			return false
		end
		task.wait(0.15)
	end
	return isPlaceable(player)
end

local function safeConvert(player)
	local char = player.Character
	if char and not StudsConverter.isConverted(char) then
		pcall(StudsConverter.convert, char)
	end
end

local desired = {} -- [player] = intent { cf, convert, valid, onPlaced, placed, running }

local function clearDesiredPlacement(player)
	desired[player] = nil
end

local function runPlacement(player)
	local intent = desired[player]
	if not intent or intent.placed or intent.running then
		return
	end
	intent.running = true
	task.spawn(function()
		-- PERSISTENT worker: keep trying for as long as the intent is still current and valid. The old
		-- 10-attempt cap turned any transient failure streak (laggy avatar load, repeated respawn swaps,
		-- a slow stream request) into a PERMANENT stranding: after the 10th failure nothing retried
		-- unless the player happened to respawn, so a hider could stand in the lobby for the whole round
		-- (live log: "PLACE: failed to place <name> after retries"). The intent system already self-
		-- limits — valid() clears the intent when they're eliminated/converted/the round ends, and
		-- clearDesiredPlacement at round end kills it — so retrying until then is safe and bounded.
		local attempt = 0
		local lastReason = nil
		-- How many times we'll re-try purely to get a CONFIRMED pre-stream before accepting an
		-- unconfirmed-but-moved placement. The body is at the target on every attempt (never stranded);
		-- this only governs how long we hold out for a clean stream. After the cap we trust the move and
		-- let StreamingIntegrity (PauseOutsideLoadedArea) reconcile the client when geometry finishes
		-- loading.
		--
		-- LIVE-LOG FIX (the real "stuck hider" cause): RequestStreamAroundAsync was timing out for many
		-- players, so streamConfirmed came back false EVERY attempt and the worker looped on "placed but
		-- stream not confirmed (client may be paused); retrying to confirm" — sometimes for minutes (see
		-- SofijaSut2016 / Rtpbecon in the live log). The body WAS on the map server-side, but each re-pivot
		-- re-triggered StreamingIntegrity's PauseOutsideLoadedArea, freezing the client in place (the
		-- 49,856 "Move called, but player currently has no humanoid" client warnings). With the OLD value
		-- of 5 plus a backoff that climbed to 2s, the trust-the-move escape hatch took far too long — and
		-- the periodic HIDE sweep made it worse by re-registering a fresh intent (resetting this counter to
		-- 0) before it could ever reach 5. PauseOutsideLoadedArea ALREADY prevents fall-through on its own
		-- (a paused body doesn't fall), so holding placed=false waiting for a confirm is both unnecessary
		-- for safety and the direct cause of the stuck state. Dropping to 2 quick tries (with the tight
		-- backoff below) gives a clean stream a brief chance in the common case, then trusts the move so
		-- the hider is marked placed within ~1-2s and the client reconciles via integrity-pause.
		local STREAM_CONFIRM_RETRIES = 2
		local streamRetries = 0
		while true do
			attempt += 1
			if desired[player] ~= intent then
				break
			end
			if not (player and player.Parent) then
				break
			end
			if intent.valid and not intent.valid(player) then
				desired[player] = nil
				break
			end
			if waitUntilPlaceable(player, 5) then
				if desired[player] ~= intent then
					break
				end
				if intent.valid and not intent.valid(player) then
					desired[player] = nil
					break
				end
				if intent.convert then
					safeConvert(player)
				end
				if desired[player] ~= intent then
					break
				end
				if intent.valid and not intent.valid(player) then
					desired[player] = nil
					break
				end
				local ok, reason, streamConfirmed = pivotOnce(player, intent.cf)
				if ok then
					local char = player.Character
					if char then
						for _, ff in ipairs(char:GetChildren()) do
							if ff:IsA("ForceField") then
								ff:Destroy()
							end
						end
					end
					if intent.onPlaced and not intent.onPlacedFired then
						intent.onPlacedFired = true
						task.spawn(intent.onPlaced, player)
					end
					if streamConfirmed then
						intent.placed = true
						break
					else
						streamRetries += 1
						if streamRetries >= STREAM_CONFIRM_RETRIES then
							-- Held out long enough for a confirmed stream and didn't get one. The body IS
							-- at the target; accept the placement so we don't re-pivot forever. The engine's
							-- PauseOutsideLoadedArea integrity mode keeps the client from falling and snaps it
							-- into place once streaming catches up. Marking placed here is safe precisely
							-- because the move already happened on the server.
							warn(
								"[MatchManager] PLACE: "
									.. player.Name
									.. " placed without confirmed stream after "
									.. streamRetries
									.. " tries; trusting the move (integrity-pause will reconcile)"
							)
							intent.placed = true
							break
						end
						lastReason = "placed but stream not confirmed (client may be paused); retrying to confirm"
					end
				else
					lastReason = reason or "pivot failed"
				end
			else
				lastReason = "character never became placeable"
			end
			-- diagnostics: warn at the old threshold (so existing log greps still match) and then
			-- periodically while it keeps failing, INCLUDING the last failure reason so a live log
			-- actually says why. The worker does NOT give up — it keeps retrying until the intent is
			-- fulfilled, replaced, or invalidated.
			-- Log on the first few failures (not only at attempt 10) so EVERY stranded hider shows up in
			-- the live log, then periodically. Previously only attempt 10 / every-30 logged, so when 3 hiders
			-- were stranded at slightly different attempt counts only one happened to be on attempt 10 at
			-- log-read time — which is why a 3-hider failure only ever showed 1 logged line.
			if attempt <= 3 or attempt == 10 or attempt % 30 == 0 then
				warn(
					"[MatchManager] PLACE: failed to place "
						.. player.Name
						.. " after retries (attempt "
						.. attempt
						.. ", last: "
						.. tostring(lastReason)
						.. "); still retrying"
				)
			end
			task.wait(math.min(0.2 * attempt, 0.5))
		end
		intent.running = false
	end)
end

local function setDesiredPlacement(player, cf, opts)
	opts = opts or {}
	if cf then
		cf = cf + Vector3.new(0, SPAWN_LIFT, 0)
	end
	desired[player] = {
		cf = cf,
		convert = opts.convert,
		valid = opts.valid,
		onPlaced = opts.onPlaced,
		placed = false,
		running = false,
	}
	runPlacement(player)
end

Placement.getLobbyTarget = getLobbyTarget
Placement.mapTarget = mapTarget
Placement.isOnLobbyPad = isOnLobbyPad
Placement.setLobbyRespawn = setLobbyRespawn
Placement.pivot = pivot
Placement.safeRestore = safeRestore
Placement.safeConvert = safeConvert
Placement.waitUntilPlaceable = waitUntilPlaceable
Placement.clearDesiredPlacement = clearDesiredPlacement
Placement.runPlacement = runPlacement
Placement.setDesiredPlacement = setDesiredPlacement
Placement.desired = desired

return Placement
