local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ModifierUtils = require(script.Parent:WaitForChild("ModifierUtils"))

local PaintFloorModifier = {}

local RISE_SPEED = 0.15
local DRAIN_SPEED = 4
local PAINT_THICKNESS = 0.5
local TOUCH_COOLDOWN = 0.2
local REVEAL_DURATION = 3
local SLOW_WALKSPEED = 8
local PAINT_MATERIAL = Enum.Material.Neon
local PAINT_TRANSPARENCY = 0.2
local HORIZONTAL_MARGIN = 10
local FLASH_MIN = 0.2
local FLASH_MAX = 0.7
local FLASH_SPEED = 4

function PaintFloorModifier.buildOptions(duration: number?)
	local paintPart: BasePart? = nil
	local heartbeatConn: RBXScriptConnection? = nil
	local touchConn: RBXScriptConnection? = nil
	local touchEndedConn: RBXScriptConnection? = nil
	local drainConn: RBXScriptConnection? = nil
	local monitorThread = nil
	local running = false
	local paintColor: Color3? = nil
	local groundY: number? = nil
	local lastTouched: { [Player]: number } = {}
	local activeEffects: { [Player]: { highlight: Highlight?, originalSpeed: number } } = {}
	local inPaint: { [Player]: number } = {}
	local leaveAt: { [Player]: number } = {}
	local maxHeight: number? = nil

	local function removeEffect(player: Player)
		local effect = activeEffects[player]
		if not effect then
			return
		end

		local character = player.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = effect.originalSpeed
			end
		end
		if effect.highlight and effect.highlight.Parent then
			effect.highlight:Destroy()
		end

		activeEffects[player] = nil
		inPaint[player] = nil
		leaveAt[player] = nil
		lastTouched[player] = nil
	end

	local function applyEffect(player: Player)
		if not ModifierUtils.inRound(player) then
			return
		end

		local now = os.clock()
		if (lastTouched[player] or 0) + TOUCH_COOLDOWN > now then
			return
		end
		lastTouched[player] = now

		local character = player.Character
		if not character then
			return
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end

		inPaint[player] = (inPaint[player] or 0) + 1
		leaveAt[player] = nil

		if activeEffects[player] then
			return
		end

		local role = ModifierUtils.getRole(player)
		local originalSpeed = humanoid.WalkSpeed
		humanoid.WalkSpeed = SLOW_WALKSPEED

		local highlight: Highlight? = nil
		if role == "Hider" then
			highlight = Instance.new("Highlight")
			highlight.Name = "PaintFloorReveal"
			highlight.Adornee = character
			highlight.FillColor = paintColor or Color3.fromRGB(255, 40, 120)
			highlight.OutlineColor = Color3.new(1, 1, 1)
			highlight.FillTransparency = FLASH_MIN
			highlight.OutlineTransparency = 0
			highlight.Parent = character
		end

		activeEffects[player] = { highlight = highlight, originalSpeed = originalSpeed }
	end

	local function onTouched(hit: BasePart)
		local character = hit:FindFirstAncestorOfClass("Model")
		if not character then
			return
		end
		local player = Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end
		applyEffect(player)
	end

	local function onTouchEnded(hit: BasePart)
		local character = hit:FindFirstAncestorOfClass("Model")
		if not character then
			return
		end
		local player = Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end

		local count = (inPaint[player] or 0) - 1
		inPaint[player] = math.max(0, count)
		if inPaint[player] <= 0 then
			leaveAt[player] = os.clock() + REVEAL_DURATION
		end
	end

	local function updateHighlights()
		local phase = (os.clock() * FLASH_SPEED) % (math.pi * 2)
		local transparency = FLASH_MIN + (FLASH_MAX - FLASH_MIN) * (0.5 + 0.5 * math.sin(phase))
		for _, effect in pairs(activeEffects) do
			local highlight = effect.highlight
			if highlight and highlight.Parent then
				highlight.FillTransparency = transparency
			end
		end
	end

	local function monitorEffects()
		local now = os.clock()
		for player, _ in pairs(activeEffects) do
			if (inPaint[player] or 0) <= 0 and (leaveAt[player] or math.huge) <= now then
				removeEffect(player)
			end
		end
	end

	local function destroyPaintPart()
		if drainConn then
			drainConn:Disconnect()
			drainConn = nil
		end
		if paintPart then
			paintPart:Destroy()
			paintPart = nil
		end
	end

	local function onStart()
		local bounds = ModifierUtils.getMapBounds()
		if not bounds then
			warn("[PaintFloorModifier] No active map bounds; cannot start paint floor.")
			return
		end

		destroyPaintPart()
		running = true
		paintColor = ModifierUtils.randomBrightColor()
		groundY = bounds.groundY
		maxHeight = groundY + 200

		local effectsFolder = Workspace:FindFirstChild("ModifierEffects")
		if not effectsFolder then
			effectsFolder = Instance.new("Folder")
			effectsFolder.Name = "ModifierEffects"
			effectsFolder.Parent = Workspace
		end

		paintPart = Instance.new("Part")
		paintPart.Name = "PaintFloor"
		paintPart.Anchored = true
		paintPart.CanCollide = false
		paintPart.CanTouch = true
		paintPart.CanQuery = false
		paintPart.Transparency = PAINT_TRANSPARENCY
		paintPart.Color = paintColor
		paintPart.Material = PAINT_MATERIAL
		paintPart.Size = Vector3.new(
			bounds.halfX * 2 + HORIZONTAL_MARGIN,
			PAINT_THICKNESS,
			bounds.halfZ * 2 + HORIZONTAL_MARGIN
		)
		paintPart.CFrame = CFrame.new(bounds.center.X, groundY - PAINT_THICKNESS / 2, bounds.center.Z)
		paintPart.Parent = effectsFolder

		touchConn = paintPart.Touched:Connect(onTouched)
		touchEndedConn = paintPart.TouchEnded:Connect(onTouchEnded)

		heartbeatConn = RunService.Heartbeat:Connect(function(dt)
			if not paintPart then
				return
			end
			local newY = paintPart.Position.Y + RISE_SPEED * dt
			if maxHeight and newY >= maxHeight then
				newY = maxHeight
				heartbeatConn:Disconnect()
				heartbeatConn = nil
			end
			paintPart.Position = Vector3.new(paintPart.Position.X, newY, paintPart.Position.Z)
		end)

		monitorThread = task.spawn(function()
			while running do
				updateHighlights()
				monitorEffects()
				task.wait(0.05)
			end
		end)
	end

	local function onStop()
		running = false

		if heartbeatConn then
			heartbeatConn:Disconnect()
			heartbeatConn = nil
		end
		if touchConn then
			touchConn:Disconnect()
			touchConn = nil
		end
		if touchEndedConn then
			touchEndedConn:Disconnect()
			touchEndedConn = nil
		end

		local playersToClear = {}
		for player in pairs(activeEffects) do
			table.insert(playersToClear, player)
		end
		for _, player in ipairs(playersToClear) do
			removeEffect(player)
		end
		table.clear(inPaint)
		table.clear(leaveAt)
		table.clear(lastTouched)

		if not paintPart or drainConn then
			return
		end

		local targetY = (groundY or paintPart.Position.Y) - PAINT_THICKNESS / 2
		drainConn = RunService.Heartbeat:Connect(function(dt)
			if not paintPart then
				return
			end
			local newY = paintPart.Position.Y - DRAIN_SPEED * dt
			if newY <= targetY then
				paintPart.Position = Vector3.new(paintPart.Position.X, targetY, paintPart.Position.Z)
				destroyPaintPart()
			else
				paintPart.Position = Vector3.new(paintPart.Position.X, newY, paintPart.Position.Z)
			end
		end)
	end

	return {
		duration = duration,
		onStart = onStart,
		onStop = onStop,
		meta = { rises = true },
	}
end

return PaintFloorModifier
