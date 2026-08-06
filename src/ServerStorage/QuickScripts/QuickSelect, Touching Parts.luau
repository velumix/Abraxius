local Selection = game:GetService("Selection")

local selected = Selection:Get()
if #selected == 0 then
	warn("Select at least one part/model first.")
	return
end

local function getParts(object)
	local parts = {}

	if object:IsA("BasePart") then
		table.insert(parts, object)
	else
		for _, d in ipairs(object:GetDescendants()) do
			if d:IsA("BasePart") then
				table.insert(parts, d)
			end
		end
	end

	return parts
end

local touchingSet = {}

for _, obj in ipairs(selected) do
	for _, part in ipairs(getParts(obj)) do
		part.CanTouch = true

		for _, hit in ipairs(part:GetTouchingParts()) do
			touchingSet[hit] = true
		end
	end
end

local touchingParts = {}
for part in pairs(touchingSet) do
	table.insert(touchingParts, part)
end

Selection:Set(touchingParts)

print("Selected", #touchingParts, "colliding parts")