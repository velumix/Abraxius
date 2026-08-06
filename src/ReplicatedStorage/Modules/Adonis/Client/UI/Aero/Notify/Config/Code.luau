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

	local gui = client.UI.Prepare(script.Parent.Parent)
	local frame = gui.Frame
	local frame2 = frame.Frame
	local msg = frame2.Message
	local ttl = frame2.Title

	local gIndex = data.gIndex
	local gTable = data.gTable

	local title = data.Title
	local message = data.Message
	local scroll = data.Scroll
	local tim = data.Time

	if not data.Message or not data.Title then gTable:Destroy() end

	ttl.Text = title
	msg.Text = message

	local function fadeOut()
		for i = 1,12 do
			msg.TextTransparency = msg.TextTransparency+0.05
			ttl.TextTransparency = ttl.TextTransparency+0.05
			msg.TextStrokeTransparency = msg.TextStrokeTransparency+0.05
			ttl.TextStrokeTransparency = ttl.TextStrokeTransparency+0.05
			frame2.BackgroundTransparency = frame2.BackgroundTransparency+0.05
			service.Wait("Stepped")
		end
		service.UnWrap(gui):Destroy()
	end

	gTable.CustomDestroy = function()
		fadeOut()
	end

	local log  = {
		Type = "Small Screen Message";
		Title = title;
		Message = message;
		Icon = "rbxassetid://7501175708";
		Time = os.date("%X");
		Function = nil;
	}

	table.insert(client.Variables.CommunicationsHistory, log) 
	service.Events.CommsPanel:Fire(log)

	task.spawn(function()
		local sound = Instance.new("Sound",service.LocalContainer())
		sound.SoundId = "rbxassetid://7152561753"
		sound.Volume = 0.3
		task.wait(0.1)
		sound:Play()
		task.wait(1)
		sound:Destroy()
	end)

	gTable.Ready()

	frame:TweenSize(UDim2.new(0, 350, 0, 150), Enum.EasingDirection.Out, Enum.EasingStyle.Quint, 0.2)

	if not tim then
		local _,time = message:gsub(" ","")
		time = math.clamp(time/2,4,11)+1
		task.wait(time)
	else
		task.wait(tim)
	end

	fadeOut()
end