local KeyListener = {} 
local KeyListenerSuper = {
	KeyListners = {},
	LookupByStack = {},
}
KeyListener.__index = KeyListener

function KeyListenerSuper:ProcessKey(InputObject : InputObject, InputState : Enum.UserInputState) 
	local KeyListnerRecord = KeyListenerSuper.LookupByStack[InputObject.KeyCode] 
	if not KeyListnerRecord then return end 
	for _, KeyListner in KeyListnerRecord do 
		KeyListner:Process(InputObject, InputState)
	end
end

function KeyListener.new(...) 
	local self = setmetatable({}, KeyListener) 
	self:init() 
	self:Or({...})

	table.insert(KeyListenerSuper.KeyListners, self)
	return self 
end

function KeyListener:init() 
	self.Registered = {} 
	self.Events = {} 
	self.KeyConfig = {} 

	self.IsHeld = false 
end

function KeyListener:RegisterWith(Keys, Record) 
	local RegisterKey = function(KeyCode : Enum.KeyCode) 
		if self.Registered[KeyCode] then return end 
		KeyListenerSuper.LookupByStack[KeyCode] =KeyListenerSuper.LookupByStack[KeyCode] or {} 
		table.insert(KeyListenerSuper.LookupByStack[KeyCode], self)
		self.Registered[KeyCode] = {false}  

		if Record == "Single" then 
			self.Registered[KeyCode][2] = true 
		end
	end

	for _, Key in Keys do 
		RegisterKey(Key)
	end

	return self 
end

function KeyListener:Or(Keys) 
	return self:RegisterWith(Keys, "Single")
end

function KeyListener:And(Keys) 
	return self:RegisterWith(Keys, "Multiple")
end

function KeyListener:Record(Key, EventFn) 
	self.Events[Key] = EventFn
end

function KeyListener:Fire(Key, ...)
	local _ = self.Events[Key] and self.Events[Key](...)
end

function KeyListener:Process(InputObject : InputObject, InputState : Enum.UserInputState) 
	local Record = self.Registered[InputObject.KeyCode]
	local FirstState = Record[1] 
	if InputState == Enum.UserInputState.Begin then  
		if Record[2] or not Record[1] then 
			self:Fire("Begin", InputObject) 
			Record[1] = true
		end

	elseif InputState == Enum.UserInputState.End then 
		if Record[2] or Record[1] then 
			self:Fire("End", InputObject)
			Record[1] = false 
		end
	end

	if Record[2] or FirstState ~= Record[1] then 
		self:Fire("Changed", InputObject, InputState)
	end
end

function KeyListener:Begin(EventFn) 
	self:Record("Begin", EventFn) return self 
end
function KeyListener:End(EventFn) 
	self:Record("End", EventFn) return self 	
end

function KeyListener:Changed(EventFn) 
	self:Record("Changed", EventFn)	return self
end

KeyListenerSuper.new = KeyListener.new 

return KeyListenerSuper