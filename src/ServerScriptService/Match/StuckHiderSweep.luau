local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("MatchConfig"))
local MatchState = require(script.Parent:WaitForChild("MatchState"))
local MapManager = require(ServerScriptService:WaitForChild("MapManager"))

local CONFIG = MatchConfig.CONFIG

local hiders = MatchState.hiders
local found = MatchState.found
local roles = MatchState.roles
local hiderPlacedAt = MatchState.hiderPlacedAt

local StuckHiderSweep = {}

local deps = {}
function StuckHiderSweep.init(d)
	deps = d
end

local function lobbyDistance(pos)
	local best = math.huge
	local fixtures = Workspace:FindFirstChild("LobbyFixtures")
	if fixtures then
		for _, d in ipairs(fixtures:GetDescendants()) do
			if d:IsA("SpawnLocation") or d.Name == "LobbySpawn" then
				if d:IsA("BasePart") then
					local dx, dz = pos.X - d.Position.X, pos.Z - d.Position.Z
					best = math.min(best, math.sqrt(dx * dx + dz * dz))
				end
			end
		end
	end
	return best
end

function StuckHiderSweep.sweep(tag)
	if MatchState.seekerGone then
		return
	end
	local Placement = deps.placement
	for _, h in ipairs(hiders) do
		if not found[h] and h.Parent then
			local intent = Placement.desired[h]
			local inLobby = false
			local char = h.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if root and lobbyDistance(root.Position) < 60 then
				inLobby = true
			end
			local notOnMap
			if not intent then
				notOnMap = true
			elseif inLobby then
				notOnMap = true
			elseif (not intent.placed) and not intent.running then
				notOnMap = true
			else
				notOnMap = false
			end
			if notOnMap then
				warn("[MatchManager] HIDE SWEEP (" .. tostring(tag) .. "): " .. h.Name .. " not confirmed on map; forcing re-placement")
				local hider = h
				task.spawn(function()
					Placement.setDesiredPlacement(hider, MapManager.getPlayerSpawnCFrame(), {
						convert = true,
						valid = function(p)
							return (MatchState.current == "HIDE" or MatchState.current == "ROUND") and roles[p] == "Hider" and not found[p]
						end,
						onPlaced = function(p)
							local c = p.Character
							local hum = c and c:FindFirstChildOfClass("Humanoid")
							if hum then
								hum.WalkSpeed = CONFIG.HIDER_SPEED
							end
							hiderPlacedAt[p] = os.clock()
						end,
					})
				end)
			end
		end
	end
end

function StuckHiderSweep.startPeriodic()
	task.spawn(function()
		local elapsed = 0
		while MatchState.current == "HIDE" and not MatchState.seekerGone do
			task.wait(1)
			elapsed += 1
			if MatchState.current == "HIDE" and not MatchState.seekerGone and elapsed % 10 == 0 then
				StuckHiderSweep.sweep("periodic @" .. elapsed .. "s")
			end
		end
	end)
end

return StuckHiderSweep
