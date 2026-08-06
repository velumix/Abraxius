-- Pathfinder
-- Stephen Leitnick
-- March 31, 2021

-- Pathfinder V2
-- Whim
-- 12/31/2022

-- C0dex Edits
-- 2026

-- Modules // SErvices --
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Mince = require(ReplicatedStorage.Modules.Mince)
local TaskScheduler = Mince.TaskScheduler

export type NodeType =  "Default" | string

export type Node = {
	Position: Vector3;
	NodeType : NodeType;
	Neighbors: {Node};
	F: number;
	G: number;
	H: number;
	Parent: Node?;
}

export type Path = {Vector3}

export type NodeMap = {
	new : (NodeMapFolder : PVInstance) -> (), 
	FindPath              : (self : NodeMap, startPosition: Vector3, goalPosition: Vector3) -> Path?,
	FindNearestNode       : (self : NodeMap, position: Vector3) -> Node,
	GetRandomNode         : (self : NodeMap) -> Node, 
	GetFirstNodeWhichIsA  : (self : NodeMap, nodeType : NodeType) -> Node,
}

-- Nodemap class 
local Nodemap = {} 
Nodemap.__index = Nodemap

function Nodemap.new(NodemapFolder : PVInstance) 
	if typeof(NodemapFolder) == "Instance" and NodemapFolder:IsA("Folder") then else 
		error("Failure whilst creating nodemap, Nodemap.new([1]) requires a folder instance.")
	end
	-- Construct a new class.
	local NewNodemap ={} 
	setmetatable(NewNodemap,Nodemap)

	NewNodemap.ProjectFolder = NodemapFolder
	NewNodemap.pathNodes = {}

	NewNodemap:__BuildNodes() 

	return NewNodemap
end

function Nodemap:__BuildNodes() 
	local nodeProjectFolder = self.ProjectFolder
	local nodes: {Node}   = {}
	local dict = {}
	-- Get nodes:

	for _,v in ipairs(nodeProjectFolder:GetChildren()) do
		if (v:IsA("Configuration")) then
			local node = {
				Position = v:GetAttribute("NodePosition");
				NodeType = v:GetAttribute("NodeType");
				Neighbors = {};
				F = 0;
				G = 0;
				H = 0;
				Parent = nil;
			}
			table.insert(nodes, node)
			dict[v:GetAttribute("NodeId")] = node
		end
	end
	-- Get node neighbors:
	for _,v in ipairs(nodeProjectFolder:GetChildren()) do
		if (v:IsA("Configuration")) then
			local links = v:GetAttribute("NodeLinks"):split(",")
			local node = dict[v:GetAttribute("NodeId")]
			for _,linkId in ipairs(links) do
				if linkId == "" then continue end 
				local neighborNode = dict[linkId]
				table.insert(node.Neighbors, neighborNode)
				table.insert(neighborNode.Neighbors, node)
			end
		end
	end

	self.pathNodes = nodes
end

function Nodemap:FindNearestNode(position: Vector3): Node
	local dist, nearest = math.huge, nil
	for _,node in ipairs(self.pathNodes) do
		local d = (position - node.Position).Magnitude
		if (d < dist) then
			dist, nearest = d, node
		end
	end
	return nearest
end


function Nodemap:GetFirstNodeWhichIsA(nodeType : NodeType): Node 
	for _,node : Node in ipairs(self.pathNodes) do 
		if node.NodeType == nodeType then 
			return node
		end
	end
end

function Nodemap:GetRandomNode(): Node 
	if #self.pathNodes == 0 then return end 
	return self.pathNodes[math.random(1,#self.pathNodes)]
end

function Nodemap:_findPathSync(startPosition: Vector3, goalPosition: Vector3): Path?
	local path = {}
	local pathFound = false

	local startNode = self:FindNearestNode(startPosition)
	local goalNode = self:FindNearestNode(goalPosition)

	local open = {[startNode] = true}
	local closed = {}

	-- Find node with lowest F score within the "open" list:
	local function FindLowestFNode()
		local lowestF, node = math.huge, nil
		for n in pairs(open) do
			if (n.F < lowestF) then
				lowestF, node = n.F, n
			end
		end
		return node
	end

	-- Find path via A* algorithm:
	while (next(open)) do

		-- Find node with lowest F score in open list.
		-- Switch that node from open list to closed list.
		local node = FindLowestFNode()
		open[node] = nil
		closed[node] = true

		-- If the node we just got is the goal node, we found the path!
		if (node == goalNode) then
			pathFound = true
			break
		end

		-- Scan through all neighbors of this node.
		for _,neighbor in ipairs(node.Neighbors) do
			-- If it's not closed, let's examine it.
			if (not closed[neighbor]) then
				-- If it's not in the open list, let's add it to the list and do some calculations on it.
				if (not open[neighbor]) then
					open[neighbor] = true
					neighbor.Parent = node
					neighbor.G = node.G + (neighbor.Position - node.Position).Magnitude
					neighbor.H = (neighbor.Position - goalNode.Position).Magnitude
					neighbor.F = (neighbor.G + neighbor.H)
				else
					-- If it is on the open list and is a good pick for the next path, let's redo some of the calculations
					if (neighbor.G < node.G) then
						neighbor.Parent = node
						neighbor.G = node.G + (neighbor.Position - node.Position).Magnitude
						neighbor.F = (neighbor.G + neighbor.H)
					end
				end
			end
		end

	end

	-- Backtrace path:
	if (pathFound) then
		local node = goalNode
		while (node) do
			table.insert(path, 1, node)
			node = node.Parent
		end
	end

	-- Reset nodes:
	local function ResetNodeDictionary(dict)
		for node in pairs(dict) do
			node.F = 0
			node.G = 0
			node.H = 0
			node.Parent = nil
		end
	end
	ResetNodeDictionary(open)
	ResetNodeDictionary(closed)

	return (pathFound and path or nil)
end

function Nodemap:FindPath(startPosition: Vector3, goalPosition: Vector3, callback: ((Path?) -> ())?, priority: number?)
	if callback then
		local scheduler = TaskScheduler.new()
		scheduler:enqueue(function()
			local result = self:_findPathSync(startPosition, goalPosition)
			callback(result)
		end, priority or TaskScheduler.Priority.NORMAL, "PathfindRequest")
		scheduler:start()
		return
	else
		return self:_findPathSync(startPosition, goalPosition)
	end
end


local Pathfinder = {
	TotalNodeMaps = {}
} 

function Pathfinder:LoadMaps(NodeMapLocation : Folder) 
	local RealMapLocation = NodeMapLocation or ReplicatedStorage.NodeMaps 
	if not RealMapLocation then 
		return warn(("Invalid or cannot find a ProjectFolder location."))
	end
	for _,NodeMapFolder in (RealMapLocation ):GetChildren() do 
		local NewNodeMap = Nodemap.new(NodeMapFolder) 

		Pathfinder.TotalNodeMaps[NodeMapFolder.Name] = NewNodeMap
	end 
end

function Pathfinder:GetNodeMap(NodeMapName : string): NodeMap 
	local __NodeMap = Pathfinder.TotalNodeMaps[NodeMapName] 
	if not __NodeMap then 
		return warn(("There is no NodeMap by the name of '%s'"):format(NodeMapName))
	end

	return __NodeMap
end

return Pathfinder