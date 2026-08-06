local Ragdoll = {}
function Ragdoll:Ragdoll(Duration)
	if self:GetAttribute("Ragdolled") then return end 
	self:SetAttribute("Ragdolled", true) 
	
	for i,v in pairs(self:GetDescendants()) do
		if v:IsA("Motor6D")  then
			local Attachment1 = Instance.new("Attachment")
			Attachment1.Name = "RagdollAttach"
			local Attachment2 = Instance.new("Attachment")
			Attachment2.Name = "RagdollAttach"
			
			Attachment1.CFrame = v.C0
			Attachment2.CFrame = v.C1
			Attachment1.Parent = v.Part0
			Attachment2.Parent = v.Part1
			
			local Socket = Instance.new("BallSocketConstraint")
			Socket.Attachment0 = Attachment1
			Socket.Attachment1 = Attachment2
			Socket.LimitsEnabled = true
			Socket.TwistLimitsEnabled = true
			Socket.MaxFrictionTorque = 30
			Socket.Restitution = 0.5
			Socket.Radius = 0.25 
			
			--Socket.UpperAngle = 25			
			if v.Name == "Right Shoulder" or v.Name == "Left Shoulder" then
				--Socket.TwistUpperAngle = -30
			end
			Socket.Parent = v.Parent
			
			v.Enabled = false
		end
	end 
	
	local Humanoid : Humanoid = self:FindFirstChild("Humanoid") 
	if Humanoid then 
		Humanoid:UnequipTools() 
		Humanoid:SetAttribute("DefHipHeight", Humanoid.HipHeight)
		Humanoid.HipHeight = 0.1
		Humanoid:ChangeState(Enum.HumanoidStateType.Ragdoll)
		Humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
	end
end

function Ragdoll:UnRagdoll()
	if not self:GetAttribute("Ragdolled") then return end 
	self:SetAttribute("Ragdolled", nil) 
	for i,v in pairs(self:GetDescendants()) do
		if  v.Name == "RagdollAttach" or v:IsA("BallSocketConstraint") then
			v:Destroy()
		elseif v:IsA("Motor6D") then
			v.Enabled = true
		end
	end
	
	local Humanoid : Humanoid = self:FindFirstChild("Humanoid") 
	if Humanoid then 
		Humanoid.HipHeight = Humanoid:GetAttribute("DefHipHeight")
		Humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
	end
end
return Ragdoll
