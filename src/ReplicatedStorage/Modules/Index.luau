return function(FirstInstance : Instance, ...) 
	if not FirstInstance then 
		return 
	end
	
	assert(typeof(FirstInstance) == "Instance", "FirstInstance must be type Instance")
	
	local Head = FirstInstance 
	local IndexChain : {string} = {...}  
	for _, ThisIndex : string in IndexChain do 
		Head = Head:WaitForChild(ThisIndex)
	end
	
	return Head 
end