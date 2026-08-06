--!strict
-- @author Velumix
-- @version 0.0.1
--[=[
	@class AnalyticsService
	@server
	Knit wrapper for funnel, economy, and custom events.
]=]
-- Roblox's types narrow customFields to nil when these run through pcall.
local Analytics: any = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AnalyticsConfig = require(ReplicatedStorage.Config.AnalyticsConfig)
local Knit = require(ReplicatedStorage.Modules.Knit)
local Trove = require(ReplicatedStorage.Modules.Trove)

type CustomFields = { [string]: string }
local canSend: () -> boolean
local sanitizeFields: (CustomFields?) -> CustomFields?

local Service = Knit.CreateService({ Name = "AnalyticsService", Client = {} })
Service._trove = Trove.new()
Service._logged = {} :: { [Player]: { [string]: { [number]: boolean } } }
Service._sessions = {} :: { [Player]: { [string]: { [string]: { [number]: boolean } } } }
Service._customLastLogged = {} :: { [Player]: { [string]: number } }

local function getDefinition(funnelName: string)
	return AnalyticsConfig.Funnels[funnelName]
end

local function validFiniteNumber(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

--[=[ Logs a custom event registered in AnalyticsConfig. ]=]
function Service:LogCustom(
	player: Player,
	eventName: string,
	value: number?,
	customFields: CustomFields?
): (boolean, string?)
	if player.Parent ~= Players then
		return false, "INVALID_PLAYER"
	end
	local definition = AnalyticsConfig.CustomEvents[eventName]
	if not definition or (value ~= nil and not validFiniteNumber(value)) then
		return false, "INVALID_CUSTOM_EVENT"
	end
	local cooldowns = self._customLastLogged[player]
	if not cooldowns then
		cooldowns = {}
		self._customLastLogged[player] = cooldowns
	end
	local now = os.clock()
	local lastLogged = cooldowns[eventName]
	if lastLogged and now - lastLogged < definition.CooldownSeconds then
		return false, "RATE_LIMITED"
	end
	cooldowns[eventName] = now
	if not canSend() then
		return true, nil
	end
	local ok, err = pcall(Analytics.LogCustomEvent, Analytics, player, eventName, value, sanitizeFields(customFields))
	if not ok then
		cooldowns[eventName] = lastLogged
		warn(`[AnalyticsService] Failed to log custom event {eventName}: {tostring(err)}`)
		return false, "ROBLOX_ERROR"
	end
	return true, nil
end

--[=[ Logs a finished economy transaction. Amount is always positive. ]=]
function Service:LogEconomy(
	player: Player,
	flow: "Source" | "Sink",
	currency: string,
	amount: number,
	balance: number,
	transactionType: string,
	itemSku: string?,
	customFields: CustomFields?
): (boolean, string?)
	if player.Parent ~= Players then
		return false, "INVALID_PLAYER"
	end
	if
		(flow ~= "Source" and flow ~= "Sink")
		or #currency == 0
		or #currency > 64
		or not validFiniteNumber(amount)
		or amount <= 0
		or not validFiniteNumber(balance)
		or balance < 0
		or #transactionType == 0
		or #transactionType > 64
		or (itemSku ~= nil and (#itemSku == 0 or #itemSku > 100))
	then
		return false, "INVALID_ECONOMY_EVENT"
	end
	if not canSend() then
		return true, nil
	end
	local flowType = if flow == "Source"
		then Enum.AnalyticsEconomyFlowType.Source
		else Enum.AnalyticsEconomyFlowType.Sink
	local ok, err = pcall(
		Analytics.LogEconomyEvent,
		Analytics,
		player,
		flowType,
		currency,
		amount,
		balance,
		transactionType,
		itemSku,
		sanitizeFields(customFields)
	)
	if not ok then
		warn(`[AnalyticsService] Failed to log {flow} {currency}: {tostring(err)}`)
		return false, "ROBLOX_ERROR"
	end
	return true, nil
end

local function getStepName(funnelName: string, step: number): string?
	local definition = getDefinition(funnelName)
	return if definition then definition.Steps[step] else nil
end

canSend = function(): boolean
	return AnalyticsConfig.Enabled and (AnalyticsConfig.LogInStudio or not RunService:IsStudio())
end

sanitizeFields = function(fields: CustomFields?): CustomFields?
	if fields == nil then
		return nil
	end
	local clean = {}
	for _, key in
		{
			Enum.AnalyticsCustomFieldKeys.CustomField01.Name,
			Enum.AnalyticsCustomFieldKeys.CustomField02.Name,
			Enum.AnalyticsCustomFieldKeys.CustomField03.Name,
		}
	do
		local value = fields[key]
		if type(value) == "string" and #value > 0 then
			clean[key] = string.sub(value, 1, 100)
		end
	end
	return if next(clean) then clean else nil
end

local function reportFailure(funnelName: string, step: number, err: any)
	warn(`[AnalyticsService] Failed to log {funnelName} step {step}: {tostring(err)}`)
end

--[=[ Logs an onboarding step. Ignores repeats in the same server. ]=]
function Service:LogStep(
	player: Player,
	funnelName: string,
	step: number,
	customFields: CustomFields?
): (boolean, string?)
	if player.Parent ~= Players then
		return false, "INVALID_PLAYER"
	end
	local definition = getDefinition(funnelName)
	local stepName = getStepName(funnelName, step)
	if not definition or not stepName or definition.Kind ~= "Onboarding" then
		return false, "INVALID_STEP"
	end
	local playerFunnels = self._logged[player]
	if not playerFunnels then
		playerFunnels = {}
		self._logged[player] = playerFunnels
	end
	local loggedSteps = playerFunnels[funnelName]
	if not loggedSteps then
		loggedSteps = {}
		playerFunnels[funnelName] = loggedSteps
	end
	if loggedSteps[step] then
		return false, "DUPLICATE_STEP"
	end
	loggedSteps[step] = true
	if canSend() then
		local ok, err = pcall(
			Analytics.LogOnboardingFunnelStepEvent,
			Analytics,
			player,
			step,
			stepName,
			sanitizeFields(customFields)
		)
		if not ok then
			loggedSteps[step] = nil
			reportFailure(funnelName, step, err)
			return false, "ROBLOX_ERROR"
		end
	end
	return true, nil
end

--[=[ Starts a recurring funnel. ]=]
function Service:StartSession(player: Player, funnelName: string): (string?, string?)
	local definition = getDefinition(funnelName)
	if player.Parent ~= Players then
		return nil, "INVALID_PLAYER"
	end
	if not definition or definition.Kind ~= "Recurring" then
		return nil, "INVALID_FUNNEL"
	end
	local sessionId = HttpService:GenerateGUID(false)
	local playerSessions = self._sessions[player]
	if not playerSessions then
		playerSessions = {}
		self._sessions[player] = playerSessions
	end
	local funnelSessions = playerSessions[funnelName]
	if not funnelSessions then
		funnelSessions = {}
		playerSessions[funnelName] = funnelSessions
	end
	funnelSessions[sessionId] = {}
	return sessionId, nil
end

function Service:EndSession(player: Player, funnelName: string, sessionId: string): boolean
	local playerSessions = self._sessions[player]
	local funnelSessions = playerSessions and playerSessions[funnelName]
	if not funnelSessions or not funnelSessions[sessionId] then
		return false
	end
	funnelSessions[sessionId] = nil
	return true
end

--[=[ Logs a recurring funnel step. ]=]
function Service:LogSessionStep(
	player: Player,
	funnelName: string,
	sessionId: string,
	step: number,
	customFields: CustomFields?
): (boolean, string?)
	local definition = getDefinition(funnelName)
	local stepName = getStepName(funnelName, step)
	local playerSessions = self._sessions[player]
	local funnelSessions = playerSessions and playerSessions[funnelName]
	local loggedSteps = funnelSessions and funnelSessions[sessionId]
	if not definition or definition.Kind ~= "Recurring" or not stepName or not loggedSteps then
		return false, "INVALID_SESSION_OR_STEP"
	end
	if loggedSteps[step] then
		return false, "DUPLICATE_STEP"
	end
	loggedSteps[step] = true
	if canSend() then
		local ok, err = pcall(
			Analytics.LogFunnelStepEvent,
			Analytics,
			player,
			funnelName,
			sessionId,
			step,
			stepName,
			sanitizeFields(customFields)
		)
		if not ok then
			loggedSteps[step] = nil
			reportFailure(funnelName, step, err)
			return false, "ROBLOX_ERROR"
		end
	end
	return true, nil
end

function Service:KnitStart()
	self._trove:Connect(Players.PlayerRemoving, function(player)
		self._logged[player] = nil
		self._sessions[player] = nil
		self._customLastLogged[player] = nil
	end)
end

function Service:Destroy()
	self._trove:Destroy()
	table.clear(self._logged)
	table.clear(self._sessions)
	table.clear(self._customLastLogged)
end

return Service
