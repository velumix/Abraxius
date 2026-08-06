-- TrollDebug (Studio-only testing helper) =========================================================
-- Lets you trigger any troll effect from the chat bar so you can SEE each one without a real round,
-- a real seeker, or a completed Robux purchase (purchases don't finish in Studio playtest).
--
-- SAFETY: this does NOTHING unless BOTH are true:
--   * the session is Studio (RunService:IsStudio()), AND
--   * the speaker's UserId is in ALLOWED below.
-- So even if it ships to the live game by accident it stays inert. Still, DELETE this script (and
-- TrollService.debugApplyTo) before a real release to be safe.
--
-- COMMANDS (type in the chat bar):
--   /troll <effect>            apply the effect to YOURSELF (to see the visual). e.g. /troll jumpscare
--   /troll <effect> me         same as above (explicit)
--   /troll <effect> all        apply to ALL active seekers (needs a live round with seekers)
--   /troll <effect> <name>     apply to the seeker whose name starts with <name>
--   /troll list                list the valid effect names
--   /trollself <effect>        alias for "/troll <effect> me"
--
-- effect is any TrollConfig key, case-insensitive: jumpscare, flashbang, freeze, trip, confusion.

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ===== gate =====
local ALLOWED = {
	[10755875748] = true,   -- jimbo_business (add more UserIds here if needed)
}

-- Hard stop outside Studio: the whole feature is inert in the live game.
if not RunService:IsStudio() then
	return
end

local TrollService = require(ServerScriptService:WaitForChild("TrollService"))
local TrollConfig = require(ReplicatedStorage:WaitForChild("TrollConfig"))

-- map a lowercase input to the real TrollConfig key (jumpscare -> "Jumpscare", etc.)
local function resolveKey(word)
	if not word then return nil end
	word = word:lower()
	for _, key in ipairs(TrollConfig.Order) do
		if key:lower() == word then return key end
	end
	return nil
end

local function listEffects()
	return table.concat(TrollConfig.Order, ", ")
end

-- find an active seeker by name prefix (only meaningful during a live round)
local function findSeekerByName(prefix)
	local mm = ServerScriptService:FindFirstChild("MatchManager")
	local api = mm and mm:FindFirstChild("GetActiveSeekers")
	if not api then return nil end
	local ok, list = pcall(function() return api:Invoke() end)
	if not ok or type(list) ~= "table" then return nil end
	prefix = prefix:lower()
	for _, s in ipairs(list) do
		if s.Name:lower():sub(1, #prefix) == prefix then return s end
	end
	return nil
end

local function handleCommand(speaker, message)
	if not ALLOWED[speaker.UserId] then return end
	if message:sub(1, 1) ~= "/" then return end

	local parts = {}
	for token in message:gmatch("%S+") do table.insert(parts, token) end
	local cmd = (parts[1] or ""):lower()

	if cmd == "/trollself" then
		local key = resolveKey(parts[2])
		if not key then warn("[TrollDebug] unknown effect. Valid: " .. listEffects()); return end
		TrollService.debugApplyTo(speaker, key, "DEBUG")
		print("[TrollDebug] applied " .. key .. " to yourself")
		return
	end

	if cmd ~= "/troll" then return end

	local arg1 = parts[2]
	if not arg1 then
		print("[TrollDebug] usage: /troll <effect> [me|all|<name>]   |   /troll list   |   effects: " .. listEffects())
		return
	end

	if arg1:lower() == "list" then
		print("[TrollDebug] effects: " .. listEffects())
		return
	end

	local key = resolveKey(arg1)
	if not key then
		warn("[TrollDebug] unknown effect '" .. tostring(arg1) .. "'. Valid: " .. listEffects())
		return
	end

	local target = (parts[3] or "me"):lower()

	if target == "me" then
		-- see the effect on yourself, no round/seeker needed
		TrollService.debugApplyTo(speaker, key, "DEBUG")
		print("[TrollDebug] applied " .. key .. " to yourself")
	elseif target == "all" then
		-- real path: troll every active seeker (needs a live round). buyer = you.
		local n = TrollService.apply(speaker, key, "all")
		print("[TrollDebug] applied " .. key .. " to ALL active seekers (count: " .. tostring(n) .. ")")
	else
		-- name prefix: find that active seeker and apply directly
		local seeker = findSeekerByName(parts[3])
		if seeker then
			TrollService.debugApplyTo(seeker, key, speaker.Name)
			print("[TrollDebug] applied " .. key .. " to " .. seeker.Name)
		else
			warn("[TrollDebug] no active seeker matching '" .. tostring(parts[3]) .. "' (needs a live round)")
		end
	end
end

Players.PlayerAdded:Connect(function(plr)
	plr.Chatted:Connect(function(msg) handleCommand(plr, msg) end)
end)
-- catch players already present (Studio play solo: you're in before this connects)
for _, plr in ipairs(Players:GetPlayers()) do
	plr.Chatted:Connect(function(msg) handleCommand(plr, msg) end)
end

print("[TrollDebug] ready (Studio only). Type /troll list in chat for effects.")
