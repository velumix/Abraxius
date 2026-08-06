local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

type ModelTween = {
	Play  : () -> (),
	Stop  : () -> (),
	Finished : RBXScriptSignal,
	Tick : RBXScriptSignal,
	Iterations : number, 
	ShouldReverse : boolean,
}

local ModelTween = {}

TweenInfo.new(1,1,1,1,true,-1)

-- Methods
function ModelTween.new(Model : Model,TweenInfo : TweenInfo,EndCFrame : CFrame, DontDestroyOnFinish) : ModelTween
	local StartPosition = Model:GetPivot()
	local Duration = TweenInfo.Time
	local DurationElapsed = 0

	local FinishedEvent = Instance.new("BindableEvent")
	local TickEvent = Instance.new("BindableEvent")

	local AnimationConnection : RBXScriptSignal
	local Tween : Tween
	local CFrameValue : CFrameValue
	local StartTime = 0

	local ModelTween : ModelTween = {
		Iterations = 0,
		ShouldReverse = false, 
		Finished = FinishedEvent.Event,
		Tick = TickEvent.Event,
		DestroyUponFinished = true, 
		Playing = false 
	}

	if DontDestroyOnFinish then 
		ModelTween.DestroyUponFinished = false 
	end

	ModelTween.Destroy = function() 
		ModelTween = nil 
		AnimationConnection:Disconnect()
		FinishedEvent:Destroy()
		TickEvent:Destroy()
	end

	ModelTween.Play = function()
		DurationElapsed = 0
		ModelTween.Iterations = 0 
		StartPosition = Model:GetPivot()
		StartTime = tick()
		if AnimationConnection then AnimationConnection:Disconnect(); AnimationConnection = nil end
		if Tween then Tween:Cancel(); Tween = nil end
		if CFrameValue then CFrameValue:Destroy(); CFrameValue = nil end

		CFrameValue = Instance.new("CFrameValue")
		CFrameValue.Value = StartPosition
		AnimationConnection = CFrameValue.Changed:Connect(function()
			local now = tick()
			local elapsed = now - StartTime
			local cycleDuration = Duration * (TweenInfo.Reverses and 2 or 1)
			if cycleDuration <= 0 then
				return
			end
			local cycleTime = elapsed % cycleDuration
			local delta
			if TweenInfo.Reverses and cycleTime > Duration then
				delta = 1 - ((cycleTime - Duration) / Duration)
			else
				delta = cycleTime / Duration
			end
			local val = TweenService:GetValue(delta, TweenInfo.EasingStyle, TweenInfo.EasingDirection)
			TickEvent:Fire(delta, val)
			Model:PivotTo(StartPosition:Lerp(EndCFrame, val))
		end)

		Tween = TweenService:Create(CFrameValue, TweenInfo, {Value = EndCFrame})
		Tween.Completed:Connect(function()
			FinishedEvent:Fire()
			if ModelTween.DestroyUponFinished then
				ModelTween.Destroy()
			end
		end)
		Tween:Play()
	end 

	ModelTween.Skip = function() 
		FinishedEvent:Fire()
		if ModelTween then ModelTween.Stop() end
		task.wait(); task.wait() 
	end

	ModelTween.Stop = function() 
		if AnimationConnection then AnimationConnection:Disconnect() end
		AnimationConnection = nil
		if Tween then Tween:Cancel(); Tween = nil end
		if CFrameValue then CFrameValue:Destroy(); CFrameValue = nil end
		if not ModelTween then return end 
		if ModelTween.DestroyUponFinished then 
			ModelTween.Destroy()
		end 
	end


	return  ModelTween 
end

return ModelTween