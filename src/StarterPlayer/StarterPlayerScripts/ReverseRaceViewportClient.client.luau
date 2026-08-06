-- Shows the current Reverse Race target model briefly for hunters who join mid-hunt.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local viewportRemote = remotes:WaitForChild("ReverseRaceViewport")

local hud = playerGui:WaitForChild("Hud")
local panel = hud:WaitForChild("ReverseRaceViewport")
local viewportFrame = panel:WaitForChild("ViewportFrame")
local titleLabel = panel:FindFirstChild("Title")

local activeToken = 0
local currentWorld = nil
local currentCamera = nil

local function clearViewport()
	if currentWorld then
		currentWorld:Destroy()
		currentWorld = nil
	end
	if currentCamera then
		currentCamera:Destroy()
		currentCamera = nil
	end
	viewportFrame:ClearAllChildren()
	viewportFrame.CurrentCamera = nil
end

local function hide()
	activeToken += 1
	panel.Visible = false
	clearViewport()
end

local function prepareClone(sourceModel)
	if not sourceModel or not sourceModel:IsA("Model") then
		return nil
	end

	local clone = sourceModel:Clone()
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("BaseScript") or d:IsA("Highlight") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	return clone
end

local function frameModel(model)
	local cf, size = model:GetBoundingBox()
	local maxDim = math.max(size.X, size.Y, size.Z, 1)
	local focus = cf.Position + Vector3.new(0, size.Y * 0.04, 0)
	local distance = math.max(5, maxDim * 1.65)

	local camera = Instance.new("Camera")
	camera.Name = "ReverseRaceViewportCamera"
	camera.FieldOfView = 35
	camera.CFrame = CFrame.lookAt(focus + Vector3.new(distance * 0.28, size.Y * 0.08, distance), focus)
	camera.Parent = viewportFrame
	viewportFrame.CurrentCamera = camera
	currentCamera = camera
end

local function show(payload)
	local sourceModel = payload.model
	local clone = prepareClone(sourceModel)
	if not clone then
		hide()
		return
	end

	activeToken += 1
	local token = activeToken
	clearViewport()

	local world = Instance.new("WorldModel")
	world.Name = "ReverseRaceViewportWorld"
	world.Parent = viewportFrame
	currentWorld = world

	clone.Parent = world
	frameModel(clone)

	if titleLabel and titleLabel:IsA("TextLabel") then
		local targetName = payload.title or payload.name or "Target Hider"
		titleLabel.Text = tostring(targetName)
	end

	panel.Visible = true

	local duration = tonumber(payload.duration) or 12
	task.delay(duration, function()
		if activeToken == token then
			hide()
		end
	end)
end

panel.Visible = false
clearViewport()

viewportRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or payload.show == false then
		hide()
		return
	end
	show(payload)
end)
