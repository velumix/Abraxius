return function(data, env)
	
	local Players: Player = service.Players
	local UserService: UserService = service.UserService
	
	local gui = script.Parent.Parent
	local Notification = gui.Notification
	local Content = Notification.Content
	local DisplayNameLabel = Content.Title.UserLabel.DisplayName
	local UsernameLabel = Content.Title.UserLabel.Username
	local UserThumbnailLabel = Content.Title.UserThumbnail
	local BodyTextLabel = Content.Body
	
	local gIndex = data.gIndex
	local gTable = data.gTable
	
	local userId: number? = data.UserId
	local title: string? = data.Title
	local message: string? = data.Message
	local scroll: any? = data.Scroll
	local duration: number? = data.Time
	
	if not (message and title) then
		gTable:Destroy()
	end
	
	UsernameLabel.Text = title or "Announcement"
	BodyTextLabel.Text = message
	
	if userId and not title then
		task.spawn(function()
			local info = UserService:GetUserInfosByUserIdsAsync({userId})[1]
			DisplayNameLabel.Text = info.DisplayName
			UsernameLabel.Text = `Message from @{info.Username}`
		end)
	elseif title and not userId then
		DisplayNameLabel.Text = title
		UsernameLabel.Visible = false
	else
		DisplayNameLabel.Text = title or "Announcement"
		UsernameLabel.Visible = false
	end
	
	if userId then
		UserThumbnailLabel.Visible = true
		task.spawn(function()
			UserThumbnailLabel.Image = Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
		end)
	else
		UserThumbnailLabel.Visible = false
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
	
	local fadeSteps = 24
	local blurSize = 10
	local textFade = 0.1
	local strokeFade = 1
	local frameFade = 0.3
	
	local blurStep = blurSize/fadeSteps
	local frameStep = frameFade/fadeSteps
	local textStep = 0.1
	local strokeStep = 0.1
	
	local function fadeIn()
		gTable:Ready()
		for i = 1,fadeSteps do
			if BodyTextLabel.TextTransparency>textFade then
				BodyTextLabel.TextTransparency = BodyTextLabel.TextTransparency-textStep
				UsernameLabel.TextTransparency = UsernameLabel.TextTransparency-textStep
			end
			if BodyTextLabel.TextStrokeTransparency>strokeFade then
				BodyTextLabel.TextStrokeTransparency = BodyTextLabel.TextStrokeTransparency-strokeStep
				UsernameLabel.TextStrokeTransparency = UsernameLabel.TextStrokeTransparency-strokeStep
			end
			if Notification.BackgroundTransparency>frameFade then
				Notification.BackgroundTransparency = Notification.BackgroundTransparency-frameStep
			end
			service.Wait("Stepped")
		end
	end
	
	local function fadeOut()
		if not gone then
			gone = true
			for i = 1,fadeSteps do
				if BodyTextLabel.TextTransparency<1 then
					BodyTextLabel.TextTransparency = BodyTextLabel.TextTransparency+textStep
					UsernameLabel.TextTransparency = UsernameLabel.TextTransparency+textStep
				end
				if BodyTextLabel.TextStrokeTransparency<1 then
					BodyTextLabel.TextStrokeTransparency = BodyTextLabel.TextStrokeTransparency+strokeStep
					UsernameLabel.TextStrokeTransparency = UsernameLabel.TextStrokeTransparency+strokeStep
				end
				if Notification.BackgroundTransparency<1 then
					Notification.BackgroundTransparency = Notification.BackgroundTransparency+frameStep
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
	if not duration then
		local _,time = message:gsub(" ","")
		time = math.clamp(time/2,4,11)+1
		wait(time)
	else
		wait(duration)
	end
	if not gone then
		fadeOut()
	end
end