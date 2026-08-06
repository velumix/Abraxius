client = nil
Pcall = nil
Routine = nil
service = nil
gTable = nil

--// All global vars will be wiped/replaced except script

return function(data)
	local playergui = service.PlayerGui
	local localplayer = service.Players.LocalPlayer
	local ping = script.Parent.Parent
	local frame = ping.Frame
	local ms = ping.Frame.Ms
	local close = ping.Frame.Close
	local pinging = true
	gTable:Ready()
	
	ms.Text = "..."
	
	close.MouseButton1Click:connect(function()
		ping:Destroy()
		pinging = false
	end)
	
	repeat
		ms.Text = `{client.Remote.Ping()}ms`
		wait(2)
	until not pinging or not gTable.Active
	
	if ping then 
		ping:Destroy()
	end
end