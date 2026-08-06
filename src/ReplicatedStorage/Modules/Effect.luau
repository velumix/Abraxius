local TweenService = game:GetService("TweenService") 

-- All this does is auto-manage deletion and allow for effects to be looped/played multiple times.

local Effect = {} 
Effect.__index = Effect 

function Effect.new(ActualEffect : Attachment | BasePart, AttachTo : BasePart | Vector3 | CFrame) 	
	local NewEffect = setmetatable(ActualEffect:GetAttributes(), Effect)  
	NewEffect:SourceAttachment(AttachTo) -- Creates .Attach and .DestroyableAttach, where the particles will GOTO 
	NewEffect:CreateEffect(ActualEffect) -- Dumps all attributes of each particle! and parents to attach!
	return NewEffect -- Check :Play() 
end

function Effect:Destroy() 
	if self.ThisEffect then 
		self.ThisEffect.Source:Destroy() 
		self.ThisEffect = nil 	
	end

	if self.DestroyableAttach then 
		self.DestroyableAttach:Destroy() -- was created for the effect! now destroy it! 
	end

	self = nil 
end

function Effect:Active()
	if not self.ThisEffect  then 
		return false 
	end 

	local IsPlaying = false 
	for _, Bool in self.ThisEffect.EffectEnabledStack do 
		if Bool then IsPlaying = true ; break end 
	end

	return IsPlaying
end


function Effect:EndingCheck() 
	if not self.ThisEffect  then return end  

	for _, Bool in self.ThisEffect.EffectEnabledStack do 
		if not Bool then return end 
	end

	self.ThisEffect.Source:Destroy() 
	self.ThisEffect = nil 

	if not self.DestroyAfter then return end 

	self:Destroy() 
end

function Effect:StartInstance(EffectInstance : Instance, Attributes)
	if EffectInstance:IsA("ParticleEmitter") or EffectInstance:IsA("Light") or EffectInstance:IsA("Beam") then 
		EffectInstance.Enabled = true


		if EffectInstance:IsA("Light") and not Attributes.IgnoreTween then 
			Attributes["Tween"] = Attributes.Tween or TweenInfo.new((Attributes.EmitDuration or 0) * 1/8, Enum.EasingStyle.Sine) 

			EffectInstance.Brightness = 0 
			TweenService:Create(EffectInstance, Attributes.Tween, { Brightness = 1 }):Play()
		elseif EffectInstance:IsA("Beam") and not Attributes.IgnoreTween then  
			-- Simply done for laziness use TweenService:GetValue() and seperate thread? 
			Attributes["Tween"] = Attributes.Tween or TweenInfo.new((Attributes.EmitDuration or 0) * 1/8, Enum.EasingStyle.Sine) 
			Attributes["Value"] = Attributes.Value or Instance.new("NumberValue", EffectInstance) 

			--EffectInstance.Transparency = NumberSequence.new(Attributes.Value.Value)
			Attributes.Value:GetPropertyChangedSignal("Value"):Connect(function() 
				--EffectInstance.Transparency = NumberSequence.new(Attributes.Value.Value)
			end)

			--Attributes.Value.Value = 0 
			TweenService:Create(Attributes.Value, Attributes.Tween, { Value = 1 }):Play()
		end
	elseif EffectInstance:IsA("Sound") then 
		EffectInstance.Playing = true 
		EffectInstance.PlaybackSpeed = 0.8 + (0.4 * math.random())
	end

	self.ThisEffect.EffectEnabledStack[EffectInstance] = false 
	self:EndingCheck() 
end

function Effect:EndInstance(EffectInstance : Instance, Attributes) 
	if EffectInstance:IsA("ParticleEmitter") or EffectInstance:IsA("Light") or EffectInstance:IsA("Beam") then 
		EffectInstance.Enabled = false 

		if EffectInstance:IsA("Light") and not Attributes.IgnoreTween then 
			EffectInstance.Brightness = 1 
			TweenService:Create(EffectInstance, Attributes.Tween, { Brightness = 0 }):Play()
		elseif EffectInstance:IsA("Beam") and not Attributes.IgnoreTween then  
			Attributes.Value.Value = 1
			TweenService:Create(Attributes.Value, Attributes.Tween, { Value = 0 }):Play()
		end
	elseif EffectInstance:IsA("Sound") then 
		EffectInstance.Playing = false 
	end

	self.ThisEffect.EffectEnabledStack[EffectInstance] = true 
	self:EndingCheck()
end


function Effect:PlayThenDestroy(...) 
	self.DestroyAfter = true 
	self:Play(...) 
end

function Effect:Play(...) 
	if not self.ThisEffect  then 
		error("No Effect to play!")
	elseif self:Active() then 
		warn(`Cannot play effect whilst playing`)
		return 
	end
	
	for _, EffectDesc : Instance in self.ThisEffect.Source:GetDescendants() do 
		if EffectDesc:IsA("Attachment") or EffectDesc:IsA("BasePart") then continue end 
		local Attributes = EffectDesc:GetAttributes()
		if Attributes.EmitDuration and not Attributes.EmitCount then -- Allows you to do NON-Particles like beams and lights
			local SpecifyAmount = ...
			task.delay(Attributes.EmitDelay or 0, function() 
				local ThisEmitCount = Attributes.EmitCount or SpecifyAmount or 0 
				if ThisEmitCount > 0 and EffectDesc:IsA("ParticleEmitter") then 
					EffectDesc:Emit(ThisEmitCount)
				end
				
				self:StartInstance(EffectDesc, Attributes)
				task.wait(Attributes.EmitDuration or 0); task.wait()  
				self:EndInstance(EffectDesc, Attributes)
			end)	
		elseif EffectDesc:IsA("ParticleEmitter") then  
			local SpecifyAmount = ...
			task.delay(Attributes.EmitDelay or 0, function() 
				EffectDesc:Emit(Attributes.EmitCount or SpecifyAmount or 5)

				task.delay(EffectDesc.Lifetime.Max, function() 
					if not self.ThisEffect then return end 
					self.ThisEffect.EffectEnabledStack[EffectDesc] = true 
					self:EndingCheck()
				end)
			end)
		elseif EffectDesc:IsA("Sound") then  
			task.delay(Attributes.EmitDelay or 0, function() 
				EffectDesc:Play() 

				task.delay(EffectDesc.TimeLength, function() 
					EffectDesc:Stop()
					self.ThisEffect.EffectEnabledStack[EffectDesc] = true 
					self:EndingCheck()
				end)	
			end) 
		end
	end

	self:EndingCheck() -- So if empty
end

function Effect:CreateEffect(AEffect : Attachment) 
	if not self.Attach then 
		error("There is no attachment!")
	end

	assert(typeof(AEffect) == "Instance" and AEffect:IsA("Attachment") or AEffect:IsA("BasePart"), "Effect couild not be loaded!")

	local Source, Stack = AEffect:Clone(), {}  
	local Attachments = {Source} 

	for _, EffectDesc in Source:GetDescendants() do 
		if EffectDesc:GetAttribute("__Effect") then 
			EffectDesc:Destroy()
			continue
		end
		if EffectDesc.Parent and EffectDesc.Parent:GetAttribute("__Effect") then continue end 

		if EffectDesc:IsA("Attachment") then 
			EffectDesc:SetAttribute("__Effect", true)
		end

		if EffectDesc:IsA("ParticleEmitter") or EffectDesc:IsA("Light") or EffectDesc:IsA("Beam") then 
			EffectDesc.Enabled = false

			Stack[EffectDesc] = false 
		elseif EffectDesc:IsA("Sound") then
			EffectDesc.Playing = false 

			Stack[EffectDesc] = false 
		end 
	end 


	Source.Parent = self.Attach

	if Source:IsA("BasePart") then 
		if Source.Anchored then 
			Source.Position = self.Attach.Position
		else
			local ConnectionWeld : Weld = Instance.new("Weld") 
			ConnectionWeld.Name = "ConnectionWeld"
			ConnectionWeld.Part0 = Source 
			ConnectionWeld.Part1 = self.Attach 
			ConnectionWeld.Parent = Source
		end
	end

	self.ThisEffect = {
		EffectEnabledStack = Stack, 
		Source = Source
	} 
end

function Effect:SourceAttachment(Attach : BasePart | Vector3 | CFrame) 
	if typeof(Attach) == "CFrame" then 
		local SourcePart = Instance.new("Part")
		SourcePart.Name = "ParticleSource"
		SourcePart.Transparency = 1 
		SourcePart.Anchored = true 
		SourcePart.CanCollide = false 
		SourcePart.CanQuery = false 
		SourcePart.CanTouch = false 
		SourcePart.Size = Vector3.one * 0.2	
		SourcePart.CFrame = Attach
		SourcePart.Parent = game.Workspace 

		self.DestroyableAttach = SourcePart
		self.Attach = SourcePart
	elseif typeof(Attach) == "Vector3" then 
		local SourcePart = Instance.new("Part")
		SourcePart.Name = "ParticleSource"
		SourcePart.Transparency = 1 
		SourcePart.Anchored = true 
		SourcePart.CanCollide = false 
		SourcePart.CanQuery = false 
		SourcePart.CanTouch = false 
		SourcePart.Size = Vector3.one * 0.2	
		SourcePart.Position = Attach
		SourcePart.Parent = game.Workspace 

		self.DestroyableAttach = SourcePart
		self.Attach = SourcePart
	elseif typeof(Attach) == "Instance" and Attach:IsA("Attachment") or Attach:IsA("BasePart") then 
		self.Attach = Attach
	end
end


return Effect