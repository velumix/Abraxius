local LightingProperties = {
	Ambient = true;
	Brightness = true;
	ColorShift_Bottom = true;
	ColorShift_Top = true;
	EnvironmentDiffuseScale = true;
	EnvironmentSpecularScale = true;
	GlobalShadows = true;
	OutdoorAmbient = true;
	ShadowSoftness = true;
	ClockTime = true;
	GeographicLatitude = true;
	ExposureCompensation = true;
	FogColor = true, 
	FogEnd = true,
	FogStart = true, 
}

local LightingClasses = {
	Atmosphere = true;
	Sky = true;
	BloomEffect = true;
	DepthOfFieldEffect = true;
	ColorCorrectionEffect = true;
	SunRaysEffect = true;
	BlurEffect = true;
	ColorGradingEffect = true,
}

local TerrainProperties = {
	WaterColor = true;
	WaterReflectance = true;
	WaterTransparency = true;
	WaterWaveSize = true;
	WaterWaveSpeed = true;
}

local TerrainClasses = {
	Clouds = true;
}

local TerrainColors = {}

for i,v in Enum.Material:GetEnumItems() do
	pcall(function()
		workspace.Terrain:GetMaterialColor(v)
		TerrainColors[tostring(v):sub(15)] = true
	end)
end

local TweenService =game:GetService("TweenService")
local Lighting = game.Lighting
local Terrain = workspace.Terrain

local PropertyService = script.Parent and require(script.Parent.PropertyService)

-- Pre-define functions

local GenerateEnvironment;
local SwitchEnvironment; 
local LoadEnvironment;

-- Define functions

GenerateEnvironment = function(Name)
	local EnvironmentFolder = Instance.new("Folder")
	EnvironmentFolder.Name = (Name and Name.."_" or "").."Environment"

	-- Save lighting settings

	local LightingConfig = Instance.new("Configuration", EnvironmentFolder)
	LightingConfig.Name = "Lighting"

	for Name in pairs(LightingProperties) do
		LightingConfig:SetAttribute(Name, Lighting[Name])
	end

	-- Save all lighting objects

	for i,Object in pairs(Lighting:GetChildren()) do
		if LightingClasses[Object.ClassName] then
			Object:Clone().Parent = LightingConfig
		end
	end

	-- Save terrain settings

	local TerrainConfig = Instance.new("Configuration", EnvironmentFolder)
	TerrainConfig.Name = "Terrain"

	for Name in pairs(TerrainProperties) do
		TerrainConfig:SetAttribute(Name, Terrain[Name])
	end

	-- Save terrain objects

	for i,Object in pairs(Terrain:GetChildren()) do
		if TerrainClasses[Object.ClassName] then
			Object:Clone().Parent = TerrainConfig
		end
	end

	-- Save terrain colors

	local TerrainColorsConfig = Instance.new("Configuration", EnvironmentFolder)
	TerrainColorsConfig.Name = "TerrainColors"

	for Name in pairs(TerrainColors) do
		TerrainColorsConfig:SetAttribute(Name, Terrain:GetMaterialColor(Name))
	end

	-- Return environment folder

	return EnvironmentFolder
end

SwitchEnvironment = function(EnvironmentFolder, FadeTime) 
	local FadeTime = FadeTime or 1
	local FadeTween = TweenInfo.new(FadeTime,Enum.EasingStyle.Linear)
	if not EnvironmentFolder then
		error("No EnvironmentFolder provided")
	end

	-- Load lighting settings

	local TweenStack = {} 

	TweenStack[Lighting] = {}

	local UnTweenable = {
		["TimeOfDay"] = true,
		["Brightness"] = true 
	} 
	local UnTweenableTypes = {
		["String"] = true,
		["Content"] = true
	} 
	local GlobalUnTweenable = {
		["Name"] = true,
	}

	-- Add all of the lighting properties to the tweenstack 
	local LightingConfig = EnvironmentFolder:FindFirstChild("Lighting")
	if LightingConfig then
		for Name, Value in pairs(LightingConfig:GetAttributes()) do
			if not UnTweenable[Name] then 
				TweenStack[Lighting][Name] = Value
			else 
				Lighting[Name] = Value 
			end
		end
	else
		warn("Environment is missing lighting config")
	end

	-- Clear existing lighting objects from lighting if they dont exist in the enviormentfolder
	for i,Object in pairs(Lighting:GetChildren()) do
		if Object:GetAttribute("IgnoreEnvironment") then continue end 
		if LightingClasses[Object.ClassName] then
			local ExistingLightingClass = LightingConfig:FindFirstChild(Object.Name)
			if not ExistingLightingClass then
				Object:Destroy()
			end
		end 
	end

	-- Load lighting objects from enviormentfolder into lighting  if they are not alreasdy in the lighting.
	local ExisitngLighting = {} 
	for i,Object in pairs(LightingConfig:GetChildren()) do
		if LightingClasses[Object.ClassName] then
			local ExistingLightingClass = Lighting:FindFirstChild(Object.Name)
			if not ExistingLightingClass then
				Object:Clone().Parent = Lighting
			else 
				ExisitngLighting[Object] = ExistingLightingClass
			end
		end
	end

	-- Tween the currency lighting if it's readable from PropertySErvice 
	for TargetLighting,LightingClass in ExisitngLighting do 
		local Class = PropertyService.GetClass(TargetLighting.ClassName) -- Set the defaults based on the datatype

		if Class then 
			TweenStack[LightingClass] = {}  
			Class.ReadScriptiableInhertitedProperties(function(PropertyName, PropertyInfo)
				if not GlobalUnTweenable[PropertyName] and not UnTweenableTypes[PropertyInfo.ValueType.Name] then 
					TweenStack[LightingClass][PropertyName] = TargetLighting[PropertyName]
				else 
					LightingClass[PropertyName] = TargetLighting[PropertyName]
				end
			end)
		else 
			warn(`Could not SwitchEnviorment lighting class name '{TargetLighting.ClassName}'.`)
		end
	end



	-- Load terrain settings

	local TerrainConfig = EnvironmentFolder:FindFirstChild("Terrain")
	if TerrainConfig then
		for Name, Value in pairs(TerrainConfig:GetAttributes()) do
			Terrain[Name] = Value
		end
	else
		warn("Environment is missing terrain config")
	end

	-- Clear existing terrain objects

	for i,Object in pairs(Terrain:GetChildren()) do
		if Object:GetAttribute("IgnoreEnvironment") then continue end 
		if TerrainClasses[Object.ClassName] then
			Object:Destroy()
		end
	end

	-- Load terrain objects

	for i,Object in pairs(TerrainConfig:GetChildren()) do
		if TerrainClasses[Object.ClassName] then
			Object:Clone().Parent = Terrain
		end
	end

	-- Load terrain colors

	local TerrainColorsConfig = EnvironmentFolder:FindFirstChild("TerrainColors")
	if TerrainColorsConfig then
		for Name, Value in pairs(TerrainColorsConfig:GetAttributes()) do
			Terrain:SetMaterialColor(Name, Value)
		end
	else
		warn("Environment is missing terrain colors config")
	end


	local Tweens = {} 

	for TweenInstance,Properties in TweenStack do 
		local Tween = TweenService:Create(TweenInstance,FadeTween,Properties)	 
		table.insert(Tweens,Tween)
	end

	for _,Tween in Tweens do 
		Tween:Play()
	end
end

LoadEnvironment = function(EnvironmentFolder)
	if not EnvironmentFolder then
		error("No EnvironmentFolder provided")
	end

	-- Load lighting settings

	local LightingConfig = EnvironmentFolder:FindFirstChild("Lighting")
	if LightingConfig then
		for Name, Value in pairs(LightingConfig:GetAttributes()) do
			Lighting[Name] = Value
		end
		local TimeOfDay = LightingConfig:GetAttribute("TimeOfDay")
		if TimeOfDay then
			Lighting.TimeOfDay = TimeOfDay
		end
	else
		warn("Environment is missing lighting config")
	end

	-- Clear existing lighting objects

	for i,Object in pairs(Lighting:GetChildren()) do
		if Object:GetAttribute("IgnoreEnvironment") then continue end 
		if LightingClasses[Object.ClassName] then
			Object:Destroy()
		end
	end

	-- Load lighting objects

	for i,Object in pairs(LightingConfig:GetChildren()) do
		if LightingClasses[Object.ClassName] then
			Object:Clone().Parent = Lighting
		end
	end

	-- Load terrain settings

	local TerrainConfig = EnvironmentFolder:FindFirstChild("Terrain")
	if TerrainConfig then
		for Name, Value in pairs(TerrainConfig:GetAttributes()) do
			Terrain[Name] = Value
		end
	else
		warn("Environment is missing terrain config")
	end

	-- Clear existing terrain objects

	for i,Object in pairs(Terrain:GetChildren()) do
		if Object:GetAttribute("IgnoreEnvironment") then continue end 
		if TerrainClasses[Object.ClassName] then
			Object:Destroy()
		end
	end

	-- Load terrain objects

	for i,Object in pairs(TerrainConfig:GetChildren()) do
		if TerrainClasses[Object.ClassName] then
			Object:Clone().Parent = Terrain
		end
	end

	-- Load terrain colors

	local TerrainColorsConfig = EnvironmentFolder:FindFirstChild("TerrainColors")
	if TerrainColorsConfig then
		for Name, Value in pairs(TerrainColorsConfig:GetAttributes()) do
			Terrain:SetMaterialColor(Name, Value)
		end
	else
		warn("Environment is missing terrain colors config")
	end
end

-- Export

return {
	GenerateEnvironment = GenerateEnvironment;
	SwitchEnvironment = SwitchEnvironment;
	LoadEnvironment = LoadEnvironment;
}