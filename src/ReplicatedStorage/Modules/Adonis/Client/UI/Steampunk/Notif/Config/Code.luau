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
	
	local playergui = service.PlayerGui
	local gui = client.UI.Prepare(script.Parent.Parent)
	local label = gui.LABEL
	local str = data.Message
	gui.IgnoreGuiInset = not client.Variables.TopBarShift
	gui.ClipToDeviceSafeArea = true
	
	client.UI.Remove("Notif",script.Parent.Parent)
	
	local log  = {
		Type = "Notif";
		Title = "Notif";
		Message = str;
		Icon = "rbxassetid://7501175708";
		Time = os.date("%X");
		Function = nil;
	}

	table.insert(client.Variables.CommunicationsHistory, log) 
	service.Events.CommsPanel:Fire(log)

	if str and type(str)=="string" then
		label.Text = str
		gTable:Ready()
	else
		gui:Destroy()
	end
end