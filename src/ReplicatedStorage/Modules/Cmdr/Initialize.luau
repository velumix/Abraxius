local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local CreateGui = require(script.Parent.CreateGui)

return function(cmdr)
    -- Locate the client root. Cmdr's setup normally moves it from the server
    -- package into ReplicatedStorage on first run. If the server package has
    -- already been stripped (e.g. after play-mode restarts), reuse the existing
    -- ReplicatedStorage copy instead of failing.
    local ReplicatedRoot = script.Parent:FindFirstChild("CmdrClient")
    if not ReplicatedRoot then
        for _, child in ipairs(ReplicatedStorage:GetChildren()) do
            if child.Name == "CmdrClient" and child:FindFirstChild("Shared") then
                ReplicatedRoot = child
                break
            end
        end
    end
    if not ReplicatedRoot then
        error("Cmdr Initialize: CmdrClient could not be found under " ..
        script.Parent:GetFullName() .. " or ReplicatedStorage")
    end
    if ReplicatedRoot.Parent ~= ReplicatedStorage then
        ReplicatedRoot.Parent = ReplicatedStorage
    end

    local function getOrCreate(class, name, parent)
        parent = parent or ReplicatedRoot
        local existing = parent:FindFirstChild(name)
        if existing then
            return existing
        end
        local object = Instance.new(class)
        object.Name = name
        object.Parent = parent
        return object
    end

    local RemoteFunction = getOrCreate("RemoteFunction", "CmdrFunction")
    local RemoteEvent = getOrCreate("RemoteEvent", "CmdrEvent")

    getOrCreate("Folder", "Commands")
    getOrCreate("Folder", "Types")

    local shared = script.Parent:FindFirstChild("Shared")
    if shared and shared.Parent ~= ReplicatedRoot then
        shared.Parent = ReplicatedRoot
    end

    -- Fallback: if ReplicatedRoot has no populated Shared folder, clone it from the standalone CmdrClient.
    local function hasSharedModules(root)
        local folder = root:FindFirstChild("Shared")
        return folder ~= nil and folder:FindFirstChild("Util") ~= nil and folder:FindFirstChild("Registry") ~= nil
    end
    if not hasSharedModules(ReplicatedRoot) then
        local sourceRoot = ReplicatedStorage:FindFirstChild("CmdrClient")
        local sourceShared = sourceRoot and sourceRoot:FindFirstChild("Shared")
        if sourceShared then
            local existing = ReplicatedRoot:FindFirstChild("Shared")
            if existing then
                existing:Destroy()
            end
            sourceShared:Clone().Parent = ReplicatedRoot
        end
    end

    cmdr.ReplicatedRoot = ReplicatedRoot
    cmdr.RemoteFunction = RemoteFunction
    cmdr.RemoteEvent = RemoteEvent

    local builtInTypes = script.Parent:FindFirstChild("BuiltInTypes")
    if builtInTypes then
        cmdr:RegisterTypesIn(builtInTypes)
        builtInTypes:Destroy()
    end

    local builtInCommands = script.Parent:FindFirstChild("BuiltInCommands")
    if builtInCommands then
        builtInCommands.Name = "Server commands"
    end

    if StarterGui:FindFirstChild("Cmdr") == nil then
        CreateGui()
    end
end
