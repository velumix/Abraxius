client = nil
Pcall = nil
Routine = nil
service = nil

--// All global vars will be wiped/replaced except script

return function(data, env)
	if env then
		setfenv(1, env)
	end

	local gui = script.Parent.Parent--client.UI.Prepare(script.Parent.Parent)
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

	local gone = false

	if not data.Message or not data.Title then gTable:Destroy() end

	ttl.Text = title
	msg.Text = message
	ttl.TextTransparency = 1
	msg.TextTransparency = 1
	ttl.TextStrokeTransparency = 1
	msg.TextStrokeTransparency = 1
	frame.BackgroundTransparency = 1

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

	local fadeSteps = 10
	local blurSize = 10
	local textFade = 0.1
	local strokeFade = 0.5
	local frameFade = 0.3

	local blurStep = blurSize/fadeSteps
	local frameStep = frameFade/fadeSteps
	local textStep = 0.1
	local strokeStep = 0.1

	local function fadeIn()
		gTable:Ready()
		for i = 1,fadeSteps do
			if msg.TextTransparency>textFade then
				msg.TextTransparency = msg.TextTransparency-textStep
				ttl.TextTransparency = ttl.TextTransparency-textStep
			end
			if msg.TextStrokeTransparency>strokeFade then
				msg.TextStrokeTransparency = msg.TextStrokeTransparency-strokeStep
				ttl.TextStrokeTransparency = ttl.TextStrokeTransparency-strokeStep
			end
			if frame.BackgroundTransparency>frameFade then
				frame.BackgroundTransparency = frame.BackgroundTransparency-frameStep
				frame2.BackgroundTransparency = frame.BackgroundTransparency
			end
			service.Wait("Stepped")
		end
	end

	local function fadeOut()
		if not gone then
			gone = true
			for i = 1,fadeSteps do
				if msg.TextTransparency<1 then
					msg.TextTransparency = msg.TextTransparency+textStep
					ttl.TextTransparency = ttl.TextTransparency+textStep
				end
				if msg.TextStrokeTransparency<1 then
					msg.TextStrokeTransparency = msg.TextStrokeTransparency+strokeStep
					ttl.TextStrokeTransparency = ttl.TextStrokeTransparency+strokeStep
				end
				if frame.BackgroundTransparency<1 then
					frame.BackgroundTransparency = frame.BackgroundTransparency+frameStep
					frame2.BackgroundTransparency = frame.BackgroundTransparency
				end
				service.Wait("Stepped")
			end
			service.UnWrap(gui):Destroy()
		end
	end

	gTable.CustomDestroy = function()
		fadeOut()
	end

	fadeIn()
	if not tim then
		local _,time = message:gsub(" ","")
		time = math.clamp(time/2,4,11)+1
		wait(time)
	else
		wait(tim)
	end
	if not gone then
		fadeOut()
	end
end