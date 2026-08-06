client = nil
Pcall = nil
Routine = nil
service = nil
gTable = nil

--// All global vars will be wiped/replaced except script
--// All guis are autonamed using client.Functions.GetRandom()

return function(data)
	local gui = client.UI.Prepare(script.Parent.Parent)
	local playergui = service.PlayerGui
	
	local frame = gui.Drag.Frame
	local close = gui.Drag.Frame.Close
	local main = gui.Drag.Frame.Main
	local ques = gui.Drag.Frame.Main.Question
	local ans = gui.Drag.Frame.Main.Answers
	local entry = gui.Entry
	
	local question = data.Question
	local answers = data.Answers
	
	local selected
	
	ques.Text = question
	
	close.MouseButton1Click:connect(function()
		gui:Destroy()
		selected = false
	end)
	
	local num = 0
	for i,v in pairs(answers) do
		local clone = entry:clone()
		clone.Parent = ans
		clone.Text = v
		clone.Position = UDim2.new(0,0,0,num*20)
		clone.Visible = true
		clone.MouseButton1Click:connect(function()
			gui:Destroy()
			selected = v
		end)
		num=num+1 
	end
	
	gTable:Ready()
	
	local temp = 0
	repeat wait(0.1) temp=temp+0.1 until temp>60 or selected~=nil
	
	if gui and gui.Parent then gui:Destroy() end
	
	return selected
end