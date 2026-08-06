local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules
local UI = require(Modules.UI)

local Npc = {}
Npc.Name = "Thomas"
Npc.Data = nil
Npc.OpenShopOnInteract = true
Npc.OpenShopSelection = "Yes, show me your store!"

Npc.Interaction = {
	["Talk"] = {
		[1] = {
			{"Welcome to my store! Would you like to browse my wares?", "InitialChoice", 134936932124567}
		}
	}
}

Npc.Options = {
	["InitialChoice"] = {"Yes, show me your store!", "No thanks, maybe later"},
}

Npc.Behavior = {
	["Yes, show me your store!"] = function(ui, index, npcData)
		local prompt = ui.CurrentPrompt
		UI.Store.ShowDocked({
			Dock = "Left",
			FocusModel = npcData.Model,
			Camera = {
				Distance = 5.5,
				Height = 1.4,
				SideOffset = 0,
				FocusHeight = 0.1,
				LookSideOffset = 4.5,
				FieldOfView = 84,
			},
			ReleaseFocusOnHide = true,
			OnHidden = function()
				if prompt then
					prompt.Enabled = true
				end
			end,
		})
		return nil
	end,

	["No thanks, maybe later"] = function(ui, index, npcData)
		ui:Leave()
		return nil
	end,
}

return Npc
