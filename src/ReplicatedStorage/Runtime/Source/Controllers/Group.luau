local GroupService = game:GetService("GroupService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Modules = ReplicatedStorage.Modules
local Mince = require(Modules.Mince)

local Player = Players.LocalPlayer

local Group = {
	Name = "Group",
	GROUP_ID = 12889407,
	IsInGroup = false,
	HasPrompted = false,
}

function Group:CheckMembership()
	local success, isInGroup = pcall(function()
		return Player:IsInGroup(self.GROUP_ID)
	end)

	if success then
		self.IsInGroup = isInGroup
		return isInGroup
	else
		warn("Failed to check group membership:", isInGroup)
		return false
	end
end

function Group:GetRank()
	local success, rank = pcall(function()
		return Player:GetRankInGroup(self.GROUP_ID)
	end)

	if success then
		return rank
	else
		warn("Failed to get group rank:", rank)
		return 0
	end
end

function Group:GetRole()
	local success, role = pcall(function()
		return Player:GetRoleInGroup(self.GROUP_ID)
	end)

	if success then
		return role
	else
		warn("Failed to get group role:", role)
		return "Guest"
	end
end

function Group:PromptJoin()
	if self.HasPrompted then
		return false
	end

	if self:CheckMembership() then
		return true
	end

	self.HasPrompted = true

	local success, result = pcall(function()
		return GroupService:PromptJoinAsync(self.GROUP_ID)
	end)

	if not success then
		warn("Failed to prompt group join:", result)
		return false
	end

	if result == Enum.GroupMembershipStatus.Joined then
		self.IsInGroup = true
		return true
	end

	if result == Enum.GroupMembershipStatus.AlreadyMember then
		self.IsInGroup = true
		return true
	end

	if result == Enum.GroupMembershipStatus.JoinRequestPending then
		return false
	end

	warn("Group join did not complete:", result)
	return false
end

function Group:GetGroupInfo()
	local success, info = pcall(function()
		return GroupService:GetGroupInfoAsync(self.GROUP_ID)
	end)

	if success then
		return info
	else
		warn("Failed to get group info:", info)
		return nil
	end
end

function Group:Setup()
	local isMember = self:CheckMembership()

	if isMember then
		self:GetRank()
		self:GetRole()
	else
		task.defer(function()
			self:PromptJoin()
		end)
	end
end

return Group