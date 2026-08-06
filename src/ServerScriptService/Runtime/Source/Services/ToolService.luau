local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InsertService = game:GetService("InsertService")

local Mince = require(ReplicatedStorage.Modules.Mince)
local StoreItems = Mince.Config.StoreItems

local TIPJAR_GROUP_ID = 12889407
local TIPJAR_ITEM_NAME = "TipJar"
local TIPJAR_SLOT = "Tool"
local DEFAULT_TOOLS = {
}
local TOPBAR_ONLY_TOOLS = {
    Flashlight = true,
}

local function getToolSpeedMultiplier(itemData)
    local stats = itemData and itemData.Stats
    if not stats then
        return nil
    end

    local multiplier = stats.SwimSpeedMultiplier or stats.SpeedMultiplier
    if typeof(multiplier) == "number" then
        return math.max(multiplier, 0)
    end

    local swimSpeed = stats.SwimSpeed
    if typeof(swimSpeed) == "number" then
        return math.max(1 + swimSpeed, 0)
    end

    return nil
end

local ToolService = {
    Name = "ToolService",
    ActiveTools = {},
    PlayerConnections = {},
    ToolCache = {},
}

function ToolService:Setup()
    self.PlayerDataManager = Mince:Get("PlayerDataManager")
    self.ActiveTools = {}
    self.PlayerConnections = {}
    self.ToolCache = {}

    Players.PlayerAdded:Connect(function(player)
        self:TrackPlayer(player)
    end)

    Players.PlayerRemoving:Connect(function(player)
        self:CleanupPlayer(player)
    end)

    for _, player in ipairs(Players:GetPlayers()) do
        self:TrackPlayer(player)
    end

    if self.PlayerDataManager.ProfileLoaded then
        self.PlayerDataManager.ProfileLoaded:Connect(function(player, profile)
            if profile and profile.Data then
                self:SyncTipJar(player, profile)
                self:GiveDefaultTools(player, profile)
                self:ApplyEquippedTools(player, profile.Data.OwnedItems)
            else
                self:ApplyEquippedTools(player)
            end
        end)
    end

    if self.PlayerDataManager.ProfileReleased then
        self.PlayerDataManager.ProfileReleased:Connect(function(player)
            self:ClearTools(player)
        end)
    end
end

function ToolService:TrackPlayer(player)
    self:DisconnectPlayer(player)
    self.PlayerConnections[player] = {}

    local charConn = player.CharacterAdded:Connect(function()
        self:ApplyPlayerTools(player)
    end)
    self.PlayerConnections[player].CharacterAdded = charConn

    if player.Character then
        task.defer(function()
            self:ApplyPlayerTools(player)
        end)
    end
end

function ToolService:DisconnectPlayer(player)
    local connections = self.PlayerConnections[player]
    if connections then
        for _, conn in pairs(connections) do
            if conn.Connected then
                conn:Disconnect()
            end
        end
        self.PlayerConnections[player] = nil
    end
end

function ToolService:CleanupPlayer(player)
    self:ClearTools(player)
    self:DisconnectPlayer(player)
end

function ToolService:SyncTipJar(player, profile)
    if not player or not profile or not profile.Data then
        return
    end

    local ownedItems = profile.Data.OwnedItems
    if type(ownedItems) ~= "table" then
        ownedItems = {}
        profile.Data.OwnedItems = ownedItems
    end

    local ok, inGroup = pcall(function()
        return player:IsInGroup(TIPJAR_GROUP_ID)
    end)
    if not ok then
        inGroup = false
    end

    local entry = ownedItems[TIPJAR_ITEM_NAME]
    local modified = false

    if inGroup then
        if not entry then
            entry = {
                Owned = true,
                Equipped = true,
                Category = "Tools",
                Slot = TIPJAR_SLOT,
                Granted = true,
            }
            ownedItems[TIPJAR_ITEM_NAME] = entry
            modified = true
        else
            if not entry.Owned then
                entry.Owned = true
                modified = true
            end
            if entry.Category ~= "Tools" then
                entry.Category = "Tools"
                modified = true
            end
            if entry.Slot ~= TIPJAR_SLOT then
                entry.Slot = TIPJAR_SLOT
                modified = true
            end
            if entry.Granted ~= true then
                entry.Granted = true
                modified = true
            end
        end
    elseif entry and entry.Granted then
        ownedItems[TIPJAR_ITEM_NAME] = nil
        modified = true
    end

    if modified and self.PlayerDataManager and self.PlayerDataManager.UpdatePlayer then
        self.PlayerDataManager:UpdatePlayer(player, "OwnedItems")
    end
end

function ToolService:GiveDefaultTools(player, profile)
    if not player or not profile or not profile.Data then
        return
    end

    local ownedItems = profile.Data.OwnedItems
    if type(ownedItems) ~= "table" then
        ownedItems = {}
        profile.Data.OwnedItems = ownedItems
    end

    local modified = false
    for itemName, defaults in pairs(DEFAULT_TOOLS) do
        local state = ownedItems[itemName]
        if not state then
            ownedItems[itemName] = {
                Owned = true,
                Equipped = true,
                Category = defaults.Category,
                Slot = defaults.Slot,
                Granted = true,
            }
            modified = true
        else
            if state.Owned ~= true then
                state.Owned = true
                modified = true
            end
            if state.Equipped ~= true then
                state.Equipped = true
                modified = true
            end
            if state.Category ~= defaults.Category then
                state.Category = defaults.Category
                modified = true
            end
            if state.Slot ~= defaults.Slot then
                state.Slot = defaults.Slot
                modified = true
            end
            if state.Granted ~= true then
                state.Granted = true
                modified = true
            end
        end
    end

    if modified and self.PlayerDataManager and self.PlayerDataManager.UpdatePlayer then
        self.PlayerDataManager:UpdatePlayer(player, "OwnedItems")
    end
end

function ToolService:GetToolFolder()
    if self.ToolFolder and self.ToolFolder.Parent then
        return self.ToolFolder
    end

    local assets = ReplicatedStorage:FindFirstChild("Assets")
    if not assets then
        warn("ReplicatedStorage.Assets not found")
        return nil
    end

    self.ToolFolder = assets:FindFirstChild("Tools")
    if not self.ToolFolder then
        warn("Assets.Tools folder missing")
    end

    return self.ToolFolder
end

function ToolService:GetCosmeticsFolder()
    if self.CosmeticsFolder and self.CosmeticsFolder.Parent then
        return self.CosmeticsFolder
    end

    local assets = ReplicatedStorage:FindFirstChild("Assets")
    if not assets then
        warn("ReplicatedStorage.Assets not found")
        return nil
    end

    self.CosmeticsFolder = assets:FindFirstChild("Cosmetics")
    if not self.CosmeticsFolder then
        warn("Assets.Cosmetics folder missing")
    end

    return self.CosmeticsFolder
end

function ToolService:GetPlushiesFolder()
    if self.PlushiesFolder and self.PlushiesFolder.Parent then
        return self.PlushiesFolder
    end

    local cosmetics = self:GetCosmeticsFolder()
    if not cosmetics then
        return nil
    end

    self.PlushiesFolder = cosmetics:FindFirstChild("Plushies")
    if not self.PlushiesFolder then
        warn("Assets.Cosmetics.Plushies folder missing")
    end

    return self.PlushiesFolder
end

function ToolService:GetItemData(itemName)
    local categories = StoreItems and StoreItems.Categories
    if not categories then
        return nil
    end

    local tools = categories.Tools
    if tools and tools[itemName] then
        return tools[itemName]
    end

    local cosmetics = categories.Cosmetics
    local cosmeticItem = cosmetics and cosmetics[itemName]
    if cosmeticItem and (cosmeticItem.Slot == "Tool" or cosmeticItem.Slot == "Plushie") then
        return cosmeticItem
    end

    return nil
end

function ToolService:LoadToolAsset(itemName, assetId)
    local folder = self:GetToolFolder()
    if not folder then
        return nil
    end

    local success, model = pcall(InsertService.LoadAsset, InsertService, assetId)
    if not success or not model then
        warn("Failed to load tool asset", assetId, "for", itemName)
        return nil
    end

    local tool = model:FindFirstChildWhichIsA("Tool", true)
    if tool then
        tool.Name = itemName
        tool.Parent = folder
    else
        warn("No tool found in asset", assetId, "for", itemName)
    end

    model:Destroy()
    return tool
end

function ToolService:GetToolTemplate(itemName)
    local cached = self.ToolCache[itemName]
    if cached ~= nil then
        return cached or nil
    end

    local folder = self:GetToolFolder()
    local template = nil
    local itemData = self:GetItemData(itemName)

    -- Item isn't in the store config anymore (stale player data or renamed item).
    -- Don't spam warnings for items we no longer support.
    if not itemData then
        self.ToolCache[itemName] = false
        return nil
    end

    if itemData.Object and itemData.Object:IsA("Tool") then
        template = itemData.Object
    elseif itemData.Slot == "Plushie" then
        local plushies = self:GetPlushiesFolder()
        if plushies then
            local found = plushies:FindFirstChild(itemName)
            if found and found:IsA("Tool") then
                template = found
            else
                warn(string.format("Plushie '%s' is not a Tool in Assets.Cosmetics.Plushies", itemName))
            end
        end
    elseif folder then
        local found = folder:FindFirstChild(itemName)
        if found and found:IsA("Tool") then
            template = found
        end
    end

    if not template then
        warn(string.format("Unable to locate tool asset '%s'", itemName))
    end

    self.ToolCache[itemName] = template or false
    return template
end

function ToolService:GetBackpack(player)
    local backpack = player:FindFirstChildOfClass("Backpack") or player:FindFirstChild("Backpack")
    if backpack then
        return backpack
    end

    local ok, result = pcall(function()
        return player:WaitForChild("Backpack", 5)
    end)

    if ok then
        return result
    end

    return nil
end

function ToolService:GiveTool(player, itemName)
    if TOPBAR_ONLY_TOOLS[itemName] then
        return
    end

    local template = self:GetToolTemplate(itemName)
    if not template then
        return
    end

    local backpack = self:GetBackpack(player)
    if not backpack then
        warn(string.format("Backpack missing for %s while equipping %s", player.Name, itemName))
        return
    end

    local tool = template:Clone()
    tool.Name = itemName
    tool:SetAttribute("StoreItemName", itemName)
    local itemData = self:GetItemData(itemName)
    local toolMultiplier = getToolSpeedMultiplier(itemData)
    if typeof(toolMultiplier) == "number" then
        tool:SetAttribute("ToolSwimSpeedMultiplier", toolMultiplier)
    end
    tool.Parent = backpack

    self.ActiveTools[player] = self.ActiveTools[player] or {}
    self.ActiveTools[player][itemName] = tool
end

function ToolService:ClearTools(player)
    local tracked = self.ActiveTools[player]
    if not tracked then
        return
    end

    for _, tool in pairs(tracked) do
        if tool then
            tool:Destroy()
        end
    end

    self.ActiveTools[player] = nil
end

function ToolService:ApplyEquippedTools(player, ownedItems)
    if not player or not player:IsDescendantOf(Players) then
        return
    end

    self:ClearTools(player)

    for itemName, itemState in pairs(ownedItems or {}) do
        local isToolSlot = itemState.Slot == "Tool" or itemState.Slot == "Plushie"
        if itemState.Equipped and (itemState.Category == "Tools" or isToolSlot) and not TOPBAR_ONLY_TOOLS[itemName] then
            self:GiveTool(player, itemName)
        end
    end
end

function ToolService:ApplyPlayerTools(player)
    if not player or not player:IsDescendantOf(Players) then
        return
    end

    task.spawn(function()
        local success, profile = pcall(function()
            return self.PlayerDataManager:GetProfile(player)
        end)

        if not success or not profile or not profile.Data then
            return
        end

        self:SyncTipJar(player, profile)
        self:GiveDefaultTools(player, profile)
        self:ApplyEquippedTools(player, profile.Data.OwnedItems)
    end)
end

return ToolService
