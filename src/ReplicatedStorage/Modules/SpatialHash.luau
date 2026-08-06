local SpatialHash = {
	Axis = Vector3.new(1,0,1),
	Round = math.round,

	Version = "0.1"
} 

-- This is a BoundingBox based spatial query that doesnt require checking neighbors.
-- It dynamically updates with size and position changes, or in schedules for items with frequent changes. 
-- It can have near-zero cost with static objects and a still player. 
-- It takes advantage of recording changes in grids, so you can tell when updates happen.
-- The querying doesnt have to be done every frame with SpatialMap:StreamFromPosition().


function SpatialHash.ShallowArrayCompare(A, B) 
	if #A ~= #B then return false end 
	for Index,Value in A do 
		if B[Index] ~= Value then return false end
	end
	return true 
end 

function SpatialHash.GridID(Size) 
	local IDSize = Size or 8
	local ID = "" 
	for _=1,IDSize do 
		ID..= string.format("%x", math.random(0,255))
	end
	return ID 
end

function SpatialHash.MapPositionToGridID(MapPosition : Vector3) 
	return string.format("%x", MapPosition.X) .. 
		string.format("%x", MapPosition.Y) .. 
		string.format("%x", MapPosition.Z)
end

function SpatialHash.MapPosition(SpatialMap,Position : Vector3)
	local XRound = SpatialHash.Round(Position.X/SpatialMap.Size) * SpatialMap.Size 
	local ZRound = SpatialHash.Round(Position.Z/SpatialMap.Size) * SpatialMap.Size 

	return Vector3.new(XRound/SpatialMap.Size,ZRound/SpatialMap.Size)	
end

function SpatialHash.StreamFromPosition(SpatialMap, WorldPosition, Radius, LoadFn, DeloadFn) 
	debug.profilebegin("SpatialHash // StreamFromPosition")

	local MapID = SpatialMap.GetMapID(WorldPosition)

	SpatialMap.CurrentLoaded = SpatialMap.CurrentLoaded or {} 


	if MapID ~= SpatialMap.LastMapID or SpatialMap.CheckObjectMapsDiffernce(SpatialMap.CurrentObjectMaps) then 
		local NextLoaded, LoadedObjectMaps = SpatialMap.GetObjectMapsInRadius(WorldPosition, Radius)

		for _,Part : BasePart in ipairs(SpatialMap.CurrentLoaded) do 
			if not NextLoaded[Part] then 
				LoadFn(Part)
			end
		end

		-- Only load in new ones that arent currentloaded
		for _,Part : BasePart in ipairs(NextLoaded) do  
			if not SpatialMap.CurrentLoaded[Part] then 
				DeloadFn(Part)
			end
		end	

		SpatialMap.CurrentObjectMaps = LoadedObjectMaps
		SpatialMap.CurrentLoaded = NextLoaded
		SpatialMap.LastMapID = MapID
	end	

	debug.profileend() 
end

function SpatialHash.NewMap(Size, ShouldUpdate) 
	local SpatialMap = {
		Object = {}, 
		Location = {}, 
		Size = Size,	

		EmptyMapCheckRate = 0.5, 

		ObjectMapsIDMemory = {},
		LastComparedObjectMaps = {},

		PartEvents = {}, 
	} 

	SpatialMap.CheckObjectMapsDiffernce = function(ObjectMaps)  
		if not ObjectMaps or next(ObjectMaps) == nil then 
			if os.clock() - (SpatialMap.LastCheckedEmptyMaps or 0) < SpatialMap.EmptyMapCheckRate then return end 
			SpatialMap.LastCheckedEmptyMaps = os.clock() 

			return true 
		end 
		if SpatialMap.LastComparedObjectMaps and not SpatialHash.ShallowArrayCompare(SpatialMap.LastComparedObjectMaps,ObjectMaps) then SpatialMap.LastComparedObjectMaps = ObjectMaps; SpatialMap.ObjectMapsIDMemory = {} return true end -- If the last object mpas changed 

		for _,ObjectMap in ObjectMaps do 
			local ObjectIDMemory = SpatialMap.ObjectMapsIDMemory[ObjectMap] or ObjectMap.ID 

			if ObjectMap.ID ~= ObjectIDMemory then
				SpatialMap.ObjectMapsIDMemory[ObjectMap] = ObjectMap.ID 

				return true 
			end

			SpatialMap.ObjectMapsIDMemory[ObjectMap] = ObjectMap.ID 
		end

		return false 
	end

	SpatialMap.Insert = function(Position,BasePart) 
		local ObjectMap = SpatialMap.Object[Position] 

		if not ObjectMap then 
			SpatialMap.Object[Position] = {} 
			ObjectMap =SpatialMap.Object[Position]
		end

		ObjectMap.ID = SpatialHash.GridID()

		-- Save Location
		table.insert(SpatialMap.Location[BasePart],Position)
		table.insert(ObjectMap,BasePart)
	end

	SpatialMap.Remove = function(Position,BasePart)
		local ObjectMap = SpatialMap.Object[Position] 

		if ObjectMap then 
			ObjectMap.ID = SpatialHash.GridID()

			table.remove(ObjectMap,table.find(ObjectMap,BasePart)) 
			if #ObjectMap == 0 then 
				SpatialMap.Object[Position] = nil -- This will clean it up 
			end
		end
	end


	SpatialMap.GetPartsInPart = function(BasePart) 
		local SizeCancel = BasePart.Size

		local TopLeftRawVector = BasePart.Position - (SizeCancel/2) 
		local BottomRightRawVector = BasePart.Position + (SizeCancel/2)

		local TopLeft     : Vector3 = SpatialHash.MapPosition(SpatialMap,TopLeftRawVector) 
		local BottomRight : Vector3 = SpatialHash.MapPosition(SpatialMap,BottomRightRawVector)

		local Parts = {} 

		for X = TopLeft.X,BottomRight.X do 
			for Y = TopLeft.Y,BottomRight.Y do 
				local MapPosition = Vector3.new(X,Y) 
				local SubParts = SpatialMap.Object[MapPosition] 

				if SubParts then 
					for _,Part in SubParts do 
						table.insert(Parts,Part)
					end
				end
			end
		end 

		return Parts
	end

	SpatialMap.GetPartsInRadius = function(WorldPosition : Vector3,ChunkRadius : number,IgnoreDistance : boolean) 
		local Parts = {} 
		local SpatialPosition  : Vector3 = SpatialHash.MapPosition(SpatialMap, WorldPosition) 

		local Radius = ChunkRadius + 0.5 
		local RadiusSq = Radius * Radius
		local Diameter = Radius * 2 
		local SideLength = (Diameter-1)/2 

		for X = SpatialPosition.X-SideLength, SpatialPosition.X+SideLength do 
			for Y = SpatialPosition.Y-SideLength, SpatialPosition.Y+SideLength do 
				local MapPosition = Vector3.new(X,Y) 
				local Offset = SpatialPosition - MapPosition
				local DistanceSq = Offset:Dot(Offset)
				local SubParts = SpatialMap.Object[MapPosition] 

				if SubParts and (IgnoreDistance or DistanceSq < RadiusSq) then 
					for _,Part in ipairs(SubParts) do 
						if SpatialMap.CompareWorld and SpatialMap.CompareWorld(Part.Position, WorldPosition) then 
							continue; 
						end

						if not Parts[Part] then 
							Parts[Part] = true  
							table.insert(Parts,Part)
						end
					end
				end
			end
		end

		return Parts
	end

	SpatialMap.GetObjectMapsInRadius = function(WorldPosition : Vector3,ChunkRadius : number, IgnoreDistance : boolean) 
		local Parts = {} 
		local ObjectMaps = {} 
		local SpatialPosition  : Vector3 = SpatialHash.MapPosition(SpatialMap,WorldPosition) 

		local Radius = ChunkRadius + 0.5 
		local RadiusSq = Radius * Radius
		local Diameter = Radius * 2 
		local SideLength = (Diameter-1)/2 

		for X = SpatialPosition.X-SideLength, SpatialPosition.X+SideLength do 
			for Y = SpatialPosition.Y-SideLength, SpatialPosition.Y+SideLength do 
				local MapPosition = Vector3.new(X,Y) 
				local Offset = SpatialPosition - MapPosition
				local DistanceSq = Offset:Dot(Offset)
				local ObjectMap = SpatialMap.Object[MapPosition]

				if ObjectMap and (IgnoreDistance or DistanceSq < RadiusSq) then 
					table.insert(ObjectMaps, ObjectMap)

					for _,Part in ipairs(ObjectMap) do 
						if not Parts[Part] then 
							Parts[Part] = true  
							table.insert(Parts,Part)
						end
					end
				end
			end
		end

		return Parts, ObjectMaps
	end 

	SpatialMap.GetMapPosition = function(WorldPosition : Vector3) 
		return SpatialHash.MapPosition(SpatialMap,WorldPosition) 
	end

	SpatialMap.GetMapID = function(WorldPosition : Vector3) 
		local SpatialPosition  : Vector3 = SpatialHash.MapPosition(SpatialMap,WorldPosition) 
		local ObjectMap = SpatialMap.Object[SpatialPosition] 
		return ObjectMap and ObjectMap.ID or SpatialHash.MapPositionToGridID(SpatialPosition) , ObjectMap or {} 
	end

	SpatialMap.GetPartsAtPosition = function(WorldPosition : Vector3) 
		local SpatialPosition  : Vector3 = SpatialHash.MapPosition(SpatialMap,WorldPosition) 
		return SpatialMap.Object[SpatialPosition] or {} 
	end

	SpatialMap.Detach = function(BasePart : BasePart) 
		if SpatialMap.PartEvents[BasePart] then 
			SpatialMap.PartEvents[BasePart]:Disconnect() 
			SpatialMap.PartEvents[BasePart] = nil 
		end

		local SpatialLocation = SpatialMap.Location[BasePart] 

		if SpatialLocation then -- Remove it all it shall no longer exist!
			for _,Position in SpatialLocation do 
				SpatialMap.Remove(Position, BasePart)
			end 
		end

		SpatialMap.Location[BasePart] = nil -- This will cleanup any lcoation for the basepart
	end

	SpatialMap.Add = function(BasePart : BasePart) 
		SpatialHash.InsertBasePart(SpatialMap, BasePart, ShouldUpdate) 
	end

	SpatialMap.StreamFromPosition = SpatialHash.StreamFromPosition 

	return SpatialMap
end

function SpatialHash.UpdateBasePart(SpatialMap, BasePart : BasePart)
	-- Firstly remove all of the location storing.
	local SpatialLocation = SpatialMap.Location[BasePart] 
	if SpatialLocation then -- Remove the previous locations so it can be updated.
		for _,Position in SpatialLocation do 
			SpatialMap.Remove(Position, BasePart)
		end 
	end
	SpatialMap.Location[BasePart] = {} -- This will reset the locations storage. 


	local IterateSize = SpatialMap.Size/2
	local SizeCancel = BasePart.Size * SpatialHash.Axis	
	local Orientation = BasePart.Orientation 
	local CanDoCheapInsertion = Orientation.X % 90 == 0 and 
		Orientation.Y % 90 == 0 and 
		Orientation.Z % 90 == 0 


	if CanDoCheapInsertion then -- The rotations are made up of compeltely 90 degree turns. so basic AABB still applies.
		local TopLeftRawVector = BasePart.Position - (SizeCancel/2) 
		local BottomRightRawVector = BasePart.Position + (SizeCancel/2)
		local TopLeft     : Vector3 = SpatialHash.MapPosition(SpatialMap,TopLeftRawVector) 
		local BottomRight : Vector3 = SpatialHash.MapPosition(SpatialMap,BottomRightRawVector)

		local Counted = {} 

		for X = TopLeft.X,BottomRight.X do 
			for Y = TopLeft.Y,BottomRight.Y do 
				local MapPosition = Vector3.new(X,Y) 

				if not Counted[MapPosition] then 
					Counted[MapPosition] = true 

					SpatialMap.Insert(MapPosition,BasePart)
				end 
			end
		end

	else  -- This is when we use CFrame magic math to get the actual world positions on the corners of the basepart. We get all points so we can create a bounding box.
		local TopLeftSizeVector = -(SizeCancel/2) 
		local BottomRightSizeVector = (SizeCancel/2)

		local Counted = {} 

		for X = TopLeftSizeVector.X,BottomRightSizeVector.X,IterateSize do 
			for Z = TopLeftSizeVector.Z,BottomRightSizeVector.Z,IterateSize do 
				local RawPositionVector = BasePart.CFrame:ToWorldSpace(CFrame.new(X,0,Z)).Position -- This is done instead of the alternative faster math. Because it's like 30 lines longer. 
				local MapPosition = SpatialHash.MapPosition(SpatialMap,RawPositionVector)

				if not Counted[MapPosition] then 
					Counted[MapPosition] = true 

					SpatialMap.Insert(MapPosition,BasePart)
				end
			end
		end
	end
end

function SpatialHash.InsertBasePart(SpatialMap, BasePart : BasePart, ShouldUpdate) 
	SpatialHash.UpdateBasePart(SpatialMap,BasePart)

	if ShouldUpdate then 
		BasePart:GetPropertyChangedSignal("Position"):Connect(function() 
			SpatialHash.UpdateBasePart(SpatialMap,BasePart)
		end)
		BasePart:GetPropertyChangedSignal("Size"):Connect(function()
			SpatialHash.UpdateBasePart(SpatialMap,BasePart)
		end)
	end



	SpatialMap.PartEvents[BasePart] = BasePart.Destroying:Once(function() 
		local SpatialLocation = SpatialMap.Location[BasePart] 

		if SpatialLocation then -- Remove it all it shall no longer exist!
			for _,Position in SpatialLocation do 
				SpatialMap.Remove(Position,BasePart)
			end 
		end

		SpatialMap.Location[BasePart] = nil -- This will cleanup any lcoation for the basepart
	end)
end


return SpatialHash