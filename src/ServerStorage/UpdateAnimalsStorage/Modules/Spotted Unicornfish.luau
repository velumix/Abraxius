local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "spottedUnicorn", -- This is the what you set the _fishId arttibute to!
	Name = "Spotted Unicornfish", -- The name of the fish that will show up in the book
	Aliases = { "Naso brevirostris" },
	Model = Assets["Spotted Unicornfish"],
	Icon = "",

	Family = "Acanthuridae",
	Diet = "Algae",
	Size = "60 cm (23.6 in)",
	Time = "Day", -- Time of day the fish is active
	Depths = "1-122 m (3.3-400 ft)",

	Facts = {
		"The spotted unicornfish gets its name from the long, horn-like projection that grows from its forehead as it matures.",
		"Spotted unicornfish form large schools, often mixing with other unicornfish species.",
		"Like other surgeonfish, unicornfish mainily eat leafy algae and seagrass, making them an important grazer on the reef. ",
		"The characteristic horn does not appear until the fish reaches adulthood, meaning juvenile unicorns look very different from adults."
	},

}