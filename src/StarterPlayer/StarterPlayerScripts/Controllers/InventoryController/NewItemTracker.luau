local NewItemTracker = {}
NewItemTracker.__index = NewItemTracker

local READY_DELAY = 3

local function collectOwnedKeys(state)
	local keys = {}
	for _, item in ipairs(state.items or {}) do
		keys[item.uid] = true
	end
	for _, collectionName in ipairs({ "killEffects", "poses", "titles" }) do
		local collection = state[collectionName]
		for _, item in ipairs((collection and collection.items) or {}) do
			if item.owned then
				keys[item.id] = true
			end
		end
	end
	return keys
end

function NewItemTracker.new()
	return setmetatable({
		startedAt = os.clock(),
		everSeen = {},
		newItems = {},
		sequence = 0,
	}, NewItemTracker)
end

function NewItemTracker:Update(state)
	local current = collectOwnedKeys(state)
	if os.clock() - self.startedAt > READY_DELAY then
		for key in pairs(current) do
			if not self.everSeen[key] then
				self.sequence += 1
				self.newItems[key] = self.sequence
			end
		end
	end
	for key in pairs(current) do
		self.everSeen[key] = true
	end
end

function NewItemTracker:GetSequence(key)
	return self.newItems[key]
end

function NewItemTracker:IsEmpty()
	return next(self.newItems) == nil
end

function NewItemTracker:Clear()
	table.clear(self.newItems)
end

return NewItemTracker
