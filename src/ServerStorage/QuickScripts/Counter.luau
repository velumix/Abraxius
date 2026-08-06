local Selection = game:GetService("Selection")

local selected = Selection:Get()

if #selected == 0 then
	warn("Nothing selected")
	return
end

local total = 0

for _, obj in ipairs(selected) do
	total += 1 -- count the object itself
	for _, _ in ipairs(obj:GetDescendants()) do
		total += 1
	end
end

print("Total instances in selection:", total)-- Write any code here, don't worry about returning anything.



