return {

	-- When no state is specified the modification is applied to *all* states (Deselected, Selected and Viewing)
	{"IconCorners", "CornerRadius", UDim.new(1,0 )}, -- Controls the corner radius of all UI elements with the "IconCorners" collective attribute
	{"Selection", "RotationSpeed", 1}, -- Controls how fast the selection highlight border rotates (used for gamepad/controller selection)
	{"Selection", "Size", UDim2.new(1, 0, 1, 1)}, -- Sets the size of the selection highlight border relative to the icon
	{"Selection", "Position", UDim2.new(0, 0, 0, 0)}, -- Sets the position of the selection highlight border
	{"SelectionGradient", "Color", ColorSequence.new({ -- Controls the gradient colors of the selection highlight border
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 30, 30)),
	})},

	-- When the icon is deselected
	{"IconImage", "Image", "", "Deselected"}, -- Sets the image displayed in the icon when deselected (empty string = no image)
	{"IconLabel", "Text", "", "Deselected"}, -- Sets the text label displayed in the icon when deselected (empty string = no text)
	{"IconLabel", "Position", UDim2.fromOffset(0, 0), "Deselected"}, -- Sets the position of the text label relative to its container
	{"Widget", "MinimumWidth", 44, "Deselected"}, -- Sets the minimum width of the entire icon widget
	{"Widget", "MinimumHeight", 44, "Deselected"}, -- Sets the minimum height of the entire icon widget
	{"Widget", "BorderSize", 4, "Deselected"}, -- Sets the border size around the icon (affects menu positioning and gaps)
	{"IconButton", "BackgroundColor3", Color3.fromRGB(0, 0, 0), "Deselected"}, -- Sets the background color of the main icon button
	{"IconButton", "BackgroundTransparency", 0.3, "Deselected"}, -- Sets the transparency of the icon button background
	{"IconImageScale", "Value", 0.5, "Deselected"}, -- Controls the scale/size of the icon image (0.5 = 50% of container)
	{"IconImageCorner", "CornerRadius", UDim.new(0, 0), "Deselected"}, -- Sets the corner radius of the icon image specifically
	{"IconImage", "ImageColor3", Color3.fromRGB(255, 255, 255), "Deselected"}, -- Sets the tint color of the icon image
	{"IconImage", "ImageTransparency", 0, "Deselected"}, -- Sets the transparency of the icon image (0 = fully opaque)
	{"IconLabel", "FontFace", Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal), "Deselected"}, -- Sets the font family, weight, and style for the text label
	{"IconLabel", "TextSize", 14, "Deselected"}, -- Sets the font size of the text label
	{"IconSpot", "BackgroundTransparency", 1, "Deselected"}, -- Sets the transparency of the main icon spot (1 = fully transparent)
	{"IconOverlay", "BackgroundTransparency", 0.925, "Deselected"}, -- Sets the transparency of the overlay effect on the icon spot
	{"IconSpotGradient", "Enabled", false, "Deselected"}, -- Controls whether the gradient effect on the icon spot is visible
	{"IconGradient", "Enabled", false, "Deselected"}, -- Controls whether the gradient effect on the icon button is visible
	{"ClickRegion", "Active", true, "Deselected"},  -- Controls whether the clickable region is active (set to false in scrollers for mobile dragging)
	{"Menu", "Active", false, "Deselected"}, -- Controls whether the menu system is active when deselected
	{"ContentsList", "HorizontalAlignment", Enum.HorizontalAlignment.Center, "Deselected"}, -- Sets how contents (image + text) are aligned horizontally
	{"Dropdown", "BackgroundColor3", Color3.fromRGB(0, 0, 0), "Deselected"}, -- Sets the background color of dropdown menus
	{"Dropdown", "BackgroundTransparency", 0.3, "Deselected"}, -- Sets the transparency of dropdown menu backgrounds
	{"Dropdown", "MaxIcons", 4, "Deselected"}, -- Sets the maximum number of icons visible in dropdown menus before scrolling
	{"Menu", "MaxIcons", 4, "Deselected"}, -- Sets the maximum number of icons visible in horizontal menus before scrolling
	{"Notice", "Position", UDim2.new(1, -12, 0, -1), "Deselected"}, -- Sets the position of notification badges relative to the icon
	{"Notice", "Size", UDim2.new(0, 20, 0, 20), "Deselected"}, -- Sets the size of notification badges
	{"NoticeLabel", "TextSize", 13, "Deselected"}, -- Sets the font size of text within notification badges
	{"PaddingLeft", "Size", UDim2.new(0, 9, 1, 0), "Deselected"}, -- Sets the size of left padding space in the icon layout
	{"PaddingRight", "Size", UDim2.new(0, 11, 1, 0), "Deselected"}, -- Sets the size of right padding space in the icon layout

	-- When the icon is selected
	-- Selected also inherits everything from Deselected if nothing is set
	{"IconSpot", "BackgroundTransparency", 0.7, "Selected"}, -- Makes the icon spot more visible when selected (less transparent)
	{"IconSpot", "BackgroundColor3", Color3.fromRGB(255, 255, 255), "Selected"}, -- Changes the icon spot background to white when selected
	{"IconSpotGradient", "Enabled", true, "Selected"}, -- Enables the gradient effect on the icon spot when selected
	{"IconSpotGradient", "Rotation", 45, "Selected"}, -- Sets the rotation angle of the gradient effect when selected
	{"IconSpotGradient", "Color", ColorSequence.new(Color3.fromRGB(30, 30, 30), Color3.fromRGB(30, 30, 30)), "Selected"}, -- Sets the gradient colors when selected (solid dark gray)


	-- When a cursor is hovering above, a controller highlighting, or touchpad (mobile) pressing (but not released)
	--{"IconSpot", "BackgroundTransparency", 0.75, "Viewing"},

}