local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Mince = require(ReplicatedStorage.Modules.Mince)

return Mince:DefinePackets("Realism", function(Net)
	return {
		LookInput = {
			Value = Net.struct({
				pitch = Net.float32,
				yaw = Net.float32,
			}),
			Reliability = "unreliable",
		},
		LookBroadcast = {
			Value = Net.struct({
				player = Net.inst,
				pitch = Net.float32,
				yaw = Net.float32,
			}),
			Reliability = "unreliable",
		},
	}
end)
