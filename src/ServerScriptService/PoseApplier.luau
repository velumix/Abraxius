local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Constants"))
local RIG_TYPE = Constants.RIG_TYPE

local PoseApplier = {}

local function rad(d) return math.rad(d) end

local DEF_ROOT = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)

local function scalePos(cf, s)
	if s == 1 then return cf end
	local x, y, z = cf.Position.X, cf.Position.Y, cf.Position.Z
	return CFrame.new(x * s, y * s, z * s) * (cf - cf.Position)
end

local JOINT_PARENTS_R15 = {
	Root          = "LowerTorso",
	Waist         = "UpperTorso",
	Neck          = "Head",
	LeftShoulder  = "LeftUpperArm",
	RightShoulder = "RightUpperArm",
	LeftElbow     = "LeftLowerArm",
	RightElbow    = "RightLowerArm",
	LeftWrist     = "LeftHand",
	RightWrist    = "RightHand",
	LeftHip       = "LeftUpperLeg",
	RightHip      = "RightUpperLeg",
	LeftKnee      = "LeftLowerLeg",
	RightKnee     = "RightLowerLeg",
	LeftAnkle     = "LeftFoot",
	RightAnkle    = "RightFoot",
}

local JOINT_PARENTS_R6 = {
	RootJoint          = "HumanoidRootPart",
	["Neck"]           = "Torso",
	["Right Shoulder"] = "Torso",
	["Left Shoulder"]  = "Torso",
	["Right Hip"]      = "Torso",
	["Left Hip"]       = "Torso",
}

PoseApplier.JOINT_PARENTS = (RIG_TYPE == "R6") and JOINT_PARENTS_R6 or JOINT_PARENTS_R15

local POSES_R15 = {
	crouch = {
		Root = { cf = CFrame.new(-0.0047, -0.8538, -0.1940) * CFrame.Angles(rad(-11.197), rad(1.794), rad(0.272)) },
		Neck = { rot = CFrame.new(-0.0000, 0.0000, -0.0000) * CFrame.Angles(rad(-4.862), rad(0.030), rad(-0.151)) },
		LeftHip = { rot = CFrame.new(-0.0475, 0.8260, -0.6609) * CFrame.Angles(rad(-0.143), rad(-0.592), rad(-3.736)) },
		RightHip = { rot = CFrame.new(0.0406, 0.8261, -0.6616) * CFrame.Angles(rad(-2.876), rad(-3.534), rad(3.176)) },
	},
	raisehands = {
		LeftShoulder = { rot = CFrame.Angles(0, 0, rad(-160)) },
		RightShoulder = { rot = CFrame.Angles(0, 0, rad(160)) },
		LeftElbow = { rot = CFrame.Angles(rad(25), 0, 0) },
		RightElbow = { rot = CFrame.Angles(rad(25), 0, 0) },
	},
	tpose = {
		LeftShoulder = { rot = CFrame.Angles(0, 0, rad(-90)) },
		RightShoulder = { rot = CFrame.Angles(0, 0, rad(90)) },
	},
	crawl = {
		Root = { cf = CFrame.new(0, -2.6, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0) },
		Waist = { rot = CFrame.identity },
		LeftShoulder = { rot = CFrame.new(0, 0, 0, 1, 0, 0, 0, -1, 0, 0, 0, -1) },
		RightShoulder = { rot = CFrame.new(0, 0, 0, 1, 0, 0, 0, -1, 0, 0, 0, -1) },
	},
	star = {
		Root = { cf = CFrame.new(0, 0, 0) },
		LeftShoulder = { rot = CFrame.Angles(0, 0, rad(-130)) },
		RightShoulder = { rot = CFrame.Angles(0, 0, rad(130)) },
		LeftHip = { rot = CFrame.Angles(0, 0, rad(-30)) },
		RightHip = { rot = CFrame.Angles(0, 0, rad(30)) },
	},
	sit = {
		Root = { cf = CFrame.new(0, -1.7, 0) },
		LeftHip = { rot = CFrame.Angles(rad(90), 0, 0) },
		RightHip = { rot = CFrame.Angles(rad(90), 0, 0) },
		LeftKnee = { rot = CFrame.Angles(rad(-95), 0, 0) },
		RightKnee = { rot = CFrame.Angles(rad(-95), 0, 0) },
	},
	laying = {
		Root = { cf = CFrame.new(0, -2.3, 0) * CFrame.Angles(rad(-90), 0, 0) },
		LeftShoulder = { rot = CFrame.Angles(0, 0, rad(-18)) },
		RightShoulder = { rot = CFrame.Angles(0, 0, rad(18)) },
	},
	ononeknee = {
		Root = { cf = CFrame.new(0, -1.5, 0) },
		LeftHip = { rot = CFrame.Angles(rad(-12), 0, 0) },
		LeftKnee = { rot = CFrame.Angles(rad(-125), 0, 0) },
		RightHip = { rot = CFrame.Angles(rad(95), 0, 0) },
		RightKnee = { rot = CFrame.Angles(rad(-95), 0, 0) },
		Waist = { rot = CFrame.Angles(rad(5), 0, 0) },
	},
	crossedarms = {
		Root = { cf = CFrame.new(-0.017, -2.654, 0.999) * CFrame.Angles(rad(91.617), rad(0.999), rad(0.919)) },
		Waist = { rot = CFrame.Angles(rad(-2.65), rad(5.216), rad(-1.175)) },
		Neck = { rot = CFrame.Angles(rad(-1.237), rad(-14.073), rad(-0.323)) },
		LeftShoulder = { rot = CFrame.new(0.025, -0.337, -0.016) * CFrame.Angles(rad(87.29), rad(-7.858), rad(74.136)) },
		RightShoulder = { rot = CFrame.new(-0.02, -0.718, -0.022) * CFrame.Angles(rad(122.266), rad(6.967), rad(-88.466)) },
		LeftHip = { rot = CFrame.Angles(rad(0), rad(0), rad(-0.707)) },
		RightHip = { rot = CFrame.Angles(rad(0), rad(0), rad(1.793)) },
	},
	backward = {
		Root = { cf = CFrame.new(-0.001, -1.658, 0.996) * CFrame.Angles(rad(95.099), rad(0), rad(0)) },
		Neck = { rot = CFrame.Angles(rad(48.59), rad(0), rad(0)) },
		LeftShoulder = { rot = CFrame.new(0.081, -0.013, -0.243) * CFrame.Angles(rad(-110.084), rad(31.518), rad(-7.4)) },
		RightShoulder = { rot = CFrame.new(-0.082, -0.013, -0.243) * CFrame.Angles(rad(-110.084), rad(-31.519), rad(7.399)) },
		LeftHip = { rot = CFrame.new(-0.177, -0.547, -0.45) * CFrame.Angles(rad(-91.049), rad(30.565), rad(-5.871)) },
		RightHip = { rot = CFrame.new(0.132, -0.577, -0.423) * CFrame.Angles(rad(-92.306), rad(-17.489), rad(6.804)) },
	},
	playingdead = {
		Root = { cf = CFrame.new(-0.023, -2.146, 0.999) * CFrame.Angles(rad(-107.257), rad(-85.351), rad(164.11)) },
		Neck = { rot = CFrame.Angles(rad(0), rad(0), rad(-20.989)) },
		LeftShoulder = { rot = CFrame.new(0.184, 0.075, -0.125) * CFrame.Angles(rad(79.264), rad(-6.491), rad(71.499)) },
		RightShoulder = { rot = CFrame.new(-0.409, -0.001, 0.025) * CFrame.Angles(rad(-164.676), rad(76.752), rad(-170.902)) },
		LeftHip = { rot = CFrame.Angles(rad(-12.557), rad(0), rad(21.138)) },
		RightHip = { rot = CFrame.Angles(rad(28.951), rad(4.452), rad(0)) },
	},
}

local POSES_R6 = {
	crouch = {
		RootJoint = CFrame.new(0, -0.5, 0) * DEF_ROOT,
		["Right Shoulder"] = { rel = CFrame.new(1.5, 0, 0) },
		["Left Shoulder"]  = { rel = CFrame.new(-1.5, 0, 0) },
		["Right Hip"]      = { rel = CFrame.new(0.5, -1.5, -0.5) },
		["Left Hip"]       = { rel = CFrame.new(-0.5, -1.5, -0.5) },
	},
	raisehands = {
		["Right Shoulder"] = { rel = CFrame.new(1.5, 1, 0, -1, 0, 0, 0, -1, 0, 0, 0, 1) },
		["Left Shoulder"]  = { rel = CFrame.new(-1.5, 1, 0, -1, 0, 0, 0, -1, 0, 0, 0, 1) },
	},
	tpose = {
		["Right Shoulder"] = { rel = CFrame.new(2, 0.5, 0) * CFrame.Angles(0, 0, rad(90)) },
		["Left Shoulder"]  = { rel = CFrame.new(-2, 0.5, 0) * CFrame.Angles(0, 0, rad(-90)) },
	},
	crawl = {
		RootJoint = CFrame.new(0, -2.6, 0) * DEF_ROOT * CFrame.Angles(rad(90), 0, 0),
		["Right Shoulder"] = { rel = CFrame.new(1.5, 1, 0, -1, 0, 0, 0, -1, 0, 0, 0, 1) },
		["Left Shoulder"]  = { rel = CFrame.new(-1.5, 1, 0, -1, 0, 0, 0, -1, 0, 0, 0, 1) },
	},
	star = {
		RootJoint = CFrame.new(-0.0332642, -0.117881, -0.114166, -0.999991, -0.00257307, 0.00351619, 0.00372752, -0.0873514, 0.996171, -0.00225607, 0.996174, 0.0873602),
		["Right Shoulder"] = { rel = CFrame.new(1.81989, 1.23614, 0.15506, -0.686128, -0.598066, -0.414182, 0.675901, -0.734635, -0.0588986, -0.269047, -0.320358, 0.908286) },
		["Left Shoulder"]  = { rel = CFrame.new(-1.81992, 1.23614, 0.155029, -0.686128, 0.598066, 0.414182, -0.675901, -0.734635, -0.0588987, 0.269047, -0.320358, 0.908286) },
		["Right Hip"]      = { rel = CFrame.new(0.739868, -1.91449, 0.150635, 0.961616, -0.239004, -0.134806, 0.257588, 0.955573, 0.143278, 0.0945733, -0.172502, 0.980458) },
		["Left Hip"]       = { rel = CFrame.new(-0.67746, -1.9, 0.173553, 0.953925, 0.170128, 0.247149, -0.2144, 0.962741, 0.16481, -0.209902, -0.210206, 0.954858) },
	},
	sit = {
		RootJoint = CFrame.new(0.0238953, -2.00515, -0.149078, -0.99939, -0.02963, 0.0185005, 0.0138987, 0.1486, 0.9888, -0.0320473, 0.988453, -0.148097),
		["Right Shoulder"] = { rel = CFrame.new(1.60571, -0.0262375, 0.189575, 0.921586, -0.156268, -0.355329, 0.15577, 0.987332, -0.030206, 0.355548, -0.027512, 0.934253) },
		["Left Shoulder"]  = { rel = CFrame.new(-1.48804, -0.0576706, 0.230042, 0.862444, 0.0695504, 0.501352, -0.0556131, 0.997538, -0.0427166, -0.503088, 0.00895892, 0.864188) },
		["Right Hip"]      = { rel = CFrame.new(0.548279, -0.809097, -1.33746, 0.998046, -0.0347081, 0.0519588, 0.0457519, -0.16043, -0.985986, 0.0425574, 0.986437, -0.158528) },
		["Left Hip"]       = { rel = CFrame.new(-0.635864, -0.82618, -1.29401, 0.994594, 0.103646, 0.00636245, 0.0221464, -0.151859, -0.988154, -0.101452, 0.982953, -0.153333) },
	},
	laying = {
		RootJoint = CFrame.new(-1.06387, -2.17234, 0.571869, -0.130444, -0.147975, -0.980351, -0.903545, -0.38932, 0.178989, -0.408156, 0.909139, -0.0829171),
		["Right Shoulder"] = { rel = CFrame.new(1.48769, -0.248734, 0.288788, 0.947095, -0.0679405, -0.31368, 0.126612, 0.977166, 0.170636, 0.294924, -0.201324, 0.934071) },
		["Left Shoulder"]  = { rel = CFrame.new(-1.16528, 1.3264, 0.147858, 0.196176, -0.0646476, -0.978436, -0.0576272, -0.99686, 0.0543108, -0.978874, 0.0457302, -0.199285) },
		["Right Hip"]      = { rel = CFrame.new(0.498444, -1.99815, 0.0464478, 0.991407, 0.0058674, -0.130686, 0.00881904, 0.993724, 0.111518, 0.13052, -0.111712, 0.985132) },
		["Left Hip"]       = { rel = CFrame.new(-0.499969, -2, 3.05176e-05, 1, -7.45058e-09, 0, -7.45058e-09, 1, -2.23517e-08, 0, -2.23517e-08, 1) },
	},
	ononeknee = {
		RootJoint = CFrame.new(0.0895081, -0.726359, 0.139374, -0.973835, -0.221961, 0.0487692, -0.0101698, 0.25695, 0.966371, -0.227028, 0.94059, -0.252485),
		["Right Shoulder"] = { rel = CFrame.new(1.50179, -0.0955658, 0.196472, 0.995562, -0.07759, -0.0532585, 0.0777137, 0.996976, 0.00025335, 0.0530777, -0.00439116, 0.998581) },
		["Left Shoulder"]  = { rel = CFrame.new(-1.52054, -0.0030365, -0.0560303, 0.998849, 0.0435915, -0.0200206, -0.0451711, 0.995206, -0.0867397, 0.0161435, 0.0875443, 0.99603) },
		["Right Hip"]      = { rel = CFrame.new(0.588501, -1.79222, -0.277283, 0.996914, -0.0705333, 0.034474, 0.0234093, 0.686209, 0.727028, -0.074936, -0.723977, 0.685742) },
		["Left Hip"]       = { rel = CFrame.new(-0.591385, -1.26759, -0.700623, 0.981337, 0.00699235, 0.19217, 0.0390793, 0.971233, -0.234902, -0.188284, 0.238028, 0.952834) },
	},
	crossedarms = {
		RootJoint = CFrame.new(0, -2.57276, -1.12459e-07, -1, 0, 0, 0, -1, -4.37114e-08, 0, -4.37114e-08, 1),
		["Right Shoulder"] = { rel = CFrame.new(0.596642, 0.50168, -0.0038746, 0.0103856, 0.999762, 0.0191982, 0.996184, -0.00868084, -0.0868417, -0.0866543, 0.0200268, -0.996037) },
		["Left Shoulder"]  = { rel = CFrame.new(-0.515796, 0.5, -0.142724, -0.0417639, -0.998626, 0.0316313, -0.953525, 0.0303824, -0.299776, 0.298404, -0.0426811, -0.953485) },
		["Right Hip"]      = { rel = CFrame.new(1, -1, 0, 0, -0.0210237, 0.999779, 0, 0.999779, 0.0210237, -1, 0, -0) },
		["Left Hip"]       = { rel = CFrame.new(-1, -1, 0, -0, 0.00323175, -0.999995, 0, 0.999995, 0.00323175, 1, 0, 0) },
		["Neck"]           = { rel = CFrame.new(-4.65661e-10, 1, 9.31323e-10, -0.999953, -0, 0.00965888, 0.0096562, 0.023545, 0.999676, -0.000227418, 0.999723, -0.0235439) },
	},
	backward = {
		RootJoint = CFrame.new(0, -1.56972, -9.00986e-09, -1, 0, 0, 0, -1, -4.37114e-08, 0, -4.37114e-08, 1),
		["Right Shoulder"] = { rel = CFrame.new(0.999998, 1.02546, 0, 0.239438, 0, 0.970911, -0.970912, 1.19249e-08, 0.239438, -1.1578e-08, -1, 2.85527e-09) },
		["Left Shoulder"]  = { rel = CFrame.new(-1, 1.02546, 0, 0.182735, 0, -0.983162, 0.983162, 1.19249e-08, 0.182735, 1.17241e-08, -1, 2.1791e-09) },
		["Right Hip"]      = { rel = CFrame.new(1.01363, -1.28426, -0.469472, 0.0811594, -0.164906, 0.982964, -0.996609, -4.31129e-08, 0.082286, -0.0135694, -0.986309, -0.164347) },
		["Left Hip"]       = { rel = CFrame.new(-1.03726, -1.25376, -0.469476, 0.104952, 0.15382, -0.982508, 0.994343, -4.31912e-08, 0.106217, 0.0163383, -0.988099, -0.15295) },
		["Neck"]           = { rel = CFrame.new(0, 1, 0, -1, 0, -0, 0, -0.943055, 0.332636, 0, 0.332636, 0.943055) },
	},
	playingdead = {
		RootJoint = CFrame.new(-9.06297e-08, -2.07337, -1.50234e-07, 4.37114e-08, -1, 0, 1, 4.37114e-08, -4.37114e-08, 4.37114e-08, 1.91069e-15, 1),
		["Right Shoulder"] = { rel = CFrame.new(0.154167, 0.6919, -0.579659, -0.374803, -0.0728095, 0.924241, 0.920761, 0.0871823, 0.38026, -0.108264, 0.993528, 0.0343639) },
		["Left Shoulder"]  = { rel = CFrame.new(-0.515796, 0.5, -0.142724, -0.0417639, -0.86779, -0.495171, -0.953525, 0.182638, -0.239651, 0.298404, 0.46215, -0.835088) },
		["Right Hip"]      = { rel = CFrame.new(1, -1, 2.98023e-08, -0.0081517, -0.019379, 0.999779, 0.387653, 0.921566, 0.0210237, -0.921769, 0.387738, -0) },
		["Left Hip"]       = { rel = CFrame.new(-1, -1, -1.49012e-08, 0.340121, -0.295956, -0.892596, 0.37504, 0.913122, -0.159853, 0.862359, -0.28039, 0.421567) },
		["Neck"]           = { rel = CFrame.new(1.49012e-08, 1, 0, -0.920719, -0, 0.390225, 0.390117, 0.023545, 0.920464, -0.00918784, 0.999723, -0.0216783) },
	},
}

PoseApplier.POSES = (RIG_TYPE == "R6") and POSES_R6 or POSES_R15

local function jointBase(j)
	if j:IsA("AnimationConstraint") then
		local a0 = j.Attachment0
		return a0 and a0.CFrame or CFrame.identity
	end
	return j.C0
end

function PoseApplier.getJoints(char)
	local joints = {}
	for jointName, parentName in pairs(PoseApplier.JOINT_PARENTS) do
		local parent = char:FindFirstChild(parentName)
		local j = parent and parent:FindFirstChild(jointName)
		if j and (j:IsA("AnimationConstraint") or j:IsA("Motor6D")) then
			joints[jointName] = j
		end
	end
	return joints
end

function PoseApplier.computeTargets(def, joints, scale)
	scale = scale or 1
	local t = {}
	if RIG_TYPE == "R6" then
		for name, joint in pairs(joints) do
			local d = def[name]
			if d then
				local base = jointBase(joint)
				if name == "RootJoint" then
					if typeof(d) == "CFrame" then
						local cf = (scale ~= 1) and scalePos(d, scale) or d
						t[name] = base:Inverse() * cf
					end
				elseif d.rel then
					local cf = (scale ~= 1) and scalePos(d.rel, scale) or d.rel
					t[name] = base:Inverse() * cf * joint.C1
				end
			end
		end
		return t
	end
	for name, joint in pairs(joints) do
		local d = def[name]
		if d then
			if name == "Root" then
				local cf = d.cf and scalePos(d.cf, scale) or CFrame.identity
				local base = jointBase(joint)
				t[name] = base:Inverse() * cf * base
			elseif d.rot then
				t[name] = d.rot
			end
		end
	end
	return t
end

function PoseApplier.preview(cframe, poseId, duration)
	local def = PoseApplier.POSES[poseId]
	if not def then return nil, "unknown pose" end
	duration = duration or 6

	local ok, rig = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), (RIG_TYPE == "R6") and Enum.HumanoidRigType.R6 or Enum.HumanoidRigType.R15)
	end)
	if not ok or not rig then return nil, "rig creation failed" end

	rig.Name = "PosePreview_" .. poseId
	for _, d in ipairs(rig:GetDescendants()) do
		if d:IsA("LuaSourceContainer") then d:Destroy() end
	end

	local hum = rig:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = 0
		hum.AutoRotate = false
		hum.EvaluateStateMachine = false
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		hum.NameDisplayDistance = 0
	end

	for _, p in ipairs(rig:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
		end
	end

	local hrp = rig:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.Anchored = true
		rig.PrimaryPart = hrp
	end

	local joints = PoseApplier.getJoints(rig)
	local targets = PoseApplier.computeTargets(def, joints, 1)
	for name, joint in pairs(joints) do
		joint.Transform = targets[name] or CFrame.identity
	end

	if cframe then rig:PivotTo(cframe) end
	rig.Parent = Workspace
	Debris:AddItem(rig, duration)
	return rig
end

do
	local RunService = game:GetService("RunService")
	if RunService:IsStudio() and RunService:IsServer() then
		task.defer(function()
			local ok, PoseConfig = pcall(function()
				return require(game:GetService("ReplicatedStorage"):WaitForChild("PoseConfig", 10))
			end)
			if not ok or type(PoseConfig) ~= "table" then
				warn("[PoseApplier] audit: could not require PoseConfig -- skipping pose consistency check")
				return
			end
			-- metadata (PoseConfig) without geometry (here)
			for _, def in ipairs(PoseConfig.POSES) do
				if PoseApplier.POSES[def.id] == nil then
					warn(string.format("[PoseApplier] No pose geometry found for pose '%s' (id=%s) -- it's in PoseConfig but has no entry in PoseApplier.POSES",
						tostring(def.name), tostring(def.id)))
				end
			end
			-- geometry (here) without metadata (PoseConfig)
			for id in PoseApplier.POSES do
				if PoseConfig.getPose(id) == nil then
					warn(string.format("[PoseApplier] Pose geometry '%s' has no PoseConfig entry -- it won't appear in the pose UI", tostring(id)))
				end
			end
		end)
	end
end

return PoseApplier
