-- KnifeIcon: renders a knife skin as a live ViewportFrame instead of a flat image.
-- This avoids needing a pre-rendered image asset for every knife — the viewport shows the actual
-- skin model (mesh + decal/color), so new knives "just work" with no render to upload.
--
-- Usage: KnifeIcon.render(iconImageLabel, skinId)
--   - hides the ImageLabel's image and parents a ViewportFrame inside it showing the knife
--   - safe to call repeatedly (it clears any previous viewport first)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local KnifeSkinManager = require(ReplicatedStorage:WaitForChild("KnifeSkinManager"))

local KnifeIcon = {}

local VIEWPORT_NAME = "KnifeViewport"

-- Cache completed viewports by skinId so large inventories don't rebuild the same knife icon
-- from scratch for every cell. The cached viewport is cloned, which is much cheaper than
-- cloning the handle + setting up the camera/lights each time.
local viewportCache = {}

-- Internal: build a ViewportFrame showing `template`'s Handle, using optional pose.
local function buildCachedViewport(template: Instance?, pose)
	if not template then return nil end
	local srcHandle = template:FindFirstChild("Handle")
	if not srcHandle or not srcHandle:IsA("BasePart") then return nil end

	local vp = Instance.new("ViewportFrame")
	vp.Name = VIEWPORT_NAME
	vp.Size = UDim2.fromScale(1, 1)
	vp.Position = UDim2.fromScale(0, 0)
	vp.BackgroundTransparency = 1

	local handle = srcHandle:Clone()
	handle.Anchored = true
	handle.CanCollide = false

	local meshParts = {}
	for _, c in ipairs(handle:GetChildren()) do
		if c:IsA("MeshPart") then
			table.insert(meshParts, c)
		end
	end
	for _, c in ipairs(handle:GetChildren()) do
		if not (c:IsA("SpecialMesh") or c:IsA("Decal") or c:IsA("Texture") or c:IsA("DataModelMesh") or c:IsA("MeshPart")) then
			c:Destroy()
		end
	end

	local rx = pose and pose.rx or 95
	local ry = pose and pose.ry or 221
	local rz = pose and pose.rz or -240
	local camDist = pose and pose.dist or 3.5
	local rot = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(rx), math.rad(ry), math.rad(rz))

	if #meshParts > 0 then
		local baseInv = handle.CFrame:Inverse()
		local offsets = {}
		for _, mp in ipairs(meshParts) do
			offsets[mp] = baseInv * mp.CFrame
		end
		handle.CFrame = rot
		for _, mp in ipairs(meshParts) do
			for _, w in ipairs(mp:GetChildren()) do
				if w:IsA("WeldConstraint") or w:IsA("Weld") or w:IsA("Motor6D") then
					w:Destroy()
				end
			end
			mp.Anchored = true
			mp.CanCollide = false
			mp.CFrame = rot * offsets[mp]
		end
	else
		handle.CFrame = rot
	end
	handle.Parent = vp

	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	local VIEW_DIR = Vector3.new(0.5, 0.32, 0.78).Unit
	cam.CFrame = CFrame.lookAt(VIEW_DIR * camDist, Vector3.new(0, 0, 0))
	cam.Parent = vp
	vp.CurrentCamera = cam

	vp.Ambient = Color3.fromRGB(180, 180, 190)
	vp.LightColor = Color3.fromRGB(255, 255, 255)
	vp.LightDirection = Vector3.new(-0.4, -1, -0.6).Unit
	return vp
end

-- Internal: build a ViewportFrame inside `holder` showing `template`'s Handle, using optional pose.
local function renderTemplate(holder: GuiObject, cacheKey: string, template: Instance?, pose)
	if not holder then return end

	local existing = holder:FindFirstChild(VIEWPORT_NAME)
	if existing then existing:Destroy() end

	if not template then return end

	-- if the holder is an ImageLabel/Button, hide its image so only the viewport shows
	if holder:IsA("ImageLabel") or holder:IsA("ImageButton") then
		holder.Image = ""
	end

	local cached = viewportCache[cacheKey]
	if not cached then
		cached = buildCachedViewport(template, pose)
		viewportCache[cacheKey] = cached
	end
	if not cached then return end

	local vp = cached:Clone()
	vp.ZIndex = (holder.ZIndex or 1)
	vp.Parent = holder
	-- CurrentCamera references the original cached camera; point it at the cloned camera instead.
	local cam = vp:FindFirstChildOfClass("Camera")
	if cam then vp.CurrentCamera = cam end
end

-- Build (or reuse) a ViewportFrame inside the given holder and show the skin's knife model in it.
function KnifeIcon.render(holder: GuiObject, skinId: string?)
	if not holder then return end
	if not skinId then
		-- no skin id: clear any viewport and bail (caller may then show a placeholder)
		local existing = holder:FindFirstChild(VIEWPORT_NAME)
		if existing then existing:Destroy() end
		return
	end
	local template = KnifeSkinManager.getTemplate and KnifeSkinManager.getTemplate(skinId)
	local def = KnifeSkinManager.getSkin and KnifeSkinManager.getSkin(skinId)
	renderTemplate(holder, skinId, template, def and def.pose)
end

-- Render the DEFAULT (base) knife — the SeekerKnife copy in KnifeSkins. Used for the inventory's
-- always-present "Default" item so it shows the real knife instead of a placeholder image.
function KnifeIcon.renderDefault(holder: GuiObject)
	if not holder then return end
	local template = KnifeSkinManager.getDefaultTemplate and KnifeSkinManager.getDefaultTemplate()
	renderTemplate(holder, "__default__", template, nil)
end

return KnifeIcon
