local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local UI = require(ReplicatedStorage.Modules.UI)
local Tutorial = require(ReplicatedStorage.Modules.Tutorial)

local Player = Players.LocalPlayer

local Npc = {}
local Connections = {}

local TaskTracker = {
	tasks = {},
	waitingForTask = nil,
	tutorialIndex = nil,
	npcData = nil
}

local activeTutorial = nil

Npc.Name = "Jess"

Npc.Interaction = {
	["Talk"] = {
		[1] = {
			{"Hi there! I'm Jess, a marine biologist here at the Observatory. I study all the amazing fish that live in our waters! Would you like me to teach you how to scan and discover new species?", "InitialChoice", 104966351472477}
		},
		[2] = {
			{"Awesome, just follow my instructions and you'll be scanning fish in no time!", "Continue", 138397015517389}
		},
		[3] = {
			{"Alright, I'll be here if you need me.", "End"}
		},
		[4] = {
			{"First, Look at the hotbar at the bottom of your screen and select the scanner tool.", "Continue", 122901187098028}
		},
		[5] = {
			{"Now go to up to a window and try scanning a fish with your scanner!", "Continue"}
		},
		[6] = {
			{"Hold down your left mouse button and move your cursor to lock onto a species.", "Continue"}
		},
		[7] = {
			{"Now click again and connect the dots to complete your scan.", "Continue"}
		},
		[8] = {
			{"You did it! What a discovery! Would you like to try scanning another fish?", "CompletionChoice", 76050387317260}
		},
		[9] = {
			{"Great! Let me know if you need anything else — I'll be right here.", "End", 98681553820548}
		}
	}
}

Npc.Options = {
	["InitialChoice"] = {"Yes, show me!", "No, I'll explore."},
	["Continue"] = {"Continue"},
	["End"] = {"Leave"},
	["CompletionChoice"] = {"No thanks, I'm good.", "Yeah, let's try again!"}
}



local function clearConnections()
	for _, conn in pairs(Connections) do
		conn:Disconnect()
	end
	table.clear(Connections)
end

local function resetLegacy()
	TaskTracker.tasks = {}
	TaskTracker.waitingForTask = nil
	TaskTracker.tutorialIndex = nil
	TaskTracker.npcData = nil
	clearConnections()
end

local function cancelTour()
	if activeTutorial then
		if activeTutorial.Cancel and activeTutorial.Active then
			activeTutorial:Cancel()
		elseif Tutorial.CancelCurrentTutorial then
			Tutorial.CancelCurrentTutorial()
		end
		activeTutorial = nil
		resetLegacy()
	end
end

local function launchTour(skipIfCompleted)
	local tutorial = Tutorial.StartOnboardingTutorial(skipIfCompleted)
	if tutorial then
		if activeTutorial and activeTutorial ~= tutorial and activeTutorial.Cancel and activeTutorial.Active then
			activeTutorial:Cancel()
		end

		resetLegacy()
		activeTutorial = tutorial

		if tutorial.TutorialCompleted then
			tutorial.TutorialCompleted:Connect(function()
				activeTutorial = nil
				UI.Notify("Nice work! You're ready to explore the observatory.", "Success", 5)
			end)
		end

		if tutorial.TutorialCancelled then
			tutorial.TutorialCancelled:Connect(function()
				activeTutorial = nil
			end)
		end

		return tutorial
	end

	return nil
end

local function startTaskTracking(taskName, ui, nextIndex, npcData)
	TaskTracker.waitingForTask = taskName
	TaskTracker.tutorialIndex = nextIndex
	TaskTracker.npcData = npcData
	TaskTracker.tasks[taskName] = false

	if taskName == "ScannerTool" then
		listenForScannerTool(ui)
	elseif taskName == "ScanFish" then
		listenForFishScan(ui)
		listenForScanStarted(ui)
		listenForCreatureLocked(ui)
	end
end

local function UnequipTool()
	if Player.Character then
		local humanoid = Player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:UnequipTools()
		end
	end
end

local function completeTask(taskName, ui)
	if TaskTracker.tasks[taskName] ~= nil then
		TaskTracker.tasks[taskName] = true
		if TaskTracker.waitingForTask == taskName then
			if taskName == "ScannerTool" then
				startTaskTracking("ScanFish", ui, TaskTracker.tutorialIndex, TaskTracker.npcData)
			elseif taskName == "ScanFish" then
				if Connections["ScanStarted"] then
					Connections["ScanStarted"]:Disconnect()
					Connections["ScanStarted"] = nil
				end
				if Connections["CreatureLocked"] then
					Connections["CreatureLocked"]:Disconnect()
					Connections["CreatureLocked"] = nil
				end
				TaskTracker.waitingForTask = nil
				if ui.CurrentState then
					ui.CurrentState.tutorialStep = nil
				end

				ui:ReopenTutorial(TaskTracker.npcData.Model, TaskTracker.tutorialIndex)
				UnequipTool()

			end
		end
	end
end

function listenForScannerTool(ui)
	local function checkForScanner()
		if TaskTracker.tasks["ScannerTool"] == true then return true end
		if Player.Character then
			local tool = Player.Character:FindFirstChildOfClass("Tool")
			if tool and tool.Name:lower():find("scanner") then
				completeTask("ScannerTool", ui)
				return true
			end
		end
		return false
	end

	if checkForScanner() then return end

	local connection
	connection = Player.CharacterAdded:Connect(function(character)
		character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") and child.Name:lower():find("scanner") and TaskTracker.tasks["ScannerTool"] ~= true then
				completeTask("ScannerTool", ui)
				connection:Disconnect()
			end
		end)
	end)

	if Player.Character then
		Player.Character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") and child.Name:lower():find("scanner") and TaskTracker.tasks["ScannerTool"] ~= true then
				completeTask("ScannerTool", ui)
				connection:Disconnect()
			end
		end)
	end
end

function listenForFishScan(ui)
	local fishScannedConnection
	fishScannedConnection = ui.ScanController.FishScanned:Connect(function(id, fishName)
		completeTask("ScanFish", ui)
		fishScannedConnection:Disconnect()
	end)
end

function listenForScanStarted(ui)
	local scanStartedConnection
	scanStartedConnection = ui.ScanController.ScanStarted:Connect(function()
		if TaskTracker.waitingForTask == "ScanFish" then
			task.wait(1)
			UI.Notify("Great! now hold left click to lock onto a species! 🔍", "Info", 5)
		end
	end)
	Connections["ScanStarted"] = scanStartedConnection
end

function listenForCreatureLocked(ui)
	local creatureLockedConnection
	creatureLockedConnection = ui.ScanController.CreatureLocked:Connect(function(creature)
		if TaskTracker.waitingForTask == "ScanFish" then
			task.wait(1)
			UI.Notify("Perfect! Now select a dot and connect them! 🎯", "Info", 5)
			task.wait(3)
			UI.Notify("Connect all the dots to complete your scan! ✨", "Info", 5)
		end
	end)
	Connections["CreatureLocked"] = creatureLockedConnection
end

local function checkForScanner(callback)
	local function onScannerEquipped()
		callback(true)
	end

	local function ScannerInHand()
		if Player.Character then
			local tool = Player.Character:FindFirstChildOfClass("Tool")
			if tool and tool.Name:lower():find("scanner") then
				onScannerEquipped()
				return true
			end
		end
		return false
	end

	if ScannerInHand() then return end
	clearConnections()

	local function onToolAdded(child)
		if child:IsA("Tool") and child.Name:lower():find("scanner") then
			clearConnections()
			onScannerEquipped()
		end
	end

	local function onCharacter(character)
		clearConnections()
		for _, tool in character:GetChildren() do
			onToolAdded(tool)
		end
		table.insert(Connections, character.ChildAdded:Connect(onToolAdded))
	end

	if Player.Character then
		onCharacter(Player.Character)
	end
	table.insert(Connections, Player.CharacterAdded:Connect(onCharacter))
end

Npc.Behavior = {
	["Yes, show me!"] = function(ui, index, npcData)
		local tutorial = launchTour(false)
		if tutorial then
			UI.Notify("Follow the markers to get equipped. I'll be nearby if you need help!", "Info", 6)
			ui:Leave()
			return nil
		end

		if not ui.CurrentState then
			ui.CurrentState = {}
		end
		ui.CurrentState.tutorialStep = 1
		local nextIndex = 2
		return nextIndex
	end,

	["No, I'll explore."] = function(ui, index, npcData)
		if activeTutorial then
			cancelTour()
		end
		local nextIndex = 3
		return nextIndex
	end,

	["Continue"] = function(ui, index, npcData)
		if activeTutorial then
			ui:Leave()
			return nil
		end
		if index == 2 then
			local nextIndex = 4
			return nextIndex
		elseif index == 4 then
			task.wait(0.5)
			UI.Notify("Equip your scanner tool from the hotbar! 🔍", "Info", 8)

			checkForScanner(function(hasScanner)
				if hasScanner then
					task.wait(0.5)
					UI.Notify("Now go up to a window and try scanning a fish! 🐠", "Info", 8)
					startTaskTracking("ScanFish", ui, 8, npcData)
				end
			end)
			ui:Leave()
		elseif index == 6 then
			task.wait(0.5)
			UI.Notify("Now go up to a window and try scanning a fish! 🐠", "Info", 8)
			startTaskTracking("ScanFish", ui, 8, npcData)
			ui:Leave()
		elseif index == 7 then
			return 8
		end
	end,

	["No thanks, I'm good."] = function(ui, index, npcData)
		if activeTutorial then
			cancelTour()
		end
		if index == 8 then
			UI.Notify("What a Discovery! 🐠", "Success", 5)
			if ui.CurrentState then
				ui.CurrentState.tutorialStep = nil
			end
			return 9
		end
	end,

	["Yeah, let's try again!"] = function(ui, index, npcData)
		local tutorial = launchTour(false)
		if tutorial then
			UI.Notify("Let's run through the tour again. Follow the markers!", "Info", 5)
			ui:Leave()
			return nil
		end

		UI.Notify("Let's try scanning again!, Equip your scanner tool from the hotbar! 🔍", "Info", 8)
		checkForScanner(function(hasScanner)
			if hasScanner then
				task.wait(0.5)
				UI.Notify("Now go up to a window and try scanning a fish! 🐠", "Info", 8)
				startTaskTracking("ScanFish", ui, 8, npcData)
			end
		end)
		ui:Leave()
		return 6
	end

}

return Npc