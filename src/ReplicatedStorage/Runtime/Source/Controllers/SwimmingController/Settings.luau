local Settings = {}

-- Camera and FOV Settings
Settings.Default = 70
Settings.MaxFov = 90

-- World Environment Settings
Settings.SeaLevel = 14.7 -- Y position of water surface
Settings.MaxDepth = 200 -- Maximum depth for pressure calculations

-- Swimming Physics Settings
Settings.SwimmingSpeed = 6 -- Base swimming speed (studs/second)
Settings.Acceleration = 6 -- How quickly to reach target speed
Settings.Deceleration = 3 -- How quickly to stop when no input

-- Advanced Physics Settings
Settings.DragCoefficient = 0.15 -- Underwater drag resistance
Settings.BuoyancyMultiplier = 1.0 -- How strong buoyancy force is
Settings.PressureDepthScale = 0.35 -- How much depth affects movement speed

-- Constraint Force Limits
Settings.MaxForce = 200000 -- Maximum linear force
Settings.MaxVelocity = 25 -- Maximum swimming velocity
Settings.MaxTorque = 200000 -- Maximum rotational force
Settings.MaxAngularVelocity = 25 -- Maximum rotation speed
Settings.Responsiveness = 20 -- How responsive constraints are

-- Oxygen and Breathing System
Settings.OxygenCapacity = 100 -- Maximum oxygen level
Settings.OxygenDepletionRate = 0.5 -- Oxygen consumed per second
Settings.BreathHoldDuration = 60 -- Seconds before oxygen depletion starts
Settings.DamageFromOxygenLoss = 5 -- Health damage when out of oxygen

-- Animation Settings
Settings.AnimationBlendTime = 0.2 -- Time to blend between animations
Settings.DirectionalThreshold = 0.3 -- Movement threshold for directional animations

-- Performance Settings
Settings.PhysicsUpdateRate = 60 -- Physics updates per second
Settings.AnimationUpdateRate = 30 -- Animation updates per second
Settings.OptimizationDistance = 100 -- Distance to start reducing update rates

-- Debug Settings (set to true for development)
Settings.ShowDebugInfo = false
Settings.ShowConstraintVisuals = false
Settings.LogPhysicsUpdates = false

return Settings