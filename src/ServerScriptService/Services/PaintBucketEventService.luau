local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local Knit = require(ReplicatedStorage.Packages.Knit)
local MapManager = require(ServerScriptService:WaitForChild("MapManager"))
local ModifierUtils = require(ServerScriptService.Modules:WaitForChild("ModifierUtils"))
local PaintBucketAI = require(ServerScriptService.Modules:WaitForChild("PaintBucketAI"))

local PaintBucketEventService = Knit.CreateService({
	Name = "PaintBucketEventService",
	Client = {
		Notify = Knit.CreateSignal(),
	},
})

local active = {
	buckets = {},
	thread = nil,
}

local CONFIG = {
	count = 4,
	duration = 60,
}

local BUCKET_TEMPLATE = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("PaintBucket")

local function randomBrightColor()
	return ModifierUtils.randomBrightColor()
end

function PaintBucketEventService:_createBucketModel(position: Vector3, color: Color3): Model
	local model = BUCKET_TEMPLATE:Clone()
	model.Name = "PaintBucket"
	model:SetAttribute("PaintColor", color)

	local hrp = model:FindFirstChild("HumanoidRootPart")
	if hrp then
		model.PrimaryPart = hrp
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.NameDisplayDistance = 0
	end

	local _, size = model:GetBoundingBox()
	local angle = math.random() * 2 * math.pi
	model:PivotTo(CFrame.new(position + Vector3.new(0, size.Y / 2, 0)) * CFrame.Angles(0, angle, 0))

	model.Parent = Workspace
	return model
end

function PaintBucketEventService:Start(count: number?, duration: number?): (boolean, string)
	if not ModifierUtils.anyInRound() then
		return false, "No active match."
	end

	self:Clear()

	local testSpawn = MapManager.getPlayerSpawnCFrame()
	if not testSpawn then
		return false, "No active map. Start a round first."
	end

	count = count or CONFIG.count
	duration = duration or CONFIG.duration

	for i = 1, count do
		local spawnCf = MapManager.getPlayerSpawnCFrame()
		local offset = Vector3.new(math.random(-12, 12), 0.1, math.random(-12, 12))
		local pos = spawnCf.Position + offset
		local color = randomBrightColor()
		local model = self:_createBucketModel(pos, color)
		print(`[PaintBucketEvent] spawned bucket {i} at {pos}`)
		local ai = PaintBucketAI.new(model)
		ai:start()
		table.insert(active.buckets, { model = model, ai = ai })
	end

	self.Client.Notify:FireAll({
		show = true,
		title = "PAINT BUCKET EVENT",
		text = `Evil paint buckets are chasing everyone and revealing hiders!`,
		duration = 6,
	})

	active.thread = task.delay(duration, function()
		self:Clear()
	end)

	return true, `Spawned {count} paint buckets for {duration}s.`
end

function PaintBucketEventService:Clear()
	local hadActive = active.thread ~= nil or #active.buckets > 0

	if active.thread then
		task.cancel(active.thread)
		active.thread = nil
	end

	for _, entry in ipairs(active.buckets) do
		entry.ai:stop()
		entry.model:Destroy()
	end
	table.clear(active.buckets)

	if hadActive then
		self.Client.Notify:FireAll({
			show = false,
			title = "PAINT BUCKET EVENT",
			text = "The paint buckets have left.",
			duration = 4,
		})
	end
end

return PaintBucketEventService
