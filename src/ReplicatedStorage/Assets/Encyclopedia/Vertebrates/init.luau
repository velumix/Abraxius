--!nocheck
local creatures = {}

for _, moduleScript in script:GetChildren() do

	local success, moduleData = pcall(function()
		return require(moduleScript)
	end)

	if not success then
		warn("Failed to load module:", moduleScript.Name, "Error:", moduleData)
		continue
	end

	local key = moduleData and moduleData._id or moduleScript.Name
	creatures[key] = moduleData
end

return creatures