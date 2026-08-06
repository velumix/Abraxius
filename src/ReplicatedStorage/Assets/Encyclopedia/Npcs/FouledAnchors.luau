local Npc = {}

Npc.Name = "FouledAnchors"
Npc.Data = {}

Npc.Interaction = {
	["Talk"] = {
		[1] = {
			{
				"FouledAnchors here. Welcome to the Aquatica Observatory, do you want know more about this place?",
				"InitialChoice",
			},
		},
		[2] = {
			{ "Long before the Observatory, the seamount was known only by a coordinate.", "Continue" },
		},
		[3] = {
			{
				"The seamount once supported a fragile but abundant and diverse community corals and creatures. That all changed when industrial bottom trawling swept across the region.",
				"Continue",
			},
		},
		[4] = {
			{
				"Steel nets dragged across the summit and flattened centuries of growth in days. What remained was a bare rock and a biological silence that echoed across the water column.",
				"Continue",
			},
		},
		[5] = {
			{
				"The Aquatica Observatory was concieved as an experimental intervention. A living laboratory anchored directly to the damaged seamount itself. The Observatory was designed to stay, to observe, and assist in real time.",
				"Continue",
			},
		},
		[6] = {
			{
				"The Observatory was constructed in phases: Stabilization, Seeding, Protection, and Regeneration. Many doubted it would work. Some argued the seamount was too far gone, that recovery would take centuries, not decades.",
				"Continue",
			},
		},
		[7] = {
			{
				"They were wrong. Slowly at first, life returned. Corals took hold, algae stabilized the rock, invertebrates followed. Reef fish arrived and stayed. Sharks began circling the summit again, reclaiming old routes written into instinct.",
				"Continue",
			},
		},
		[8] = {
			{
				"Today, the Aquatica Observatory overlooks a thriving, rebuilt ecosystem. One shaped by science, patience, passion, and restraint. Not a replica of the past, but a living reef adapted to a changing ocean.",
				"Continue",
			},
		},
		[9] = {
			{
				"The observatory now serves as a research hub, sanctuary, living archive, and a public interface!",
				"Continue",
			},
		},
		[10] = {
			{ "Are you excited to explore?", "CompletionChoice" },
		},
		[11] = {
			{ "Yay, can't wait to see you around.", "End" },
		},
		[12] = {
			{ "Oh well, hope you still enjoy.", "End" },
		},
	},
}

Npc.Options = {
	["InitialChoice"] = { "Yes! Tell me about it.", "I'll pass." },
	["Continue"] = { "Continue" },
	["CompletionChoice"] = { "No.", "Yes, I am excited!" },
	["End"] = { "Leave" },
}

Npc.Behavior = {
	["Yes! Tell me about it."] = function()
		return 2
	end,

	["I'll pass."] = function()
		return 10
	end,

	["Continue"] = function(_, index)
		local nextIndex = index + 1
		return nextIndex
	end,

	["Yes, I am excited!"] = function()
		return 11
	end,

	["No."] = function()
		return 12
	end,

	["Leave"] = function()
		return nil
	end,
}

return Npc
