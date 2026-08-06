local RunService = game:GetService("RunService")
local Signal = require(script.Parent.Signal)

local SplineSolver = {}
SplineSolver.__index = SplineSolver

local SCRIPTED_FISH_PATH_SPLINE_RESOLUTION = 200
local DEFAULT_OPTIONS = {
	Speed = 10,
	Looped = false,
	Offset = CFrame.new()
}

local function solveScriptedPathSplineSection(P0,P1,P2,P3,SolvingList)

	for i = 0,SCRIPTED_FISH_PATH_SPLINE_RESOLUTION-1 do
		local t = i/SCRIPTED_FISH_PATH_SPLINE_RESOLUTION


		local Val = 0.5 *
			((2 * P1) +
				(-P0 + P2)*t +
				(2*P0 - 5*P1 + 4*P2 - P3) * t^2 +
				(-P0 + 3*P1- 3*P2 + P3) * t^3)

		SolvingList[#SolvingList + 1] = Val
	end
end

local function solveScriptedPathSpline(Looped : boolean,Points : {Vector3})
	local SolvingList = {}
	if Looped then
		local Index = 0
		local PointCount = #Points
		for i = 1,#Points do
			solveScriptedPathSplineSection(
				Points[(i)%PointCount+1],
				Points[(i+1)%PointCount+1],
				Points[(i+2)%PointCount+1],
				Points[(i+3)%PointCount+1],
				SolvingList
			)
		end
	else
		local Index = 0
		for i = 1,#Points - 3 do
			solveScriptedPathSplineSection(
				Points[i],
				Points[i+1],
				Points[i+2],
				Points[i+3],
				SolvingList
			)
		end
	end
	return SolvingList
end

function SplineSolver.new(object, nodes, options)
	local self = {}
	self.nodes = nodes
	self.speed = options.Speed or DEFAULT_OPTIONS.Speed
	self.looped = options.Looped or DEFAULT_OPTIONS.Looped
	self.offset = options.Offset or DEFAULT_OPTIONS.Offset

	self.vectors = {}
	self.vectorToPart = {}
	self.object = object

	self.currentNode = 1
	self.isCompleted = false

	self.NodeReached = Signal.new()
	self.Completed = Signal.new()

	self.steppedConn = nil
	self = setmetatable(self, SplineSolver)
	self:SetPath(nodes)

	return self
end

function SplineSolver:SetPath(nodes)
	if self.steppedConn then
		warn("You cannot change the path of the spline while it's running!")
		return
	end


	self.vectors = {}
	self.vectorToPart = {}

	for _, part in nodes:GetChildren() do
		local index = tonumber(part.Name)
		self.vectors[index] = part.Position
		self.vectorToPart[part.Position] = part
	end

	self.spline = solveScriptedPathSpline(self.looped, self.vectors)
	self.numOfNodes = #self.spline
end

function SplineSolver:SetSpeed(newSpeed)
	self.speed = newSpeed
end

function SplineSolver:GetNextNode(nodeNum)
	local nextNodeIndex = 0

	if self.looped then
		nextNodeIndex = (nodeNum % self.numOfNodes) + 1
	else
		nextNodeIndex = nodeNum + 1

		if nextNodeIndex > self.numOfNodes then
			self.isCompleted = true
			self.Completed:Fire()
			return
		end
	end

	return nextNodeIndex
end

function SplineSolver:Update(deltaTime)
	local travelDistance = self.speed * deltaTime

	while travelDistance > 0 and not self.isCompleted do
		local node = self.spline[self.currentNode]
		local nextNodeIndex = self:GetNextNode(self.currentNode)
		local nextNode = self.spline[nextNodeIndex]

		local objectPosition = self.object:GetPivot().Position
		local nextNodeOffset = (nextNode - objectPosition)
		local nextNodeDistance = nextNodeOffset.Magnitude

		local nextNextNodeIndex = self:GetNextNode(self.currentNode + 2)
		local nextNextNode = self.spline[nextNextNodeIndex]

		if not nextNextNode then
			nextNextNode = nextNode + (nextNode - node)
		end

		if nextNodeDistance < travelDistance then
			travelDistance -= nextNodeDistance

			self.object:PivotTo(
				CFrame.lookAt(nextNode, nextNextNode) * self.offset
			)

			if self.vectorToPart[nextNode] then
				local nodeThatWasReached = self.vectorToPart[nextNode]
				self.NodeReached:Fire(nodeThatWasReached)
			end

			self.currentNode += 1
		else
			local newPosition = objectPosition + (travelDistance / nextNodeDistance) * nextNodeOffset
			self.object:PivotTo(
				CFrame.lookAt(newPosition, nextNextNode) * self.offset
			)

			travelDistance = 0
		end
	end
end

function SplineSolver:Start()
	if self.steppedConn then
		warn("Solver is already running")
		return
	end

	self.object:PivotTo(CFrame.new(self.spline[1]) * self.offset)
	self.NodeReached:Fire(self.vectorToPart[self.vectors[2]])

	self.steppedConn = RunService.Stepped:Connect(function(_, deltaTime)
		self:Update(deltaTime)
	end)
end

function SplineSolver:Stop()

	if self.steppedConn then
		self.steppedConn:Disconnect()
		self.steppedConn = nil
	end
end

return SplineSolver