local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local ContextActionService = game:GetService("ContextActionService")

local Client = Players.LocalPlayer
local Mouse = Client:GetMouse()

local KnifeFolder = ReplicatedStorage:WaitForChild("Knife")
local PackagesFolder = ReplicatedStorage:WaitForChild("Packages")

local KnifeUtil = KnifeFolder.Util
local KnifeAnimations = KnifeFolder.Animations
local KnifeSounds = KnifeFolder.Sounds
local KnifeRemotes = KnifeFolder.Remotes
local KnifeSkinManager = require(ReplicatedStorage:WaitForChild("KnifeSkinManager"))
local GamepadConfig = require(ReplicatedStorage:WaitForChild("GamepadConfig"))
local Constants = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Constants"))
local RIG_TYPE = Constants.RIG_TYPE

local Observers = require(PackagesFolder.Observers)
local Trove = require(PackagesFolder.Trove)

local GetPlayerFromPart = require(KnifeUtil.Hooks.GetPlayerFromPart)
local KnifeProjectileArgsType = require(KnifeUtil.Types.KnifeProjectileArgs)

const CHARGE_TIME = 0.25

-- R15 throw windup felt too snappy compared to when throw actually becomes available.
-- Keep legacy speed on R6, but slow R15 to half speed for better sync/feel.
const CHARGE_PLAYBACK_SPEED_R6 = 3
const CHARGE_PLAYBACK_SPEED_R15 = 1.5

local function getChargePlaybackSpeed(): number
	if RIG_TYPE == "R15" then
		return CHARGE_PLAYBACK_SPEED_R15
	end
	return CHARGE_PLAYBACK_SPEED_R6
end

const PROJECTILE_SPEED = 200
const PROJECTILE_SPIN_SPEED = -25
const PROJECTILE_MAX_DISTANCE = 1000
const PROJECTILE_HIT_RADIUS = 0.65

-- A tight, blade-shaped hitbox for stabs. The real knife blade is much smaller than the 3-stud Handle,
-- so we attach a transparent part that only covers the blade area and scan that each frame.
local STAB_HITBOX_SIZE = Vector3.new(0.6, 1.6, 0.2)
local STAB_HITBOX_OFFSET = CFrame.new(0, 0.55, 0.4)

type KnifeState = "Idle" | "Charging" | "Charged" | "Stabbing"
type KnifeProjectileArgs = KnifeProjectileArgsType.KnifeProjectileArgs

local function playOneShotSound(parent: Instance, soundTemplate: Sound)
	local sound = soundTemplate:Clone()
	local sfx = game:GetService("SoundService"):FindFirstChild("SFX")
	if sfx then sound.SoundGroup = sfx end  -- obey the Settings SFX slider
	sound.Parent = parent
	sound.PlayOnRemove = true
	sound:Destroy()
end

-- Find the point the player is actually aiming at, SKIPPING fully-transparent parts
-- (Transparency >= 1). The map has invisible border walls; if the camera is zoomed out THROUGH a
-- wall, Mouse.Hit lands on that invisible wall, so a throw would fly into the wall instead of toward
-- the intended target behind it. We re-cast past each invisible hit until we reach something visible
-- (or run out of attempts), and fall back to a far point along the camera ray if nothing visible is
-- found. `ignoreChar` is the thrower's own character so we don't aim at ourselves.
-- Resolve the world point the player is aiming at. `screenPos` (optional Vector2) overrides where on
-- screen to cast from — used by mobile to aim at a tapped location; on PC it defaults to the mouse.
-- Either way we skip fully-transparent parts (invisible map walls) so a zoomed-out camera through a
-- wall, or a tap over a wall, doesn't make the knife fly into the wall.
local function getAimPoint(ignoreChar: Instance?, screenPos: Vector2?): Vector3
	local camera = workspace.CurrentCamera
	local ray
	if screenPos then
		-- A tapped position from a touch InputObject is in tap/GUI space (measured from the true top-left,
		-- i.e. it INCLUDES the topbar inset). ScreenPointToRay is the inset-AWARE conversion, so we pass the
		-- raw tap coordinates straight in and it maps them correctly. (Using ViewportPointToRay here — which
		-- ignores the inset — made throws land off by the topbar height; ScreenPointToRay is the right
		-- function for tap coordinates and needs no manual inset math.)
		ray = camera:ScreenPointToRay(screenPos.X, screenPos.Y)
	else
		-- PC mouse path: GetMouseLocation is inset-excluded, matching ViewportPointToRay.
		local mousePos = UserInputService:GetMouseLocation()
		ray = camera:ViewportPointToRay(mousePos.X, mousePos.Y)
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	local ignored = {}
	if ignoreChar then table.insert(ignored, ignoreChar) end
	params.FilterDescendantsInstances = ignored

	local origin = ray.Origin
	local direction = ray.Direction * PROJECTILE_MAX_DISTANCE
	for _ = 1, 12 do  -- cap iterations so a wall of invisible parts can't loop forever
		local result = workspace:Raycast(origin, direction, params)
		if not result or not result.Instance then
			break  -- nothing (visible) hit; fall through to the far-point fallback
		end
		local part = result.Instance
		if part:IsA("BasePart") and part.Transparency >= 1 then
			-- invisible (e.g. a map border) — skip it and cast again past it
			table.insert(ignored, part)
			params.FilterDescendantsInstances = ignored
		else
			return result.Position  -- real, visible surface the player is aiming at
		end
	end
	-- nothing visible in range: aim at a far point straight down the camera ray
	return origin + direction
end

-- GAMEPAD aim: cast through the on-screen gamepad RETICLE, skipping invisible map-border walls just
-- like getAimPoint. This is the canonical third-person-shooter "two-step" aim: find the world point the
-- player is looking at (camera -> reticle screen point), then performThrow aims the knife from the
-- HANDLE toward that point. The handle is offset from the camera, so aiming the handle straight ahead
-- (viewport center) misses where the reticle visually sits.
--
-- KEY FIX: the gamepad reticle is NOT at viewport center -- Roblox's default 3rd-person camera draws it
-- ABOVE center, and UserInputService:GetMouseLocation() returns that exact reticle position on a live
-- gamepad (verified on-device: reticle Y=347 vs viewport-center Y=521 on a 1042px viewport). The old
-- code cast through viewport center, ~174px below the reticle, so throws flew low (toward the player's
-- feet) in 3rd person but looked fine in shift lock (where the camera centers the reticle). We now cast
-- through GetMouseLocation when the player is actually on a gamepad.
--
-- We GATE on the active input being a gamepad: GetMouseLocation returns the reticle on console / active
-- controller, but on a PC-with-controller that's idling on mouse it would return the stale mouse cursor.
-- When not actively on gamepad we fall back to viewport center (the previous behavior).
local function isOnGamepad(): boolean
	local ok, pref = pcall(function() return UserInputService.PreferredInput end)
	if ok and pref ~= nil then
		return pref == Enum.PreferredInput.Gamepad
	end
	local lit = UserInputService:GetLastInputType()
	return lit == Enum.UserInputType.Gamepad1 or lit == Enum.UserInputType.Gamepad2
		or lit == Enum.UserInputType.Gamepad3 or lit == Enum.UserInputType.Gamepad4
end

local function getGamepadAimPoint(ignoreChar: Instance?): Vector3
	local camera = workspace.CurrentCamera
	local vp = camera.ViewportSize
	local ray
	local reticle = isOnGamepad() and UserInputService:GetMouseLocation() or nil
	-- Use the reticle only if it's a valid on-screen position. GetMouseLocation can return (-1, -1) when
	-- the cursor isn't currently positioned on screen; casting through that would aim into nowhere, so we
	-- fall back to viewport center in that case (and whenever the player isn't actively on a gamepad).
	local reticleValid = reticle ~= nil
		and reticle.X >= 0 and reticle.Y >= 0
		and reticle.X <= vp.X and reticle.Y <= vp.Y
	if reticleValid then
		ray = camera:ViewportPointToRay(reticle.X, reticle.Y)
	else
		ray = camera:ViewportPointToRay(vp.X / 2, vp.Y / 2)
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	local ignored = {}
	if ignoreChar then table.insert(ignored, ignoreChar) end
	params.FilterDescendantsInstances = ignored

	local origin = ray.Origin
	local direction = ray.Direction * PROJECTILE_MAX_DISTANCE
	for _ = 1, 12 do
		local result = workspace:Raycast(origin, direction, params)
		if not result or not result.Instance then
			break
		end
		local part = result.Instance
		if part:IsA("BasePart") and part.Transparency >= 1 then
			table.insert(ignored, part)
			params.FilterDescendantsInstances = ignored
		else
			return result.Position
		end
	end
	return origin + direction
end

local function knifeAnimationsFolder(): Instance
	if RIG_TYPE == "R15" then
		local r15 = KnifeAnimations:FindFirstChild("R15")
		if r15 then
			return r15
		end
	end
	return KnifeAnimations
end

local function loadAnimations(animator: Animator): { [string]: AnimationTrack }
	local animations = {}

	for _, animation in knifeAnimationsFolder():QueryDescendants(">Animation") do
		local track = animator:LoadAnimation(animation)
		track.Priority = Enum.AnimationPriority.Action
		animations[animation.Name] = track
	end

	return animations
end

local function getProjectileCFrame(position: Vector3, direction: Vector3): CFrame
	return CFrame.fromMatrix(position, Vector3.yAxis:Cross(direction), direction)
end

-- Emitter classes that count as "baked VFX" to copy onto the thrown projectile (mirrors the server's
-- applyKnifeSkinVisual content rule). A skin like the Vampire Scythe authors these directly on its
-- template Handle (ParticleEmitters under attachments, lightning emitters, etc.).
local PROJECTILE_EMITTER_CLASSES = {
	ParticleEmitter = true, Beam = true, Trail = true,
	PointLight = true, SpotLight = true, SurfaceLight = true,
	Fire = true, Smoke = true, Sparkles = true,
}

-- Copy a skin's baked emitter VFX from its template Handle onto the thrown projectile part, so a skin
-- with built-in handle VFX (e.g. the Vampire Scythe's lightning/particles) shows that effect while the
-- knife travels — matching the in-hand look. We use the SAME content-based rule the server uses: copy
-- an Attachment only if it CONTAINS an emitter, or an emitter sitting directly on the handle. The base
-- knife's standard parts (SlashTrail + its empty Attachment0/Attachment1, the Mesh, Decal, Sounds) are
-- the baseline and are skipped, so we never duplicate them. `baseline` is the projectile's own existing
-- children (it's cloned from the default KnifeProjectile, which carries the base parts).
local function applyBakedProjectileVFX(projectile: BasePart, skinId: string?)
	if not skinId or skinId == "" then return end
	local template = KnifeSkinManager.getTemplate(skinId)
	local srcHandle = template and template:FindFirstChild("Handle")
	if not srcHandle then return end
	local baseline = {}
	for _, c in ipairs(projectile:GetChildren()) do
		baseline[c.Name] = true
	end
	local function hasEmitter(inst)
		if PROJECTILE_EMITTER_CLASSES[inst.ClassName] then return true end
		for _, d in ipairs(inst:GetDescendants()) do
			if PROJECTILE_EMITTER_CLASSES[d.ClassName] then return true end
		end
		return false
	end
	for _, child in ipairs(srcHandle:GetChildren()) do
		local copyIt = false
		if child:IsA("Attachment") then
			copyIt = hasEmitter(child)
		elseif PROJECTILE_EMITTER_CLASSES[child.ClassName] then
			copyIt = not baseline[child.Name]
		end
		if copyIt then
			local vfxClone = child:Clone()
			vfxClone.Parent = projectile
			-- emit an immediate burst per emitter so the effect shows the instant the knife is thrown
			-- (Rate-based emitters would otherwise take a moment to build up a visible cloud).
			for _, em in ipairs(vfxClone:GetDescendants()) do
				if em:IsA("ParticleEmitter") then
					em:Emit(math.max(5, math.floor(em.Rate)))
				end
			end
			if vfxClone:IsA("ParticleEmitter") then
				vfxClone:Emit(math.max(5, math.floor(vfxClone.Rate)))
			end
		end
	end
end

local function destroyKnifeProjectile(projectile: BasePart)
	if not projectile.Parent then
		return
	end

	for _, descendant in ipairs(projectile:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			descendant.Enabled = false
			descendant:Clear()
		elseif descendant:IsA("Trail") or descendant:IsA("Beam") then
			descendant.Enabled = false
		end
	end

	projectile:Destroy()
end

local function getProjectileContainer(): Folder
	local container = workspace:FindFirstChild("KnifeProjectiles")
	if not container then
		container = Instance.new("Folder")
		container.Name = "KnifeProjectiles"
		container.Parent = workspace
	end
	return container :: Folder
end

local function getKnifeProjectileTemplate(skinTexture: string?, effectId: string?, meshId: string?, meshScale: Vector3?, meshTextureId: string?, skinId: string?, parent: Instance?)
	local projectile = script.KnifeProjectile:Clone()
	projectile.Parent = parent or workspace
	projectile.Anchored = true
	projectile.CanCollide = false


	-- match the equipped skin: repaint the projectile's Decal with the skin's texture
	if skinTexture and skinTexture ~= "" then
		local decal = projectile:FindFirstChildWhichIsA("Decal")
		if decal then
			decal.Texture = skinTexture
		end
	end

	-- match the equipped skin's MESH (so a skin with a different shape, e.g. Candy Seer, is thrown
	-- with that shape and not the default knife shape)
	if meshId and meshId ~= "" then
		local mesh = projectile:FindFirstChildOfClass("SpecialMesh")
		if mesh then
			mesh.MeshId = meshId
			if meshScale then mesh.Scale = meshScale end
			if meshTextureId then mesh.TextureId = meshTextureId end
		end
	end

	-- match the equipped mutation: clone its VFX from KnifeVFX onto the projectile and weld it
	if effectId and effectId ~= "" and effectId ~= "none" then
		local vfxFolder = ReplicatedStorage:FindFirstChild("KnifeVFX")
		local vfxTemplate = vfxFolder and vfxFolder:FindFirstChild(effectId)
		if vfxTemplate then
			local vfx = vfxTemplate:Clone()
			for _, d in ipairs(vfx:GetChildren()) do
				if d:IsA("WeldConstraint") then d:Destroy() end
			end
			vfx.CFrame = projectile.CFrame
			vfx.Parent = projectile
			local w = Instance.new("WeldConstraint")
			w.Part0 = projectile
			w.Part1 = vfx
			w.Parent = vfx
			-- the emitters are Rate-based, so they'd take a moment to build up a visible cloud;
			-- emit an immediate burst so the effect shows the instant the knife is thrown.
			for _, em in ipairs(vfx:GetDescendants()) do
				if em:IsA("ParticleEmitter") then
					em:Emit(math.max(5, math.floor(em.Rate)))
				end
			end
		end
	end

	-- match the equipped skin's BAKED handle VFX (e.g. the Vampire Scythe's lightning/particles). These
	-- are authored on the skin template's Handle (separate from KnifeVFX mutations), so the thrown knife
	-- carries the same built-in effect it has in-hand. Rebuilt from the shared template by skinId, so it
	-- works for both the local thrower and remote viewers (who receive skinId over the remote).
	applyBakedProjectileVFX(projectile, skinId)

	return projectile
end

local function startThrow(args: KnifeProjectileArgs, callback: ((RaycastResult) -> ())?)
	local thrower = args.sender or Client

	if not thrower.Character then
		return
	end

	local trove = Trove.new()
	local projectile = getKnifeProjectileTemplate(args.skinTexture, args.effectId, args.meshId, args.meshScale, args.meshTextureId, args.skinId)
	trove:Add(function()
		destroyKnifeProjectile(projectile)
	end)
	projectile:PivotTo(getProjectileCFrame(args.x0, args.dir))

	local root = thrower.Character.PrimaryPart
	if root then
		local throwSound = trove:Clone(KnifeSounds.Throw)

		trove:Add(throwSound.Ended:Connect(function()
			throwSound:Destroy()
		end))

		throwSound.Parent = root
		throwSound:Play()
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	-- exclude the thrower, and the spawned coins folder so thrown knives pass through coins
	-- (coins are also CanQuery=false, but exclude the folder too as a safety net)
	local excludeList = { thrower.Character }
	local coinsFolder = workspace:FindFirstChild("SpawnedCoins")
	if coinsFolder then table.insert(excludeList, coinsFolder) end
	table.insert(excludeList, projectile)
	raycastParams.FilterDescendantsInstances = excludeList

	local origin = args.x0
	local lastPosition = projectile.Position

	trove:Add(RunService.RenderStepped:Connect(function(dt)
		local nextCFrame = (projectile.CFrame + PROJECTILE_SPEED * dt * args.dir)
			* CFrame.Angles(PROJECTILE_SPIN_SPEED * dt, 0, 0)

		local nextPosition = nextCFrame.Position
		local raycast = workspace:Spherecast(
			lastPosition,
			PROJECTILE_HIT_RADIUS,
			nextPosition - lastPosition,
			raycastParams
		)

		if raycast then
			if callback then
				callback(raycast)
			end

			if not GetPlayerFromPart(raycast.Instance)  then
				local knifeProjectileHitClone = getKnifeProjectileTemplate(args.skinTexture, args.effectId, args.meshId, args.meshScale, args.meshTextureId, args.skinId)
				knifeProjectileHitClone:PivotTo(getProjectileCFrame(raycast.Position, args.dir))
				playOneShotSound(knifeProjectileHitClone, KnifeSounds.Hit)
				task.delay(2, destroyKnifeProjectile, knifeProjectileHitClone)
			end

			trove:Clean()
			return
		end

		if (nextPosition - origin).Magnitude > PROJECTILE_MAX_DISTANCE then
			trove:Clean()
			return
		end

		projectile:PivotTo(nextCFrame)
		lastPosition = nextPosition
	end))

	return trove:WrapClean()
end

local function setupKnife(tool: Tool, animations: { [string]: AnimationTrack })
	local knifeTrove = Trove.new()
	local oldCursor = Mouse.Icon

	local handle = tool:WaitForChild("Handle") :: BasePart
	local state: KnifeState = "Idle"
	local stabIndex = 0
	local mouseDown = false   -- is M1 currently held? (drives auto stab->throw continuation, PC)
	local beginCharge         -- forward-declared so resetStab can continue a held click into a throw
	local queuedThrow = false -- (mobile) player tapped THROW mid-stab; arm the throw as soon as the stab ends
	local armThrow            -- forward-declared (mobile): arms the throw + starts the windup

	local chargeTrove = knifeTrove:Extend()
	local hitDebounces = {}

	local stabAnimations = {}
	do
		local i = 1
		while animations["GenericStab" .. i] do
			stabAnimations[#stabAnimations + 1] = animations["GenericStab" .. i]
			i += 1
		end
	end

	local function setState(newState: KnifeState)
		state = newState
	end

	local function stopAllAnimations()
		for _, track in animations do
			track:Stop()
		end
	end

	local function resetStab()
		if state == "Stabbing" then
			setState("Idle")
			table.clear(hitDebounces)
			-- If the player is STILL holding M1 when the stab finishes, they're trying to throw — not
			-- stab again. Flow straight into the charge so releasing performs a throw. (Previously a
			-- held click during the stab did nothing, then registered as a fresh stab on release,
			-- causing a frustrating stab loop.)
			if mouseDown and beginCharge then
				beginCharge()
			-- MOBILE equivalent QoL: if the player tapped THROW mid-stab, that press was queued instead of
			-- ignored. Now that the stab is done, arm the throw immediately so the tap isn't wasted.
			elseif queuedThrow and armThrow then
				queuedThrow = false
				armThrow()
			end
		end
	end

	beginCharge = function()
		if state ~= "Idle" then
			return
		end

		chargeTrove:Clean()
		chargeTrove:Add(task.delay(CHARGE_TIME, function()
			setState("Charging")

			local chargeTrack = animations.ThrowCharge

			local chargePlaybackSpeed = getChargePlaybackSpeed()
			chargeTrack.Looped = false
			chargeTrack:Play(nil, nil, chargePlaybackSpeed)

			chargeTrove:Add(function()
				if chargeTrack.IsPlaying then
					chargeTrack:Stop()
				end

				if state ~= "Stabbing" then
					setState("Idle")
				end
			end)

			chargeTrove:Add(chargeTrack.Stopped:Connect(function()
				if state ~= "Charging" then
					return
				end

				setState("Charged")

				chargeTrack:Play(0, 1, 0)
				chargeTrack.TimePosition = math.max(0, chargeTrack.Length - 0.001)
			end))

			-- SAFETY FALLBACK: the transition to "Charged" above relies on the ThrowCharge animation's
			-- Stopped event firing. On mobile / laggy clients the animation can fail to load, play, or
			-- emit Stopped at all — which left the player stuck in "Charging" forever (armed but unable to
			-- throw, frozen in the windup pose). If we're still "Charging" after a safe window, force the
			-- "Charged" state so tapping always throws. (When the animation works normally, Stopped fires
			-- first and this no-ops.)
			local expected = chargeTrack.Length > 0 and (chargeTrack.Length / chargePlaybackSpeed) or 0
			local fallbackAfter = math.max(0.6, expected + 0.25)
			chargeTrove:Add(task.delay(fallbackAfter, function()
				if state == "Charging" then
					setState("Charged")
					-- freeze on the windup's last frame too, so the pose matches the normal path
					pcall(function()
						chargeTrack:Play(0, 1, 0)
						chargeTrack.TimePosition = math.max(0, chargeTrack.Length - 0.001)
					end)
				end
			end))
		end))
	end

	local function performStab()
		if state ~= "Idle" then
			return
		end

		setState("Stabbing")

		-- Notify the server of the swing itself (not just a landed hit) so game modes like
		-- Reverse Race can charge a life for a swing that misses / hits a prop or decoy.
		local swingRemote = KnifeRemotes:FindFirstChild("KnifeSwing")
		if swingRemote then
			swingRemote:FireServer()
		end

		local count = #stabAnimations
		local pick = 1
		if count > 1 then
			pick = math.random(count)
			if pick == stabIndex then
				pick = (pick % count) + 1
			end
		end
		stabIndex = pick
		local track = stabAnimations[pick]
		if track then
			track:Play()
		end
	end

	local function performThrow(aimScreenPos: Vector2?, useGamepadAim: boolean?)
		if state ~= "Charged" then
			return
		end

		local origin = handle.Position
		-- aim at where the player is actually pointing, skipping invisible walls (so zooming the camera
		-- out through a wall doesn't make the knife fly into that wall). Ignore our own character.
		-- On mobile, aimScreenPos is the tapped location; on PC (mouse) it's nil -> uses the mouse
		-- cursor; on a GAMEPAD (useGamepadAim) we aim from the viewport center (the crosshair).
		local aimPoint
		if useGamepadAim then
			aimPoint = getGamepadAimPoint(Client.Character)
		else
			aimPoint = getAimPoint(Client.Character, aimScreenPos)
		end
		local direction = (aimPoint - origin).Unit

		-- read the equipped knife's look so the thrown projectile matches it:
		--   skinTexture = the Handle's Decal texture (set per skin by the server)
		--   effectId    = the name of the equipped mutation VFX (the "KnifeVFX" child's source)
		--   mesh*       = the Handle's SpecialMesh shape, so skins with a different mesh (e.g. Candy
		--                 Seer) keep their shape when thrown, not just their texture
		local skinTexture, effectId, skinId
		local decal = handle:FindFirstChildWhichIsA("Decal")
		if decal then skinTexture = decal.Texture end
		effectId = tool:GetAttribute("EffectId")  -- set by the server's applyKnifeVFX (nil if no mutation)
		skinId = tool:GetAttribute("SkinId")      -- set by the server's applyKnifeSkinVisual (nil = default knife)

		local meshId, meshScale, meshTextureId
		local handleMesh = handle:FindFirstChildOfClass("SpecialMesh")
		if handleMesh then
			meshId = handleMesh.MeshId
			meshScale = handleMesh.Scale
			meshTextureId = handleMesh.TextureId
		end

		local projectileArgs: KnifeProjectileArgs = {
			t0 = workspace:GetServerTimeNow(),
			x0 = origin,
			dir = direction,
			skinTexture = skinTexture,
			effectId = effectId,
			meshId = meshId,
			meshScale = meshScale,
			meshTextureId = meshTextureId,
			skinId = skinId,
		}

		KnifeRemotes.RenderKnifeProjectile:FireServer(projectileArgs)
		local cleanup = startThrow(projectileArgs, function(raycastResult: RaycastResult)
			if raycastResult and GetPlayerFromPart(raycastResult.Instance) then
				KnifeRemotes.KnifeHit:FireServer("throw", raycastResult.Instance)
				GamepadConfig.playHaptic(Enum.HapticEffectType.GameplayCollision)  -- rumble on a landed throw (gamepad only)
			end
		end)

		if cleanup then
			knifeTrove:Add(cleanup)
		end

		setState("Idle")
		chargeTrove:Clean()
	end

	for _, track in stabAnimations do
		knifeTrove:Add(track.Stopped:Connect(resetStab))
	end

	-- Blade-only stab hitbox. Size is driven by Attachment0/Attachment1 so it works for any knife or
	-- sword using the same handle convention; falls back to the defaults if those are missing.
	local att0 = handle:FindFirstChild("Attachment0") :: Attachment?
	local att1 = handle:FindFirstChild("Attachment1") :: Attachment?

	local hitboxSize, hitboxOffset
	if att0 and att1 then
		local center = (att0.Position + att1.Position) / 2
		local length = (att0.Position - att1.Position).Magnitude
		hitboxSize = Vector3.new(math.max(handle.Size.X, 0.6), math.max(length + 0.3, 0.6), 0.2)
		hitboxOffset = CFrame.new(center)
	else
		hitboxSize = STAB_HITBOX_SIZE
		hitboxOffset = STAB_HITBOX_OFFSET
	end

	local stabHitbox = Instance.new("Part")
	stabHitbox.Name = "StabHitbox"
	stabHitbox.Size = hitboxSize
	stabHitbox.Transparency = 1
	stabHitbox.CanCollide = false
	stabHitbox.CanTouch = false
	stabHitbox.CanQuery = true
	stabHitbox.Massless = true
	stabHitbox.CastShadow = false
	stabHitbox.CFrame = handle.CFrame * hitboxOffset
	stabHitbox.Parent = handle

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = stabHitbox
	weld.Parent = stabHitbox

	knifeTrove:Add(stabHitbox)

	knifeTrove:Add(RunService.Heartbeat:Connect(function()
		if state ~= "Stabbing" then
			return
		end
		if not stabHitbox.Parent then
			return
		end

		for _, part in ipairs(workspace:GetPartsInPart(stabHitbox)) do
			local player = GetPlayerFromPart(part)
			if player and player ~= Client and not hitDebounces[player] then
				hitDebounces[player] = true
				KnifeRemotes.KnifeHit:FireServer("stab", part)
				GamepadConfig.playHaptic(Enum.HapticEffectType.GameplayCollision)  -- rumble on a successful stab (gamepad only)
			end
		end
	end))


	knifeTrove:Add(UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			mouseDown = true
			beginCharge()
		end
	end))

	knifeTrove:Add(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		mouseDown = false

		if state == "Charged" then
			performThrow()
		elseif state == "Idle" then
			performStab()
		end
		-- NOTE: if state is "Stabbing" or "Charging" here, we do nothing on release. A held click is
		-- handled by resetStab() (stab->charge continuation); a charging click resolves on its own.

		chargeTrove:Clean()
	end))

	-- ===== MOBILE controls =====
	-- The PC handlers above use the mouse. Mobile has no mouse and the seeker's backpack (where the
	-- default tool button lives) is hidden, so we build our own controls:
	--   * Tap anywhere in the world  -> stab (default behavior), UNLESS throw is armed.
	--   * A dedicated on-screen THROW button -> plays the windup/charge (same as HOLDING LMB on PC),
	--     arming the throw. The next tap anywhere then throws the knife AT that tapped location.
	-- This keeps aiming location-based (not player-targeted), which suits a hide-and-seek game.
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		local throwArmed = false  -- has the player pressed THROW and is waiting to tap a target spot?

		-- build the mobile UI (its own ScreenGui, independent of the hidden backpack CoreGui)
		local gui = Instance.new("ScreenGui")
		gui.Name = "KnifeMobileControls"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.DisplayOrder = 20
		gui.Parent = Client:WaitForChild("PlayerGui")

		local throwBtn = Instance.new("TextButton")
		throwBtn.Name = "ThrowButton"
		throwBtn.AnchorPoint = Vector2.new(1, 1)
		-- sit on the right side, above the default jump button
		throwBtn.Position = UDim2.new(1, -45, 1, -205)  -- nudged slightly up & left so it clears the jump button on iPads
		throwBtn.Size = UDim2.new(0, 110, 0, 110)
		throwBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
		throwBtn.BackgroundTransparency = 0.25
		throwBtn.AutoButtonColor = true
		throwBtn.Text = "THROW"
		throwBtn.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
		throwBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		throwBtn.TextScaled = true
		throwBtn.Parent = gui
		local btnCorner = Instance.new("UICorner"); btnCorner.CornerRadius = UDim.new(1, 0); btnCorner.Parent = throwBtn
		local btnStroke = Instance.new("UIStroke"); btnStroke.Color = Color3.fromRGB(255, 215, 90); btnStroke.Thickness = 3; btnStroke.Parent = throwBtn
		local btnPad = Instance.new("UIPadding")
		btnPad.PaddingTop = UDim.new(0, 32); btnPad.PaddingBottom = UDim.new(0, 32)
		btnPad.PaddingLeft = UDim.new(0, 14); btnPad.PaddingRight = UDim.new(0, 14)
		btnPad.Parent = throwBtn

		local function setArmedVisual(armed)
			if armed == "queued" then
				-- the player tapped THROW mid-stab; we've queued it and will arm as soon as the stab ends
				throwBtn.Text = "THROW QUEUED…"
				throwBtn.BackgroundColor3 = Color3.fromRGB(90, 70, 0)
				btnStroke.Color = Color3.fromRGB(255, 235, 150)
			elseif armed then
				throwBtn.Text = "TAP ANYWHERE TO THROW"
				throwBtn.BackgroundColor3 = Color3.fromRGB(120, 90, 0)
				btnStroke.Color = Color3.fromRGB(255, 235, 150)
			else
				throwBtn.Text = "THROW"
				throwBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
				btnStroke.Color = Color3.fromRGB(255, 215, 90)
			end
		end

		-- arms the throw and starts the windup (assigned to the forward-declared armThrow so resetStab can
		-- trigger it when a queued-during-stab press resolves).
		armThrow = function()
			throwArmed = true
			setArmedVisual(true)
			beginCharge()           -- runs the full windup -> ends in "Charged", exactly like holding LMB
		end

		local function disarm()
			-- also clears a queued-during-stab throw, so tapping THROW while it's queued cancels cleanly
			if not throwArmed and not queuedThrow then return end
			throwArmed = false
			queuedThrow = false
			mouseDown = false
			setArmedVisual(false)
			-- ALWAYS cancel the windup, whatever state we're in. This must be unconditional: if the player
			-- taps THROW again during the brief pre-charge delay (state still "Idle", the charge timer
			-- scheduled but not yet fired), a state-gated clean would SKIP cleanup and leave an orphaned
			-- timer that later forces "Charged" while disarmed — freezing the knife (can't throw, can't
			-- re-arm). Cleaning unconditionally cancels any pending/active windup in every case.
			chargeTrove:Clean()
			if state ~= "Stabbing" then setState("Idle") end
		end

		-- THROW button: arm the throw + play the windup. Tapping it again while armed (or while queued)
		-- cancels (so a mis-press isn't a dead end). If pressed MID-STAB, queue it and auto-arm the
		-- instant the stab finishes (mobile equivalent of PC's held-click->throw continuation).
		knifeTrove:Add(throwBtn.Activated:Connect(function()
			if throwArmed or queuedThrow then
				disarm()
				return
			end
			if state == "Stabbing" then
				-- mid-stab: don't ignore the press — queue it so it fires when the stab ends
				queuedThrow = true
				setArmedVisual("queued")
				return
			end
			if state ~= "Idle" then return end  -- mid-charge/charged already: ignore until settled
			-- NOTE: unlike PC (which uses mouseDown to flow a held stab into a charge), mobile uses explicit
			-- arm/disarm + the queuedThrow flag, so we deliberately do NOT set mouseDown here.
			armThrow()
		end))

		-- Taps: throw at the tapped spot if armed, otherwise stab.
		--
		-- We do our OWN tap recognition off the raw touch InputBegan/Changed/Ended instead of using
		-- UserInputService.TouchTap. TouchTap is a single-finger gesture that the engine SUPPRESSES while
		-- another touch is already dragging (the movement joystick) or while panning the camera — so a
		-- player holding the joystick to move literally could not tap to stab (they had to stop, tap, then
		-- move again). Raw touch InputBegan fires for EVERY new finger independently of the joystick finger,
		-- so a second finger tapping the world registers even while moving — letting the player stab and
		-- walk simultaneously.
		--
		-- To keep the two behaviors we DO want from TouchTap, we filter:
		--   * gpe (gameProcessedEvent) is true when the touch began on a GuiObject (THROW button, jump
		--     button, the joystick area, etc.), so UI/joystick touches never stab.
		--   * we treat a touch as a TAP (stab/throw) only if the finger barely moved and was released
		--     quickly; a larger/longer drag is a camera pan and is ignored (panning shouldn't stab),
		--     exactly like TouchTap behaved.
		local TAP_MOVE_TOLERANCE = 12   -- px of travel still considered a tap (not a camera-pan drag)
		local TAP_MAX_DURATION = 0.4    -- seconds held still considered a tap
		-- per-finger tracking so a joystick/camera finger never gets confused with the tapping finger
		local touchStarts = {}          -- [InputObject] = { pos = Vector2, t = clock, moved = boolean }

		local function handleTap(tapPos: Vector2?)
			if throwArmed then
				-- Only act once the windup has actually finished (state == "Charged"). A tap during windup
				-- ("Charging") is ignored and stays armed, so the throw isn't silently lost.
				if state == "Charged" then
					performThrow(tapPos)   -- throw toward where they tapped
					throwArmed = false
					mouseDown = false
					setArmedVisual(false)
				end
			else
				-- default behavior: a tap stabs
				if state == "Idle" then
					performStab()
				end
			end
		end

		knifeTrove:Add(UserInputService.InputBegan:Connect(function(input, gpe)
			if input.UserInputType ~= Enum.UserInputType.Touch then return end
			if gpe then return end  -- began on UI (THROW/jump button, joystick) — not a world tap
			touchStarts[input] = {
				pos = Vector2.new(input.Position.X, input.Position.Y),
				t = os.clock(),
				moved = false,
			}
		end))

		knifeTrove:Add(UserInputService.InputChanged:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.Touch then return end
			local rec = touchStarts[input]
			if not rec then return end
			-- if the finger travels past the tolerance it's a drag (camera pan), not a tap
			local now = Vector2.new(input.Position.X, input.Position.Y)
			if (now - rec.pos).Magnitude > TAP_MOVE_TOLERANCE then
				rec.moved = true
			end
		end))

		knifeTrove:Add(UserInputService.InputEnded:Connect(function(input, gpe)
			if input.UserInputType ~= Enum.UserInputType.Touch then return end
			local rec = touchStarts[input]
			touchStarts[input] = nil
			if not rec then return end                 -- touch we never tracked (started on UI)
			if rec.moved then return end               -- it was a drag/pan, not a tap
			if (os.clock() - rec.t) > TAP_MAX_DURATION then return end  -- too long to be a tap
			-- a genuine quick, stationary tap: use the release position as the aim point (same tap/GUI
			-- space TouchTap used, which ScreenPointToRay in getAimPoint expects)
			handleTap(Vector2.new(input.Position.X, input.Position.Y))
		end))

		-- drop any in-flight touch tracking when the knife is cleaned up
		knifeTrove:Add(function()
			table.clear(touchStarts)
		end)

		-- clean the UI up with the rest of the knife
		knifeTrove:Add(function()
			gui:Destroy()
		end)
	end

	-- ===== CONSOLE / GAMEPAD controls =====
	-- Matches Murder Mystery 2's console scheme: the knife is auto-equipped (the backpack is locked),
	-- and the RIGHT TRIGGER (ButtonR2 = RT on Xbox / R2 on PlayStation) drives stab + throw, aimed with
	-- the camera (the player points the camera/crosshair, exactly like MM2 with Shift Lock):
	--   * TAP the trigger            -> stab (state was Idle, released before the windup armed).
	--   * HOLD the trigger           -> windup/charge (same as holding LMB on PC).
	--   * RELEASE a held trigger     -> throw toward the camera's center.
	-- This reuses the exact same beginCharge / performThrow / performStab functions as PC, so the throw
	-- logic is identical; only the INPUT source differs. We bind through ContextActionService so the
	-- trigger is claimed only while a knife is equipped (and released cleanly with the knife).
	--
	-- Aim: performThrow(nil, true) aims from the viewport CENTER via getGamepadAimPoint. This is correct
	-- on BOTH a real console AND a PC with a controller connected. (We deliberately do NOT rely on
	-- GetMouseLocation here: it only reports screen-center on console; on PC-with-controller it returns
	-- the real mouse position, which would misaim the throw.)
	--
	-- Gate: bind for gamepad-capable clients that are NOT touch (so a phone with a paired controller
	-- still uses the on-screen THROW button path above, and PC keeps mouse). GamepadEnabled covers
	-- console and any PC/handheld with a controller connected.
	if UserInputService.GamepadEnabled and not UserInputService.TouchEnabled then
		-- unique action name per knife instance so binds never collide (a new knife each round). pcall
		-- around GetDebugId in case it's unavailable; fall back to a random suffix.
		local okId, debugId = pcall(function() return tool:GetDebugId() end)
		local THROW_ACTION = "KnifeThrow_" .. (okId and debugId or tostring(math.random(1, 1000000000)))

		local function onTriggerAction(_actionName, inputState, _inputObject)
			if inputState == Enum.UserInputState.Begin then
				-- press: start the windup (mirrors PC's MouseButton1 InputBegan). padDown reuses the
				-- mouseDown flag so resetStab's held-input -> charge continuation works identically.
				mouseDown = true
				beginCharge()
			elseif inputState == Enum.UserInputState.End then
				-- release: throw if the windup armed, otherwise it was a quick tap -> stab (mirrors PC's
				-- MouseButton1 InputEnded).
				mouseDown = false
				if state == "Charged" then
					performThrow(nil, true)   -- gamepad aim: cast from the viewport center (crosshair)
				elseif state == "Idle" then
					performStab()
				end
				chargeTrove:Clean()
			end
			return Enum.ContextActionResult.Sink
		end

		-- bind the right trigger (R2 is the documented MM2 throw trigger). The key comes from
		-- GamepadConfig so it's changeable in one place. createTouchButton=false: we never want CAS to
		-- draw its own on-screen button (that's the mobile path's job, and this branch is non-touch anyway).
		ContextActionService:BindAction(THROW_ACTION, onTriggerAction, false, GamepadConfig.Keys.KnifeThrow)

		-- release the binding when the knife is unequipped/destroyed, so the trigger isn't left captured.
		knifeTrove:Add(function()
			ContextActionService:UnbindAction(THROW_ACTION)
		end)
	end

	knifeTrove:Add(function()
		stopAllAnimations()
		setState("Idle")
		Mouse.Icon = oldCursor
	end)

	playOneShotSound(handle, KnifeSounds.Equip)
	Mouse.Icon = "rbxasset://textures/GunCursor.png"

	return knifeTrove:WrapClean()
end

-- ===== DragonBlade custom idle =====
-- While the DragonBlade knife is equipped, override the player's normal idle with a custom idle
-- animation. It plays at Movement priority (so it beats the default Idle-priority idle) and is gated
-- to only run while the character is standing still, so it never fights the walk / jump / fall
-- animations or the Action-priority knife stab/throw. Local-only setup; a self-played animation still
-- replicates to other clients, so everyone sees the custom idle.
local DRAGONBLADE_SKIN_ID = "dragonblade"
local DRAGONBLADE_IDLE_ID = "rbxassetid://133410740016629"

local IDLE_BLOCK_STATES = {
	[Enum.HumanoidStateType.Jumping] = true,
	[Enum.HumanoidStateType.Freefall] = true,
	[Enum.HumanoidStateType.FallingDown] = true,
	[Enum.HumanoidStateType.Climbing] = true,
	[Enum.HumanoidStateType.Seated] = true,
	[Enum.HumanoidStateType.GettingUp] = true,
	[Enum.HumanoidStateType.Ragdoll] = true,
	[Enum.HumanoidStateType.PlatformStanding] = true,
	[Enum.HumanoidStateType.Dead] = true,
}

local function shouldPlayDragonIdle(humanoid: Humanoid): boolean
	if humanoid.Health <= 0 then
		return false
	end
	if humanoid.MoveDirection.Magnitude > 0.05 then
		return false  -- walking / running: let the default movement animation show
	end
	local ok, state = pcall(function()
		return humanoid:GetState()
	end)
	if ok and IDLE_BLOCK_STATES[state] then
		return false  -- jumping / falling / climbing / seated: let the default animation show
	end
	return true
end

local function setupDragonBladeIdle(tool: Tool, humanoid: Humanoid, animator: Animator)
	local trove = Trove.new()

	local function isDragonBlade(): boolean
		return tool:GetAttribute("SkinId") == DRAGONBLADE_SKIN_ID
	end

	local started = false
	local function start()
		if started then
			return
		end
		started = true

		local anim = Instance.new("Animation")
		anim.AnimationId = DRAGONBLADE_IDLE_ID
		local idleTrack = animator:LoadAnimation(anim)
		idleTrack.Looped = true
		idleTrack.Priority = Enum.AnimationPriority.Movement
		trove:Add(function()
			pcall(function()
				idleTrack:Stop(0.15)
			end)
			idleTrack:Destroy()
			anim:Destroy()
		end)

		trove:Add(RunService.Heartbeat:Connect(function()
			if shouldPlayDragonIdle(humanoid) then
				if not idleTrack.IsPlaying then
					idleTrack:Play(0.2)
				end
			elseif idleTrack.IsPlaying then
				idleTrack:Stop(0.2)
			end
		end))
	end

	if isDragonBlade() then
		start()
	else
		-- the SkinId attribute can replicate a beat after the tool is equipped/tagged
		trove:Add(tool:GetAttributeChangedSignal("SkinId"):Connect(function()
			if isDragonBlade() then
				start()
			end
		end))
	end

	return trove:WrapClean()
end

Observers.observeLocalCharacter(function(character)
	local trove = Trove.new()
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local animator = humanoid:WaitForChild("Animator") :: Animator
	local animations = loadAnimations(animator)

	trove:Add(Observers.observeTag("Knife", function(instance)
		if not instance:IsA("Tool") then
			return
		end

		local cleanupKnife = setupKnife(instance, animations)
		local cleanupIdle = setupDragonBladeIdle(instance, humanoid, animator)
		return function()
			if cleanupKnife then
				cleanupKnife()
			end
			if cleanupIdle then
				cleanupIdle()
			end
		end
	end, { character }))

	return trove:WrapClean()
end)

KnifeFolder.Remotes.RenderKnifeProjectile.OnClientEvent:Connect(function(projectileArgs: KnifeProjectileArgs)
	if projectileArgs.sender == Client then
		return
	end

	startThrow(projectileArgs)
end)
