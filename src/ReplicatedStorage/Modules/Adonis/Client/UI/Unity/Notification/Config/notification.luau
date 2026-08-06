client = nil
Pcall = nil
Routine = nil
service = nil
GetEnv = nil
gTable = nil

--// All global vars will be wiped/replaced except script

return function(data, env)
	if env then
		setfenv(1, env)
	end
	local playergui = service.PlayerGui
	local localplayer = service.Players.LocalPlayer

	local frame = script.Parent.Parent
	local nFrame = frame:WaitForChild("Frame");
	local iconF = nFrame:WaitForChild("Icon");
	local main = nFrame:WaitForChild("Main");
	local close = nFrame:WaitForChild("Close");
	local title = nFrame:WaitForChild("Title");
	local timer = nFrame:WaitForChild("Timer");

	local gTable = data.gTable
	local clickfunc = data.OnClick
	local closefunc = data.OnClose
	local ignorefunc = data.OnIgnore

	local name = data.Title
	local text = data.Message or data.Text or ""
	local time = data.Time
	local icon = data.Icon or client.MatIcons.Info

	local returner = nil

	if clickfunc and type(clickfunc)=="string" then
		clickfunc = client.Core.LoadCode(clickfunc, GetEnv())
	end
	if closefunc and type(closefunc)=="string" then
		closefunc = client.Core.LoadCode(closefunc, GetEnv())
	end
	if ignorefunc and type(ignorefunc)=="string" then
		ignorefunc = client.Core.LoadCode(ignorefunc, GetEnv())
	end

	local holder = client.UI.Get("NotificationHolder",nil,true)

	if not holder then
		client.UI.Make("NotificationHolder")
		holder = client.UI.Get("NotificationHolder",nil,true)
		holder.Object.ScrollingFrame.Active = false
	end

	holder = holder.Object.ScrollingFrame
	title.Text = name
	main.Text = text
	iconF.Image = icon

	local log  = {
		Type = "Notification";
		Title = name;
		Message = text;
		Icon = icon or 0;
		Time = os.date("%X");
		Function = clickfunc;
	}

	table.insert(client.Variables.CommunicationsHistory, log)
	service.Events.CommsPanel:Fire(log)

	main.MouseButton1Click:Connect(function()
		if frame and frame.Parent then
			if clickfunc then
				clickfunc()
			end
			frame:Destroy()
		end
	end)

	close.MouseButton1Click:Connect(function()
		if frame and frame.Parent then
			if closefunc then
				closefunc()
			end
			gTable:Destroy()
		end
	end)

	frame.Parent = holder

	task.spawn(function()
		local sound = Instance.new("Sound",service.LocalContainer())
		sound.SoundId = 'rbxassetid://203785584'--client.NotificationSound
		sound.Volume = 0.2
		sound:Play()
		wait(0.5)
		sound:Destroy()
	end)

	if time then
		timer.Visible = true
		repeat
			timer.Text = math.floor(time*100)/100
			wait(1)
			time = time-1
		until time<=0 or not frame or not frame.Parent

		if frame and frame.Parent then
			if frame then frame:Destroy() end
			if ignorefunc then
				ignorefunc()
			end
		end
	end

	return returner
end