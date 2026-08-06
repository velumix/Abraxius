-- Modules // Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MessagingService = game:GetService("MessagingService")
local HTTPService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Mince = require(ReplicatedStorage.Modules.Mince)
-- Remotes
local NoticeEvent = Mince:GetEvent("NoticeEvent")
local NotificationEvent = Mince:GetEvent("Notification")
local NoticeHandle = {
	Name = "Notice",
}

function NoticeHandle.GlobalNotice(Text, Color: Color3, Duration, Sound)
	MessagingService:PublishAsync("GlobalMessage", {
		Type = "Notice",
		Message = { Text, Color:ToHex(), Duration, Sound },
	})
end

function NoticeHandle.GlobalNotification(Param)
	Param.Scope = "Global"
	Param.Type = "Important"
	Param.InjectConfig = {
		Color = Param.Color,
		Sound = Param.Sound,
	}
	MessagingService:PublishAsync("GlobalMessage", {
		Type = "Notification",
		Param = HTTPService:JSONEncode(Param),
	})
end

function NoticeHandle.SendError(Player, Text, Duration)
	NoticeEvent:Fire(Player, Text, Color3.new(1, 0.2, 0.2), Duration, "error")
end

function NoticeHandle.SendNotice(Player, Text, Color, Duration, Sound)
	NoticeEvent:Fire(Player, Text, Color, Duration, Sound)
end

function NoticeHandle.StartSubscription()
	MessagingService:SubscribeAsync("GlobalMessage", function(MessagingPacket)
		local MessageObject = MessagingPacket.Data
		if MessageObject.Type == "Notice" then
			for _, Player in Players:GetPlayers() do
				local Text, RawColor, Duration, Sound = table.unpack(MessageObject.Message)
				NoticeHandle.SendNotice(Player, Text, Color3.fromHex(RawColor), Duration, Sound)
			end
		elseif MessageObject.Type == "Notification" then
			local Param = HTTPService:JSONDecode(MessageObject.Param)

			for _, Player in Players:GetPlayers() do
				NotificationEvent:Fire(Player, Param)
			end
		end
	end)
end

return NoticeHandle
