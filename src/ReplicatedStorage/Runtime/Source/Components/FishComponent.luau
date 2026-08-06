local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules
local Mince = require(Modules.Mince)

local Encyclopedia = ReplicatedStorage.Assets.Encyclopedia

local FishAgent = Mince.Agent(Modules.FishBrain)

local FishEncyclopedia = {}
local Vertebrates = require(Encyclopedia.Vertebrates)
local Invertebrates = require(Encyclopedia.Invertebrates)

for _, Vertebrate in Vertebrates do
	FishEncyclopedia[Vertebrate._id] = Vertebrate
end

for _, Invertebrate in Invertebrates do
	FishEncyclopedia[Invertebrate._id] = Invertebrate
end

local BuildFish = function(self)
	local attributes = {}
	local fishData = nil

	for property, value in self.Instance:GetAttributes() do
		if property == "_fishId" then
			fishData = FishEncyclopedia[value]
		else
			attributes[property] = value
		end
	end

	if not fishData then
		warn("Fish data not found", self.Instance)
		return
	end

	local InstanceId = self.Instance.Name .. " " .. tick()

	self.FishBrain = FishAgent.New()
	self.FishBrain:AssignInstance("Parent", self.Instance)
	self.FishBrain:AssignInstance("Region", self.Instance)
	self.FishBrain:AssignInstance("Node", self.Instance)
	self.FishBrain:AssignInstance("FishModel", fishData.Model)

	self.FishBrain:SetData({
		Parent = self.Instance,
		FishModel = fishData.Model,
		Region = self.Instance,
		Id = self.Instance:GetAttribute("_fishId"),
		SchoolSize = attributes.SchoolSize,
		SwimmingSpeed = {
			Min = attributes.MinSpeed or 1,
			Max = attributes.MaxSpeed or 2,
		},
		AnimationSpeed = {
			Min = attributes.Min_AnimationSpeed or 0.5,
			Max = attributes.Max_AnimationSpeed or 2,
		},
		MinimumCrowdDistance = attributes.CrowdingDist or 2,
		AlignWeight = attributes.Align or 0.3,
		SeperateWeight = attributes.Seperate or 0.4,
	})

	self.Bones = {
		Base = self.Instance:FindFirstChild("Base", true),
		Tail = self.Instance:FindFirstChild("Tail1", true),
	}

	self.Instance.CanCollide = false
	self.Instance.CanQuery = false

	self.Instance.Transparency = 1
	self.FishData = fishData
	self.Properties = attributes

	self.FishBrain:Start(self.Instance)

	self.Started = true

	workspace:SetAttribute("FishSimulation", true)
end

local FishComponent = Mince.Component({
	Tag = "Boid",
	Running = false,
	Properties = {},

	Construct = function(self)
		task.defer(BuildFish, self)
	end,

	StartSimulation = function(self)
		if self.Started and not self.Running then
			self.Running = true
			self.FishBrain:Resume()
		end
	end,

	StopSimulation = function(self)
		if self.Running then
			self.Running = false
			self.FishBrain:Stop()
		end
	end,

	Destroy = function(self)
		if self.FishBrain then
			self.FishBrain:Destroy()
			if self.FishBrain._Cleanup then
				self.FishBrain:_Cleanup()
			end
			self.FishBrain = nil
		end
	end,
})

return FishComponent
