local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local LocalPlayer = Players.LocalPlayer 

local ResetEvent = Instance.new("BindableEvent")
local AddedEvent = Instance.new("BindableEvent")
local EquippedEvent = Instance.new("BindableEvent")
local UnequippedEvent = Instance.new("BindableEvent")
local RemovedEvent = Instance.new("BindableEvent")

local CustomBackpack = {
	Backpack = {},  
	BackpackEvents = {}, 

	CurrentEquipped = nil, 

	Reset = ResetEvent.Event,
	Added = AddedEvent.Event,
	Equipped = EquippedEvent.Event,
	Unequipped = UnequippedEvent.Event,
	Removed = RemovedEvent.Event,
}

function CustomBackpack.GiveTool(ThisTool : Tool)
	ThisTool.Parent = CustomBackpack.CurrentBackpackInstance 
end

function CustomBackpack.IterateBackpackItems(IteratorFn) 
	for Position : number, InsertedTool : Tool in CustomBackpack.Backpack do 
		IteratorFn(Position, InsertedTool)
	end
end

function CustomBackpack.SelectSlot(Position) 
	CustomBackpack.SelectItem(CustomBackpack.Backpack[Position])
end

function CustomBackpack.SelectItem(Tool, Position) 
	if Tool and  Tool.Parent ~= nil then 
		local Humanoid : Humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
		local EquippedTool : Tool = LocalPlayer.Character:FindFirstChildWhichIsA("Tool")
		if LocalPlayer:GetAttribute("ViewingCameraAngles") then
			if Humanoid then
				Humanoid:UnequipTools()
			end
			return
		end

		if Humanoid ~= nil then
			if EquippedTool and EquippedTool == Tool then 
				Humanoid:UnequipTools() 
			else 
				Humanoid:EquipTool(Tool)
			end
		end
	end
end


function CustomBackpack.CheckToolInstance(ToolInstance : Tool) 
	if not ToolInstance or not ToolInstance:IsA("Tool") then 
		return 	-- Return if this 'tool' instance is actually a too linstance.s. 
	end 

	local ToolBackpackPosition = table.find(CustomBackpack.Backpack, ToolInstance) 	-- Check to see if the tool is in the backpack 
	if ToolBackpackPosition then 
		if LocalPlayer.Character and  ToolInstance.Parent == LocalPlayer.Character and CustomBackpack.CurrentEquipped ~= ToolInstance then -- Check to see if this tool is now equipped to the character!
			-- Send out a signal if this thing is currently equipped!
			if CustomBackpack.CurrentEquipped ~= nil then 
				local UnequippedPosition = table.find(CustomBackpack.Backpack, CustomBackpack.CurrentEquipped)

				if UnequippedPosition then 
					UnequippedEvent:Fire(UnequippedPosition, CustomBackpack.CurrentEquipped) 
				end
			end

			CustomBackpack.CurrentEquipped = ToolInstance
			EquippedEvent:Fire(ToolBackpackPosition, ToolInstance)
		elseif CustomBackpack.CurrentEquipped and CustomBackpack.CurrentEquipped.Parent ~= CustomBackpack.ThisCharacter then  -- if the current equipped becomes uneqipped 
			-- SEnd out a signal if this thing is currently equipped!
			if CustomBackpack.CurrentEquipped ~= nil then 
				local UnequippedPosition = table.find(CustomBackpack.Backpack, CustomBackpack.CurrentEquipped)

				if UnequippedPosition then 
					UnequippedEvent:Fire(UnequippedPosition, CustomBackpack.CurrentEquipped) 
				end
			end

			CustomBackpack.CurrentEquipped = nil
		end

		return 
	end


	local CachedBackpackRef = CustomBackpack.CurrentBackpackInstance
	local NextToolPosition = #CustomBackpack.Backpack+1


	CustomBackpack.BackpackEvents[ToolInstance] = ToolInstance.AncestryChanged:Connect(function()	
		if ToolInstance.Parent == nil then 
			RemovedEvent:Fire(NextToolPosition,ToolInstance )
			CustomBackpack.Backpack[NextToolPosition] = nil
			CustomBackpack.BackpackEvents[ToolInstance] = nil 
		end
	end)

	CustomBackpack.Backpack[NextToolPosition] = ToolInstance
	AddedEvent:Fire(NextToolPosition, ToolInstance)

	--- Is this now eqipped if so do the callback for it!~
	if ToolInstance.Parent == CustomBackpack.ThisCharacter then 
		CustomBackpack.CurrentEquipped = ToolInstance 
		EquippedEvent:Fire(NextToolPosition, ToolInstance)
	end

end

function CustomBackpack.FindNewBackpack() 
	local Backpack : Backpack = LocalPlayer:WaitForChild("Backpack") 
	if Backpack == CustomBackpack.CurrentBackpackInstance then 
		return 
	end


	for _, BackpackEvent in CustomBackpack.BackpackEvents do 
		BackpackEvent:Disconnect() 
	end

	CustomBackpack.Backpack = {} 
	ResetEvent:Fire()

	CustomBackpack.BackpackEvents.BackpackChildAdded = Backpack.ChildAdded:Connect(CustomBackpack.CheckToolInstance) 
	for _, Child in Backpack:GetChildren() do 
		task.defer(CustomBackpack.CheckToolInstance, Child)  
	end

	CustomBackpack.CurrentBackpackInstance = Backpack
end

function CustomBackpack.NewCharacter(Character : Model) 
	CustomBackpack.ThisCharacter = Character
	CustomBackpack.FindNewBackpack() 
	CustomBackpack.CheckToolInstance(Character:FindFirstChildWhichIsA("Tool"))
	CustomBackpack.ThisCharacter = Character 
	CustomBackpack.BackpackEvents.CharacterChildAdded = Character.ChildAdded:Connect(CustomBackpack.CheckToolInstance)
end

function CustomBackpack.Init() 
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

	if LocalPlayer.Character then task.spawn(CustomBackpack.NewCharacter, LocalPlayer.Character) end
	LocalPlayer.CharacterAdded:Connect(CustomBackpack.NewCharacter)	
end

CustomBackpack.Init() 
return CustomBackpack
