return {
	["Owner"] = {"DefaultUtil","DefaultAdmin","GameOwner"},
	["Developer"] = {"DefaultUtil","DefaultAdmin","GameOwner"},

	HasPermission = function(self, Player, Permission) 
		if game:GetService("RunService"):IsStudio() then return true end 

		local GroupRank = Player:GetRoleInGroup(game.CreatorId) or "Non-Member"
		local GroupPermissions = self[GroupRank] or {} 

		local HasPermission = false 
		for _,Group in ipairs(GroupPermissions) do 
			if Group == Permission then 
				return true 
			end
		end
	end,
}