--[[
TheNexusAvenger

Wrapper for Nexus VR Backback to work with two hands.
Make sure to test your game with this backpack. There may be compatibility issues with having more than 1 tool in a character.
--]]
--!strict

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CharacterBackpack = require(script.Parent:WaitForChild("NexusVRBackpack"):WaitForChild("NexusVRBackpack"):WaitForChild("CharacterBackpack"))

local TwoHandNexusVRBackpack = {
	UseKeyboardTestInputs = false,
	CurrentBackpacks = {} :: {CharacterBackpack.CharacterBackpack},
	CurrentCharacterEvents = {} :: {RBXScriptConnection},
	ToolEvents = {} :: {[Player]: {[Tool]: {RBXScriptConnection}}},
}

local EquipVRToolEvent = script:FindFirstChild("EquipVRTool") :: RemoteEvent
if not EquipVRToolEvent then
	if RunService:IsClient() then
		EquipVRToolEvent = script:WaitForChild("EquipVRTool") :: RemoteEvent
	else
		local NewEquipVRToolEvent = Instance.new("RemoteEvent")
		NewEquipVRToolEvent.Name = "EquipVRTool"
		NewEquipVRToolEvent.Parent = script
		EquipVRToolEvent = NewEquipVRToolEvent
	end
end



--[[
Returns the grip for a given tool.
--]]
function TwoHandNexusVRBackpack:GetGrip(Tool: Tool, UserCFrame: Enum.UserCFrame): CFrame
	if UserCFrame == Enum.UserCFrame.LeftHand then
		return CFrame.new(0, 0, -2 * Tool.Grip.Z) * Tool.Grip
	end
	return Tool.Grip
end

--[[
Updates the tool grips for a character.
--]]
function TwoHandNexusVRBackpack:UpdateGrips(Character: Model): ()
	for _, Tool in Character:GetChildren() do
		--Get the parts of the tools.
		if not Tool:IsA("Tool") then continue end
		local Handle = Tool:FindFirstChild("Handle") :: BasePart
		if not Handle then continue end
		local UserCFrame = Tool:GetAttribute("Hand") or Enum.UserCFrame.RightHand
		
		--Get the parts of the character.
		local Hand = Character:FindFirstChild(UserCFrame == Enum.UserCFrame.LeftHand and "LeftHand" or "RightHand") :: BasePart
		local OppositeHand = Character:FindFirstChild(UserCFrame == Enum.UserCFrame.LeftHand and "RightHand" or "LeftHand") :: BasePart
		if not Hand then continue end
		local GripAttachment = Hand:FindFirstChild(UserCFrame == Enum.UserCFrame.LeftHand and "LeftGripAttachment" or "RightGripAttachment") :: Attachment
		if not GripAttachment then continue end
		
		--Clear any welds in the opposite hand.
		if OppositeHand then
			for _, GripWeld in OppositeHand:GetChildren() do
				if not GripWeld:IsA("JointInstance") then continue end
				if (GripWeld :: JointInstance).Part1 ~= Handle then continue end
				GripWeld:Destroy()
			end
		end
		
		--Create or update the grip weld.
		local ExistingHandGripWeld: JointInstance? = nil
		for _, GripWeld in Hand:GetChildren() do
			if not GripWeld:IsA("JointInstance") then continue end
			if (GripWeld :: JointInstance).Part1 ~= Handle then continue end
			ExistingHandGripWeld = GripWeld :: JointInstance
			break
		end
		if not ExistingHandGripWeld then
			local NewHandGripWeld = Instance.new("Weld")
			NewHandGripWeld.Name = (UserCFrame == Enum.UserCFrame.LeftHand and "Left" or "Right").."Grip"
			NewHandGripWeld.Part0 = Hand
			NewHandGripWeld.Part1 = Handle
			NewHandGripWeld.Parent = Hand
			ExistingHandGripWeld = NewHandGripWeld
		end
		local HandGripWeld = ExistingHandGripWeld :: JointInstance
		HandGripWeld.C0 = GripAttachment.CFrame
		HandGripWeld.C1 = self:GetGrip(Tool, UserCFrame)
	end
end

--[[
Unequips all tool for a character for a given hand.
--]]
function TwoHandNexusVRBackpack:UnequipTools(Character: Model, UserCFrame: Enum.UserCFrame, ExcludedTool: Tool?): ()
	local Player = Players:GetPlayerFromCharacter(Character)
	for _, Tool in Character:GetChildren() do
		if Tool == ExcludedTool then continue end
		if not Tool:IsA("Tool") then continue end
		local ToolUserCFrame = Tool:GetAttribute("Hand") or Enum.UserCFrame.RightHand
		if ToolUserCFrame ~= UserCFrame then continue end
		
		--Parent the tool.
		Tool.Parent = Players:GetPlayerFromCharacter(Character):FindFirstChildOfClass("Backpack")
		Tool:SetAttribute("Hand", nil)
		if Player and self.ToolEvents[Player] and self.ToolEvents[Player][Tool] then
			for _, Event in self.ToolEvents[Player][Tool] do
				Event:Disconnect()
			end
			self.ToolEvents[Player][Tool] = nil
		end
		
		--Clear the welds.
		local Handle = Tool:FindFirstChild("Handle") :: BasePart
		local Hand = Character:FindFirstChild((UserCFrame == Enum.UserCFrame.LeftHand and "Left" or "Right").."Grip")
		if not Handle or not Hand then continue end
		for _, GripWeld in Hand:GetChildren() do
			if not GripWeld:IsA("JointInstance") then continue end
			if (GripWeld :: JointInstance).Part1 ~= Handle then continue end
			GripWeld:Destroy()
		end
	end
end

--[[
Equips a tool for a character.
--]]
function TwoHandNexusVRBackpack:EquipTool(Tool: Tool, Character: Model, UserCFrame: Enum.UserCFrame): ()
	--Unequip the current tools for the hand.
	self:UnequipTools(Character, UserCFrame, Tool)
	
	--Parent the tool.
	Tool:SetAttribute("Hand", UserCFrame)
	Tool.Parent = Character
	if RunService:IsClient() then
		EquipVRToolEvent:FireServer(Tool, UserCFrame)
	end
	
	--Update the grip.
	local Player = Players:GetPlayerFromCharacter(Character)
	self:UpdateGrips(Character)
	if Player then
		if not self.ToolEvents[Player] then
			self.ToolEvents[Player] = {}
		end
		
		local ToolEvents = {}
		self.ToolEvents[Player][Tool] = ToolEvents
		table.insert(ToolEvents, Tool:GetPropertyChangedSignal("Grip"):Connect(function()
			self:UpdateGrips(Character)
		end))
		table.insert(ToolEvents, Tool.AncestryChanged:Connect(function()
			if Tool.Parent == Character then return end
			Tool:SetAttribute("Hand", nil)
		end))
	end
end

--[[
Replaces the Humanoid of a CharacterBackpack with a custom version.
The behavior is specific to V.1.0.X where only EquipTool and UnequipTools are used.
--]]
function TwoHandNexusVRBackpack:ReplaceHumanoid(Backpack: CharacterBackpack.CharacterBackpack, Character: Model, UserCFrame: Enum.UserCFrame): ()
	local VRBackpack = self
	local ToolHumanoidShim = {}
	function ToolHumanoidShim:EquipTool(Tool: Tool): ()
		VRBackpack:EquipTool(Tool, Character, UserCFrame)
	end

	function ToolHumanoidShim:UnequipTools(): ()
		VRBackpack:UnequipTools(Character, UserCFrame)
	end
	(Backpack :: any).Humanoid = ToolHumanoidShim
end

--[[
Creates a backpack for the current character.
--]]
function TwoHandNexusVRBackpack:SetUpCharacter(Character: Model): ()
	if not Character then return end
	
	--Clear the existing backpcks.
	for _, Backpack in self.CurrentBackpacks do
		Backpack:Destroy()
	end
	self.CurrentBackpacks = {}
	for _, Event in self.CurrentCharacterEvents do
		Event:Disconnect()
	end
	self.CurrentCharacterEvents = {}
	
	--Create the backpacks.
	local LeftHandBackpack = CharacterBackpack.new(Character)
	LeftHandBackpack:SetUserCFrame(Enum.UserCFrame.LeftHand)
	LeftHandBackpack:SetKeyCode(self.UseKeyboardTestInputs and Enum.KeyCode.Q or Enum.KeyCode.ButtonL3)
	self:ReplaceHumanoid(LeftHandBackpack, Character, Enum.UserCFrame.LeftHand)
	table.insert(self.CurrentBackpacks, LeftHandBackpack)

	local RightHandBackpack = CharacterBackpack.new(Character)
	RightHandBackpack:SetUserCFrame(Enum.UserCFrame.RightHand)
	RightHandBackpack:SetKeyCode(self.UseKeyboardTestInputs and Enum.KeyCode.E or Enum.KeyCode.ButtonR3)
	self:ReplaceHumanoid(RightHandBackpack, Character, Enum.UserCFrame.RightHand)
	table.insert(self.CurrentBackpacks, RightHandBackpack)
	
	--Connect grips being added.
	local RightHand = Character:WaitForChild("RightHand")
	table.insert(self.CurrentCharacterEvents, RightHand.ChildAdded:Connect(function(GripWeld)
		if not GripWeld:IsA("JointInstance") then return end
		local Handle = GripWeld.Part1 :: BasePart
		if not Handle then return end
		local Tool = Handle.Parent
		if not Tool or not Tool:IsA("Tool") then return end
		task.defer(function()
			self:UpdateGrips(Character)
		end)
	end))
end


--[[
Enables a test version of Nexus VR Backpack that works outside of VR.
--]]
function TwoHandNexusVRBackpack:EnableNonVRTesting()
	if UserInputService.VREnabled then return end
	self.UseKeyboardTestInputs = true
	
	(CharacterBackpack :: any).GetBackpackCFrame = function(self)
		return Workspace.CurrentCamera.CFrame * CFrame.new(self.UserCFrame == Enum.UserCFrame.RightHand and 1 or -1, 0, -2)
	end

	(CharacterBackpack :: any).GetHandPosition = function(self)
		--The following is long because the API to test with is in world space.
		--Since the backpack is a SurfaceGui in 3D space, this is required to translate the mouse into 3D space relative to the backpack.
		local BackpackSize = self.Backpack.Part.Size :: Vector3
		local BackpackCFrame = self:GetBackpackCFrame() :: CFrame
		local MouseLocation = UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
		local UpperLeftCorner = Workspace.CurrentCamera:WorldToScreenPoint((BackpackCFrame * CFrame.new(-BackpackSize.X / 2, BackpackSize.Y / 2, 0)).Position)
		local BottomRightCorner = Workspace.CurrentCamera:WorldToScreenPoint((BackpackCFrame * CFrame.new(BackpackSize.X / 2, -BackpackSize.Y / 2, 0)).Position)
		local RelativeX = (MouseLocation.X - UpperLeftCorner.X) / (BottomRightCorner.X - UpperLeftCorner.X)
		local RelativeY = (MouseLocation.Y - UpperLeftCorner.Y) / (BottomRightCorner.Y - UpperLeftCorner.Y)
		return (BackpackCFrame * CFrame.new(BackpackSize.X * (RelativeX - 0.5), BackpackSize.Y * (0.5 - RelativeY), 0)).Position
	end
end

--[[
Sets up the two-handed backpack.
--]]
function TwoHandNexusVRBackpack:SetUp(): ()
	if RunService:IsClient() then
		--Disable loading the backpack if not in VR.
		if not UserInputService.VREnabled and not self.UseKeyboardTestInputs then
			return
		end
		
		--Connect creating the backpack.
		Players.LocalPlayer.CharacterAdded:Connect(function(Character)
			self:SetUpCharacter(Character)
		end)
		task.spawn(function()
			self:SetUpCharacter(Players.LocalPlayer.Character)
		end)
		
		--Load the Nexus VR Character Model API.
		task.spawn(function()
			local NexusVRCharacterModel = require(ReplicatedStorage:WaitForChild("NexusVRCharacterModel", 10 ^ 99)) :: any
			if not NexusVRCharacterModel.Api then
				warn("Nexus VR Character Model is loaded by no API is found. This was added in V.2.4.0. Inputs on the right controller won't be disabled when interacting with the backpack.")
				return
			end
			(CharacterBackpack :: any).NexusVRCharacterModelControllerApi = NexusVRCharacterModel.Api:WaitFor("Controller")
		end)
	else
		--Connect the weld event.
		EquipVRToolEvent.OnServerEvent:Connect(function(Player: Player, Tool: Tool, UserCFrame: Enum.UserCFrame)
			if not Tool or not UserCFrame then return end
			local Backpack = Player:FindFirstChildOfClass("Backpack") :: Backpack
			local Character = Player.Character :: Model
			if not Backpack or not Character then return end
			if not Tool:IsDescendantOf(Backpack) and not Tool:IsDescendantOf(Character) then return end
			self:EquipTool(Tool, Character, UserCFrame)
		end)
		
		--Connect clearing events.
		Players.PlayerRemoving:Connect(function(Player)
			if not self.ToolEvents[Player] then return end
			for _, Events in self.ToolEvents[Player] do
				for _, Event in Events do
					Event:Disconnect()
				end
			end
			self.ToolEvents[Player] = nil
		end)
	end
end



return TwoHandNexusVRBackpack