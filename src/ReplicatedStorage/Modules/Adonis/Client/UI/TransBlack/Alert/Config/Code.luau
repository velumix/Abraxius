client = nil
Pcall = nil
Routine = nil
service = nil

--// All global vars will be wiped/replaced except script

return function(data)
	local gui = script.Parent.Parent
	local ok = gui.Frame.Main.Ok
	local quest = gui.Frame.Main.Question
	
	local gTable = data.gTable
	
	quest.Text = data.Message
	gTable:Ready()
	
	local alarm=Instance.new('Sound',quest)
	alarm.Volume=1
	alarm.Looped=true
	alarm.SoundId='http://www.roblox.com/asset/?id=138081509'
	alarm:Play()
	
	ok.MouseButton1Click:connect(function()
		gui:Destroy()
		alarm:Stop()
	end)
	
	--gTable.CustomDestroy = function()
	--	gui:Destroy()
	--	alarm:Stop()
	--end
		--This could probably break something... Too bad!
end