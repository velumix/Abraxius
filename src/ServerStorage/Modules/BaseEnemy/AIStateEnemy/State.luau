local State = {} 

-- Factory! All of the class code is container within the constructor!
function State.new(StateName)
	local State = {
		Enabled = true 
	} 
	
	State.Init = function()end 
	State.Update = function()end 
	State.Switch = function()end 
	State.Exit = function()end
	
	return State
end

return State 


 