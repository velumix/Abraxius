local Case = {} 
local Case_MT = {__index= Case} 

function Case.new() 
	local self = setmetatable({}, Case_MT)  
	self.Cases = {}
	
	return self 
end

function Case:Changed(CallbackFn) 
	self.ChangedCallbackFn = CallbackFn 
end

function Case:Extend() 
	local CaseExtend = {
		Value = true, 
	} 
	
	function CaseExtend:Set(bool)
		assert(typeof(bool) == "boolean", "must set bool")
		self.Value = bool
		
		if self.ChangedCallbackFn then return self.ChangedCallbackFn(self:GetValue()) end 
	end
	 
	table.insert(self.Cases, CaseExtend)
	
	return CaseExtend	
end

function Case:GetValue() 
	for _, CaseExtend in self.Cases do 
		if not CaseExtend.Value then return false end 
	end
	
	return true 
end

return Case 