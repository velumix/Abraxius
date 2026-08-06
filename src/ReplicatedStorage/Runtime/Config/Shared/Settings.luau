local Colors = {
	Red = Color3.new(0.7, 0.2, 0.2),     -- Used for negative/off/low states
	Green = Color3.new(0.2, 0.8, 0.2),   -- Used for positive/on/high states
	Orange = Color3.new(0.9, 0.6, 0.1),   -- Used for medium/intermediate states

	-- Performance Colors
	White = Color3.new(1, 1, 1),
	Cyan = Color3.new(0, 0.9, 1),        -- Bright cyan for very high FPS
	DarkRed = Color3.new(0.5, 0, 0),
	Yellow = Color3.new(1, 0.8, 0),
	LightGreen = Color3.new(0.4, 1, 0.4)
}


function Colors:lerpColor(color1, color2, alpha)
	return Color3.new(
		color1.R + (color2.R - color1.R) * alpha,
		color1.G + (color2.G - color1.G) * alpha,
		color1.B + (color2.B - color1.B) * alpha
	)
end

function Colors:GetFPSColor(fps)
	if fps >= 60 then
		-- Lerp from green to cyan for high FPS, with a smooth transition
		-- Takes 180 FPS to reach full cyan (60 FPS baseline + 120 FPS range)
		local alpha = math.min((fps - 60) / 120, 1)
		return self:lerpColor(Colors.Green, Colors.Cyan, alpha)
	else
		-- Lerp from red to green for lower FPS
		local alpha = math.min(fps / 60, 1)
		return self:lerpColor(Colors.DarkRed, Colors.Green, alpha)
	end
end

-- Get color based on ping value
function Colors:GetPingColor(ping)
	if ping <= 0 then
		return Colors.White
	elseif ping < 90 then
		-- Lerp from white to light green
		local alpha = ping / 90
		return self:lerpColor(Colors.White, Colors.LightGreen, alpha)
	elseif ping < 100 then
		-- Lerp from light green to yellow
		local alpha = (ping - 90) / 10
		return self:lerpColor(Colors.LightGreen, Colors.Yellow, alpha)
	elseif ping < 150 then
		-- Lerp from yellow to red
		local alpha = (ping - 100) / 50
		return self:lerpColor(Colors.Yellow, Colors.Red, alpha)
	else
		return Colors.DarkRed
	end
end

local CreateDevBoolSetting = function(b)return{Hidden=true,Identifer=b,Name="Interal Setting",Description=b,Type="Buttons",Buttons={{Text="false",Value=false,Color=Colors.Red},{Text="true",Value=true,Color=Colors.Green}}}end

return {
	Colors = Colors,
	Objects = {
		{
			Identifier = "GraphicsQuality",
			Name = "Graphics Quality",
			Description = "Adjust the game's graphics quality.",
			Type = "Buttons",
			Buttons = {
				{Text = "Low", Value = 1, Color = Colors.Red},
				{Text = "Medium", Value = 2, Color = Colors.Orange},
				{Text = "High", Value = 3, Color = Colors.Green}
			}
		},

		{
			Identifier = "MusicVol",
			Name = "Music",
			Description = "Music volume.",
			Type = "Slider",
		},

		{
			Identifier = "SFXVol",
			Name = "SFX",
			Description = "Sound effects volume.",
			Type = "Slider",
		},

		{
			Identifier = "Caustics",
			Name = "Caustics",
			Description = "Toggle underwater caustics, requires shadows.",
			Type = "Buttons",
			Buttons = {
				{Text = "Off", Value = false, Color = Colors.Red},
				{Text = "On", Value = true, Color = Colors.Green}
			}
		},

		{
			Identifier = "CausticsSpeed",
			Name = "Caustics Speed",
			Description = "Modify the caustics speed.",
			Type = "Slider",
		},

		{
			Identifier = "Shadows",
			Name = "Shadows",
			Description = "Toggle shadows.",
			Type = "Buttons",
			Buttons = {
				{Text = "Off", Value = false, Color = Colors.Red},
				{Text = "On", Value = true, Color = Colors.Green}
			}
		},

		{
			Identifier = "ShowNotifications",
			Name = "Notifications",
			Description = "Toggle in-game notifications.",
			Type = "Buttons",
			Buttons = {
				{Text = "Off", Value = false, Color = Colors.Red},
				{Text = "On", Value = true, Color = Colors.Green}
			}
		},

		{
			Identifier = "HeadMovementEnabled",
			Name = "Head Movement",
			Description = "Show head movement.",
			Type = "Buttons",
			Buttons = {
				{Text = "Off", Value = false, Color = Colors.Red},
				{Text = "On", Value = true, Color = Colors.Green}
			}
		},

		{
			Identifier = "ShowTrash",
			Name = "Show Debris",
			Description = "Show or hide ocean debris.",
			Type = "Buttons",
			Buttons = {
				{Text = "Hide", Value = false, Color = Colors.Red},
				{Text = "Show", Value = true, Color = Colors.Green}
			}
		},

		{
			Identifier = "ShowGearInObservatory",
			Name = "Diving Gear Visibility",
			Description = "Show or hide diving gear inside.",
			Type = "Buttons",
			Buttons = {
				{Text = "Hide Indoors", Value = false, Color = Colors.Red},
				{Text = "Always Show", Value = true, Color = Colors.Green}
			}
		},

		{
			Identifier = "ReplayFirstTimeChallenge",
			Name = "Replay First Steps",
			Description = "Replay the First Steps tutorial.",
			Type = "Buttons",
			DisregardAfterSession = true,
			Buttons = {
				{Text = "Replay", Value = true, Color = Colors.Blue}
			}
		},



	}
} 