-- OutOfBoundsManager: anti-escape safety net.
--
-- Some maps have spots a player can exploit to clip OUTSIDE the playable shell (e.g. Map2's roof,
-- reached via a counter -> ceiling fan -> crouch/uncrouch physics eject), making themselves
-- unreachable so they auto-win as a hider. Rather than chase every individual exploit, the map
-- builder places an invisible trigger part named "OutOfBounds" over each escape surface (e.g. a thin
-- slab just above a roof). Any in-round player who touches one is instantly teleported back to a
-- valid spawn point.
--
-- DESIGN:
--   * Data-driven: we react to ANY BasePart named "OutOfBounds" inside the active map. The builder
--     decides where the danger zones are per map; this script needs zero per-map coordinates.
--   * The trigger parts should be CanCollide=false, CanTouch=true, Transparency=1, Anchored (set in
--     the template). Non-colliding so players pass INTO them (and get caught) instead of standing on
--     them; invisible so they're unseen.
--   * Only acts during a live round (HIDE or ROUND) and only on real player characters with a
--     Humanoid — thrown knives, coins, corpses brushing the trigger are ignored. A brief per-player
--     cooldown prevents repeat-fire while a body is still overlapping the trigger mid-teleport.
--   * Teleport reuses the same INSTANT-SNAP technique as MatchManager.pivot (anchor the HRP, PivotTo,
--     zero velocity, unanchor) so the player snaps to the spawn rather than gliding there, and lands
--     feet-on-marker via the spawn CFrame from MapManager.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapManager = require(ServerScriptService:WaitForChild("MapManager"))
local StudsConverter = require(ServerStorage:WaitForChild("StudsConverter"))

-- ===== TEMP SEEKER DEBUG (logs only; no behavior change) =====
-- Set false to silence. Logs the seeker's journey through the validation sweep / rescue path so we can
-- see WHERE and WHY a seeker ends up teleported mid-air. Remove this block once the bug is found.
local DEBUG_SEEKER = false
local function seekerRole(player)
	local mm = ServerScriptService:FindFirstChild("MatchManager")
	local api = mm and mm:FindFirstChild("GetRole")
	if not api then return nil end
	local ok, role = pcall(function() return api:Invoke(player) end)
	return ok and role or nil
end
local function isSeeker(player)
	return seekerRole(player) == "Seeker"
end
local function dbg(...)
	if DEBUG_SEEKER then print("[SeekerDebug]", ...) end
end
local function fmtCF(cf)
	if not cf then return "nil" end
	local p = cf.Position
	return string.format("%.1f, %.1f, %.1f", p.X, p.Y, p.Z)
end

-- MatchManager publishes the current phase as the first token of MatchTelemetry.Value.
-- The net is active during HIDE and ROUND (a hider could escape during either) but not in the
-- lobby/intermission, where players are legitimately outside any map footprint.
local MatchTelemetry = ReplicatedStorage:WaitForChild("MatchTelemetry")
local function isRoundActive()
	local v = MatchTelemetry.Value or ""
	return v:sub(1, 5) == "ROUND" or v:sub(1, 4) == "HIDE"
end

local RETELEPORT_COOLDOWN = 1.5   -- seconds before the same player can be re-caught (covers the
                                  -- frames where their body is still overlapping the trigger)
local lastTeleport = {}           -- [player] = os.clock() of their last out-of-bounds rescue
Players.PlayerRemoving:Connect(function(plr) lastTeleport[plr] = nil end)

-- Snap a player to a fresh spawn point, instantly (no client-interpolated glide). Mirrors the
-- teleport in MatchManager.pivot: anchor the HRP so the server CFrame is authoritative, PivotTo,
-- zero velocity so nothing flings them, then unanchor so they can move.
local function snapToSpawn(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (char and root) then return end
	local cframe = MapManager.getPlayerSpawnCFrame()
	if not cframe then
		if isSeeker(player) then dbg(player.Name, "snapToSpawn: getPlayerSpawnCFrame returned NIL (no spawn) -> not moved") end
		return
	end
	local _, size = char:GetBoundingBox()
	local targetCF = cframe + Vector3.new(0, size.Y / 2, 0)
	if isSeeker(player) then
		dbg(player.Name, "snapToSpawn: spawnCF=" .. fmtCF(cframe) .. " bboxY=" .. string.format("%.1f", size.Y) .. " -> targetCF=" .. fmtCF(targetCF))
	end
	local groundParams = RaycastParams.new()
	groundParams.FilterType = Enum.RaycastFilterType.Exclude
	groundParams.FilterDescendantsInstances = { char }
	groundParams.IgnoreWater = true
	if not Workspace:Raycast(targetCF.Position + Vector3.new(0, 2, 0), Vector3.new(0, -1000, 0), groundParams) then
		return
	end
	local wasAnchored = root.Anchored
	root.Anchored = true
	char:PivotTo(targetCF)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.Anchored = wasAnchored
end

-- ============================================================================
-- PERIODIC POSITION VALIDATION (the map-agnostic anti-glitch net)
-- ============================================================================
-- The hand-placed OutOfBounds touch parts above only catch escapes the BUILDER anticipated. They
-- miss the general case the crawl/pose exploit produces: a player squeezing their own collision body
-- THROUGH map geometry (network ownership means the client simulates its own character, so the server
-- accepts whatever position the squeeze produces). Rather than try to PREVENT every wedge geometry,
-- we periodically VALIDATE the outcome on the server and snap anyone who is no longer in a legal
-- position back to safety. This catches every clip regardless of how it was achieved.
--
-- THE ONLY failure test: OUT OF BOUNDS HORIZONTALLY -- the HRP is well OUTSIDE the map's horizontal
-- footprint. This catches a glitcher who escaped sideways past the shell. We do NOT test a below-ground
-- threshold: maps here are MULTI-LEVEL (Party Hall has floors at ~Y28 and ~Y55), so a single groundY
-- can't distinguish legitimate lower-floor / staircase movement from a fall -- it teleported players
-- just for taking the stairs. Genuine falls into the void are caught by a hand-placed OutOfBounds slab
-- beneath the lowest floor (precise per-map) instead of a global vertical guess.
--
-- WHY WE DON'T DO "EMBEDDED" OR "UNDER A CEILING" CHECKS: this is a HIDE-AND-SEEK game. Squeezing
-- into tight spots with geometry close overhead and pressed up against props (between two shelves,
-- under a table, inside a cupboard) is the CORE legitimate gameplay. Earlier versions also flagged
-- "a collidable part overlaps my center" and "a ceiling is above me with no ground straight below" --
-- but those signatures are indistinguishable from legitimate hiding, and they teleported players out
-- of perfectly good hiding spots (e.g. standing between two shelves). There is no clean geometric way
-- to tell "hiding under a table" from "clipped just under a thin floor", so we DELIBERATELY only act
-- on the unambiguous below/outside-the-map signal. Shallow clips that stay within the playable volume
-- are left to the hand-placed OutOfBounds trigger parts (which a builder can target precisely) and
-- aren't really exploitable anyway -- a seeker can still reach a player who's only a stud or two off.
--
-- DEBOUNCE: a failure must persist for STRIKE_LIMIT consecutive checks before we act, so a single
-- frame of physics jitter or a moving platform can't yank a legitimate player.
--
-- LAST-GOOD BREADCRUMB: every time a player passes the test we remember their position. On a rescue
-- we snap them back to that last-known-good spot (feels far less punishing than a full spawn reset and
-- simply UNDOES the glitch); if we never recorded one yet, we fall back to snapToSpawn.
local CHECK_INTERVAL = 0.5        -- seconds between validation sweeps (very cheap: a couple of compares)
local STRIKE_LIMIT = 2            -- consecutive failed checks before a rescue (debounce against jitter)
local FOOTPRINT_MARGIN = 60       -- studs outside the map footprint before "left the shell" trips

local strikes = {}               -- [player] = consecutive failed checks
local lastGood = {}              -- [player] = last validated-safe CFrame of their HRP
Players.PlayerRemoving:Connect(function(plr)
	strikes[plr] = nil
	lastGood[plr] = nil
end)

-- True if the HRP is outside the map's horizontal footprint (escaped past the shell).
-- We deliberately do NOT test a below-ground threshold: this game has MULTI-LEVEL maps (e.g. Party
-- Hall has a lower floor ~Y28 and an upper floor ~Y55), so a single groundY can't tell "walking the
-- lower floor / on the stairs" from "fell through" -- a below-ground check yanked players just for
-- using the stairs. Genuine falls into the void under a map are caught by a hand-placed OutOfBounds
-- trigger slab beneath the lowest floor (precise, per-map) instead. The footprint margin is generous
-- so a player pressed into the edge of the play area is never flagged; only a real sideways escape trips it.
local function isOutOfBounds(root, bounds)
	if not bounds then return false end
	local p = root.Position
	if math.abs(p.X - bounds.center.X) > bounds.halfX + FOOTPRINT_MARGIN then return true end
	if math.abs(p.Z - bounds.center.Z) > bounds.halfZ + FOOTPRINT_MARGIN then return true end
	return false
end

-- snap a player back to their last validated-safe spot; falls back to a fresh spawn if we have none.
local function rescue(player)
	local good = lastGood[player]
	if isSeeker(player) then
		dbg(player.Name, "RESCUE FIRED. using " .. (good and ("lastGood breadcrumb=" .. fmtCF(good)) or "NO breadcrumb -> snapToSpawn fallback"))
	end
	if good then
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if char and root then
			local rp = RaycastParams.new()
			rp.FilterType = Enum.RaycastFilterType.Exclude
			rp.FilterDescendantsInstances = { char }
			rp.IgnoreWater = true
			if Workspace:Raycast(good.Position + Vector3.new(0, 2, 0), Vector3.new(0, -1000, 0), rp) then
				local wasAnchored = root.Anchored
				root.Anchored = true
				char:PivotTo(good)
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
				root.Anchored = wasAnchored
				return
			end
		end
	end
	snapToSpawn(player)
end

-- the validation sweep: one pass over every in-round, on-map player.
local function validationSweep()
	if not isRoundActive() then return end
	local activeMap = MapManager.getActiveMap()
	if not activeMap then return end
	local bounds = MapManager.getBounds()
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		-- Only validate players who are actually on the map this round (converted to studs). This skips
		-- lobby players, spectators, and anyone mid-respawn -- they're legitimately outside the footprint.
		if root and hum and hum.Health > 0 and StudsConverter.isConverted(char) then
			local bad = isOutOfBounds(root, bounds)
			if DEBUG_SEEKER and isSeeker(player) then
				local b = bounds
				dbg(player.Name, string.format("sweep: pos=%s | bad=%s | bounds(center=%s halfX=%.0f halfZ=%.0f groundY=%s) | margin=%d | strikes=%d",
					fmtCF(root.CFrame), tostring(bad),
					b and string.format("%.0f,%.0f,%.0f", b.center.X, b.center.Y, b.center.Z) or "nil",
					b and b.halfX or -1, b and b.halfZ or -1, b and tostring(b.groundY) or "nil",
					FOOTPRINT_MARGIN, strikes[player] or 0))
			end
			if bad then
				strikes[player] = (strikes[player] or 0) + 1
				if isSeeker(player) then dbg(player.Name, "FLAGGED out-of-bounds, strike " .. strikes[player] .. "/" .. STRIKE_LIMIT) end
				if strikes[player] >= STRIKE_LIMIT then
					strikes[player] = 0
					rescue(player)
				end
			else
				-- clean: clear strikes and remember this as the last known-good position
				strikes[player] = 0
				if hum.FloorMaterial ~= Enum.Material.Air then
					lastGood[player] = root.CFrame
				end
			end
		else
			-- not a validatable on-map player right now: clear their transient state so a stale strike or
			-- breadcrumb from a previous round can't carry over.
			strikes[player] = nil
			lastGood[player] = nil
		end
	end
end

task.spawn(function()
	while true do
		task.wait(CHECK_INTERVAL)
		local ok, err = pcall(validationSweep)
		if not ok then
			warn("[OutOfBoundsManager] validation sweep error: " .. tostring(err))
		end
	end
end)

local BODY_PARTS = {
	HumanoidRootPart = true,
}

-- Resolve a touched part to an IN-ROUND player, or nil if it isn't one / shouldn't fire. Requires the
-- touched part to be an actual body part (see BODY_PARTS) AND a DIRECT child of the character model,
-- so accessory handles / tools / welded shells that hang off the character can't trigger a rescue.
local function playerFromTouch(hitPart)
	if not hitPart then return nil end
	if not BODY_PARTS[hitPart.Name] then return nil end       -- only real body parts, never hats/tools
	local model = hitPart.Parent
	if not (model and model:IsA("Model")) then return nil end  -- body parts sit directly under the character
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return nil end          -- ignore corpses / non-characters
	local player = Players:GetPlayerFromCharacter(model)
	if not player then return nil end                          -- ignore NPCs / stray parts
	return player
end

local function onTriggerTouched(hitPart)
	if not isRoundActive() then return end
	local player = playerFromTouch(hitPart)
	if not player then return end
	local now = os.clock()
	local last = lastTeleport[player]
	if last and (now - last) < RETELEPORT_COOLDOWN then return end
	lastTeleport[player] = now
	snapToSpawn(player)
end

-- Wire up every OutOfBounds trigger in the active map. The map is cloned into Workspace.ActiveMap
-- each round, so we (re)scan whenever a new ActiveMap appears, and also catch triggers added later.
local connectedTriggers = setmetatable({}, { __mode = "k" })  -- weak: entries vanish when parts do

local function tryConnect(inst)
	if inst:IsA("BasePart") and inst.Name == "OutOfBounds" and not connectedTriggers[inst] then
		connectedTriggers[inst] = true
		inst.Touched:Connect(onTriggerTouched)
	end
end

local function scanMap(map)
	if not map then return end
	for _, d in ipairs(map:GetDescendants()) do
		tryConnect(d)
	end
	-- catch triggers parented in after the initial scan
	map.DescendantAdded:Connect(tryConnect)
end

-- connect to the current ActiveMap if present, and to any future one
local function hookActiveMap()
	local active = Workspace:FindFirstChild("ActiveMap")
	if active then scanMap(active) end
end
Workspace.ChildAdded:Connect(function(child)
	if child.Name == "ActiveMap" then
		task.defer(scanMap, child)  -- defer so the clone's descendants are all in place
	end
end)
hookActiveMap()
