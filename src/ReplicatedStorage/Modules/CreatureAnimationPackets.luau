local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Mince = require(ReplicatedStorage.Modules.Mince)

return Mince:DefinePackets("CreatureAnimations", function(Net)
	return {
		Ready = {
			Value = Net.nothing,
			Reliability = "reliable",
		},
		Sync = {
			Value = Net.array(Net.struct({
				creature = Net.inst,
				startedAt = Net.float64,
				speed = Net.float32,
			})),
			Reliability = "reliable",
		},
	}
end)
