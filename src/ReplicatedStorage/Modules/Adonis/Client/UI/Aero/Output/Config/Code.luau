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
	local main = scr.Main
	local t1 = main.Title
	local t2 = main.Message
	local msg = data.Message
	local title = data.Title
	local color = data.Color

	local found = client.UI.Get("Output")
	if found then
		for i,v in found do
			local p = v.Object
			if p and p.Parent then
				p.Main.Position = UDim2.new(0, 0, 0.35, p.Main.Position.Y.Offset+50)
			end
		end
	end
	t2.Text = msg
	if color then
		t2.TextColor3 = color
	end

	task.spawn(function()
		local sound = Instance.new("Sound",service.LocalContainer())
		sound.SoundId = "rbxassetid://7152562261"
		sound.Volume = 0.1
		sound:Play()
		task.wait(0.8)
		sound:Destroy()
	end)

	main.Size = UDim2.new(1, 0, 0, 0)
	gTable.Ready()
	main:TweenSize(UDim2.new(1, 0, 0, 50), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.1)
	task.wait(5)
	gTable.Destroy()
end