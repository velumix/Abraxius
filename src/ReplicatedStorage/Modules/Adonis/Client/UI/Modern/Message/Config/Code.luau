return function(data, env)

	local Players: Player = service.Players
	local UserService: UserService = service.UserService
	local TweenService: TweenService = service.TweenService

	local MessageEffects = script.Parent.Parent.MessageEffects
	local BlurEffect = MessageEffects["Adonis.Message.Blur"]
	local ColorCorrectionEffect = MessageEffects["Adonis.Message.ColorCorrection"]
	local BloomEffect = MessageEffects["Adonis.Message.Bloom"]


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
	local image: string? = data.Image

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
		UsernameLabel.Visible = false
		DisplayNameLabel.Text = title or "Announcement"
	end

	if userId and not image then
		UserThumbnailLabel.Visible = true
		task.spawn(function()
			UserThumbnailLabel.Image = Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
		end)
	elseif image then
		UserThumbnailLabel.Visible = true
		UserThumbnailLabel.Image = image
		UserThumbnailLabel.BackgroundTransparency = 1
		UserThumbnailLabel.UIStroke.Enabled = false
		UserThumbnailLabel.UICorner.CornerRadius = UDim.new(0, 0)
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
	local textFade = 0.1
	local strokeFade = 1
	local frameFade = 0.3

	local frameStep = 0.1
	local textStep = 0.1
	local strokeStep = 0.1

	local TWEEN_INFO_IN = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	local TWEEN_INFO_OUT = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	local function fadeIn()		
		gTable:Ready()
		
		if userId then
			for _, effect in MessageEffects:GetChildren() do
				effect.Parent = workspace.CurrentCamera
			end
		end

		TweenService:Create(BloomEffect, TWEEN_INFO_IN, {
			Intensity = 1;
			Size = 56;
			Threshold = 0.8;
		}):Play()

		TweenService:Create(BlurEffect, TWEEN_INFO_IN, {
			Size = 16;
		}):Play()

		TweenService:Create(ColorCorrectionEffect, TWEEN_INFO_IN, {
			Contrast = 1;
			Saturation = -0.8;
		}):Play()

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

			TweenService:Create(BloomEffect, TWEEN_INFO_IN, {
				Intensity = 0;
				Size = 0;
				Threshold = 0;
			}):Play()

			TweenService:Create(BlurEffect, TWEEN_INFO_IN, {
				Size = 0;
			}):Play()

			local cctween = TweenService:Create(ColorCorrectionEffect, TWEEN_INFO_IN, {
				Contrast = 0;
				Saturation = 0;
			})

			cctween:Play()
			cctween.Completed:Connect(function()
				BloomEffect:Destroy()
				BlurEffect:Destroy()
				ColorCorrectionEffect:Destroy()
			end)

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