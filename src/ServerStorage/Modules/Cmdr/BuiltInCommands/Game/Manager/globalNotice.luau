return {
	Name = "globalNotice";
	Description = "Publishes a Notice which every server can see.";
	Group = "GameOwner";
	Args = {
		{
			Type = "string";
			Name = "Notice";
			Description = "The Notice you want to publish.";
		},
		{
			Type = "number";
			Name = "Duration";
			Description = "How many seconds you want the notice to show for";
			Default = 15;
		},
		{
			Type = "color3";
			Name = "Color";
			Description = "What color the notice should be";
			Default = Color3.new(1, 0.858824, 0.294118);
		},
		{
			Type = "string";
			Name = "Sound";
			Description = "The Sound you want to be associated with the notice.";
			Default = "none"
		},
	};
}