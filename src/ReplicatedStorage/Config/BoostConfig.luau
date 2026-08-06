local BoostConfig = {}

BoostConfig.Channel = "main"
BoostConfig.CommandSource = "cmdr:BoostLuck"
BoostConfig.EventName = "Luck"
BoostConfig.EventSource = "event:Luck"
BoostConfig.DefaultType = "x2"
BoostConfig.DefaultMultiplier = 2
BoostConfig.DefaultDurationMinutes = 5

local LOW_ICON = "rbxassetid://132607390290853"
local MID_ICON = "rbxassetid://92170369025764"
local HIGH_ICON = "rbxassetid://71569734460168"

export type BoostType = {
	id: string,
	displayName: string,
	multiplier: number,
	image: string,
}

local types: { [string]: BoostType } = {
	x2 = {
		id = "x2",
		displayName = "2x Luck",
		multiplier = 2,
		image = LOW_ICON,
	},
	x4 = {
		id = "x4",
		displayName = "4x Luck",
		multiplier = 4,
		image = MID_ICON,
	},
	x6 = {
		id = "x6",
		displayName = "6x Luck",
		multiplier = 6,
		image = MID_ICON,
	},
	x8 = {
		id = "x8",
		displayName = "8x Luck",
		multiplier = 8,
		image = HIGH_ICON,
	},
}
BoostConfig.Types = types

function BoostConfig.parseMultiplier(value: any): number?
	if type(value) == "string" then
		local normalized = string.lower(string.match(value, "^%s*(.-)%s*$") or "")
		value = string.match(normalized, "^x(%d+)$") or normalized
	end

	local multiplier = tonumber(value)
	if not multiplier or multiplier ~= multiplier or multiplier <= 0 or multiplier % 1 ~= 0 then
		return nil
	end
	return multiplier
end

function BoostConfig.getImageForMultiplier(multiplier: number): string
	if multiplier <= 2 then
		return LOW_ICON
	elseif multiplier <= 6 then
		return MID_ICON
	end
	return HIGH_ICON
end

function BoostConfig.fromMultiplier(multiplier: number): BoostType?
	local parsed = BoostConfig.parseMultiplier(multiplier)
	if not parsed then
		return nil
	end

	return {
		id = tostring(parsed),
		displayName = string.format("%dx Luck", parsed),
		multiplier = parsed,
		image = BoostConfig.getImageForMultiplier(parsed),
	}
end

function BoostConfig.get(value: any?): BoostType?
	if value == nil or value == "" then
		value = BoostConfig.DefaultMultiplier
	end
	local multiplier = BoostConfig.parseMultiplier(value)
	return multiplier and BoostConfig.fromMultiplier(multiplier) or nil
end

function BoostConfig.listTypes()
	local types = {}
	for boostType in pairs(BoostConfig.Types) do
		table.insert(types, boostType)
	end
	table.sort(types, function(a, b)
		return BoostConfig.Types[a].multiplier < BoostConfig.Types[b].multiplier
	end)
	return types
end

return BoostConfig
