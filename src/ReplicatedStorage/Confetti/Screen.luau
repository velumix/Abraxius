local Confetti = {}
Confetti.__index = Confetti

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local confettiShapes = {"Square", "Circle", "Triangle", "Diamond"}
local baseColors = {
	Color3.fromRGB(255, 75, 75),
	Color3.fromRGB(75, 255, 75),
	Color3.fromRGB(75, 75, 255),
	Color3.fromRGB(255, 255, 75),
	Color3.fromRGB(255, 75, 255),
	Color3.fromRGB(75, 255, 255)
}

function Confetti.new()
	local self = setmetatable({}, Confetti)
	self.ActiveConfetti = 0
	self.activeEmitters = 0
	return self
end

function Confetti:CreateConfettiPiece(spawnPos)
	local confetti = Instance.new("Frame")
	confetti.Name = "ConfettiPiece"
	local size = math.random(24, 36)
	confetti.Size = UDim2.new(0, size, 0, size)
	confetti.BackgroundTransparency = 1
	confetti.BorderSizePixel = 0
	confetti.AnchorPoint = Vector2.new(0.5, 0.5)

	if spawnPos and typeof(spawnPos) == "UDim2" then
		confetti.Position = spawnPos
	else
		confetti.Position = UDim2.fromScale(math.random(0, 100)/100, math.random(-25, 125)/100)
	end
	
	local baseColor = baseColors[math.random(#baseColors)]
	local brightnessFactor = math.random(95, 105) / 100
	confetti.BackgroundColor3 = Color3.new(
		math.clamp(baseColor.R * brightnessFactor, 0, 1),
		math.clamp(baseColor.G * brightnessFactor, 0, 1),
		math.clamp(baseColor.B * brightnessFactor, 0, 1)
	)

	local gradient = Instance.new("UIGradient")
	gradient.Rotation = math.random(0, 360)
	gradient.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.new(math.random(75, 100)/100, math.random(75, 100)/100, math.random(75, 100)/100)),
		ColorSequenceKeypoint.new(1, Color3.new(math.random(75, 100)/100, math.random(75, 100)/100, math.random(75, 100)/100))
	}
	gradient.Parent = confetti

	local shapeType = confettiShapes[math.random(#confettiShapes)]
	local uiCorner = Instance.new("UICorner")
	if shapeType == "Circle" then
		uiCorner.CornerRadius = UDim.new(1, 0)
	elseif shapeType == "Diamond" then
		confetti.Rotation = 45
	elseif shapeType == "Triangle" then
		confetti.Size = UDim2.new(0, math.random(28, 38), 0, math.random(18, 28))
	end
	uiCorner.Parent = confetti

	TweenService:Create(confetti, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut), {BackgroundTransparency = 0}):Play()
	return confetti
end

function Confetti:Emit(amount, spawnPos : UDim2)
	if typeof(amount) ~= "number" then amount = 250 end
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	local screenGui = playerGui:FindFirstChild("ConfettiScreenGui")
	if not screenGui then
		screenGui = Instance.new("ScreenGui")
		screenGui.Name = "ConfettiGui"
		screenGui.Parent = playerGui
		screenGui.IgnoreGuiInset = true
	end

	self.activeEmitters = (self.activeEmitters or 0) + 1
	
	local bonusSound = Instance.new("Sound")
	bonusSound.SoundId = "rbxassetid://140693247883244"
	bonusSound.Name = "BonusSound"
	bonusSound.Parent = screenGui
	repeat task.wait() until bonusSound.IsLoaded
	bonusSound:Play()
	
	for _ = 1, amount do
		local confetti = self:CreateConfettiPiece(spawnPos)
		confetti.Parent = screenGui

		local velocityX, velocityY, gravity = math.random(-300, 300), math.random(-350, -200), 75
		local rotationSpeed = math.random(-300, 300)
		local startTime = tick()

		local connection
		connection = RunService.RenderStepped:Connect(function(deltaTime)
			if not confetti.Parent then
				connection:Disconnect()
				return
			end

			local elapsedTime = tick() - startTime
			local newX = confetti.Position.X.Scale + (velocityX * deltaTime / 400)
			local newY = confetti.Position.Y.Scale + (velocityY * deltaTime / 400) + (0.5 * gravity * elapsedTime^2 / 3000)
			confetti.Position = UDim2.new(newX, 0, math.min(newY, 1.3), 0)
			confetti.Rotation += rotationSpeed * deltaTime + math.sin(elapsedTime * 2) * 0.5

			if newY > 1.3 then
				confetti:Destroy()
				connection:Disconnect()
				self.ActiveConfetti -= 1
			end
		end)

		self.ActiveConfetti = (self.ActiveConfetti or 0) + 1
	end

	coroutine.wrap(function()
		while self.ActiveConfetti > 0 do task.wait(1) end
		self.activeEmitters -= 1
		if self.activeEmitters ~= 0 then return end
		screenGui:Destroy()
	end)()
end

return Confetti