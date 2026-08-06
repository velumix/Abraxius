client = nil
Pcall = nil
Routine = nil
service = nil
gTable = nil

--// All global vars will be wiped/replaced except script

return function(data)
	local playergui = service.PlayerGui
	local localplayer = service.Players.LocalPlayer
	local gui = script.Parent.Parent
	local Frame = gui.Frame
	local Close = gui.Frame.Close
	local Reply = gui.Frame.Reply
	local ReplyBox = gui.Frame.Frame.ReplyBox
	local Message = gui.Frame.Frame.Message
	local Title = gui.Frame.Title
	local Remote = client.Remote
	local replyTicket = data.replyTicket
	local player = data.Player
	local message = data.Message
	local title = data.Title
	
	local replying = false
	
	local function send()
		if ReplyBox.Text~='Enter text then hit enter or "reply"' and #ReplyBox.Text>0 then 
			gui:Destroy()
			Remote.Send('PrivateMessage', replyTicket, player, ReplyBox.Text)
		--	client.Remote.Send('PrivateMessage','Reply from '..localplayer.Name,player,localplayer,service.Filter(ReplyBox.Text,localplayer,player))
			client.UI.Make("Hint", {Message = "Reply sent"})
		else
			ReplyBox.Text='Enter text then hit enter or "reply"'
		end
	end
	
	Frame.Visible = false
	
	ReplyBox.Visible = true
	Reply.Visible = true
	
	Message.Text = message
	Title.Text = title
	
	ReplyBox.FocusLost:connect(function(enterPressed)
		if enterPressed then
			send()
		end
	end)
	
	Close.MouseButton1Click:connect(function() 
		gui:Destroy() 
	end)
	
	Reply.MouseButton1Click:connect(function()
		if not replying then
			replying = true
			Frame:TweenSize(UDim2.new(0,300,0,280),nil,nil,0.5)
			ReplyBox:CaptureFocus()
		else
			send()
		end
	end)
	
	client.UI.Make("Notification",{
		Title = "New Message";
		Message = "New Message from "..player.Name..". Click to here to view.";
		Time = false;
		OnClick = function() gTable:Ready() Frame.Visible = true end;
		OnClose = function() gTable:Destroy() end;
		OnIgnore = function() gTable:Destroy() end;
	})
end