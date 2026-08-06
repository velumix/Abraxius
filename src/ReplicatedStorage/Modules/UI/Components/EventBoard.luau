local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local TweenService = game:GetService("TweenService")

local Modules = ReplicatedStorage.Modules
local Mince = require(Modules.Mince)

local UI

local EventBoard = Mince.Component {
	Tag = "EventBoard",
}

function EventBoard:Construct()
	UI = require(Modules.UI)

	self.Model = self.Instance
	self.RSVP = self.Instance:FindFirstChild("RSVP", true) :: TextButton
	self.EventImage = self.Instance:FindFirstChild("EventImage", true) :: ImageLabel

	self.EventId = self.Instance:GetAttribute("EventId")
	if not self.EventId then
		local value = self.Instance:FindFirstChild("EventId")
		if value and value:IsA("StringValue") then
			self.EventId = value.Value
		end
	end

	if self.RSVP then
		self._buttonBaseSize = self.RSVP.Size
		self._buttonBasePosition = self.RSVP.Position
		self:_updateRsvpButton()
		self._rsvpConnection = self.RSVP.Activated:Connect(function()
			self:_promptRsvp()
		end)

		self._hoverConnection = self.RSVP.MouseEnter:Connect(function()
			self:_tweenButton(UDim2.new(0, 6, 0, 4), UDim2.new(0, -3, 0, -2), 0.12)
		end)
		self._leaveConnection = self.RSVP.MouseLeave:Connect(function()
			self:_tweenButton(UDim2.new(0, 0, 0, 0), UDim2.new(0, 0, 0, 0), 0.14)
		end)
		self._pressConnection = self.RSVP.MouseButton1Down:Connect(function()
			self:_tweenButton(UDim2.new(0, -2, 0, -2), UDim2.new(0, 1, 0, 1), 0.08)
		end)
		self._releaseConnection = self.RSVP.MouseButton1Up:Connect(function()
			self:_tweenButton(UDim2.new(0, 6, 0, 4), UDim2.new(0, -3, 0, -2), 0.1)
		end)
		self._inputEndedConnection = self.RSVP.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				self:_tweenButton(UDim2.new(0, 6, 0, 4), UDim2.new(0, -3, 0, -2), 0.1)
			end
		end)
	end
end

function EventBoard:_tweenButton(sizeOffset, positionOffset, duration)
	if not self.RSVP or not self._buttonBaseSize or not self._buttonBasePosition then
		return
	end

	if self._buttonTween then
		self._buttonTween:Cancel()
		self._buttonTween = nil
	end

	local targetSize = self._buttonBaseSize + sizeOffset
	local targetPosition = self._buttonBasePosition + positionOffset

	self._buttonTween = TweenService:Create(
		self.RSVP,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = targetSize, Position = targetPosition }
	)
	self._buttonTween:Play()
end

function EventBoard:_promptRsvp()
	if not self.EventId then
		warn("EventBoard missing EventId attribute/value")
		UI.Notify("This event isn't available in this experience.", "Warning", 5)
		return
	end

	task.spawn(function()
		local ok, result = pcall(function()
			return SocialService:PromptRsvpToEventAsync(self.EventId)
		end)
		if not ok then
			warn("Failed to prompt RSVP:", result)
			if typeof(result) == "string" and result:lower():find("universe") then
				UI.Notify("This event isn't in the current universe.", "Warning", 5)
			else
				UI.Notify("Unable to open the RSVP prompt right now.", "Warning", 5)
			end
			return
		end
		self:_updateRsvpButton(result)
	end)
end

function EventBoard:_updateRsvpButton(forcedStatus)
	if not self.RSVP then
		return
	end

	if not self.EventId then
		self.RSVP.Text = "RSVP"
		self.RSVP.AutoButtonColor = false
		self.RSVP.Active = false
		return
	end

	local status = forcedStatus
	if not status then
		local ok, result = pcall(function()
			return SocialService:GetEventRsvpStatusAsync(self.EventId)
		end)
		if ok then
			status = result
		end
	end

	self.RSVP.Active = true
	self.RSVP.AutoButtonColor = true

	if status == Enum.RsvpStatus.Going then
		self.RSVP.Text = "NOTIFIED!"
	elseif status == Enum.RsvpStatus.NotGoing then
		self.RSVP.Text = "NOTIFY ME!"
	else
		self.RSVP.Text = "NOTIFY ME!"
	end
end

return EventBoard
