local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "clownTrigger", -- This is the what you set the _fishId arttibute to!
	Name = "Clown Triggerfish", -- The name of the fish that will show up in the book
	Aliases = { "Balistoides conspicillum" },
	Model = Assets["Clown Triggerfish"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",
	
	Family = "Balistidae",
	Diet = "Invertebrates",
	Size = "50 cm (11.8 in)",
    Depths = "10-75 m (33-246 ft)",
	
    Facts = {
		"This iconic reef fish can often be seen swiming in outer reef habitats, occasionally darting into caves for cover.",
		"The bold coloration of this fish has made it desirable for aquariums. It is an aggressive fish, so is not reccomended for beginners.",
		"Clown triggerfish, like other triggerfish, eat hard shelled invertebrates such as urchins and clams.",
		"The back two fins of some clown triggerfish individuals are a vivid pink color!",
	},
}