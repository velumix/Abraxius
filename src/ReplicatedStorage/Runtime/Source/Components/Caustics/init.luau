local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if not RunService:IsClient() then
	return {
		Name = "CausticsClientOnly",
	}
end

local LocalPlayer = Players.LocalPlayer
local Mince = require(ReplicatedStorage.Modules.Mince)
local Textures = require(script.WaterTextures).assets

local RegisteredTextures = {}
local AnimatorConnection = nil
local CurrentFrame = 1
local FrameAccumulator = 0

local Caustics = Mince.Component({
	Tag = "Caustics",
})

local function isEnabled()
	return LocalPlayer:GetAttribute("Caustics") == true
end

local function getFrameInterval()
	local speed = math.clamp(LocalPlayer:GetAttribute("CausticsSpeed") or 0.5, 0, 1)
	local framesPerSecond = 4 + speed * 6
	return 1 / framesPerSecond
end

local function applyEnabledState()
	local enabled = isEnabled()
	local textureAsset = Textures[CurrentFrame]

	for texture in pairs(RegisteredTextures) do
		if texture.Parent then
			local targetTexture = enabled and textureAsset or ""
			if texture.Texture ~= targetTexture then
				texture.Texture = targetTexture
			end
		else
			RegisteredTextures[texture] = nil
		end
	end
end

local function startAnimator()
	if AnimatorConnection then
		return
	end

	AnimatorConnection = RunService.RenderStepped:Connect(function(deltaTime)
		if not isEnabled() or next(RegisteredTextures) == nil then
			return
		end

		FrameAccumulator += deltaTime
		local frameInterval = getFrameInterval()
		if FrameAccumulator < frameInterval then
			return
		end

		FrameAccumulator %= frameInterval
		CurrentFrame = (CurrentFrame % #Textures) + 1
		local textureAsset = Textures[CurrentFrame]

		for texture in pairs(RegisteredTextures) do
			if texture.Parent then
				texture.Texture = textureAsset
			else
				RegisteredTextures[texture] = nil
			end
		end
	end)
end

function Caustics:Setup()
	task.spawn(function()
		local success, err = pcall(ContentProvider.PreloadAsync, ContentProvider, Textures)
		if not success then
			warn(`Caustics texture preload failed: {err}`)
		end
	end)

	LocalPlayer:GetAttributeChangedSignal("Caustics"):Connect(applyEnabledState)
	startAnimator()
	applyEnabledState()
end

function Caustics:Construct()
	self.Part = self.Instance
	if not self.Part:IsA("BasePart") then
		return
	end

	self.Texture = self.Part:FindFirstChildWhichIsA("Texture")
	if not self.Texture then
		return
	end

	RegisteredTextures[self.Texture] = true
	self.Texture.Texture = isEnabled() and Textures[CurrentFrame] or ""
end

function Caustics:Removing()
	if self.Texture then
		RegisteredTextures[self.Texture] = nil
		self.Texture.Texture = ""
	end
end

function Caustics:Stop()
	self:Removing()
end

return Caustics
