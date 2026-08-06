local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Mince = require(ReplicatedStorage.Modules.Mince)

local Creatures = Mince.Component({
	Tag = "ServerCreatures",
})

function Creatures:Construct()
	self.Model = self.Instance

	-- Temporary phenomenon creatures manage their own finite server animation
	-- and despawn when it finishes. Do not let the permanent-creature
	-- optimization stop that track after the model is cloned into the world.
	local eventFolder = Workspace:FindFirstChild("GlobalEventCreatures")
	if eventFolder and self.Model:IsDescendantOf(eventFolder) then
		return
	end

	-- Some legacy exhibit rigs contain their own server Script which starts the
	-- same animation before this component is constructed. Disable those scripts
	-- and stop any track they already created.
	for _, descendant in self.Model:GetDescendants() do
		if descendant:IsA("Script") then
			descendant.Enabled = false
		elseif descendant:IsA("Animator") then
			for _, track in descendant:GetPlayingAnimationTracks() do
				track:Stop(0)
				track:Destroy()
			end
		end
	end

	-- The server deliberately does not load or play this rig's animation.
	-- CreatureAnimationService supplies a shared epoch through ByteNet and each
	-- client evaluates the animation locally, avoiding replicated joint poses.
end

return Creatures
