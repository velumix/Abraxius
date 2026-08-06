return function(data, env)
	if env then
		setfenv(1, env)
	end
	
	local Players: Players = service.Players
	local PlayerGui: PlayerGui = service.PlayerGui
	local Gui = client.UI.Prepare(script.Parent.Parent)
	
	local userId: number? = data.UserId
	local message: string? = data.Message
	
	client.UI.Remove("Notif", script.Parent.Parent)
	
	local log  = {
		Type = "Notif";
		Title = "Notif";
		Message = message;
		Icon = "rbxassetid://7501175708";
		Time = os.date("%X");
		Function = nil;
	}

	table.insert(client.Variables.CommunicationsHistory, log) 
	service.Events.CommsPanel:Fire(log)

	if message then
		
		Gui.LABEL.Content.Body.Text = message
		Gui.LABEL.Content.Author.Visible = false
		Gui.LABEL.Content.Divider.Visible = false
		
		if userId then
			task.spawn(function()
				local gotUserInfo, userInfo = pcall(service.UserService.GetUserInfosByUserIdsAsync, service.UserService, {
					userId
				})
				
				if gotUserInfo then	
					userInfo = userInfo[1]
					Gui.LABEL.Content.Author.Visible = true
					Gui.LABEL.Content.Divider.Visible = true
					Gui.LABEL.Content.Author.UserLabel.DisplayName.Text = `{userInfo.DisplayName}{userInfo.HasVerifiedBadge and `<font size="12">{utf8.char(0xe000)}</font>` or ''}`
				else
					warn(`Failed to get user information for {userId}: {userInfo}`)
				end
			end)
			task.spawn(function()
				local gotUserThumbnail, userThumbnail = pcall(Players.GetUserThumbnailAsync, Players, userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
				if gotUserThumbnail then
					Gui.LABEL.Content.Author.UserThumbnail.Image = userThumbnail
				else
					warn(`Failed to get user thumbnail for {userId}: {userThumbnail}`)
				end
			end)
		end
		
		gTable:Ready()
	else
		Gui:Destroy()
	end
end