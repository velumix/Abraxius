local PolicyService = game:GetService("PolicyService") 
local Players = game:GetService("Players") 

local LocalPlayer = Players.LocalPlayer 

if not LocalPlayer then
	return {}
end

return PolicyService:GetPolicyInfoForPlayerAsync(LocalPlayer)