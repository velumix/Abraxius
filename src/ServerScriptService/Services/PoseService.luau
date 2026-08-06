local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local PoseApplier = require(ServerScriptService:WaitForChild("PoseApplier"))
local StudsConverter = require(ServerStorage:WaitForChild("StudsConverter"))
local Constants = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Constants"))
local RIG_TYPE = Constants.RIG_TYPE

local PoseService = Knit.CreateService({
	Name = "PoseService",
	Client = {
		SetPose = Knit.CreateSignal(),
		PoseSync = Knit.CreateSignal(),
		PoseRejected = Knit.CreateSignal(),
	},
})

local posed = {}

local function tableCount(t)
	local c = 0
	for _ in pairs(t) do
		c = c + 1
	end
	return c
end

local function charScale(char)
	if not char then
		return 1
	end
	local ok, s = pcall(function()
		return char:GetScale()
	end)
	if ok and type(s) == "number" and s > 0 then
		return s
	end
	return 1
end

local COLLISION_SWAP_PARTS = (RIG_TYPE == "R6")
	and { "HumanoidRootPart", "Torso", "Head" }
	or { "HumanoidRootPart", "UpperTorso", "LowerTorso", "Head" }
local function applyPoseCollision(char)
	local saved = {}
	for _, name in ipairs(COLLISION_SWAP_PARTS) do
		local part = char:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			saved[name] = part.CanCollide
			part.CanCollide = (name == "HumanoidRootPart")
		end
	end
	return saved
end

local function restorePoseCollision(char, saved)
	if not saved then
		return
	end
	for name, wasCollide in pairs(saved) do
		local part = char:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			part.CanCollide = wasCollide
		end
	end
end

local STAND_HEIGHT = 5
local SEARCH_RING = 6
local SEARCH_STEPS = 3

local function hasHeadroom(pos, ignoreChar)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ignoreChar }
	local hit = workspace:Raycast(pos, Vector3.new(0, STAND_HEIGHT, 0), params)
	return hit == nil
end

local function groundSpotAt(x, y, z, ignoreChar)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ignoreChar }

	local from = Vector3.new(x, y + 3, z)
	local hit = workspace:Raycast(from, Vector3.new(0, -10, 0), params)
	if not hit then
		return nil
	end
	local standPos = hit.Position + Vector3.new(0, 3, 0)
	if hasHeadroom(standPos, ignoreChar) then
		return standPos
	end
	return nil
end

local function findSafeStandPosition(char)
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local pos = root.Position

	if hasHeadroom(pos, char) then
		return nil
	end

	local dirs = {
		Vector3.new(1, 0, 0),
		Vector3.new(-1, 0, 0),
		Vector3.new(0, 0, 1),
		Vector3.new(0, 0, -1),
		Vector3.new(1, 0, 1).Unit,
		Vector3.new(1, 0, -1).Unit,
		Vector3.new(-1, 0, 1).Unit,
		Vector3.new(-1, 0, -1).Unit,
	}
	for step = 1, SEARCH_STEPS do
		local dist = SEARCH_RING * step
		for _, d in ipairs(dirs) do
			local sample = pos + d * dist
			local spot = groundSpotAt(sample.X, pos.Y, sample.Z, char)
			if spot then
				return spot
			end
		end
	end
	return nil
end

local CRAWL_DROP_THRESHOLD = 1.5
local CRAWL_FRONT_GAP = 1.0
local R6_HALF_DEPTH = 1.0
local R6_FEET_OFFSET = 2.5
local R6_HEAD_OFFSET = 1.5

local function poseRootDrop(def)
	if RIG_TYPE == "R6" then
		local cf = def.RootJoint
		if typeof(cf) ~= "CFrame" then
			return 0
		end
		return -cf.Position.Y
	end
	local r = def.Root
	local cf = r and r.cf
	if typeof(cf) ~= "CFrame" then
		return 0
	end
	return -cf.Position.Y
end

local function crawlWouldClip(char)
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end

	local look = root.CFrame.LookVector
	local fwd = Vector3.new(look.X, 0, look.Z)
	if fwd.Magnitude < 0.01 then
		return false
	end
	fwd = fwd.Unit

	local rayLen = R6_HALF_DEPTH + CRAWL_FRONT_GAP

	local feetY = root.Position.Y - R6_FEET_OFFSET
	local centerY = root.Position.Y
	local headY = root.Position.Y + R6_HEAD_OFFSET

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }

	local function castFwd(y)
		local origin = Vector3.new(root.Position.X, y, root.Position.Z)
		return workspace:Raycast(origin, fwd * rayLen, params)
	end

	local lowHit = castFwd(feetY)
	local midHit = castFwd(centerY)
	local highHit = castFwd(headY)
	if lowHit and highHit and lowHit.Instance.CanCollide and highHit.Instance.CanCollide and lowHit.Instance == highHit.Instance then
		return true, lowHit.Instance.Name
	end
	if midHit and highHit and midHit.Instance.CanCollide and highHit.Instance.CanCollide and midHit.Instance == highHit.Instance then
		return true, midHit.Instance.Name
	end
	return false
end

function PoseService:clearPose(player, reason)
	local state = posed[player]
	if not state then
		self.Client.PoseSync:FireAll(player)
		return
	end

	posed[player] = nil
	self.Client.PoseSync:FireAll(player)

	local char = state.char
	if char and char.Parent then
		for name, joint in pairs(state.joints) do
			if joint and joint.Parent then
				joint.Transform = CFrame.identity
			end
		end

		local hum = state.hum
		if hum and hum.Parent then
			hum.PlatformStand = false
		end

		local animate = char:FindFirstChild("Animate")
		if animate then
			animate.Disabled = false
		end

		local root = char:FindFirstChild("HumanoidRootPart")
		if root and not hasHeadroom(root.Position, char) then
			local watchChar, savedCollision = char, state.savedCollision
			task.spawn(function()
				for _ = 1, 400 do
					task.wait(0.05)
					local r = watchChar.Parent and watchChar:FindFirstChild("HumanoidRootPart")
					if not r then
						return
					end
					if posed[player] then
						return
					end
					if hasHeadroom(r.Position, watchChar) then
						restorePoseCollision(watchChar, savedCollision)
						return
					end
				end
				if watchChar.Parent and not posed[player] then
					restorePoseCollision(watchChar, savedCollision)
				end
			end)
		else
			restorePoseCollision(char, state.savedCollision)
		end
	end
end

local function buildPosePayload(joints, targets)
	local payload = {}
	for name, joint in pairs(joints) do
		payload[#payload + 1] = { joint, targets[name] or CFrame.identity }
	end
	return payload
end

function PoseService:applyPose(player, poseName)
	local def = PoseApplier.POSES[poseName]
	if not def then
		return
	end
	local char = player.Character
	if not char then
		return
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return
	end

	local drop = poseRootDrop(def)
	if drop >= CRAWL_DROP_THRESHOLD then
		local clip, what = crawlWouldClip(char)
		if clip then
			self.Client.PoseRejected:Fire(player, poseName)
			return
		end
	end

	self:clearPose(player)

	local joints = PoseApplier.getJoints(char)
	local scale = charScale(char)
	local targets = PoseApplier.computeTargets(def, joints, scale)

	local animate = char:FindFirstChild("Animate")
	if animate then
		animate.Disabled = true
	end
	local animator = hum:FindFirstChildOfClass("Animator")
	if animator then
		for _, tr in ipairs(animator:GetPlayingAnimationTracks()) do
			tr:Stop(0)
		end
	end

	if def.platformStand then
		hum.PlatformStand = true
	end

	local savedCollision = applyPoseCollision(char)

	posed[player] = {
		char = char,
		hum = hum,
		joints = joints,
		targets = targets,
		def = def,
		lastScale = scale,
		platformStand = def.platformStand and true or false,
		savedCollision = savedCollision,
	}

	self.Client.PoseSync:FireAll(player, buildPosePayload(joints, targets))
end

function PoseService:KnitStart()
	RunService.Stepped:Connect(function()
		for player, state in pairs(posed) do
			local char = state.char
			local hum = state.hum
			if not char or not char.Parent or not hum or hum.Parent ~= char or hum.Health <= 0 then
				posed[player] = nil
			elseif player.Character ~= char or not StudsConverter.isConverted(char) then
				self:clearPose(player)
			else
				if state.platformStand then
					hum.PlatformStand = true
				end
				if not state.debugPrinted then
					state.debugPrinted = true
				end

				local liveScale = charScale(char)
				if math.abs(liveScale - (state.lastScale or 1)) > 0.001 then
					state.targets = PoseApplier.computeTargets(state.def, state.joints, liveScale)
					state.lastScale = liveScale
					self.Client.PoseSync:FireAll(player, buildPosePayload(state.joints, state.targets))
				end

				local animator = hum:FindFirstChildOfClass("Animator")
				if animator then
					for _, tr in ipairs(animator:GetPlayingAnimationTracks()) do
						tr:Stop(0)
					end
				end

				for name, joint in pairs(state.joints) do
					if joint and joint.Parent then
						joint.Transform = state.targets[name] or CFrame.identity
					end
				end
			end
		end
	end)

	self.Client.SetPose:Connect(function(player, poseName)
		if poseName == nil or poseName == "none" then
			self:clearPose(player, "SetPose none")
			return
		end
		if type(poseName) ~= "string" then
			return
		end
		if not PoseApplier.POSES[poseName] then
			return
		end

		local char = player.Character
		if not char or not StudsConverter.isConverted(char) then
			return
		end
		self:applyPose(player, poseName)
	end)

	Players.PlayerRemoving:Connect(function(player)
		posed[player] = nil
	end)

	local function onPlayer(player)
		player.CharacterAdded:Connect(function()
			posed[player] = nil
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in ipairs(Players:GetPlayers()) do
		onPlayer(p)
	end
end

function PoseService:IsPosed(player)
	return posed[player] ~= nil
end

function PoseService:ClearPose(player)
	self:clearPose(player)
end

return PoseService
