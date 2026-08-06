local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameRemotes = ReplicatedStorage:WaitForChild("GameRemotes")

local module = {}

-- ActionBroadcastService fans this cross-server
function module.execute(params)
	if type(params) ~= "table" then return end
	local remote = GameRemotes:FindFirstChild("GlobalUnbox")
	if remote then
		remote:FireAllClients(params)
	end
end

return module