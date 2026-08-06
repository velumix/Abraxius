local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventDefinitions = {}

export type EventCategory = "Weather" | "Special" | "Interactive" | "Boost"

export type ResolverContext = {
	config: {[string]: any}?,
}

export type EventDefinition = {
	displayName: string | (context: ResolverContext) -> string,
	description: (string | (context: ResolverContext) -> string)?,
	icon: string | (context: ResolverContext) -> string,
	category: EventCategory,
	statusColor: string?,
	activeText: string?,
	inactiveText: string?,
	lightingPreset: string?,
	command: boolean?,
	isGlobal: boolean?,
	requiresRound: boolean?,
	requiredGameMode: string?,
	hidden: boolean?,
	silent: boolean?,
	hideMultiLabel: boolean?,
	channels: { string }?,
}

local definitions: {[string]: EventDefinition} = {
	-- Paint & Seek events, keyed by event name (must match a handler module under
	-- ServerScriptService.Services.EventService). Admin-triggered global host events.

	ColorSwap = {
		displayName = "Color Swap",
		description = "Every hider's colors keep scrambling!",
		icon = "",
		category = "Special",
	},

	PaintFloor = {
		displayName = "Paint Floor",
		description = "Rising paint floods the map - don't get caught!",
		icon = "",
		category = "Special",
		command = false,
	},

	PaintBucketEvent = {
		displayName = "Paint Buckets",
		description = "Evil paint buckets are chasing everyone!",
		icon = "",
		category = "Interactive",
		command = false,
	},

	PaintMutation = {
		displayName = "Paint Mutation",
		description = "Random mutations warp every player!",
		icon = "",
		category = "Special",
		command = false,
	},

	ChaosButton = {
		displayName = "Chaos Buttons",
		description = "Press a button... if you dare.",
		icon = "",
		category = "Interactive",
		command = false,
	},

	CoinRain = {
		displayName = "Coin Rain",
		description = "Coins are falling from the sky!",
		icon = "",
		category = "Boost",
	},


	SmallSize = {
		displayName = "Small Size",
		description = "All hiders shrink down, making them harder to catch!",
		icon = "rbxassetid://133795606153901",
		category = "Special",
	},

	SpeedBoost = {
		displayName = function(context)
			local multiplier = tonumber(context.config and context.config.multiplier) or 2
			return string.format("%gx Speed", multiplier)
		end,
		description = function(context)
			local multiplier = tonumber(context.config and context.config.multiplier) or 2
			return string.format("Everyone moves at %gx speed!", multiplier)
		end,
		icon = "rbxassetid://95446304116481",
		category = "Boost",
	},

	BoostLuck = {
		displayName = function(context)
			local multiplier = tonumber(context.config and context.config.multiplier) or 2
			return string.format("%dx Luck", multiplier)
		end,
		description = function(context)
			local multiplier = tonumber(context.config and context.config.multiplier) or 2
			return string.format("Everyone gets %dx luck!", multiplier)
		end,
		icon = function(context)
			local multiplier = tonumber(context.config and context.config.multiplier) or 2
			local BoostConfig = require(ReplicatedStorage.Config.BoostConfig)
			local boost = BoostConfig.fromMultiplier(multiplier)
			return boost and boost.image or ""
		end,
		category = "Boost",
		requiresRound = false,
	},

	Luck = {
		displayName = function(context)
			local multiplier = tonumber(context.config and context.config.multiplier) or 2
			return string.format("%dx Luck", multiplier)
		end,
		description = function(context)
			local multiplier = tonumber(context.config and context.config.multiplier) or 2
			return string.format("Everyone gets %dx luck!", multiplier)
		end,
		icon = function(context)
			local multiplier = tonumber(context.config and context.config.multiplier) or 2
			local BoostConfig = require(ReplicatedStorage.Config.BoostConfig)
			local boost = BoostConfig.fromMultiplier(multiplier)
			return boost and boost.image or ""
		end,
		category = "Boost",
		requiresRound = false,
	},

	PaintingBoss = {
		displayName = "Paint Boss",
		description = "Classic round: team up to defeat the Paint Boss and its minions to earn the Paintball Knife skin!",
		icon = "",
		category = "Special",
		requiredGameMode = "hideandseek",
	},

	HugeSize = {
		displayName = "Huge Size",
		description = "Everyone grows to giant size!",
		icon = "",
		category = "Special",
	},

}

function EventDefinitions.get(eventName: string): EventDefinition?
	return definitions[eventName]
end

function EventDefinitions.getIcon(eventName: string, config: {[string]: any}?): string
	local def = definitions[eventName]
	if not def then
		return "rbxassetid://15057690464"
	end

	local icon
	if typeof(def.icon) == "function" then
		icon = def.icon({ config = config })
	else
		icon = def.icon
	end

	if not icon or icon == "" then
		return "rbxassetid://15057690464"
	end

	return icon
end

function EventDefinitions.getDisplayName(eventName: string, config: {[string]: any}?): string
	local def = definitions[eventName]
	if not def then
		return eventName
	end

	if typeof(def.displayName) == "function" then
		return def.displayName({ config = config })
	end

	return def.displayName
end

function EventDefinitions.getDescription(eventName: string, config: {[string]: any}?): string?
	local def = definitions[eventName]
	if not def or not def.description then
		return nil
	end

	if typeof(def.description) == "function" then
		return def.description({ config = config })
	end

	return def.description
end

function EventDefinitions.getAll(): {[string]: EventDefinition}
	return definitions
end

function EventDefinitions.getByCategory(category: EventCategory): {[string]: EventDefinition}
	local result = {}
	for name, def in definitions do
		if def.category == category then
			result[name] = def
		end
	end
	return result
end

function EventDefinitions.getVisible(): {[string]: EventDefinition}
	local result = {}
	for name, def in definitions do
		if not def.hidden then
			result[name] = def
		end
	end
	return result
end

return EventDefinitions
