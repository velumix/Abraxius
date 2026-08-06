local MicroID = {
	benchsize = 1000000,
	range = {33, 126}, 
	r = Random.new() 
}

MicroID.factor = function()
	local seed = math.floor((os.time() * 1e6) + (os.clock() * 1e9))
	MicroID.r = Random.new(seed)
end

MicroID.gent = function(Size)
	local Position , Length , IDStr , Size = math.floor((os.time()%1000000)*1000000+os.clock()*10000000), MicroID.range[2] - MicroID.range[1], "", Size or 16
	repeat
		Position = math.floor(Position / Length) 
		if Position ~= 0 then
			IDStr = IDStr .. string.char(MicroID.range[1] + ((Position % Length) + 1) + 1 )  
		end 
	until Position == 0  

	for c = 1, Size do
		IDStr =  string.char(MicroID.r:NextInteger(MicroID.range[1], MicroID.range[2])) .. IDStr
	end  

	return IDStr
end

MicroID.gen = function(Size)
	local IDStr , Size = "", Size or 16
	for c = 1, Size do
		IDStr = IDStr .. string.char(MicroID.r:NextInteger(MicroID.range[1], MicroID.range[2]))
	end  

	return IDStr
end

task.defer(MicroID.factor)
return MicroID