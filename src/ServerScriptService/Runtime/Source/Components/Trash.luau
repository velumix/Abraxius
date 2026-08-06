local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage.Modules
local Mince = require(Modules.Mince)

local TrashEvent = Mince:GetEvent("TrashEvent")
local TrashCollected = TrashEvent:Extend("Collected")

local Trash = Mince.Component {
	Tag = "Trash",
}

function Trash:Construct()
	self.CurrencyService = Mince:Get("CurrencyService")
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = "Debris"
	prompt.ActionText = "Clean Up"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 15
	prompt.Parent = self.Instance

	self.Prompt = prompt

	self.Prompt.Triggered:Connect(function(player)
		self:OnCleaned(player)
	end)
end

function Trash:OnCleaned(player)
	local trashName = self.Instance.Name
	local success = self.CurrencyService:CollectTrash(player, trashName)

	if success then
		local trashPosition = nil
		local ok, pivot = pcall(self.Instance.GetPivot, self.Instance)
		if ok and pivot then
			trashPosition = pivot.Position
		end
		TrashCollected:Fire(player, trashPosition, 1)

		-- would Play sound
		self.Instance:Destroy()
	end
end

function Trash:Destroy()
	if self.Prompt then
		self.Prompt:Destroy()
	end
end

return Trash
