
local OptimizedRaycast = {}

function OptimizedRaycast:batchRaycast(Object, directions: { Vector3 }, params)
	local closest_obstruction = nil
	local closest_distance = math.huge

	if #directions == 0 then
		return nil
	end

	local position = Object:GetPivot().Position

	for _, direction in ipairs(directions) do
		local result = workspace:Raycast(position, direction, params)
		if result then
			local distance = (result.Position - position).Magnitude
			if distance < closest_distance then
				closest_distance = distance
				closest_obstruction = result.Position
				if distance < 0.1 then
					break -- Early exit if very close obstruction found
				end
			end
		end
	end

	return closest_obstruction
end

return OptimizedRaycast