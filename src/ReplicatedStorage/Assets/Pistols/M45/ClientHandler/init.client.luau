local Tool = script.Parent
local Camera = workspace.CurrentCamera
local Debris = game:GetService("Debris")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local WeaponInfo = RS.PublicEvents.Weapons.Load
local Player = game.Players.LocalPlayer
repeat wait() until Player.Character ~= nil
local Character = Player.Character or Player.CharacterAdded:Wait()
local Module = require(script.Setting)
local CameraModule = require(script.CameraModule)
local Barrel = Tool.Pistol:FindFirstChild("Muzzle")
local Fire = RS.PublicEvents.Weapons.Fire
local Sounds = Tool.Pistol.Sounds
local AmmoUI = Player.PlayerGui:WaitForChild("AmmoUI")
local Configuration = nil
local Cooldown = false
local Tracks = {}
local Mouse = Player:GetMouse()
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local Character = Player.Character or Player.CharacterAdded:Wait()
local Head = Character:WaitForChild("Head")
local Neck = Head:WaitForChild("Neck")
local Arm = Character:WaitForChild("RightUpperArm")
local Shoulder = Arm:WaitForChild("RightShoulder")
local Humanoid = Character:WaitForChild("Humanoid")
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local Equipped = false
local NeckOriginC0 = Neck.C0
local ShoulderOriginC0 = Shoulder.C0
local AimDown = false

Neck.MaxVelocity = 2/3

RunService.RenderStepped:Connect(function()
	if not Equipped then return end
	if Configuration == nil then return end
	if not Configuration.isEquipped == true then return end
	local CameraCFrame = Camera.CoordinateFrame
	if Character:FindFirstChild("UpperTorso") and Character:FindFirstChild("Head") then
		local ArmLookVector = Arm.CFrame.lookVector
		local HeadPosition = Head.CFrame.Position
		if Neck and Shoulder then
			if Camera.CameraSubject:IsDescendantOf(Character) or Camera.CameraSubject:IsDescendantOf(Player) then
				local Point = Mouse.Hit.Position
				local Distance = (Head.CFrame.p - Point).magnitude
				local Difference = Head.CFrame.Y - Point.Y
				Neck.C0 = Neck.C0:lerp(NeckOriginC0 *
					CFrame.Angles(-(math.asin(Difference / Distance) ), (((HeadPosition - Point).Unit):Cross(ArmLookVector)).Y, 0), .5 )
				Shoulder.C0 = Shoulder.C0:lerp(ShoulderOriginC0 *
					CFrame.Angles(-(math.asin(Difference / Distance)), (((HeadPosition - Point).Unit):Cross(ArmLookVector)).Y, 0), .5 )
			end
		end
	end	
end)

local function RAND(Min, Max, Accuracy)
	local Inverse = 1 / (Accuracy or 1)
	return (math.random(Min * Inverse, Max * Inverse) / Inverse)
end

local function RecoilCamera()
	if Module.CameraRecoilingEnabled then
		local CurrentRecoil = Module.Recoil*(AimDown and 1-Module.RecoilRedution or 1)
		local RecoilX = math.rad(CurrentRecoil * RAND(Module.AngleX_Min, Module.AngleX_Max, Module.Accuracy))
		local RecoilY = math.rad(CurrentRecoil * RAND(Module.AngleY_Min, Module.AngleY_Max, Module.Accuracy))
		local RecoilZ = math.rad(CurrentRecoil * RAND(Module.AngleZ_Min, Module.AngleZ_Max, Module.Accuracy))
		CameraModule:accelerate(RecoilX,RecoilY,RecoilZ)	    
		delay(0.03, function()
			CameraModule:accelerateXY(-RecoilX,-RecoilY)
		end)
	end
end

--// Update Ammo UI
local function UpdateAmmo()
	AmmoUI.AmmoAmount.Text = Configuration["AmmoLeft"].Value
	return
end

--// Stop All Animations
local function StopTracks()
	for i,Track in pairs(Tracks) do
		Track:Stop()
	end return
end

--// Slide
local function SlideBack(Item)
	Item.Pistol.SlideBack.Transparency = 0
	Item.Pistol.Slide.Transparency = 1
	task.wait(.05)
	Item.Pistol.SlideBack.Transparency = 1
	Item.Pistol.Slide.Transparency = 0
	return
end

local function CheckImpact(Item)
	local Checked = false
	if Checked == false then
		Checked = true	
		local Bullet = RS.Bullets.Bullet:Clone(); Bullet.Parent = workspace; 
		local Muzzle = Item["Pistol"]:FindFirstChild("Muzzle")
		local Player = game:GetService("Players").LocalPlayer
		local Character = Player.Character
		local Hit, Position, Normal = workspace:FindPartOnRay(Ray.new(Muzzle.Position,Muzzle.CFrame.lookVector * 500),Muzzle)
		
		Muzzle.Beam.Attachment1 = Bullet.BulletAttach	
		task.delay(.05, function() Muzzle.Beam.Enabled = false end)
		
		if Hit then 
			Debris:AddItem(Bullet,1)
			Bullet.Transparency = 1
			Bullet.Position = Position
			Bullet.Anchored = true
			if Hit.Parent:FindFirstChild("Humanoid") or Hit.Parent.Parent:FindFirstChild("Humanoid") then
			local Data = require(script.Impact)
			local TableData = Data:GetData(Player, Hit)
				Bullet.Impact:Play()
				Bullet.BloodHit:Emit(30)
			else
				Bullet.Concret:Emit(50)
				Bullet.Material = Hit.Material
				Bullet.Transparency = 0
				Bullet.Color = Color3.fromRGB(57, 57, 57)
			end
		else
			Debris:AddItem(Bullet, .1)
		end
		return 
	end
end

--// Weapon Fired
local function WeaponFired(Item, Player)
	SlideBack(Item)
	local Muzzle = Item["Pistol"]:FindFirstChild("Muzzle")
	Muzzle.MuzzleFlash:Emit(1)
	Muzzle.Smoke:Emit(1)
	Item.Pistol.Sounds.Fire:Play()
	Muzzle.Beam.Enabled = true
	if Player.Name == game.Players.LocalPlayer.Name then RecoilCamera() end
	return CheckImpact(Item)
end

local function MagDrop(Position, Item)
	Item.Pistol.SlideBack.Transparency = 0
	Item.Pistol.Slide.Transparency = 1
	Item.Pistol.Mag.Transparency = 1
	Item.Pistol.Sounds.Reload:Play()
	local Mag = RS.Mags[Item.Name]:Clone()
	Mag.CFrame = Position
	Mag.Parent = workspace
	task.wait(1.5)
	Item.Pistol.Mag.Transparency = 0
	Item.Pistol.SlideBack.Transparency = 1
	Item.Pistol.Slide.Transparency = 0
	Debris:AddItem(Mag, 3)
end

--// Load Weapon Information
WeaponInfo:FireServer(Tool)
WeaponInfo.OnClientEvent:Connect(function(Packet)
	local GetConfiguration = RS[Player.Name][Tool.Name]["Configuration"]
	Configuration = GetConfiguration
	return
end)

--// Preload Animations
for _,Animation in pairs(Tool:WaitForChild("Animations"):GetChildren()) do
	Tracks[Animation.Name] = Character.Humanoid:LoadAnimation(Animation)
end

--// Inputs
UIS.InputBegan:Connect(function(Input)
	local AmmoUI = Player.PlayerGui:WaitForChild("AmmoUI")
	if Input.KeyCode == Enum.KeyCode.R  and Configuration.isReloading.Value ~= true then
		Configuration.isReloading.Value = true
		Tracks['Reload']:Play()
		local Position = Tool.Pistol.Mag.CFrame 
		RS.PublicEvents.Weapons.Mag:FireServer(Position, Tool)
		Tracks['Reload'].Stopped:Wait()
		Configuration.isReloading.Value = false
		Configuration["AmmoLeft"].Value = 9
		UpdateAmmo()
		return Configuration.isReloading
	elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then
		Tracks["Aiming"]:Play()
		local Barrel = Tool.Pistol.Barrel
		local Beam = Barrel.Beam
		local Muzzle = Tool.Pistol.Muzzle
		Beam.Enabled = true
		local BeamParticle = Barrel.End.ParticleEmitter
		BeamParticle.Enabled = true
		while Input.UserInputState == Enum.UserInputState.Begin do
			BeamParticle:Emit(1)
			local Hit, Position, Normal = workspace:FindPartOnRay(
				Ray.new(
					Muzzle.Position, Muzzle.CFrame.lookVector * 1000),Barrel)
			local Distance = (Position - Barrel.Attachment.WorldPosition).Magnitude
			Barrel.End.Position = Vector3.new(math.round(Distance),0,0) 
			RunService.Heartbeat:Wait()
		end
		Tracks["Aiming"]:Stop()
		return
	end
end)

UIS.InputEnded:Connect(function(Input)
	if Input.UserInputType == Enum.UserInputType.MouseButton2 then
		local Barrel = Tool.Pistol.Barrel
		local Beam = Barrel.Beam
		local Muzzle = Tool.Pistol.Muzzle
		local BeamParticle = Barrel.End.ParticleEmitter
		BeamParticle.Enabled = false
		Beam.Enabled = false
	end
end)

--// Use Weapon
Tool.Activated:Connect(function()
	if Configuration.isReloading.Value or Cooldown then return end
	if Configuration["AmmoLeft"].Value > 0 then
		Configuration["AmmoLeft"].Value -= 1
		Cooldown = true
		--//Tracks['Shoot']:Play() 
		Fire:FireServer(Tool)
		UpdateAmmo()
		task.wait(Configuration.FireRate.Value)
		Cooldown = false
	elseif Configuration["AmmoLeft"].Value == 0 and not Configuration.isReloading.Value then
		Configuration.isReloading.Value = true
		Tracks['Reload']:Play()
		task.wait(.2)
		local Position = Tool.Pistol.Mag.CFrame 
		RS.PublicEvents.Weapons.Mag:FireServer(Position, Tool)
		Tracks['Reload'].Stopped:Wait()
		Configuration["AmmoLeft"].Value = 9
		UpdateAmmo()
		Configuration.isReloading.Value = false
		return Configuration.isReloading
	end
end)

--// Tool Listener
Tool.AncestryChanged:Connect(function()
	if not Tool.Parent:isA("Model") then
		Configuration.isEquipped.Value = false
		AmmoUI.Enabled = false
		Equipped = false
		UIS.MouseIconEnabled = true
		Configuration.isReloading.Value = true
		return task.spawn(StopTracks)
	else
		Configuration.isReloading.Value = false
		AmmoUI.Enabled = true
		Equipped = true
		UIS.MouseIconEnabled = false
		Configuration.isEquipped.Value = true
	end
	return Configuration.isEquipped, Configuration.isReloading
end)

--// ClientEvents
RS.PublicEvents.Weapons.Mag.OnClientEvent:Connect(function(Position, Item) return MagDrop(Position, Item) end)
RS.PublicEvents.Weapons.Fire.OnClientEvent:Connect(function(Item, Player) return WeaponFired(Item, Player) end)

--// By MrHardswell 7/7/2022