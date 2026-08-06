local TweenService = game:GetService("TweenService")
local img = script.Parent

local basePos = img.Position
local amplitude = 0.045 -- vertical bob amount (Scale)
local speed = 1       -- lower = slower, higher = faster

local tweenInfo = TweenInfo.new(
	speed / 2,
	Enum.EasingStyle.Sine,
	Enum.EasingDirection.InOut,
	-1,   -- infinite
	true  
)

TweenService:Create(
	img,
	tweenInfo,
	{
		Position = UDim2.new(
			basePos.X.Scale,
			basePos.X.Offset,
			basePos.Y.Scale + amplitude,
			basePos.Y.Offset
		)
	}
):Play()
