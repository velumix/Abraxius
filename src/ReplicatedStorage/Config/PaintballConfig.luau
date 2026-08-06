-- Shared constants and types for the paintball gun system.
-- Lives in ReplicatedStorage so both the server service and client controller can read it.

export type PaintballArgs = {
	origin: Vector3,
	direction: Vector3,
	t0: number,
	shotId: string,
	sender: Player?,
	color: Color3,
}

export type PaintballHitInfo = {
	shotId: string,
	hitPart: BasePart,
	normal: Vector3?,
}

export type PaintballImpactInfo = {
	position: Vector3,
	normal: Vector3,
	target: Model?,
	hitPart: BasePart?,
	color: Color3?,
}

local PaintballConfig = {
	-- Projectile visuals / physics
	ProjectileSpeed = 180, -- studs/sec
	ProjectileMaxDistance = 300,
	ProjectileRadius = 0.25,
	ProjectileColor = Color3.fromRGB(255, 60, 60),

	-- Combat tuning
	FireRate = 0.25, -- seconds between shots
	HitCooldown = 0.1, -- seconds between accepted hits per player
	Damage = 50,

	-- Aim assist (auto-aim toward Painting Boss / minions)
	AutoAimAngle = 15, -- degrees; targets within this cone from the screen center are snapped to
	AutoAimMaxDistance = 400, -- studs
	AutoAimRequiresLineOfSight = true,
	AutoAimStickiness = 1.8, -- multiplier; once locked, keep target until it leaves this wider cone
	AutoAimTargetLerp = 12, -- higher = snappier, lower = smoother lock movement
	AutoAimPredictionEnabled = true,
	AutoAimMaxLeadTime = 1.5, -- seconds; bounds bad estimates after replication spikes
	AutoAimMaxTargetSpeed = 60, -- studs/sec; boss movement is normally 8-12
	AutoAimVelocityResponse = 14, -- smoothing speed for replicated CFrame motion
	AutoAimVelocityMemory = 0.18, -- seconds before an unmoving target is treated as stopped

	-- Auto-fire when locked on. Kept per-input so it feels fair/natural on every device.
	AutoFireOnLock = true,
	AutoFireOnLockKeyboardMouse = true,
	AutoFireOnLockGamepad = true,
	AutoFireOnLockTouch = true,
	AutoFireLockAcquireTime = 0.08, -- seconds target must stay locked before auto-fire starts
	AutoFireLockReleaseGrace = 0.12, -- seconds we keep lock across tiny LOS/camera flickers
	AutoFireRequiresClearShot = true, -- raycast from muzzle to target before firing

	-- Server validation
	MaxShotOriginDelta = 15, -- max studs the reported muzzle can be from the player's HRP
	HitPathTolerance = 12, -- max studs a victim can be off the recorded flight path
	HitMaxTravel = 300, -- max studs a paintball can travel for a valid hit
	HitWindow = 2, -- seconds a shot remains valid for hit validation
}

return PaintballConfig
