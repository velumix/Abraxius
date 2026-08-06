-- BackpackLockClient: locks/unlocks the backpack GUI on the server's command.
-- While the seeker holds their knife the backpack is hidden so they can't unequip or drop it;
-- when they stop being the seeker it's restored. The knife stays equipped because, with the
-- backpack GUI disabled, the player has no hotbar to unequip from.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local LockBackpack = Remotes:WaitForChild("LockBackpack")

local function setBackpackEnabled(enabled)
	-- SetCoreGuiEnabled can briefly fail before the CoreGui is ready; retry a few times.
	for _ = 1, 10 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, enabled)
		end)
		if ok then return end
		task.wait(0.1)
	end
end

LockBackpack.OnClientEvent:Connect(function(locked)
	-- locked == true  -> hide the backpack (seeker can't unequip the knife)
	-- locked == false -> show it again
	setBackpackEnabled(not locked)
end)
