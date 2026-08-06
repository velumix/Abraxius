local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local KillEffectManager = require(ReplicatedStorage:WaitForChild("KillEffectManager"))

local KillEffectApplier = {}

local VFX_DURATION = 3
local R6_PARTS = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg", "HumanoidRootPart" }
local VFX_CLASSES = {
	ParticleEmitter = true, Beam = true, Trail = true,
	Smoke = true, Fire = true, Sparkles = true,
	PointLight = true, SpotLight = true, SurfaceLight = true, Sound = true,
}

local function assetsFolder()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets then return nil end
	return assets:FindFirstChild("KIllEffects") or assets:FindFirstChild("KillEffects")
end

local function getTemplate(def)
	local folder = assetsFolder()
	if not folder then return nil end
	local direct = folder:FindFirstChild(def.vfx) or folder:FindFirstChild(def.name)
	if direct then return direct end
	local want = string.lower(def.vfx or "")
	for _, c in ipairs(folder:GetChildren()) do
		if string.lower(c.Name) == want then return c end
	end
	return nil
end

local function primaryPart(rig)
	return rig:FindFirstChild("Torso") or rig:FindFirstChild("HumanoidRootPart") or rig:FindFirstChildWhichIsA("BasePart")
end

local function playEffectSound(corpse, def)
	local soundId = def and def.soundId
	if type(soundId) ~= "string" or soundId == "" then
		return
	end
	local host = primaryPart(corpse)
	if not host then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = "KillEffectSound"
	sound.SoundId = soundId
	sound.Volume = 1
	sound.RollOffMaxDistance = 90
	sound.Parent = host
	pcall(function()
		sound:Play()
	end)
	Debris:AddItem(sound, 8)
end

local function transferVFX(template, corpse)
	local attMap = {}
	local cloned = {}
	local function dstFor(partName)
		return corpse:FindFirstChild(partName) or primaryPart(corpse)
	end
	for _, partName in ipairs(R6_PARTS) do
		local src = template:FindFirstChild(partName)
		local dst = src and dstFor(partName)
		if src and dst then
			for _, ch in ipairs(src:GetChildren()) do
				if ch:IsA("Attachment") then
					local existing = dst:FindFirstChild(ch.Name)
					if existing and existing:IsA("Attachment") then
						attMap[ch] = existing
					else
						local n = ch:Clone()
						n.Parent = dst
						attMap[ch] = n
					end
				end
			end
		end
	end
	for _, partName in ipairs(R6_PARTS) do
		local src = template:FindFirstChild(partName)
		local dst = src and dstFor(partName)
		if src and dst then
			for _, ch in ipairs(src:GetChildren()) do
				if VFX_CLASSES[ch.ClassName] then
					local n = ch:Clone()
					if n:IsA("Beam") or n:IsA("Trail") then
						n.Attachment0 = attMap[ch.Attachment0] or n.Attachment0
						n.Attachment1 = attMap[ch.Attachment1] or n.Attachment1
					end
					n.Parent = dst
					table.insert(cloned, n)
				end
			end
		end
	end
	local bodyPartSet = {}
	for _, n in ipairs(R6_PARTS) do bodyPartSet[n] = true end
	local templatePivot = template:GetPivot()
	local corpsePivot = corpse:GetPivot()
	for _, child in ipairs(template:GetChildren()) do
		if not bodyPartSet[child.Name] and not child:IsA("Humanoid") and (child:IsA("BasePart") or child:IsA("Model")) then
			local n = child:Clone()
			n:PivotTo(corpsePivot * (templatePivot:Inverse() * child:GetPivot()))
			if n:IsA("BasePart") then
				n.Anchored = true
				n.CanCollide = false
				n.CanQuery = false
				n.CanTouch = false
			end
			for _, p in ipairs(n:GetDescendants()) do
				if p:IsA("BasePart") then
					p.Anchored = true
					p.CanCollide = false
					p.CanQuery = false
					p.CanTouch = false
				end
			end
			n.Parent = corpse
			table.insert(cloned, n)
			Debris:AddItem(n, VFX_DURATION + 2)
		end
	end
	return cloned
end

local function activate(root, def, duration)
	duration = duration or VFX_DURATION
	local toggled = {}
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("ParticleEmitter") then
			local n = d:GetAttribute("EmitCount")
			if typeof(n) == "number" and n > 0 then
				d.Enabled = false
				d:Emit(n)
			else
				d.Enabled = true
				table.insert(toggled, d)
			end
		elseif d:IsA("Beam") or d:IsA("Trail") or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles") then
			d.Enabled = true
			table.insert(toggled, d)
		elseif d:IsA("Sound") then
			pcall(function() d:Play() end)
		end
	end
	if def and def.effectType == "freeze" then
		for _, p in ipairs(root:GetDescendants()) do
			if p:IsA("BasePart") then p.Anchored = true end
		end
	end
	task.delay(duration, function()
		for _, d in ipairs(toggled) do
			if d and d.Parent then d.Enabled = false end
		end
	end)
end

local BALLOON_COUNT = 8
local BALLOON_LIFETIME = 4.5
local BALLOON_COLORS = {
	Color3.fromRGB(255, 70, 70),
	Color3.fromRGB(70, 140, 255),
	Color3.fromRGB(90, 220, 110),
	Color3.fromRGB(255, 210, 70),
	Color3.fromRGB(255, 120, 220),
	Color3.fromRGB(170, 110, 255),
	Color3.fromRGB(70, 220, 230),
	Color3.fromRGB(255, 150, 60),
}

local function balloonTemplate()
	local folder = assetsFolder()
	return folder and folder:FindFirstChild("Balloons")
end

local function spawnOneBalloon(template, originCF, color, duration, parent)
	local b = template:Clone()
	local primary = b:FindFirstChild("Balloon") or b:FindFirstChildWhichIsA("BasePart")
	if not primary then b:Destroy() return end
	b.PrimaryPart = primary

	local spread = 1.5
	local offset = Vector3.new((math.random() - 0.5) * spread, (math.random() - 0.5) * spread, (math.random() - 0.5) * spread)
	b:PivotTo((originCF + offset) * CFrame.Angles(math.random() * 6.2832, math.random() * 6.2832, math.random() * 6.2832))

	for _, p in ipairs(b:GetDescendants()) do
		if p:IsA("BasePart") then
			if p.Name ~= "Cylinder.005" then p.Color = color end
			p.Anchored = false
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Massless = (p ~= primary)
			if p ~= primary then
				local w = Instance.new("WeldConstraint")
				w.Part0 = primary
				w.Part1 = p
				w.Parent = primary
			end
		end
	end

	b.Parent = parent
	pcall(function() primary:SetNetworkOwner(nil) end)

	local dir = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5)
	if dir.Magnitude < 0.05 then dir = Vector3.new(1, 0, 0) end
	dir = dir.Unit
	primary.AssemblyLinearVelocity = dir * (16 + math.random() * 12) + Vector3.new(0, 10 + math.random() * 10, 0)
	primary.AssemblyAngularVelocity = Vector3.new((math.random() - 0.5) * 5, (math.random() - 0.5) * 5, (math.random() - 0.5) * 5)

	local att = Instance.new("Attachment")
	att.Parent = primary
	local force = Instance.new("VectorForce")
	force.Attachment0 = att
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.ApplyAtCenterOfMass = true
	force.Force = Vector3.new(0, primary.AssemblyMass * Workspace.Gravity * 1.07, 0)
	force.Parent = primary

	task.delay(math.max(0, duration - 0.6), function()
		if not b.Parent then return end
		for _, p in ipairs(b:GetDescendants()) do
			if p:IsA("BasePart") then
				TweenService:Create(p, TweenInfo.new(0.6), { Transparency = 1 }):Play()
			end
		end
	end)
end

local function spawnBalloons(originCF, duration)
	local template = balloonTemplate()
	if not template then return nil end
	duration = duration or BALLOON_LIFETIME
	local folder = Instance.new("Folder")
	folder.Name = "BalloonBurst"
	folder.Parent = Workspace
	for i = 1, BALLOON_COUNT do
		local color = BALLOON_COLORS[((i - 1) % #BALLOON_COLORS) + 1]
		spawnOneBalloon(template, originCF, color, duration, folder)
	end
	Debris:AddItem(folder, duration + 0.5)
	return folder
end

local FX_GROUP = "Corpse"

local function corpseAnchorPos(corpse)
	local part = primaryPart(corpse)
	return (part and part.Position) or corpse:GetPivot().Position
end

local function groundYUnder(pos, ignoreList)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = ignoreList or {}
	local hit = Workspace:Raycast(pos + Vector3.new(0, 5, 0), Vector3.new(0, -60, 0), rp)
	if hit then
		return hit.Position.Y
	end
	return pos.Y - 3
end

local function makeFXPart(name, size, cframe, color, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	pcall(function() p.CollisionGroup = FX_GROUP end)
	p.Parent = parent
	return p
end

local function rotateAbout(cf, pivotPos, axis, ang)
	local piv = CFrame.new(pivotPos)
	return piv * CFrame.fromAxisAngle(axis, ang) * piv:Inverse() * cf
end

local function cloneEffectModel(name)
	local folder = assetsFolder()
	local template = folder and folder:FindFirstChild(name)
	if not template then return nil end
	local m = template:Clone()
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			pcall(function() p.CollisionGroup = FX_GROUP end)
		end
	end
	return m
end

local function worldAABB(inst)
	local minV = Vector3.new(math.huge, math.huge, math.huge)
	local maxV = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in ipairs(inst:GetDescendants()) do
		if p:IsA("BasePart") then
			local cf, sz = p.CFrame, p.Size
			for xs = -1, 1, 2 do
				for ys = -1, 1, 2 do
					for zs = -1, 1, 2 do
						local w = cf * Vector3.new(xs * sz.X / 2, ys * sz.Y / 2, zs * sz.Z / 2)
						minV = Vector3.new(math.min(minV.X, w.X), math.min(minV.Y, w.Y), math.min(minV.Z, w.Z))
						maxV = Vector3.new(math.max(maxV.X, w.X), math.max(maxV.Y, w.Y), math.max(maxV.Z, w.Z))
					end
				end
			end
		end
	end
	return minV, maxV
end

local function placeOnGround(model, centerPos, groundY, extraYaw)
	local rot = model:GetPivot().Rotation
	if extraYaw and extraYaw ~= 0 then
		rot = CFrame.Angles(0, extraYaw, 0) * rot
	end
	model:PivotTo(CFrame.new(centerPos.X, 1000, centerPos.Z) * rot)
	local minV, maxV = worldAABB(model)
	local center = (minV + maxV) / 2
	model:PivotTo(model:GetPivot() + Vector3.new(centerPos.X - center.X, groundY - minV.Y, centerPos.Z - center.Z))
end

function KillEffectApplier._hauntedDoor(centerPos, corpse, faceYaw)
	local model = cloneEffectModel("HauntedDoor")
	if not model then
		return
	end
	model.Name = "HauntedDoorFX"

	local ignore = { model }
	if corpse then table.insert(ignore, corpse) end
	local corpsesF = Workspace:FindFirstChild("Corpses")
	if corpsesF then table.insert(ignore, corpsesF) end
	local groundY = groundYUnder(centerPos, ignore)

	placeOnGround(model, centerPos, groundY, faceYaw or 0)
	model.Parent = Workspace

	local door = model:FindFirstChild("Door")
	local doorAuthored = door and door:GetPivot()
	local hingePos, hingeAxis, closedAngle, openAngle = nil, nil, 0, 0
	local function setDoorAngle(ang)
		if door and door.Parent and doorAuthored and hingeAxis then
			door:PivotTo(rotateAbout(doorAuthored, hingePos, hingeAxis, ang))
		end
	end
	if door then
		hingePos = doorAuthored.Position
		local ax = doorAuthored.YVector
		ax = Vector3.new(ax.X, 0, ax.Z)
		if ax.Magnitude < 0.05 then
			ax = doorAuthored.ZVector
			ax = Vector3.new(ax.X, 0, ax.Z)
		end
		hingeAxis = ax.Unit
		local function doorYExtent(a)
			local rel = rotateAbout(doorAuthored, hingePos, hingeAxis, a) * doorAuthored:Inverse()
			local mnY, mxY = math.huge, -math.huge
			for _, p in ipairs(door:GetDescendants()) do
				if p:IsA("BasePart") then
					local cf, sz = rel * p.CFrame, p.Size
					for xs = -1, 1, 2 do
						for ys = -1, 1, 2 do
							for zs = -1, 1, 2 do
								local wy = (cf * Vector3.new(xs * sz.X / 2, ys * sz.Y / 2, zs * sz.Z / 2)).Y
								mnY = math.min(mnY, wy)
								mxY = math.max(mxY, wy)
							end
						end
					end
				end
			end
			return mxY - mnY
		end
		closedAngle = (doorYExtent(math.rad(-90)) <= doorYExtent(math.rad(90))) and math.rad(-90) or math.rad(90)
		openAngle = closedAngle + ((closedAngle < 0) and math.rad(105) or math.rad(-105))
		setDoorAngle(closedAngle)
	end

	task.spawn(function()
		local DUR, t = 0.35, 0
		while t < DUR do
			local dt = task.wait()
			t = math.min(DUR, t + dt)
			local a = t / DUR
			local eased = 1 - (1 - a) * (1 - a)
			setDoorAngle(closedAngle + (openAngle - closedAngle) * eased)
		end
		setDoorAngle(openAngle)
	end)

	task.delay(0.28, function()
		if not corpse or not corpse.Parent then
			return
		end
		local parts = {}
		for _, p in ipairs(corpse:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Anchored = true
				parts[#parts + 1] = { part = p, cf = p.CFrame, t0 = p.Transparency }
			end
		end
		local DUR, t = 0.55, 0
		while t < DUR and corpse.Parent do
			local dt = task.wait()
			t = math.min(DUR, t + dt)
			local a = t / DUR
			local off = -Vector3.new(0, 8 * a, 0)
			for _, e in ipairs(parts) do
				if e.part.Parent then
					e.part.CFrame = e.cf + off
					e.part.Transparency = e.t0 + (1 - e.t0) * a
				end
			end
		end
		if corpse.Parent then
			corpse:Destroy()
		end
	end)

	task.delay(1.0, function()
		local DUR, t = 0.12, 0
		while t < DUR do
			local dt = task.wait()
			t = math.min(DUR, t + dt)
			local a = t / DUR
			setDoorAngle(openAngle + (closedAngle - openAngle) * a)
		end
		setDoorAngle(closedAngle)
	end)

	task.delay(1.45, function()
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then
				TweenService:Create(p, TweenInfo.new(0.4), { Transparency = 1 }):Play()
			end
		end
	end)

	Debris:AddItem(model, 2.2)
	return model
end

function KillEffectApplier._crushedBuilding(centerPos, corpse)
	local model = cloneEffectModel("CrushedBuilding")
	if not model then
		return
	end
	model.Name = "CrushedBuildingFX"

	local ignore = { model }
	if corpse then table.insert(ignore, corpse) end
	local corpsesF = Workspace:FindFirstChild("Corpses")
	if corpsesF then table.insert(ignore, corpsesF) end
	local groundY = groundYUnder(centerPos, ignore)

	placeOnGround(model, centerPos, groundY, 0)
	local bmin, bmax = worldAABB(model)
	local footX, footZ = bmax.X - bmin.X, bmax.Z - bmin.Z

	local RISE = 46
	local rest = {}
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			rest[#rest + 1] = { part = p, cf = p.CFrame }
			p.CFrame = p.CFrame + Vector3.new(0, RISE, 0)
		end
	end
	model.Parent = Workspace

	local function onImpact()
		if corpse and corpse.Parent then
			for _, p in ipairs(corpse:GetDescendants()) do
				if p:IsA("BasePart") then
					p.Anchored = true
					local cf = p.CFrame
					local flatCF = CFrame.new(cf.X, groundY + 0.25, cf.Z) * (cf - cf.Position)
					local sz = p.Size
					local flatSize = Vector3.new(sz.X, math.max(0.2, sz.Y * 0.22), sz.Z)
					TweenService:Create(p, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = flatCF, Size = flatSize }):Play()
				end
			end
		end
		for i = 1, 12 do
			local ang = (i / 12) * math.pi * 2
			local d = makeFXPart("Dust", Vector3.new(1.8, 1.8, 1.8), CFrame.new(centerPos.X + math.cos(ang) * footX / 2, groundY + 0.9, centerPos.Z + math.sin(ang) * footZ / 2), Color3.fromRGB(150, 148, 140), Workspace)
			d.Shape = Enum.PartType.Ball
			d.Transparency = 0.3
			local outCF = CFrame.new(centerPos.X + math.cos(ang) * (footX / 2 + 7), groundY + 3, centerPos.Z + math.sin(ang) * (footZ / 2 + 7))
			TweenService:Create(d, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = outCF, Transparency = 1, Size = Vector3.new(4.5, 4.5, 4.5) }):Play()
			Debris:AddItem(d, 1)
		end
	end

	task.spawn(function()
		local DUR, t = 0.34, 0
		while t < DUR do
			local dt = task.wait()
			t = math.min(DUR, t + dt)
			local a = t / DUR
			local eased = a * a
			for _, e in ipairs(rest) do
				if e.part.Parent then
					e.part.CFrame = e.cf + Vector3.new(0, RISE * (1 - eased), 0)
				end
			end
		end
		for _, e in ipairs(rest) do
			if e.part.Parent then e.part.CFrame = e.cf end
		end
		onImpact()
	end)

	task.delay(1.3, function()
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then
				TweenService:Create(p, TweenInfo.new(0.5), { Transparency = 1 }):Play()
			end
		end
	end)

	Debris:AddItem(model, 2.4)
	return model
end

local function previewDummy(pos)
	local m = Instance.new("Model")
	m.Name = "KillEffectPreviewDummy"
	local p = Instance.new("Part")
	p.Size = Vector3.new(2, 5, 1)
	p.CFrame = CFrame.new(pos + Vector3.new(0, 2.5, 0))
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Color = Color3.fromRGB(180, 140, 120)
	p.Parent = m
	m.PrimaryPart = p
	m.Parent = Workspace
	Debris:AddItem(m, 5)
	return m
end

function KillEffectApplier.apply(corpse, effectId)
	if not corpse or not effectId then return end
	local def = KillEffectManager.getEffect(effectId)
	if not def then return end
	playEffectSound(corpse, def)
	if effectId == "balloons" then
		local part = primaryPart(corpse)
		local pos = part and part.Position or corpse:GetPivot().Position
		spawnBalloons(CFrame.new(pos + Vector3.new(0, 1, 0)), BALLOON_LIFETIME)
		return
	end
	if effectId == "haunteddoor" then
		KillEffectApplier._hauntedDoor(corpseAnchorPos(corpse), corpse)
		return
	end
	if effectId == "crushedbuilding" then
		KillEffectApplier._crushedBuilding(corpseAnchorPos(corpse), corpse)
		return
	end
	local template = getTemplate(def)
	if template then
		transferVFX(template, corpse)
	end
	activate(corpse, def, VFX_DURATION)
end

function KillEffectApplier.preview(cframe, effectId, duration)
	local def = KillEffectManager.getEffect(effectId)
	if not def then return nil, "unknown effect" end
	if effectId == "balloons" then
		local folder = spawnBalloons((cframe or CFrame.new()) * CFrame.new(0, 2, 0), duration or 6)
		if not folder then return nil, "asset 'Balloons' missing" end
		return folder
	end
	if effectId == "haunteddoor" or effectId == "crushedbuilding" then
		local pos = (cframe or CFrame.new()).Position
		local dummy = previewDummy(pos)
		if effectId == "haunteddoor" then
			return KillEffectApplier._hauntedDoor(pos, dummy)
		end
		return KillEffectApplier._crushedBuilding(pos, dummy)
	end
	local template = getTemplate(def)
	if not template then return nil, ("asset '%s' missing"):format(tostring(def.vfx)) end
	duration = duration or 6

	local rig = template:Clone()
	rig.Name = "KillEffectPreview_" .. def.id
	for _, d in ipairs(rig:GetDescendants()) do
		if d:IsA("Humanoid") then d:Destroy() end
	end
	for _, p in ipairs(rig:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
		end
	end
	if cframe then rig:PivotTo(cframe) end
	rig.Parent = Workspace
	activate(rig, def, duration)
	Debris:AddItem(rig, duration + 2)
	return rig
end

return KillEffectApplier
