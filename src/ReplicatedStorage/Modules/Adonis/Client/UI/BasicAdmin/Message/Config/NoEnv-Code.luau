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

	local Title,Message = data.Title,data.Message
	if not Title or not Message then return end

	local gTable = data.gTable
	local baseClip = script.Parent.Parent.BaseClip
	local messageTemplate = baseClip.Frame
	local messageClone = messageTemplate
	messageClone.Size = UDim2.new(1,0,0,baseClip.AbsoluteSize.Y)
	messageClone.Position = UDim2.new(0,0,-1,0)
	messageClone.Parent = baseClip
	messageClone.Visible = true
	local closeButton = messageClone:WaitForChild('TextButton')
	local Top = messageClone:WaitForChild('Top')
	local Body = messageClone:WaitForChild('Body')
	local topTitle = Top:WaitForChild('Title')
	local bodyText = Body:WaitForChild('To Name Later')
	local Left = Top:WaitForChild('Left')
	local tim = data.Time
	topTitle.Text = Title
	bodyText.Text = Message
	local bodyBounds_Y = bodyText.TextBounds.Y
	if bodyBounds_Y < 30 then
		bodyBounds_Y = 30
	else
		bodyBounds_Y = bodyBounds_Y + 15
	end
	local titleSize_Y = Top.Size.Y.Offset
	messageClone.Size = UDim2.new(1,0,0,bodyBounds_Y+titleSize_Y)

	local function Resize()
		local toDisconnect
		local Success, Message = pcall(function()
			toDisconnect = gTable.BindEvent(baseClip.Changed, function(Prop)
				if Prop == "AbsoluteSize" then
					messageClone.Size = UDim2.new(1,0,0,baseClip.AbsoluteSize.Y)
					local bodyBounds_Y = bodyText.TextBounds.Y
					if bodyBounds_Y < 30 then
						bodyBounds_Y = 30
					else
						bodyBounds_Y = bodyBounds_Y + 15
					end
					local titleSize_Y = Top.Size.Y.Offset
					messageClone.Size = UDim2.new(1,0,0,bodyBounds_Y+titleSize_Y)
					if messageClone ~= nil and messageClone.Parent == baseClip then
						messageClone:TweenPosition(UDim2.new(0,0,0.5,-messageClone.Size.Y.Offset/2),'Out','Quint',0.5,true)
					else
						if toDisconnect then
							toDisconnect:Disconnect()
						end
						return
					end
				end
			end)
		end)
		if Message and toDisconnect then
			toDisconnect:Disconnect()
			return
		end
	end

	gTable.CustomDestroy = function()
		gTable.CustomDestroy = nil
		gTable.ClearEvents()

		pcall(function()
			messageClone:TweenPosition(UDim2.new(0,0,1,0),'Out','Quint',0.3,true,function(Done)
				if Done == Enum.TweenStatus.Completed and messageClone then
					messageClone:Destroy()
				elseif Done == Enum.TweenStatus.Canceled and messageClone then
					messageClone:Destroy()
				end
			end)
			wait(0.3)
		end)

		return gTable.Destroy()
	end

	gTable:Ready()
	messageClone:TweenPosition(UDim2.new(0,0,0.5,-messageClone.Size.Y.Offset/2),'Out','Quint',0.5,true,function(Status)
		if Status == Enum.TweenStatus.Completed then
			Resize()
		end
	end)

	gTable.BindEvent(closeButton.MouseButton1Click, function()
		pcall(function()
			messageClone:TweenPosition(UDim2.new(0,0,1,0),'Out','Quint',0.3,true,function(Done)
				if Done == Enum.TweenStatus.Completed and messageClone then
					messageClone:Destroy()
					gTable:Destroy()
				elseif Done == Enum.TweenStatus.Canceled and messageClone then
					messageClone:Destroy()
					gTable:Destroy()
				end
			end)
		end)
	end)

	local waitTime = tim or (#bodyText.Text*0.1)+1
	local Position_1,Position_2 = string.find(waitTime,"%p")
	if Position_1 and Position_2 then
		local followingNumbers = tonumber(string.sub(waitTime,Position_1))
		if followingNumbers >= 0.5 then
			waitTime = tonumber(string.sub(waitTime,1,Position_1))+1
		else
			waitTime = tonumber(string.sub(waitTime,1,Position_1))
		end
	end
	--[[if waitTime > 15 then
		waitTime = 15
	elseif waitTime <= 1 then
		waitTime = 2
	end]]--
	Left.Text = `{waitTime}.00`
	for i=waitTime,1,-1 do
		if not Left then break end
		Left.Text = `{i}.00`
		wait(1)
	end
	Left.Text = "Closing.."
	wait(0.3)
	if messageClone then
		pcall(function()
			messageClone:TweenPosition(UDim2.new(0,0,1,0),'Out','Quint',0.3,true,function(Done)
				if Done == Enum.TweenStatus.Completed and messageClone then
					messageClone:Destroy()
					gTable:Destroy()
				elseif Done == Enum.TweenStatus.Canceled and messageClone then
					messageClone:Destroy()
					gTable:Destroy()
				end
			end)
		end)
	end
end