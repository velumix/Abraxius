local ReplicatedStorage = game:GetService('ReplicatedStorage')

local Signal = require(ReplicatedStorage.Modules.Signal)

local CardStack = {
	ClosePrevious = true 
} 
CardStack.__index = CardStack


function CardStack.new(Proto) 
	local NewStack = setmetatable(Proto or {}, CardStack)
	NewStack:Init() 
	return NewStack 
end


function CardStack:ForEach(IterateFn) 
	for _, UIControl in ipairs(self.Stack) do 
		IterateFn(UIControl)
	end
end

function CardStack:Init() 
	self.Stack = {} 
	self.Animating = false 
	
	self.StackAdding = Signal.new() 
	self.StackAdded = Signal.new() 
	self.StackRemoving = Signal.new() 
	self.StackRemoved = Signal.new() 
end

function CardStack:Validate(UIControl) 
	if UIControl.ManualStack then 
		error("A ManuallyStacked UIControl was attempted to do a CardStack Operation! Please make sure if you plan to enter it manually you don't use Manual Methods!")
	end
end

function CardStack:Animate(AnimateFn, Bypass)
	if Bypass then return AnimateFn() end
	if self.Animating then warn("stop!") return false end
	self.Animating = true 
	local Success, Failure = pcall(function() 
		return AnimateFn() 
	end)
	self.Animating = false

	if not Success then 
		warn(`Failure while animating! '{Success}'`)
		return false 
	end
	
	return true 
end

-- Operation(s)...


function CardStack:Length() 
	return #self.Stack 
end

function CardStack:IsEmpty() 
	return #self.Stack == 0 
end

function CardStack:GetTop() 
	return self.Stack[#self.Stack]
end

function CardStack:IsInTheStack(UIControl) 
	return table.find(self.Stack, UIControl) ~= nil 
end

function CardStack:RemoveInPlace(UIControl)
	if not self:IsInTheStack(UIControl) then return end 
	if self.Animating then return end 
	self:Validate(UIControl)
	return self:Animate(function() 
		local TopUIControl = self:GetTop()  
		if UIControl == TopUIControl then 
			self:Remove(true)
		else 
			-- Find the index and remove it; table.remove expects an integer index.
			local index = table.find(self.Stack, UIControl)
			if index then
				table.remove(self.Stack, index)
			end
			self.StackRemoving:Fire(UIControl)
			self.StackRemoved:Fire(UIControl)
		end
	end) 
end

function CardStack:Add(UIControl, BreakAnimation) -- Add something onto the top of the deck
	if not BreakAnimation and self.Animating then return end 
	self:Validate(UIControl)
	return self:Animate(function() -- This is an explination of the operations 
		if #self.Stack > 0 then -- If there is something in the deck 
			local TopUIControl = self:GetTop() 
			TopUIControl:Deactivate()   -- remove it from the top 
		end
		self.StackAdding:Fire(UIControl)
		UIControl:Activate() -- make this card appear
		table.insert(self.Stack, UIControl)
		self.StackAdded:Fire(UIControl) 
	end, BreakAnimation)
end


function CardStack:Remove(BreakAnimation) -- remove something from the top of the deck 
	if not BreakAnimation and self.Animating then return end 
	return self:Animate(function() -- This is an explination of the operations 
		if #self.Stack > 0 then -- If there is something in the deck 
			local TopUIControl = self:GetTop() 
			
			self.StackRemoving:Fire(TopUIControl)
			TopUIControl:Deactivate()   -- remove it from the top 
			table.remove(self.Stack, #self.Stack)
			self.StackRemoved:Fire(TopUIControl)

			if #self.Stack > 0 then -- If there is still something in the deck 
				local TopUIControl = self:GetTop()  -- Get the top one and... 
				TopUIControl:Activate() -- Make it appear (this will contuine to happen until the deck is empty )
			end
		end  
	end, BreakAnimation)
end

function CardStack:Switch(UIControl) -- switch out the top card on the deck 
	if self.Animating then return warn("Attempt to do operation while animating") end 
	self:Validate(UIControl)
	return self:Animate(function() -- This is an explination of the operations 
		if #self.Stack <= 1 then 
			local WasPrevious = #self.Stack > 0 
			
			self:Remove(true) 
			self:Add(UIControl, true)
			return 
		end
		
		warn("There are too many items within the stack to SwitchLast.", self.Stack)
	end)
end

return CardStack
