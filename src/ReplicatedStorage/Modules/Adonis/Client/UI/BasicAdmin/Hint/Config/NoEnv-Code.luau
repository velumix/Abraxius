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

	if not data.Message then return end

	local gTable = data.gTable
	local baseClip = script.Parent.Parent.BaseClip
	local hintTemplate = baseClip.Frame
	local hintClone = hintTemplate
	local hintButton = hintClone:WaitForChild('TextButton')
	local hintTop = hintClone:WaitForChild('Top')
	local hintBody = hintClone:WaitForChild('Body')
	local hintTitleText = hintTop:WaitForChild('Title')
	local hintBodyText = hintBody:WaitForChild('To Name Later')
	baseClip.Parent.IgnoreGuiInset = not client.Variables.TopBarShift
	baseClip.Parent.ClipToDeviceSafeArea = true

	gTable.BindEvent(hintButton.MouseButton1Click, function()
		hintClone:TweenPosition(UDim2.new(0,0,0,-hintClone.AbsoluteSize.Y),'Out','Quint',0.3,true,function(Stat)
			if Stat == Enum.TweenStatus.Completed then
				hintClone:Destroy()
				gTable:Destroy()
			end
		end)

	end)

	hintTitleText.Text = data.Title or " "
	hintBodyText.Text = data.Message
	hintClone.Parent = baseClip
	hintClone.Visible = true
	hintClone.Position = UDim2.new(0,0,-1,0)
	gTable.CustomDestroy = function()
		gTable.CustomDestroy = nil
		gTable.ClearEvents()

		pcall(function()
			hintClone:TweenPosition(UDim2.new(0,0,0,-hintClone.AbsoluteSize.Y),'Out','Quint',0.3,true,function(Stat)
				if Stat == Enum.TweenStatus.Completed then
					hintClone:Destroy()
					gTable:Destroy()
				end

			end)
			wait(0.3)
		end)

		gTable:Destroy()
	end

	gTable:Ready()
	hintClone:TweenPosition(UDim2.new(0,0,0,0),'Out','Quint',0.3,true)
	local def_waitTime = (#hintBodyText.Text*0.1)+1
	local waitTime = tonumber(data.Wait or def_waitTime) or def_waitTime
	if def_waitTime <= 1 then
		def_waitTime = 2.5
	elseif def_waitTime > 10 then
		def_waitTime = 10
	end

	wait(waitTime)
	pcall(function()
		if hintClone then
			hintClone:TweenPosition(UDim2.new(0,0,0,-hintClone.AbsoluteSize.Y),'Out','Quint',0.3,true,function(Stat)
				if Stat == Enum.TweenStatus.Completed then
					hintClone:Destroy()
					gTable:Destroy()
				end
			end)
		end
	end)
end