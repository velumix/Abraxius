-- AfkTag: shows a blue "AFK" label floating over a player's head while they have AFK toggled on.
-- Server-spawned BillboardGui so it replicates to everyone. Driven by AfkService:SetAfk via
-- AfkTag.setAfk(player, isAfk). Survives respawns: the per-player AFK state is tracked here and
-- re-applied whenever the player's character spawns, so the tag reappears on the new body.

local Players = game:GetService("Players")

local AfkTag = {}

local TAG_NAME = "AfkTag"  -- reserved BillboardGui name on the head

local afkState = {}  -- [userId] = true while AFK is toggled on

-- the head (R15 + R6 both name it "Head"); wait briefly for a fresh respawn
local function getHead(char)
	local h = char:FindFirstChild("Head")
	if h then return h end
	return char:WaitForChild("Head", 1.5)
end

local function removeFrom(char)
	if not char then return end
	local head = char:FindFirstChild("Head")
	if head then
		local existing = head:FindFirstChild(TAG_NAME)
		if existing then existing:Destroy() end
	end
end

-- Build the blue "AFK" billboard on the player's head (idempotent: clears any existing first).
local function buildFor(player)
	local char = player.Character
	if not char then return end
	removeFrom(char)
	local head = getHead(char)
	if not head then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = TAG_NAME
	billboard.Size = UDim2.fromScale(2, 0.6)        -- studs (scale of the part billboard space)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.4, 0)  -- float above the head
	billboard.AlwaysOnTop = true                     -- visible through walls/other players
	billboard.MaxDistance = 100
	billboard.LightInfluence = 0

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "AFK"
	-- white base so the UIGradient below shows at full, true color (a gradient multiplies the base)
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.Parent = billboard

	-- beautiful vertical blue gradient on the text: bright icy cyan-blue at the top, through a vivid
	-- azure, into a deep royal blue at the bottom. Slight glossy lift in the upper third.
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90  -- top -> bottom
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.00, Color3.fromRGB(195, 240, 255)),  -- icy highlight
		ColorSequenceKeypoint.new(0.35, Color3.fromRGB(80, 175, 255)),   -- bright azure
		ColorSequenceKeypoint.new(0.70, Color3.fromRGB(40, 120, 255)),   -- vivid blue
		ColorSequenceKeypoint.new(1.00, Color3.fromRGB(20, 70, 210)),    -- deep royal blue
	})
	gradient.Parent = label

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(8, 22, 60)   -- deep navy outline so the blue pops against any background
	stroke.Thickness = 2.5
	stroke.Parent = label

	billboard.Parent = head
end

-- Public: set a player's AFK tag on/off. Tracks state so respawns re-apply it.
function AfkTag.setAfk(player, isAfk)
	if not player then return end
	if isAfk then
		afkState[player.UserId] = true
		buildFor(player)
	else
		afkState[player.UserId] = nil
		removeFrom(player.Character)
	end
end

function AfkTag.isAfk(player)
	return player and afkState[player.UserId] == true
end

function AfkTag.init()
	local function hook(plr)
		plr.CharacterAdded:Connect(function(char)
			-- re-apply the tag on the new body if they're still AFK
			task.wait(0.3)
			if afkState[plr.UserId] and plr.Character == char then
				buildFor(plr)
			end
		end)
	end
	for _, plr in ipairs(Players:GetPlayers()) do hook(plr) end
	Players.PlayerAdded:Connect(hook)
	Players.PlayerRemoving:Connect(function(plr) afkState[plr.UserId] = nil end)
end

return AfkTag
