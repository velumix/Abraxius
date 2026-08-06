-- @author Velumix
-- @version 0.0.1
--[=[
	@class TransferService
	@server
	Prompts Robux transfers and idempotently processes sender/receiver receipts.
]=]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local ServerScriptService = game:GetService("ServerScriptService")

local CommerceConfig = require(ReplicatedStorage.Config.CommerceConfig)
local Knit = require(ReplicatedStorage.Modules.Knit)
local NetGuard = require(ServerScriptService.NetGuard)
local Signal = require(ReplicatedStorage.Modules.Signal)
local Trove = require(ReplicatedStorage.Modules.Trove)

type TransferData = {
	Requests: { [string]: any },
	Receipts: { [string]: any },
}

type TransferHandler = (player: Player, receiptInfo: any, data: any) -> boolean?
type PromptTimes = { [Player]: number }
type ProcessingKeys = { [string]: boolean }

local TransferService = Knit.CreateService({
	Name = "TransferService",
	Client = {
		TransferProcessed = Knit.CreateSignal(),
	},
})

--[=[
	@prop TransferProcessed Signal
	@within TransferService
	Fires after a transfer receipt is durably processed.
]=]
TransferService.TransferProcessed = Signal.new()
TransferService._handlers = {} :: { [string]: TransferHandler }
TransferService._promptTimes = {} :: PromptTimes
TransferService._processing = {} :: ProcessingKeys
TransferService._trove = Trove.new()

NetGuard.Define("Transfer.Prompt", {
	RateLimit = { Requests = 1, Window = 3 },
	Validate = function(_player, receiverUserId, amount)
		return type(receiverUserId) == "number"
			and receiverUserId > 0
			and receiverUserId % 1 == 0
			and type(amount) == "number"
			and amount % 1 == 0,
			"INVALID_TRANSFER"
	end,
})

local function ensureTransferData(profile: { Data: any }): TransferData
	-- Profiles from older schema versions can legitimately be missing any of
	-- these tables. Keep this migration boundary dynamic, then return the
	-- normalized structure with a concrete type for all callers.
	local data = profile.Data :: any
	data.Commerce = data.Commerce or {}
	data.Commerce.Transfers = data.Commerce.Transfers or {}
	data.Commerce.Transfers.Requests = data.Commerce.Transfers.Requests or {}
	data.Commerce.Transfers.Receipts = data.Commerce.Transfers.Receipts or {}
	return data.Commerce.Transfers :: TransferData
end

--[=[
	Registers one optional durable receipt handler for a transfer role. The handler
	receives `(player, receiptInfo, data)` and must mutate only `data`.

	@param role "Sender" | "Receiver"
	@param handler (player: Player, receiptInfo: table, data: table) -> boolean?
]=]
function TransferService:RegisterHandler(role: "Sender" | "Receiver", handler: TransferHandler)
	assert(role == "Sender" or role == "Receiver", "role must be Sender or Receiver")
	assert(type(handler) == "function", "transfer handler must be a function")
	assert(not self._handlers[role], `{role} transfer handler already registered`)
	self._handlers[role] = handler
end

function TransferService:_processReceipt(role, receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ReceiptDecision.NotProcessedYet
	end

	local profile = self._dataService:WaitForProfile(player, CommerceConfig.ReceiptProfileWaitSeconds)
	if not profile then
		return Enum.ReceiptDecision.NotProcessedYet
	end

	local key = `{role}:{tostring(receiptInfo.TransferRequestId)}`
	local processing = self._processing :: ProcessingKeys
	if processing[key] then
		return Enum.ReceiptDecision.NotProcessedYet
	end

	processing[key] = true
	local committed, result = self._dataService:RunCommittedMutation(
		player,
		function(data, commitVersion): (boolean, any)
			local transfers = ensureTransferData({ Data = data })
			local existing = transfers.Receipts[key]
			if existing then
				existing.CommitVersion = commitVersion
				return true, { NewlyHandled = false }
			end

			local handler = self._handlers[role] :: TransferHandler?
			if handler and handler(player, receiptInfo, data) == false then
				return false, "HANDLER_DEFERRED"
			end
			transfers.Receipts[key] = {
				Role = role,
				TransferRequestId = tostring(receiptInfo.TransferRequestId),
				ProcessedAt = os.time(),
				CommitVersion = commitVersion,
			}
			return true, { NewlyHandled = true }
		end,
		CommerceConfig.ReceiptCommitTimeoutSeconds
	)

	if committed and result.NewlyHandled then
		self.TransferProcessed:Fire(player, role, receiptInfo)
		self.Client.TransferProcessed:Fire(player, role, tostring(receiptInfo.TransferRequestId))
	elseif not committed then
		warn(`{role} transfer receipt was deferred: {tostring(result)}`)
	end
	processing[key] = nil

	return if committed then Enum.ReceiptDecision.Processed else Enum.ReceiptDecision.NotProcessedYet
end

--[=[
	Validates and opens a server-authoritative Robux transfer prompt.

	@param sender Player
	@param receiverUserId number -- Positive integer user ID distinct from sender.
	@param amount number -- Integer amount within configured transfer limits.
	@return string? -- Transfer request ID on success.
	@return string? -- Stable validation or Roblox error message.
	@yields
]=]
function TransferService:PromptTransfer(sender: Player, receiverUserId, amount): (string?, string?)
	if not CommerceConfig.Transfers.Enabled then
		return nil, "Robux transfers are disabled"
	end
	if type(receiverUserId) ~= "number" or receiverUserId <= 0 or receiverUserId % 1 ~= 0 then
		return nil, "invalid receiver user ID"
	end
	if receiverUserId == sender.UserId then
		return nil, "sender and receiver must be different users"
	end
	if
		type(amount) ~= "number"
		or amount % 1 ~= 0
		or amount < CommerceConfig.Transfers.MinimumRobux
		or amount > CommerceConfig.Transfers.MaximumRobux
	then
		return nil, "invalid transfer amount"
	end

	local now = os.clock()
	local promptTimes = self._promptTimes :: PromptTimes
	if now - (promptTimes[sender] or 0) < 2 then
		return nil, "transfer prompt rate limited"
	end
	promptTimes[sender] = now

	local ok, transferRequestId = pcall(function()
		return MarketplaceService:PromptRobuxTransferAsync(sender, receiverUserId, amount)
	end)
	if not ok then
		return nil, tostring(transferRequestId)
	end

	local profile = self._dataService:GetProfile(sender)
	if profile then
		task.spawn(function()
			local committed, reason = self._dataService:RunCommittedMutation(sender, function(data)
				local transfers = ensureTransferData({ Data = data })
				transfers.Requests[tostring(transferRequestId)] = {
					ReceiverUserId = receiverUserId,
					Amount = amount,
					RequestedAt = os.time(),
				}
				return true
			end, CommerceConfig.ReceiptCommitTimeoutSeconds)
			if not committed then
				warn(`Transfer request audit commit failed: {tostring(reason)}`)
			end
		end)
	end
	return tostring(transferRequestId), nil
end

--[=[
	@client
	@within TransferService
	Guarded remote method that requests a transfer prompt for the caller.

	@param receiverUserId number
	@param amount number
	@return string? -- Transfer request ID.
	@return string? -- Rejection or validation reason.
]=]
function TransferService.Client:PromptTransfer(player: Player, receiverUserId, amount)
	local allowed, reason = NetGuard.Check(player, "Transfer.Prompt", receiverUserId, amount)
	if not allowed then
		return nil, reason
	end
	return self.Server:PromptTransfer(player, receiverUserId, amount)
end

function TransferService:KnitInit()
	self._dataService = Knit.GetService("PlayerDataService")
end

function TransferService:KnitStart()
	if not CommerceConfig.Transfers.Enabled then
		return
	end

	self._trove:Add(MarketplaceService:BindReceiptHandler(Enum.ReceiptType.RobuxTransferSender, function(receiptInfo)
		return self:_processReceipt("Sender", receiptInfo)
	end))
	self._trove:Add(MarketplaceService:BindReceiptHandler(Enum.ReceiptType.RobuxTransferReceiver, function(receiptInfo)
		return self:_processReceipt("Receiver", receiptInfo)
	end))
end

--[=[
	Disconnects bound transfer receipt handlers. Intended for test teardown.
]=]
function TransferService:Destroy()
	self._trove:Clean()
end

return TransferService
