local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("MatchConfig"))
local MatchState = require(script.Parent:WaitForChild("MatchState"))
local MatchRemotes = require(script.Parent:WaitForChild("MatchRemotes"))
local BackKnife = require(ServerScriptService:WaitForChild("BackKnife"))
local MapManager = require(ServerScriptService:WaitForChild("MapManager"))

local CONFIG = MatchConfig.CONFIG
local ScreenFade = MatchRemotes.ScreenFade
local Blackout = MatchRemotes.Blackout
local RoleAnnounce = MatchRemotes.RoleAnnounce

local hiders = MatchState.hiders
local found = MatchState.found
local foundTime = MatchState.foundTime
local eliminating = MatchState.eliminating
local roles = MatchState.roles
local joinedAsSeeker = MatchState.joinedAsSeeker
local seekerOut = MatchState.seekerOut
local seekers = MatchState.seekers
local placing = MatchState.placing
local diedConns = MatchState.diedConns
local seekerCountActive = MatchState.seekerCountActive
local aliveHiderCount = MatchState.aliveHiderCount
local OfferJoinAsSeeker = MatchRemotes.OfferJoinAsSeeker
local ReviveRules = require(script.Parent:WaitForChild("ReviveRules"))

local SeekerConversion = {}

local deps = {}
function SeekerConversion.init(d)
	deps = d
end

function SeekerConversion.convert(player: Player): boolean
	if not player or not player.Parent then
		return false
	end

	if MatchState.current ~= "HIDE" and MatchState.current ~= "ROUND" then
		return false
	end
	if MatchState.seekerGone then
		return false
	end
	if roles[player] == "Seeker" then
		return false
	end
	if deps.isAfk(player) then
		return false
	end

	local Placement = deps.placement
	local Knife = deps.knife

	for i = #hiders, 1, -1 do
		if hiders[i] == player then
			table.remove(hiders, i)
		end
	end
	found[player] = nil
	foundTime[player] = nil
	eliminating[player] = nil

	roles[player] = "Seeker"
	joinedAsSeeker[player] = true
	seekerOut[player] = nil
	local alreadyListed = false
	for _, s in ipairs(seekers) do
		if s == player then
			alreadyListed = true
			break
		end
	end
	if not alreadyListed then
		table.insert(seekers, player)
	end
	if seekerCountActive() > 0 then
		deps.setSeekerGone(false)
	end

	placing[player] = true
	ScreenFade:FireClient(player, "in", { fadeTime = 0.2 })
	task.spawn(function()
		task.wait(0.25)

		local ready = Placement.waitUntilPlaceable(player, 8)
		local stillValid = ready and player.Parent ~= nil and (MatchState.current == "HIDE" or MatchState.current == "ROUND") and roles[player] == "Seeker"

		if not stillValid then
			placing[player] = nil
			if roles[player] == "Seeker" then
				roles[player] = nil
				joinedAsSeeker[player] = nil
				for i = #seekers, 1, -1 do
					if seekers[i] == player then
						table.remove(seekers, i)
					end
				end
			end
			Knife.clearKnife(player)
			deps.setInRound(player, false)
			BackKnife.setSuppressed(player, false)
			if seekerCountActive() == 0 then
				warn(
					string.format(
						"[SEEKERGONE-DIAG] convert-rollback set seekerGone=true | phase=%s | player=%s | #seekers=%d\n%s",
						tostring(MatchState.current),
						tostring(player and player.Name),
						#seekers,
						debug.traceback()
					)
				)
				deps.setSeekerGone(true)
			end
			deps.broadcastRoleMap()
			deps.broadcastHidersLeft()
			ScreenFade:FireClient(player, "out", { fadeTime = 0.35 })
			warn("[MatchManager] convert aborted for " .. player.Name .. " (player not placeable in time)")
			return
		end

		Placement.safeRestore(player)
		deps.setFrozen(player, false)
		Blackout:FireClient(player, false)
		BackKnife.setSuppressed(player, true)
		deps.setInRound(player, true)
		Placement.setDesiredPlacement(player, MapManager.getPlayerSpawnCFrame(), {
			valid = function(p)
				return (MatchState.current == "HIDE" or MatchState.current == "ROUND") and roles[p] == "Seeker" and not seekerOut[p]
			end,
			onPlaced = function(p)
				local c = p.Character
				local hum = c and c:FindFirstChildOfClass("Humanoid")
				if hum then
					hum.WalkSpeed = CONFIG.SEEKER_SPEED
				end
				Knife.giveKnife(p)
			end,
		})
		RoleAnnounce:FireClient(player, "Seeker")
		placing[player] = nil
		task.wait(0.15)
		ScreenFade:FireClient(player, "out", { fadeTime = 0.35 })
	end)

	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		table.insert(
			diedConns,
			hum.Died:Connect(function()
				if MatchState.current == "HIDE" or MatchState.current == "ROUND" then
					deps.markSeekerOut(player)
				end
			end)
		)
	end
	table.insert(
		diedConns,
		player.CharacterAdded:Connect(function()
			if MatchState.current == "HIDE" or MatchState.current == "ROUND" then
				deps.markSeekerOut(player)
				task.defer(function()
					Knife.clearKnife(player)
				end)
				deps.setInRound(player, false)
			end
		end)
	)

	deps.broadcastRoleMap()
	deps.broadcastHidersLeft()
	print("[MatchManager] " .. player.Name .. " joined as a seeker mid-round")
	return true
end

function SeekerConversion.offerJoin(player: Player)
	if not player or not player.Parent then
		return
	end
	if MatchState.current ~= "ROUND" then
		return
	end
	if MatchState.seekerGone then
		return
	end
	if deps.isOffered(player) then
		return
	end
	if deps.isAfk(player) then
		return
	end
	if roles[player] == "Seeker" then
		return
	end
	if aliveHiderCount() <= 0 then
		return
	end

	deps.markOffered(player)
	OfferJoinAsSeeker:FireClient(player)
	ReviveRules.sendReviveEligibility(player)
end

return SeekerConversion
