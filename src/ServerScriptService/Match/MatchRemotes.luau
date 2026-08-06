local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchRemotes = {}

local Remotes = ReplicatedStorage:FindFirstChild("GameRemotes")
if not Remotes then
	Remotes = Instance.new("Folder")
	Remotes.Name = "GameRemotes"
	Remotes.Parent = ReplicatedStorage
end

local function event(name)
	local r = Remotes:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = Remotes
	end
	return r
end

MatchRemotes.folder = Remotes

local EVENTS = {
	"StateChanged", "ChooseMapConfirm", "GlobalMapChoice", "MapQueueUpdate",
	"RoleAnnounce", "InRound", "RoundResult", "RoundSummary", "WinSequence",
	"SeekerChance", "RoleMap", "RequestRoleMap", "HidersLeft", "SeekerQueueUpdate",
	"Blackout", "ScreenFade", "LockBackpack", "OfferJoinAsSeeker", "JoinAsSeekerResponse",
	"RequestJoinOffer", "RevealHiders", "TrollNotify", "TrollBroadcast",
	"ReviveEligibility", "ReviveTestRequest", "KillReward", "CoinPurchase", "Spectate",
}

for _, name in ipairs(EVENTS) do
	MatchRemotes[name] = event(name)
end

local Telemetry = ReplicatedStorage:FindFirstChild("MatchTelemetry")
if not Telemetry then
	Telemetry = Instance.new("StringValue")
	Telemetry.Name = "MatchTelemetry"
	Telemetry.Parent = ReplicatedStorage
end
MatchRemotes.Telemetry = Telemetry

return MatchRemotes
