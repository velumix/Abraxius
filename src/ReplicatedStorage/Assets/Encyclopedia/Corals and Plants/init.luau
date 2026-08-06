--!nocheck
local creatures = {}

for _, moduleScript in script:GetChildren() do
	local moduleData = require(moduleScript)
	local key = moduleData and moduleData._id or moduleScript.Name
	creatures[key] = moduleData
end

return creatures