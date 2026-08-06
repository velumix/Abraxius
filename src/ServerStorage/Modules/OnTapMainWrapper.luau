local OnTapMain = {
	Host = "https://back.diepolder.co", -- testing host!
	APIKey = "GcSDTwKEcd4HJWRQ7R7ueNfVXAsZDqR9xfMzKd2DQsOBOU8y39aMHvL4CQnVVrst6FZHKSumWKIpGyPc64yi8I05bhyFOp1XRAjQTny2fs388r3MImAQVZi3I5simrkk",

	Version = "0.8" 
} 

OnTapMain.Methods = {
	ONLINE = { "GET",  "/online"},
	LOGS_LOG_COMMAND = { "POST", "/logs/log-command"},
	NOTES_GET_NOTES = { "POST", "/notes/get-notes" }, 
	NOTES_VOTE_NOTE = { "POST", "/notes/vote-note" }, 
	PLAYERS_ADD_BAN = { "POST", "/players/add-ban" },
	NOTES_DELETE_NOTE = { "POST", "/notes/delete-note" },
	NOTES_CREATE_NOTE = { "POST", "/notes/create-note" }, 
	MATCHMAKING_PEEK_PLAYERS = { "POST", "/matchmaking/peek-players"},
	MEW_SVG_FILE_RECORD_CONVERT_PNG = { "POST", "/file/new-svg-file-record-convert-png"}
}

-- Modules // Services -- 
local HTTPService = game:GetService("HttpService")
local Players = game:GetService("Players")

-- You can change this to warn if you'd like to throw non fatal errors. But i'd reocmmend using pcall.
OnTapMain.Soft = warn 
OnTapMain.Throw = error 

function OnTapMain.AnalyzeResponse(ResponseTable : table) 
	if ResponseTable.ThisResultIsAnError then 
		OnTapMain.Throw(`API Error [{ResponseTable.Code or "N/A"}] : {ResponseTable.Message}`)
	end
end

function OnTapMain.TypeCheckValue(TypeArray,...) 
	local Values = {...} 
	if #Values ~= #TypeArray then 
		OnTapMain.Throw("Greater or lesser amount of required paramaters.")
	end

	-- This get's the subclass, of objects.
	local TypeOf = function(Value) 
		local Type = typeof(Value)  
		if Type == "Instance" then 
			Type = Value.ClassName
		end
		if Type == "table" then 
			if Value.__type then 
				Type = Value.__type
			end
		end
		return Type 
	end

	for i=1,#TypeArray do 
		if typeof(TypeArray[i]) == "table" then 
			local Match, Format = false, ""; 
			for Index, PotMatch in TypeArray[i] do 
				if PotMatch == Values[i] then Match = true end
				
				Format ..= tostring(PotMatch) 
				if Index ~= #TypeArray[1] then 
					Format ..= ", "
				end
			end
			
			if not Match then 
				OnTapMain.Throw(`Expected Value(s) {Format} for ({TypeArray.ValidatingArr and TypeArray.ValidatingArr[i] or TypeArray.Validating or "paramater"})[{i}] instead got '{Values[i]}'.`)
			end
			
			continue; 
		end
		
		local ValueType = TypeOf(Values[i]) 
		local Match = false 
		-- Accepts both superclass an subclasses.
		if ValueType == TypeArray[i] then 
			Match = true
		end		
		if typeof(Values[i]) == TypeArray[i] then 
			Match = true 
		end

		if not Match then 
			OnTapMain.Throw(`Expected '{TypeArray[i]}' as ({TypeArray.ValidatingArr and TypeArray.ValidatingArr[i] or TypeArray.Validating or "paramater"})[{i}] instead got '{ValueType}'.`)
		end
	end

	return ... 
end

function OnTapMain.FormatParamaters(ParamaterTable : table) 
	local BuildString = "?" 
	for Key,Value in pairs(ParamaterTable) do 
		BuildString = BuildString .. Key .. "=" .. tostring(Value)  .. "&"
	end

	return BuildString:sub(1, -2) --Trim Last One Off
end

function OnTapMain.GetAsyncNetworkResult(Type,Method,Content,ParamaterTable) : NetworkResult
	local Headers = {
		["Authorization"] =  ("Bearer %s"):format(OnTapMain.APIKey),
		["Content-Type"] = "application/json"
	} 
	local JSONContentOutput
	if Content then 
		JSONContentOutput = HTTPService:JSONEncode(Content)
	end

	local Success = false 
	local RequestURL = OnTapMain.Host .. Method	 
	if ParamaterTable then 
		RequestURL ..= OnTapMain.FormatParamaters(ParamaterTable)
	end


	local Success , Response = pcall(function() 
		return HTTPService:RequestAsync({  
			Url = RequestURL, 
			Method = Type, 
			Headers = Headers,
			Body = JSONContentOutput 
		})
	end)
	if not Success then OnTapMain.Throw(`HTTP SYNTAX ERROR: {Response}`) end 

	if Response and not Response.Success then 
		OnTapMain.Throw(`HTTP ERROR[{Response.StatusCode or "N/A"}]: {Response.StatusMessage} `)	
	end

	local Success , ResponseBody = pcall(function() 
		return HTTPService:JSONDecode(Response and Response.Body)
	end) 
	if not Success then OnTapMain.Throw(`Parsing Error: {ResponseBody}`) end 

	OnTapMain.AnalyzeResponse(ResponseBody)

	return ResponseBody
end


-- Direct API METHODS -- 

function OnTapMain:UploadSVGAndGetURL(...) 
	local SVGData = OnTapMain.TypeCheckValue({"string"}, ...)
	local Result = OnTapMain.GetAsyncNetworkResult(OnTapMain.Methods.MEW_SVG_FILE_RECORD_CONVERT_PNG[1], OnTapMain.Methods.MEW_SVG_FILE_RECORD_CONVERT_PNG[2], {
		FileContents = SVGData, 
		FileName = "automated-svg-upload.svg"
	}) 
	
	if Result.Record then 
		return `{OnTapMain.Host}/gtrcd?i={Result.Record}`
	else 
		OnTapMain.Throw("No record could be generated! ")
	end
end

function OnTapMain:PeekPlayers(...) 
	local PlayerInfoArray = OnTapMain.TypeCheckValue({"table"}, ...)
	
	local FormattedPlayerInfoArray = {} 
	for _,PlayerInfo in PlayerInfoArray do
		local PlayerInfo = OnTapMain.TypeCheckValue({"table"}, PlayerInfo)
		local Player = OnTapMain.TypeCheckValue({"Player"}, PlayerInfo[1]) 
		local MatchPrefs = OnTapMain.TypeCheckValue({"table"}, PlayerInfo[2])  
		for Index, Value in MatchPrefs do OnTapMain.TypeCheckValue({"number", "number", ValidatingArr = {"table.index", "table.value"}}, Index, Value) end
		local MatchKey = PlayerInfo[3] 
		if MatchKey then OnTapMain.TypeCheckValue({"string"}, MatchKey) end 
		
		table.insert(FormattedPlayerInfoArray, {Player.UserId, MatchPrefs, MatchKey})
	end

	
	return OnTapMain.GetAsyncNetworkResult(OnTapMain.Methods.MATCHMAKING_PEEK_PLAYERS[1], OnTapMain.Methods.MATCHMAKING_PEEK_PLAYERS[2],{
		LookingPlayers = FormattedPlayerInfoArray
	})
end

function OnTapMain:AddBan(...) 
	local BanKey, BanPlayerID, BanDuration = OnTapMain.TypeCheckValue({"string", "number", "number"}, ...) 
	return OnTapMain.GetAsyncNetworkResult(OnTapMain.Methods.PLAYERS_ADD_BAN[1],OnTapMain.Methods.PLAYERS_ADD_BAN[2],{
		BanKey = BanKey, 
		BanDuration = BanDuration,
		PlayerName = Players:GetNameFromUserIdAsync(BanPlayerID), 
		PlayerID = BanPlayerID
	})
end

function OnTapMain:LogAction(...) 
	local Player : Player, LogKey, LogContent = OnTapMain.TypeCheckValue({"Player", "string", "string"}, ...) 
	return OnTapMain.GetAsyncNetworkResult(OnTapMain.Methods.LOGS_LOG_COMMAND[1],OnTapMain.Methods.LOGS_LOG_COMMAND[2],{
		LogContent = LogContent,
		LogKey = LogKey, 
		PlayerName = Player.Name, 
		PlayerID = Player.UserId
	})
end

function OnTapMain:CreateNote(...) 
	local Player : Player, Message : string, Color : Color3 = OnTapMain.TypeCheckValue({"Player", "string", "Color3"}, ...)
	return OnTapMain.GetAsyncNetworkResult(OnTapMain.Methods.NOTES_CREATE_NOTE[1],OnTapMain.Methods.NOTES_CREATE_NOTE[2],{
		PlayerID = Player.UserId,
		PlayerName = Player.Name, 
		ColorHex = Color:ToHex(),
		Message = Message 
	})
end

function OnTapMain:VoteNote(...) 
	local NoteID : string, VoteType : string = OnTapMain.TypeCheckValue({"string","string"}, ...)
	return OnTapMain.GetAsyncNetworkResult(OnTapMain.Methods.NOTES_VOTE_NOTE[1],OnTapMain.Methods.NOTES_VOTE_NOTE[2],{
		NoteID = NoteID,
		Vote = VoteType 
	})
end

function OnTapMain:DeleteNote(...) 
	local NoteID : string = OnTapMain.TypeCheckValue({"string"}, ...)
	return OnTapMain.GetAsyncNetworkResult(OnTapMain.Methods.NOTES_DELETE_NOTE[1],OnTapMain.Methods.NOTES_DELETE_NOTE[2],{
		NoteID = NoteID,
	})
end


function OnTapMain:GetNotes(Cursor : string, PageSize : number, ...) 
	local SortType : string = OnTapMain.TypeCheckValue({"string"}, ...)
	return OnTapMain.GetAsyncNetworkResult(OnTapMain.Methods.NOTES_GET_NOTES[1],OnTapMain.Methods.NOTES_GET_NOTES[2],{
		Sort = SortType, 
		Cursor = Cursor, 
		PageSize = PageSize
	})
end



function OnTapMain:IsOnline()
	local Success , Result = pcall(function() 
		return OnTapMain.GetAsyncNetworkResult(table.unpack(OnTapMain.Methods.ONLINE)) 
	end)
	if Success then
		if Result then
			return true 
		end
	end

	return false 
end


return OnTapMain
