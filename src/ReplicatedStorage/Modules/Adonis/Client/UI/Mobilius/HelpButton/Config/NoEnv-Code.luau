client = nil
Pcall = nil
Routine = nil
service = nil

--// All global vars will be wiped/replaced except script

return function(data, env)
	if env then
		setfenv(1, env)
	end

	local playergui = service.PlayerGui
	local localplayer = service.Player
	local toggle = script.Parent.Parent.Toggle

	if client.UI.Get("Chat") then
		toggle.Position = UDim2.new(1, -(45+40),1, -45)
	end

	toggle.MouseButton1Down:Connect(function()
		local found = client.UI.Get("UserPanel",nil,true)
		local setting = client.Variables.HelpButtonAction
		if string.lower(setting) == "console" then
			service.Events.ToggleConsole:Fire()
		else -- defaulting to info just incase anything happens
			if found then
				found.Object:Destroy()
			else
				client.UI.Make("UserPanel")
			end
		end
	end)

	script.Parent.Parent.Parent = playergui
	toggle.Parent.Enabled = true -- workaround for Adonis not enabling the UI for some reason
end