local ParticleSource = {} 

function ParticleSource.Create(Particle : ParticleEmitter,Position,Size,EmitCount) 
	local Duration = Particle.Lifetime.Max + 0.5
	local Particle = Particle:Clone() 
	local SourcePart = Instance.new("Part")
	SourcePart.Name = "ParticleSource"
	SourcePart.Transparency = 1 
	SourcePart.Position = Position
	SourcePart.Anchored = true 
	SourcePart.CanCollide = false 
	SourcePart.Size = Size	
	SourcePart.Position = Position

	Particle.Enabled = false 

	Particle.Parent = SourcePart
	SourcePart.Parent = workspace

	Particle:Emit(EmitCount) 

	game:GetService("Debris"):AddItem(SourcePart,Duration)
end

function ParticleSource.Emit(Part, ManualRate, PlaySounds)
	for _,Child : ParticleEmitter in Part:GetDescendants() do  
		if PlaySounds and Child:IsA("Sound") then 
			Child:Play() 
		end
		if Child:IsA("ParticleEmitter") then 
			if Child:GetAttribute("Time") then 
				Child.Enabled =true 
				task.delay(Child:GetAttribute("Time"),function() 
					Child.Enabled = false
				end)
			else 
				Child:Emit(Child:GetAttribute("EmitCount") or ManualRate or Child.Rate or 1)
			end
		end
	end
end

function ParticleSource.CreateGroup(Attachment : Attachment,AttachPart : BasePart, EmitCount)  : Attachment
	local Duration = 0
	local Source = Attachment:Clone() 

	for _,ParticleEmitter : ParticleEmitter in Source:GetDescendants() do 
		if ParticleEmitter:IsA("ParticleEmitter") then 
			ParticleEmitter.Enabled = false

			Duration = math.max(Duration,ParticleEmitter.Lifetime.Max + 0.5)
		end
	end

	if typeof(AttachPart) == "Vector3" then 
		local SourcePart = Instance.new("Part")
		SourcePart.Name = "ParticleSource"
		SourcePart.Transparency = 1 
		SourcePart.Anchored = true 
		SourcePart.CanCollide = false 
		SourcePart.Size = Vector3.one * 0.2	
		SourcePart.Position = AttachPart
		SourcePart.Parent = game.Workspace

		game:GetService("Debris"):AddItem(SourcePart,Duration)

		AttachPart = SourcePart
	end

	Source.Parent = AttachPart 

	for _,ParticleEmitter : ParticleEmitter in Source:GetDescendants() do 
		if ParticleEmitter:IsA("ParticleEmitter") then
			local ParticleTime =  ParticleEmitter:GetAttribute("Time")
			if ParticleTime then 
				ParticleEmitter.Enabled =true 
				task.delay(ParticleTime,function() 
					ParticleEmitter.Enabled = false 
				end)
			else 
				ParticleEmitter:Emit(EmitCount or ParticleEmitter.Rate)
			end
		end

		if ParticleEmitter:IsA("Sound") then 
			ParticleEmitter:Play() 
		end
	end

	game:GetService("Debris"):AddItem(Source,Duration)

	return Source
end



return ParticleSource 