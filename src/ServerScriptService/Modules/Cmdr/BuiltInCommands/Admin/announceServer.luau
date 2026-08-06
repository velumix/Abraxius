local TextChatService = game:GetService("TextChatService")
local Players = game:GetService("Players")

return function (context, text)
	local textChannel = TextChatService:FindFirstChild("RBXSystem") or TextChatService.TextChannels:FindFirstChildOfClass("TextChannel")
	
	if textChannel then
		textChannel:DisplaySystemMessage(`{context.Executor.DisplayName}: {text}`)
	else
		for _, player in ipairs(Players:GetPlayers()) do
			context:SendEvent(player, "Message", text, context.Executor)
		end
	end

	return "Created announcement."
end