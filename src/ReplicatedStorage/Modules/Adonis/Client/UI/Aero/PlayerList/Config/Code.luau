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

	client.Variables.PlayerListEnabled = false
	service.StarterGui:SetCoreGuiEnabled('PlayerList',false)

	local gui = script.Parent.Parent
	local drag = gui.Drag
	local frame = gui.Drag.Frame
	local dragger = gui.Drag.Frame.Dragger
	local list = gui.Drag.Frame.List
	local entry = gui.Entry
	local fakeDrag = gui.Drag.Frame.FakeDragger

	local top

	gTable:Ready()

	local specialPeople = {
		["1237666"] = 355277187; -- Sceleratis
		["39958537"] = 116524268; -- kryptonikofficial
		["66136675"] = 355858707; -- Chirality
		["102761590"] = 355858707; -- ayymd
		["6087802"] = 355858707; -- j1my3p1x
		["33869774"] = 355858707; -- LLVM
		["60557514"] = 355858707; -- Axstin
		["28606349"] = 99727663; -- MrRootx
		["64362264"] = 48094325; -- Waffle
		["39259729"] = 356709818; -- Cdk
		["68591528"] = 397876352; -- PlasticPeachey
	}

	local mouse=service.Players.LocalPlayer:GetMouse()
	local nx,ny,np=drag.AbsoluteSize.X,frame.AbsoluteSize.Y,nil--350,300
	local defx,defy,defp=nx,ny,drag.Position.X.Offset
	local dragging=false
	local dontSize=false

	local function checkStats()
		local stats = localplayer:FindFirstChild("leaderstats")
		if stats and not dontSize then
			nx = ((#stats:GetChildren()-1)*70)+210
			defx = nx
			drag.Size = UDim2.new(0,nx,0,30)
			drag.Position = UDim2.new(1,-(nx),0,0)
		end

		if stats then
			return true
		else
			return false
		end
	end

	local function fadeIn()
		frame.BackgroundTransparency = 0
		list.BackgroundTransparency = 0
		fakeDrag.Visible = true
	end

	local function fadeOut()
		frame.BackgroundTransparency = 0.7
		list.BackgroundTransparency = 1
		fakeDrag.Visible = false
	end

	local function populate()
		list:ClearAllChildren()
		checkStats()

		local teams = {
			Neutral = {Color = BrickColor.White(), Players = {}, Stats = {}, StatNames = {}}
		}

		local numPlayers = 0
		local numEntries = 0
		local leaderstats = {}
		local found = {}

		for i,v in service.Teams:GetChildren() do
			teams[v.Name] = {Color = v.TeamColor, Players = {}, Stats = {}, StatNames = {}}
		end

		for i,v in service.Players:GetPlayers() do
			local good = false
			local team
			if not v.Neutral then
				for k,m in teams do
					if m.Color == v.TeamColor then
						good = true
						team = m
						table.insert(m.Players,v)
					end
				end
			end
			if not good then
				team = teams.Neutral
				table.insert(teams.Neutral.Players,v)
			end

			local stats = v:FindFirstChild("leaderstats")
			if stats then
				for k,m in stats:GetChildren() do
					if team.Stats[m.Name] and tonumber(team.Stats[m.Name]) and m:IsA("IntValue") and tonumber(m.Value) then
						team.Stats[m.Name] = team.Stats[m.Name]+tonumber(m.Value)
					elseif not team.Stats[m.Name] and m:IsA("IntValue") then
						table.insert(team.Stats,m.Value)
						team.Stats[m.Name] = m.Value
					else
						team.Stats[m.Name] = ""
					end
					table.insert(team.StatNames,m.Name)
					if not found[m.Name] then
						table.insert(leaderstats,m.Name)
						found[m.Name] = true
					end
				end
			end
			numPlayers = numPlayers+1
		end

		if top then top:Destroy() end

		top = entry:Clone()
		top.Visible = true
		top.Position = UDim2.new(0,0,0,0)
		local nameb = top:FindFirstChild("Nameb")
		if nameb then
			nameb.Text = localplayer.Name
		end
		local imlabel = top:FindFirstChild("ImageLabel")
		if imlabel then
			imlabel.Visible = false
		end
		local stats = top:FindFirstChild("Stats")
		if stats then
			stats.Visible = true
			local statEnt = top.Stat
			for stat,k in leaderstats do
				local new = statEnt:Clone()
				new.Visible = true
				new.Parent = stats
				new.Text = k
				new.Position = UDim2.new(0,(stat-1)*70,0,0)
			end
		end

		top.Parent = drag

		if #teams.Neutral.Players==0 then
			teams.Neutral = nil
		end

		for i,v in teams do
			if #teams > 1 then
				local team = entry:Clone()
				team.Visible = true
				team.Position = UDim2.new(0,0,0,numEntries*25)
				team.Nameb.Text = i
				team.BackgroundTransparency = 0.5
				team.BackgroundColor3 = v.Color.Color
				team.ImageLabel.Visible = false
				team.Parent = list
				if string.len(i)>15 then
					team.Nameb.TextScaled = true
				end
				if #v.StatNames>0 then
					team.Stats.Visible = true
					team.Stats.Size = UDim2.new(0,70*(#v.Stats-1),1,0)
					local statEnt = team.Stat
					for stat,k in v.StatNames do
						local new = statEnt:Clone()
						new.Parent = team.Stats
						new.Visible = true
						local val = v.Stats[k]
						if val and type(val)=="number" then
							new.Text = val
						else
							new.Text = ""
						end
						new.Position = UDim2.new(0,(#team.Stats:GetChildren()-1)*70,0,0)
					end
				else
					team.Stats.Visible = false
				end
				numEntries = numEntries+1
			end
			for k,p in v.Players do
				local player = entry:Clone()
				player.Visible = true
				player.Position = UDim2.new(0,0,0,numEntries*25)

				local image = player:FindFirstChild("ImageLabel")
				local pstats = player:FindFirstChild("Stats")
				local nameb = player:FindFirstChild("Nameb")
				local pstat = player:FindFirstChild("Stat")

				if nameb then
					nameb.Text = p.Name
				end

				player.Parent = list

				if string.len(p.Name)>15 then
					nameb.TextScaled = true
				end

				local custom = specialPeople[tostring(p.UserId)]
				if image then
					if custom then
						image.Image = `http://www.roblox.com/asset/?id={custom}`
						image.Visible = true
					elseif p.UserId==game.CreatorId then
						image.Image = 'rbxasset://textures/ui/icon_placeowner.png'
						image.Visible = true
					elseif p:IsInGroup(1200769) then
						image.Image = 'http://www.roblox.com/asset/?id=99727663'
						image.Visible = true
					elseif localplayer:IsFriendsWith(p.UserId) and p~=localplayer then
						image.Image = 'http://www.roblox.com/asset/?id=99749771'
						image.Visible = true
					elseif p.MembershipType==Enum.MembershipType.BuildersClub then
						image.Image = 'rbxasset://textures/ui/TinyBcIcon.png'
						image.Visible = true
					elseif p.MembershipType==Enum.MembershipType.TurboBuildersClub then
						image.Image = 'rbxasset://textures/ui/TinyTbcIcon.png'
						image.Visible = true
					elseif p.MembershipType==Enum.MembershipType.OutrageousBuildersClub then
						image.Image = 'rbxasset://textures/ui/TinyObcIcon.png'
						image.Visible = true
					else
						image.Visible = false
					end
				end

				local stats = p:FindFirstChild("leaderstats")
				if stats and pstats and pstat then
					stats = stats:GetChildren()
					pstats.Visible = true
					local statEnt = pstat
					for stat,k in stats do
						local new = statEnt:Clone()
						new.Visible = true
						new.Parent = pstats
						new.Text = k.Value
						--[[
						local event
						event = k.Changed:Connect(function()
							if k and k.Parent and new and new.Parent then
								--new.Text = k.Value
								populate()
							else
								event:Disconnect()
							end
						end)
						--]]
						new.Position = UDim2.new(0,(#pstats:GetChildren()-1)*70,0,0)
					end
				elseif pstats then
					pstats.Visible = false
				end
				numEntries = numEntries+1
			end
		end

		if not dontSize then
			local noomis = numEntries
			if noomis>10 then
				noomis=10
			end
			local newy = (noomis*25)+30
			ny = newy
			defy = newy
			frame.Size = UDim2.new(0,nx,0,newy)
		end

		list.CanvasSize = UDim2.new(0, 0, 0, ((numEntries)*20))
	end

	drag.Position = UDim2.new(1,-nx,0,0)

	fadeOut()

	frame.MouseEnter:Connect(function()
		fadeIn()
	end)

	frame.MouseLeave:Connect(function()
		fadeOut()
	end)

	service.UserInputService.InputBegan:Connect(function(InputObject)
		local textbox = service.UserInputService:GetFocusedTextBox()
		if not (textbox) and InputObject.UserInputType==Enum.UserInputType.Keyboard and InputObject.KeyCode == Enum.KeyCode.Tab then
			if drag.Visible then
				drag.Visible = false
			else
				drag.Visible = true
			end
		end
	end)

	mouse.Move:Connect(function(x,y)
		if dragging then
			np=defp+(dragger.Position.X.Offset)
			nx=defx-(dragger.Position.X.Offset)
			ny=defy+(dragger.Position.Y.Offset+20)

			if nx<100 then
				nx=100
			end

			if ny<50 then
				ny=50
			end

			frame.Size=UDim2.new(1, 0, 0, ny)
			drag.Size=UDim2.new(0, nx, 0, 30)

			if nx>100 then
				drag.Position=UDim2.new(drag.Position.X.Scale,np,drag.Position.Y.Scale,drag.Position.Y.Offset)
			end
		end
	end)

	dragger.DragBegin:Connect(function(init)
		defp = drag.Position.X.Offset
		dragging = true
		dontSize = true
	end)

	dragger.DragStopped:Connect(function(x,y)
		dragging = false
		nx,ny,np=drag.AbsoluteSize.X,frame.AbsoluteSize.Y,nil--350,300
		defx,defy,defp=nx,ny,drag.Position.X.Offset
		dragger.Position = UDim2.new(0,0,1,-20)
		--populate()
	end)

	--[[
	for k,p in service.Players:GetPlayers() do
		p.Changed:Connect(populate)
		p.ChildAdded:Connect(function(c)
			populate()
			if c.Name=="leaderstats" then
				c.ChildAdded:Connect(populate)
			end
		end)
	end

	service.Players.PlayerAdded:Connect(function(p)
		populate()
		p.Changed:Connect(populate)
		p.ChildAdded:Connect(function(c)
			if c.Name=="leaderstats" then
				c.ChildAdded:Connect(populate)
			end
		end)
		task.wait(0.5)
		populate()
	end)

	service.Teams.ChildAdded:Connect(populate)
	service.Teams.ChildRemoved:Connect(populate)

	task.wait(0.5)
	populate()
	--]]

	while wait(0.5) do
		populate()
	end
end