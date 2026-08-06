client = nil
Pcall = nil
Routine = nil
service = nil
gTable = nil

--// All global vars will be wiped/replaced except script
--// All guis are autonamed client.Variables.CodeName..gui.Name
--// Be sure to update the console gui's code if you change stuff

return function(data, env)
	if env then
		setfenv(1, env)
	end

	if not data.Question then return end

	local gTable = data.gTable
	local baseClip = script.Parent.Parent.BaseClip
	local duration = data.Duration or data.Timeout

	local toReturn
	local confirmationTemplate = baseClip.Frame
	local confirmationClone = confirmationTemplate
	confirmationClone.Parent = baseClip
	confirmationClone.Position = UDim2.new(0.5,-210,0,-confirmationClone.Size.Y.Offset)
	confirmationClone.Visible = true
	local Body = confirmationClone:WaitForChild('Body')
	local Options = Body:WaitForChild('Options')
	local Confirm,Cancel = Options:WaitForChild('Confirm'),Options:WaitForChild('Cancel')
	local commandText = Body:WaitForChild('Command')
	local title = confirmationTemplate.Top.Title

	commandText.Text = data.Subtitle or " "
	Body.Ques.Text = data.Question or "Unknown"
	title.Text = data.Title or "Yes/No Prompt"

	Body.Options.Cancel.Text = data.No or "No"
	Body.Options.Confirm.Text = data.Yes or "Yes"

	gTable:Ready()

	gTable.CustomDestroy = function()
		gTable.CustomDestroy = nil
		gTable.ClearEvents()
		if toReturn == nil then toReturn = data.No or "No" end

		pcall(function()
			confirmationClone:TweenPosition(UDim2.new(0.5,-210,1,0),"Out",'Quint',0.3,true,function(Stat)
				if Stat == Enum.TweenStatus.Completed then
					confirmationClone:Destroy()
				end
			end)

			wait(0.3)
		end)

		gTable:Destroy()
	end

	confirmationClone:TweenPosition(UDim2.new(0.5,-210,0.5,-70),"Out",'Quint',0.3,true)
	local Confirming; Confirming = gTable.BindEvent(Confirm.MouseButton1Click, function()
		Confirming:Disconnect()
		confirmationClone:TweenPosition(UDim2.new(0.5,-210,1,0),"Out",'Quint',0.3,true,function(Stat)
			if Stat == Enum.TweenStatus.Completed then
				confirmationClone:Destroy()
			end
		end)

		toReturn = data.Yes or "Yes"
		wait(0.3)
		gTable:Destroy()
	end)

	local Cancelling; Cancelling = gTable.BindEvent(Cancel.MouseButton1Click, function()
		Cancelling:Disconnect()
		confirmationClone:TweenPosition(UDim2.new(0.5,-210,1,0),"Out",'Quint',0.3,true,function(Stat)
			if Stat == Enum.TweenStatus.Completed then
				confirmationClone:Destroy()
			end
		end)
		toReturn = data.No or "No"
		wait(0.3)
		gTable:Destroy()
	end)

	local start = os.clock()
	repeat
		wait()
	until toReturn ~= nil or (duration and (os.clock()-duration) > duration)
	if toReturn == nil then toReturn = false end

	return toReturn
end