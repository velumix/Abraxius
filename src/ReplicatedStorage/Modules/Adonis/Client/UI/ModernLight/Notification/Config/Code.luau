export type NotificationProps = {
	OnClick: () -> nil;
	OnClose: () -> nil;
	OnIgnore: () -> nil;
	Title: string?;
	Message: string?;
	Text: string?;
	Time: number?;
	Icon: string?;
}

return function(data: NotificationProps, env)

	if env then
		setfenv(1, env)
	end

	local NotificationFrame = script.Parent.Parent
	local BodyTextLabel = NotificationFrame.Content.Body
	local Buttons = NotificationFrame.Buttons
	local ContentFrame = NotificationFrame.Content
	local TitleFrame = NotificationFrame.Title
	local TimerTextLabel = TitleFrame.Folder.Timer

	local gIndex = data.gIndex
	local gTable = data.gTable

	data.Message = data.Message or data.Text

	if data.OnClick and type(data.OnClick)=="string" then
		data.OnClick = client.Core.LoadCode(data.OnClick, GetEnv())
	end
	if data.OnClose and type(data.OnClose)=="string" then
		data.OnClose = client.Core.LoadCode(data.OnClose, GetEnv())
	end
	if data.OnIgnore and type(data.OnIgnore)=="string" then
		data.OnIgnore = client.Core.LoadCode(data.OnIgnore, GetEnv())
	end

	if data.Message then
		BodyTextLabel.Visible = true
		BodyTextLabel.Text = data.Message
	else
		BodyTextLabel.Visible = false
	end

	TitleFrame.Title.Text = data.Title or "Adonis"

	local log = {
		Type = "Notification";
		Title = data.Title;
		Message = data.Message;
		Icon = data.Icon or 0;
		Time = os.date("%X");
		Function = data.OnClick;
	}

	table.insert(client.Variables.CommunicationsHistory, log) 
	service.Events.CommsPanel:Fire(log)

	local clickResultBindable = Instance.new("BindableEvent")
	local timeThread = nil
	
	TitleFrame.Folder.Close.Visible = true
	TitleFrame.Folder.Close.MouseButton1Click:Connect(function()

		if timeThread then
			timeThread = task.cancel(timeThread)
		end

		NotificationFrame.Parent = nil
		clickResultBindable:Fire(data.OnClose and data.OnClose() or nil)
	end)

	if data.OnClick or data.OnClose then
		Buttons.Visible = true

		if data.OnClick then
			Buttons.Primary.Text = "Open"
			Buttons.Primary.MouseButton1Click:Connect(function()

				if timeThread then
					timeThread = task.cancel(timeThread)
				end

				clickResultBindable:Fire(data.OnClick())
			end)
		else
			Buttons.Primary.Visible = false
		end

		if data.OnClose then

			Buttons.Secondary.Text = "Dismiss"
			Buttons.Secondary.MouseButton1Click:Connect(function()

				if timeThread then
					timeThread = task.cancel(timeThread)
				end
				
				NotificationFrame.Parent = nil
				clickResultBindable:Fire(data.OnClose())
			end)
		else
			TitleFrame.Folder.Close.Visible = false
			Buttons.Secondary.Visible = false
		end

		if (data.OnClick and not data.OnClose) or (data.OnClose and not data.OnClick) then
			Buttons.UIGridLayout.CellSize = UDim2.new(UDim.new(1, 0), Buttons.UIGridLayout.CellSize.Height)
		end

	else
		Buttons.Visible = false
	end

	if data.Time then
		TimerTextLabel.Text = data.Time
		TimerTextLabel.Visible = true

		timeThread = task.spawn(function()
			local duration = data.Time

			while task.wait(1) and duration > 0 do
				duration -= 1
				TimerTextLabel.Text = duration
			end

			timeThread = nil
			clickResultBindable:Fire(data.OnIgnore and data.OnIgnore() or nil)
		end)
	end

	if data.Icon then
		TitleFrame.Icon.Image = data.Icon
	end

	local holder = client.UI.Get("NotificationHolder", nil, true)

	if not holder then
		client.UI.Make("NotificationHolder")
		holder = client.UI.Get("NotificationHolder", nil, true)
		holder.Object.ScrollingFrame.Active = false
	end

	NotificationFrame.Visible = true
	NotificationFrame.Parent = holder.Object.ScrollingFrame

	task.spawn(function()
		local sound = Instance.new("Sound", service.LocalContainer())
		sound.SoundId = 'rbxassetid://203785584'--client.NotificationSound
		sound.Volume = 0.2
		sound:Play()
		wait(0.5)
		sound:Destroy()
	end)

	local result = clickResultBindable.Event:Wait()

	if timeThread then
		task.cancel(timeThread)
	end
	
	NotificationFrame:Destroy()

	return result
end