local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("MatchConfig"))
local MatchState = require(script.Parent:WaitForChild("MatchState"))
local MatchRemotes = require(script.Parent:WaitForChild("MatchRemotes"))
local ReviveRules = require(script.Parent:WaitForChild("ReviveRules"))
local Elimination = require(script.Parent:WaitForChild("Elimination"))
local BackKnife = require(ServerScriptService:WaitForChild("BackKnife"))
local MapManager = require(ServerScriptService:WaitForChild("MapManager"))

local CONFIG = MatchConfig.CONFIG
local ScreenFade = MatchRemotes.ScreenFade
local RoleAnnounce = MatchRemotes.RoleAnnounce

local reviveCount = MatchState.reviveCount
local found = MatchState.found
local foundTime = MatchState.foundTime
local eliminating = MatchState.eliminating
local foundOrder = MatchState.foundOrder
local hiders = MatchState.hiders
local roles = MatchState.roles
local diedConns = MatchState.diedConns
local hiderPlacedAt = MatchState.hiderPlacedAt

local Revive = {}

local deps = {}
function Revive.init(d)
	deps = d
end

function Revive.revive(player: Player): boolean
	if not ReviveRules.canRevive(player) then
		return false
	end
	local Placement = deps.placement

	reviveCount[player] = (reviveCount[player] or 0) + 1

	found[player] = nil
	foundTime[player] = nil
	eliminating[player] = nil
	for i = #foundOrder, 1, -1 do
		if foundOrder[i] == player.Name then
			table.remove(foundOrder, i)
		end
	end
	local inHiders = false
	for _, h in ipairs(hiders) do
		if h == player then
			inHiders = true
			break
		end
	end
	if not inHiders then
		table.insert(hiders, player)
	end

	deps.setInRound(player, true)
	BackKnife.setSuppressed(player, true)
	Placement.setLobbyRespawn(player)
	deps.broadcastHidersLeft()
	deps.broadcastRoleMap()

	ScreenFade:FireClient(player, "in", { message = "Reviving...", fadeTime = 0.2 })

	Placement.setDesiredPlacement(player, MapManager.getPlayerSpawnCFrame(), {
		convert = true,
		valid = function(p)
			return MatchState.current == "ROUND" and roles[p] == "Hider" and not found[p]
		end,
		onPlaced = function(p)
			local c = p.Character
			local hum = c and c:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.WalkSpeed = CONFIG.HIDER_SPEED
			end
			hiderPlacedAt[p] = os.clock()
			ScreenFade:FireClient(p, "out", { fadeTime = 0.35 })
		end,
	})
	RoleAnnounce:FireClient(player, "Hider")

	local function hookDeath()
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			table.insert(
				diedConns,
				hum.Died:Connect(function()
					if not (MatchState.current == "HIDE" or MatchState.current == "ROUND") then
						return
					end

					local placedAt = hiderPlacedAt[player]
					if placedAt and (os.clock() - placedAt) < 2 and not found[player] and Placement.desired[player] then
						local intent = Placement.desired[player]
						if intent then
							intent.placed = false
							intent.onPlacedFired = false
						end
						hiderPlacedAt[player] = nil
						return
					end
					Elimination.eliminate(player)
				end)
			)
		end
	end
	hookDeath()
	table.insert(
		diedConns,
		player.CharacterAdded:Connect(function()
			if MatchState.current == "HIDE" or MatchState.current == "ROUND" then
				task.wait(0.2)
				hookDeath()
			end
		end)
	)

	for _, plr in ipairs(Players:GetPlayers()) do
		ReviveRules.sendReviveEligibility(plr)
	end

	print("[MatchManager] " .. player.Name .. " REVIVED back into the round")
	return true
end

return Revive
