local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local UI = require(Modules:WaitForChild("UI"))
local TutorialManager = require(Modules:WaitForChild("TutorialManager"))

local Tutorial = {}

local completedTutorials = {}
local LocalPlayer = Players.LocalPlayer

local function markTutorialCompleted(tutorialId)
	completedTutorials[tutorialId] = true
	print("Tutorial completed:", tutorialId)
end

function Tutorial.HasCompleted(tutorialId)
	return completedTutorials[tutorialId] == true
end

function Tutorial.StartScanningTutorial(skipIfCompleted)
	if skipIfCompleted and Tutorial.HasCompleted("ScanningTutorial") then
		UI.Notify("You've already completed this tutorial!", "Info", 3)
		return nil
	end
	local success, result = pcall(function()
		return UI.StartTutorial("ScanningTutorial")
	end)

	if not success then
		warn("Failed to start scanning tutorial:", result)
		return nil
	end

	if result then
		result.TutorialCompleted:Connect(function()
			markTutorialCompleted("ScanningTutorial")
			task.wait(2)
			UI.Notify("Don't forget to check your Encyclopedia! 📖", "Info", 5)
		end)
	end

	return result
end

function Tutorial.StartQuickScanTutorial()
	local ScanningTutorial = require(Modules.Tutorials.ScanningTutorial)
	local tutorial = ScanningTutorial.CreateQuick()
	tutorial:Start()

	tutorial.TutorialCompleted:Connect(function()
		UI.Notify("Great job! Keep exploring! 🌊", "Success", 4)
	end)

	return tutorial
end

function Tutorial.StartOnboardingTutorial(skipIfCompleted)
	if skipIfCompleted and Tutorial.HasCompleted("OnboardingTutorial") then
		UI.Notify("You've already completed the onboarding tour!", "Info", 3)
		return nil
	end

	local success, tutorial = pcall(function()
		return UI.StartTutorial("OnboardingTutorial")
	end)

	if not success then
		warn("Failed to start onboarding tutorial:", tutorial)
		return nil
	end

	if tutorial then
		tutorial.TutorialCompleted:Connect(function()
			markTutorialCompleted("OnboardingTutorial")
			UI.Notify("Nice work! You're ready to explore the observatory.", "Success", 4)
		end)
	end

	return tutorial
end

function Tutorial.NeedsScanningTutorial()
	if Tutorial.HasCompleted("ScanningTutorial") then
		return false
	end

	local character = LocalPlayer.Character
	local backpack = LocalPlayer:FindFirstChild("Backpack")

	local hasScanner = false

	if character and character:FindFirstChild("Scanner") then
		hasScanner = true
	elseif backpack and backpack:FindFirstChild("Scanner") then
		hasScanner = true
	end

	return hasScanner
end

function Tutorial.SetupAutoTutorial()
	if Tutorial.HasCompleted("ScanningTutorial") then
		return
	end

	local offered = false

	local function offerTutorial()
		if offered then return end
		offered = true
		task.wait(1)
		UI.Notify("Would you like to learn how to scan? Talk to Jess the marine biologist!", "Info", 6)
	end

	local function checkCharacter(character)
		if not character then return end
		character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") and child.Name == "Scanner" then
				offerTutorial()
			end
		end)
	end

	local backpack = LocalPlayer:WaitForChild("Backpack", 10)
	if backpack then
		backpack.ChildAdded:Connect(function(child)
			if child:IsA("Tool") and child.Name == "Scanner" then
				offerTutorial()
			end
		end)
	end

	LocalPlayer.CharacterAdded:Connect(checkCharacter)
	if LocalPlayer.Character then
		checkCharacter(LocalPlayer.Character)
	end
end

function Tutorial.CancelCurrentTutorial()
	UI.CancelAllTutorials()
	UI.Notify("Tutorial cancelled", "Info", 2)
end

function Tutorial.HighlightObject(object, duration, color)
	local Highlight = require(Modules:WaitForChild("Highlight"))

	local highlightSet = Highlight.newSet({
		Color = color or Color3.new(1, 0.8, 0),
		OutlineColor = Color3.new(1, 1, 1),
		DoesFlash = true,
		HasOutline = true,
	})

	highlightSet:Set(object)

	if duration then
		highlightSet:Expire(duration)
	end

	return highlightSet
end

function Tutorial.CreateMarker(target, icon, color, duration)
	if not UI.DirectionalMarker then
		warn("DirectionalMarker not loaded")
		return nil
	end

	local marker = UI.DirectionalMarker.Create({
		Target = target,
		Icon = icon or "➤",
		Color = color or Color3.new(1, 1, 0),
		Persistent = not duration,
	})

	if duration then
		task.delay(duration, function()
			marker:Destroy()
		end)
	end

	return marker
end

function Tutorial.ShowEncyclopediaNotification()
	UI.Notify("New discovery recorded! 🎉", "Success", 4)
	task.wait(1)
	UI.Notify("Check your Encyclopedia to learn more! 📖", "Info", 5)
end

function Tutorial.ResetProgress()
	completedTutorials = {}
	print("Tutorial progress reset")
end

function Tutorial.GetCompletedTutorials()
	return completedTutorials
end

return Tutorial
