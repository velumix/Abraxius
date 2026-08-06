--[[ VisualSettings.lua By @MrHardswell Version 1.0.0]]

local Lighting = game:GetService("Lighting")
local VisualSettings = {}
VisualSettings.__index = VisualSettings

type Visuals = {
	[string]:{
		Lighting: {
			Ambient: Color3,
			Brightness: number,
			ColorShift_Bottom: Color3,
			ColorShift_Top: Color3,
			EnvironmentDiffuseScale: number,
			EnvironmentSpecularScale: number,
			GlobalShadows: boolean,
			OutdoorAmbient: Color3,
			ShadowSoftness: number,
			ClockTime: number,
			GeographicLatitude: number,
			TimeOfDay: string,
			ExposureCompensation: number,
		},
		Atmosphere: {
			Density: number,
			Offset: number,
			Color : Color3,
			Decay: Color3,
			Glare: number,
			Haze: number,
		},
		Bloom: {
			Enabled: boolean,
			Intensity: number,
			Size: number,
			Threshold: number,
		},
		Blur: {
			Enabled: boolean,
			Size: number,
		},
		ColorCorrection: {
			Enabled: boolean,
			Brightness: number,
			Contrast: number,
			Saturation: number,
			TintColor: Color3,
		},
		DepthOfFieldEffect: {
			Enabled: boolean,
			FarIntensity: number,
			FocusDistance: number,
			InFocusRadius: number,
			NearIntensity: number,
		},
		SunRays : {
			Enabled: boolean,
			Intensity: number,
			Spread: number,
		}
	}
}

VisualSettings.Current = "Default"

VisualSettings.Default = {
	Lighting = {
		Ambient = Color3.fromRGB(112, 112, 112),
		Brightness = 3,
		ColorShift_Bottom = Color3.fromRGB(0, 0, 0),
		ColorShift_Top = Color3.fromRGB(132, 153, 167),
		EnvironmentDiffuseScale = 1,
		EnvironmentSpecularScale = 1,
		GlobalShadows = true,
		OutdoorAmbient = Color3.fromRGB(147, 179, 255),
		ShadowSoftness = 0.2,
		ClockTime = 12,
		GeographicLatitude = 51.5,
		TimeOfDay = "12:00:00",
		ExposureCompensation = 0.34,
	},
	Atmosphere = {
		Density = 0.45,
		Offset = 0.199,
		Color = Color3.fromRGB(155, 166, 181),
		Decay = Color3.fromRGB(92, 60, 13),
		Glare = 0.68,
		Haze = 0.36,
	},
	Bloom = {
		Enabled = false,
		Intensity = 0.3,
		Size = 0.5,
		Threshold = 0.5,
	},
	Blur = {
		Enabled = false,
		Size = 0,
	},
	ColorCorrection = {
		Enabled = true,
		Brightness = 0,
		Contrast = 0.2,
		Saturation = 0.05,
		TintColor = Color3.fromRGB(255, 255, 255),
	},
	DepthOfField = {
		Enabled = true,
		FarIntensity = 0.2,
		FocusDistance = 45,
		InFocusRadius = 50,
		NearIntensity = 0,
	},
	SunRays = {
		Enabled = false,
		Intensity = 0.5,
		Spread = 0.5,
	}
}

VisualSettings.Initiate = function()
	-- Checks if items exist in Lighting
	if not Lighting:FindFirstChild("Atmosphere") then -- Atmosphere
		local Atmosphere = Instance.new("Atmosphere")
		Atmosphere.Name = "Atmosphere"
		Atmosphere.Parent = Lighting
	end

	if not Lighting:FindFirstChild("Bloom") then -- Bloom
		local BloomEffect = Instance.new("BloomEffect")
		BloomEffect.Name = "Bloom"
		BloomEffect.Parent = Lighting
	end

	if not Lighting:FindFirstChild("Blur") then -- Blur
		local BlurEffect = Instance.new("BlurEffect")
		BlurEffect.Name = "Blur"
		BlurEffect.Parent = Lighting
	end

	if not Lighting:FindFirstChild("ColorCorrection") then -- ColorCorrection
		local ColorCorrectionEffect = Instance.new("ColorCorrectionEffect")
		ColorCorrectionEffect.Name = "ColorCorrection"
		ColorCorrectionEffect.Parent = Lighting
	end

	if not Lighting:FindFirstChild("DepthOfField") then -- DepthOfField
		local DepthOfFieldEffect = Instance.new("DepthOfFieldEffect")
		DepthOfFieldEffect.Name = "DepthOfField"
		DepthOfFieldEffect.Parent = Lighting
	end

	if not Lighting:FindFirstChild("SunRays") then -- SunRays
		local SunRaysEffect = Instance.new("SunRaysEffect")
		SunRaysEffect.Name = "SunRays"
		SunRaysEffect.Parent = Lighting
	end

end

VisualSettings.SetDefault = function() -- Sets the current settings to the default settings
	VisualSettings.Current = "Default"
	VisualSettings.Apply()
end

VisualSettings.Apply = function(Theme: string?) -- Applies theme to the current settings.. if no theme is specified, it will use the current theme
	local Visual = VisualSettings[Theme or VisualSettings.Current]
	-- Lighting
	Lighting.Ambient = Visual.Lighting.Ambient
	Lighting.Brightness = Visual.Lighting.Brightness
	Lighting.ColorShift_Bottom = Visual.Lighting.ColorShift_Bottom
	Lighting.ColorShift_Top = Visual.Lighting.ColorShift_Top
	Lighting.EnvironmentDiffuseScale = Visual.Lighting.EnvironmentDiffuseScale
	Lighting.EnvironmentSpecularScale = Visual.Lighting.EnvironmentSpecularScale
	Lighting.GlobalShadows = Visual.Lighting.GlobalShadows
	Lighting.OutdoorAmbient = Visual.Lighting.OutdoorAmbient
	Lighting.ShadowSoftness = Visual.Lighting.ShadowSoftness
	Lighting.ClockTime = Visual.Lighting.ClockTime
	Lighting.GeographicLatitude = Visual.Lighting.GeographicLatitude
	Lighting.TimeOfDay = Visual.Lighting.TimeOfDay
	Lighting.ExposureCompensation = Visual.Lighting.ExposureCompensation
	-- Atmosphere
	Lighting.Atmosphere.Density = Visual.Atmosphere.Density
	Lighting.Atmosphere.Offset = Visual.Atmosphere.Offset
	Lighting.Atmosphere.Color = Visual.Atmosphere.Color
	Lighting.Atmosphere.Decay = Visual.Atmosphere.Decay
	Lighting.Atmosphere.Glare = Visual.Atmosphere.Glare
	Lighting.Atmosphere.Haze = Visual.Atmosphere.Haze
	-- Blur
	Lighting.Bloom.Enabled = Visual.Bloom.Enabled
	Lighting.Bloom.Intensity = Visual.Bloom.Intensity
	Lighting.Bloom.Size = Visual.Bloom.Size
	Lighting.Bloom.Threshold = Visual.Bloom.Threshold
	-- Blur
	Lighting.Blur.Enabled = Visual.Blur.Enabled
	Lighting.Blur.Size = Visual.Blur.Size
	-- ColorCorrection
	Lighting.ColorCorrection.Enabled = Visual.ColorCorrection.Enabled
	Lighting.ColorCorrection.Brightness = Visual.ColorCorrection.Brightness
	Lighting.ColorCorrection.Contrast = Visual.ColorCorrection.Contrast
	Lighting.ColorCorrection.Saturation = Visual.ColorCorrection.Saturation
	Lighting.ColorCorrection.TintColor = Visual.ColorCorrection.TintColor
	-- DepthOfField
	Lighting.DepthOfField.Enabled = Visual.DepthOfField.Enabled
	Lighting.DepthOfField.FarIntensity = Visual.DepthOfField.FarIntensity
	Lighting.DepthOfField.FocusDistance = Visual.DepthOfField.FocusDistance
	Lighting.DepthOfField.InFocusRadius = Visual.DepthOfField.InFocusRadius
	Lighting.DepthOfField.NearIntensity = Visual.DepthOfField.NearIntensity
	-- SunRays
	Lighting.SunRays.Enabled = Visual.SunRays.Enabled
	Lighting.SunRays.Intensity = Visual.SunRays.Intensity
	Lighting.SunRays.Spread = Visual.SunRays.Spread
end

VisualSettings.GetDefaultTheme = function() -- Gets the default theme
	return VisualSettings.Default
end

VisualSettings.CreateTheme = function(Theme: string, Settings: table) -- Creates a new theme
	VisualSettings[Theme] = Settings
end

return VisualSettings