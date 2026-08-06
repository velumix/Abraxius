local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Knit = require(ReplicatedStorage.Packages.Knit)

local MapManager = require(ServerScriptService:WaitForChild("MapManager"))
local ModifierUtils = require(ServerScriptService.Modules:WaitForChild("ModifierUtils"))
local ChaosButtonEffects = require(ServerScriptService.Modules:WaitForChild("ChaosButtonEffects"))

local ChaosButtonService = Knit.CreateService({
	Name = "ChaosButtonService",
	Client = {},
})

local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local TrollBroadcast = Remotes:WaitForChild("TrollBroadcast")

local active = {
	buttons = {},
	thread = nil,
}

local CONFIG = {
	count = 4,
	duration = 90,
	pressDepth = 0.35,
	minSpacing = 12,      -- min studs between buttons so they don't pile up
}

local BUTTON_TEMPLATE = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Misc"):WaitForChild("ChaosButton")

local function getButtonsFolder()
	local folder = Workspace:FindFirstChild("ChaosButtons")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "ChaosButtons"
		folder.Parent = Workspace
	end
	return folder
end

local function playPressSound(position: Vector3)
	local template = game:GetService("SoundService"):FindFirstChild("ChaosButton")
	if not template then
		return
	end
	local emitter = Instance.new("Part")
	emitter.Name = "ChaosButtonSoundEmitter"
	emitter.Anchored = true
	emitter.CanCollide = false
	emitter.CanQuery = false
	emitter.CanTouch = false
	emitter.Transparency = 1
	emitter.Size = Vector3.new(1, 1, 1)
	emitter.CFrame = CFrame.new(position)
	emitter.Parent = Workspace

	local sound = template:Clone()
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 10
	sound.RollOffMaxDistance = 120
	sound.Parent = emitter
	sound:Play()
	sound.Ended:Once(function()
		emitter:Destroy()
	end)
	game:GetService("Debris"):AddItem(emitter, 10)
end

local function createButtonModel(position: Vector3): (Model, BasePart)
	local model = BUTTON_TEMPLATE:Clone()
	model.Name = "ChaosButton"

	local base = model.PrimaryPart or model:FindFirstChild("Base")

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = true
			descendant.CanQuery = false
		end
	end

	if base then
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 255, 255)
		light.Range = 12
		light.Brightness = 1
		light.Shadows = false
		light.Parent = base

		local pivotRot = model:GetPivot().Rotation
		local angle = math.random() * 2 * math.pi
		local yaw = CFrame.Angles(0, angle, 0)

		model:PivotTo(CFrame.new(position) * yaw * pivotRot)
		local boxCf, boxSize = model:GetBoundingBox()
		local bottomY = boxCf.Position.Y - boxSize.Z / 2
		local shift = position.Y - bottomY
		model:PivotTo(CFrame.new(position.X, position.Y + shift, position.Z) * yaw * pivotRot)
	end

	model.Parent = getButtonsFolder()
	return model, base
end

local function announceEffect(effectName: string, pressedBy: Player?)
	local pretty = effectName
	pretty = pretty:gsub("(%l)(%u)", "%1 %2") -- CamelCase -> words
	if TrollBroadcast then
		TrollBroadcast:FireAllClients({
			buyer = pressedBy and pressedBy.Name or "Chaos Button",
			target = "everyone",
			effect = pretty,
		})
	end
end

function ChaosButtonService:_spawnButton(position: Vector3)
	local model, base = createButtonModel(position)

	local entry = {
		model = model,
		base = base,
		used = false,
		touchConns = {},
	}

	local function onTouched(hit)
		if entry.used then
			return
		end

		local char = hit.Parent
		if not char then
			return
		end
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end
		local player = Players:GetPlayerFromCharacter(char)
		if not player then
			return
		end

		entry.used = true

		local buttonPart = model:FindFirstChild("Button")
		if buttonPart and buttonPart:IsA("BasePart") then
			local rest = buttonPart.CFrame
			local pressed = rest * CFrame.new(0, -CONFIG.pressDepth, 0)
			TweenService:Create(buttonPart, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = pressed }):Play()
			task.delay(0.15, function()
				if buttonPart and buttonPart.Parent then
					TweenService:Create(buttonPart, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = rest }):Play()
				end
			end)
		end

		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.Color = Color3.fromRGB(120, 120, 120)
			elseif descendant:IsA("Texture") then
				descendant.Color3 = Color3.fromRGB(120, 120, 120)
			end
		end

		if base then
			playPressSound(base.Position)
		end

		task.delay(0.5, function()
			if model and model.Parent then
				model:Destroy()
			end
		end)

		local effectName = ChaosButtonEffects.getRandomEffectName()
		local origin = base and base.Position or position
		local ok, err = pcall(function()
			ChaosButtonEffects.run(effectName, origin, player, model)
			announceEffect(effectName, player)
		end)
		if not ok then
			warn(`[ChaosButtonService] effect {effectName} failed: {err}`)
		end
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(entry.touchConns, descendant.Touched:Connect(onTouched))
		end
	end

	table.insert(active.buttons, entry)
end

function ChaosButtonService:Start(count: number?, duration: number?): (boolean, string)
	if not ModifierUtils.anyInRound() then
		return false, "No active match."
	end

	self:Clear()

	if not MapManager.isLoaded() then
		return false, "No active map. Start a round first."
	end

	count = count or CONFIG.count
	duration = duration or CONFIG.duration

	local placedPositions = {}
	for _ = 1, count do
		local pos = nil
		for _ = 1, 30 do
			local candidate = MapManager.getCoinSpawnPosition(0.6)
			if candidate then
				candidate = candidate - Vector3.new(0, 0.6, 0)
			else
				local cf = MapManager.getPlayerSpawnCFrame()
				if cf then
					candidate = cf.Position + Vector3.new(math.random(-8, 8), 0, math.random(-8, 8))
				end
			end
			if candidate then
				local tooClose = false
				for _, existing in ipairs(placedPositions) do
					if (existing - candidate).Magnitude < CONFIG.minSpacing then
						tooClose = true
						break
					end
				end
				if not tooClose then
					pos = candidate
					break
				end
			end
		end
		if pos then
			table.insert(placedPositions, pos)
			self:_spawnButton(pos)
		end
	end

	if #active.buttons == 0 then
		return false, "Could not find any valid button spawn positions."
	end

	active.thread = task.delay(duration, function()
		self:Clear()
	end)

	return true, `Spawned {#active.buttons} chaos buttons for {duration}s.`
end

function ChaosButtonService:Clear()
	if active.thread then
		task.cancel(active.thread)
		active.thread = nil
	end

	for _, entry in ipairs(active.buttons) do
		for _, conn in ipairs(entry.touchConns or {}) do
			conn:Disconnect()
		end
		if entry.model and entry.model.Parent then
			entry.model:Destroy()
		end
	end
	table.clear(active.buttons)

	local folder = Workspace:FindFirstChild("ChaosButtons")
	if folder then
		folder:Destroy()
	end
end

return ChaosButtonService
