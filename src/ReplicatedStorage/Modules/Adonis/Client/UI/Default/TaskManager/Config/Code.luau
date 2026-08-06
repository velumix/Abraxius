client, Pcall, Routine, service = nil, nil, nil, nil

--// All global vars will be wiped/replaced except script
local function Expand(ent, point)
	ent.MouseLeave:Connect(function(x,y)
		point.Visible = false
	end)
	
	ent.MouseMoved:Connect(function(x,y)
		point.Label.Text = ent.Desc.Value
		point.Size = UDim2.new(0, 10000, 0, 10000)
		local bounds = point.Label.TextBounds.X
		local rows = math.floor(bounds/500)
		rows = rows+1
		if rows<1 then rows = 1 end
		local newx = 500
		if bounds<500 then newx = bounds end
		point.Visible = true
		point.Size = UDim2.new(0, newx+5, 0, (rows*20)+5)
		point.Position = UDim2.new(0, x, 0, y-40-((rows*20)+5))
	end)
end


return function(data, env)
	if env then
		setfenv(1, env)
	end
	
	local gTable = data.gTable
	local gui = gTable.Object
	local drag = gui.Drag
	local Main = gui.Drag.Main
	local Close = gui.Drag.Close
	local Hide = gui.Drag.Hide
	local Search = gui.Drag.Search
	local cTab = gui.Drag.Main.ClientTab
	local sTab = gui.Drag.Main.ServerTab
	local Dragger = gui.Drag.Main.Dragger
	local cFrame = gui.Drag.Main.Client
	local sFrame = gui.Drag.Main.Server
	local Title = gui.Drag.Title
	local Entry = gui.Entry
	local Desc = gui.Desc
	
	local num = 0
	local mouse = service.Players.LocalPlayer:GetMouse()
	local nx,ny = drag.AbsoluteSize.X,Main.AbsoluteSize.Y
	local dragging = false
	local defx,defy = nx,ny
	local topText = ""
	
	local function openClient()
		sFrame.Visible = false
		cFrame.Visible = true
		cTab.BackgroundTransparency = 0
		sTab.BackgroundTransparency = 0.5
	end
	
	local function openServer()
		sFrame.Visible = true
		cFrame.Visible = false
		cTab.BackgroundTransparency = 0.5
		sTab.BackgroundTransparency = 0
	end
	
	local updateLists; updateLists = function()
		local serverTasks --= client.Remote.Get("TaskCommand","GetTasks")
		local clientTasks = service.GetTasks() --service.Threads.Tasks
		--// Unfinished
		cFrame:ClearAllChildren()
		
		local cNum = 0
		for index,task in pairs(clientTasks) do
			local new = Entry:Clone()
			local frame = new.Frame
			local status = task:Status()
			new.Parent = cFrame
			new.Visible = true
			new.Desc.Value = task.Name
			new.Position = UDim2.new(0,0,0,cNum*20)
			frame.Text.Text = tostring(task.Function)
			frame.Status.Text = status
			
			if status == "suspended" then
				frame.Resume.Text = "Resume"
			elseif status == "normal" or status == "running" then
				frame.Resume.Text = "Suspend"
			end
			
			frame.Resume.MouseButton1Down:Connect(function()
				if frame.Resume.Text == "Resume" and task:Status() == "Suspended" then
					task:Resume()
				else
					task:Pause()
				end
				wait(0.5)
				updateLists()
			end)
			
			frame.Kill.MouseButton1Down:Connect(function()
				task:Kill()
				wait(0.5)
				updateLists()
			end)
			
			frame.Stop.MouseButton1Down:Connect(function()
				task:Stop()
				wait(0.5)
				updateLists()
			end)
			
			Expand(new,Desc)
			cNum = cNum+1
		end
		
		cFrame.CanvasSize =  UDim2.new(0, 0, 0, num*20)
	end
	
	sTab.MouseButton1Down:Connect(openServer)
	cTab.MouseButton1Down:Connect(openClient)
	
	Close.MouseButton1Click:Connect(function()
		drag.Draggable = false
		drag:TweenPosition(UDim2.new(drag.Position.X.Scale, drag.Position.X.Offset, 1,0), "Out", "Sine", 0.5, true)
		wait(0.5)
		gTable:Destroy()
	end)

	drag.BackgroundColor3 = Main.BackgroundColor3
	
	Hide.MouseButton1Click:Connect(function() 
		if Main.Visible then
			Main.Visible = false
			drag.BackgroundTransparency = Main.BackgroundTransparency
			Hide.Text = "+"
		else
			Main.Visible = true
			drag.BackgroundTransparency = 1
			Hide.Text = "-"
		end
	end)
	
	mouse.Move:Connect(function(x,y) 
		if dragging then
			nx=defx+(Dragger.Position.X.Offset+20)
			ny=defy+(Dragger.Position.Y.Offset+20)
			if nx<200 then nx=200 end
			if ny<200 then ny=200 end
			drag.Size=UDim2.new(0, nx, 0, 30) 
			Main.Size=UDim2.new(1, 0, 0, ny)
			if nx<220 then
				if topText=="" then
					topText=Title.Text
				end
				Title.Text=""
			else
				if topText~="" then
					Title.Text=topText
					topText=""
				end
			end
		end
	end)
	
	Dragger.DragBegin:Connect(function(init)
		dragging = true
	end)
	
	Dragger.DragStopped:Connect(function(x,y)
		dragging = false
		defx = nx
		defy = ny
		Dragger.Position = UDim2.new(1,-20,1,-20)
	end)
	
	gTable:Ready()
	
	while wait(1) do
		updateLists()
	end
end










