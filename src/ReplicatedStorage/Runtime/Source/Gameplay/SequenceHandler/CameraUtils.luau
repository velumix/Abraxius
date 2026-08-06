local ReplicatedStorage = game:GetService("ReplicatedStorage") 
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Mince = require(ReplicatedStorage.Modules.Mince) 

local SequenceHandler = Mince:Get("SequenceHandler") 


local CameraUtils = {} 

local function tweenCameraBetweenPoints(ACFrame, BCFrame, t, shouldStop)
	local CurrentCamera = Workspace.CurrentCamera 
	local start = time()
	local connection

	-- Create a Promise-like completion mechanism
	local completed = false
	local function cleanup()
		if connection then
			connection:Disconnect()
			connection = nil
		end
		completed = true
	end

	connection = RunService.RenderStepped:Connect(function()
		local now = time()
		local elapsed = now - start

		if shouldStop and shouldStop() then
			CurrentCamera.CFrame = BCFrame -- Jump to end position
			cleanup()
			return
		end

		if elapsed >= t then
			CurrentCamera.CFrame = BCFrame
			cleanup()
			return
		end

		local alpha = elapsed / t
		CurrentCamera.CFrame = ACFrame:Lerp(BCFrame, alpha)
	end)

	-- Wait for completion or interruption
	while not completed do
		RunService.Heartbeat:Wait()
	end
end

local function bezier(points, t)
	local temp = points
	while #temp > 1 do
		local newTemp = {}
		for i = 1, #temp - 1 do
			newTemp[i] = temp[i]:Lerp(temp[i + 1], t)
		end
		temp = newTemp
	end
	return temp[1]
end

local function tweenCameraBezier(controlPoints, duration, shouldStop)
	local CurrentCamera = Workspace.CurrentCamera
	local start = time()
	local connection
	local stopConnection

	-- Create a Promise-like completion mechanism
	local completed = false
	local function cleanup()
		if connection then
			connection:Disconnect()
			connection = nil
		end
		if stopConnection then
			stopConnection:Disconnect()
			stopConnection = nil
		end
		completed = true
	end

	-- Listen for stop signal
	stopConnection = SequenceHandler.StopSequence:Connect(function()
		CurrentCamera.CFrame = controlPoints[#controlPoints]
		cleanup()
	end)

	connection = RunService.RenderStepped:Connect(function()
		local now = time()
		local elapsed = now - start

		if shouldStop and shouldStop() then
			CurrentCamera.CFrame = controlPoints[#controlPoints]
			cleanup()
			return
		end

		if elapsed >= duration then
			CurrentCamera.CFrame = controlPoints[#controlPoints]
			cleanup()
			return
		end

		local t = math.min(elapsed / duration, 1)
		CurrentCamera.CFrame = bezier(controlPoints, t)
	end)

	-- Wait for completion or interruption
	while not completed do
		RunService.Heartbeat:Wait()
	end
end

CameraUtils.TweenCameraBeizer = tweenCameraBezier
CameraUtils.TweenCameraAB = tweenCameraBetweenPoints 

return CameraUtils