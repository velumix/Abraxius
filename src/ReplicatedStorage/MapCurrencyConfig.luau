local MapCurrencyConfig = {}

MapCurrencyConfig.FIREWORKS_ENABLED = false

MapCurrencyConfig.DEFAULT_SPLIT = { coins = 100, fireworks = 0 }

MapCurrencyConfig.SPLIT_BY_MAP = {}

function MapCurrencyConfig.getSplit(mapName)
	local split = (mapName and MapCurrencyConfig.SPLIT_BY_MAP[mapName]) or MapCurrencyConfig.DEFAULT_SPLIT
	local coins = math.max(0, split.coins or 0)
	local fireworks = math.max(0, split.fireworks or 0)
	if not MapCurrencyConfig.FIREWORKS_ENABLED then
		fireworks = 0
	end
	return coins, fireworks
end

function MapCurrencyConfig.rollType(mapName)
	local coins, fireworks = MapCurrencyConfig.getSplit(mapName)
	local total = coins + fireworks
	if total <= 0 then
		return "Coin"
	end
	if math.random() < (fireworks / total) then
		return "Firework"
	end
	return "Coin"
end

return MapCurrencyConfig
