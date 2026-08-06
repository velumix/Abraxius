local IGameMode = {}

function IGameMode.validate(mode)
	if type(mode) ~= "table" then
		return false, "module did not return a table"
	end
	if type(mode.id) ~= "string" or mode.id == "" then
		return false, "missing string field 'id'"
	end
	if type(mode.run) ~= "function" then
		return false, "missing function 'run(ctx)'"
	end
	return true
end

return IGameMode
