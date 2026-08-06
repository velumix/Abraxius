-- Marketplace // Services 
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local LocalPlayer : Player = Players.LocalPlayer

local Mince = require(ReplicatedStorage.Modules.Mince)
local Queue = require(ReplicatedStorage.Modules.Queue)
local Utility = require(ReplicatedStorage.Modules.Utility)

local ProductScraper = {
	Memory = {},
	UserMemory = {} 
}

function ProductScraper:GetUserName(UserID : number, CallbackFn) 
	ProductScraper.Queue:Push(function()
		if ProductScraper.UserMemory[UserID] then 
			return CallbackFn(table.unpack(ProductScraper.UserMemory[UserID]))
		end
		
		ProductScraper.UserMemory[UserID] = {Players:GetNameFromUserIdAsync(UserID)}
		CallbackFn(table.unpack(ProductScraper.UserMemory[UserID]))
	end)
end

function ProductScraper:PlayerOwnsGamePass(GamePassID : number, CallbackFn) 
	ProductScraper.Queue:Push(function() 
		CallbackFn(MarketplaceService:UserOwnsGamePassAsync(LocalPlayer.UserId, GamePassID))
	end)
end
 
function ProductScraper:WhenProductInfo(AssetID : number, InfoType : Enum.InfoType?, CallbackFn : (ProductInfo)->()) 
	assert(Utility.AssertTypes(AssetID, "number")) 
	assert(Utility.AssertTypes(CallbackFn, "function")) 
	
	ProductScraper.Memory[InfoType] = ProductScraper.Memory[InfoType] or {} 
	
	ProductScraper.Queue:Push(function() 
		if ProductScraper.Memory[InfoType][AssetID] ~= nil then 
			CallbackFn(table.unpack(ProductScraper.Memory[InfoType][AssetID]))
		end
		
		ProductScraper.Memory[InfoType][AssetID] = {MarketplaceService:GetProductInfo(AssetID, InfoType)}
		
		
		CallbackFn(table.unpack(ProductScraper.Memory[InfoType][AssetID]))
	end)
end
 

function ProductScraper:Init() 
	ProductScraper.Queue = Queue.new() 	
	ProductScraper.Queue:RunPushedFunctions()  
	
end

ProductScraper:Init() ; return ProductScraper 