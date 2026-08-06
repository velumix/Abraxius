-- BackKnife: shows a cosmetic copy of a player's EQUIPPED knife skin slung on their back (or the
-- DEFAULT knife if they have nothing equipped). Purely visual, server-spawned (so it replicates to everyone). It appears ONLY for players who are
-- in the LOBBY (no active round role). It is never built for a Hider or Seeker, because:
--   * hiders get converted to a studded/headless form (a back-knife would clip / break the disguise
--     and could reveal them), and
--   * the seeker already physically holds the knife during the round.
-- So the back-knife is lobby flair that shows off what you've equipped, with no gameplay leak.
--
-- GATE: a back-knife is shown only for players in the LOBBY (not out on the map for a live round).
-- MatchManager calls BackKnife.setSuppressed(player, true) when it sends a player out to play and
-- setSuppressed(player, false) when it returns them to the lobby (including a found hider during
-- RESOLVE, before roles clear), so the model appears/disappears exactly when the player leaves/
-- re-enters the lobby. A role-lookup fallback covers any path that doesn't call setSuppressed.
--
-- Usage:
--   BackKnife.setInventoryManager(InventoryManager)   -- to read the equipped skin
--   BackKnife.init()                                  -- start listening for spawns
--   BackKnife.refresh(player)                         -- rebuild for one player (call after equip change)
--   BackKnife.setSuppressed(player, bool)             -- MatchManager: out-on-map vs in-lobby
--   BackKnife.refreshAll()                            -- rebuild everyone (call at round boundaries)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local KnifeSkinManager = require(ReplicatedStorage:WaitForChild("KnifeSkinManager"))

local BackKnife = {}

local InventoryManager = nil
function BackKnife.setInventoryManager(im) InventoryManager = im end

local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"))
local DataService = nil
local function getDataService()
	if DataService then return DataService end
	local ok, svc = pcall(function() return Knit.GetService("DataService") end)
	if ok then DataService = svc end
	return DataService
end

local ATTACH_NAME = "BackKnifeModel"  -- reserved name for the welded cosmetic part

-- ===== Per-skin back positioning =====
-- The offset is relative to the torso CFrame (read back from a playtest as torso:ToObjectSpace(model.CFrame)).
-- DEFAULT is used for normal knives; some skin shapes need their own offset so they sit right on the
-- back. getOffset() picks a special offset by skin id when one applies, else DEFAULT.
local DEFAULT_OFFSET = CFrame.new(0.0753, 0.0730, 0.6231)
	* CFrame.Angles(math.rad(-92.202), math.rad(-44.005), math.rad(-97.021))

-- Cane knives (Blue/Green/Purple/Orange/Pink/Candy Cane) have a long candy-cane shape that needs a
-- different lie on the back. Detected by the skin id ending in "cane", so any future cane skin gets
-- this automatically. Dialed in by hand in a playtest.
local CANE_OFFSET = CFrame.new(0.0631, -0.0311, 0.6540)
	* CFrame.Angles(math.rad(-9.074), math.rad(0.597), math.rad(-49.905))

-- Per-skin back offsets for the Brainrot meshes, dialed in by hand in a playtest (read back as
-- torso:ToObjectSpace(model.CFrame)). Each distinct mesh sits differently from the default knife,
-- so it gets its own offset keyed by skin id. Built from the exact captured CFrame components.
local SKIN_OFFSETS = {
	darkrose = DEFAULT_OFFSET * CFrame.Angles(0, math.rad(90), 0),
	frozen = DEFAULT_OFFSET * CFrame.Angles(0, math.rad(90), 0),
	-- Blackhole Dagger (Cosmic Secret): captured in a playtest. Stored torso-relative; converted from a
	-- BodyBackAttachment-relative reading (that attachment sits at torso-local (0,0,0.5), so +0.5 on Z).
	blackholedagger = CFrame.new(0.075, 0.119, 0.623)
		* CFrame.Angles(math.rad(-94.3), math.rad(-18.6), math.rad(-87.0)),
	tralalero = CFrame.new(
		0.075286865234375, 0.15056610107421875, 0.623443603515625,
		-0.998694896697998, 0.04358089342713356, 0.026630789041519165,
		0.03998038172721863, 0.9915580749511719, -0.12334542721509933,
		-0.03178149461746216, -0.1221197247505188, -0.9920064210891724
	),
	meowl = CFrame.new(
		0.07537841796875, 0.06961822509765625, 0.623199462890625,
		-0.9910672903060913, 0.10759463906288147, 0.07883626222610474,
		0.10469578206539154, 0.9936977028846741, -0.04003969952464104,
		-0.08264827728271484, -0.03142610564827919, -0.9960868954658508
	),
	pothotspot = CFrame.new(
		0.0752258, 0.0678215, 0.623108,
		0.318586, 0.945596, -0.0659639,
		-0.94579, 0.321743, 0.0443118,
		0.0631245, 0.0482708, 0.996838
	),
	-- orcaleroorcala reuses Tralalero's back offset (per request: same equip position as Tralalero)
	orcaleroorcala = CFrame.new(
		0.075286865234375, 0.15056610107421875, 0.623443603515625,
		-0.998694896697998, 0.04358089342713356, 0.026630789041519165,
		0.03998038172721863, 0.9915580749511719, -0.12334542721509933,
		-0.03178149461746216, -0.1221197247505188, -0.9920064210891724
	),
	-- guest666 reuses Meowl's back offset (per request: same equip position as Meowl)
	guest666 = CFrame.new(
		0.07537841796875, 0.06961822509765625, 0.623199462890625,
		-0.9910672903060913, 0.10759463906288147, 0.07883626222610474,
		0.10469578206539154, 0.9936977028846741, -0.04003969952464104,
		-0.08264827728271484, -0.03142610564827919, -0.9960868954658508
	),
	-- vampirescythe: captured by hand in a playtest (torso:ToObjectSpace(model.CFrame)). The scythe is
	-- long, so it lies across the back differently from a normal knife.
	vampirescythe = CFrame.new(
		0.9108581543, -0.6271247864, 0.6630554199,
		-0.694719255, 0.7138887644, 0.08791406453,
		0.7187510729, 0.6936962008, 0.04672012478,
		-0.02763273567, 0.09564568102, -0.9950323105
	),
	-- Kawaii Kitchen Crate knives: all imported in the same orientation, so they share ONE back
	-- offset (captured by hand in a playtest as torso:ToObjectSpace(model.CFrame)).
	cakefork = CFrame.new(
		0.075317, 0.073002, 0.623108,
		-0.087920, 0.713886, -0.694721,
		-0.046721, 0.693699, 0.718748,
		0.995031, 0.095650, -0.027637
	),
	cheesy = CFrame.new(
		0.075317, 0.073002, 0.623108,
		-0.087920, 0.713886, -0.694721,
		-0.046721, 0.693699, 0.718748,
		0.995031, 0.095650, -0.027637
	),
	dango = CFrame.new(
		0.075317, 0.073002, 0.623108,
		-0.087920, 0.713886, -0.694721,
		-0.046721, 0.693699, 0.718748,
		0.995031, 0.095650, -0.027637
	),
	sausagefork = CFrame.new(
		0.075317, 0.073002, 0.623108,
		-0.087920, 0.713886, -0.694721,
		-0.046721, 0.693699, 0.718748,
		0.995031, 0.095650, -0.027637
	),
	fork = CFrame.new(
		0.075317, 0.073002, 0.623108,
		-0.087920, 0.713886, -0.694721,
		-0.046721, 0.693699, 0.718748,
		0.995031, 0.095650, -0.027637
	),
	chipmunk = CFrame.new(
		0.075317, 0.073002, 0.623108,
		-0.087920, 0.713886, -0.694721,
		-0.046721, 0.693699, 0.718748,
		0.995031, 0.095650, -0.027637
	),
	kitty = CFrame.new(
		0.075317, 0.073002, 0.623108,
		-0.087920, 0.713886, -0.694721,
		-0.046721, 0.693699, 0.718748,
		0.995031, 0.095650, -0.027637
	),
	bear = CFrame.new(
		0.075317, 0.073002, 0.623108,
		-0.087920, 0.713886, -0.694721,
		-0.046721, 0.693699, 0.718748,
		0.995031, 0.095650, -0.027637
	),
	spatula = CFrame.new(
		0.075317, 0.073002, 0.623108,
		-0.087920, 0.713886, -0.694721,
		-0.046721, 0.693699, 0.718748,
		0.995031, 0.095650, -0.027637
	),
	eggspatula = CFrame.new(
		0.075317, 0.073002, 0.623108,
		-0.087920, 0.713886, -0.694721,
		-0.046721, 0.693699, 0.718748,
		0.995031, 0.095650, -0.027637
	),
	pinkspoon = CFrame.new(
		0.075317, 0.073002, 0.623108,
		-0.087920, 0.713886, -0.694721,
		-0.046721, 0.693699, 0.718748,
		0.995031, 0.095650, -0.027637
	),
	greenspoon = CFrame.new(
		0.075317, 0.073002, 0.623108,
		-0.087920, 0.713886, -0.694721,
		-0.046721, 0.693699, 0.718748,
		0.995031, 0.095650, -0.027637
	),
	greenplastic = CFrame.new(
		0.075317, 0.073002, 0.623108,
		-0.087920, 0.713886, -0.694721,
		-0.046721, 0.693699, 0.718748,
		0.995031, 0.095650, -0.027637
	),
	pinkplastic = CFrame.new(
		0.075317, 0.073002, 0.623108,
		-0.087920, 0.713886, -0.694721,
		-0.046721, 0.693699, 0.718748,
		0.995031, 0.095650, -0.027637
	),
	bakingspoon = CFrame.new(
		0.075317, 0.073002, 0.623108,
		-0.087920, 0.713886, -0.694721,
		-0.046721, 0.693699, 0.718748,
		0.995031, 0.095650, -0.027637
	),
	blueberrybunny = CFrame.new(
		0.075317, 0.073002, 0.623108,
		-0.087920, 0.713886, -0.694721,
		-0.046721, 0.693699, 0.718748,
		0.995031, 0.095650, -0.027637
	),
}

local function getOffset(skinId)
	if type(skinId) == "string" then
		-- exact per-skin override first
		local special = SKIN_OFFSETS[string.lower(skinId)]
		if special then return special end
		-- cane family by suffix
		if string.find(string.lower(skinId), "cane$") then
			return CANE_OFFSET
		end
	end
	return DEFAULT_OFFSET
end

-- Role lookup via MatchManager's GetRole BindableFunction. Resolved lazily (MatchManager creates it
-- during its own init, which may be after this module loads). Returns "Hider"/"Seeker"/nil.
local roleApi = nil
local function getRole(player)
	if not roleApi then
		local mm = ServerScriptService:FindFirstChild("MatchManager")
		roleApi = mm and mm:FindFirstChild("GetRole")
	end
	if not roleApi then return nil end
	local ok, role = pcall(function() return roleApi:Invoke(player) end)
	return ok and role or nil
end

-- Explicit lobby/suppression state, controlled by MatchManager. This is AUTHORITATIVE: MatchManager
-- knows exactly when a player is out on the map (suppress) vs back in the lobby (allow), including a
-- found hider during RESOLVE whose role is still "Hider" but who is physically back in the lobby.
-- Values: true = out on map (hide), false = in lobby (show). nil = no explicit state yet, in which
-- case we fall back to the role lookup (covers any path that never calls setSuppressed).
local suppressed = {}  -- [userId] = true | false | nil
function BackKnife.setSuppressed(player, isSuppressed)
	if not player then return end
	local val = isSuppressed and true or false
	suppressed[player.UserId] = val
	BackKnife.refresh(player)
	-- When clearing suppression (player returned to lobby), the character may have just respawned and
	-- not be fully assembled yet, or another refresh may have raced ahead while still suppressed. Do a
	-- couple of deferred retries so the knife reliably reappears once the body has settled.
	if not val then
		task.spawn(function()
			for _ = 1, 3 do
				task.wait(0.5)
				if suppressed[player.UserId] == false and player.Parent then
					local char = player.Character
					if char and not char:FindFirstChild(ATTACH_NAME) then
						BackKnife.refresh(player)
					end
				end
			end
		end)
	end
end

-- Clear the explicit state (e.g. on leave) so the role fallback applies again.
function BackKnife.clearSuppressed(player)
	if not player then return end
	suppressed[player.UserId] = nil
end

-- A player is "in the lobby" (eligible for a back-knife) per the EXPLICIT suppression state if one
-- is set; otherwise fall back to the role lookup. The explicit state wins so that a found hider
-- (role still "Hider") who has been returned to the lobby correctly shows their knife again.
local function inLobby(player)
	local s = suppressed[player.UserId]
	if s ~= nil then return s == false end  -- explicit: show only when not suppressed
	return getRole(player) == nil          -- fallback: no role = lobby
end

-- Remove any existing back-knife from a character.
local function clearFrom(char)
	if not char then return end
	local existing = char:FindFirstChild(ATTACH_NAME)
	if existing then existing:Destroy() end
end

-- The torso part to weld to (R15 = UpperTorso, R6 = Torso). Waits briefly for it to exist, since a
-- freshly-respawned character may not have assembled its torso yet when refresh is called.
local function getTorso(char)
	local t = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
	if t then return t end
	-- wait up to ~3s for the torso to stream in on a fresh respawn
	t = char:WaitForChild("UpperTorso", 1.5) or char:WaitForChild("Torso", 1.5)
	return t
end

-- Copy the per-skin visual (decal texture, color, mesh) from a source Handle onto our part,
-- mirroring MatchManager.applyKnifeSkinVisual so the back-knife matches the held knife exactly.
local function applySkinVisualFromHandle(part, srcHandle)
	if not srcHandle then return end

	part.Color = srcHandle.Color

	-- decal
	local srcDecal = srcHandle:FindFirstChild("Decal")
	if srcDecal then
		local d = part:FindFirstChildOfClass("Decal")
		if not d then d = Instance.new("Decal"); d.Parent = part end
		d.Texture = srcDecal.Texture
		d.Face = srcDecal.Face
	end

	-- mesh (some skins, e.g. Candy Seer, use a distinct shape)
	local srcMesh = srcHandle:FindFirstChildOfClass("SpecialMesh")
	if srcMesh then
		local m = part:FindFirstChildOfClass("SpecialMesh")
		if not m then m = Instance.new("SpecialMesh"); m.Parent = part end
		m.MeshId = srcMesh.MeshId
		m.Scale = srcMesh.Scale
		m.TextureId = srcMesh.TextureId
		m.VertexColor = srcMesh.VertexColor
	end
end

-- ===== Baked-in handle VFX on the back-knife =====
-- Some skins author extra particle VFX directly on their template Handle (e.g. the Vampire Scythe's
-- lightning + dark-particle emitters) ON TOP of the base knife's standard components. The back-knife
-- is a fresh blank Part, so we copy the skin's EXTRA emitter VFX onto it (mirroring the held knife in
-- MatchManager.applyKnifeSkinVisual) so the cosmetic back-knife shows the same baked aura.
--
-- We must copy ONLY the skin's extra VFX, NOT the base knife's own components: the Sounds, Mesh,
-- Decal, and the standard SlashTrail (+ its empty Attachment0/Attachment1). We compute the baseline
-- set of child NAMES from the DEFAULT knife template's Handle and skip those; Attachments are decided
-- by whether they actually CONTAIN an emitter (the skin reuses base names like "Attachment1", whose
-- base copy carries no emitter and is correctly skipped, while the skin's emitter-bearing one copies).
local EMITTER_CLASSES = {
	ParticleEmitter = true, Beam = true, Trail = true,
	PointLight = true, SpotLight = true, SurfaceLight = true,
	Fire = true, Smoke = true, Sparkles = true,
}
-- baseline child-name set = the names present on the base/default knife Handle. Resolved lazily +
-- cached. Falls back to a hardcoded set if neither template is found.
local _baselineNames = nil
local function baselineHandleNames()
	if _baselineNames then return _baselineNames end
	local names = {}
	-- prefer the server's base SeekerKnife (what the held knife clones); fall back to the default skin
	local baseTool = ServerStorage:FindFirstChild("SeekerKnife")
	local baseHandle = baseTool and baseTool:FindFirstChild("Handle")
	if not baseHandle and KnifeSkinManager.getDefaultTemplate then
		local def = KnifeSkinManager.getDefaultTemplate()
		baseHandle = def and def:FindFirstChild("Handle")
	end
	if baseHandle then
		for _, c in ipairs(baseHandle:GetChildren()) do names[c.Name] = true end
	else
		-- last-resort hardcoded baseline (matches the standard SeekerKnife handle)
		names = { Throw=true, Hit=true, Equip=true, UnEquip=true,
			Attachment0=true, Attachment1=true, SlashTrail=true, Mesh=true, Decal=true }
	end
	_baselineNames = names
	return names
end

local function hasEmitterDescendant(inst)
	if EMITTER_CLASSES[inst.ClassName] then return true end
	for _, d in ipairs(inst:GetDescendants()) do
		if EMITTER_CLASSES[d.ClassName] then return true end
	end
	return false
end

-- Copy the skin template Handle's EXTRA emitter VFX onto the back-knife part. Welds nothing (the part
-- itself is already welded to the torso, so children ride along). Emitters are parented directly to
-- the part; emitter-bearing Attachments are cloned so their child emitters keep their mount offset.
local function applyBakedHandleVFX(part, srcHandle)
	if not srcHandle then return end
	local baseline = baselineHandleNames()
	for _, child in ipairs(srcHandle:GetChildren()) do
		local copyIt = false
		if child:IsA("Attachment") then
			-- copy an attachment only if it carries emitter VFX (skin's own mounts). The base's empty
			-- Attachment0/Attachment1 (used by the standard SlashTrail) carry none -> skipped.
			copyIt = hasEmitterDescendant(child)
		elseif EMITTER_CLASSES[child.ClassName] then
			-- an emitter directly on the handle: copy unless it's a baseline component (the base
			-- SlashTrail). This keeps the back-knife free of the swing-trail while taking real VFX.
			copyIt = not baseline[child.Name]
		end
		if copyIt then
			local clone = child:Clone()
			clone.Parent = part
		end
	end
end

-- Attach a mutation's VFX to the back-knife part, mirroring MatchManager.applyKnifeVFX so the back-
-- knife shows the SAME particle effect as the held knife. The VFX models live in
-- ReplicatedStorage.KnifeVFX keyed by effect id ("firey", "galaxy", etc.); each is a small invisible
-- Part of emitters that we clone and weld to the back-knife part. "none"/nil = no mutation.
local KnifeVFXFolder = ReplicatedStorage:FindFirstChild("KnifeVFX")
local function applyMutationVFX(part, effectId)
	if not effectId or effectId == "none" then return end
	if not KnifeVFXFolder then return end
	local template = KnifeVFXFolder:FindFirstChild(effectId)
	if not template then return end

	local vfx = template:Clone()
	vfx.Name = "BackKnifeVFX"  -- reserved name (distinct from the held knife's "KnifeVFX")
	vfx.CanCollide = false
	vfx.CanQuery = false
	vfx.CanTouch = false
	vfx.Massless = true
	vfx.Anchored = false
	vfx.CFrame = part.CFrame
	vfx.Parent = part
	-- weld so the emitters travel with the back-knife
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part
	weld.Part1 = vfx
	weld.Parent = vfx
end

-- Resolve the template Handle to copy for a player: their equipped skin if any, otherwise the
-- DEFAULT knife (so a player with nothing equipped still shows the basic knife on their back).
-- Returns (srcHandle, skinId, effectId). skinId/effectId are nil when falling back to default.
local function resolveSourceHandle(player)
	local skinId, effectId = nil, nil
	local dataSvc = getDataService()
	if dataSvc and dataSvc:IsActive() then
		skinId, effectId = dataSvc:GetEquippedWeapon(player)
	elseif InventoryManager then
		skinId, effectId = InventoryManager.getEquippedSkin(player.UserId)
	end
	local template = skinId and KnifeSkinManager.getTemplate(skinId) or nil
	if not template and KnifeSkinManager.getDefaultTemplate then
		template = KnifeSkinManager.getDefaultTemplate()  -- no skin equipped -> default knife
		skinId, effectId = nil, nil
	end
	if not template then return nil, nil, nil end
	local srcHandle = template:FindFirstChild("Handle")
	if srcHandle and srcHandle:IsA("BasePart") then return srcHandle, skinId, effectId end
	return nil, nil, nil
end

-- Build (or rebuild) the back-knife for a player based on their equipped skin (or the default knife
-- if nothing is equipped).
function BackKnife.refresh(player)
	if not player then return end
	local char = player.Character
	if not char then return end
	clearFrom(char)

	-- GATE: only show the back-knife for players in the lobby (not out on the map for a live round).
	if not inLobby(player) then return end

	-- source handle: equipped skin, or the default knife if nothing is equipped
	local srcHandle, skinId, effectId = resolveSourceHandle(player)
	if not srcHandle then return end

	local torso = getTorso(char)
	if not torso then return end

	-- our cosmetic part: a copy of the handle's shape, but visual-only (no sounds/scripts/trail)
	local part = Instance.new("Part")
	part.Name = ATTACH_NAME
	part.Size = srcHandle.Size
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Anchored = false
	part.Material = srcHandle.Material
	part.Color = srcHandle.Color

	applySkinVisualFromHandle(part, srcHandle)

	-- baked-in handle VFX (e.g. the Vampire Scythe's emitters) so the back-knife shows the same aura
	-- the held knife does. Copies only the skin's EXTRA emitters, never the base SlashTrail/sounds/mesh.
	applyBakedHandleVFX(part, srcHandle)

	-- Position on the back, relative to the torso CFrame. The offset is per-skin (canes lie
	-- differently from normal knives); getOffset() returns the right one for this skin id.
	part.CFrame = torso.CFrame * getOffset(skinId)

	local srcMeshParts = {}
	for _, c in ipairs(srcHandle:GetChildren()) do
		if c:IsA("MeshPart") then
			table.insert(srcMeshParts, c)
		end
	end
	if #srcMeshParts > 0 then
		part.Transparency = 1
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
			clone.CFrame = part.CFrame * rel
			local mpWeld = Instance.new("WeldConstraint")
			mpWeld.Part0 = part
			mpWeld.Part1 = clone
			mpWeld.Parent = clone
			clone.Parent = part
		end
	end

	-- weld it to the torso so it follows the body
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = torso
	weld.Part1 = part
	weld.Parent = part

	part.Parent = char

	-- mutation VFX (firey/galaxy/etc.): same particle effect the held knife shows. Added AFTER the
	-- part is positioned + parented so the cloned emitters spawn at the right spot on the back.
	applyMutationVFX(part, effectId)
end

-- Rebuild for everyone. Called at round boundaries: at round start, players who became Hider/Seeker
-- get their model removed (role gate); when the round ends and roles clear, lobby players get it back.
function BackKnife.refreshAll()
	for _, plr in ipairs(Players:GetPlayers()) do
		task.spawn(function() BackKnife.refresh(plr) end)
	end
end

-- Back-compat aliases (older call sites used show/hide semantics; now everything routes through the
-- role-aware refresh, so these just rebuild with the gate applied).
function BackKnife.show(player) BackKnife.refresh(player) end
function BackKnife.hide(player) BackKnife.refresh(player) end
function BackKnife.showAll() BackKnife.refreshAll() end
function BackKnife.hideAll() BackKnife.refreshAll() end

function BackKnife.init()
	local function hook(plr)
		plr.CharacterAdded:Connect(function(char)
			-- wait for the torso to exist, then build (the role gate inside refresh decides if it shows)
			task.wait(0.4)
			if plr.Character == char then BackKnife.refresh(plr) end
		end)
		-- build for an already-spawned character
		if plr.Character then task.spawn(function() BackKnife.refresh(plr) end) end
	end
	for _, plr in ipairs(Players:GetPlayers()) do hook(plr) end
	Players.PlayerAdded:Connect(hook)
	Players.PlayerRemoving:Connect(function(plr) suppressed[plr.UserId] = nil end)
end

return BackKnife
