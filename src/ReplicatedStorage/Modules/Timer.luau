-- Services 
local TweenService = game:GetService("TweenService")

type Timer = {
	Start : (self : Timer, Duration : number) -> (), 
	Tween : (self : Timer, TweenInfo : TweenInfo) -> (), 
	EasingStyle : Enum.EasingStyle, 
	EasingDirection : Enum.EasingDirection,
	Completed : RBXScriptSignal, 
	Tick : RBXScriptSignal, 
	Progress : number,  
	TimeValue : number,  
	Loop : bool, 
	Reverses : bool,
	Enabled : bool,
	DestroyOnFinish : bool,
}

local Signal = require(script.Parent.Signal)
local Timer = {}
Timer.__index = Timer

Timer.Throw = function(str)
	warn("[Timer]:"..str)
end

function Timer.fromTweenInfo(TweenInfo : TweenInfo) 
	local NewTimer = Timer.new(TweenInfo.Time) 
	NewTimer.Loop = (TweenInfo.RepeatCount < 0)
	NewTimer.Reverses = TweenInfo.Reverses 
	NewTimer.EasingStyle = TweenInfo.EasingStyle
	NewTimer.EasingDirection = TweenInfo.EasingDirection 
	return NewTimer 
end

function Timer.new(Duration : number)
	local self : Timer = setmetatable({
		Duration = Duration or 1,
		Enabled = true,
		Loop = false,
		Reverses = false, 
		Time = 0,
		Progress = 0, 
		DestroyOnFinish = false,
		-----------------------------
		__IsForward = true,
		__TimeElapsed = 0, 
		__Running = false,
	}, Timer)
	self.Completed = Signal.new() 
	self.Tick = Signal.new()
	return self
end

function Timer.delay(Duration : number,callback)
	assert(typeof(callback) == "function","Timer.defer([2]) must be a function.")
	local DeferTimer = Timer.new(Duration) 
	DeferTimer:Start() 
	DeferTimer.Completed:Connect(function() 
		callback() 
		DeferTimer:Destroy() 
	end)
	return DeferTimer
end

function Timer.interval(Duration,callback)
	assert(typeof(callback) == "function","Timer.interval([2]) must be a function.")
	local IntervalTimer = Timer.new(Duration) 
	IntervalTimer:Start() 
	IntervalTimer.Loop = true 
	IntervalTimer.Completed:Connect(function() 
		callback() 
	end)
	return IntervalTimer
end


function Timer:Tween(TweenInfo : TweenInfo) 
	self.Duration = TweenInfo.Time 
	self.Loop = (TweenInfo.RepeatCount < 0)
	self.Reverses = TweenInfo.Reverses 
	self.EasingStyle = TweenInfo.EasingStyle
	self.EasingDirection = TweenInfo.EasingDirection 
	self:Reset() 
end

function Timer:Start(Duration)
	if not self.__Running and self.Enabled then
		if self.Thread and coroutine.status(self.Thread) == "running" then task.wait() end 
		self.Duration = Duration or self.Duration 
		self.Thread = task.spawn(function()
			self.__Running = true
			if self.__IsForward then 
				repeat 
					if not self.__Running then break end 
					if self.Enabled then
						local ActualTime = self.__TimeElapsed/self.Duration 
						self.Progress = ActualTime 
						if self.EasingStyle and self.EasingDirection then 
							ActualTime = TweenService:GetValue(ActualTime,self.EasingStyle,self.EasingDirection)
						end
						self.TimeValue = ActualTime
						self.Tick:Fire(ActualTime,self.__TimeElapsed)
						self.__TimeElapsed += task.wait()		
					end
				until self.__TimeElapsed > self.Duration				
			else 
				repeat 
					if not self.__Running then break end 
					if self.Enabled then
						local ActualTime = self.__TimeElapsed/self.Duration 
						self.Progress = ActualTime 
						if self.EasingStyle and self.EasingDirection then 
							ActualTime = TweenService:GetValue(ActualTime,self.EasingStyle,self.EasingDirection)
						end
						self.TimeValue = ActualTime
						self.Tick:Fire(ActualTime,self.__TimeElapsed)
						self.__TimeElapsed -= task.wait()		
					end
				until self.__TimeElapsed < 0
			end
			
			if self.__Running then return end 
			
			self.Tick:Fire(1)-- Complettion
			self.Completed:Fire()
			if self.DestroyOnFinish then 
				task.wait()
				self:Destroy() 
				return 
			end
			if self.Reverses then 
				self.__IsForward = not self.__IsForward
			end
			-- Only if going forward will the tick reset 
			if self.__IsForward then 
				self.__TimeElapsed = 0	
			else 
				self.__TimeElapsed = math.min(self.__TimeElapsed,self.Duration)
			end
			if self.Loop then 
				self.__Running = false 
				self:Start()
			else 
				self.__Running = false 
			end
		end)
	end 
end

function Timer:Reset()
	self.__Running = false
	self.__TimeElapsed = 0 
	self:Start(self.Duration)
end

function Timer:Pause() 
	self.Enabled = false 
end

function Timer:Resume() 
	self.Enabled = true 
end

function Timer:Stop()
	self.__Running = false 
	if self.Thread then 
		coroutine.close(self.Thread)	
	end
end

function Timer:Destroy() 
	self:Stop()
	self.__CompletedEvent:Destroy()
	self.__Tick:Destroy()
	self = nil 
end

return Timer