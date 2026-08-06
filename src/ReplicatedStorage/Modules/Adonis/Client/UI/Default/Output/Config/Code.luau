client = nil
Pcall = nil
Routine = nil
service = nil
gTable = nil

--// All global vars will be wiped/replaced except script

return function(data, env)
	if env then
		setfenv(1, env)
	end
	
	local playerGui = service.PlayerGui
	local localPlayer = service.Players.LocalPlayer
	local scr = client.UI.Prepare(script.Parent.Parent)
	local main = scr.Main
	local titleLabel = main.Title
	local messageLabel = main.Message
	local messageData = data.Message
	local titleData = data.Title or ""
	local colorIn = data.Color
	
	local found = client.UI.Get("Output")
	if found then
		for _,v in pairs(found) do
			local p = v.Object
			if p and p.Parent then
				p.Main.Position = UDim2.new(0, 0, 0.35, p.Main.Position.Y.Offset+50)
			end
		end
	end
	
	messageLabel.Text = messageData
	messageLabel.Font = Enum.Font.SourceSans
	if data.Color then
		messageLabel.TextColor3 = data.Color
	end
	gTable.Ready()
	task.wait(5)
	gTable.Destroy()
end