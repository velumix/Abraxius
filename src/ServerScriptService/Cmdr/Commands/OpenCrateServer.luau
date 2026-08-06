local ServerScriptService = game:GetService("ServerScriptService")

local UnboxManager = require(ServerScriptService.UnboxManager)

return function(context, crate: string, amount: number?)
	local player = context.Executor
	if not player then
		return "This command must be run by a player."
	end

	local requestedAmount = math.floor(tonumber(amount) or 1)
	local crateCount = math.clamp(requestedAmount, 1, 3)
	local opened = 0

	for _ = 1, crateCount do
		local ok = UnboxManager.openCrate(player, crate)
		if not ok then
			break
		end
		opened += 1
	end

	if opened == 0 then
		return `Failed to open "{crate}".`
	end

	local suffix = opened == 1 and "" or "s"
	return `Opening {opened} {crate}{suffix}...`
end
