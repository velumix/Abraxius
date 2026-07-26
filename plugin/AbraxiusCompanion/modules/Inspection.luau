--!strict
local Inspection = {}

function Inspection.selection(Selection: Selection, instanceInfo: (Instance) -> any): any
	local out = {}
	for _, inst in ipairs(Selection:Get()) do table.insert(out, instanceInfo(inst)) end
	return { ok = true, selection = out }
end

function Inspection.children(inst: Instance?, requestedPath: any, instanceInfo: (Instance) -> any): any
	if not inst then return { ok = false, error = "Instance not found: " .. tostring(requestedPath) } end
	local children = {}
	for _, child in ipairs(inst:GetChildren()) do table.insert(children, instanceInfo(child)) end
	table.sort(children, function(a, b) return a.name < b.name end)
	return { ok = true, instance = instanceInfo(inst), children = children }
end

function Inspection.source(inst: Instance?, requestedPath: any, instanceInfo: (Instance) -> any, hashSource: (string) -> string): any
	if not inst or not inst:IsA("LuaSourceContainer") then return { ok = false, error = "Script not found: " .. tostring(requestedPath) } end
	return { ok = true, script = instanceInfo(inst), source = inst.Source, sourceHash = hashSource(inst.Source), sourceLength = #inst.Source }
end

return Inspection

