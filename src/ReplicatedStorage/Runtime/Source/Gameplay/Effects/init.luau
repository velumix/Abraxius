local ReplicatedStorage = game:GetService('ReplicatedStorage')
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players") 
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local Mince = require(ReplicatedStorage.Modules.Mince) 
local Effect = require(ReplicatedStorage.Modules.Effect)
local ParticleSource = require(ReplicatedStorage.Modules.ParticleSource)
local OldParticleSource = require(script.OldParticleSource)

local SoundHandler = Mince:Get("SoundHandler")
local InterfaceHandler = Mince:Get("InterfaceHandler")
local Settings = Mince:Get("Settings")

--local SpawnGroup = Mince:GetEvent("SpawnGroup")
--local SpawnEffect = Mince:GetEvent("SpawnEffect") 
--local RequestReset = Mince:GetEvent("RequestReset")
--local PlayerEffect = Mince:GetEvent("PlayerEffects") 
local Effects = {
	Tweens = {
		HighlightTween = TweenInfo.new(0.3),  
		FadeTween = TweenInfo.new(0.3),
		FadeTween2 = TweenInfo.new(2), 
	},
	
	Fireworks = {}, 
	FireworkPosition = 1,  
	
	DisableCameraEffects = true, 
} 


function Effects.CameraEffectDisabled()  
	return Effects.DisableCameraEffects
end 

function Effects.SetCameraEffectsEnabled(Enabled) 
	Effects.DisableCameraEffects = not Enabled
end

function Effects.PlayBlackout(Time) 
	TweenService:Create(Effects.Blackout, Effects.Tweens.FadeTween, {
		GroupTransparency = 0
	}):Play()
	
	task.wait(Time) 
	
	TweenService:Create(Effects.Blackout, Effects.Tweens.FadeTween, {
		GroupTransparency = 1 
	}):Play()
end

function Effects.ImageEffect() 
	Effects.JumpScare.ImageTransparency = 0 
	Effects.JumpScare.UIScale.Scale = 1 
	TweenService:Create(Effects.JumpScare, Effects.Tweens.FadeTween2, {
		ImageTransparency = 1 
	}):Play() 
	TweenService:Create(Effects.JumpScare.UIScale, Effects.Tweens.FadeTween2, {
		Scale = 0.1 
	}):Play() 
end

function Effects.ScarySpider()
	local Vignette = LocalPlayer.PlayerGui.MainPriority:WaitForChild("JumpscareVignette")
	local Spider = ReplicatedStorage.Assets.Extras.SpiderJumpscare:Clone()
	Spider.Parent = workspace
	
	local Animation = Spider.AnimationController.Animator:LoadAnimation(Spider.JumpscareAnim)
	
	repeat task.wait() until Animation.Length > 0 and Spider.CameraPart.Jumpscare.IsLoaded
	
	Animation:Play()
	
	task.delay(0.1, function() 
		task.defer(function()
			Effects.SharpCameraEffect({
				FieldOfView = 90, 
			}, 2, 0.5)
		end)
		
		TweenService:Create(Vignette, TweenInfo.new(0.1), { ImageTransparency = 0.3 }):Play()
		Spider.CameraPart.Jumpscare:Play()
		SoundHandler.PlaySound("Scare.Light")
		SoundHandler.PlaySound("Scare.Hard") 
		
		task.wait(0.1)
		TweenService:Create(Vignette, TweenInfo.new(3), { ImageTransparency = 1 }):Play()
	end)
	
	local Connection = RunService.RenderStepped:Connect(function(deltaTime: number) 
		Spider.CameraPart.CFrame = workspace.CurrentCamera.CFrame
	end)
	
	task.wait(Animation.Length)
	Connection:Disconnect()
	Spider:Destroy()
end

function Effects.PopConfetti(Tool)
	local ToolPartClone = Tool.Handle:Clone()
	ToolPartClone.Anchored = true
	ToolPartClone.Transparency = 1
	ToolPartClone.Parent = workspace
	
	for _, Item in ToolPartClone:GetChildren() do
		if Item:IsA("Weld") then
			Item:Destroy()
		end
	end
	
	local Effects = ToolPartClone.Attachment:GetChildren()
	
	if Tool:FindFirstChild("Cap") then
		Tool.Cap.CanCollide = true
		Tool.Handle.CapWeld:Destroy()
	end
	
	for _, Sound in Tool.Handle:GetChildren() do
		if not Sound:IsA("Sound") then continue end
		Sound:Play()
	end
	
	for _, Effect: ParticleEmitter in Effects do
		Effect:Emit(Settings.GetValue("NoFlash") and 5 or (Effect:GetAttribute("EmitCount") or 40))
	end
	
	Debris:AddItem(ToolPartClone, 15)
end

function Effects.FocusEffect(BasePart, Duration) 
	if Effects.CameraEffectDisabled() then return end 
	local TimeElapsed ,  Duration = 0 ,  Duration or 0.8 


	task.spawn(function() 
		repeat 
			local Camera = game.Workspace.CurrentCamera
			local DeltaTime = task.wait()
			TimeElapsed += DeltaTime
			Camera.CFrame =  Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position,BasePart.Position),DeltaTime * 20 )

		until TimeElapsed > Duration 
	end)
end

function Effects.SharpCameraEffect(Properties, Duration, PopDuration)  
	if Effects.CameraEffectDisabled() then return end 
	
	local Defaults = {} 
	local Camera = game.Workspace.CurrentCamera
	for PropertyName, _ in Properties do 
		Defaults[PropertyName] = Camera[PropertyName]
	end


	local PopTween = TweenInfo.new(PopDuration or 0.05, Enum.EasingStyle.Exponential) 
	local FadeTween = TweenInfo.new(Duration or 12, Enum.EasingStyle.Quart) 

	local Intial : Tween = TweenService:Create(Camera, PopTween, Properties)
	Intial:Play() 
	Intial.Completed:Wait() 

	local Ending = TweenService:Create(Camera, FadeTween, Defaults) 
	Ending:Play() 
end

function Effects.CorrectionSharpEffect(Properties, Duration, PopDuration, MidFn) 
	local Defaults = {} 
	local ColorCorrection = Instance.new("ColorCorrectionEffect", game.Lighting) 
	ColorCorrection:SetAttribute("IgnoreEnvironment", true)
	for PropertyName, _ in Properties do 
		Defaults[PropertyName] = ColorCorrection[PropertyName]
	end
	
	
	local PopTween = TweenInfo.new(PopDuration or 0.05, Enum.EasingStyle.Exponential) 
	local FadeTween = TweenInfo.new(Duration or 15, Enum.EasingStyle.Quart) 
	
	local Intial : Tween = TweenService:Create(ColorCorrection, PopTween, Properties)
	Intial:Play() 
	Intial.Completed:Wait() 
	
	if MidFn then MidFn() end 
	
	local Ending = TweenService:Create(ColorCorrection, FadeTween, Defaults) 
	Ending:Play() 
	Ending.Completed:Connect(function() 
		ColorCorrection:Destroy() 
	end)
end



function Effects.ColorEffect(Color : Color3, Duration) 
	local Duration = Duration or 0.5
	local NeturalBase = Color3.new(1,1,1)
	local ColorCorrection = Instance.new("ColorCorrectionEffect",game.Lighting)
	ColorCorrection:SetAttribute("IgnoreEnvironment", true)

	local ConstructedTweenInfo = TweenInfo.new(Duration,Enum.EasingStyle.Quint)

	ColorCorrection.TintColor = Color

	local EffectTween = TweenService:Create(ColorCorrection,ConstructedTweenInfo,{
		TintColor = NeturalBase,
	})

	EffectTween:Play() 
	EffectTween.Completed:Connect(function() 
		EffectTween:Destroy()
		ColorCorrection:Destroy()
	end) 
end

function Effects.BrightEffect(Brightness : number, Duration) 
	local Duration = Duration or 3 
	local NeturalBase = Color3.new(1,1,1)
	local ColorCorrection = Instance.new("ColorCorrectionEffect",game.Lighting)
	ColorCorrection:SetAttribute("IgnoreEnvironment", true)

	local ConstructedTweenInfo = TweenInfo.new(Duration,Enum.EasingStyle.Quint)


	ColorCorrection.TintColor = NeturalBase
	ColorCorrection.Brightness = Brightness

	local EffectTween = TweenService:Create(ColorCorrection,ConstructedTweenInfo,{
		Brightness = 0   
	})

	EffectTween:Play() 
	EffectTween.Completed:Connect(function() 
		EffectTween:Destroy()
		ColorCorrection:Destroy()
	end) 
end

function Effects.GetRawAttachment(BasePart : BasePart) 
	local A = BasePart:FindFirstChild("__Attachment") 
	if not A then 
		A = Instance.new("Attachment",BasePart)
		A.Name = "__Attachment"
		return A 
	end
	return A 
end

function Effects.PlaySound(...) 
	SoundHandler.PlaySound(...)
end

function Effects.SpawnEffectset(Player, EffectName) 
	local Character : Model = Player.Character
	if not Character then return end 
	local Humanoid : Humanoid = Character:FindFirstChild("Humanoid") 
	local Animator : Animator = Humanoid and Humanoid:FindFirstChild("Animator")
	local HumanoidRootPart : BasePart= Character:FindFirstChild("HumanoidRootPart")

	local LeftHand = Character:FindFirstChild("LeftHand") 
	local RightHand = Character:FindFirstChild("RightHand") 

	local CharCFrame : CFrame, Size = Character:GetBoundingBox()
	local Floor : Vector3= CharCFrame.Position-Vector3.new(0, Size.Y*0.5, 0)

	local HRPOffset = (HumanoidRootPart.Position - Floor)

	local Effectset = ReplicatedStorage.Assets.Particles.Effectset:FindFirstChild(EffectName)  
	if not Effectset then return end 

	local Anims = {} 
	local AnimationFolder = Effectset:FindFirstChild("Animations") 
	if AnimationFolder then 
		for _, Animation : Animation in AnimationFolder:GetChildren() do 
			local AnimationTrack = Animator:LoadAnimation(Animation) 
			AnimationTrack:AdjustSpeed(Animation:GetAttribute("Speed") or 1) 

			Anims[AnimationTrack] = {
				StartDelay = Animation:GetAttribute("StartDelay") or 0 
			}
		end
	end

	local Effects = {} 
	for _, FloorPart : BasePart in Effectset.Floor:GetChildren() do 
		if FloorPart:GetAttribute("DisableNoFlash") and Settings.GetValue("NoFlash") then continue end
		
		local FloorClone = FloorPart:Clone()
		FloorClone:PivotTo(CFrame.new(Floor + (FloorClone.Size * Vector3.yAxis)) * HumanoidRootPart.CFrame.Rotation)
		FloorClone.Parent = game.Workspace 

		table.insert(Effects, Effect.new(FloorClone, Floor))
	end

	for _, BodyEffect : BasePart in Effectset.CharacterEffects:GetChildren() do 
		local Limb : BasePart= Character:FindFirstChild(BodyEffect.Name) 
		if not Limb then continue end 

		local LimbClone = BodyEffect:Clone()
		if BodyEffect:GetAttribute("UseLimbPos") then 
			table.insert(Effects, Effect.new(LimbClone, Limb.Position))
		else 
			table.insert(Effects, Effect.new(LimbClone, Limb))
		end
	end

	local ScreenEffectConfiguration = Effectset:FindFirstChild("ScreenEffect")
	if ScreenEffectConfiguration then 
		task.delay(ScreenEffectConfiguration:GetAttribute("StartDelay") or 0, function() 
			ScreenEffects.PlayAt("", ScreenEffectConfiguration:GetAttribute("Distance") or 40, HumanoidRootPart.Position, ScreenEffectConfiguration)
		end)
	end
	
	if Effectset:GetAttribute("KillAfter") then 
		task.delay(Effectset:GetAttribute("KillAfter") or 0, function() 
			if Player == LocalPlayer then 
				RequestReset.Fire(Effectset:GetAttribute("HardDeath"))
			end
		end)
	end

	if Effectset:GetAttribute("MovementDisable") and Player == LocalPlayer then 
		Locomotion.SetEnabled(false)
		task.delay(Effectset:GetAttribute("MovementDisable"), function() 
			Locomotion.SetEnabled(true) 
		end)
	end

	for AnimationTrack : AnimationTrack,  Setting in Anims  do 
		task.delay(Setting.StartDelay, function() 
			AnimationTrack:Play()
		end) 
	end

	for _, Effect in Effects do 
		Effect:PlayThenDestroy() 
	end
end

function Effect.SpawnNewEffect(EffectName, PositionOrPart) 
	local GroupEffect = ReplicatedStorage.Assets.Particles.Effects:FindFirstChild(EffectName) 

	if GroupEffect then 
		Effect.new(GroupEffect, PositionOrPart):PlayThenDestroy()  
	else 
		error("Effect NOW!"..EffectName)
	end
end


function Effects.SpawnEffect(EffectName,Position,...) 
	local GroupEffect = ReplicatedStorage.Assets.Particles.Groups:FindFirstChild(EffectName) 

	if GroupEffect then 
		ParticleSource.CreateGroup(GroupEffect, Position, ...) 
	else 
		error("Effect NOW!"..EffectName)
	end
end

function Effects.Init() 
	
end

function Effects.Emit(Part) 
	OldParticleSource.Emit(Part, nil , true)
end

function Effects.SpawnFirecrackers(FirecrackerGroup: Model) 
	local Firecrackers = FirecrackerGroup:GetChildren()
	local ActiveFirecrackers = 0
	
	for _, Firecracker in pairs(Firecrackers) do
		if ActiveFirecrackers >= 4 then repeat task.wait(.1) until ActiveFirecrackers < 2 end
		ActiveFirecrackers += 1
		Firecracker.Firecrackers:Play()
		
		for _, particl in pairs(Firecracker:GetChildren()) do
			if particl:IsA("ParticleEmitter") and not Settings.GetValue("NoFlash") then
				particl.Enabled = true
			end
		end
		
		task.defer(function()
			Firecracker.Firecrackers.Ended:Wait()
			for _, particl in pairs(Firecracker:GetChildren()) do
				if particl:IsA("ParticleEmitter") then
					particl.Enabled = false
				end
			end
			ActiveFirecrackers -= 1
		end)
	end
end

function Effects.SpawnPsudeoFirework1(Position : Position) 
	local FireworkPart = ReplicatedStorage.Assets.Extras.Firework1:Clone() 
	FireworkPart.Parent = game.Workspace
	FireworkPart.Position = Position 

	local Height = math.random(100, 150) 
	local Side = Vector3.new(
		math.random(-10, 10),
		0,
		math.random(-10, 10)
	)

	local Start : Vector3 = Position
	local End   : Vector3 = Start + (Height *  Vector3.yAxis) + Side 

	local SecondsPerStud = 0.01

	local Distance = (Start-End).Magnitude 
	local TimeElapsed, Duration = 0, Distance * SecondsPerStud 
	repeat 
		TimeElapsed += task.wait()
		local Delta = TimeElapsed/Duration 

		FireworkPart.Position = Start:Lerp(End, Delta)
	until TimeElapsed > Duration

	Effect.new(FireworkPart.Explosion, FireworkPart.Position):PlayThenDestroy()  
	FireworkPart:Destroy()
end 

function Effects.SpawnFirework(MotarTarget : BasePart) 
	local MotarFolder = MotarTarget.Parent 
	local MotarConfig = MotarFolder:GetAttributes()

	MotarTarget.Fire:Play()
	
	local Height = math.random(MotarConfig.Height.Min, MotarConfig.Height.Max)
	local Side = Vector3.new(
		math.random(-MotarConfig.Spread, MotarConfig.Spread), 
		0, 
		math.random(-MotarConfig.Spread , MotarConfig.Spread)
	)
	local Start : Vector3 = MotarTarget.Position - (Vector3.yAxis * 2)
	local End   : Vector3 = Start + (Height *  Vector3.yAxis) + Side 
	
	Effects.FireworkPosition += 1 
	if Effects.FireworkPosition > #Effects.Fireworks then 
		Effects.FireworkPosition = 1 
	end
	
	local Firework = Effects.Fireworks[Effects.FireworkPosition]
	for _, Desc in Firework:GetDescendants() do 
		if Desc:IsA("Trail") then Desc.Enabled = false end
	end

	Firework.Projectile.Base.Trail.Enabled = false 
	Firework.Projectile.Position = Start 
	Firework.Explosion.Position = Start 
	
	task.wait(0.1)
	Firework.Projectile.Base.Trail.Enabled = true
	
	for _, Desc in Firework:GetDescendants() do 
		if Desc:IsA("ParticleEmitter") or Desc:IsA("Trail") or Desc:IsA("Beam") then 
			Desc.Color =ColorSequence.new(MotarConfig.Color)
			
			if Desc:IsA("Trail") then 
				Desc.Enabled = true 
			end
		elseif Desc:IsA("Light") then
			Desc.Color = MotarConfig.Color
		end
	end
	
	Firework:ScaleTo(4.786 * MotarConfig.Scale)
	Firework.Projectile.Screaming:Play()
	
	local SecondsPerStud = 0.01
	
	local Distance = (Start-End).Magnitude 
	local TimeElapsed, Duration = 0, Distance * SecondsPerStud 
	repeat 
		TimeElapsed += task.wait()
		local Delta = TimeElapsed/Duration 
		
		Firework:PivotTo(CFrame.new(Start:Lerp(End, Delta)))
	until TimeElapsed > Duration
	
	for _, Desc in Firework:GetDescendants() do 
		if Desc:IsA("Trail") then Desc.Enabled = false end
	end
	Firework.Projectile.Position = Vector3.zero  
	Firework.Projectile.Screaming:Stop() 
	Firework.Explosion.Explosion:Play() 
	ParticleSource.Emit(Firework.Explosion, Settings.GetValue("NoFlash") and 1 or 14)
	
	task.wait(10)
	Firework.Projectile.Base.Trail.Enabled = false
	Firework:PivotTo(CFrame.new(Vector3.zero))
end

function Effects.SoulAura(Player : Player) 
	local Character : Model = Player.Character
	if not Character then return end

	local Humanoid : Humanoid = Player.Character:FindFirstChild("Humanoid") 
	local HumanoidRootPart : BasePart= Player.Character:FindFirstChild("HumanoidRootPart")
	if HumanoidRootPart and Humanoid then 
		local Parts = {"Head", "LeftLowerArm", "RightLowerArm", "RightUpperLeg", "LeftUpperLeg"}

		for _,Part in ipairs(Parts) do 
			local BodyPart : BasePart = Character:FindFirstChild(Part) 
			if BodyPart then 
				for _, Particle in game.ReplicatedStorage.Assets.Particles.Aura1:GetChildren() do 
					Particle:Clone().Parent = BodyPart
				end
			end
		end


		local SpiritLoop : Sound = SoundHandler.GetSound("spirit_loop")
		SpiritLoop.Looped = true 
		SpiritLoop.Parent = HumanoidRootPart 
		SpiritLoop:Play()

	end
end

function Effects.Invis(Player : Player) 
	local Character : Model = Player.Character
	if not Character then return end

	local Humanoid : Humanoid = Player.Character:FindFirstChild("Humanoid") 
	local HumanoidRootPart : BasePart= Player.Character:FindFirstChild("HumanoidRootPart")
	if HumanoidRootPart and Humanoid then 
		local Effect = game.ReplicatedStorage.Assets.Particles.OnTapInvisible:Clone() 
		
		Effect.Parent = workspace
		Effect.CFrame = HumanoidRootPart.CFrame
		local Weld = Instance.new("WeldConstraint", Effect)
		Weld.Part1 = Effect
		Weld.Part0 = HumanoidRootPart
		Weld.Enabled = true
		
		for _, Particle in Effect:GetChildren() do
			if not Particle:IsA("ParticleEmitter") then continue end
			task.defer(function()
				task.wait(Particle:GetAttribute("EmitDelay") or 0)
				Particle:Emit(Particle:GetAttribute("EmitCount"))
			end)
		end
		
		Debris:AddItem(Effect, 5)
	end
end

function Effects.CloneStaff(Hit: CFrame) 
	local Effect = game.ReplicatedStorage.Assets.Particles.StaffSummonLand:Clone() 

	Effect.Parent = workspace
	Effect.Anchored = true
	Effect.CanCollide = false
	Effect.CFrame = Hit

	for _, Particle in Effect:GetDescendants() do
		if Particle:IsA("Sound") then
			Particle:Play()
		end
		if not Particle:IsA("ParticleEmitter") then continue end
		task.defer(function()
			task.wait(Particle:GetAttribute("EmitDelay") or 0)
			Particle:Emit(Particle:GetAttribute("EmitCount"))
		end)
	end

	Debris:AddItem(Effect, 5)
end

function Effects.RefreshStaff(Hit: CFrame) 
	local Effect = game.ReplicatedStorage.Assets.Particles.OnTapAvatarChange:Clone() 

	Effect.Parent = workspace
	Effect.Anchored = true
	Effect.CanCollide = false
	Effect.CFrame = Hit

	for _, Particle in Effect:GetDescendants() do
		if Particle:IsA("Sound") then
			Particle:Play()
		end
		if not Particle:IsA("ParticleEmitter") then continue end
		task.defer(function()
			task.wait(Particle:GetAttribute("EmitDelay") or 0)
			Particle:Emit(Particle:GetAttribute("EmitCount"))
		end)
	end

	Debris:AddItem(Effect, 5)
end

function Effects.YarnCat(Player : Player) 
	local Character : Model = Player.Character
	if not Character then return end
	
	local Humanoid : Humanoid = Player.Character:FindFirstChild("Humanoid") 
	local HumanoidRootPart : BasePart= Player.Character:FindFirstChild("HumanoidRootPart")
	if HumanoidRootPart and Humanoid then 
		local Effect = game.ReplicatedStorage.Assets.Particles.OnTapCat:Clone() 
		
		Effect.Parent = workspace
		Effect.Anchored = true
		
		local Needles = Effect:FindFirstChild("Needle")
		local Animation = Instance.new("Animation")
		Animation.AnimationId = "rbxassetid://16844886400"

		local Track = Needles.AnimationController.Animator:LoadAnimation(Animation)
		if Character.Humanoid.Sit and Player == game.Players.LocalPlayer then Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end
		task.wait(0.5)
		
		Effect.CFrame = CFrame.new(HumanoidRootPart.Position) * Effect.CFrame.Rotation
		Needles:PivotTo(CFrame.new(HumanoidRootPart.Position) * Needles.PrimaryPart.CFrame.Rotation)
		
		for _, Particle in Effect:GetChildren() do
			if Particle:IsA("ParticleEmitter") then
				task.delay(Particle:GetAttribute("EmitDelay") or 0, function()
					Particle:Emit(Particle:GetAttribute("EmitCount"))
				end) 
			end
		end

		task.wait(1)
		for _, Item in pairs(Needles:GetChildren()) do
			if Item:IsA("BasePart") and Item.Name ~= "RootPart" then
				Item.Transparency = 0
			end
		end
		
		for _, Inst in pairs(Character:GetDescendants()) do
			if Inst:IsA("BasePart") then
				Inst.LocalTransparencyModifier = 1
			end
		end
		Track:Play()

		task.wait(Track.Length)
		for _, Item in pairs(Needles:GetChildren()) do
			if Item:IsA("BasePart") and Item.Name ~= "RootPart" then
				Item.LocalTransparencyModifier = 1
			end
		end

		Debris:AddItem(Effect, 5)
	end
end

function Effects.Fish(Player : Player) 
	local Character : Model = Player.Character
	if not Character then return end

	local Humanoid : Humanoid = Player.Character:FindFirstChild("Humanoid") 
	local HumanoidRootPart : BasePart= Player.Character:FindFirstChild("HumanoidRootPart")
	if HumanoidRootPart and Humanoid then 
		local Effect = game.ReplicatedStorage.Assets.Particles.FishEffect:Clone() 

		Effect.Parent = workspace
		Effect.Anchored = true

		if Character.Humanoid.Sit and Player == game.Players.LocalPlayer then Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end
		task.wait(0.5)

		Effect.CFrame = CFrame.new(HumanoidRootPart.Position) * Effect.CFrame.Rotation

		for _, Particle in Effect:GetDescendants() do
			if Particle:IsA("ParticleEmitter") and Particle:GetAttribute("ExplosionEffect") then
				task.delay(Particle:GetAttribute("EmitDelay") or 0, function()
					Particle:Emit(Particle:GetAttribute("EmitCount"))
				end) 
			else
				Debris:AddItem(Particle, 2)
			end
		end
		
		task.wait(1)

		Debris:AddItem(Effect, 5)
	end
end

function Effects.ApplyAura(Player : Player, AuraName : string) 
	local Character : Model = Player.Character
	if not Character then return end

	local AuraGroup = game.ReplicatedStorage.Assets.Particles.Auras:FindFirstChild(AuraName) 
	if not AuraGroup then 
		warn(`no auragroup {AuraName}`)
		return 
	end 

	local Time = 60 

	local Humanoid : Humanoid = Player.Character:FindFirstChild("Humanoid") 
	local HumanoidRootPart : BasePart= Player.Character:FindFirstChild("HumanoidRootPart")
	if HumanoidRootPart and Humanoid then 
		local Parts = {"Head", "LeftLowerArm", "RightLowerArm", "RightLowerLeg", "LeftLowerLeg"}

		for _,Part in ipairs(Parts) do 
			local BodyPart : BasePart = Character:FindFirstChild(Part)  
			local ApplyGroup = AuraGroup:FindFirstChild(Part)
			if BodyPart then 
				for _, Particle in AuraGroup.Aura:GetChildren() do 
					local BodyClone = Particle:Clone()
					BodyClone.Parent = BodyPart

					Debris:AddItem(BodyClone, Time)
				end

				if ApplyGroup then 
					warn("something here!")

					for _, Particle in ApplyGroup:GetChildren() do 
						local BodyClone = Particle:Clone()
						BodyClone.Parent = BodyPart 

						Debris:AddItem(BodyClone, Time)
					end
				end
			end

		end

		local LoopName = AuraGroup:GetAttribute("Loop")
		if not LoopName	then return end 

		local SpiritLoop : Sound = SoundHandler.GetSound(LoopName)
		SpiritLoop.Looped = true 
		SpiritLoop.Parent = HumanoidRootPart 
		SpiritLoop.RollOffMinDistance = 5 
		SpiritLoop.RollOffMaxDistance  = 30 
		SpiritLoop.RollOffMode = Enum.RollOffMode.LinearSquare
		SpiritLoop:Play()

		Debris:AddItem(SpiritLoop, Time)
	end
end

function Effects.Spark(Player : Player) 
	local Character : Model = Player.Character
	if not Character then return end
	if Settings.GetValue("NoFlash") then return end

	local Humanoid : Humanoid = Player.Character:FindFirstChild("Humanoid") 
	local HumanoidRootPart : BasePart= Player.Character:FindFirstChild("HumanoidRootPart")
	if HumanoidRootPart and Humanoid then 
		local PlayerHighlight = Instance.new("Highlight", Character) 
		PlayerHighlight.OutlineTransparency = 1 
		PlayerHighlight.FillColor = Color3.new(1, 0.917647, 0) 
		PlayerHighlight.FillTransparency = 0 


		for _, Child in ReplicatedStorage.Assets.Particles.Sparkle:GetChildren() do 
			local Part = Child:Clone() 
			Part.Parent = HumanoidRootPart 
			Debris:AddItem(Part, 0.5)
		end

		PlayerHighlight.Parent = Character 

		local Highlight = TweenService:Create(PlayerHighlight, Effects.Tweens.HighlightTween, {
			FillTransparency = 1 
		})
		Highlight.Completed:Connect(function() 
			PlayerHighlight:Destroy() 
		end)
		Highlight:Play() 

	end
end

function Effects.WaterPortal(Player : Player) 
	warn("WaterPortal!", Player)

	local Character : Model = Player.Character
	if not Character then return end 
	local Humanoid : Humanoid = Player.Character:FindFirstChild("Humanoid")
	local HumanoidRootPart : BasePart= Player.Character:FindFirstChild("HumanoidRootPart")
	if not HumanoidRootPart or not Humanoid then return end 

	local CharCFrame : CFrame, Size = Character:GetBoundingBox()
	local Floor : Vector3 = (CharCFrame.Position-Vector3.new(0, Size.Y*0.5, 0)) + (Vector3.yAxis * 1)

	local HRPOffset = (HumanoidRootPart.Position - Floor)
	local HumanoidRootPart : BasePart= Player.Character:FindFirstChild("HumanoidRootPart")

	HumanoidRootPart.Anchored = true

	local TargetClone = HumanoidRootPart:Clone()
	TargetClone.Parent = game.Workspace


	local GateExplosion = ReplicatedStorage.Assets.Particles.Water.WaterExplosion:Clone()
	local Tenticle = ReplicatedStorage.Assets.Extras.Tentacle:Clone() 
	local Gate : Model = ReplicatedStorage.Assets.Particles.Water.WaterPortal:Clone() 
	Gate.Parent = game.Workspace
	GateExplosion.Parent = game.Workspace

	GateExplosion:PivotTo(CFrame.new(Floor))

	local TenticleAnimator = Tenticle.AnimationController.Animator 

	local Rig : Model = Tenticle:WaitForChild("Rig")
	local RigHumanoid : Humanoid = Rig:WaitForChild("Humanoid")

	local PortalLoop : Sound = SoundHandler.PlaySound("water_sound", nil, {RETURN=true})
	PortalLoop:Play() 

	PortalLoop.RollOffMaxDistance = 120 
	PortalLoop.RollOffMinDistance = 5 

	PortalLoop.Parent = Gate.Base


	task.wait()
	ParticleSource.Emit(GateExplosion)


	ScreenEffects.PlayAt("PortalOpen2", 20, TargetClone.Position)

	local _, GateSize = Gate:GetBoundingBox() 
	local TimeElapsed, Duration = 0, 2 
	repeat 
		TimeElapsed += task.wait() 
		local Progress = TweenService:GetValue(TimeElapsed/Duration, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
		local NewFloor = HumanoidRootPart.Position - HRPOffset
		Gate:ScaleTo(Progress * 0.5)
		Gate:PivotTo(CFrame.new(
			NewFloor - (GateSize 
				* Vector3.new(0,0.5,0)
			) 
			) * CharCFrame.Rotation)

		Gate.Base.Light.Range = 15 * Progress
		Gate.Base.Light.Brightness = 10 * Progress
	until TimeElapsed > Duration 


	Tenticle.Parent = game.Workspace
	if Player == LocalPlayer then 
		game.Workspace.CurrentCamera.CameraSubject = TargetClone
	end


	Tenticle:PivotTo(CFrame.new(Floor))
	RigHumanoid:ApplyDescription(Humanoid:GetAppliedDescription())
	local PullAnimation = TenticleAnimator:LoadAnimation(Tenticle.Animation)	
	PullAnimation:GetMarkerReachedSignal("Under"):Connect(function() 
		PullAnimation:AdjustSpeed(0)

		task.wait(0.5)
		Tenticle:Destroy() 
	end)
	PullAnimation:Play()


	task.wait(0.5)
	Character:PivotTo(Character:GetPivot() - (Vector3.yAxis*10) ) 

	task.wait(4.5)


	local TimeElapsed, Duration = 0, 1.3 
	repeat 
		TimeElapsed += task.wait() 
		local Alpha = 1-math.clamp(TimeElapsed/Duration, 0, 1)  
		local Delta = TweenService:GetValue(Alpha, Enum.EasingStyle.Back, Enum.EasingDirection.Out) 

		Gate:ScaleTo((Delta  * 0.5) + 0.001)

		Gate.Base.Light.Range = 15 * Delta
		Gate.Base.Light.Brightness = 10 * Delta
	until TimeElapsed > Duration 

	Gate:Destroy()
	GateExplosion:Destroy()

	if Player == LocalPlayer then RequestReset.Fire(true) end 
end

function Effects.OpenGate(Player : Player) 
	local Character : Model = Player.Character
	if not Character then return end 
	local LeftHand = Player.Character:FindFirstChild("LeftHand") 
	local RightHand = Player.Character:FindFirstChild("RightHand") 

	local Humanoid : Humanoid = Player.Character:FindFirstChild("Humanoid") 
	local Animator : Animator = Humanoid and Humanoid:FindFirstChild("Animator")
	local HumanoidRootPart : BasePart= Player.Character:FindFirstChild("HumanoidRootPart")
	if HumanoidRootPart and LeftHand and RightHand then 
		local CharCFrame : CFrame, Size = Character:GetBoundingBox()
		local Floor : Vector3= CharCFrame.Position-Vector3.new(0, Size.Y*0.5, 0)

		local HRPOffset = (HumanoidRootPart.Position - Floor) + (Vector3.yAxis*0.1)



		local Gate : Model = ReplicatedStorage.Assets.Particles.Gate:Clone() 
		Gate.Parent = game.Workspace

		local PullAnimation : AnimationTrack = (Animator or Humanoid):LoadAnimation(Gate.PullAnimation)		

		local GateBase = Gate:WaitForChild("Base")
		local LeftBeamAttachment = GateBase:WaitForChild("Left") 
		local RightBeamAttachment = GateBase:WaitForChild("Right")

		local LeftBeam : Beam = LeftBeamAttachment:WaitForChild("Beam") 
		local RightBeam : Beam = RightBeamAttachment:WaitForChild("Beam")

		local LeftAttachment = Effects.GetRawAttachment(LeftHand) 
		local RightAttachment = Effects.GetRawAttachment(RightHand)

		LeftBeam.Attachment1 = LeftAttachment 
		RightBeam.Attachment1 = RightAttachment

		local _, GateSize = Gate:GetBoundingBox() 

		local PortalLoop : Sound = SoundHandler.PlaySound("portal_loop",nil, {RETURN=true})
		PortalLoop.Looped = true 
		PortalLoop:Play() 
		
		PortalLoop.RollOffMaxDistance = 120 
		PortalLoop.RollOffMinDistance = 5 

		PortalLoop.Parent = GateBase

		Gate:ScaleTo(0.01)


		Humanoid.JumpPower = 0 

		local TimeElapsed, Duration = 0, 3 
		repeat 
			TimeElapsed += task.wait() 
			local Progress = TimeElapsed/Duration
			local NewFloor = HumanoidRootPart.Position - HRPOffset
			Gate:ScaleTo(Progress)
			Gate:PivotTo(CFrame.new(
				NewFloor - (GateSize 
					* Vector3.new(0,0.5,0)
				) 
				) * CharCFrame.Rotation)

			PortalLoop.Volume = 10 * Progress

			GateBase.Light.Range = 15 * Progress
			GateBase.Light.Brightness = 10 * Progress
		until TimeElapsed > Duration 

		SoundHandler.PlaySoundAt("portal_open", GateBase, {5,120})
		ScreenEffects.PlayAt("PortalOpen", 15, HumanoidRootPart.Position)

		if Player == LocalPlayer then
			PullAnimation:GetMarkerReachedSignal("Under"):Connect(function() 
				PullAnimation:AdjustSpeed(0)
			end)
			PullAnimation:Play(0.3)
		end

		PortalLoop.Volume = 10
		GateBase.Light.Range = 15 
		GateBase.Light.Brightness = 10 

		local SoulLoop : Sound = SoundHandler.PlaySound("soul_loop",nil, {RETURN=true})
		SoulLoop.Looped = true 
		SoulLoop.Parent = GateBase 
		SoulLoop:Play()
		
		SoulLoop.RollOffMaxDistance = 120
		SoulLoop.RollOffMinDistance = 5

		local FlutterLoop : Sound = SoundHandler.PlaySound("flutter_loop",nil, {RETURN=true})
		FlutterLoop.Looped = true 
		FlutterLoop.Parent = GateBase
		FlutterLoop:Play() 
		
		FlutterLoop.RollOffMaxDistance = 120 
		FlutterLoop.RollOffMinDistance = 5 

		Gate:ScaleTo(1)

		HumanoidRootPart.Anchored = true 

		task.wait(4.7)   

		local SoulVolume = SoulLoop.Volume 
		local FlutterVolume = FlutterLoop.Volume 
		local TimeElapsed, Duration = 0, 1.3 
		repeat 
			TimeElapsed += task.wait() 
			local Alpha = 1-math.clamp(TimeElapsed/Duration, 0, 1)  
			local Delta = TweenService:GetValue(Alpha, Enum.EasingStyle.Back, Enum.EasingDirection.Out) 

			Gate:ScaleTo(Delta+0.001)

			PortalLoop.Volume = 10 * Delta

			GateBase.Light.Range = 15 * Delta
			GateBase.Light.Brightness = 10 * Delta

			SoulLoop.Volume = SoulVolume * Delta 
			FlutterLoop.Volume = FlutterVolume * Delta
		until TimeElapsed > Duration 

		SoulLoop:Stop()
		SoulLoop.Looped = false 

		FlutterLoop:Stop()
		FlutterLoop.Looped = false 

		PortalLoop:Stop() 
		PortalLoop.Looped = false 

		Gate:Destroy() 

		if Player == LocalPlayer then RequestReset.Fire(true) end 
	end
end

function Effects:__init() 
	-- Don't do this until first character	
	if LocalPlayer.Character then 
		Effects.DisableCameraEffects = false 
	else 
		LocalPlayer.CharacterAdded:Once(function() 
			Effects.DisableCameraEffects = false 
		end)
	end
end

function Effects.Setup()  
	Effects:__init()
	Effects.JumpScare = InterfaceHandler:GetScreenGui("MainPriority").JumpScare
	Effects.Blackout = InterfaceHandler:GetScreenGui("MainPriority").Blackout
	Effects.Blackout.Visible = true 
	
	--SpawnGroup.Event:Connect(Effects.SpawnEffect)
	--SpawnEffect.Event:Connect(Effect.SpawnNewEffect)
	
	--[[PlayerEffect.Event:Connect(function(Index, ...) 
		local Method = Effects[Index] 
		if Method then Method(...) end
	end)]]

	--Effects.Play = ScreenEffects.Play 
	
	local Folder = Instance.new("Folder", game.Workspace)
	Folder.Name = "LocalFireworks" 
	
	local Fireworks = 40 
	--[[for _=1, Fireworks do 
		local Firework = ReplicatedStorage.Assets.LNYFirework:Clone() 
		Firework.Parent = Folder
		Firework.Projectile.Base.Trail.Enabled = false 
		Firework.Projectile.Position = Vector3.zero  
		Firework.Explosion.Position = Vector3.zero  
		
		table.insert(Effects.Fireworks, Firework)
	end]]
	
	-- Backwards compatability
	--[[local TweenClient = Mince:GetEvent("Tween").Extend("Minigame")
	TweenClient.Event:Connect(function(item, properties, ...)
		TweenService:Create(item, TweenInfo.new(...), properties):Play()
	end)]]
end


return Effects 