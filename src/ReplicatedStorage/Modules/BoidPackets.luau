local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Mince = require(ReplicatedStorage.Modules.Mince)

return Mince:DefinePackets("Boids", function(Net)
	return {
		Ready = {
			Value = Net.nothing,
			Reliability = "reliable",
		},
		TargetBatch = {
			Value = Net.array(Net.struct({
				node = Net.inst,
				target = Net.vec3,
			})),
			Reliability = "unreliable",
		},
	}
end)
