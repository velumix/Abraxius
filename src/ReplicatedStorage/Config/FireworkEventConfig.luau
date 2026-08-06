local FireworkEventConfig = {
	-- Asset location
	ASSET_ROOT = "ReplicatedStorage.Assets.Events.Fireworks",

	-- Event timing
	DEFAULT_DURATION = 120,
	TRANSITION_DURATION = 4,
	FIREWORK_INTERVAL = 0.16,
	SPARKLER_INTERVAL = 0.35,
	LAUNCH_SPEED = 180,

	-- Spawn area (fireworks spawn around map center at these heights)
	FIREWORK_HEIGHT = { Min = 220, Max = 420 },
	SPARKLER_HEIGHT = { Min = 2, Max = 8 },
	SPAWN_RADIUS = 800,

	-- Burst density
	FIREWORK_EMIT_COUNT = 60,
	SPARKLER_EMIT_COUNT = 12,

	-- How long a single burst lives before it can be reused
	BURST_LIFETIME = 4,

	-- Lighting effect tag for cleanup
	LIGHTING_TAG = "FireworkEventLighting",
	VFX_FOLDER_NAME = "FireworkEventVfx",

	-- Names of firework templates inside Vfx
	TEMPLATES = {
		"Firework1",
		"Firework2",
		"Firework3",
		"Firework4",
		"Firework5",
		"Firework6",
		"Firework7",
		"Firework8",
		"Firework9",
	},

	-- Separate lingering spark template that plays at the burst point after each firework.
	SPARKFALL_TEMPLATE = "Sparkfall",
	SPARKFALL_EMIT_COUNT = 25,
	SPARKFALL_DELAY = 0.1,

	-- Sunset lighting overrides: bright, warm, late-evening look so fireworks are still
	-- visible but the map isn't washed out in full daylight or too dark at night.
	SUNSET_LIGHTING = {
		ClockTime = 17.5,
		Ambient = Color3.fromRGB(130, 110, 90),
		OutdoorAmbient = Color3.fromRGB(220, 170, 110),
		Brightness = 3.5,
		GlobalShadows = true,
		ShadowSoftness = 0.35,
	},

	-- Warm orange-pink atmosphere for a sunset feel.
	SUNSET_ATMOSPHERE = {
		Density = 0.25,
		Offset = 0.2,
		Color = Color3.fromRGB(255, 170, 115),
		Decay = Color3.fromRGB(255, 140, 90),
		Glare = 0.6,
		Haze = 0.25,
	},

	SOUND_IDS = {
		Launch = "128139595268642",
		Explosion = "100559751053348",
	},

	SOUND_VOLUME = {
		Launch = 0.9,
		Explosion = 1,
	},

	SOUND_ROLLOFF = {
		MinDistance = 40,
		MaxDistance = 10000,
	},
}

return FireworkEventConfig
