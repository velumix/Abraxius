local Bucket = {}
Bucket.__index = Bucket

function Bucket.new(items)
	local self = setmetatable({}, Bucket) 
	self.pool = {} -- Initialize an empty pool 
	self.items = items 
	self.maxStackAttempts = 20
	self:Replenish()
	return self
end

function Bucket:Replenish() 
	local newPool = {} 
	for index, item in ipairs(self.items) do
		newPool[index] = item 
	end

	self.pool = newPool
end

function Bucket:GetRandom(min, max, exclude) 
	if not exclude then 
		return math.random(min, max)	
	end

	if min == max then
		return min 
	elseif max - min == 1 then
		return min == exclude and max or min
	end

	local result = math.random(min, max)
	if result == exclude then
		return result == max and max - 1 or result + 1 
	end

	return result
end
function Bucket:Next(conditionalFn) 
	return self:__Next(conditionalFn)
end

function Bucket:__IsBoolPcalled(thisConditonalFn, ...) 
	local param = {...}
	return pcall(function() 
		return thisConditonalFn(table.unpack(param)) 
	end)
end


function Bucket:__Next(conditionalFn, timesRan)
	if #self.pool == 0 then
		self:Replenish()
	end

	local randomIndex = Bucket:GetRandom(1, #self.pool, self.lastPoolIndex)
	local item = self.pool[randomIndex]
	self.lastPoolIndex = randomIndex

	if conditionalFn and not ((timesRan or 0) > self.maxStackAttempts) then 
		local shouldRemove = self:__IsBoolPcalled(conditionalFn, item)
		if shouldRemove or #self.pool == 1 then	
			table.remove(self.pool, randomIndex)
			return item
		else
			return self:__Next(conditionalFn, (timesRan or 0) +1)
		end
	end

	table.remove(self.pool, randomIndex) -- Remove the selected item
	return item
end

return Bucket