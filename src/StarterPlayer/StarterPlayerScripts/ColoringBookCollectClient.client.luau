local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local ColoringBookConfig = require(ReplicatedStorage:WaitForChild("ColoringBookConfig"))

local TAG = "ColoringBookCollectClick"

local GameRemotes = ReplicatedStorage:WaitForChild("GameRemotes")
local collectRemote = GameRemotes:WaitForChild("ColoringBookCollectRequest")
local ColoringBookUpdate = GameRemotes:WaitForChild("ColoringBookUpdate")
local ColoringBookRequest = GameRemotes:WaitForChild("ColoringBookRequest")
local ColoringBookFriendFound = GameRemotes:WaitForChild("ColoringBookFriendFound")

local collectSoundTemplate = Instance.new("Sound")
collectSoundTemplate.Name = "ColoringBookCollectSound"
collectSoundTemplate.SoundId = "rbxassetid://131390520971848"
collectSoundTemplate.SoundGroup = SoundService:FindFirstChild("SFX")
collectSoundTemplate.Parent = SoundService
local function playCollectSound()
	local s = collectSoundTemplate:Clone()
	s.Parent = SoundService
	s:Play()
	task.delay((s.TimeLength > 0 and s.TimeLength or 2) + 0.1, function()
		if s then s:Destroy() end
	end)
end

local freecamScript = playerGui:WaitForChild("FreecamEngine"):WaitForChild("FreecamScript")
local function freecamActive()
	return freecamScript:GetAttribute("FreecamEnabled") == true
end

local booksData = {}
local connected = setmetatable({}, { __mode = "k" })

local function activeMapName()
	local am = Workspace:FindFirstChild("ActiveMap")
	return am and am:GetAttribute("MapName")
end

local function bookModelOf(clickDetector)
	local collision = clickDetector.Parent
	local model = collision and collision.Parent
	if model and model:IsA("Model") then
		return model
	end
	return nil
end

local function isCollected(model)
	local mapName = activeMapName()
	if not mapName then
		return false
	end
	local page = model.Parent
	local pageId = page and page.Name
	local mapData = booksData[mapName]
	local entry = mapData and pageId and mapData[pageId]
	return (entry and entry.parts and entry.parts[model.Name]) == true
end

local function setBookHidden(model, hidden)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p.Name ~= "Collision" then
			p.LocalTransparencyModifier = hidden and 1 or 0
		elseif p:IsA("ClickDetector") then
			p.MaxActivationDistance = hidden and 0 or ColoringBookConfig.CLICK_DISTANCE
		end
	end
end

local function applyHiding()
	for _, cd in ipairs(CollectionService:GetTagged(TAG)) do
		local model = bookModelOf(cd)
		if model then
			setBookHidden(model, isCollected(model))
		end
	end
end

local function hook(clickDetector)
	if not clickDetector:IsA("ClickDetector") or connected[clickDetector] then
		return
	end
	connected[clickDetector] = true
	local model = bookModelOf(clickDetector)
	if model then
		setBookHidden(model, isCollected(model))
	end
	clickDetector.MouseClick:Connect(function()
		if freecamActive() then
			return
		end
		local m = bookModelOf(clickDetector)
		if not m or isCollected(m) then
			return
		end
		setBookHidden(m, true)
		playCollectSound()
		collectRemote:FireServer(m)
	end)
end

for _, cd in ipairs(CollectionService:GetTagged(TAG)) do
	hook(cd)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(hook)

local mouse = player:GetMouse()
local hookedTools = setmetatable({}, { __mode = "k" })

local function tryToolCollect()
	if freecamActive() then
		return
	end
	local target = mouse.Target
	if not target or target.Name ~= "Collision" then
		return
	end
	local cd = target:FindFirstChildOfClass("ClickDetector")
	if not cd or not connected[cd] or cd.MaxActivationDistance <= 0 then
		return
	end
	local model = bookModelOf(cd)
	if not model or isCollected(model) then
		return
	end
	local char = player.Character
	local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
	if head and (target.Position - head.Position).Magnitude > cd.MaxActivationDistance then
		return
	end
	setBookHidden(model, true)
	playCollectSound()
	collectRemote:FireServer(model)
end

local function hookTool(tool)
	if not tool:IsA("Tool") or hookedTools[tool] then
		return
	end
	hookedTools[tool] = true
	tool.Activated:Connect(tryToolCollect)
end

local function hookCharacterTools(character)
	for _, c in ipairs(character:GetChildren()) do
		hookTool(c)
	end
	character.ChildAdded:Connect(hookTool)
end

if player.Character then
	hookCharacterTools(player.Character)
end
player.CharacterAdded:Connect(hookCharacterTools)

ColoringBookUpdate.OnClientEvent:Connect(function(data)
	booksData = (data and data.books) or {}
	applyHiding()
end)

ColoringBookFriendFound.OnClientEvent:Connect(function()
	playCollectSound()
end)

local function watchActiveMap(inst)
	if inst.Name ~= "ActiveMap" then
		return
	end
	inst:GetAttributeChangedSignal("MapName"):Connect(applyHiding)
	task.defer(applyHiding)
end

Workspace.ChildAdded:Connect(watchActiveMap)
local existingActive = Workspace:FindFirstChild("ActiveMap")
if existingActive then
	watchActiveMap(existingActive)
end

ColoringBookRequest:FireServer()
