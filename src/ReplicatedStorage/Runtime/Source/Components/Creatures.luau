local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules

local Mince = require(Modules.Mince)

local Creatures = Mince.Component {Tag = "Creatures"}

local function hasValidAnimationId(animation)
	if not animation or not animation:IsA("Animation") then
		return false
	end

	local animationId = animation.AnimationId
	return typeof(animationId) == "string"
		and animationId ~= ""
		and animationId ~= "0"
		and animationId ~= "rbxassetid://0"
		and not animationId:match("[?&]id=0$")
end

function Creatures:Construct()
	self.Model = self.Instance

	self.Animations = {}
	self.Connections = {}

	self.Animation = self.Model:FindFirstChild("Animation", true)
	if not self.Animation then
		return
	end

	if not hasValidAnimationId(self.Animation) then
		return
	end

	self.AnimationController = self.Model:FindFirstChild("AnimationController")

	if not self.AnimationController then
		warn("No AnimationController found for " .. self.Model.Name, "Creating one...")
		self.AnimationController = Instance.new("AnimationController", self.Model)
	end

	self.Animator = self.AnimationController:FindFirstChild("Animator")

	if not self.Animator then
		self.Animator = Instance.new("Animator", self.AnimationController)
	end

	local success, result = pcall(function()
		return self.Animator:LoadAnimation(self.Animation)
	end)

	if not success then
		warn("Failed to load animation for " .. self.Model.Name .. ": " .. tostring(result))
		return
	end

	self.Animations.Normal = result
	self.Animations.Normal:Play()

	self.Events = self.Instance:GetAttribute("Events")

	if self.Events then
		if self.Model.Name == "HarlequinSmiler" then
			self.SandSpits = {
				SandSpitA = self.Model:FindFirstChild("SandSpitA", true),
				SandSpitB = self.Model:FindFirstChild("SandSpitB", true),
			}
			
			for I, Emitter in self.SandSpits do
				self.Connections[I] = self.Animations.Normal:GetMarkerReachedSignal(I):Connect(function()
					Emitter:Emit(10)
					print(I)
				end)
			end
		end
	end

end

return Creatures

