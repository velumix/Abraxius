-- @author Velumix
-- @version 0.0.1
--[=[
	@class CommerceConfig
	@server
	Declares products and game passes that this experience is allowed to prompt.
]=]
local CommerceConfig = {}

-- Add entries as [assetId] = "StableName". Product grant callbacks are
-- registered by stable name in CommerceService, keeping IDs out of game logic.
--[=[
	@prop DeveloperProducts {[number]: string}
	@within CommerceConfig
	Product ID to stable name.
]=]
CommerceConfig.DeveloperProducts = {}
--[=[
	@prop GamePasses {[number]: string}
	@within CommerceConfig
	Game-pass ID to stable name.
]=]
CommerceConfig.GamePasses = {}
--[=[
	@prop Assets {[number]: string}
	@within CommerceConfig
	Asset ID to stable name.
]=]
CommerceConfig.Assets = {}
--[=[
	@prop Bundles {[number]: string}
	@within CommerceConfig
	Bundle ID to stable name.
]=]
CommerceConfig.Bundles = {}
--[=[
	@prop Subscriptions {[string]: string}
	@within CommerceConfig
	Subscription ID to stable name.
]=]
CommerceConfig.Subscriptions = {}

--[=[
	@prop ReceiptProfileWaitSeconds number
	@within CommerceConfig
	Maximum profile-ready wait.
]=]
CommerceConfig.ReceiptProfileWaitSeconds = 10
--[=[
	@prop ReceiptCommitTimeoutSeconds number
	@within CommerceConfig
	Maximum durable receipt commit wait.
]=]
CommerceConfig.ReceiptCommitTimeoutSeconds = 20

-- Robux transfers are intentionally opt-in. They require Roblox Plus and are
-- separate from developer-product receipt processing.
--[=[
	@prop Transfers table
	@within CommerceConfig
	Transfer enablement and minimum/maximum amount limits.
]=]
CommerceConfig.Transfers = {
	Enabled = false,
	MinimumRobux = 10,
	MaximumRobux = 500,
}

return CommerceConfig
