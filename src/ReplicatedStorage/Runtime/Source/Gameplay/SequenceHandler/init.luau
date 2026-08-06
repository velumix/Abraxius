--[[
	SequenceHandler
	** Client-side only **
	A module for managing cinematic sequences and camera movements in the game.
	Sequences can be defined with multiple camera positions and timing information.

	Example usage:
	```lua
	local SequenceHandler = require(path.to.SequenceHandler)
	
	-- Play a predefined scene
	SequenceHandler:PlayScene("IntroScene")
	
	-- Create a custom sequence
	SequenceHandler:WhenStarted("CustomSequence", function(CompleteSequence)
		-- Start cinematic bars
		SequenceHandler:StartCinematicBars()
		
		-- Lock character movement
		SequenceHandler:LockCharacter()
		
		-- Do your sequence logic here
		task.wait(2)
		
		-- When done, call CompleteSequence
		CompleteSequence()
	end)
	
	-- Call the sequence
	SequenceHandler:CallSequence("CustomSequence", function()
		print("Sequence completed!")
	end)
	```
	
	API:
	- PlayScene(SceneName: string) -> void : Plays a predefined scene with camera movements
	- WhenStarted(SequenceIndex: string, HandlerFn: function) -> void : Registers a sequence handler
	- CallSequence(SequenceIndex: string, WhenCompleted: function) -> void : Executes a sequence
	- StartCinematicBars() -> void : Shows cinematic black bars
	- StopCinematicBars() -> void : Hides cinematic black bars
	- LockCharacter() -> void : Disables character movement
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService('ReplicatedFirst')
local TweenService = game:GetService('TweenService')
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local Mince = require(ReplicatedStorage.Modules.Mince)
local Signal = require(ReplicatedStorage.Modules.Signal)
local Trove = require(ReplicatedStorage.Modules.Trove)
local CameraUtils = require(script.CameraUtils)
local CameraControlManager = require(ReplicatedStorage.Runtime.Source.Controllers.CameraControlManager)

local InterfaceHandler = Mince:Get("InterfaceHandler")
local CharacterController = Mince:Get("CharacterController")

local Skip

local SequenceHandler = {
	Trove = Trove.new(),
	Handlers = {},
	Scenes = {},
	SkipScene = false,
	IsActive = false,
	StopSequence = Signal.new(),
	CurrentThread = nil, -- Add reference to current sequence thread

	TweenInfos = {
		FadeCinematic = TweenInfo.new(1),
	}
}

function SequenceHandler:PlayScene(SceneName : string)
	if SequenceHandler.SkipScene then 
		return 
	end

	local CurrentCamera = Workspace.CurrentCamera
	CurrentCamera.CameraType = Enum.CameraType.Scriptable

	SequenceHandler.Interface.scene.Visible = RunService:IsStudio()
	SequenceHandler.Interface.scene.Text = `scene.{SceneName}`
	local SceneObject = SequenceHandler.Scenes[SceneName]
	if not SceneObject then error(`There is no scene by the name of '{SceneName}'.`) end 

	task.wait() -- Force a yield to allow interruption
	CameraUtils.TweenCameraBeizer(SceneObject.TotalCFrames, SceneObject.Time or 1, function()
		return SequenceHandler.SkipScene
	end)
end

function SequenceHandler:ConnectBeginnings() 
	SequenceHandler.Trove:Add(function() 
		CameraControlManager:ReleaseControl("SequenceHandler")

		local CurrentCamera = Workspace.CurrentCamera
		CurrentCamera.CameraType = Enum.CameraType.Custom
		SequenceHandler.Interface.scene.Visible = false 
		CharacterController:SetEnabled(true) 
		SequenceHandler:StopCinematicBars()
		SequenceHandler.SkipScene = false -- Reset skip flag on cleanup
		if Skip then
			Skip.Enabled = false
		end
	end)
end

function SequenceHandler:StartCinematicBars() 
	SequenceHandler.Interface.CinematicBars.GroupTransparency = 1 
	TweenService:Create(SequenceHandler.Interface.CinematicBars, SequenceHandler.TweenInfos.FadeCinematic, {
		GroupTransparency = 0
	}):Play()
end

function SequenceHandler:StopCinematicBars() 
	TweenService:Create(SequenceHandler.Interface.CinematicBars, SequenceHandler.TweenInfos.FadeCinematic, {
		GroupTransparency = 1
	}):Play()
end

function SequenceHandler:LockCharacter() 
	CharacterController:SetEnabled(false) 
end

function SequenceHandler:WhenStarted(SequenceIndex, SequenceHandlerFn) 
	SequenceHandler.Handlers[SequenceIndex] = SequenceHandlerFn
end

function SequenceHandler:CallSequence(SequenceIndex, WhenCompleted)
	if SequenceHandler.IsActive then 
		return 
	end 

	local ThisHanlder = SequenceHandler.Handlers[SequenceIndex] 
	local WasCompleted, WasEnded = false, false 

	SequenceHandler.SkipScene = false -- Reset skip flag at start

	local EndSequence = function() 
		if WasCompleted or WasEnded then return end 
		WasEnded = true 
		SequenceHandler.IsActive = false
		SequenceHandler.Trove:Clean()

		-- Reset camera and controls
		local CurrentCamera = Workspace.CurrentCamera
		CurrentCamera.CameraType = Enum.CameraType.Custom
		CharacterController:SetEnabled(true)
	end

	local CompleteSequence = function()
		if WasCompleted or WasEnded then return end
		EndSequence();
		WasCompleted = true

		-- Callback for when the sequence is completed
		task.spawn(WhenCompleted) -- Wrap in task.spawn to prevent yielding
	end

	SequenceHandler.IsActive = true

	CameraControlManager:RequestControl(
		"SequenceHandler",
		CameraControlManager.Priority.SEQUENCE
	)

	SequenceHandler:ConnectBeginnings()

	if Skip then
		Skip.Enabled = true
		local TextButton = Skip:FindFirstChild("Main"):FindFirstChild("TextButton")
		if TextButton then
			SequenceHandler.Trove:Add(TextButton.Activated:Connect(function()
				if SequenceHandler.IsActive then
					SequenceHandler.SkipScene = true -- Set skip flag when button is clicked
					SequenceHandler.StopSequence:Fire() -- Fire stop signal

					-- Force kill the sequence thread if it exists
					if SequenceHandler.CurrentThread then
						task.cancel(SequenceHandler.CurrentThread)
						SequenceHandler.CurrentThread = nil
					end

					-- Reset camera and controls immediately
					local CurrentCamera = Workspace.CurrentCamera
					CurrentCamera.CameraType = Enum.CameraType.Custom
					CharacterController:SetEnabled(true)

					task.spawn(CompleteSequence) -- Wrap in task.spawn to prevent yielding
				end
			end))
		end
	end

	-- Run the sequence in a spawned thread so we can cancel it
	SequenceHandler.CurrentThread = task.spawn(function()
		local Success, Result = pcall(ThisHanlder, CompleteSequence)
		if not Success then
			warn(WasCompleted and "ERROR in Sequence ( COMPLETED )" or "ERROR in Sequence ( DID NOT COMPLETED)") 
			warn(Result)
		end
		SequenceHandler.CurrentThread = nil
	end)
end

function SequenceHandler:Setup() 
	SequenceHandler.Interface = InterfaceHandler:GetScreenGui("Sequence")

	InterfaceHandler:NewButton(SequenceHandler.Interface.TextButton).Activated:Connect(function() 
		SequenceHandler:CallSequence("TestSequence", function() 
			warn("Finished! ")
		end)
	end)

	local HandleNew= function(SceneConfig : Configuration) 
		if SceneConfig:IsA("Configuration") then 
			SequenceHandler.Scenes[SceneConfig.Name] = SceneConfig:GetAttributes() 
			local Scene = SequenceHandler.Scenes[SceneConfig.Name] 
			Scene.TotalCFrames = {} 
			local Position = 0 
			repeat Position += 1 
				local FoundOne = false 
				local ThisValue = SceneConfig:FindFirstChild(`Part{Position}`) 
				if ThisValue and ThisValue:IsA("CFrameValue") then 
					table.insert(Scene.TotalCFrames, ThisValue.Value)
					FoundOne = true 
				end
			until not FoundOne 
		end
	end

	for _,SceneConfig : Configuration in ReplicatedStorage.Assets.Scenes:GetDescendants() do  HandleNew(SceneConfig) end
	ReplicatedStorage.Assets.Scenes.DescendantAdded:Connect(HandleNew)
end

return SequenceHandler