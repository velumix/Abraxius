-- Ensures the Reverse Race client remotes exist at server boot, independent of when the ReverseRace
-- mode module first loads. The orchestrator now waits for players before touching any mode, so the
-- mode (which lazily creates these) may not load for a while -- without this, the client controllers
-- infinite-yield on WaitForChild for these remotes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local gr = ReplicatedStorage:FindFirstChild("GameRemotes")
if not gr then
	gr = Instance.new("Folder")
	gr.Name = "GameRemotes"
	gr.Parent = ReplicatedStorage
end

for _, name in ipairs({
	"ReverseRaceHUD",
	"ReverseRaceRoll",
	"ReverseRaceLeaderboard",
	"OfferJoinReverseRace",
	"JoinReverseRaceResponse",
	"ReverseRaceViewport",
}) do
	if not gr:FindFirstChild(name) then
		local r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = gr
	end
end
