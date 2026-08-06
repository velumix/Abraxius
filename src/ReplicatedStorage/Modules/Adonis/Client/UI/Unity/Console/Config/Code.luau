client = nil
Pcall = nil
Routine = nil
service = nil
gTable = nil

--// All global vars will be wiped/replaced except script
--// All guis are autonamed codeName..gui.Name

return function(data, env)
	if env then
		setfenv(1, env)
	end
	local player = service.Players.LocalPlayer
	local playergui = player.PlayerGui
	local gui = script.Parent.Parent
	local frame = gui.Frame
	local text = gui.Frame.TextBox
	local scroll = gui.Frame.ScrollingFrame
	local players = gui.Frame.PlayerList
	local entry = gui.Entry
	local BindEvent = gTable.BindEvent

	local opened = false
	local scrolling = false
	local debounce = false
	local settings = client.Remote.Get("Setting",{"SplitKey","ConsoleKeyCode","BatchKey","Prefix"})
	local splitKey = settings.SplitKey
	local consoleKey = settings.ConsoleKeyCode
	local batchKey = settings.BatchKey
	local prefix = settings.Prefix
	local commands = client.Remote.Get('FormattedCommands') or {}

	local tweenInfo = TweenInfo.new(0.20)----service.SafeTweenSize(frame,UDim2.new(1,0,0,40),nil,nil,0.3,nil,function() if scrollOpen then frame.Size = UDim2.new(1,0,0,140) end end)
	local scrollOpenTween = service.TweenService:Create(frame, tweenInfo, {
		Size = UDim2.new(1, 0, 0, 140);
	})

	local scrollCloseTween = service.TweenService:Create(frame, tweenInfo, {
		Size = UDim2.new(1, 0, 0, 40);
	})

	local consoleOpenTween = service.TweenService:Create(frame, tweenInfo, {
		Position = UDim2.new(0, 0, 0.02, 0);
	})

	local consoleCloseTween = service.TweenService:Create(frame, tweenInfo, {
		Position = UDim2.new(0, 0, 0, -200);
	})

	frame.Position = UDim2.new(0,0,0,-200)
	frame.Visible = false
	frame.Size = UDim2.new(1,0,0,40)
	scroll.Visible = false

	if client.Variables.ConsoleOpen then
		if client.Variables.ChatEnabled then
			service.StarterGui:SetCoreGuiEnabled("Chat",true)
		end

		if client.Variables.PlayerListEnabled then
			service.StarterGui:SetCoreGuiEnabled('PlayerList',true)
		end
		if client.UI.Get("Notif") then
			client.UI.Get("Notif",nil,true).Object.LABEL.Visible = true
		end

		local scr = client.UI.Get("Chat",nil,true)
		if scr then scr.Object.Drag.Visible = true end

		local scr = client.UI.Get("PlayerList",nil,true)
		if scr then scr.Object.Drag.Visible = true end

		local scr = client.UI.Get("HintHolder",nil,true)
		if scr then scr.Object.Frame.Visible = true end
	end

	client.Variables.ChatEnabled = service.StarterGui:GetCoreGuiEnabled("Chat")
	client.Variables.PlayerListEnabled = service.StarterGui:GetCoreGuiEnabled('PlayerList')

	local function close()
		if gui:IsDescendantOf(game) and not debounce then
			debounce = true
			scroll:ClearAllChildren()
			scroll.CanvasSize = UDim2.new(0,0,0,0)
			scroll.ScrollingEnabled = false
			frame.Size = UDim2.new(1,0,0,40)
			scroll.Visible = false
			players.Visible = false
			scrollOpen = false

			if client.Variables.ChatEnabled then
				service.StarterGui:SetCoreGuiEnabled("Chat",true)
			end

			if client.Variables.PlayerListEnabled then
				service.StarterGui:SetCoreGuiEnabled('PlayerList',true)
			end

			if client.UI.Get("Notif") then
				client.UI.Get("Notif",nil,true).Object.LABEL.Visible = true
			end

			local scr = client.UI.Get("Chat",nil,true)
			if scr then scr.Object.Drag.Visible = true end

			local scr = client.UI.Get("PlayerList",nil,true)
			if scr then scr.Object.Drag.Visible = true end

			local scr = client.UI.Get("HintHolder",nil,true)
			if scr then scr.Object.Frame.Visible = true end

			consoleCloseTween:Play();
			--service.SafeTweenPos(frame,UDim2.new(0,0,0,-200),'Out','Linear',0.2,true)
			--frame:TweenPosition(UDim2.new(0,0,0,-200),'Out','Linear',0.2,true)
			debounce = false
			opened = false
		end
	end

	local function open()
		if gui:IsDescendantOf(game) and not debounce then
			debounce = true
			client.Variables.ChatEnabled = service.StarterGui:GetCoreGuiEnabled("Chat")
			client.Variables.PlayerListEnabled = service.StarterGui:GetCoreGuiEnabled('PlayerList')

			service.StarterGui:SetCoreGuiEnabled("Chat",false)
			service.StarterGui:SetCoreGuiEnabled('PlayerList',false)

			scroll.ScrollingEnabled = true
			players.ScrollingEnabled = true

			if client.UI.Get("Notif") then
				client.UI.Get("Notif",nil,true).Object.LABEL.Visible = false
			end

			local scr = client.UI.Get("Chat",nil,true)
			if scr then scr.Object.Drag.Visible = false end

			local scr = client.UI.Get("PlayerList",nil,true)
			if scr then scr.Object.Drag.Visible = false end

			local scr = client.UI.Get("HintHolder",nil,true)
			if scr then scr.Object.Frame.Visible = false end

			consoleOpenTween:Play();

			frame.Size = UDim2.new(1,0,0,40)
			scroll.Visible = false
			players.Visible = false
			scrollOpen = false
			text.Text = ''
			frame.Visible = true
			frame.Position = UDim2.new(0,0,0,0)
			text:CaptureFocus()
			text.Text = ''
			wait()
			text.Text = ''
			debounce = false
			opened = true
		end
	end

	local function isInConsoleBounds(pos) -- input.Position
		for i,v in ipairs(playergui:GetGuiObjectsAtPosition(pos.X, pos.Y)) do
			if v == gui or v == gui.Frame then return true end
		end
		return false
	end

	text.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			if text.Text~='' and string.len(text.Text)>1 then
				client.Remote.Send('ProcessCommand',text.Text)
			end
			close()
		elseif not isInConsoleBounds(player:GetMouse()) then
			close()
		end
	end)

	text.Changed:Connect(function(c)
		if c == 'Text' and text.Text ~= '' and open then
			if string.sub(text.Text, string.len(text.Text)) == "	" then
				if players:FindFirstChild("Entry 0") then
					local args = string.split(text.Text, splitKey)
					args[#args] = nil
					local textWithoutLastArg = table.concat(args, splitKey)

					if textWithoutLastArg ~= "" then
						textWithoutLastArg ..= splitKey
					end

					text.Text = textWithoutLastArg .. players["Entry 0"].Text .. " "
				elseif scroll:FindFirstChild("Entry 0") then
					text.Text = string.split(scroll["Entry 0"].Text, "<")[1]
				else
					text.Text = text.Text..prefix
				end
				text.CursorPosition = string.len(text.Text) + 1
				text.Text = string.gsub(text.Text, "	", "")
			end
			scroll:ClearAllChildren()
			players:ClearAllChildren()

			local nText = text.Text
			if string.match(nText,`.*{batchKey}([^']+)`) then
				nText = string.match(nText,`.*{batchKey}([^']+)`)
				nText = string.match(nText,"^%s*(.-)%s*$")
			end

			local pNum = 0
			local pMatch = string.match(nText,`.+{splitKey}(.*)$`)
			for i,v in next,service.Players:GetPlayers() do
				if (pMatch and string.sub(string.lower(tostring(v)),1,#pMatch) == string.lower(pMatch)) or string.match(nText,`{splitKey}$`) then
					local new = entry:Clone()
					new.Text = tostring(v)
					new.Name = `Entry {pNum}`
					new.TextXAlignment = "Right"
					new.Visible = true
					new.Parent = players
					new.Position = UDim2.new(0,0,0,20*pNum)
					new.Activated:Connect(function()
						text.Text = text.Text..tostring(v)
						text:CaptureFocus()
					end)
					pNum = pNum+1
				end
			end

			players.CanvasSize = UDim2.new(0,0,0,pNum*20)

			local num = 0
			for i,v in next,commands do
				if string.sub(string.lower(v),1,#nText) == string.lower(nText) or string.find(string.lower(v), string.match(string.lower(nText),`^(.-){splitKey}`) or string.lower(nText), 1, true) then
					if not scrollOpen then
						scrollOpenTween:Play();
						--frame.Size = UDim2.new(1,0,0,140)
						scroll.Visible = true
						players.Visible = true
						scrollOpen = true
					end
					local b = entry:Clone()
					b.Visible = true
					b.Parent = scroll
					b.Text = v
					b.Name = `Entry {num}`
					b.Position = UDim2.new(0,0,0,20*num)
					b.Activated:Connect(function()
						text.Text = b.Text:gsub("<.->", "")
						text:CaptureFocus()
					end)
					num = num+1
				end
			end
			local temptween = service.TweenService:Create(frame, tweenInfo, {
				Size =  UDim2.new(1, 0, 0, math.clamp((num*20)+40, 40, 140));
			})

			local temptween1 = service.TweenService:Create(scroll, tweenInfo, {
				CanvasSize = UDim2.new(0,0,0,num*20);
			})

			temptween:Play(); 			temptween1:Play()

		elseif c == 'Text' and text.Text == '' and opened then
			scrollCloseTween:Play();
			--service.SafeTweenSize(frame,UDim2.new(1,0,0,40),nil,nil,0.3,nil,function() if scrollOpen then frame.Size = UDim2.new(1,0,0,140) end end)
			scroll.Visible = false
			players.Visible = false
			scrollOpen = false
			scroll:ClearAllChildren()
			scroll.CanvasSize = UDim2.new(0,0,0,0)
		end
	end)

	BindEvent(service.Events.ToggleConsole, function()
		if opened then
			close()
		else
			open()
		end
		client.Variables.ConsoleOpen = opened
	end)

	BindEvent(service.UserInputService.InputBegan, function(InputObject, gameProcessedEvent)
		local textbox = service.UserInputService:GetFocusedTextBox()
		if not textbox and not gameProcessedEvent and rawequal(InputObject.UserInputType, Enum.UserInputType.Keyboard) and InputObject.KeyCode.Name == (client.Variables.CustomConsoleKey or consoleKey) then
			service.Events.ToggleConsole:Fire()
		end
	end)

	gTable:Ready()
end