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
	local localplayer = service.Players.LocalPlayer
	local scr = client.UI.Prepare(script.Parent.Parent)
	local main = scr.Main
	local t1 = main.Title
	local t2 = main.Message
	local msg = data.Message
	local title = data.Title
	local color = data.Color
	
	local found = client.UI.Get("Output")
	if found then
		for i,v in pairs(found) do
			local p = v.Object
			if p and p.Parent then
				p.Main.Position = UDim2.new(0, 0, 0.35, p.Main.Position.Y.Offset+50)
			end
		end
	end

	t2.Text = msg
	t2.Font = "Arial"
	if color then
		t2.TextColor3 = color
	end
	--t2.Position = UDim2.new(0, 0, 0.35, 0)
	gTable.Ready()
	task.wait(5)
	gTable.Destroy()
end