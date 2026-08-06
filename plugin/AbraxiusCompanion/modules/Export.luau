--!strict
local Export = {}

function Export.scripts(requestedServices: any?, defaultServices: { string }): any
	local services = requestedServices or defaultServices
	local scripts = {}
	for _, serviceName in ipairs(services) do
		local service = game:FindFirstChild(tostring(serviceName))
		if service then
			for _, inst in ipairs(service:GetDescendants()) do
				if inst:IsA("LuaSourceContainer") then
					local runContext = if inst:IsA("Script") then inst.RunContext.Name else nil
					table.insert(scripts, {
						path = string.gsub(inst:GetFullName(), "^game%.", ""), className = inst.ClassName,
						source = inst.Source, hasChildren = #inst:GetChildren() > 0, runContext = runContext,
					})
				end
			end
		end
	end
	table.sort(scripts, function(a, b) return a.path < b.path end)
	return { ok = true, scripts = scripts, count = #scripts }
end

return Export
