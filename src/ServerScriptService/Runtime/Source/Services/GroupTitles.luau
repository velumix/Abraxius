local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Modules = ReplicatedStorage.Modules

local Mince = require(Modules.Mince)

local GroupTitles = {
	Name = "GroupTitles",
}

local GROUP_ID = 12889407

local RANKS = {
	[1] = "Supporter",
	[10] = "Regular",
	[21] = "🗺️",
	[24] = "🎨",
	[99] = "🧪",
	[101] = "🧪",
	[130] = "🛡️",
	[135] = "⚙️",
	[140] = "🏛️",
	[150] = "💼",
	[254] = "🛠️",
	[255] = "🛠️",
}

function GroupTitles:GameStart()
	local function onPlayerAdded(player)
		player.CharacterAdded:Connect(function(character)
			self:UpdateTitle(player, character)
		end)
		if player.Character then
			self:UpdateTitle(player, player.Character)
		end
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end
end

function GroupTitles:UpdateTitle(player, character)
	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid")
		if not humanoid then return end

		task.wait(0.5)

		local success, rank = pcall(function()
			return player:GetRankInGroup(GROUP_ID)
		end)

		if success and rank and rank > 0 then
			local title = RANKS[rank]
			if title then
				humanoid.DisplayName = title .. " " .. player.DisplayName
			end
		end
	end)
end

return GroupTitles