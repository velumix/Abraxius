local animation = script.Animation
local animationController = script.Parent.AnimationController
local animationTrack = animationController:LoadAnimation(animation)

animationTrack:Play()