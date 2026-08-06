-- PlayerCollisionGroup: puts every living player's body parts into the "Player" collision group so
-- that ragdoll corpses (in the "Corpse" group) pass through living players, AND so living players
-- pass through EACH OTHER (no player-to-player pushing). Players still collide with the map.
-- Collision groups don't affect raycasts, CanQuery, or Touched logic, so this is safe for the
-- knife/coins/etc.

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")

local GROUP = "Player"

-- make sure the group exists (it's also registered in edit mode, but be safe at runtime)
if not PhysicsService:IsCollisionGroupRegistered(GROUP) then
	PhysicsService:RegisterCollisionGroup(GROUP)
end
-- Apply collidability settings UNCONDITIONALLY (not only on first registration), so the
-- player-vs-player = false rule always takes effect even if the group was pre-registered in edit mode.
PhysicsService:CollisionGroupSetCollidable(GROUP, GROUP, false)   -- players pass through each other
PhysicsService:CollisionGroupSetCollidable(GROUP, "Default", true) -- but still collide with the map/world

-- "Corpse" group for ragdoll/dead bodies. Corpses must REST ON the map (collide with Default) but
-- pass through living players and through each other, so they never shove players around or pile up
-- into a physics mess. RagdollCorpse assigns parts to this group; we must register it + set its rules
-- here or the corpse falls through the world (unregistered group = no guaranteed map collision).
local CORPSE_GROUP = "Corpse"
if not PhysicsService:IsCollisionGroupRegistered(CORPSE_GROUP) then
	PhysicsService:RegisterCollisionGroup(CORPSE_GROUP)
end
PhysicsService:CollisionGroupSetCollidable(CORPSE_GROUP, "Default", true)    -- corpses rest on the map
PhysicsService:CollisionGroupSetCollidable(CORPSE_GROUP, GROUP, false)       -- pass through living players
PhysicsService:CollisionGroupSetCollidable(CORPSE_GROUP, CORPSE_GROUP, false) -- corpses pass through each other

local function setPart(part)
	if part:IsA("BasePart") then
		part.CollisionGroup = GROUP
	end
end

local function onCharacter(char)
	for _, d in ipairs(char:GetDescendants()) do setPart(d) end
	char.DescendantAdded:Connect(setPart)  -- catch limbs/accessories added later
end

local function onPlayer(plr)
	if plr.Character then onCharacter(plr.Character) end
	plr.CharacterAdded:Connect(onCharacter)
end

for _, plr in ipairs(Players:GetPlayers()) do onPlayer(plr) end
Players.PlayerAdded:Connect(onPlayer)
