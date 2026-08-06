--!strict
local Update = {}

function Update.validateSource(inst: Instance?, payload: any, hashSource: (string) -> string, sourceDiff: (string, string) -> any): any
	if not inst or not inst:IsA("LuaSourceContainer") then return { error = "Script not found: " .. tostring(payload.path) } end
	if typeof(payload.source) ~= "string" then return { error = "source must be a string" } end
	local previous = inst.Source
	if payload.expectedHash and hashSource(previous) ~= payload.expectedHash then return { error = "Source changed since it was read", currentHash = hashSource(previous) } end
	return { instance = inst, previous = previous, diff = sourceDiff(previous, payload.source) }
end

return Update
