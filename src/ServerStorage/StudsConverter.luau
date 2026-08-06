local MaterialService = game:GetService("MaterialService")

local StudsConverter = {}

local STUDS_VARIANT = "Studs"
local START_COLOR = Color3.fromRGB(245, 245, 245)
local STUD_REFLECTANCE = 0

local STUD_TEXTURE = "rbxassetid://10509831729"
local STUD_TILE = 1
local STUD_TRANSPARENCY = 0
local STUD_FACES = { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right, Enum.NormalId.Top, Enum.NormalId.Bottom }
local STUD_TAG = "StudsCamoTexture"

local function applyStudTextures(part, color)
	for _, face in ipairs(STUD_FACES) do
		local tex = Instance.new("Texture")
		tex.Name = STUD_TAG
		tex.Texture = STUD_TEXTURE
		tex.Face = face
		tex.StudsPerTileU = STUD_TILE
		tex.StudsPerTileV = STUD_TILE
		tex.Transparency = STUD_TRANSPARENCY
		tex.Color3 = color or START_COLOR
		tex.Parent = part
	end
end

local function tintStudTextures(part, color)
	for _, c in ipairs(part:GetChildren()) do
		if c:IsA("Texture") and c.Name == STUD_TAG then
			c.Color3 = color
		end
	end
end

local function removeStudTextures(part)
	for _, c in ipairs(part:GetChildren()) do
		if c:IsA("Texture") and c.Name == STUD_TAG then
			c:Destroy()
		end
	end
end

local TORSO_HALF_TAG = "TorsoHalfShell"

local SHELL_DEPTH_INFLATE = 0.06
local SHELL_INNER_OVERLAP = 0.03
local function makeTorsoHalf(torso, side)
	local size = torso.Size
	local shell = Instance.new("Part")
	shell.Name = TORSO_HALF_TAG

	shell.Size = Vector3.new(size.X / 2 + SHELL_INNER_OVERLAP, size.Y, size.Z + SHELL_DEPTH_INFLATE)
	shell.Material = Enum.Material.Plastic
	shell.Reflectance = STUD_REFLECTANCE
	shell.Color = START_COLOR
	shell.CanCollide = false
	shell.CanTouch = false
	shell.CanQuery = true
	shell.CastShadow = false
	shell.Massless = true

	shell.CFrame = torso.CFrame * CFrame.new(side * (size.X / 4 - SHELL_INNER_OVERLAP / 2), 0, 0)
	shell.Parent = torso.Parent

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = torso
	weld.Part1 = shell
	weld.Parent = shell

	applyStudTextures(shell, START_COLOR)
	return shell
end

local function removeTorsoHalves(character)
	for _, d in ipairs(character:GetChildren()) do
		if d:IsA("BasePart") and d.Name == TORSO_HALF_TAG then
			d:Destroy()
		end
	end
end

local cache = setmetatable({}, { __mode = "k" })

local EFFECT_CLASSES = {
	ParticleEmitter = true,
	Trail = true,
	Beam = true,
	PointLight = true,
	SpotLight = true,
	SurfaceLight = true,
	Fire = true,
	Smoke = true,
	Sparkles = true,
}

local function hideAccessory(saved, obj)
	local accessory = obj:IsA("Accessory") and obj or obj:FindFirstAncestorOfClass("Accessory")
	if not accessory then
		return
	end

	local handle = accessory:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		if saved.accessories[handle] == nil then
			saved.accessories[handle] = handle.Transparency
		end
		handle.Transparency = 1
		for _, sub in ipairs(handle:GetDescendants()) do
			if sub:IsA("Decal") or sub:IsA("Texture") then
				if saved.accessories[sub] == nil then
					saved.accessories[sub] = sub.Transparency
				end
				sub.Transparency = 1
			end
		end
	end

	for _, sub in ipairs(accessory:GetDescendants()) do
		if EFFECT_CLASSES[sub.ClassName] then
			if saved.accessoryEffects[sub] == nil then
				saved.accessoryEffects[sub] = sub.Enabled
			end
			sub.Enabled = false
		end
	end
end

local function isBodyPart(obj)
	return obj:IsA("BasePart") and obj.Name ~= "HumanoidRootPart" and obj.Name ~= "CollisionPart"
end

function StudsConverter.convert(character)
	if not character then
		return false, "no character"
	end
	if cache[character] then
		return true, "already converted"
	end

	local saved = {
		parts = {},
		accessories = {},
		accessoryEffects = {},
		clothing = {},
		meshes = {},
		head = {},
		description = false,
	}

	local hum = character:FindFirstChildOfClass("Humanoid")
	if hum then
		local okDesc, desc = pcall(function()
			return hum:GetAppliedDescription()
		end)
		if okDesc and desc then
			saved.description = desc
			pcall(function()
				hum:ApplyDescription(Instance.new("HumanoidDescription"))
			end)
		end
	end

	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		saved.head.part = head
		saved.head.transparency = head.Transparency
		head.Transparency = 1

		saved.head.decals = {}
		for _, c in ipairs(head:GetChildren()) do
			if c:IsA("Decal") or c:IsA("Texture") then
				saved.head.decals[c] = c.Transparency
				c.Transparency = 1
			end
		end
	end

	for _, obj in ipairs(character:GetDescendants()) do
		if isBodyPart(obj) and obj.Name ~= "Head" and obj.Transparency < 1 then
			local entry = {
				Color = obj.Color,
				Material = obj.Material,
				MaterialVariant = obj.MaterialVariant,
				Reflectance = obj.Reflectance,
			}
			if obj:IsA("MeshPart") then
				entry.TextureID = obj.TextureID
			end
			saved.parts[obj] = entry

			obj.Material = Enum.Material.Plastic
			obj.MaterialVariant = STUDS_VARIANT
			obj.Reflectance = STUD_REFLECTANCE
			obj.Color = START_COLOR
			if obj:IsA("MeshPart") then
				obj.TextureID = ""
			end

			applyStudTextures(obj, START_COLOR)
		end
	end

	local torso = character:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then
		makeTorsoHalf(torso, 1)
	end

	for _, obj in ipairs(character:GetDescendants()) do
		if obj:IsA("Accessory") then
			hideAccessory(saved, obj)
		end
	end
	saved.convertedConn = character.DescendantAdded:Connect(function(obj)
		hideAccessory(saved, obj)
	end)

	for _, obj in ipairs(character:GetDescendants()) do
		if obj:IsA("Shirt") or obj:IsA("Pants") or obj:IsA("ShirtGraphic") then
			table.insert(saved.clothing, { inst = obj, parent = obj.Parent })
			obj.Parent = nil
		end
	end

	for _, obj in ipairs(character:GetDescendants()) do
		if obj:IsA("CharacterMesh") then
			table.insert(saved.meshes, { inst = obj, parent = obj.Parent })
			obj.Parent = nil
		end
	end

	cache[character] = saved

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		saved.hrpCanQuery = hrp.CanQuery
		hrp.CanQuery = false
	end

	return true
end

function StudsConverter.restore(character)
	local saved = cache[character]
	if not saved then
		return false, "not converted"
	end

	if saved.convertedConn then
		saved.convertedConn:Disconnect()
		saved.convertedConn = nil
	end

	removeTorsoHalves(character)

	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("Texture") and d.Name == STUD_TAG then
			d:Destroy()
		end
	end

	local hum = character:FindFirstChildOfClass("Humanoid")
	if hum and saved.description then
		pcall(function()
			hum:ApplyDescription(saved.description)
		end)
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if hrp and saved.hrpCanQuery ~= nil then
			hrp.CanQuery = saved.hrpCanQuery
		end
		cache[character] = nil
		return true
	end

	for part, entry in pairs(saved.parts) do
		if part and part.Parent then
			removeStudTextures(part)
			part.Color = entry.Color
			part.Material = entry.Material
			part.MaterialVariant = entry.MaterialVariant
			part.Reflectance = entry.Reflectance or 0
			if entry.TextureID ~= nil and part:IsA("MeshPart") then
				part.TextureID = entry.TextureID
			end
		end
	end

	for inst, transparency in pairs(saved.accessories) do
		if inst and inst.Parent then
			inst.Transparency = transparency
		end
	end

	for inst, wasEnabled in pairs(saved.accessoryEffects) do
		if inst and inst.Parent then
			inst.Enabled = wasEnabled
		end
	end

	for _, c in ipairs(saved.clothing) do
		if c.inst then
			c.inst.Parent = c.parent
		end
	end

	if saved.meshes then
		for _, m in ipairs(saved.meshes) do
			if m.inst then
				m.inst.Parent = m.parent
			end
		end
	end

	if saved.head and saved.head.part and saved.head.part.Parent then
		saved.head.part.Transparency = saved.head.transparency or 0
		if saved.head.decals then
			for decal, transparency in pairs(saved.head.decals) do
				if decal and decal.Parent then
					decal.Transparency = transparency
				end
			end
		end
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp and saved.hrpCanQuery ~= nil then
		hrp.CanQuery = saved.hrpCanQuery
	end

	cache[character] = nil
	return true
end

function StudsConverter.paintPart(part, color)
	if part and isBodyPart(part) then
		part.Color = color
		tintStudTextures(part, color)
		return true
	end
	return false
end

function StudsConverter.paintAll(character, color)
	local saved = cache[character]
	if not saved then
		return false, "not converted"
	end

	for part, _ in pairs(saved.parts) do
		if part and part.Parent then
			StudsConverter.paintPart(part, color)
		end
	end

	for _, d in ipairs(character:GetChildren()) do
		if d:IsA("BasePart") and d.Name == TORSO_HALF_TAG then
			d.Color = color
			tintStudTextures(d, color)
		end
	end

	return true
end

function StudsConverter.isConverted(character)
	return cache[character] ~= nil
end

return StudsConverter
