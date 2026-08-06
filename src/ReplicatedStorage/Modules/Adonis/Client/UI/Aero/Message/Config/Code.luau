client = nil
Pcall = nil
Routine = nil
service = nil

--// All global vars will be wiped/replaced except script

return function(data, env)
	if env then
		setfenv(1, env)
	end

	local gui = client.UI.Prepare(script.Parent.Parent) -- Change it to a TextLabel to avoid chat clearing
	local playergui = service.PlayerGui
	local frame = gui.Frame
	local msg = gui.Frame.Message
	local ttl = gui.Frame.Title

	local gIndex = data.gIndex
	local gTable = data.gTable

	local title = data.Title
	local message = data.Message
	local scroll = data.Scroll
	local tim = data.Time

	if not data.Message or not data.Title then gui:Destroy() end

	ttl.Text = title
	msg.Text = message
	ttl.TextTransparency = 1
	msg.TextTransparency = 1
	ttl.TextStrokeTransparency = 1
	msg.TextStrokeTransparency = 1
	frame.BackgroundTransparency = 1


	local blur = service.New("BlurEffect")
	blur.Enabled = false
	blur.Size = 0
	blur.Parent = workspace.CurrentCamera

	local fadeSteps = 10
	local blurSize = 10
	local textFade = 0.1
	local strokeFade = 0.5
	local frameFade = 0.3

	local blurStep = blurSize/fadeSteps
	local frameStep = frameFade/fadeSteps
	local textStep = 0.1
	local strokeStep = 0.1
	local gone = false

	local function fadeIn()
		if not gone then
			blur.Enabled = true
			gTable:Ready()
			--gui.Parent = service.PlayerGui
			for i = 1,fadeSteps do
				if blur.Size<blurSize then
					blur.Size = blur.Size+blurStep
				end
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
				end
				task.wait(1/60)
			end
		end
	end

	local function fadeOut()
		if not gone then
			for i = 1,fadeSteps do
				if blur.Size>0 then
					blur.Size = blur.Size-blurStep
				end
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
				end
				task.wait(1/60)
			end
			blur.Enabled = false
			blur:Destroy()
			service.UnWrap(gui):Destroy()
			gone = true
		end
	end

	gTable.CustomDestroy = function()
		if not gone then
			gone = true
			pcall(fadeOut)
		end

		pcall(function() service.UnWrap(gui):Destroy() end)
		pcall(function() blur:Destroy() end)
	end


	--[[if not scroll then
		msg.Text = message
	else
		Routine(function()
			task.wait(0.5)
			for i = 1, #message do
				msg.Text = msg.Text .. message:sub(i,i)
				task.wait(0.05)
			end
		end)
	end--]] -- For now?

	fadeIn()
	task.wait(tim or 5)
	if not gone then
		fadeOut()
	end

	--[[

	frame.Position = UDim2.new(0.5,-175,-1.5,0)

	gui.Parent = playergui

	frame:TweenPosition(UDim2.new(0.5,-175,0.25,0),nil,nil,0.5)

	if not scroll then
		msg.Text = message
		task.wait(tim or 10)
	else
		task.wait(0.5)
		for i = 1, #message do
			msg.Text = msg.Text .. message:sub(i,i)
			task.wait(0.05)
		end
		task.wait(tim or 5)
	end

	if frame then
		frame:TweenPosition(UDim2.new(0.5,-175,-1.5,0),nil,nil,0.5)
		task.wait(1)
		gui:Destroy()
	end
	--]]
end