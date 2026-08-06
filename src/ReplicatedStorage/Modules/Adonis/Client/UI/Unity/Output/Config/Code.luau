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
	local color = data.Color or Color3.fromRGB(255, 78, 78)

	local tweenInfo = TweenInfo.new(0.20)----service.SafeTweenSize(frame,UDim2.new(1,0,0,40),nil,nil,0.3,nil,function() if scrollOpen then frame.Size = UDim2.new(1,0,0,140) end end)
	local consoleOpenTween = service.TweenService:Create(main, tweenInfo, {
		Position = UDim2.new(0.11, 0, 0.35, 0);
	})

	local consoleCloseTween = service.TweenService:Create(main, tweenInfo, {
		Position = UDim2.new(0.11, 0, 0, -200);
	})

	local found = client.UI.Get("Output")
	if found then
		for i,v in pairs(found) do
			local p = v.Object
			if p and p.Parent then
				local consoleOpenTween1 = service.TweenService:Create(p.Main, tweenInfo, {
					Position = UDim2.new(0.11, 0, 0.35, p.Main.Position.Y.Offset+55);
				})
				consoleOpenTween1:Play()
			end
		end
	end
	t2.TextColor3 = color
	main.BackgroundColor3 = color

	t2.Text = msg
	t2.Font = Enum.Font.Roboto
	consoleOpenTween:Play()
	--t2.Position = UDim2.new(0, 0, 0.35, 0)
	gTable.Ready()
	task.wait(5)
	consoleCloseTween:Play()
	task.wait(2)
	gTable.Destroy()
end