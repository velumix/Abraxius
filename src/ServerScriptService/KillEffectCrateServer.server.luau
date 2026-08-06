local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local KillEffectManager = require(ReplicatedStorage:WaitForChild("KillEffectManager"))
local KillEffectCrateManager = require(ServerScriptService:WaitForChild("KillEffectCrateManager"))

local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"))
local function svc(n) local ok, s = pcall(function() return Knit.GetService(n) end) return ok and s or nil end
local _coin
local function coinSvc() if not _coin then _coin = svc("CoinService") end return _coin end

local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local function ensureRemote(name)
	local r = Remotes:FindFirstChild(name)
	if not r then r = Instance.new("RemoteEvent"); r.Name = name; r.Parent = Remotes end
	return r
end
local KillEffectCratePurchase = ensureRemote("KillEffectCratePurchase")

KillEffectCratePurchase.OnServerEvent:Connect(function(player, crateName)
	if type(crateName) ~= "string" then return end
	local price = KillEffectManager.cratePrice(crateName)
	if not price then
		KillEffectCratePurchase:FireClient(player, crateName, false, "unknown")
		return
	end
	local paid = coinSvc():Spend(player, price)
	if paid then
		KillEffectCrateManager.openCrate(player, crateName)
		KillEffectCratePurchase:FireClient(player, crateName, true, "ok")
	else
		KillEffectCratePurchase:FireClient(player, crateName, false, "insufficient")
	end
end)
