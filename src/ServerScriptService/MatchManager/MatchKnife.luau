local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local KnifeSkinManager = require(ReplicatedStorage:WaitForChild("KnifeSkinManager"))
local SeekerKnifeTemplate = ServerStorage:FindFirstChild("SeekerKnife")
local PaintballGunGiver = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("PaintballGunGiver"))
local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local LockBackpack = Remotes:FindFirstChild("LockBackpack")
if not LockBackpack then
	LockBackpack = Instance.new("RemoteEvent")
	LockBackpack.Name = "LockBackpack"
	LockBackpack.Parent = Remotes
end
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"))
local function dsInv()
	local ok, s = pcall(function() return Knit.GetService("DataService") end)
	return ok and s or nil
end

local Knife = {}

local KnifeVFXFolder = ReplicatedStorage:FindFirstChild("KnifeVFX")
local function applyKnifeVFX(knifeTool, effectId)
	if not effectId or effectId == "none" then
		return
	end
	if not KnifeVFXFolder then
		return
	end
	local template = KnifeVFXFolder:FindFirstChild(effectId)
	if not template then
		return
	end
	local handle = knifeTool:FindFirstChild("Handle")
	if not handle then
		return
	end

	local vfx = template:Clone()
	vfx.Name = "KnifeVFX" -- reserved name so it can be found/removed
	vfx.CFrame = handle.CFrame
	vfx.Parent = knifeTool
	vfx.Anchored = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = vfx
	weld.Parent = vfx
	knifeTool:SetAttribute("EffectId", effectId)
end

local function applyKnifeSkinVisual(knifeTool, skinId)
	if not skinId then
		return
	end
	local skinTemplate = KnifeSkinManager.getTemplate(skinId)
	if not skinTemplate then
		return
	end
	local srcHandle = skinTemplate:FindFirstChild("Handle")
	local dstHandle = knifeTool:FindFirstChild("Handle")
	if not srcHandle or not dstHandle then
		return
	end

	knifeTool:SetAttribute("SkinId", skinId)

	if skinTemplate:IsA("Tool") and knifeTool:IsA("Tool") then
		knifeTool.Grip = skinTemplate.Grip
	end

	local srcDecal = srcHandle:FindFirstChild("Decal")
	local dstDecal = dstHandle:FindFirstChild("Decal")
	if srcDecal and dstDecal then
		dstDecal.Texture = srcDecal.Texture
	end

	dstHandle.Color = srcHandle.Color

	local srcMesh = srcHandle:FindFirstChildOfClass("SpecialMesh")
	local dstMesh = dstHandle:FindFirstChildOfClass("SpecialMesh")
	if srcMesh and dstMesh then
		dstMesh.MeshId = srcMesh.MeshId
		dstMesh.Scale = srcMesh.Scale
		dstMesh.TextureId = srcMesh.TextureId
		dstMesh.VertexColor = srcMesh.VertexColor
	end

	local srcMeshParts = {}
	for _, c in ipairs(srcHandle:GetChildren()) do
		if c:IsA("MeshPart") then
			table.insert(srcMeshParts, c)
		end
	end
	if #srcMeshParts > 0 then
		if dstMesh then
			dstMesh.MeshId = ""
			dstMesh.TextureId = ""
		end
		dstHandle.Transparency = 1
		if dstDecal then
			dstDecal.Transparency = 1
		end
		local baseInv = srcHandle.CFrame:Inverse()
		for _, mp in ipairs(srcMeshParts) do
			local rel = baseInv * mp.CFrame
			local clone = mp:Clone()
			for _, w in ipairs(clone:GetChildren()) do
				if w:IsA("WeldConstraint") or w:IsA("Weld") or w:IsA("Motor6D") then
					w:Destroy()
				end
			end
			clone.Anchored = false
			clone.CanCollide = false
			clone.CanQuery = false
			clone.CanTouch = false
			clone.Massless = true
			clone.CFrame = dstHandle.CFrame * rel
			clone.Parent = dstHandle
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = dstHandle
			weld.Part1 = clone
			weld.Parent = clone
		end
	end

	-- ===== Baked-in handle VFX (e.g. the Vampire Scythe's particle emitters) =====
	-- Some skins author extra VFX directly on their template Handle (ParticleEmitters, glows, etc.)
	-- ON TOP of the base knife's standard components. giveKnife clones the BASE SeekerKnife (which has
	-- the standard Sounds + SlashTrail + Attachment0/Attachment1 + Mesh + Decal), so those baseline
	-- parts are already present on dstHandle and must NOT be duplicated. Here we copy ONLY the skin's
	-- EXTRA emitter VFX onto the equipped knife so the baked look shows up in-hand (and on the thrown
	-- projectile, which clones the Handle).
	--
	-- What counts as "extra VFX to copy":
	--   * a ParticleEmitter/Beam/Trail/Light/Fire/Smoke/Sparkles sitting DIRECTLY on the handle, AND
	--   * an Attachment that CONTAINS such an emitter (the skin's emitters live under their own
	--     attachments). We decide Attachments by their CONTENTS, not their name, because the skin reuses
	--     names like "Attachment1" that also exist on the base (the base's are used by the standard
	--     SlashTrail and carry NO emitter, so they're correctly skipped).
	-- We never copy the base knife's own components: the Sounds, the SpecialMesh, the Decal, and the
	-- standard SlashTrail (+ its empty Attachment0/Attachment1). A name guard against the base handle's
	-- baseline children covers the direct-emitter case; the emitter-content test covers Attachments.
	local EMITTER_CLASSES = {
		ParticleEmitter = true,
		Beam = true,
		Trail = true,
		PointLight = true,
		SpotLight = true,
		SurfaceLight = true,
		Fire = true,
		Smoke = true,
		Sparkles = true,
	}
	local baseline = {}
	for _, c in ipairs(dstHandle:GetChildren()) do
		baseline[c.Name] = true
	end
	local function hasEmitter(inst)
		if EMITTER_CLASSES[inst.ClassName] then
			return true
		end
		for _, d in ipairs(inst:GetDescendants()) do
			if EMITTER_CLASSES[d.ClassName] then
				return true
			end
		end
		return false
	end
	for _, child in ipairs(srcHandle:GetChildren()) do
		local copyIt = false
		if child:IsA("Attachment") then
			copyIt = hasEmitter(child)
		elseif EMITTER_CLASSES[child.ClassName] then
			copyIt = not baseline[child.Name]
		end
		if copyIt then
			local vfxClone = child:Clone()
			vfxClone.Parent = dstHandle
		end
	end
end

local function paintingBossActive(): boolean
	local ok, svc = pcall(function()
		return Knit.GetService("PaintingBossService")
	end)
	return ok and svc and svc:IsEventActive() or false
end

local function giveKnife(player)
	-- During the Painting Boss event, seekers (and anyone who becomes a seeker) get a paintball gun.
	if paintingBossActive() then
		PaintballGunGiver.StripSeekerKnife(player)
		PaintballGunGiver.GiveGun(player)
		return
	end

	-- remove any existing copies first to avoid duplicates
	local function strip(container)
		if not container then
			return
		end
		for _, t in ipairs(container:GetChildren()) do
			if t.Name == "SeekerKnife" and t:IsA("Tool") then
				t:Destroy()
			end
		end
	end
	strip(player:FindFirstChildOfClass("Backpack"))
	strip(player.Character)

	if not SeekerKnifeTemplate then
		return
	end
	local equippedId, equippedEffect
	local inventoryService = dsInv()
	if inventoryService then
		equippedId, equippedEffect = inventoryService:GetEquippedSkin(player)
	end

	local clone = SeekerKnifeTemplate:Clone()
	clone.Name = "SeekerKnife" -- keep the name so all knife logic still finds it
	applyKnifeSkinVisual(clone, equippedId)
	applyKnifeVFX(clone, equippedEffect)
	clone.Parent = player:FindFirstChildOfClass("Backpack")

	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum:EquipTool(clone)
	end
	LockBackpack:FireClient(player, true)
end

local function seekerHasKnife(player)
	local function has(container)
		if not container then
			return false
		end
		for _, t in ipairs(container:GetChildren()) do
			if t.Name == "SeekerKnife" and t:IsA("Tool") then
				return true
			end
		end
		return false
	end
	return has(player.Character) or has(player:FindFirstChildOfClass("Backpack"))
end

local function clearKnife(player)
	local function strip(container)
		if not container then
			return
		end
		for _, t in ipairs(container:GetChildren()) do
			if t.Name == "SeekerKnife" and t:IsA("Tool") then
				t:Destroy()
			end
		end
	end
	strip(player:FindFirstChildOfClass("Backpack"))
	strip(player.Character)
	LockBackpack:FireClient(player, false)
end

Knife.giveKnife = giveKnife
Knife.seekerHasKnife = seekerHasKnife
Knife.clearKnife = clearKnife

return Knife
