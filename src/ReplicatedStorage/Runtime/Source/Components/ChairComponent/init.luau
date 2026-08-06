local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules

local Player = game.Players.LocalPlayer

local Mince = require(Modules.Mince)
local Animations = require(script.Animations)
local InteractIndicator = Mince:Get("InteractIndicator")

local ChairComponent = Mince.Component {
	Tag = "Chair",
}

function ChairComponent:Construct()
	self.Chair = self.Instance
	self.LoadedAnimations = {}

	if not self.Instance:IsA("Model") then
		return warn("Chair component must be attached to a model", self.Instance, self.Instance:GetFullName())
	end

	self.Seats = self.Chair:FindFirstChild("Seats")
	self.Indicators = {}

	if not self.Seats then
		return warn("Chair model must have a Seats folder", self.Instance)
	end

	self.AnimationName = self.Chair:GetAttribute("Animation")
	if self.AnimationName and not Animations[self.AnimationName] then
		self.AnimationName = nil
	end

	self.LoadAnimation = function(player)
		if not self.AnimationName or not player.Character or not player.Character:FindFirstChild("Humanoid") then
			return
		end

		local humanoid = player.Character.Humanoid
		local animator = humanoid:FindFirstChild("Animator")

		if not animator then
			return
		end

		local animationId = "rbxassetid://" .. Animations[self.AnimationName]
		local animation = Instance.new("Animation")
		animation.AnimationId = animationId

		local animationTrack = animator:LoadAnimation(animation)
		animationTrack.Looped = true
		animationTrack:Play()

		self.LoadedAnimations[player] = animationTrack
	end

	self.UnloadAnimation = function(player)
		local animationTrack = self.LoadedAnimations[player]
		if animationTrack then
			animationTrack:Stop()
			animationTrack:Destroy()
			self.LoadedAnimations[player] = nil
		end
	end

	self.ShowAll = function()
		for _, seat in self.Seats:GetChildren() do
			if not seat.Occupant then
				seat.ProximityPrompt.Enabled = true
			end
		end
	end

	self.HideAll = function()
		for _, seat in self.Seats:GetChildren() do
			seat.ProximityPrompt.Enabled = false
		end
	end

	self.Connections = {}

	for _, seat in self.Seats:GetChildren() do
		self.Connections[seat] = {}

		local indicator = InteractIndicator.new(seat)
		self.Indicators[seat] = indicator
		local Prompt = indicator.ProximityPrompt
		Prompt.ActionText = "Sit"
		Prompt.ObjectText = "Sit"
		Prompt.MaxActivationDistance = 7.5
		Prompt.RequiresLineOfSight = false

		self.Connections[seat]["Triggered"] = Prompt.Triggered:Connect(function(player)
			if not seat.Occupant then
				local isSwimming = Player:GetAttribute("Swimming")
				if not isSwimming then
					seat:Sit(player.Character.Humanoid)
				else
					print("Cannot sit while swimming!")
				end
			end
		end)

		self.Connections[seat]["Changed"] = seat:GetPropertyChangedSignal("Occupant"):Connect(function()
			if seat.Occupant then
				Prompt.Enabled = false
				local character = seat.Occupant.Parent
				local player = game.Players:GetPlayerFromCharacter(character)

				if player then
					self.LoadAnimation(player)
				end

				if seat.Occupant == Player.Character.Humanoid then
					self.HideAll()
				end
			else
				for player, animationTrack in pairs(self.LoadedAnimations) do
					if player.Character and not player.Character.Humanoid.Sit then
						self.UnloadAnimation(player)
					end
				end

				local playerSeated = false
				if Player.Character and Player.Character:FindFirstChild("Humanoid") then
					for _, checkSeat in self.Seats:GetChildren() do
						if checkSeat.Occupant == Player.Character.Humanoid then
							playerSeated = true
							break
						end
					end
				end

				if not playerSeated then
					self.ShowAll()
				else
					if not seat.Occupant then
						Prompt.Enabled = true
					end
				end
			end

		end)

	end


	self.ClearConnections = function()
		for player, animationTrack in pairs(self.LoadedAnimations) do
			self.UnloadAnimation(player)
		end

		for _, seat in self.Seats:GetChildren() do
			if self.Connections[seat] then
				if self.Connections[seat]["Triggered"] then
					self.Connections[seat]["Triggered"]:Disconnect()
				end
				if self.Connections[seat]["Changed"] then
					self.Connections[seat]["Changed"]:Disconnect()
				end
			end
			local indicator = self.Indicators and self.Indicators[seat]
			if indicator and indicator.Stop then
				indicator:Stop(true)
			end
		end
	end

end

function ChairComponent:Removing()
	self.ClearConnections()
end

return ChairComponent