-- R15 rig definition for manual ragdoll construction.
-- Mirrors the structure the old NpcUtility used from RagdollLimit.RAGDOLL_RIG.

export type RigEntry = {
	motorParentName: string,
	motorName: string,
	part0Name: string,
	part1Name: string,
	limits: {
		UpperAngle: number,
		TwistUpperAngle: number,
		TwistLowerAngle: number,
	},
}

local RAGDOLL_RIG: { RigEntry } = {
	{ motorParentName = "LowerTorso", motorName = "Root", part0Name = "HumanoidRootPart", part1Name = "LowerTorso", limits = { UpperAngle = 20, TwistUpperAngle = 30, TwistLowerAngle = 0 } },
	{ motorParentName = "UpperTorso", motorName = "Waist", part0Name = "LowerTorso", part1Name = "UpperTorso", limits = { UpperAngle = 20, TwistUpperAngle = 30, TwistLowerAngle = -10 } },
	{ motorParentName = "Head", motorName = "Neck", part0Name = "UpperTorso", part1Name = "Head", limits = { UpperAngle = 45, TwistUpperAngle = 30, TwistLowerAngle = -30 } },

	{ motorParentName = "RightUpperArm", motorName = "RightShoulder", part0Name = "UpperTorso", part1Name = "RightUpperArm", limits = { UpperAngle = 90, TwistUpperAngle = 160, TwistLowerAngle = -70 } },
	{ motorParentName = "RightLowerArm", motorName = "RightElbow", part0Name = "RightUpperArm", part1Name = "RightLowerArm", limits = { UpperAngle = 0, TwistUpperAngle = 95, TwistLowerAngle = -5 } },
	{ motorParentName = "RightHand", motorName = "RightWrist", part0Name = "RightLowerArm", part1Name = "RightHand", limits = { UpperAngle = 10, TwistUpperAngle = 5, TwistLowerAngle = -45 } },

	{ motorParentName = "LeftUpperArm", motorName = "LeftShoulder", part0Name = "UpperTorso", part1Name = "LeftUpperArm", limits = { UpperAngle = 90, TwistUpperAngle = 160, TwistLowerAngle = -70 } },
	{ motorParentName = "LeftLowerArm", motorName = "LeftElbow", part0Name = "LeftUpperArm", part1Name = "LeftLowerArm", limits = { UpperAngle = 0, TwistUpperAngle = 95, TwistLowerAngle = -5 } },
	{ motorParentName = "LeftHand", motorName = "LeftWrist", part0Name = "LeftLowerArm", part1Name = "LeftHand", limits = { UpperAngle = 10, TwistUpperAngle = 5, TwistLowerAngle = -45 } },

	{ motorParentName = "RightUpperLeg", motorName = "RightHip", part0Name = "LowerTorso", part1Name = "RightUpperLeg", limits = { UpperAngle = 60, TwistUpperAngle = 45, TwistLowerAngle = -45 } },
	{ motorParentName = "RightLowerLeg", motorName = "RightKnee", part0Name = "RightUpperLeg", part1Name = "RightLowerLeg", limits = { UpperAngle = 0, TwistUpperAngle = 5, TwistLowerAngle = -80 } },
	{ motorParentName = "RightFoot", motorName = "RightAnkle", part0Name = "RightLowerLeg", part1Name = "RightFoot", limits = { UpperAngle = 10, TwistUpperAngle = 5, TwistLowerAngle = -45 } },

	{ motorParentName = "LeftUpperLeg", motorName = "LeftHip", part0Name = "LowerTorso", part1Name = "LeftUpperLeg", limits = { UpperAngle = 60, TwistUpperAngle = 45, TwistLowerAngle = -45 } },
	{ motorParentName = "LeftLowerLeg", motorName = "LeftKnee", part0Name = "LeftUpperLeg", part1Name = "LeftLowerLeg", limits = { UpperAngle = 0, TwistUpperAngle = 5, TwistLowerAngle = -80 } },
	{ motorParentName = "LeftFoot", motorName = "LeftAnkle", part0Name = "LeftLowerLeg", part1Name = "LeftFoot", limits = { UpperAngle = 10, TwistUpperAngle = 5, TwistLowerAngle = -45 } },
}

return RAGDOLL_RIG
