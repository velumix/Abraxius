local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LimitedStockManager = {}

local STOCK_CAP = 2000
local STORE_NAME = "LimitedStock_v1"
local REFRESH_INTERVAL = 15

LimitedStockManager.STOCK_CAP = STOCK_CAP

local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local store = DataStoreService:GetDataStore(STORE_NAME)

local function ensureIntValue(name, default)
	local v = Remotes:FindFirstChild(name)
	if not v then
		v = Instance.new("IntValue")
		v.Name = name
		v.Value = default
		v.Parent = Remotes
	end
	return v
end

local function defineItem(displayName, key, stockValueName)
	local item = {
		displayName = displayName,
		key = key,
		stockValue = ensureIntValue(stockValueName, STOCK_CAP),
		capValue = ensureIntValue(stockValueName .. "Cap", STOCK_CAP),
		localSold = 0,
		dataStoreOk = true,
	}
	
	local function readSold()
		local ok, result = pcall(function()
			return store:GetAsync(item.key)
		end)
		if ok then
			if type(result) == "number" then
				return result
			end
			return 0
		end
		item.dataStoreOk = false
		return item.localSold
	end
	
	local function publish(sold)
		item.stockValue.Value = math.clamp(STOCK_CAP - sold, 0, STOCK_CAP)
	end
	
	function item.tryConsume()
		if not item.dataStoreOk then
			if item.localSold >= STOCK_CAP then
				return false
			end
			item.localSold += 1
			publish(item.localSold)
			return true
		end
		
		local claimed = false
		local ok, newSold = pcall(function()
			return store:UpdateAsync(item.key, function(existing)
				local sold = (type(existing) == "number") and existing or 0
				if sold >= STOCK_CAP then
					claimed = false
					return existing
				end
				claimed = true
				return sold + 1
			end)
		end)
		
		if not ok then
			item.dataStoreOk = false
			warn("[LimitedStockManager] " .. item.displayName .. " UpdateAsync failed; falling back to local stock. (" .. tostring(newSold) .. ")")
			if item.localSold >= STOCK_CAP then
				return false
			end
			item.localSold += 1
			publish(item.localSold)
			return true
		end
		
		if type(newSold) == "number" then
			publish(newSold)
		end
		return claimed
	end
	
	function item.inStock()
		return item.stockValue.Value > 0
	end
	
	function item.init()
		task.spawn(function()
			local sold = readSold()
			publish(sold)
			local remaining = math.clamp(STOCK_CAP - sold, 0, STOCK_CAP)
			print(string.format("[LimitedStockManager] %s stock resolved: %d/%d remaining", item.displayName, remaining, STOCK_CAP))
		end)
		task.spawn(function()
			while true do
				task.wait(REFRESH_INTERVAL)
				if item.dataStoreOk then
					publish(readSold())
				end
			end
		end)
	end
	
	return item
end

local scythe = defineItem("Vampire Scythe", "VampireScythe_sold", "VampireScytheStock")
local voidBlade = defineItem("Void Blade", "VoidBlade_sold", "VoidBladeStock")
local frozenKnife = defineItem("Frozen Knife", "FrozenKnife_sold", "FrozenKnifeStock")

function LimitedStockManager.tryConsumeStock()
	return scythe.tryConsume()
end
function LimitedStockManager.inStock()
	return scythe.inStock()
end

function LimitedStockManager.tryConsumeFrozenKnifeStock()
	return frozenKnife.tryConsume()
end
function LimitedStockManager.frozenKnifeInStock()
	return frozenKnife.inStock()
end

function LimitedStockManager.init()
	scythe.init()
	frozenKnife.init()
end

return LimitedStockManager
