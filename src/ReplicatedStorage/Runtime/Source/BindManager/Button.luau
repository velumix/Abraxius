return {
	Static = "rbxassetid://12091205581", 
	Pressed = "rbxassetid://12095141051",

	BaseIconSize = 0.6,

	StaticColor = Color3.new(1,1,1),
	PressedColor = Color3.new(0,0,0),

	InteractingButton = {},

	ButtonAligments = {
		["BottomRight"] = {
			Multiplier = -1, 
			Position = Vector2.new(1,1), 
			Anchor = Vector2.new(1,0.5)
		},
		["TopRight"] =  {
			Multiplier = Vector2.new(-1,1),
			Position = Vector2.new(1,0), 
			Anchor = Vector2.new(1,0)
		} 
	},

	Stack = {}
}