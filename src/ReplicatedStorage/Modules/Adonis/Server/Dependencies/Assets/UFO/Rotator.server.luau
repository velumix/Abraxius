local tweenService = game:GetService("TweenService")
local ufo = script.Parent
local parts = ufo:GetChildren()
local info = TweenInfo.new(30, Enum.EasingStyle.Linear,  Enum.EasingDirection.Out, -1, true, 0)

for i,v in next,parts do
	if v:IsA("BasePart") and v.Name ~= "Light" and v.Name ~= "Primary" then
		tweenService:Create(v, info, {
				Orientation = Vector3.new(0, 180*(math.random(-1, 1)), 90)
		}):Play()
	end
end