local LightRunner = _G.LightRunner
local Task = require(script.Parent.Task)

local CONFIG = {
	TIMEOUT_WARNING_DURATION = 2,
	TIMEOUT_MAX_DURATION = 5,
	ASSET_PRELOAD_RESOLUTION = 30,
	RBXASSETID_PREFIX = "rbxassetid://",
	RBXASSETID_PREFIX_LENGTH = 13,
}

local ProgressWait = function(Duration, Progress)
	local Resolution = CONFIG.ASSET_PRELOAD_RESOLUTION
	for Position=1,Resolution do 
		Progress(Position/Resolution)
		task.wait(Duration/Resolution)
	end
end

local ContentProvider = game:GetService("ContentProvider")

local IsValidAssetId = function(assetString)
	return type(assetString) == "string" and assetString:sub(1, CONFIG.RBXASSETID_PREFIX_LENGTH) == CONFIG.RBXASSETID_PREFIX
end

local LimitedWait = function(LoadingManager, Progress, Finish, ConditionFn)
	local OriginalDescriptor = LoadingManager.CurrentTask and LoadingManager.CurrentTask.Descriptor 
	local TimeElapsed = 0

	repeat 
		if not OriginalDescriptor then 
			OriginalDescriptor = LoadingManager.CurrentTask and LoadingManager.CurrentTask.Descriptor  
		end

		TimeElapsed += task.wait()
		if TimeElapsed > CONFIG.TIMEOUT_WARNING_DURATION then 
			local WaitLeft = math.floor(CONFIG.TIMEOUT_MAX_DURATION - (TimeElapsed - CONFIG.TIMEOUT_WARNING_DURATION)) - CONFIG.TIMEOUT_WARNING_DURATION
			LoadingManager.CurrentTask.Descriptor = `{OriginalDescriptor or "CurrentTask.NotRetrieved"} ({math.max(0, WaitLeft+1)})`
			Progress(1 - (WaitLeft / (CONFIG.TIMEOUT_MAX_DURATION - CONFIG.TIMEOUT_WARNING_DURATION)))
			if TimeElapsed > CONFIG.TIMEOUT_MAX_DURATION then 
				warn(`Loading timeout exceeded for task: {OriginalDescriptor}`)
				return Finish()
			end
		end
	until ConditionFn() 
end

local TaskArray = { 
	Task.New{
		-- Here the server code runs, preventing any client code from starting until this step is finished
		-- This will most likely only be a problem in servers players are teleported too, or in studio. Because this only becomes a blocker
		-- when a server is spooling/starting up..
		Descriptor = "Waiting For Server",
		Worker = function(_, Finish)  
			LightRunner:Get("Runner"):Get("Mince"):WaitUntilSetup("Server")
			Finish() 
		end,
	},
	Task.New{
		-- This is the client scripts setting up and then completing aka start
		Descriptor = "Client Scripts Intializing",
		Worker = function(_, Finish)  
			LightRunner:Get("Runner"):Get("Mince"):WhenStart(Finish)
		end,
	},
	Task.New{
		-- The Mince Handshake is to ensure, that the client and server are both setup, and are ready to start recieivng/sending communications. 
		-- For the most part the server will be able to recieve signals instantly because the client only runs when the server is done. 
		-- But the server will wait until the client's setup before it starts sending anything.
		-- Just to ensure that the client never misses important updates like a non request based playredata update or anything else.
		-- This is literally a "ping pong" so it's usally the players ping (less than 1s).   
		Descriptor = "Syncing With Server",
		Worker = function(_, Finish)  
			LightRunner:Get("Runner"):Get("Mince"):WaitUntilHandshake(game:GetService("Players").LocalPlayer)
			Finish() 
		end,
	},
	Task.New{
		-- Now that both the server and client are setup and the handshake is completed, the client will start recieving updates. 
		-- For most code in games the uis won't be able to update unless they have playerdata, which will be recieved in this step. 
		Descriptor = "Loading Player Data",
		Worker = function(Progress, Finish)  
			local Mince = LightRunner:Get("Runner"):Get("Mince")
			Progress(0.5)
			Mince:WhenStart(function() 
				local UserProfile = Mince:Get("UserProfile")	
				UserProfile:WaitUntilLoaded() 
				Finish()
			end) 
		end,
	},
	Task.New{
		-- Only after all of the code related stuff is done should we do any of the asset loading/ world loading. 
		-- This is a basic game.Loaded() 
		Descriptor = "Loading Game World",
		Worker = function(_, Finish) 
			if not game:IsLoaded() then
				game.Loaded:Wait()
			end
			Finish() 
		end,
	},	
	Task.New{
		StartEarly = true, -- Starts right away, but it's progress will be visible later.
		Descriptor = "Loading Sound Effects", 
		Worker = function(Progress, Finish, LoadingManager, ThisTask) 
			if not game:IsLoaded() then
				game.Loaded:Wait()
			end

			local Mince = LightRunner:Get("Runner"):Get("Mince")
			Mince:WaitUntilSetup("Client")
			local SoundHandler = Mince:Get("SoundHandler")

			local SoundContent = {} 

			for _, Source in SoundHandler.Sources do 
				for _, SoundAsset in Source.SoundIDs do 
					if IsValidAssetId(SoundAsset) then 
						table.insert(SoundContent, SoundAsset)
					end
				end
			end

			-- If no sounds to load, just finish
			if #SoundContent == 0 then
				Finish()
				return
			end

			local LoadedCount = 0 
			local success, err = pcall(function()
				ContentProvider:PreloadAsync(SoundContent, function(_)
					LoadedCount += 1 
					Progress(LoadedCount / #SoundContent)
				end)
			end)

			if not success then
				warn(`Failed to preload sound effects: {err}`)
				Finish()
				return
			end

			repeat task.wait() until ThisTask == LoadingManager.CurrentTask -- Once it gets to this step do the LimitedWait.

			LimitedWait(LoadingManager, Progress, Finish, function() 
				return LoadedCount == #SoundContent
			end)
			Finish() 
		end,
	},
	Task.New{
		StartEarly = true,
		Descriptor = "Loading User Interfaces", 
		Worker = function(Progress, Finish, LoadingManager, ThisTask) 
			local Guis = game.StarterGui:GetDescendants() 
			local Loaded = {} 
			local ImageContent = {} 
			for Position, Item in ipairs(Guis) do
				if (Item:IsA("ImageButton") or Item:IsA("ImageLabel")) and Item.Image and IsValidAssetId(Item.Image) and not Loaded[Item.Image] then 
					Loaded[Item.Image] = true 
					table.insert(ImageContent, Item.Image)
				end
			end

			Loaded = nil 

			-- If no images to load, just finish
			if #ImageContent == 0 then
				Finish()
				return
			end

			local LoadedCount = 0 
			local success, err = pcall(function()
				ContentProvider:PreloadAsync(ImageContent, function(assetId, assetFetchStatus)
					LoadedCount += 1 
					Progress(LoadedCount / #ImageContent)
				end)
			end)

			if not success then
				warn(`Failed to preload UI images: {err}`)
				Finish()
				return
			end

			repeat task.wait() until ThisTask == LoadingManager.CurrentTask

			LimitedWait(LoadingManager, Progress, Finish, function() 
				return LoadedCount == #ImageContent
			end)

			Finish() 
		end,
	},--
}

return TaskArray




