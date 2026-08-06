local queue = {}
queue.__index = queue

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

function queue:sort()
	table.sort(self.list, function(a, b)
		return a.priority > b.priority
	end)
end

function queue:getQueueFromList(id)

	for i = 1, #self.list do
		local queuedTask = self.list[i]

		if queuedTask._id == id then
			return i, queuedTask
		end
	end
end

function queue:remove(id)
	local pos, tbl = self:getQueueFromList(id)
	table.remove(self.list, pos)
	self:sort()
end

function queue:add(func, args, priority)
	local id = HttpService:GenerateGUID()
	local tbl = {
		_id = id,
		priority = priority or 10,
		args = args,
		run = function()
			local success, err = pcall(function()
				return func(args and unpack(args, 1, #args) or nil)
			end)
			self:remove(id)
			
			if not success then
				print(("%s failed to run: %s"):format(id, err))
			end
		end
	}
	
	
	table.insert(self.list, tbl)
	self:sort()
	
	return id
end

function queue.new(interval)
	local self = setmetatable({
		list = {}
	}, queue)
	
	task.spawn(function()
		while true do
			if self.list[1] then
				self.list[1]:run()
			end

			task.wait(interval)
		end
	end)
	
	return self
end

return queue
