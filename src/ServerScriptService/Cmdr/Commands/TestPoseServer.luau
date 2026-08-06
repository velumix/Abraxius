local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PoseApplier = require(ServerScriptService:WaitForChild("PoseApplier"))
local PoseConfig = require(ReplicatedStorage:WaitForChild("PoseConfig"))

local PREVIEW_SECONDS = 8

return function(context, pose: string)
	local player = context.Executor
	local char = player and player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return "You need a spawned character to preview from (be in the lobby)."
	end

	local facing = (hrp.CFrame * CFrame.new(0, 0, -8)) * CFrame.Angles(0, math.pi, 0)

	local ids = {}
	if pose == "All" then
		for _, def in ipairs(PoseConfig.POSES) do
			table.insert(ids, def.id)
		end
	else
		table.insert(ids, pose)
	end

	local shown, missing = 0, {}
	local center = (#ids + 1) / 2
	for i, id in ipairs(ids) do
		local cf = facing * CFrame.new((i - center) * 6, 0, 0)
		local rig, err = PoseApplier.preview(cf, id, PREVIEW_SECONDS)
		if rig then
			shown += 1
		else
			table.insert(missing, id .. (err and (" - " .. err) or ""))
		end
	end

	local msg = ("Previewing %d pose(s) in front of you for ~%ds."):format(shown, PREVIEW_SECONDS)
	if #missing > 0 then
		msg = msg .. " Skipped: " .. table.concat(missing, ", ")
	end
	return msg
end
