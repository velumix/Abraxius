local MatchmakingService = game:GetService("MatchmakingService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("MatchConfig"))

local MatchmakingPublisher = {}

local BUCKET = MatchConfig.MATCHMAKING_TIME_BUCKET_SECONDS
local lastPhase = nil
local lastTimeBucket = nil

local function timeBucket(timeLeft)
	if type(timeLeft) ~= "number" then
		return -1
	end
	if timeLeft <= 0 then
		return 0
	end
	return math.ceil(timeLeft / BUCKET) * BUCKET
end

function MatchmakingPublisher.publish(phase, timeLeft, force)
	local bucket = timeBucket(timeLeft)
	if not force and phase == lastPhase and bucket == lastTimeBucket then
		return
	end
	local phaseChanged = force or phase ~= lastPhase
	local bucketChanged = force or bucket ~= lastTimeBucket
	if phaseChanged then
		local ok, success, errorMessage = pcall(function()
			return MatchmakingService:SetServerAttribute("MatchPhase", phase)
		end)
		if not ok or not success then
			warn("[MatchManager] failed to publish MatchPhase: " .. tostring(errorMessage or success))
		else
			lastPhase = phase
		end
	end
	if bucketChanged then
		local ok, success, errorMessage = pcall(function()
			return MatchmakingService:SetServerAttribute("TimeBucket", bucket)
		end)
		if not ok or not success then
			warn("[MatchManager] failed to publish TimeBucket: " .. tostring(errorMessage or success))
		else
			lastTimeBucket = bucket
		end
	end
end

function MatchmakingPublisher.initStudio()
	if RunService:IsStudio() then
		pcall(function()
			MatchmakingService:InitializeServerAttributesForStudio({
				MatchPhase = "WAITING",
				TimeBucket = -1,
			})
		end)
	end
end

return MatchmakingPublisher
