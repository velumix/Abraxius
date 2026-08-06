client = nil
Pcall = nil
Routine = nil
service = nil
gTable = nil

--// All global vars will be wiped/replaced except script
--// All guis are autonamed client.Variables.CodeName..gui.Name

return function(data, env)
	if env then
		setfenv(1, env)
	end

	local gui = script.Parent.Parent
	local playergui = service.PlayerGui
	local str = data.Message
	local time = data.Time or 15

	--client.UI.Make("HintHolder")
	local container = client.UI.Get("HintHolder",nil,true)
	if not container then
		local holder = service.New("ScreenGui")
		holder.IgnoreGuiInset = not client.Variables.TopBarShift
		holder.ClipToDeviceSafeArea = true
		local hTable = client.UI.Register(holder)
		local frame = service.New("ScrollingFrame", holder)
		client.UI.Prepare(holder)
		hTable.Name = "HintHolder"
		frame.Name = "Frame"
		frame.BackgroundTransparency = 1
		frame.Size = UDim2.new(1, 0, 0,150)
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

		container = hTable
		hTable:Ready()
	end
	container = container.Object.Frame

	--// First things first account for notif :)
	local notif = client.UI.Get("Notif")

	container.Position = UDim2.new(0, 0, 0, (notif and 30 or 0))

	local children = container:children()

	gui.Position = UDim2.new(0,0,0,-100)
	gui.Frame.msg.Text = str
	local bounds = gui.Frame.msg.TextBounds.X

	spawn(function()
		local sound = Instance.new("Sound",service.LocalContainer())
		sound.SoundId = "rbxassetid://489390072"
		wait(0.1)
		sound:Play()
		wait(0.8)
		sound:Destroy()
	end)

	local function moveGuis(m,ignore)
		m = m or 0
		local max = #container:children()
		for i,v in pairs(container:children()) do
			if v~=ignore then
				local y = (i+m)*28
				v.Position = UDim2.new(0,0,0,y)
				if i~=max then v.Size = UDim2.new(1,0,0,28) end
			end
		end
	end

	local lom = -1
	moveGuis(-1)
	gui.Parent = container
	if #container:children()>5 then lom = -2 end
	UDim2.new(0,0,0,(#container:children()+lom)*28)
	moveGuis(-1)
	--gui:TweenPosition(UDim2.new(0,0,0,(#container:children()+lom)*28),nil,nil,0.3,true,function() if gui and gui.Parent then moveGuis(-1) end end)

	if #container:children()>5 then
		local gui = container:children()[1]
		moveGuis(-2,gui)
		gui:Destroy()
		--gui:TweenPosition(UDim2.new(0,0,0,-100),nil,nil,0.2,true,function() if gui and gui.Parent then gui:Destroy() end end)
	end

	wait(data.Time or 5)

	if gui and gui.Parent then
		moveGuis(-2,gui)
		gui:Destroy()
		--gui:TweenPosition(UDim2.new(0,0,0,-100),nil,nil,0.2,true,function() if gui and gui.Parent then gui:Destroy() end end)
	end
end