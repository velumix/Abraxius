-- RagdollCorpse: turns a dying R6 character into a persistent floppy ragdoll "corpse" (MM2-style)
-- that stays on the map after the player respawns. This is the proven DevForum approach
-- ("Basic General Ragdoll Script" / "R6 Ragdoll with corpse"), adapted for this game.
--
-- HOW IT WORKS (and why this is the version that actually works):
--   * We do NOT clone the living body and ragdoll the clone. A fresh clone's Humanoid re-runs its
--     state machine and stands the body back up / makes it float and "dance" — that was the
--     float-and-freeze bug. Instead we MOVE the real dead character's parts into a new corpse Model,
--     so the thing that ragdolls is the actual body, already in its death pose.
--   * For each Motor6D: make two Attachments at the joint's C0 and C1, link them with a
--     BallSocketConstraint, then DISABLE the Motor6D (don't destroy it). Limits only on the neck.
--   * HumanoidRootPart.CanCollide = false — the HRP is a controller part; if it collides it props the
--     whole body up off the floor (this is what made the corpse "float"). The Head is set collidable
--     so the body has something to rest on. Gravity then pulls it straight down to the ground.
--   * SetNetworkOwner(nil) on every part so the SERVER simulates the physics (no client tug-of-war
--     stutter), then ChangeState(Ragdoll) + disable GettingUp so the Humanoid never stands it back up.
--   * No PlatformStand, no ChangeState(Physics), no anchoring timer, no manual velocity hacks. The
--     body simply falls and rests like any physics object, then stops on its own.
--   * After moving the parts out, the original character is emptied; eliminateHider lets Roblox
--     respawn the player fresh in the lobby, so you never see "two bodies" (one standing, one dead).
--   * Parts go in the "Corpse" collision group (registered in PlayerCollisionGroup): the body rests
--     on the map but passes through living players and other corpses.
--   * Corpses auto-clean after a lifetime; the total count is capped for performance.

local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local RagdollCorpse = {}

-- ===== config =====
local CORPSE_LIFETIME = 60      -- seconds a corpse stays before cleanup (0 = until round/manual clear)
local MAX_CORPSES = 12         -- cap concurrent corpses (oldest removed first) for performance
local CORPSE_GROUP = "Corpse"
local NECK_UPPER_ANGLE = 30    -- the head/neck gets a limit so it doesn't spin all the way around
local NECK_TWIST = 30
local REST_SPEED = 1.5         -- assembly speed (studs/s) under which a corpse counts as "come to rest"
local MIN_RAGDOLL_TIME = 2     -- seconds the body MUST ragdoll before the rest-anchor may engage. A
                               -- freshly-killed body standing still has ~zero velocity, so without
                               -- this floor the rest check passed INSTANTLY and anchored the corpse
                               -- upright ~0.3s after death — the "frozen standing statue" bug.
local SETTLE_CEILING = 8       -- hard cap (s): anchor by now even if something keeps it jittering

-- folder that holds all active corpses
local function corpsesFolder()
	local f = Workspace:FindFirstChild("Corpses")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Corpses"
		f.Parent = Workspace
	end
	return f
end

-- track spawn order so we can cull the oldest when over the cap
local active = {}  -- array of corpse Models, oldest first

local function cull()
	while #active > MAX_CORPSES do
		local oldest = table.remove(active, 1)
		if oldest then oldest:Destroy() end
	end
end

-- Convert one Motor6D into a BallSocketConstraint (the proven method). Attachments are built from the
-- joint's C0/C1 so each limb stays exactly where the rigid joint held it, now hinged. Only the neck
-- gets angle limits (so the head doesn't spin freely); the other joints swing loose, which is what
-- gives the natural floppy collapse. The Motor6D is DISABLED, not destroyed.
local function jointToSocket(joint)
	local p0, p1 = joint.Part0, joint.Part1
	if not p0 or not p1 then return end

	local a0 = Instance.new("Attachment")
	a0.CFrame = joint.C0
	a0.Parent = p0

	local a1 = Instance.new("Attachment")
	a1.CFrame = joint.C1
	a1.Parent = p1

	local socket = Instance.new("BallSocketConstraint")
	socket.Attachment0 = a0
	socket.Attachment1 = a1
	if p1.Name == "Head" or joint.Name == "Neck" then
		socket.LimitsEnabled = true
		socket.TwistLimitsEnabled = true
		socket.UpperAngle = NECK_UPPER_ANGLE
		socket.TwistLowerAngle = -NECK_TWIST
		socket.TwistUpperAngle = NECK_TWIST
	end
	socket.Parent = p0

	joint.Enabled = false  -- disable the rigid motor so the socket takes over (keep it, don't destroy)
end

-- Build a corpse from a dying character and leave it on the map. We MOVE the real parts into a new
-- Model (not a clone), ragdoll them, and let physics drop the body. Returns the corpse Model.
function RagdollCorpse.spawn(sourceChar)
	if not sourceChar then return end
	local hum = sourceChar:FindFirstChildOfClass("Humanoid")
	local hrp = sourceChar:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- New model to hold the corpse, independent of the player's respawn.
	local corpse = Instance.new("Model")
	corpse.Name = (sourceChar.Name or "Hider") .. "_Corpse"
	corpse.Parent = corpsesFolder()

	if hum then
		hum.BreakJointsOnDeath = false
		hum.RequiresNeck = false
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None  -- hide name/health bar
	end

	-- The HRP must not collide or it props the body upright (the "floating" bug). Do this BEFORE moving.
	hrp.CanCollide = false

	-- Walk the character's descendants: move top-level children into the corpse model, convert joints
	-- to sockets, rebuild accessory welds, make the Head collidable, and assign the Corpse group.
	for _, v in ipairs(sourceChar:GetDescendants()) do
		if v.Parent == sourceChar then
			v.Parent = corpse                     -- re-parent the real limb/part out of the character
		end
		if v:IsA("BasePart") then
			v.Anchored = false                    -- CRITICAL: a hider killed while using the position
			                                      -- Lock (FREEZE) has ANCHORED parts; an anchored corpse
			                                      -- ignores gravity and the topple impulse entirely and
			                                      -- just stands there frozen. Corpses must always be free.
			v.CanCollide = (v.Name ~= "HumanoidRootPart")
			v.CanQuery = false                    -- knife raycasts shouldn't snag on a corpse
			v.CanTouch = false
			pcall(function() v.CollisionGroup = CORPSE_GROUP end)
		end
		if v:IsA("Motor6D") then
			jointToSocket(v)
		elseif v.Name == "AccessoryWeld" and v:IsA("Weld") then
			-- keep hats/accessories attached: replace the animatable weld with a rigid WeldConstraint
			if v.Part0 and v.Part1 then
				local wc = Instance.new("WeldConstraint")
				wc.Part0 = v.Part0
				wc.Part1 = v.Part1
				wc.Parent = v.Parent
			end
			v.Enabled = false
		elseif v.Name == "Head" and v:IsA("BasePart") then
			v.CanCollide = true                   -- the body rests on its head/torso
		end
	end

	-- Strip scripts/tools that would animate or run logic on the corpse.
	for _, d in ipairs(corpse:GetDescendants()) do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Tool") then
			d:Destroy()
		end
	end
	local animate = corpse:FindFirstChild("Animate")
	if animate then animate:Destroy() end

	-- Server owns the physics so there's no client/server tug-of-war (stutter), THEN put the Humanoid
	-- into the Ragdoll state and stop it from getting back up. Order matters: ownership before state.
	for _, d in ipairs(corpse:GetDescendants()) do
		if d:IsA("BasePart") then
			pcall(function() d:SetNetworkOwner(nil) end)
		end
	end
	local corpseHum = corpse:FindFirstChildOfClass("Humanoid")
	if corpseHum then
		pcall(function() corpseHum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false) end)
		pcall(function() corpseHum:ChangeState(Enum.HumanoidStateType.Ragdoll) end)
	end

	-- track + cap
	table.insert(active, corpse)
	cull()

	-- TOPPLE IMPULSE: a hider killed while standing still has zero momentum, and a balanced upright
	-- body can stay standing on its socketed legs indefinitely — nothing starts the fall. Give the
	-- torso a small HORIZONTAL push in a random direction plus a gentle tumble so every corpse visibly
	-- collapses, each in a different direction. Strictly no upward (+Y) force (an up-shoved body hangs
	-- in the air); any inherited upward momentum is clipped so gravity always pulls it straight down.
	local torso = corpse:FindFirstChild("Torso") or corpse:FindFirstChild("HumanoidRootPart")
	if torso and torso:IsA("BasePart") then
		local dir = math.rad(math.random(0, 360))
		local inherited = torso.AssemblyLinearVelocity
		inherited = Vector3.new(inherited.X, math.min(inherited.Y, 0), inherited.Z)
		torso.AssemblyLinearVelocity = inherited
			+ Vector3.new(math.cos(dir) * math.random(6, 10), 0, math.sin(dir) * math.random(6, 10))
		torso.AssemblyAngularVelocity = Vector3.new(
			math.random(-8, 8), math.random(-4, 4), math.random(-8, 8))
	end

	-- PERFORMANCE: once the body has actually come to REST on the ground, anchor its parts so the
	-- BallSocketConstraints stop being simulated/replicated for the rest of the corpse's lifetime. We
	-- poll the torso's assembly speed and only anchor once it's genuinely slow (below REST_SPEED),
	-- confirmed over a brief moment so we never freeze it mid-fall/mid-bounce. A hard ceiling anchors
	-- it anyway if it somehow keeps jittering, so no corpse simulates forever. This is the single
	-- biggest lag saver for the corpse system (up to ~72 live constraints across the cap otherwise).
	task.spawn(function()
		-- Let the body actually ragdoll first. Without this minimum, a corpse that spawns standing
		-- still (speed ~0) passes the rest check on the very first poll and gets anchored upright.
		task.wait(MIN_RAGDOLL_TIME)
		local deadline = os.clock() + SETTLE_CEILING
		while corpse and corpse.Parent and table.find(active, corpse) do
			local part = corpse:FindFirstChild("Torso") or corpse:FindFirstChild("HumanoidRootPart")
			if not part then break end
			if part.AssemblyLinearVelocity.Magnitude < REST_SPEED then
				task.wait(0.25)  -- confirm it stays slow (not just passing through ~0 at a bounce apex)
				if part and part.Parent and part.AssemblyLinearVelocity.Magnitude < REST_SPEED then
					for _, d in ipairs(corpse:GetDescendants()) do
						if d:IsA("BasePart") then d.Anchored = true end
					end
					return
				end
			end
			if os.clock() >= deadline then
				for _, d in ipairs(corpse:GetDescendants()) do
					if d:IsA("BasePart") then d.Anchored = true end
				end
				return
			end
			task.wait(0.15)
		end
	end)

	-- auto-clean after the lifetime
	if CORPSE_LIFETIME > 0 then
		Debris:AddItem(corpse, CORPSE_LIFETIME)
		task.delay(CORPSE_LIFETIME + 0.1, function()
			local idx = table.find(active, corpse)
			if idx then table.remove(active, idx) end
		end)
	end

	return corpse
end

-- Remove all corpses (call at round end / cleanup).
function RagdollCorpse.clearAll()
	local f = Workspace:FindFirstChild("Corpses")
	if f then
		for _, c in ipairs(f:GetChildren()) do c:Destroy() end
	end
	table.clear(active)
end

return RagdollCorpse
