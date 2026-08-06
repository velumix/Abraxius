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
	local close = frame.Frame.Close
	local main = frame.Frame.Main
	local title = frame.Frame.Title
	local timer = frame.Frame.Timer

	local gTable = data.gTable
	local clickfunc = data.OnClick
	local closefunc = data.OnClose
	local ignorefunc = data.OnIgnore

	local name = data.Title
	local text = data.Message or data.Text or ""
	local time = data.Time
	local icon = data.Icon

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

	--client.UI.Make("NotificationHolder")
	local holder = client.UI.Get("NotificationHolder",nil,true)
	if not holder then
		local hold = service.New("ScreenGui")
		local hTable = client.UI.Register(hold)
		local frame = service.New("ScrollingFrame", hold)
		client.UI.Prepare(hold)
		hTable.Name = "NotificationHolder"
		frame.Name = "Frame"
		frame.BackgroundTransparency = 1
		frame.Size = UDim2.new(0, 200, 0.5, 0)
		frame.Position = UDim2.new(1, -210, 0.5, -10)
		frame.CanvasSize = UDim2.new(0, 0, 0, 0)
		frame.ChildAdded:Connect(function(c)
			if #frame:GetChildren() == 0 then
				frame.Visible = false
			else
				frame.Visible = true
			end
		end)

		frame.ChildRemoved:Connect(function(c)
			if #frame:GetChildren() == 0 then
				frame.Visible = false
			else
				frame.Visible = true
			end
		end)

		holder = hTable
		hTable:Ready()
	end

	local function moveGuis(holder,mod)
		local holdstuff = {}
		for i,v in pairs(holder:GetChildren()) do
			table.insert(holdstuff,1,v)
		end
		for i,v in pairs(holdstuff) do
			v.Position = UDim2.new(0,0,1,-75*(i+mod))
		end
		holder.CanvasSize=UDim2.new(0,0,0,(#holder:GetChildren()*75))
		local pos = (((#holder:GetChildren())*75) - holder.AbsoluteWindowSize.Y)
		if pos<0 then pos = 0 end
		holder.CanvasPosition = Vector2.new(0,pos)
	end

	holder = holder.Object.Frame
	title.Text = name
	frame.Name = name
	main.Text = text

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
				returner = clickfunc()
			end
			frame:Destroy()
			moveGuis(holder,0)
		end
	end)

	close.MouseButton1Click:Connect(function()
		if frame and frame.Parent then
			if closefunc then
				returner = closefunc()
			end
			gTable:Destroy()
			moveGuis(holder,0)
		end
	end)

	moveGuis(holder,1)
	frame.Parent = holder
	frame:TweenPosition(UDim2.new(0,0,1,-75),'Out','Linear',0.2)

	spawn(function()
		local sound = Instance.new("Sound",service.LocalContainer())
		if text == "Click here for commands." then
			sound.SoundId = "rbxassetid://987728667"
		elseif name == "Warning!" then
			sound.SoundId = "rbxassetid://428495297"
		else
			sound.SoundId = "rbxassetid://2275705078"
		end
		wait(0.1)
		sound:Play()
		wait(1)
		sound:Destroy()
	end)

	if time then
		timer.Visible = true
		spawn(function()
			repeat
				timer.Text = math.floor(time*100)/100
				--timer.Size=UDim2.new(0,timer.TextBounds.X,0,10)
				wait(1)
				time = time-1
			until time<=0 or not frame or not frame.Parent

			if frame and frame.Parent then
				if ignorefunc then
					returner = ignorefunc()
				end
				frame:Destroy()
				moveGuis(holder,0)
			end
		end)
	end

	repeat wait() until returner ~= nil or not frame or not frame.Parent

	return returner
end