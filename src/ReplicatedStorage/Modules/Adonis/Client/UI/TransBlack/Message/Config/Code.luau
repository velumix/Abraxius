client = nil
Pcall = nil
Routine = nil
service = nil

--// All global vars will be wiped/replaced except script

return function(data)
	local gui = script.Parent.Parent
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
	
	local fadeSteps = 10
	local blurSize = 10
	local textFade = 0.1
	local strokeFade = 0.5
	local frameFade = 0.3
	
	local blurStep = blurSize/fadeSteps
	local frameStep = frameFade/fadeSteps
	local textStep = 0.1
	local strokeStep = 0.1
	
	gui.Enabled = true  --// Please do not remove this. For whatever reason this doesnt' enable by itself - Eastern
	
	local function fadeIn()
		gui.Parent = service.PlayerGui
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
			end
			service.Wait("Stepped")
		end
	end
	
	local function fadeOut()
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
			end
			service.Wait("Stepped")
		end
		gui:Destroy()
	end
	
	
	local gone = false
	--gTable.CustomDestroy = function()
	--	gone = true
	--	fadeOut()
	--end
	
	
	--[[if not scroll then
		msg.Text = message
	else
		Routine(function()
			wait(0.5)
			for i = 1, #message do 
				msg.Text = msg.Text .. message:sub(i,i) 
				wait(0.05) 
			end 
		end)
	end--]] -- For now?
	
	fadeIn()
	wait(tim or 5)
	if not gone then
		fadeOut()
	end
	
	--[[
	
	frame.Position = UDim2.new(0.5,-175,-1.5,0)
	
	gui.Parent = playergui
	
	frame:TweenPosition(UDim2.new(0.5,-175,0.25,0),nil,nil,0.5)
	
	if not scroll then
		msg.Text = message
		wait(tim or 10)
	else
		wait(0.5)
		for i = 1, #message do 
			msg.Text = msg.Text .. message:sub(i,i) 
			wait(0.05) 
		end 
		wait(tim or 5) 
	end
	
	if frame then
		frame:TweenPosition(UDim2.new(0.5,-175,-1.5,0),nil,nil,0.5)
		wait(1)
		gui:Destroy()
	end
	--]]
end