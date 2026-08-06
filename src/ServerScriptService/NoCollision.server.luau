local PhysService = game:GetService("PhysicsService")
local PlayerGroup = "p"
local SoundGroup = "SoundArea"

local function safeRegister(name)
	local success, _ = pcall(function() PhysService:RegisterCollisionGroup(name) end)
end

safeRegister(PlayerGroup)
safeRegister(SoundGroup)

PhysService:CollisionGroupSetCollidable(PlayerGroup, PlayerGroup, false)
PhysService:CollisionGroupSetCollidable(SoundGroup, "Default", false)

function NoCollide(model)
	for k,v in pairs (model:GetChildren()) do
		if v:IsA"BasePart" then
			v.CollisionGroup = PlayerGroup
		end
	end
end

local function CheckSoundArea(v)
	if v:IsA("BasePart") and (v.Name == "SoundArea" or v.Name == "SoundZone") then
		v.CollisionGroup = SoundGroup
	end
end

for _, v in pairs(workspace:GetDescendants()) do
	CheckSoundArea(v)
end

workspace.DescendantAdded:Connect(CheckSoundArea)

game:GetService("Players").PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		char:WaitForChild("HumanoidRootPart")
		char:WaitForChild("Head")
		char:WaitForChild("Humanoid")
		task.wait(0.1)
		NoCollide(char)

		if player.Character then
			NoCollide(player.Character)
		end
	end)
end)
