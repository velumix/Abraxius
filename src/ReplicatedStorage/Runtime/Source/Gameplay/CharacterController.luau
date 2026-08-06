local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Modules = ReplicatedStorage.Modules

local Mince = require(Modules.Mince)

local Player = Players.LocalPlayer

local PlayerModule = Player.PlayerScripts:WaitForChild("PlayerModule")
local ControlModule = require(PlayerModule.ControlModule)
local PlayerModule = require(PlayerModule)

local CharacterController =  {
	Name = "CharacterController";
	IsEnabled = true;

	Signals = {
		Added = Instance.new("BindableEvent");
		Removed = Instance.new("BindableEvent");
		Died = Instance.new("BindableEvent");
	};

	Walkspeeds = {
		Default = 16;
		Sprint = 22;
	};

	Binds = {
		Sprint = Enum.KeyCode.LeftShift;
	};

	Cooldowns = {
		Jump = {
			Duration = .75;
			Last = 0;
		};
	};

	Animations = {
		SwimmingIdle = "rbxassetid://128025332439232";
		Swimming = "rbxassetid://73094995970172";
		SwimmingLeft = "rbxassetid://134953822416907";
		SwimmingRight = "rbxassetid://131382627855940";
		SwimUp = "rbxassetid://94479495979829";
		SwimDown = "rbxassetid://117014059352398";
	};

	LoadedAnimation = {};
	Connections = {};
}

function CharacterController:SetEnabled(Bool)
	if not CharacterController.Controls then return end
	if CharacterController.IsEnabled == Bool then return end
	CharacterController.IsEnabled = Bool
	if Bool then
		CharacterController.Controls:Enable()
	else 
		CharacterController.Controls:Disable()
	end
end

function CharacterController:ForceUnseat()
	local player = Players.LocalPlayer
	if player.Character and player.Character:FindFirstChild("Humanoid") then
		local humanoid = player.Character.Humanoid
		if humanoid.Sit then
			humanoid.Sit = false
			humanoid.Jump = true
		end
	end
end

function CharacterController:Setup()
	local Controls = PlayerModule:GetControls()
	CharacterController.Controls = Controls
	CharacterController:SetEnabled(true)
end

function CharacterController:Start()

	local function ClearConnections()
		for _, Connection in self.Connections do
			Connection:Disconnect()
		end
		self.Connections = {}
	end

	local function OnCharacterAdded(Character : Model)
		self.Character = Character
		self.Humanoid = Character:WaitForChild("Humanoid")
		self.Rootpart = Character:WaitForChild("HumanoidRootPart")
		self.AlignPosition = Instance.new("AlignPosition", self.Rootpart)
		self.AlignOrientation = Instance.new("AlignOrientation", self.Rootpart)

		self.HumanoidAnimations = function()
			return self.Humanoid:GetPlayingAnimationTracks()
		end

		for Name, AnimationId in pairs(self.Animations) do
			local Animation = Instance.new("Animation")
			Animation.AnimationId = AnimationId
			self.LoadedAnimation[Name] = self.Humanoid:LoadAnimation(Animation)
			self.LoadedAnimation[Name].Priority = Enum.AnimationPriority.Core
		end

		self.Connections["HumanoidDied"] = self.Humanoid.Died:Connect(function()
			self.Signals.Died:Fire(self.Humanoid :: Humanoid)
		end)

		self.Connections["Removing"] = Character.AncestryChanged:Connect(function()
			if not Character.Parent then
				self.Signals.Removed:Fire(Character :: Model)
				ClearConnections()
			end
		end)

		self.Connections["InputBegan"] = UserInputService.InputBegan:Connect(function(Input, Processed)
			if Processed then return end

			if Input.KeyCode == Enum.KeyCode.Space and self.Humanoid.Sit then
				self:ForceUnseat()
				return
			end

			if Input.KeyCode == self.Binds.Sprint then
				local MoveVector = self.Humanoid.MoveDirection
				if MoveVector.Magnitude > 0 then
					self.Humanoid.WalkSpeed = self.Walkspeeds.Sprint
				end
			end
		end)

		self.Connections["InputEnded"] = UserInputService.InputEnded:Connect(function(Input, Processed)
			if Processed then return end
			if Input.KeyCode == self.Binds.Sprint then
				self.Humanoid.WalkSpeed = self.Walkspeeds.Default
			end
		end)

		self.Signals.Added:Fire(Character :: Model)
	end

	if Player.Character then
		OnCharacterAdded(Player.Character)
	end

	self.PlayerAddedConnection = Player.CharacterAdded:Connect(OnCharacterAdded)

end

CharacterController:Start()

function CharacterController:StopAll()
	for _, Connection in self.Connections do
		Connection:Disconnect()
	end
	self.PlayerAddedConnection:Disconnect()
end

return CharacterController