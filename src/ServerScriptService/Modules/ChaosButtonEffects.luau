-- ChaosButtonEffects: the individual outcomes triggered when a giant chaos button is pressed.
-- Each effect is self-contained and cleans itself up.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local ServerScriptService = game:GetService("ServerScriptService")

local CoinSpawner = require(ServerScriptService:WaitForChild("CoinSpawner"))
local ModifierUtils = require(ServerScriptService.Modules:WaitForChild("ModifierUtils"))
local StudsConverter = require(ServerStorage:WaitForChild("StudsConverter"))

local ChaosButtonEffects = {}

local EFFECT_ORDER = {
	"DropCoins",
	"SpawnGlue",
	"RevealEveryone",
	"SwapColors",
	"SpawnFakeHiders",
	"FlingEveryone",
}

function ChaosButtonEffects.getRandomEffectName(): string
	return EFFECT_ORDER[math.random(1, #EFFECT_ORDER)]
end

function ChaosButtonEffects.listEffectNames(): { string }
	return table.clone(EFFECT_ORDER)
end

-- ===== DROP COINS =====
function ChaosButtonEffects.dropCoins(origin: Vector3, amount: number?, buttonModel: Model?)
	amount = amount or 20

	-- blow up the button as coins burst out
	if buttonModel then
		task.spawn(function()
			for _, part in ipairs(buttonModel:GetDescendants()) do
				if part:IsA("BasePart") then
					TweenService:Create(part, TweenInfo.new(0.15), { Transparency = 1 }):Play()
				end
			end
			task.wait(0.2)
			buttonModel:Destroy()
		end)
	end

	local trailColor = Color3.fromRGB(255, 210, 80)
	for _ = 1, amount do
		local angle = math.random() * math.pi * 2
		local horizontal = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local speed = 20 + math.random() * 25
		local up = 25 + math.random() * 20
		local spread = Vector3.new(math.random(-8, 8), 0, math.random(-8, 8))
		local velocity = horizontal * speed + Vector3.new(0, up, 0) + spread
		CoinSpawner.spawnFlyingCoin(origin, velocity, trailColor)
	end
end

-- ===== SPAWN GLUE =====
local glueSlows = {}

function ChaosButtonEffects.spawnGlue(origin: Vector3, puddleCount: number?, duration: number?)
	puddleCount = puddleCount or 10
	duration = duration or 15
	local GLUE_SLOW = 8
	local GLUE_SLOW_DURATION = 3
	local GLUE_COLOR = Color3.fromRGB(255, 80, 180)
	local PUDDLE_SIZE = 8

	local function makePuddle(pos: Vector3)
		local puddle = Instance.new("Part")
		puddle.Name = "GluePuddle"
		puddle.Shape = Enum.PartType.Cylinder
		puddle.Size = Vector3.new(0.2, PUDDLE_SIZE, PUDDLE_SIZE)
		puddle.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
		puddle.Anchored = true
		puddle.CanCollide = false
		puddle.CanTouch = true
		puddle.CanQuery = false
		puddle.Color = GLUE_COLOR
		puddle.Material = Enum.Material.Neon
		puddle.Transparency = 0.35
		puddle.Parent = Workspace

		local light = Instance.new("PointLight")
		light.Color = GLUE_COLOR
		light.Range = 10
		light.Brightness = 1
		light.Shadows = false
		light.Parent = puddle

		local conn = puddle.Touched:Connect(function(hit)
			local char = hit:FindFirstAncestorOfClass("Model")
			if not char then return end
			local player = Players:GetPlayerFromCharacter(char)
			if not player then return end
			local hum = char:FindFirstChildOfClass("Humanoid")
			if not hum or hum.Health <= 0 then return end
			if glueSlows[player] then return end

			glueSlows[player] = true
			local original = hum.WalkSpeed
			hum.WalkSpeed = GLUE_SLOW

			task.delay(GLUE_SLOW_DURATION, function()
				if player and player.Parent then
					local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
					if h then
						h.WalkSpeed = original
					end
				end
				glueSlows[player] = nil
			end)
		end)

		task.delay(duration, function()
			if conn then
				conn:Disconnect()
			end
			if puddle and puddle.Parent then
				puddle:Destroy()
			end
		end)
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {}

	for _ = 1, puddleCount do
		local angle = math.random() * math.pi * 2
		local dist = math.random() * 16
		local offset = Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
		local target = origin + offset

		local floorY = origin.Y
		local hit = Workspace:Raycast(target + Vector3.new(0, 4, 0), Vector3.new(0, -8, 0), params)
		if hit then
			floorY = hit.Position.Y
		end

		makePuddle(Vector3.new(target.X, floorY + 0.1, target.Z))
	end
end

-- ===== REVEAL EVERYONE =====
function ChaosButtonEffects.revealEveryone(duration: number?)
	duration = duration or 5
	ModifierUtils.forEachHider(function(player)
		local character = player.Character
		if not character then
			return
		end

		local existing = character:FindFirstChild("ChaosReveal")
		if existing then
			existing:Destroy()
		end

		local highlight = Instance.new("Highlight")
		highlight.Name = "ChaosReveal"
		highlight.FillColor = Color3.fromRGB(255, 40, 40)
		highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
		highlight.FillTransparency = 0.5
		highlight.OutlineTransparency = 0
		highlight.Parent = character

		task.delay(duration, function()
			if highlight and highlight.Parent then
				highlight:Destroy()
			end
		end)
	end)
end

-- ===== SWAP COLORS =====
local STUD_TAG = "StudsCamoTexture"
local swapCaches = setmetatable({}, { __mode = "k" })

function ChaosButtonEffects.swapColors(duration: number?)
	duration = duration or 8
	local color = ModifierUtils.randomBrightColor()

	ModifierUtils.forEachPlayerInRound(function(player)
		local character = player.Character
		if not character then
			return
		end

		local cache = {}
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
				local textures = {}
				for _, child in ipairs(part:GetChildren()) do
					if child:IsA("Texture") and child.Name == STUD_TAG then
						textures[child] = child.Color3
					end
				end
				cache[part] = { color = part.Color, textures = textures }
			end
		end
		swapCaches[character] = cache

		for part in pairs(cache) do
			StudsConverter.paintPart(part, color)
		end

		task.delay(duration, function()
			local c = swapCaches[character]
			if not c then
				return
			end
			swapCaches[character] = nil
			for part, data in pairs(c) do
				if part and part.Parent then
					part.Color = data.color
					for tex, col in pairs(data.textures) do
						if tex and tex.Parent then
							tex.Color3 = col
						end
					end
				end
			end
		end)
	end)
end

-- ===== SPAWN FAKE HIDERS =====
function ChaosButtonEffects.spawnFakeHiders(count: number?, duration: number?)
	count = count or 4
	duration = duration or 25

	local fakeFolder = Workspace:FindFirstChild("FakeHiders")
	if not fakeFolder then
		fakeFolder = Instance.new("Folder")
		fakeFolder.Name = "FakeHiders"
		fakeFolder.Parent = Workspace
	end

	local function randomUserId(): number
		local players = Players:GetPlayers()
		if #players > 0 then
			return players[math.random(1, #players)].UserId
		end
		return 1
	end

	for _ = 1, count do
		local pos = ModifierUtils.getRandomMapPosition(0.5)
		if not pos then
			continue
		end

		local userId = randomUserId()
		local ok, dummy = pcall(function()
			return Players:CreateHumanoidModelFromUserId(userId)
		end)
		if not ok or not dummy then
			continue
		end

		dummy.Name = "FakeHider"
		for _, descendant in ipairs(dummy:GetDescendants()) do
			if descendant:IsA("Script") or descendant:IsA("LocalScript") then
				descendant:Destroy()
			end
		end

		local humanoid = dummy:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = 0
			humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			humanoid.NameDisplayDistance = 0
		end

		local root = dummy:FindFirstChild("HumanoidRootPart")
		if root then
			root.Anchored = true
		end

		pcall(function()
			dummy:ScaleTo(1)
		end)
		dummy:PivotTo(CFrame.new(pos))

		local color = ModifierUtils.randomBrightColor()
		for _, part in ipairs(dummy:GetDescendants()) do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
				StudsConverter.paintPart(part, color)
			end
		end

		dummy.Parent = fakeFolder
		game:GetService("Debris"):AddItem(dummy, duration)
	end
end

-- ===== FLING EVERYONE =====
function ChaosButtonEffects.flingEveryone(origin: Vector3, power: number?)
	power = power or 1.5
	ModifierUtils.forEachPlayerInRound(function(player)
		local character = player.Character
		if not character then
			return
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root or root.Anchored then
			return
		end
		local hum = character:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health <= 0 then
			return
		end

		local away = root.Position - origin
		away = Vector3.new(away.X, 0, away.Z)
		if away.Magnitude < 0.001 then
			away = Vector3.new(1, 0, 0)
		end
		away = away.Unit

		local up = 120 * power
		local side = 80 * power
		local randomSpread = Vector3.new(math.random(-50, 50), 0, math.random(-50, 50))
		local velocity = away * side + Vector3.new(0, up, 0) + randomSpread

		-- Override velocity directly; humanoid movement can't cancel it in the same frame.
		root.AssemblyLinearVelocity = velocity
		root.AssemblyAngularVelocity = Vector3.new(
			math.random(-30, 30) * power,
			math.random(-30, 30) * power,
			math.random(-30, 30) * power
		)
	end)
end

-- ===== DISPATCH =====
local EFFECT_NAMES = {}
for _, name in ipairs(EFFECT_ORDER) do
	EFFECT_NAMES[name] = true
end

function ChaosButtonEffects.run(name: string, origin: Vector3, pressedBy: Player?, buttonModel: Model?)
	if name == "DropCoins" then
		ChaosButtonEffects.dropCoins(origin, nil, buttonModel)
	elseif name == "SpawnGlue" then
		ChaosButtonEffects.spawnGlue(origin)
	elseif name == "RevealEveryone" then
		ChaosButtonEffects.revealEveryone()
	elseif name == "SwapColors" then
		ChaosButtonEffects.swapColors()
	elseif name == "SpawnFakeHiders" then
		ChaosButtonEffects.spawnFakeHiders()
	elseif name == "FlingEveryone" then
		ChaosButtonEffects.flingEveryone(origin)
	else
		warn(`[ChaosButtonEffects] unknown effect '{name}'`)
	end
end

return ChaosButtonEffects
