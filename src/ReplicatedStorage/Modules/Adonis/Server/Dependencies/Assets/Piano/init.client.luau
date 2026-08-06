task.wait(0.5)
ExistingSounds = {}
Player = game:GetService("Players").LocalPlayer
Gui = script:WaitForChild("PianoGui")
Humanoid = Player.Character:FindFirstChildOfClass("Humanoid")
Tools = Instance.new("Folder",game:service("ReplicatedStorage"))
PlayingEnabled = false
PianoSounds = {
	"233836579", --C/C#
	"233844049", --D/D#
	"233845680", --E/F
	"233852841", --F#/G
	"233854135", --G#/A
	"233856105", --A#/B
}

ScriptReady = false

PianoId = nil

function Activate()
	PlayingEnabled = true
	Gui.Parent=Player.PlayerGui
	MakeKeyboardConnections()
	MakeGuiConnections()
	--SetCamera(Player.Character.Torso.CFrame)
	SetSounds(PianoSounds)
	--Player.Character.Torso.Anchored=true
	--Humanoid.PlatformStand=true
	for _, v in ipairs(Player.Backpack:GetChildren()) do
		v.Parent=Tools
	end
end

function Deactivate()
	PlayingEnabled = false
	BreakKeyboardConnections()
	BreakGuiConnections()
	--ReturnCamera()	
	--Player.Character.Torso.Anchored=false
	--Humanoid.PlatformStand=false
	for i,v in pairs(ExistingSounds) do
		if v then
			v:Stop()
			v:Destroy()
		end
	end
	for _, v in ipairs(Tools:GetChildren()) do
		v.Parent=Player.Backpack
	end
	Tools:Destroy()
	Gui.Parent=script
	task.wait(0.5)
	script:Destroy()
end

function PlayNoteClient(note)
	PlayNoteSound(note)
	HighlightPianoKey(note)
end

InputService = game:GetService("UserInputService")
Mouse = Player:GetMouse()
TextBoxFocused = false
ShiftLock = false

function LetterToNote(key, shift)
	local letterNoteMap = "1!2@34$5%6^78*9(0qQwWeErtTyYuiIoOpPasSdDfgGhHjJklLzZxcCvVbBnm"
	local capitalNumberMap = ")!@#$%^&*("
	local letter = string.char(key)
	if shift then
		if tonumber(letter) then
			-- is a number
			letter = string.sub(capitalNumberMap, tonumber(letter) + 1, tonumber(letter) + 1)
		else
			letter = string.upper(letter)
		end
	end
	local note = string.find(letterNoteMap, letter, 1, true)
	if note then
		return note
	end
end

function KeyDown(Object)
	if TextBoxFocused then return end
	local key = Object.KeyCode.Value
	local shift = InputService:IsKeyDown(304) == not ShiftLock
	if (key >= 97 and key <= 122) or  (key >= 48 and key <= 57) then
		-- a letter was pressed
		local note = LetterToNote(key, shift)
		if note then PlayNoteClient(note) end
	elseif key == 8 then
		-- backspace was pressed
		Deactivate()
		
	elseif key == "s" then
		-- space was pressed --changed to S
		ToggleSheets()
	elseif key == 13 then
		-- return was pressed
		ToggleCaps()
	end
end

function Input(Object)
	local type = Object.UserInputType.Name
	local state = Object.UserInputState.Name -- in case I ever add input types
	if type == "Keyboard" then
		if state == "Begin" then
			KeyDown(Object)
		end
	end
end

function TextFocus()
	TextBoxFocused = true
end
function TextUnfocus()
	TextBoxFocused = false
end

KeyboardConnection = nil
JumpConnection = nil
FocusConnection = InputService.TextBoxFocused:Connect(TextFocus) --always needs to be connected
UnfocusConnection = InputService.TextBoxFocusReleased:Connect(TextUnfocus)

function MakeKeyboardConnections()
	KeyboardConnection = InputService.InputBegan:Connect(Input)
	
end
function BreakKeyboardConnections()
	KeyboardConnection:Disconnect()
end

PianoGui = Gui.PianoGui
SheetsGui = Gui:FindFirstChild("SheetsGui")
SheetsVisible = false

function ShowSheets()
	SheetsGui:TweenPosition(
		UDim2.new(0.5, -380, 1, -610),
		Enum.EasingDirection.Out,
		Enum.EasingStyle.Sine,
		.5,
		true
	)
end
function HideSheets()
	SheetsGui:TweenPosition(
		UDim2.new(0.5, -380, 1, 0),
		Enum.EasingDirection.Out,
		Enum.EasingStyle.Sine,
		.5,
		true
	)
end
function ToggleSheets()
	SheetsVisible = not SheetsVisible
	if SheetsVisible then
		ShowSheets()
	else
		HideSheets()
	end
end

function IsBlack(note)
	if note%12 == 2 or note%12 == 4 or note%12 == 7 or note%12 == 9 or note%12 == 11 then
		return true
	end
end

function HighlightPianoKey(note)
	local keyGui = PianoGui.Keys[note]
	if IsBlack(note) then
		keyGui.BackgroundColor3 = Color3.new(50/255, 50/255, 50/255)
	else
		keyGui.BackgroundColor3 = Color3.new(200/255, 200/255, 200/255)
	end
	task.delay(.5, function() RestorePianoKey(note) end)
end

function RestorePianoKey(note)
	local keyGui = PianoGui.Keys[note]
	if IsBlack(note) then
		keyGui.BackgroundColor3 = Color3.new(0, 0, 0)
	else
		keyGui.BackgroundColor3 = Color3.new(1, 1, 1)
	end
end

function PianoKeyPressed(Object, note)
	local type = Object.UserInputType.Name
	if type == "MouseButton1" or type == "Touch" then
		PlayNoteClient(note)
	end
end

function ExitButtonPressed(Object)
	local type = Object.UserInputType.Name
	if type == "MouseButton1" or type == "Touch" then
		Deactivate()
	end
end

function SheetsButtonPressed(Object)
	local type = Object.UserInputType.Name
	if type == "MouseButton1" or type == "Touch" then
		ToggleSheets()
	end
end

function SheetsEdited(property)
	if property == "Text" then
		local bounds = SheetsGui.Sheet.ScrollingFrame.TextBox.TextBounds
		--SheetsGui.Sheet.ScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(14, bounds.Y))
	end
end

function ToggleCaps()
	ShiftLock = not ShiftLock
	if ShiftLock then
		PianoGui.CapsButton.BackgroundColor3 = Color3.new(1, 170/255, 0)
		PianoGui.CapsButton.BorderColor3 = Color3.new(154/255, 103/255, 0)
		PianoGui.CapsButton.TextColor3 = Color3.new(1, 1, 1)
	else
		PianoGui.CapsButton.BackgroundColor3 = Color3.new(140/255, 140/255, 140/255)
		PianoGui.CapsButton.BorderColor3 = Color3.new(68/255, 68/255, 68/255)
		PianoGui.CapsButton.TextColor3 = Color3.new(180/255, 180/255, 180/255)
	end
end

function CapsButtonPressed(Object)
	local type = Object.UserInputType.Name
	if type == "MouseButton1" or type == "Touch" then
		ToggleCaps()
	end
end

PianoKeysConnections = {}
ExitButtonConnection = nil
SheetsButtonConnection = nil
SheetsEditedConnection = nil
CapsButtonConnection = nil

function MakeGuiConnections()
	for i, v in pairs(PianoGui.Keys:GetChildren()) do
		PianoKeysConnections[i] = v.InputBegan:Connect(function(Object) PianoKeyPressed(Object, tonumber(v.Name)) end)
	end
	PianoGui.Buy.MouseButton1Click:Connect(function() game:service("MarketplaceService"):PromptPurchase(Player,254415530) end)
	PianoGui.Teleport.MouseButton1Click:Connect(function() game:service("TeleportService"):Teleport(233727153) end)
	ExitButtonConnection = PianoGui.ExitButton.InputBegan:Connect(ExitButtonPressed)
	SheetsButtonConnection = PianoGui.SheetsButton.InputBegan:Connect(SheetsButtonPressed)
	--SheetsEditedConnection = SheetsGui.Sheet.ScrollingFrame.TextBox.Changed:Connect(SheetsEdited)
	CapsButtonConnection = PianoGui.CapsButton.InputBegan:Connect(CapsButtonPressed)
end
function BreakGuiConnections()
	for i, v in pairs(PianoKeysConnections) do
		v:Disconnect()
	end
	
	ExitButtonConnection:Disconnect()
	SheetsButtonConnection:Disconnect()
	--SheetsEditedConnection:Disconnect()
	CapsButtonConnection:Disconnect()
end

ContentProvider = game:GetService("ContentProvider")

LocalSounds = {
	"233836579", --C/C#
	"233844049", --D/D#
	"233845680", --E/F
	"233852841", --F#/G
	"233854135", --G#/A
	"233856105", --A#/B
}

SoundFolder = script.SoundFolder

SoundFolder.Parent = game:GetService("Players").LocalPlayer.Character

function PreloadAudio(sounds)
	for i, v in pairs(sounds) do
		ContentProvider:Preload(`http://www.roblox.com/asset/?id={v}`)
	end
end
function SetSounds(sounds)
	PreloadAudio(sounds)
	LocalSounds = sounds
end
function PlayNoteSound(note, source, range, sounds)
	
	local SoundList = sounds or LocalSounds
	
	local note2 = (note - 1)%12 + 1	-- Which note? (1-12)
	
	local octave = math.ceil(note/12) -- Which octave?
	
	local sound = math.ceil(note2/2) -- Which audio?
	
	local offset = 16 * (octave - 1) + 8 * (1 - note2%2) -- How far in audio?
	
	local audio = Instance.new("Sound", SoundFolder)-- Create the audio
	audio.SoundId = `https://roblox.com/asset/?id={SoundList[sound]}` -- Give its sound
	audio.Volume = 1
	
	if source then
		local a = 1/range^2
		local distance = (workspace.CurrentCamera.CFrame.p - source).Magnitude
		local volume = -a*distance^2 + 1
		if volume < 0.05 then
			audio:Destroy()
			return
		end
		audio.Volume = volume
	end--]]
	audio.TimePosition = offset + (octave - .9)/15 -- set the time position
	audio:Play() -- Play the audio
	
	table.insert(ExistingSounds, 1, audio)
	if #ExistingSounds >= 10 then
		ExistingSounds[10]:Stop() -- limit the number of playing sounds!
		ExistingSounds[10] = nil
	end
	
	task.delay(4, function() audio:Stop() audio:Destroy() end ) -- remove the audio in 4 seconds, enough time for it to play
end

Camera = workspace.CurrentCamera


function SetCamera(cframe)
	Camera.CameraType = Enum.CameraType.Scriptable
	Camera:Interpolate(cframe, cframe + cframe.lookVector, .5)
	--Camera.CFrame = cframe
end
function ReturnCamera()
	Camera.CameraType = Enum.CameraType.Custom
end

ScriptReady = true
Humanoid.Died:Connect(Deactivate)
Activate()


