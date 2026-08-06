local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Modules = ReplicatedStorage.Modules

local Octree = require(Modules.Octree)
local Queue = require(Modules.Queue)
local Signal = require(Modules.Signal)

local isStudio = RunService:IsStudio()

local Player = Players.LocalPlayer
local DesiredDrawDistance = Player:GetAttribute("DrawDistance") or 200

local Current = 0
local Interval = 0.3

local FishController = {
	Name = "FishController",
	Queue = Queue.new(0.5),
	Octree = Octree.new(),
	TrackedFish = {},
	ActiveFish = {},
	SteppingConnection = nil,
	StepSignal = Signal.new(),
	FishLimits = {},
}

local function tableFind(tbl, index, value)
	for _, v in tbl do
		if v[index] == value then
			return v
		end
	end
end

function FishController:Track(fish)
	if not self.TrackedFish[fish.Instance] then
		local newNode = self.Octree:CreateNode(fish.Instance.Position, fish.Instance)

		local fishObject = {
			Node = newNode,
			Component = fish,
		}

		self.TrackedFish[fish.Instance] = fishObject
		self:StartActiveFish({ fishObject }, true)
	end
end

function FishController:ClearTrackedFish()
	for i = #self.ActiveFish, 1, -1 do
		local v = self.ActiveFish[i]
		local component = self.TrackedFish[v].Component
		self.Queue:add(component.StopSimulation, { component })
		table.remove(self.ActiveFish, i)
	end

	if #self.ActiveFish == 0 then
		self:StopStepping()
	end
end

function FishController:StopInactiveFish(nodes)
	for i = #self.ActiveFish, 1, -1 do
		local v = self.ActiveFish[i]
		if not tableFind(nodes, "Object", v) then
			local component = self.TrackedFish[v].Component
			self.Queue:add(component.StopSimulation, { component })
			table.remove(self.ActiveFish, i)
		end
	end

	if #self.ActiveFish == 0 then
		self:StopStepping()
	end
end

function FishController:StartActiveFish(nodes, Simulate)
	if not Simulate then
		return
	end
	for _, node in nodes do
		if not table.find(self.ActiveFish, node.Object) then
			local component = self.TrackedFish[node.Object].Component
			self.Queue:add(component.StartSimulation, { component })
			table.insert(self.ActiveFish, node.Object)
		end
	end

	if #self.ActiveFish > 0 and not self.SteppingConnection then
		self:StartStepping()
	end
end

function FishController:StartStepping()
	if self.SteppingConnection then
		return
	end

	self.SteppingConnection = RunService.PreSimulation:Connect(function(dt)
		if not workspace:GetAttribute("FishSimulation") then
			return
		end

		self.StepSignal:Fire(dt)
	end)
end

function FishController:StopStepping()
	if self.SteppingConnection then
		self.SteppingConnection:Disconnect()
		self.SteppingConnection = nil
	end
end

function FishController:GetComponent(BoidInstance)
	local TrackedBoid = self.TrackedFish[BoidInstance]
	if not TrackedBoid then
		error("attempted to get a instance that isnt tracked...")
	end
	return TrackedBoid.Component
end

function FishController:Setup()
	local limits = CollectionService:GetTagged("FishLimit")

	self.FishLimits = limits

	task.spawn(function()
		for _, limit in ipairs(limits) do
			limit.Transparency = 1
		end
	end)
end

function FishController:GameStart()
	if isStudio then
		if workspace:GetAttribute("FishSimulation") == false then
			return warn("Fish Simulation is disabled!")
		end
	end

	self.Heartbeat = RunService.Heartbeat:Connect(function(deltaTime)
		Current += deltaTime
		if Current >= Interval and (Player.Character and Player.Character.Parent) then
			Current = 0

			local Simulate = workspace:GetAttribute("FishSimulation")
			local nodes = self.Octree:SearchRadius(Player.Character:GetPivot().Position, DesiredDrawDistance)

			if Simulate then
				self:StopInactiveFish(nodes)
				self:StartActiveFish(nodes, Simulate)
			else
				self:ClearTrackedFish()
			end
		end
	end)
end

return FishController
