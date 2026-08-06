local Npc = {}

Npc.Name = "Alex the Aquarist"
Npc.Data = nil

Npc.Interaction = {
	["Talk"] = {
		[1] = {
			{"Hey, want to hear cool facts about a tropical fish?", "InitialChoice", 78219321176580}
		},
		[2] = {
			{"It's called the Yellow Tang, and it's known for its bright yellow color!", "Continue", 111528319603305}
		},
		[3] = {
			{"Yellow Tangs are found in the warm waters of the Pacific Ocean, particularly around the Hawaiian Islands. They are popular in home aquariums due to their vibrant color and relatively easy care.", "Continue", 77349880510913}
		},
		[4] = {
			{"These fish are herbivores, primarily feeding on algae. In the wild, they play a crucial role in maintaining the health of coral reefs by grazing on algae that can otherwise overgrow and suffocate the corals.", "Continue", 126897955703139}
		},
		[5] = {
			{"Yellow Tangs have a unique defense mechanism. They possess sharp spines on either side of their tails, which they can use to fend off predators. These spines are so sharp that they can cause serious injury.", "Continue", 104724963291828}
		},
		[6] = {
			{"In addition to their bright color, Yellow Tangs are known for their social behavior. They often form schools, especially when they are young. This schooling behavior helps protect them from predators.", "Continue", 129823481570883}
		},
		[7] = {
			{"Yellow Tangs can live up to 30 years in the wild, although their lifespan in captivity is usually shorter. Proper care, including a balanced diet and a clean environment, can help them live longer in home aquariums.", "Continue", 77010308953284}
		},
		[8] = {
			{"It's a really fascinating fish, you should check it out!", "End", 95123293208167}
		}
	}
}

Npc.Options = {
	["InitialChoice"] = {"Yes, tell me!", "No thanks"},
	["Continue"] = {"Continue"},
	["End"] = {"Leave"}
}


Npc.Behavior = {
	["Yes, tell me!"] = function(ui, index, npcData)
		local nextIndex = 2
		return nextIndex
	end,

	["No thanks"] = function(ui, index, npcData)
		local nextIndex = 8
		return nextIndex
	end,

	["Continue"] = function(ui, index, npcData)
		local nextIndex
		if index == 2 then nextIndex = 3
		elseif index == 3 then nextIndex = 4
		elseif index == 4 then nextIndex = 5
		elseif index == 5 then nextIndex = 6
		elseif index == 6 then nextIndex = 7
		elseif index == 7 then nextIndex = 8
		end

		return nextIndex
	end,

	["Leave"] = function()
		return nil
	end
}

return Npc