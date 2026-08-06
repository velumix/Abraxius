local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Knit = require(ReplicatedStorage.Packages.Knit)
local MapManager = require(ServerScriptService:WaitForChild("MapManager"))
local ModifierUtils = require(ServerScriptService.Modules:WaitForChild("ModifierUtils"))

local function svc(n) local ok, s = pcall(function() return Knit.GetService(n) end) return ok and s or nil end
local _coin
local function coinSvc() if not _coin then _coin = svc("CoinService") end return _coin end

local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local CoinCollected = Remotes:WaitForChild("CoinCollected")

local HiddenAdminService = Knit.CreateService({
	Name = "HiddenAdminService",
	Client = {},
})

local GROUP_ID = 133797237
local MIN_RANK = 200
local REWARD = 50
local NPC_SCALE = 0.3

local DEV_USER_IDS = {
	32933015,    -- sstrictly_business
	9498178206,  -- uuu111821
	2916335641,  -- Mikethelizard3009
	25451922,    -- mewantacookie2
	10751598093, -- MisfitsBSthree
	2715832384,  -- velumix
	2249165880,  -- QuestioningCarl
}

local active = {
	npcs = {},
}

local function getDevUserIds(): { number }
	if #DEV_USER_IDS > 0 then
		return DEV_USER_IDS
	end

	-- Fallback: if the list is empty, use ranked players currently in the server.
	local ids = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local ok, rank = pcall(function()
			return player:GetRankInGroupAsync(GROUP_ID)
		end)
		if ok and rank and rank >= MIN_RANK then
			table.insert(ids, player.UserId)
		end
	end

	if #ids == 0 then
		for _, player in ipairs(Players:GetPlayers()) do
			table.insert(ids, player.UserId)
		end
	end

	if #ids == 0 then
		ids = { 1 }
	end

	return ids
end

local function createAdminModel(position: Vector3, userId: number): (Model?, string?)
	local ok, dummy = pcall(function()
		return Players:CreateHumanoidModelFromUserId(userId)
	end)
	if not ok or not dummy then
		warn(`[HiddenAdminService] failed to create model for {userId}`)
		return nil, nil
	end

	local nameOk, username = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local displayName = nameOk and username or "Hidden Admin"

	dummy.Name = displayName

	-- strip scripts so it doesn't animate or break
	for _, descendant in ipairs(dummy:GetDescendants()) do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant:Destroy()
		end
	end

	local humanoid = dummy:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 0
		humanoid.AutoRotate = false
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.NameDisplayDistance = 0
	end

	local root = dummy:FindFirstChild("HumanoidRootPart")
	if root then
		root.Anchored = true

		-- Place the glow light inside the figurine itself (prefer torso/head so it glows from the body)
		local lightParent = dummy:FindFirstChild("UpperTorso")
			or dummy:FindFirstChild("Head")
			or dummy:FindFirstChild("LowerTorso")
			or root
		local light = Instance.new("PointLight")
		light.Color = ModifierUtils.randomBrightColor()
		light.Brightness = 2
		light.Range = math.random(2, 3)
		light.Shadows = false
		light.Parent = lightParent

		task.spawn(function()
			while light and light.Parent do
				local fadeIn = TweenService:Create(light, TweenInfo.new(0.6), { Brightness = 5 })
				fadeIn:Play()
				fadeIn.Completed:Wait()
				if not light then
					break
				end
				local fadeOut = TweenService:Create(light, TweenInfo.new(0.6), { Brightness = 1 })
				fadeOut:Play()
				fadeOut.Completed:Wait()
			end
		end)
	end

	pcall(function()
		dummy:ScaleTo(NPC_SCALE)
	end)
	dummy:PivotTo(CFrame.new(position))
	dummy.Parent = Workspace

	if root then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Grab"
		prompt.ObjectText = displayName
		prompt.HoldDuration = 0.2
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt.Parent = root
	end

	return dummy, displayName
end

function HiddenAdminService:Spawn(count: number?): (boolean, string)
	if not ModifierUtils.anyInRound() then
		return false, "No active match."
	end

	self:Clear()

	local devIds = getDevUserIds()
	if #devIds == 0 then
		return false, "No development team members found."
	end

	count = count or 5
	local spawned = 0
	for i = 1, count do
		local spawnCf = MapManager.getPlayerSpawnCFrame()
		if not spawnCf then
			return false, "No active map."
		end
		local offset = Vector3.new(math.random(-8, 8), 0, math.random(-8, 8))
		local pos = spawnCf.Position + offset
		local userId = devIds[math.random(1, #devIds)]
		local model, adminName = createAdminModel(pos, userId)
		if not model then
			continue
		end

		spawned += 1
		local entry = { model = model, adminName = adminName, collected = false }
		table.insert(active.npcs, entry)

		local root = model:FindFirstChild("HumanoidRootPart")
		if root then
			local prompt = root:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				entry.promptConn = prompt.Triggered:Connect(function(player)
					self:_collect(entry, player, adminName)
				end)
			end
		end
	end

	return true, `Spawned {spawned} hidden admins.`
end

function HiddenAdminService:_collect(entry, player: Player, adminName: string)
	if entry.collected then
		return
	end
	entry.collected = true
	coinSvc():Credit(player, REWARD, "Hidden Admin found")

	local root = entry.model and entry.model:FindFirstChild("HumanoidRootPart")
	local pos = root and root.Position
	if pos then
		CoinCollected:FireClient(player, pos, REWARD)
	end

	if entry.model and entry.model.Parent then
		entry.model:Destroy()
	end
end

function HiddenAdminService:Clear()
	for _, entry in ipairs(active.npcs) do
		if entry.promptConn then
			entry.promptConn:Disconnect()
		end
		if entry.model and entry.model.Parent then
			entry.model:Destroy()
		end
	end
	table.clear(active.npcs)
end

return HiddenAdminService
