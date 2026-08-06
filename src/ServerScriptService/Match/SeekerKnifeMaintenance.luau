local MatchState = require(script.Parent:WaitForChild("MatchState"))

local seekers = MatchState.seekers
local seekerOut = MatchState.seekerOut

local SeekerKnifeMaintenance = {}

local function hasPaintballGun(player: Player): boolean
	local backpack = player:FindFirstChildOfClass("Backpack")
	local char = player.Character
	if backpack and backpack:FindFirstChild("Paintball Gun") then
		return true
	end
	if char and char:FindFirstChild("Paintball Gun") then
		return true
	end
	return false
end

function SeekerKnifeMaintenance.start(knife)
	local watchedStart = MatchState.roundStartTime
	task.spawn(function()
		while MatchState.current == "ROUND" and MatchState.roundStartTime == watchedStart do
			if not MatchState.seekerGone then
				for _, s in ipairs(seekers) do
					local char = s.Parent and s.Character
					local hum = char and char:FindFirstChildOfClass("Humanoid")
					if hum and hum.Health > 0 and not seekerOut[s] and not knife.seekerHasKnife(s) and not hasPaintballGun(s) then
						knife.giveKnife(s)
					end
				end
			end
			task.wait(1)
		end
	end)
end

return SeekerKnifeMaintenance
