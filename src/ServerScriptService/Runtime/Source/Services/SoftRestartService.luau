local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules
local Mince = require(Modules.Mince)

local SOFT_RESTART_SECONDS = 48 * 60 * 60
local CHECK_INTERVAL = 30
local TELEPORT_BATCH_SIZE = 50
local ANNOUNCE_COLOR = Color3.fromRGB(255, 200, 100)

local SoftRestartService = {
	Name = "SoftRestartService",
	RestartAfterSeconds = SOFT_RESTART_SECONDS,
	CheckInterval = CHECK_INTERVAL,
	WarningDuration = 10,
	TeleportBatchSize = TELEPORT_BATCH_SIZE,
	_startTime = 0,
	_restarting = false,
	_reservationCode = nil,
}

local function chunkPlayers(players, size)
	local batches = {}
	local batch = {}
	for _, player in ipairs(players) do
		table.insert(batch, player)
		if #batch >= size then
			table.insert(batches, batch)
			batch = {}
		end
	end
	if #batch > 0 then
		table.insert(batches, batch)
	end
	return batches
end

function SoftRestartService:_announce(text)
	for _, player in ipairs(Players:GetPlayers()) do
		if self.NoticeEvent then
			self.NoticeEvent:Fire(player, text, ANNOUNCE_COLOR, self.WarningDuration)
		end
	end
end

function SoftRestartService:_reserveServer()
	if self._reservationCode then
		return self._reservationCode
	end

	local ok, code = pcall(function()
		local accessCode = TeleportService:ReserveServerAsync(game.PlaceId)
		return accessCode
	end)

	if ok and code then
		self._reservationCode = code
		return code
	end

	warn("ReserveServerAsync failed:", code)
	return nil
end

function SoftRestartService:_teleportBatch(batch)
	if #batch == 0 then
		return
	end

	local teleportData = { SoftRestart = true }
	local options = Instance.new("TeleportOptions")
	options:SetTeleportData(teleportData)

	local reserveCode = self:_reserveServer()
	if reserveCode then
		options.ReservedServerAccessCode = reserveCode
	end

	local ok, err = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, batch, options)
	end)
	if not ok then
		warn("TeleportAsync failed:", err)
	end
end

function SoftRestartService:_teleportAll()
	local players = Players:GetPlayers()
	if #players == 0 then
		return
	end

	for _, batch in ipairs(chunkPlayers(players, self.TeleportBatchSize)) do
		self:_teleportBatch(batch)
		task.wait(0.2)
	end
end

function SoftRestartService:_queueTeleport(player)
	if not player then
		return
	end
	self:_teleportBatch({ player })
end

function SoftRestartService:BeginRestart()
	if self._restarting then
		return
	end
	self._restarting = true

	self:_announce("Server is refreshing. You will be moved to a new server.")
	task.wait(5)
	self:_teleportAll()
end

function SoftRestartService:Setup()
	self._startTime = os.time()
	self.NoticeEvent = Mince:GetEvent("NoticeEvent")

	Players.PlayerAdded:Connect(function(player)
		if self._restarting then
			self:_queueTeleport(player)
		end
	end)
end

function SoftRestartService:GameStart()
	task.spawn(function()
		while true do
			task.wait(self.CheckInterval)
			if self._restarting then
				return
			end
			local now = os.time()
			if now - self._startTime >= self.RestartAfterSeconds then
				self:BeginRestart()
				return
			end
		end
	end)
end

return SoftRestartService
