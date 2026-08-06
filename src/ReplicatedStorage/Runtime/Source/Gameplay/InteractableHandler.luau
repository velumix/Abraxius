-- Services // Modules 
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local VRService = game:GetService("VRService")

local LocalPlayer = Players.LocalPlayer 
local Mouse = LocalPlayer:GetMouse()

local Mince = require(ReplicatedStorage.Modules.Mince)
local Signal = require(ReplicatedStorage.Modules.Signal)
local Utility = require(ReplicatedStorage.Modules.Utility)
local Highlight = require(ReplicatedStorage.Modules.Highlight)

local BindManager = Mince:Get("BindManager")
local InterfaceHandler = Mince:Get("InterfaceHandler")

local InteractableHandler = {
	Name = "InteractableHandler",
	HitPartRegistryLookup = {}, 
	HitColliders = {},
	InteractionBindings = {},

	InteractionActive = false,

	MaxDistance = 100,
	MaxCharacterDistance = 10,
	ReachDistance = 0.5,

	ValidInteractionResults = Utility.CreateFuzzyFinder{"Sink", "Pass"},

	ShowsInspectAtMousePosition = true,

	ReadyForRegistry = false,
	RegistryReady = Signal.new(), 
	SelectionBegin = Signal.new(),
	SelectionEnded = Signal.new(), 

	-- Throttle expensive raycasts when cursor/camera are idle
	MinQueryInterval = 0.05,
	LastQueryTime = 0,
	LastMouseX = nil,
	LastMouseY = nil,
	LastCameraCFrame = nil,
}

local Direction = function(Start : Vector3,End : Vector3)
	return (End - Start).Unit
end

local Interactable = {} 
Interactable.__index = Interactable 

function Interactable.new() 
	local NewInteractable = setmetatable({}, Interactable)
	NewInteractable:Init() 
	return NewInteractable
end

function Interactable:Init()
	self.Controls = {}
end

function Interactable:CallControl(Index, ...)
	assert(self.Controls[Index], `Invalid Control {Index}`)
	return self.Controls[Index](...)
end

function Interactable:Control(Index, Method) 
	assert(type(Method) == "function", "Interactable:Control(Index, [[FUNCTION]]) must be a function!")
	self.Controls[Index] = Method
end

function Interactable:HasControlIndex(Index) 
	return self.Controls[Index] ~= nil  
end

function InteractableHandler.newInteractable(HoverName : string, HitPartOrParts : {Part} | Part, HighlightPart) 
	local ThisInteractable = Interactable.new() 
	ThisInteractable.PartToHighlight = HighlightPart
	ThisInteractable.HoverName = HoverName 

	if typeof(HitPartOrParts) == "table" then 
		for _, BasePart in HitPartOrParts do 
			InteractableHandler:RegisterNewHitPartWithInteractable(BasePart, ThisInteractable)
		end

		ThisInteractable.BackupPart = HitPartOrParts[1]
	elseif typeof(HitPartOrParts) == "Instance" and HitPartOrParts:IsA("BasePart") then 
		InteractableHandler:RegisterNewHitPartWithInteractable(HitPartOrParts, ThisInteractable)

		ThisInteractable.BackupPart = HitPartOrParts
	end

	return ThisInteractable
end


function InteractableHandler:Update(DeltaTime : number) 
	if InteractableHandler.InteractionActive then return end

	local now = os.clock()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local CameraPosition = camera.CFrame.Position
	local RaycastResult
	local MouseVec

	if VRService.VREnabled and VRService:GetUserCFrameEnabled(Enum.UserCFrame.RightHand) then
		local rightHandCFrame = VRService:GetUserCFrame(Enum.UserCFrame.RightHand)
		CameraPosition = rightHandCFrame.Position
		local RayDirection = rightHandCFrame.LookVector

		RaycastResult = game.Workspace:Spherecast(CameraPosition, 
			InteractableHandler.ReachDistance, 
			RayDirection * InteractableHandler.MaxDistance, 
			InteractableHandler.InteractParams
		)
		MouseVec = Vector2.new(0, 0)
	else
		local mouseX, mouseY = Mouse.X, Mouse.Y
		local cameraCFrame = camera and camera.CFrame
		local mouseMoved = InteractableHandler.LastMouseX == nil
			or math.abs(mouseX - InteractableHandler.LastMouseX) > 1
			or math.abs(mouseY - InteractableHandler.LastMouseY) > 1
		local cameraMoved = false
		if InteractableHandler.LastCameraCFrame and cameraCFrame then
			cameraMoved = (cameraCFrame.Position - InteractableHandler.LastCameraCFrame.Position).Magnitude > 0.05
		end

		if not mouseMoved and not cameraMoved and (now - InteractableHandler.LastQueryTime) < InteractableHandler.MinQueryInterval then
			return
		end
		InteractableHandler.LastQueryTime = now
		InteractableHandler.LastMouseX = mouseX
		InteractableHandler.LastMouseY = mouseY
		InteractableHandler.LastCameraCFrame = cameraCFrame

		local MousePosition = Mouse.Hit.Position
		local MouseDirection = Direction(CameraPosition, MousePosition) 

		RaycastResult = game.Workspace:Spherecast(CameraPosition, 
			InteractableHandler.ReachDistance, 
			MouseDirection * InteractableHandler.MaxDistance, 
			InteractableHandler.InteractParams
		)

		MouseVec = Vector2.new(Mouse.X, Mouse.Y)
	end

	local ActualHitInstance = RaycastResult and RaycastResult.Instance

	if ActualHitInstance and InteractableHandler.Target ~= ActualHitInstance and InteractableHandler.HumanoidRootPart then
		local CharacterDistance = (InteractableHandler.HumanoidRootPart.Position - RaycastResult.Position).Magnitude
		if CharacterDistance > InteractableHandler.MaxCharacterDistance then return end 
		local Interactable = InteractableHandler.HitPartRegistryLookup[ActualHitInstance]

		if Interactable then 
			if InteractableHandler.ShowsInspectAtMousePosition then 
				InteractableHandler.Inspect.Position = UDim2.fromOffset(MouseVec.X, MouseVec.Y)
			end


			if Interactable:HasControlIndex("OnHover") then 
				local HoverResult, Alt1 = Interactable:CallControl("OnHover") 

				if not HoverResult then 
					InteractableHandler:Unselect() 
					InteractableHandler:InvalidateNew(Interactable, Alt1) 
					return 
				end

				if HoverResult == "Unselect" then 
					InteractableHandler:Unselect()
					InteractableHandler:ClearInvalidation() 
				end
			end

			-- Current interactable!
			if Interactable == InteractableHandler.CurrentInteractable then 
				return 
			end

			InteractableHandler:SelectNew(Interactable)
		end
	else 
		InteractableHandler:Unselect()
		InteractableHandler:ClearInvalidation() 
	end
end


function InteractableHandler:InvalidateNew(Interactable, Alt1) 
	if InteractableHandler.CurrentInvalidation ~= Interactable then 
		InteractableHandler.CurrentInvalidation = Interactable 
		InteractableHandler.Inspect.Visible = true 
		InteractableHandler.Inspect.MainText.Text = Alt1 or Interactable.HoverName or "Interactable.HoverName"
		InteractableHandler.Inspect.SubText.Text = ""

		-- Do Part 2 
		InteractableHandler.InvalidHighlight:Set(Interactable.PartToHighlight or Interactable.BackupPart)
	end
end

function InteractableHandler:SelectNew(Interactable) 
	if InteractableHandler.CurrentInteractable ~= Interactable then 
		InteractableHandler.CurrentInteractable = Interactable 
		InteractableHandler.Inspect.Visible = true 
		InteractableHandler.Inspect.MainText.Text = Interactable.HoverName or "Interactable.HoverName"
		InteractableHandler.Inspect.SubText.Text = Interactable.HoverMetaText or ""

		-- Do Part 2 
		InteractableHandler.Highlight:Set(Interactable.PartToHighlight or Interactable.BackupPart)
		InteractableHandler.SelectionBegin:Fire(InteractableHandler.CurrentInteractable)

		InteractableHandler:ClearInvalidation() 
	end
end

function InteractableHandler:ClearInvalidation() 
	if InteractableHandler.CurrentInvalidation then
		InteractableHandler.Inspect.Visible = false
		InteractableHandler.CurrentInvalidation = nil 
		InteractableHandler.InvalidHighlight:Clear() 
	end
end

function InteractableHandler:Unselect() 
	if InteractableHandler.CurrentInteractable then 
		InteractableHandler.Highlight:Clear() 
		InteractableHandler.Inspect.Visible = false

		InteractableHandler.SelectionEnded:Fire(InteractableHandler.CurrentInteractable)
		InteractableHandler.CurrentInteractable = nil
	end
end

function InteractableHandler:BeginInteractionWithSelection() 
	local Interactable = InteractableHandler.CurrentInteractable
	InteractableHandler:Unselect()
	InteractableHandler.InteractionActive = true

	local Success, Failure = pcall(function() 
		return Interactable:CallControl("Interact",function() 
			InteractableHandler.InteractionActive = false
		end)    
	end) 

	if not Success then 
		warn(`Error while interacting automatically ended!`)
		warn(Failure)

		InteractableHandler.InteractionActive = false
	end
end


function InteractableHandler:DestroyReigstry(HitPart : BasePart) 
	if not InteractableHandler.ReadyForRegistry then InteractableHandler.RegistryReady:Wait() end 
	assert(HitPart and HitPart:IsA("BasePart"), "HitPart is required.")

	local Index = table.find(InteractableHandler.HitColliders, HitPart)
	if Index then table.remove(InteractableHandler.HitColliders, Index) end

	InteractableHandler.InteractParams.FilterDescendantsInstances = InteractableHandler.HitColliders
	InteractableHandler.HitPartRegistryLookup[HitPart] = nil 
end

function InteractableHandler:RegisterNewHitPartWithInteractable(HitPart : BasePart, Interactable)
	if not InteractableHandler.ReadyForRegistry then InteractableHandler.RegistryReady:Wait() end 
	assert(HitPart and HitPart:IsA("BasePart"), "HitPart is required.")
	assert(typeof(Interactable) == "table", `Interactable Must be an 'Interactable'.`)  
	HitPart.CanQuery = true 
	HitPart.CanTouch = false 
	HitPart.Destroying:Once(function() 
		InteractableHandler:DestroyReigstry(HitPart)
	end)

	table.insert(InteractableHandler.HitColliders, HitPart)
	InteractableHandler.InteractParams.FilterDescendantsInstances = InteractableHandler.HitColliders
	InteractableHandler.HitPartRegistryLookup[HitPart] = Interactable 
end

function InteractableHandler:NewInteractableBlocker(HitPart)
	assert(HitPart and HitPart:IsA("BasePart"), "HitPart is required.")
	InteractableHandler.HitPartRegistryLookup[HitPart] = false 
end

function InteractableHandler:BindToInteract(Priority : number, CallbackFn) 
	local InteractionBinding = {
		Priority = Priority, 
		CallbackFn = CallbackFn
	}

	table.insert(InteractableHandler.InteractionBindings, InteractionBinding)
	table.sort(InteractableHandler.InteractionBindings, function(BindingA, BindingB) 
		return BindingA.Priority < BindingB.Priority
	end)
end

function InteractableHandler:TriggerInteraction() 
	if InteractableHandler.InteractionActive then 
		return "Sink"
	end 

	if InteractableHandler.CurrentInteractable then 
		InteractableHandler:BeginInteractionWithSelection() 
		return "Sink"
	end

	return "Pass"
end


function InteractableHandler:Interact() 
	for _, InteractionBinding in InteractableHandler.InteractionBindings do 
		local BindingResult = InteractionBinding.CallbackFn() 
		assert(InteractableHandler.ValidInteractionResults[BindingResult], `BindingResult is Either 'Sink' or 'Pass'. Got '{BindingResult or "None"}'`)
		if BindingResult == "Sink" then return end 
		-- TO-DO 
		-- Maybe PCALL CallbackFn() and automatically pass if fail?
	end
end


function InteractableHandler:NewCharacter(Character : Model) 
	local HumanoidRootPart : BasePart = Character:WaitForChild("HumanoidRootPart")

	InteractableHandler.HumanoidRootPart = HumanoidRootPart
end

function InteractableHandler:__SetupConnections() 
	BindManager:Get("UnifiedInteract").OnAction:Connect(function(InputState)
		if InputState == Enum.UserInputState.Begin then 
			InteractableHandler:Interact()
		end
	end)

	UserInputService.TouchTapInWorld:Connect(function(pv,pbui)
		if pbui then return end 
		InteractableHandler:Interact()
	end)
end

function InteractableHandler:__SetupStuffs() 
	local InteractParams = RaycastParams.new() 
	InteractParams.FilterType = Enum.RaycastFilterType.Include
	InteractableHandler.InteractParams = InteractParams 

	InteractableHandler.Highlight = Highlight.newSet{
		DoesFlash = false,
		Color = Color3.new(1,1,1)
	} 

	InteractableHandler.InvalidHighlight = Highlight.newSet{
		DoesFlash = false, 
		Color = Color3.new(1,0,0)
	} 

	InteractableHandler.ReadyForRegistry = true 
	InteractableHandler.RegistryReady:Fire()  

	if LocalPlayer.Character then InteractableHandler:NewCharacter(LocalPlayer.Character) end 
	LocalPlayer.CharacterAdded:Connect(function(Character) 
		InteractableHandler:NewCharacter(Character)
	end)
end

function InteractableHandler:Setup()  
	InteractableHandler.MainPriority = InterfaceHandler:GetScreenGui("MainPriority", true) 
	InteractableHandler.Inspect = InteractableHandler.MainPriority.Inspect 

	InteractableHandler:__SetupStuffs()
	InteractableHandler:__SetupConnections()

	InteractableHandler:BindToInteract(0, function() 
		return InteractableHandler:TriggerInteraction() 
	end)

	RunService.Heartbeat:Connect(function(DeltaTime)
		InteractableHandler:Update(DeltaTime)
	end)
end

return InteractableHandler