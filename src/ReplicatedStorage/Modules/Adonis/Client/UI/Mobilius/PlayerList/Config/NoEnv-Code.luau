client = nil
Pcall = nil
Routine = nil
service = nil

--// All global vars will be wiped/replaced except script

return function(data, env)
	env.script.Parent.Parent:Destroy()
end