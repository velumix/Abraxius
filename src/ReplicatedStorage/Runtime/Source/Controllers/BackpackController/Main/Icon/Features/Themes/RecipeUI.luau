-- Theme inspired by the RecipeSelector UI
-- Modern dark theme with blue accents and smooth animations

return {

	-- Global settings (applied to all states)
	{"IconCorners", "CornerRadius", UDim.new(0, 12)}, -- Rounded corners like RecipeSelector cards
	{"Selection", "RotationSpeed", 1},
	{"Selection", "Size", UDim2.new(1, 6, 1, 6)}, -- Slightly larger selection border
	{"Selection", "Position", UDim2.new(0, -3, 0, -3)},
	{"SelectionGradient", "Color", ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(45, 180, 220)), -- Recipe UI accent color
		ColorSequenceKeypoint.new(1, Color3.fromRGB(65, 200, 240)), -- Recipe UI accent hover
	})},

	-- Deselected state - matches recipe card styling
	{"IconImage", "Image", "", "Deselected"},
	{"IconLabel", "Text", "", "Deselected"},
	{"IconLabel", "Position", UDim2.fromOffset(0, 0), "Deselected"},
	{"Widget", "MinimumWidth", 50, "Deselected"}, -- Slightly larger for modern look
	{"Widget", "MinimumHeight", 50, "Deselected"},
	{"Widget", "BorderSize", 8, "Deselected"}, -- More spacing like recipe cards
	{"IconButton", "BackgroundColor3", Color3.fromRGB(25, 40, 65), "Deselected"}, -- Recipe card color
	{"IconButton", "BackgroundTransparency", 0, "Deselected"}, -- Solid background
	{"IconButton", "BorderSizePixel", 0, "Deselected"}, -- Remove default border
	{"IconImageScale", "Value", 0.65, "Deselected"}, -- Slightly larger icons
	{"IconImageCorner", "CornerRadius", UDim.new(0, 8), "Deselected"}, -- Rounded icon images
	{"IconImage", "ImageColor3", Color3.fromRGB(220, 240, 255), "Deselected"}, -- Recipe UI text color
	{"IconImage", "ImageTransparency", 0, "Deselected"},
	{"IconLabel", "FontFace", Font.new("rbxasset://fonts/families/SourceSans.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal), "Deselected"}, -- Match recipe font
	{"IconLabel", "TextSize", 16, "Deselected"}, -- Larger text
	{"IconLabel", "TextColor3", Color3.fromRGB(220, 240, 255), "Deselected"}, -- Recipe UI text color
	{"IconSpot", "BackgroundTransparency", 1, "Deselected"},
	{"IconOverlay", "BackgroundTransparency", 1, "Deselected"}, -- No overlay when deselected
	{"IconSpotGradient", "Enabled", false, "Deselected"},
	{"IconGradient", "Enabled", false, "Deselected"},
	{"ClickRegion", "Active", true, "Deselected"},
	{"Menu", "Active", false, "Deselected"},
	{"ContentsList", "HorizontalAlignment", Enum.HorizontalAlignment.Center, "Deselected"},
	{"Dropdown", "BackgroundColor3", Color3.fromRGB(15, 25, 45), "Deselected"}, -- Recipe background color
	{"Dropdown", "BackgroundTransparency", 0.05, "Deselected"}, -- Mostly opaque
	{"Dropdown", "MaxIcons", 5, "Deselected"}, -- More icons visible
	{"Menu", "MaxIcons", 6, "Deselected"},
	{"Notice", "Position", UDim2.new(1, -16, 0, -4), "Deselected"}, -- Better positioning
	{"Notice", "Size", UDim2.new(0, 26, 0, 26), "Deselected"}, -- Larger notices
	{"Notice", "BackgroundColor3", Color3.fromRGB(45, 180, 220), "Deselected"}, -- Accent color for notices
	{"Notice", "BorderSizePixel", 0, "Deselected"},
	{"NoticeCorner", "CornerRadius", UDim.new(0, 13), "Deselected"}, -- Round notices
	{"NoticeLabel", "TextSize", 15, "Deselected"},
	{"NoticeLabel", "TextColor3", Color3.new(1, 1, 1), "Deselected"}, -- White text on accent
	{"NoticeLabel", "FontFace", Font.new("rbxasset://fonts/families/SourceSans.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal), "Deselected"},
	{"PaddingLeft", "Size", UDim2.new(0, 14, 1, 0), "Deselected"}, -- More padding
	{"PaddingRight", "Size", UDim2.new(0, 16, 1, 0), "Deselected"},

	-- Selected state - hover effect like recipe cards
	{"IconButton", "BackgroundColor3", Color3.fromRGB(35, 55, 85), "Selected"}, -- Recipe card hover color
	{"IconSpot", "BackgroundTransparency", 0.75, "Selected"}, -- Subtle glow effect
	{"IconSpot", "BackgroundColor3", Color3.fromRGB(45, 180, 220), "Selected"}, -- Accent glow
	{"IconSpotGradient", "Enabled", true, "Selected"},
	{"IconSpotGradient", "Rotation", 0, "Selected"}, -- No rotation for cleaner look
	{"IconSpotGradient", "Color", ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(45, 180, 220)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(65, 200, 240)),
	}), "Selected"},
	{"IconOverlay", "BackgroundTransparency", 0.55, "Selected"}, -- Subtle overlay
	{"IconOverlay", "BackgroundColor3", Color3.fromRGB(45, 180, 220), "Selected"}, -- Accent overlay
	{"IconImage", "ImageColor3", Color3.fromRGB(255, 255, 255), "Selected"}, -- Brighter when selected
	{"IconLabel", "TextColor3", Color3.fromRGB(255, 255, 255), "Selected"}, -- Brighter text
	{"Notice", "BackgroundColor3", Color3.fromRGB(65, 200, 240), "Selected"}, -- Brighter notice when selected

	-- Viewing state (hover) - similar to selected but more subtle
	{"IconButton", "BackgroundColor3", Color3.fromRGB(30, 47, 75), "Viewing"}, -- Subtle hover
	{"IconSpot", "BackgroundTransparency", 0.85, "Viewing"}, -- Very subtle glow
	{"IconSpot", "BackgroundColor3", Color3.fromRGB(45, 180, 220), "Viewing"},
	{"IconImage", "ImageColor3", Color3.fromRGB(240, 250, 255), "Viewing"}, -- Slightly brighter
	{"IconLabel", "TextColor3", Color3.fromRGB(240, 250, 255), "Viewing"},
	{"Notice", "BackgroundColor3", Color3.fromRGB(55, 190, 230), "Viewing"}, -- Slightly brighter notice when viewing

}
