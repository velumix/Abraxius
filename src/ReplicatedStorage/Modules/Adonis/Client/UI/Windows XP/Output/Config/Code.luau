client = nil
Pcall = nil
Routine = nil
service = nil
gTable = nil

--// All global vars will be wiped/replaced except script

return function(data, env)
	if env then
		setfenv(1, env)
	end

	local playergui = service.PlayerGui
	local localplayer = service.Players.LocalPlayer
	local scr = client.UI.Prepare(script.Parent.Parent)
	local window = scr.Window
	local errorTextBox = window.Main.ScrollingFrame.ErrorText
	local titleTextBox = window.Title
	local message = data.Message
	local title = data.Title
	local color = data.Color

	local found = client.UI.Get("Output")
	if found then
		for _,v in found do
			local p = v.Object
			if p and p.Parent then
				p.Window.Position = UDim2.new(0.5, 0, 0.5, p.Window.Position.Y.Offset+160)
			end
		end
	end

	if title and title ~= "" then 
		titleTextBox.Text = title else titleTextBox.Text = "Error" 
	end

	errorTextBox.Text = message
	if color then
		errorTextBox.TextColor3 = color
	end

	window.Close.MouseButton1Down:Connect(function()
		gTable.Destroy()
	end)

	spawn(function()
		local sound = Instance.new("Sound",service.LocalContainer())
		sound.SoundId = "rbxassetid://160715357"
		sound.Volume = 2
		sound:Play()
		task.wait(0.8)
		sound:Destroy()
	end)

	gTable.Ready()
	task.wait(5)
	gTable.Destroy()
end