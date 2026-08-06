local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Knit = require(ReplicatedStorage.Packages.Knit)
local ModifierUtils = require(ServerScriptService.Modules:WaitForChild("ModifierUtils"))

local AdminSeekerService = Knit.CreateService({
	Name = "AdminSeekerService",
	Client = {
		Notify = Knit.CreateSignal(),
		UseAbility = Knit.CreateSignal(),
	},
})

local active = {
	player = nil,
	endsAt = nil,
	thread = nil,
	leaveConn = nil,
	effects = {},
}

local CONFIG = {
	duration = 60,
	passiveSpeed = 32,
	seekerBaseSpeed = 28,
	revealDuration = 4,
	stompRadius = 24,
	stompSlowDuration = 3,
	stompSlowSpeed = 8,
	speedBoostDuration = 5,
	speedBoostAmount = 40,
}

local function getHumanoid(player)
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

local function setWalkSpeed(player, speed)
	local hum = getHumanoid(player)
	if hum then
		hum.WalkSpeed = speed
	end
end

function AdminSeekerService:Start(duration: number?): (boolean, string)
	if not ModifierUtils.anyInRound() then
		return false, "No active match."
	end

	if active.player then
		self:Stop()
	end

	local seekers = {}
	ModifierUtils.forEachSeeker(function(player)
		table.insert(seekers, player)
	end)

	if #seekers == 0 then
		return false, "No seekers in the round."
	end

	local player = seekers[math.random(1, #seekers)]
	active.player = player
	active.endsAt = os.clock() + (duration or CONFIG.duration)

	setWalkSpeed(player, CONFIG.passiveSpeed)

	self.Client.Notify:Fire(player, {
		show = true,
		title = "ADMIN SEEKER",
		text = "Ability buttons are at the top of your screen.",
		duration = 6,
	})

	active.thread = task.delay(duration or CONFIG.duration, function()
		self:Stop()
	end)

	active.leaveConn = Players.PlayerRemoving:Connect(function(removed)
		if removed == active.player then
			self:Stop()
		end
	end)

	return true, player.Name
end

function AdminSeekerService:Stop()
	local previousPlayer = active.player

	if active.thread then
		task.cancel(active.thread)
		active.thread = nil
	end
	if active.leaveConn then
		active.leaveConn:Disconnect()
		active.leaveConn = nil
	end

	if previousPlayer then
		setWalkSpeed(previousPlayer, CONFIG.seekerBaseSpeed)
		self.Client.Notify:Fire(previousPlayer, {
			show = false,
			title = "ADMIN SEEKER",
			text = "Your admin powers have ended.",
			duration = 4,
		})
	end

	self:_clearEffects()

	active.player = nil
	active.endsAt = nil
end

function AdminSeekerService:Clear()
	self:Stop()
end

function AdminSeekerService:KnitStart()
	self.Client.UseAbility:Connect(function(player, id: string)
		if active.player ~= player then
			return
		end
		if id == "PaintStomp" then
			self:_paintStomp(player)
		elseif id == "RevealRoar" then
			self:_revealRoar(player)
		elseif id == "SpeedBoost" then
			self:_speedBoost(player)
		end
	end)
end

function AdminSeekerService:_paintStomp(player)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local position = root.Position
	self:_stompVisual(position)

	ModifierUtils.forEachHider(function(hider)
		local hiderChar = hider.Character
		if not hiderChar then
			return
		end
		local hiderRoot = hiderChar:FindFirstChild("HumanoidRootPart")
		if not hiderRoot then
			return
		end
		if (hiderRoot.Position - position).Magnitude <= CONFIG.stompRadius then
			self:_applySlow(hider, CONFIG.stompSlowDuration, CONFIG.stompSlowSpeed)
			self:_applyReveal(hider, CONFIG.stompSlowDuration)
		end
	end)
end

function AdminSeekerService:_revealRoar(_player)
	ModifierUtils.forEachHider(function(hider)
		self:_applyReveal(hider, CONFIG.revealDuration)
	end)
end

function AdminSeekerService:_speedBoost(player)
	local hum = getHumanoid(player)
	if not hum then
		return
	end
	hum.WalkSpeed = CONFIG.speedBoostAmount
	task.delay(CONFIG.speedBoostDuration, function()
		if player and player.Parent then
			local h = getHumanoid(player)
			if h then
				h.WalkSpeed = active.player == player and CONFIG.passiveSpeed or CONFIG.seekerBaseSpeed
			end
		end
	end)
end

function AdminSeekerService:_applySlow(player, duration, speed)
	local hum = getHumanoid(player)
	if not hum then
		return
	end
	local original = hum.WalkSpeed
	hum.WalkSpeed = speed

	local effect = {
		type = "slow",
		player = player,
		original = original,
	}
	effect.thread = task.delay(duration, function()
		if player and player.Parent then
			local h = getHumanoid(player)
			if h then
				h.WalkSpeed = original
			end
		end
		effect.finished = true
	end)
	table.insert(active.effects, effect)
end

function AdminSeekerService:_applyReveal(player, duration)
	local character = player.Character
	if not character then
		return
	end

	local existing = character:FindFirstChild("AdminSeekerReveal")
	if existing then
		existing:Destroy()
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "AdminSeekerReveal"
	highlight.FillColor = Color3.fromRGB(255, 40, 40)
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.FillTransparency = 0.5
	highlight.OutlineTransparency = 0
	highlight.Parent = character

	task.delay(duration, function()
		if highlight and highlight.Parent then
			highlight:Destroy()
		end
	end)
end

function AdminSeekerService:_clearEffects()
	for _, effect in ipairs(active.effects) do
		if effect.thread and not effect.finished then
			task.cancel(effect.thread)
		end
		if effect.type == "slow" and effect.player and effect.player.Parent then
			local h = getHumanoid(effect.player)
			if h then
				h.WalkSpeed = effect.original
			end
		end
	end
	table.clear(active.effects)

	for _, plr in ipairs(Players:GetPlayers()) do
		local character = plr.Character
		if character then
			local hl = character:FindFirstChild("AdminSeekerReveal")
			if hl then
				hl:Destroy()
			end
		end
	end
end

function AdminSeekerService:_stompVisual(position)
	local ring = Instance.new("Part")
	ring.Name = "AdminSeekerStomp"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.2, CONFIG.stompRadius * 2, CONFIG.stompRadius * 2)
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Color = Color3.fromRGB(255, 40, 80)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.3
	ring.Parent = Workspace

	TweenService:Create(
		ring,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.2, CONFIG.stompRadius * 4, CONFIG.stompRadius * 4), Transparency = 1 }
	):Play()

	task.delay(0.6, function()
		if ring and ring.Parent then
			ring:Destroy()
		end
	end)
end

return AdminSeekerService
