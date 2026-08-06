local Search = {}
Search.__index = Search

local function normalize(value)
	return tostring(value or ""):lower():gsub("[^%w]+", "")
end

local function nameMatches(query, text)
	local rawQuery = tostring(query or ""):lower()
	if rawQuery:gsub("%s+", "") == "" then
		return true
	end

	local rawText = tostring(text or ""):lower()
	if rawQuery:find("[^%w%s]") then
		return rawText:find(rawQuery, 1, true) ~= nil
	end

	return normalize(rawText):find(normalize(rawQuery), 1, true) ~= nil
end

function Search.new(managers)
	return setmetatable({
		query = "",
		killEffects = managers.killEffects,
		knifeSkins = managers.knifeSkins,
		titles = managers.titles,
	}, Search)
end

function Search:GetQuery()
	return self.query
end

function Search:SetQuery(query)
	self.query = tostring(query or "")
end

function Search:IsActive()
	return self.query:gsub("%s+", "") ~= ""
end

function Search:Matches(item, kind)
	local text
	if kind == "killeffect" then
		text = item.name or self.killEffects.effectName(item.id) or item.id or ""
	elseif kind == "pose" then
		text = item.name or item.id or ""
	elseif kind == "title" then
		text = self.titles.titleName(item.id) or item.name or item.id or ""
	else
		text = self.knifeSkins.displayName(item.name)
	end
	return nameMatches(self.query, text)
end

return Search
