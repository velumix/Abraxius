-- Modules // Services -- 
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService") 
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local ServerModules = ServerScriptService:WaitForChild("Modules")
local Queue = require(ReplicatedStorage.Modules.Queue) 
local TipjarConfig = ServerModules:FindFirstChild("TipjarConfig")

local HTTPQueue = Queue.new() 
HTTPQueue.Step = 2 

local RobloxAPIHandler = { -- economy.roblox.com/v2/assets/${asset}/details
	CursorDepthLimit = 10,
	Proxy = "https://%sroproxy.com",
	GetAssetInfo = {"economy","/v2/assets/%s/details"},
	GetGameList = {"games","/v2/users/%s/games?accessFilter=2&limit=50"},
	GetGamepassList = {"games","/v1/games/%s/game-passes?sortOrder=Asc&limit=100"},
	GetUniverseGamepasses = {"apis","/game-passes/v1/universes/%s/game-passes?passView=Full&pageSize=%d"},
	InventoryGamepassItemsURL = {"games","/v2/users/%s/games?sortOrder=Asc&accessFilter=Public&limit=50&cursor=%s"},
	SearchMarketplaceURL = {"catalog","/v1/search/items/details?Category=All&SalesTypeFilter=Robux&SortOrder=Asc&Limit=%d&CreatorType=User&CreatorTargetId=%s"}, 
	GamePassPageLimit = 100,
	CatalogPageLimit = 30,

	HTTPQueue = HTTPQueue 
} 

function RobloxAPIHandler.Warn(...)
	warn("[RobloxAPIHandler]:",...)
end

function RobloxAPIHandler.CreateProxyURL(Builder) 
	local Prefix = Builder[1] and Builder[1] .. "." or "" 

	local URL =RobloxAPIHandler.Proxy:format(Prefix) 
	return URL .. Builder[2]
end

local function GetUniverseIdForUser(targetUserId)
	if TipjarConfig then
		local lookup = TipjarConfig:FindFirstChild("UniverseMap")
		if lookup and lookup:IsA("Folder") then
			local value = lookup:FindFirstChild(tostring(targetUserId))
			if value and value:IsA("StringValue") and value.Value ~= "" then
				return value.Value
			end
		end
	end

	return tostring(game.GameId)
end

local function FetchUniverseGamepassesViaApis(PlayerID)
	local universeId = GetUniverseIdForUser(PlayerID)
	if not universeId or universeId == "" then
		return false
	end

	local Aggregated = {}
	local pageToken
	local Depth = 0

	repeat
		HTTPQueue:PushAndWait()

		local RequestURL = RobloxAPIHandler.CreateProxyURL(RobloxAPIHandler.GetUniverseGamepasses):format(
			universeId,
			RobloxAPIHandler.GamePassPageLimit
		)
		if pageToken then
			RequestURL = RequestURL .. "&pageToken=" .. HttpService:UrlEncode(pageToken)
		end

		local Success, Result = pcall(function()
			return HttpService:GetAsync(RequestURL)
		end)

		if not Success then
			RobloxAPIHandler.Warn("Failure->", Result)
			return false
		end

		local JSONData : string = Result
		local DecodedSuccess, Decoded = pcall(function()
			return HttpService:JSONDecode(JSONData)
		end)

		if not DecodedSuccess or type(Decoded) ~= "table" then
			RobloxAPIHandler.Warn("Failure->", Decoded)
			return false
		end

		local DataBlock = (type(Decoded.data) == "table" and Decoded.data)
		if not DataBlock and type(Decoded.gamePasses) == "table" then
			DataBlock = Decoded.gamePasses
		end
		DataBlock = DataBlock or {}

		for _, Entry in ipairs(DataBlock) do
			table.insert(Aggregated, Entry)
		end

		pageToken = Decoded.nextPageToken or Decoded.nextPageCursor or nil
		if pageToken == "" then
			pageToken = nil
		end

		Depth = Depth + 1
		if Depth >= RobloxAPIHandler.CursorDepthLimit then
			pageToken = nil
		end
	until not pageToken

	return true, Aggregated
end

function RobloxAPIHandler.GetUpToDateProductInfo(AssetID) 
	HTTPQueue:PushAndWait()

	local RequestURL = RobloxAPIHandler.CreateProxyURL(RobloxAPIHandler.GetAssetInfo):format(AssetID) 
	local Success, Result = pcall(function() 
		return HttpService:GetAsync(RequestURL)
	end) 

	if not Success then 
		RobloxAPIHandler.Warn("Failure->",Result)
		return nil 
	end
	-----------------------------------------------
	local JSONData : string = Result
	local Success , Result = pcall(function()
		return HttpService:JSONDecode(JSONData)
	end)

	if not Success then
		RobloxAPIHandler.Warn("Failure->",Result)
		return false 
	end 
	-----------------------------------------------

	return Result
end

local function LegacyGetUserGamepassesFromGames(PlayerID) 

	HTTPQueue:PushAndWait()

	local RequestURL = RobloxAPIHandler.CreateProxyURL(RobloxAPIHandler.GetGameList):format(PlayerID)
	local Success, Result = pcall(function()
		return HttpService:GetAsync(RequestURL)
	end)
	if not Success then
		warn(RequestURL)
		RobloxAPIHandler.Warn("Failure->",Result)
		return false 
	end 
	-----------------------------------------------
	local JSONData : string = Result
	local Success , Result = pcall(function()
		return HttpService:JSONDecode(JSONData)
	end)

	if not Success then
		RobloxAPIHandler.Warn("Failure->",Result)
		return false 
	end 
	-----------------------------------------------

	local UniverseIDs = {} 

	if type(Result.data) == "table" then 
		for _, placeData in Result.data do 
			if placeData and placeData.id then
				table.insert(UniverseIDs, placeData.id)
			end
		end
	end

	local GamepassData = {} 

	for _, universeId in ipairs(UniverseIDs) do 
		HTTPQueue:PushAndWait()
		local RequestURL = RobloxAPIHandler.CreateProxyURL(RobloxAPIHandler.GetGamepassList):format(universeId)
		local Success, Result = pcall(function()
			return HttpService:GetAsync(RequestURL)
		end)
		if Success then
			local JSONData : string = Result
			local Success , Result = pcall(function()
				return HttpService:JSONDecode(JSONData)
			end)

			if Success then
				if Result.data and #Result.data > 0 then 
					for _,RawGamepassData in Result.data do 
						table.insert(GamepassData,RawGamepassData)	
					end
				end
			end 
		else
			local message = tostring(Result)
			if not message:find("HTTP 404") then
				warn("======ERROR====")
				warn(RequestURL)
				warn(Result)
			end
		end
	end

	return true, GamepassData
end

function RobloxAPIHandler.GetUserGamepassesFromGames(PlayerID)
	local Success, Data = FetchUniverseGamepassesViaApis(PlayerID)
	if Success and type(Data) == "table" and #Data > 0 then
		return true, Data
	end

	if not Success then
		RobloxAPIHandler.Warn("Falling back to legacy game-pass crawl for", PlayerID)
	end
	return LegacyGetUserGamepassesFromGames(PlayerID)
end

local function InventoryGamepassItemsRecursiveAsync(PlayerID, Items, Cursor, Depth) 

	HTTPQueue:PushAndWait()

	Depth = (Depth and Depth+1) or 0 
	Items = Items or {}  
	Cursor = Cursor or "" 
	local RequestURL = RobloxAPIHandler.CreateProxyURL(RobloxAPIHandler.InventoryGamepassItemsURL):format(PlayerID,Cursor)
	local Success, Result = pcall(function()
		return HttpService:GetAsync(RequestURL)
	end)

	if not Success then
		RobloxAPIHandler.Warn("Failure->",Result)
		return false 
	end 
	-----------------------------------------------
	local JSONData : string = Result
	local Success , Result = pcall(function()
		return HttpService:JSONDecode(JSONData)
	end)

	if not Success then
		RobloxAPIHandler.Warn("Failure->",Result)
		return false 
	end 
	-----------------------------------------------

end

local function FetchCreatorCatalogItems(playerId)
	local aggregated = {}
	local cursor
	local depth = 0

	repeat
		HTTPQueue:PushAndWait()

		local requestUrl = RobloxAPIHandler.CreateProxyURL(RobloxAPIHandler.SearchMarketplaceURL):format(
			RobloxAPIHandler.CatalogPageLimit,
			tostring(playerId)
		)
		if cursor then
			requestUrl = requestUrl .. "&cursor=" .. HttpService:UrlEncode(cursor)
		end

		local success, response = pcall(function()
			return HttpService:GetAsync(requestUrl)
		end)

		if not success then
			RobloxAPIHandler.Warn("Failure->", response)
			return false
		end

		local decodeSuccess, decoded = pcall(function()
			return HttpService:JSONDecode(response)
		end)

		if not decodeSuccess or type(decoded) ~= "table" then
			RobloxAPIHandler.Warn("Failure->", decoded)
			return false
		end

		local dataBlock = (type(decoded.data) == "table" and decoded.data) or {}
		for _, item in ipairs(dataBlock) do
			table.insert(aggregated, item)
		end

		cursor = decoded.nextPageCursor
		if cursor == "" then
			cursor = nil
		end

		depth += 1
		if depth >= RobloxAPIHandler.CursorDepthLimit then
			cursor = nil
		end
	until not cursor

	return true, aggregated
end


function RobloxAPIHandler.GetUserCatalogItems(playerId)
	return FetchCreatorCatalogItems(playerId)
end

function RobloxAPIHandler.GetUserSaleInventory(playerId)
	local passSuccess, passes = RobloxAPIHandler.GetUserGamepassesFromGames(playerId)
	local catalogSuccess, catalogItems = FetchCreatorCatalogItems(playerId)

	if not passSuccess and not catalogSuccess then
		return false
	end

	return true, {
		gamePasses = passSuccess and passes or {},
		catalogItems = catalogSuccess and catalogItems or {},
	}
end

function RobloxAPIHandler.Init() 
	local CheckNewPLayerCount = function() 
		local PlayerCount = #Players:GetChildren()

		if PlayerCount > 1 or RunService:IsStudio()  then 
			HTTPQueue.Step = 0.2 
		else 
			HTTPQueue.Step = 3 
		end
	end

	Players.PlayerAdded:Connect(CheckNewPLayerCount)
	Players.PlayerRemoving:Connect(CheckNewPLayerCount) 
	task.defer(CheckNewPLayerCount)	
end

RobloxAPIHandler.Init()
return RobloxAPIHandler