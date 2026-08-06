local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PolicyService = game:GetService("PolicyService")
local HttpService = game:GetService("HttpService")


local Unify = require(ReplicatedStorage.Modules.Unify)
local Utility = require(ReplicatedStorage.Modules.Utility)
local TableUtil = require(ReplicatedStorage.Modules.TableUtil)

local LocalPlayerDataPrototype = {} 
local LocalPlayerData = {
	DefaultData = {
		Records = {},
		LimitRecords = {},
		ScheduledUpdates = {},
		GamepassesCheckedLocally = {},
		OwnedGampasses = {},
		GamepassOwnershipDetailing = {},
	},
	
	RateLimitRecords = { -- Need it when frequent access is sometimes needed but don't want to let it completely opn
		-- Time, Amount, Cooldown, Cooldown or wait for credits 
		["ReportInterfaceInteraction"] = {60, 10, 60, true}, -- 30 times per minute, 1 time every 3 seconds
	},
	
	CooldownRecords = {
	} 
} 

function LocalPlayerDataPrototype:GetPolicyInfo() 
	if self.PolicyInfo then 
		return self.PolicyInfo 
	end
	
	local Success, Result = pcall(function() 
		return PolicyService:GetPolicyInfoForPlayerAsync(self.Player)
	end) 


	if not Success then return end 
	
	self.PolicyInfo = Result	
	return Result
end


function LocalPlayerDataPrototype:RateLimit(Record) 
	local RateLimitRecord =  LocalPlayerData.RateLimitRecords[Record] 
	if not RateLimitRecord then 
		error   "Invalid cooldown record"
		return 
	end 

	local RateLimitRecordInstance = self.LimitRecords[Record] 
	if not RateLimitRecordInstance then  
		self.LimitRecords[Record] = {
			Credits = RateLimitRecord[2], 
			LastCheck = os.time(), 

		}

		RateLimitRecordInstance = self.LimitRecords[Record] 
	end

	if RateLimitRecordInstance.Locked then 
		if RateLimitRecordInstance.OpenOn - os.time() < 0 then 
			RateLimitRecordInstance.Locked = false 
			RateLimitRecordInstance.Credits = RateLimitRecord[2]
			return false 
		end

		return true 
	end

	local TimePassed = os.time() - RateLimitRecordInstance.LastCheck 
	RateLimitRecordInstance.Credits = math.min(RateLimitRecord[2], RateLimitRecordInstance.Credits+ ((TimePassed/ RateLimitRecord[1]) * RateLimitRecord[2]) )
	RateLimitRecordInstance.Credits -= 1 
	RateLimitRecordInstance.LastCheck = os.time()


	if RateLimitRecordInstance.Credits < 0 then 
		if RateLimitRecord[4] then 
			RateLimitRecordInstance.Credits = 0
			return true 
		end
		RateLimitRecordInstance.Locked = true 
		RateLimitRecordInstance.OpenOn = os.time() + RateLimitRecord[3] 
		return true 
	end
end

function LocalPlayerDataPrototype:Cooldown(Record : string, ManualDelay : any) 
	assert(Utility.AssertTypes(Record, "string")) 
	
	local IsReady, TimeRemaining  

	local RecordDuration =  LocalPlayerData.CooldownRecords[Record] 
	if not RecordDuration then 
		error   "Invalid cooldown record"
		return 
	end

	local LastAccessed = self.Records[Record] 
	if not LastAccessed then 
		IsReady = true 
		self.Records[Record] = os.time() + RecordDuration
	else 
		TimeRemaining = LastAccessed - os.time()

		if TimeRemaining  < 0 then 
			IsReady = true 
			self.Records[Record] = os.time() + RecordDuration
		end 
	end

	if ManualDelay then 
		self.Records[Record] = os.time() + ManualDelay
	end

	return IsReady, TimeRemaining
end

function LocalPlayerData:HandleNewCharacter()
	self.Alive = true 
	
	local Humanoid : Humanoid = self.Character:WaitForChild("Humanoid") 
	self.Humanoid = Humanoid 
	
	Humanoid.Died:Connect(function() 
		self.Alive = false
	end)
end

function LocalPlayerData:SetupAsync() 
	self.Character = self.Player.Character 
	self.Player.CharacterAdded:Connect(function(Character)
		self.Character = Character
		LocalPlayerData.HandleNewCharacter(self)
	end) 
	
	if self.Character then 
		LocalPlayerData.HandleNewCharacter(self)
	end
end



function LocalPlayerData.new(Player : Player) 
	local LocalData = setmetatable(Utility.Deepcopy(LocalPlayerData.DefaultData), {
		__index = LocalPlayerDataPrototype
	})
	
	LocalData.Player = Player :: Player
	LocalData.JoinedOn = Unify.GetServerTime()
	LocalData.CountedOn = Unify.GetServerTime() 
	LocalData.FunnelSessionId = HttpService:GenerateGUID()
	
	LocalPlayerData.SetupAsync(LocalData)
	
	return LocalData
end

return LocalPlayerData