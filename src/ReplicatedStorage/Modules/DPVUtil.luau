local DPVUtil = {}

local DEFAULT_MOVE_THRESHOLD = 0.5
local DEFAULT_TURN_THRESHOLD = 0.3
local DEFAULT_FORWARD_SPEED_SCALE = 13
local DEFAULT_MIN_FORWARD_SPEED = 0.5
local DEFAULT_MAX_FORWARD_SPEED = 2.0
local DEFAULT_BLEND_TIME = 0.2

local function clamp01(value)
	return math.clamp(value, 0, 1)
end

function DPVUtil.loadAnimationTracks(humanoid, animationsFolder, animationNames)
	local tracks = {}
	if not (humanoid and animationsFolder and animationNames) then
		return tracks
	end

	for _, animName in ipairs(animationNames) do
		local animObject = animationsFolder:FindFirstChild(animName)
		if animObject and animObject:IsA("Animation") then
			local track = humanoid:LoadAnimation(animObject)
			if animName == "Idle" then
				track.Priority = Enum.AnimationPriority.Action
			else
				track.Priority = Enum.AnimationPriority.Action2
			end
			tracks[animName] = track
		end
	end

	return tracks
end

function DPVUtil.stopAnimationTracks(tracks, blendTime)
	if not tracks then
		return
	end

	for _, track in pairs(tracks) do
		if track.IsPlaying then
			track:Stop(blendTime or 0)
		end
	end
end

function DPVUtil.destroyAnimationTracks(tracks)
	if not tracks then
		return {}
	end

	for _, track in pairs(tracks) do
		if track.IsPlaying then
			track:Stop()
		end
		track:Destroy()
	end

	return {}
end

function DPVUtil.updateDirectionalAnimations(tracks, movementSpeed, currentVelocity, rootPart, config)
	if not (tracks and rootPart) then
		return
	end

	local moveThreshold = config and config.moveThreshold or DEFAULT_MOVE_THRESHOLD
	local turnThreshold = config and config.turnThreshold or DEFAULT_TURN_THRESHOLD
	local forwardSpeedScale = config and config.forwardSpeedScale or DEFAULT_FORWARD_SPEED_SCALE
	local minForwardSpeed = config and config.minForwardSpeed or DEFAULT_MIN_FORWARD_SPEED
	local maxForwardSpeed = config and config.maxForwardSpeed or DEFAULT_MAX_FORWARD_SPEED
	local blendTime = config and config.blendTime or DEFAULT_BLEND_TIME

	local isMoving = movementSpeed > moveThreshold
	local localMovement = Vector3.zero
	if currentVelocity and currentVelocity.Magnitude > 1e-3 then
		localMovement = rootPart.CFrame:VectorToObjectSpace(currentVelocity.Unit)
	end

	if isMoving then
		if tracks.Idle and tracks.Idle.IsPlaying then
			tracks.Idle:Stop(blendTime)
		end

		if tracks.Forward and not tracks.Forward.IsPlaying then
			tracks.Forward:Play(blendTime, 1, 1)
		end

		if tracks.Forward and tracks.Forward.IsPlaying then
			local speedRatio = forwardSpeedScale > 0 and movementSpeed / forwardSpeedScale or 0
			tracks.Forward:AdjustSpeed(math.clamp(speedRatio, minForwardSpeed, maxForwardSpeed))
		end

		if localMovement.X < -turnThreshold then
			if tracks.Left and not tracks.Left.IsPlaying then
				tracks.Left:Play(blendTime, 1, 1)
			end
		else
			if tracks.Left and tracks.Left.IsPlaying then
				tracks.Left:Stop(blendTime)
			end
		end

		if localMovement.X > turnThreshold then
			if tracks.Right and not tracks.Right.IsPlaying then
				tracks.Right:Play(blendTime, 1, 1)
			end
		else
			if tracks.Right and tracks.Right.IsPlaying then
				tracks.Right:Stop(blendTime)
			end
		end
	else
		if tracks.Forward and tracks.Forward.IsPlaying then
			tracks.Forward:Stop(blendTime)
		end
		if tracks.Left and tracks.Left.IsPlaying then
			tracks.Left:Stop(blendTime)
		end
		if tracks.Right and tracks.Right.IsPlaying then
			tracks.Right:Stop(blendTime)
		end

		if tracks.Idle and not tracks.Idle.IsPlaying then
			tracks.Idle:Play(blendTime, 1, 1)
		end
	end
end

function DPVUtil.updateMotorSound(sound, state, speedRatio, deltaTime, config)
	if not sound then
		return state
	end

	local threshold = config and config.threshold or 0
	local minPitch = config and config.minPitch or 0.2
	local maxPitch = config and config.maxPitch or 1.6
	local responseTime = config and config.responseTime or 0

	local normalizedRatio = clamp01(speedRatio or 0)
	local targetVolume = normalizedRatio
	if normalizedRatio <= threshold then
		targetVolume = 0
	end

	local targetPitch = math.clamp(normalizedRatio, minPitch, maxPitch)

	state = state or {
		Volume = sound.Volume,
		Pitch = sound.PlaybackSpeed,
	}

	if deltaTime and responseTime and responseTime > 0 then
		local alpha = 1 - math.exp(-deltaTime / responseTime)
		state.Volume += (targetVolume - state.Volume) * alpha
		state.Pitch += (targetPitch - state.Pitch) * alpha
	else
		state.Volume = targetVolume
		state.Pitch = targetPitch
	end

	if state.Volume <= 0.01 and targetVolume == 0 then
		sound.Volume = 0
		if sound.IsPlaying then
			sound:Stop()
		end
	else
		if not sound.IsPlaying then
			sound:Play()
		end
		sound.Volume = clamp01(state.Volume)
		sound.PlaybackSpeed = math.clamp(state.Pitch, minPitch, maxPitch)
	end

	return state
end

return DPVUtil
