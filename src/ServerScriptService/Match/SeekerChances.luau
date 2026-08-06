local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("MatchConfig"))
local MatchState = require(script.Parent:WaitForChild("MatchState"))
local MatchRemotes = require(script.Parent:WaitForChild("MatchRemotes"))

local PITY = MatchConfig.PITY
local SEEKER_BOOST_ATTR = MatchConfig.SEEKER_BOOST_ATTR
local SeekerChance = MatchRemotes.SeekerChance

local pity = MatchState.pity
local lastSeekers = MatchState.lastSeekers
local ownsSeekerGamepass = MatchState.ownsSeekerGamepass

local SeekerChances = {}

local isAfkFn = function()
	return false
end

function SeekerChances.setIsAfk(fn)
	if type(fn) == "function" then
		isAfkFn = fn
	end
end

function SeekerChances.refreshBoost(plr)
	ownsSeekerGamepass[plr.UserId] = plr:GetAttribute(SEEKER_BOOST_ATTR) == true
end

function SeekerChances.weight(plr)
	local base = PITY.BASE_WEIGHT
	if ownsSeekerGamepass[plr.UserId] then
		base = base * PITY.GAMEPASS_MULT
	end
	local bonus = math.min((pity[plr] or 0) * PITY.PER_ROUND, PITY.MAX_PITY_BONUS)
	local w = base + bonus

	if lastSeekers[plr] then
		w = w * PITY.RECENT_SEEKER_MULT
	end
	return w
end

function SeekerChances.broadcast()
	local eligible = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		if not isAfkFn(plr) then
			table.insert(eligible, plr)
		end
	end
	local total = 0
	for _, plr in ipairs(eligible) do
		total += SeekerChances.weight(plr)
	end
	for _, plr in ipairs(eligible) do
		local pct = 0
		if total > 0 then
			pct = (SeekerChances.weight(plr) / total) * 100
		end
		SeekerChance:FireClient(plr, pct)
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		if isAfkFn(plr) then
			SeekerChance:FireClient(plr, 0)
		end
	end
end

return SeekerChances
