client = nil
Pcall = nil
Routine = nil
service = nil

return function(data, env)
	if env then
		setfenv(1, env)
	end

	local gTable = data.gTable
	local gui = gTable.Object
	local playergui = service.PlayerGui
	local str = data.Message

	local hint = gui.HintFrame
	local frame = hint.Frame
	local msg = frame.msg

	client.Core.RemoveGui("Hint",gui)

	msg.Text = str
	gTable:Ready()

	wait(data.Time or 5)

	gui:Destroy()
end