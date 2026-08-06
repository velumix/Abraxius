local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("MatchConfig"))
local MatchState = require(script.Parent:WaitForChild("MatchState"))
local SeekerChances = require(script.Parent:WaitForChild("SeekerChances"))

local roles = MatchState.roles
local found = MatchState.found
local hiders = MatchState.hiders
local seekers = MatchState.seekers
local kills = MatchState.kills
local foundOrder = MatchState.foundOrder
local foundTime = MatchState.foundTime
local joinedAsSeeker = MatchState.joinedAsSeeker
local reviveCount = MatchState.reviveCount
local sizePurchasedThisRound = MatchState.sizePurchasedThisRound
local seekerOut = MatchState.seekerOut
local hiderPlacedAt = MatchState.hiderPlacedAt
local placing = MatchState.placing
local lastSeekers = MatchState.lastSeekers
local pity = MatchState.pity

local RoleAssignment = {}

local deps = {}
function RoleAssignment.init(d)
	deps = d
end

local function collectRoundCandidates(timeout)
	local candidates = {}
	local waiting = {}
	local seen = {}

	for _, plr in ipairs(Players:GetPlayers()) do
		if not deps.isAfk(plr) then
			if deps.hasPlaceableCharacter(plr) then
				candidates[#candidates + 1] = plr
				seen[plr] = true
			else
				deps.placement.clearDesiredPlacement(plr)
				deps.placement.setLobbyRespawn(plr)
				deps.clearRoundScreens(plr)
				local ok = pcall(function()
					plr:LoadCharacter()
				end)
				if not ok then
					warn("[MatchManager] collectRoundCandidates: LoadCharacter failed for " .. plr.Name)
				end
				waiting[#waiting + 1] = plr
			end
		end
	end

	local deadline = os.clock() + (timeout or 5)
	while #waiting > 0 and os.clock() < deadline do
		for i = #waiting, 1, -1 do
			local plr = waiting[i]
			if not plr.Parent or deps.isAfk(plr) then
				table.remove(waiting, i)
			elseif deps.hasPlaceableCharacter(plr) then
				if not seen[plr] then
					candidates[#candidates + 1] = plr
					seen[plr] = true
				end
				table.remove(waiting, i)
			end
		end
		if #waiting > 0 then
			task.wait(0.15)
		end
	end

	for _, plr in ipairs(waiting) do
		if plr.Parent and not deps.isAfk(plr) then
			warn("[MatchManager] skipping " .. plr.Name .. " for role assignment: character did not become placeable")
			deps.setInRound(plr, false)
			deps.clearRoundScreens(plr)
			deps.placement.clearDesiredPlacement(plr)
			deps.placement.setLobbyRespawn(plr)
		end
	end

	return candidates
end

function RoleAssignment.assign(): { Player }
	table.clear(roles)
	table.clear(found)
	table.clear(hiders)
	table.clear(seekers)
	table.clear(kills)
	table.clear(foundOrder)
	deps.resetSentToLobby()
	table.clear(foundTime)
	table.clear(joinedAsSeeker)
	deps.resetOffered()
	table.clear(reviveCount)
	table.clear(sizePurchasedThisRound)
	table.clear(seekerOut)
	table.clear(hiderPlacedAt)
	for _, plr in ipairs(Players:GetPlayers()) do
		deps.placement.clearDesiredPlacement(plr)
		deps.applyCharacterScale(plr, 1)
	end
	table.clear(placing)
	deps.setRoundHadHiders(false)
	local list = collectRoundCandidates(5)
	if #list == 0 then
		return
	end

	for i = #list, 2, -1 do
		local j = math.random(i)
		list[i], list[j] = list[j], list[i]
	end
	local seekerCount = 1
	if #list <= 1 then
		seekerCount = 0
	end

	local chosenSeekers = {}
	local guaranteedFilled = 0
	local byUserId = {}
	for _, plr in ipairs(list) do
		byUserId[plr.UserId] = plr
	end
	local seekerQueue = deps.seekerQueue
	while guaranteedFilled < seekerCount and #seekerQueue > 0 do
		local uid = seekerQueue[1]
		local plr = byUserId[uid]
		if plr and not chosenSeekers[plr] then
			chosenSeekers[plr] = true
			guaranteedFilled += 1
			table.remove(seekerQueue, 1)
		elseif not plr then
			break
		else
			table.remove(seekerQueue, 1)
		end
	end

	for _, plr in ipairs(list) do
		SeekerChances.refreshBoost(plr)
	end
	local weight = {}
	for _, plr in ipairs(list) do
		weight[plr] = SeekerChances.weight(plr)
	end

	local pool = {}
	for _, plr in ipairs(list) do
		if not chosenSeekers[plr] then
			table.insert(pool, plr)
		end
	end
	for _ = 1, (seekerCount - guaranteedFilled) do
		if #pool == 0 then
			break
		end
		local total = 0
		for _, plr in ipairs(pool) do
			total += weight[plr]
		end
		local r = math.random() * total
		local acc, pickedIdx = 0, 1
		for idx, plr in ipairs(pool) do
			acc += weight[plr]
			if r <= acc then
				pickedIdx = idx
				break
			end
		end
		local picked = table.remove(pool, pickedIdx)
		chosenSeekers[picked] = true
	end

	local soloRole = deps.getSoloRole()
	if soloRole then
		chosenSeekers = {}
		if soloRole == "Seeker" then
			for _, plr in ipairs(list) do
				chosenSeekers[plr] = true
			end
		end
	end

	for _, plr in ipairs(list) do
		if chosenSeekers[plr] then
			roles[plr] = "Seeker"
			table.insert(seekers, plr)
			pity[plr] = 0
		else
			roles[plr] = "Hider"
			table.insert(hiders, plr)
			pity[plr] = (pity[plr] or 0) + 1
		end
	end

	table.clear(lastSeekers)
	for _, plr in ipairs(seekers) do
		lastSeekers[plr] = true
	end
end

return RoleAssignment
