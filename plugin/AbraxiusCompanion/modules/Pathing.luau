--!strict
local Pathing = {}

function Pathing.resolve(path: string): Instance?
	local parts = string.split(path, ".")
	local current: Instance? = game
	for _, part in ipairs(parts) do
		if current == nil then return nil end
		if part == "game" then continue end
		current = current:FindFirstChild(part)
	end
	return current
end

function Pathing.info(inst: Instance): any
	return {
		className = inst.ClassName,
		name = inst.Name,
		fullName = inst:GetFullName(),
		path = string.gsub(inst:GetFullName(), "^game%.", ""),
	}
end

return Pathing

