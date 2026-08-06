local Data = {
	WalkSpeed = 10,
	WaitBetweenPoi = 25,
	SpeechDuration = 7.5,

	ChatColor = Color3.new(1, 1, 1),
	ChatStrokeColor = Color3.new(0, 0, 0),
	ChatStrokeTransparency = 0.35,
	ChatTextSize = 18,
	ChatWrapped = true,
	ChatXAlignment = Enum.TextXAlignment.Center,
	ChatYAlignment = Enum.TextYAlignment.Center,

	Dialog = {
		"Observatory be a fine place to drop anchor.",
		"Have ye seen any treasure 'round these parts?",
		"Look at this manta ray its a beauty!",
		"Keep your eyes on the reef - some fish only show when you slow down.",
		"Upgrading your gear makes every dive smoother. Worth the coin.",
		"Pitch in on ocean cleanup and you'll earn a few coins for the effort.",
	},

	UsedBin = {}

}

function Data.Init(npc)
	npc.DisplayName = npc.Instance.Name

	if npc.Humanoid then
		npc.Humanoid.WalkSpeed = Data.WalkSpeed or npc.Humanoid.WalkSpeed
	end

	Data.Chat = script:FindFirstChild("Chat")

	if Data.Chat then
		Data.Chat.Parent = npc.Instance
		Data.textLabel = Data.Chat.TextLabel :: TextLabel?
		if Data.textLabel then
			Data.textLabel.TextColor3 = Data.ChatColor or Data.textLabel.TextColor3
			Data.textLabel.TextStrokeColor3 = Data.ChatStrokeColor or Data.textLabel.TextStrokeColor3
			Data.textLabel.TextStrokeTransparency = Data.ChatStrokeTransparency or Data.textLabel.TextStrokeTransparency
			Data.textLabel.TextSize = Data.ChatTextSize or Data.textLabel.TextSize
			Data.textLabel.TextWrapped = Data.ChatWrapped ~= nil and Data.ChatWrapped or Data.textLabel.TextWrapped
			Data.textLabel.TextXAlignment = Data.ChatXAlignment or Data.textLabel.TextXAlignment
			Data.textLabel.TextYAlignment = Data.ChatYAlignment or Data.textLabel.TextYAlignment
			if Data.textLabel.Text ~= "" then
				Data.textLabel.Text = ""
			end
		end
	end

	return npc
end

function Data.SaySomething(npc)
	if not Data.textLabel then
		return
	end

	local dialog = Data.Dialog
	if type(dialog) ~= "table" then
		return
	end

	if #dialog == 0 then
		local bin = Data.UsedBin
		if type(bin) == "table" and #bin > 0 then
			for _, line in ipairs(bin) do
				table.insert(dialog, line)
			end
			table.clear(bin)
		else
			return
		end
	end

	if #dialog == 0 then
		return
	end

	local index = math.random(1, #dialog)
	local line = table.remove(dialog, index)
	table.insert(Data.UsedBin, line)

	Data.textLabel.Text = line

	task.delay(Data.SpeechDuration or 4, function()
		if Data.textLabel then
			Data.textLabel.Text = ""
		end
	end)

end

return Data
