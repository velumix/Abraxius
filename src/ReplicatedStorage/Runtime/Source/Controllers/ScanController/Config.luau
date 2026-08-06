local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIColors = require(ReplicatedStorage.Modules.UI.UIColors)

local Config = {}

-- ========== NUMERIC CONSTANTS ==========
Config.FISH_SIDE_OFFSET_MULTIPLIER = 0.6
Config.ACTIVATION_DISTANCE = 55
Config.MIN_CURSOR_HIT_RADIUS = 26
Config.RADIUS_SEARCH = 300
Config.SCAN_HITBOX_MODIFIER = 90

-- ========== TIMING CONSTANTS ==========
Config.MOUSE_DELTA_SENSITIVITY = 1
Config.CURSOR_LOCK_THRESHOLD = 0.3
Config.SMART_CURSOR_LOCK_THRESHOLD = 0.1
Config.CURSOR_UPDATE_SPEED = 30
Config.CURSOR_LERP_SPEED = 60
Config.CURSOR_SIZE_LERP = 5
Config.RAYCAST_DISTANCE = 100
Config.RAYCAST_MAX_DISTANCE = 100
Config.SCAN_OCCLUSION_TRANSPARENCY = 0.6
Config.SCAN_PROBE_RADIUS = 4
Config.SCAN_RAYCAST_BUDGET = 24
Config.GAMEPAD_CURSOR_SPEED = 14
Config.GAMEPAD_CURSOR_DEADZONE = 0.18

-- ========== EFFECT TIMING ==========
Config.CONNECTION_TRAIL_PULSE_DURATION = 0.35
Config.CONNECTION_TRAIL_FADE_DURATION = 0.4
Config.CONNECTION_EFFECT_DELAY = 0.05
Config.PULSE_RING_DELAY_STEP = 0.15
Config.PULSE_RING_CREATE_DELAY = 0.08
Config.SPARKLE_DURATION_STEP = 0.05
Config.SPARKLE_DISTANCE = 75
Config.COMPLETION_EFFECT_DELAY = 0.05
Config.MOUSE_UNLOCK_DECREASE_RATE = 1.2
Config.MOUSE_UNLOCK_INCREASE_LIMIT = 1.5
Config.MOUSE_UNLOCK_THRESHOLD = 1.0
Config.MOUSE_SPEED_THRESHOLD = 2.5
Config.SCAN_INTERVAL_THRESHOLD = 0.5
Config.ENABLE_DELAY = 0.5
Config.ENABLE_INITIAL_WAIT = 1.5
Config.NO_TARGET_NOTIFY_COOLDOWN = 2
Config.CAMERA_LERP_SPEED = 10
Config.UIGRADIENT_LERP_SPEED = 8
Config.CONNECTION_SCORE_WEIGHT = 0.01
Config.CONNECTION_TRAIL_HEIGHT = 6
Config.CONNECTION_TRAIL_TRANSPARENCY = 0.6
Config.SCROLL_MULTIPLIER = 2
Config.ZOOM_MAX_MULTIPLIER = 6
Config.DISCOVERY_EFFECT_CLEANUP_DELAY = 0.8
Config.DISCOVERY_OVERLAY_TRANSPARENCY = 0.7
Config.DISCOVERY_BURST_STROKE_THICKNESS = 5
Config.DISCOVERY_BURST_STROKE_TRANSPARENCY = 0.2
Config.LAST_SCAN_LOCK_THRESHOLD = 2
Config.SKELETON_CLICK_COOLDOWN = 0.25
Config.SKELETON_CLICK_PADDING = 6
Config.SKELETON_STICK_DISTANCE = 32
Config.SKELETON_STICK_RELEASE_DISTANCE = 70
Config.SKELETON_EFFECT_SCALE = 0.85
Config.SKELETON_NODE_CLICK_SIZE_OFFSET = 12
Config.SKELETON_NODE_CLICK_STROKE_BOOST = 4
Config.SKELETON_NODE_GLOW_EXPAND = 0.4
Config.SKELETON_NODE_SPARK_COUNT = 8
Config.SKELETON_NODE_SPARK_DISTANCE = 0.45
Config.SKELETON_CONNECTION_RING_SIZE = 2.6
Config.SKELETON_CONNECTION_RING_DELAY = 0.1
Config.SKELETON_CONNECTION_SPARK_COUNT = 6
Config.SKELETON_CONNECTION_SPARK_DISTANCE = 0.55

Config.SHOULDER_LIMITS = {
	Yaw = { Min = math.rad(-180), Max = math.rad(90) },
	Pitch = { Min = math.rad(-90), Max = math.rad(90) }
}
Config.R15_HEAD_OFFSET = Vector3.new(0, 1.5, 0)
Config.HUMANOID_ROOT_PART_SIZE = Vector3.new(2, 2, 1)

-- ========== GUIDE MESSAGES ==========
Config.GUIDE_MESSAGES = {
	Start = "Click again to start scanning",
	SingleNode = "Connect to the highlighted node",
	MultipleNodes = "Connect to any highlighted node",
	Recommended = "Click the pulsing node to Begin",
	Progress = "Keep going! Select the next node",
	Default = "Select a node to continue"
}

Config.DEFAULT_GUIDE_MESSAGE = "Click the pulsing node!"

-- ========== NODE STYLING ==========
Config.NODE_STYLES = {
	Default = {
		Background = UIColors.ScanNodeDefault,
		BackgroundTransparency = 0.3,
		Stroke = UIColors.ScanNodeDefaultStroke,
		StrokeThickness = 2
	},
	Selected = {
		Background = UIColors.ScanNodeSelected,
		BackgroundTransparency = 0,
		Stroke = UIColors.ScanNodeSelectedStroke,
		StrokeThickness = 6
	},
	Connectable = {
		Background = UIColors.ScanNodeConnectable,
		BackgroundTransparency = 0,
		Stroke = UIColors.ScanNodeConnectableStroke,
		StrokeThickness = 5
	},
	Recommendation = {
		Background = UIColors.ScanNodeRecommendation,
		BackgroundTransparency = 0,
		Stroke = UIColors.ScanNodeRecommendationStroke,
		StrokeThickness = 7
	},
	Completed = {
		Background = UIColors.ScanNodeCompleted,
		BackgroundTransparency = 0.2,
		Stroke = UIColors.ScanNodeCompletedStroke,
		StrokeThickness = 3
	}
}

-- ========== PULSE CONFIGURATIONS ==========
Config.CONNECTABLE_PULSE = {
	OuterRingStartSize = UDim2.fromScale(2, 2),
	OuterRingEndSize = UDim2.fromScale(3.5, 3.5),
	OuterStrokeThickness = 12,
	OuterStrokeMinThickness = 4,
	InnerStrokeThickness = 8,
	InnerStrokeMaxThickness = 14,
	InnerStrokeMinTransparency = 0.2,
	GlowEndSize = UDim2.fromScale(1.8, 1.8),
	OuterDuration = 1,
	InnerDuration = 0.7,
	GlowDuration = 0.8
}

Config.RECOMMENDATION_PULSE = {
	MegaRingStartSize = UDim2.fromScale(2, 2),
	MegaRingEndSize = UDim2.fromScale(4, 4),
	MegaStrokeThickness = 16,
	MegaStrokeMinThickness = 4,
	InnerStrokeThickness = 10,
	InnerStrokeMaxThickness = 16,
	InnerStrokeMinTransparency = 0.2,
	OuterStrokeThickness = 14,
	OuterStrokeMaxThickness = 20,
	OuterStrokeMaxTransparency = 0.8,
	GlowEndSize = UDim2.fromScale(2, 2),
	MegaDuration = 1.2,
	InnerDuration = 0.7,
	OuterDuration = 0.6,
	GlowDuration = 0.8
}

-- ========== TWEEN CONFIGURATIONS ==========
Config.TOOL_TIP_TWEEN = TweenInfo.new(
	0.3,
	Enum.EasingStyle.Quad, 
	Enum.EasingDirection.Out
)

Config.CURSOR_TWEEN = TweenInfo.new(
	0.2, 
	Enum.EasingStyle.Quad, 
	Enum.EasingDirection.Out, 
	0, 
	true
)

Config.CONNECTION_POOF_TWEEN = TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
Config.CONNECTION_FADE_TWEEN = TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
Config.PULSE_RING_TWEEN = TweenInfo.new(0.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
Config.COMPLETION_BURST_TWEEN = TweenInfo.new(0.6, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
Config.COMPLETION_FADE_TWEEN = TweenInfo.new(0.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
Config.SPARKLE_TWEEN = TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

Config.DISCOVERY_OVERLAY_IN_TWEEN = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
Config.DISCOVERY_OVERLAY_OUT_TWEEN = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
Config.DISCOVERY_BURST_EXPAND_TWEEN = TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
Config.DISCOVERY_BURST_FADE_TWEEN = TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

Config.PULSE_SINE_TWEEN = function(duration)
	return TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
end

-- ========== TWEEN POSITIONS ==========
Config.TWEEN_POSITIONS = {
	Information = {
		Open = UDim2.new()
	}
}


Config.SCAN_ZOOM_FOV = 50
Config.FOV_TRANSITION_INFO = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Shoulder Constraints
Config.SHOULDER_MIN_YAW = -145
Config.SHOULDER_MAX_YAW = 110
Config.SHOULDER_MIN_PITCH = -110
Config.SHOULDER_MAX_PITCH = 110
Config.SHOULDER_MAX_ROLL = 38


-- Depth Of Field
Config.DOF_INTENSITY = 0.8
Config.DOF_RADIUS = 1.6
Config.DOF_TWEEN_INFO = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)


-- Locked Camera
Config.LOCKED_CAMERA_OFFSET = Vector3.new(2, 6, 6)
Config.ZOOM_STEP = 5
Config.MAX_EXTRA_ZOOM = 100

return Config
