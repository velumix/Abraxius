local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

return function(context)
	local player = context.Executor
	if not player then
		return "No player."
	end

	local character = player.Character
	if not character then
		return "Character not loaded."
	end

	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return "Missing HumanoidRootPart."
	end

	local ok, err = pcall(function()
		local ragdollService = Knit.GetService("RagdollService")
		if not ragdollService then
			error("RagdollService is not registered with Knit.")
		end

		ragdollService:ActivateRagdoll(character)

		-- Hurl the character. We set velocity directly on the HRP assembly so the whole body flies,
		-- and re-apply it for a few frames in case the humanoid state tries to zero it.
		task.defer(function()
			local look = root.CFrame.LookVector
			local flatLook = Vector3.new(look.X, 0, look.Z).Unit
			if flatLook.Magnitude < 0.001 then
				flatLook = Vector3.new(0, 0, 1)
			end

			local fling = (flatLook * 180) + Vector3.new(0, 130, 0) + (root.CFrame.RightVector * math.random(-80, 80))
			local angular = Vector3.new(math.random(-15, 15), math.random(-15, 15), math.random(-15, 15))

			for _ = 1, 6 do
				if not character or not character.Parent then
					return
				end
				local currentRoot = character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if currentRoot then
					currentRoot.AssemblyLinearVelocity = fling
					currentRoot.AssemblyAngularVelocity = angular
				end
				task.wait()
			end
		end)

		-- Hold ragdoll for 4 seconds, then release.
		task.delay(4, function()
			if character and character.Parent then
				pcall(function()
					ragdollService:DeactivateRagdoll(character)
				end)
			end
		end)
	end)

	if not ok then
		return "Ragdoll test failed: " .. tostring(err)
	end

	return "Ragdolled and flung."
end
