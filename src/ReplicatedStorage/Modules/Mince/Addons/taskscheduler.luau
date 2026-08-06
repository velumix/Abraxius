local RunService = game:GetService("RunService")

local Identity

export type Task = {
	callback: (() -> ())?,
	worker: any?,
	method: string?,
	args: { any }?,
	priority: number,
	name: string,
	timestamp: number,
	cancelled: boolean,
}

local TaskScheduler = {}
TaskScheduler.__index = TaskScheduler

TaskScheduler.Priority = table.freeze({
	CRITICAL = 0,
	HIGH = 1,
	NORMAL = 2,
	LOW = 3,
	DEFERRED = 4,
})

local MIN_PRIORITY = TaskScheduler.Priority.CRITICAL
local MAX_PRIORITY = TaskScheduler.Priority.DEFERRED

local function newQueue()
	return { items = {}, head = 1, tail = 0, size = 0 }
end

local function validatePriority(priority)
	assert(type(priority) == "number" and priority % 1 == 0, "Task priority must be an integer")
	assert(
		priority >= MIN_PRIORITY and priority <= MAX_PRIORITY,
		`Task priority must be between {MIN_PRIORITY} and {MAX_PRIORITY}`
	)
	return priority
end

local function createWorkerTask(worker, method: string, args: { any }, priority: number, name: string?): Task
	assert(worker ~= nil, "Parallel task worker is required")
	assert(type(method) == "string" and method ~= "", "Parallel task method must be a non-empty string")

	return {
		worker = worker,
		method = method,
		args = args,
		priority = validatePriority(priority),
		name = name or method,
		timestamp = os.clock(),
		cancelled = false,
	}
end

local function createTask(callback: () -> (), priority: number, name: string?): Task
	assert(type(callback) == "function", "Task callback must be a function")

	return {
		callback = callback,
		priority = validatePriority(priority),
		name = name or "unnamed",
		timestamp = os.clock(),
		cancelled = false,
	}
end

function TaskScheduler.new(config)
	config = config or {}

	local rateLimit = math.max(1, config.rateLimit or 1000)
	local self = setmetatable({
		_queues = {
			[0] = newQueue(),
			[1] = newQueue(),
			[2] = newQueue(),
			[3] = newQueue(),
			[4] = newQueue(),
		},
		_taskCount = 0,
		_running = false,
		_isPaused = false,
		_connection = nil,
		_stepEvent = config.stepEvent,
		_runInParallel = config.runInParallel == true,
		_timers = {},
		_recurringTasks = {},
		maxTasksPerFrame = math.max(1, config.maxTasksPerFrame or 10),
		timeBudgetSeconds = math.max(0, config.timeBudgetSeconds or ((config.timeBudgetMs or 2) / 1000)),
		enableRateLimit = config.enableRateLimit ~= false,
		rateLimit = rateLimit,
		_rateTokens = rateLimit,
		_lastTokenUpdate = os.clock(),
		parallelWorker = config.parallelWorker,
		enableMetrics = config.enableMetrics == true,
		_tasksCompleted = 0,
		_tasksQueued = 0,
		_tasksFailed = 0,
		_tasksCancelled = 0,
		_parallelTasksActive = 0,
		_totalTime = 0,
		_framesProcessed = 0,
	}, TaskScheduler)

	if config.autoStart then
		self:start()
	end

	return self
end

function TaskScheduler:enqueue(callback, priority, name)
	priority = priority or self.Priority.NORMAL
	local scheduledTask = createTask(callback, priority, name)
	local queue = self._queues[priority]
	queue.tail += 1
	queue.items[queue.tail] = scheduledTask
	queue.size += 1
	self._taskCount += 1
	self._tasksQueued += 1
	return scheduledTask
end

function TaskScheduler:enqueueBatch(callbacks, priority, basePrefix)
	assert(type(callbacks) == "table", "Callbacks must be provided as a table")
	local scheduledTasks = {}
	for index, callback in ipairs(callbacks) do
		local name = basePrefix and `{basePrefix}_{index}` or tostring(index)
		table.insert(scheduledTasks, self:enqueue(callback, priority, name))
	end
	return scheduledTasks
end

-- Closures cannot cross Actor VM boundaries. Parallel jobs therefore identify
-- a method on a Mince Worker Module and send only serializable arguments.
function TaskScheduler:enqueueWorker(worker, method, args, priority, name)
	local scheduledTask = createWorkerTask(worker, method, args or {}, priority or self.Priority.NORMAL, name)
	local queue = self._queues[scheduledTask.priority]
	queue.tail += 1
	queue.items[queue.tail] = scheduledTask
	queue.size += 1
	self._taskCount += 1
	self._tasksQueued += 1
	return scheduledTask
end

function TaskScheduler:enqueueParallel(method, args, priority, name)
	assert(self.parallelWorker ~= nil, "No parallelWorker was configured for this scheduler")
	return self:enqueueWorker(self.parallelWorker, method, args, priority, name)
end

function TaskScheduler:cancel(scheduledTask)
	if not scheduledTask or scheduledTask.cancelled then
		return false
	end

	scheduledTask.cancelled = true
	self._recurringTasks[scheduledTask] = nil
	local timerThread = self._timers[scheduledTask]
	if timerThread then
		self._timers[scheduledTask] = nil
		task.cancel(timerThread)
	end
	self._tasksCancelled += 1
	return true
end

function TaskScheduler:clear()
	for scheduledTask, timerThread in pairs(self._timers) do
		scheduledTask.cancelled = true
		task.cancel(timerThread)
	end
	table.clear(self._timers)
	for scheduledTask in pairs(self._recurringTasks) do
		scheduledTask.cancelled = true
	end
	table.clear(self._recurringTasks)

	for priority = MIN_PRIORITY, MAX_PRIORITY do
		self._queues[priority] = newQueue()
	end
	self._taskCount = 0
end

function TaskScheduler:getQueueSize()
	return self._taskCount
end

function TaskScheduler:getQueueSizeByPriority(priority)
	local queue = self._queues[validatePriority(priority)]
	return queue.size
end

function TaskScheduler:_replenishRateTokens(now)
	if not self.enableRateLimit then
		return
	end

	local elapsed = math.max(0, now - self._lastTokenUpdate)
	self._lastTokenUpdate = now
	self._rateTokens = math.min(self.rateLimit, self._rateTokens + elapsed * self.rateLimit)
end

function TaskScheduler:_pop(queue)
	local scheduledTask = queue.items[queue.head]
	queue.items[queue.head] = nil
	queue.head += 1
	queue.size -= 1
	self._taskCount -= 1

	if queue.size == 0 then
		queue.head = 1
		queue.tail = 0
	end

	return scheduledTask
end

function TaskScheduler:_queueDueRecurring(now)
	for recurringTask, schedule in pairs(self._recurringTasks) do
		if recurringTask.cancelled then
			self._recurringTasks[recurringTask] = nil
		elseif now >= schedule.nextRun and not schedule.queued then
			schedule.queued = true
			-- Preserve the requested cadence instead of rounding every interval up
			-- to the next render/simulation frame.
			schedule.nextRun += schedule.interval
			while schedule.nextRun <= now do
				schedule.nextRun += schedule.interval
			end
			self:enqueue(function()
				schedule.queued = false
				if not recurringTask.cancelled then
					recurringTask.callback()
				end
			end, recurringTask.priority, recurringTask.name)
		end
	end
end

function TaskScheduler:process()
	if self._isPaused then
		return 0
	end

	local tasksProcessed = 0
	local startedAt = os.clock()
	self:_queueDueRecurring(startedAt)
	if self._taskCount == 0 then
		return 0
	end
	self:_replenishRateTokens(startedAt)

	for priority = MIN_PRIORITY, MAX_PRIORITY do
		if tasksProcessed >= self.maxTasksPerFrame then
			break
		end

		local queue = self._queues[priority]
		while queue.size > 0 and tasksProcessed < self.maxTasksPerFrame do
			if self.timeBudgetSeconds > 0 and os.clock() - startedAt >= self.timeBudgetSeconds then
				break
			end
			if self.enableRateLimit and self._rateTokens < 1 then
				break
			end

			local scheduledTask = self:_pop(queue)
			if not scheduledTask.cancelled then
				if self.enableRateLimit then
					self._rateTokens -= 1
				end

				tasksProcessed += 1
				if scheduledTask.worker then
					self._parallelTasksActive += 1
					task.spawn(function()
						local success, err = xpcall(function()
							local workerMethod = scheduledTask.worker[scheduledTask.method]
							workerMethod(scheduledTask.worker, table.unpack(scheduledTask.args))
						end, debug.traceback)
						self._parallelTasksActive -= 1
						if success then
							self._tasksCompleted += 1
						else
							self._tasksFailed += 1
							warn(`[TaskScheduler] Parallel task '{scheduledTask.name}' failed:\n{err}`)
						end
					end)
				else
					local success, err = xpcall(scheduledTask.callback, debug.traceback)
					if success then
						self._tasksCompleted += 1
					else
						self._tasksFailed += 1
						warn(`[TaskScheduler] Task '{scheduledTask.name}' failed:\n{err}`)
					end
				end
			end
		end
	end

	if self.enableMetrics then
		self._totalTime += os.clock() - startedAt
		self._framesProcessed += 1
	end

	return tasksProcessed
end

function TaskScheduler:start()
	if self._running then
		return self
	end

	self._running = true
	local stepEvent = self._stepEvent or (Identity == "Client" and RunService.RenderStepped or RunService.Heartbeat)
	local connect = if self._runInParallel then stepEvent.ConnectParallel else stepEvent.Connect
	self._connection = connect(stepEvent, function()
		self:process()
	end)
	return self
end

function TaskScheduler:stop()
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end
	self._running = false
	return self
end

function TaskScheduler:destroy()
	self:stop()
	self:clear()
end

function TaskScheduler:pause(shouldPause)
	if shouldPause == nil then
		self._isPaused = not self._isPaused
	else
		self._isPaused = shouldPause == true
	end
	return self._isPaused
end

function TaskScheduler:spawn(callback, priority, name)
	return self:enqueue(callback, priority or self.Priority.NORMAL, name)
end

function TaskScheduler:defer(callback, name)
	return self:enqueue(callback, self.Priority.DEFERRED, name)
end

function TaskScheduler:delay(callback, delaySeconds, priority, name)
	assert(type(delaySeconds) == "number" and delaySeconds >= 0, "Delay must be a non-negative number")
	local scheduledTask = createTask(callback, priority or self.Priority.NORMAL, name)
	self._tasksQueued += 1

	self._timers[scheduledTask] = task.delay(delaySeconds, function()
		self._timers[scheduledTask] = nil
		if scheduledTask.cancelled then
			return
		end

		local queue = self._queues[scheduledTask.priority]
		queue.tail += 1
		queue.items[queue.tail] = scheduledTask
		queue.size += 1
		self._taskCount += 1
	end)

	return scheduledTask
end

function TaskScheduler:every(intervalSeconds, callback, priority, name, runImmediately)
	assert(type(intervalSeconds) == "number" and intervalSeconds > 0, "Interval must be greater than zero")
	assert(type(callback) == "function", "Task callback must be a function")

	local recurringTask = createTask(callback, priority or self.Priority.NORMAL, name)
	self._recurringTasks[recurringTask] = {
		interval = intervalSeconds,
		nextRun = os.clock() + (runImmediately and 0 or intervalSeconds),
		queued = false,
	}
	return recurringTask
end

function TaskScheduler:getMetrics()
	return {
		tasksCompleted = self._tasksCompleted,
		tasksQueued = self._tasksQueued,
		tasksFailed = self._tasksFailed,
		tasksCancelled = self._tasksCancelled,
		currentQueueSize = self._taskCount,
		parallelTasksActive = self._parallelTasksActive,
		totalExecutionTime = self._totalTime,
		averageFrameTime = self._framesProcessed > 0 and (self._totalTime / self._framesProcessed) or 0,
		isRunning = self._running,
		isPaused = self._isPaused,
	}
end

function TaskScheduler:printMetrics()
	if not self.enableMetrics then
		warn("Metrics disabled. Set enableMetrics = true on creation.")
		return
	end

	local metrics = self:getMetrics()
	print(
		string.format(
			"Tasks: %d/%d | Failed: %d | Queue: %d | Time: %.3fms",
			metrics.tasksCompleted,
			metrics.tasksQueued,
			metrics.tasksFailed,
			metrics.currentQueueSize,
			metrics.totalExecutionTime * 1000
		)
	)
end

local Scheduler = {
	SchedulerRegistry = {},
	DefaultScheduler = nil,
}

function Scheduler.createScheduler(config)
	local scheduler = TaskScheduler.new(config)
	table.insert(Scheduler.SchedulerRegistry, scheduler)
	if not Scheduler.DefaultScheduler then
		Scheduler.DefaultScheduler = scheduler
	end
	return scheduler
end

function Scheduler.new(config)
	return Scheduler.createScheduler(config)
end

function Scheduler.GetSchedulers()
	return Scheduler.SchedulerRegistry
end

function Scheduler.getDefault(config)
	if not Scheduler.DefaultScheduler then
		Scheduler.DefaultScheduler = Scheduler.createScheduler(config)
	end
	Scheduler.DefaultScheduler:start()
	return Scheduler.DefaultScheduler
end

return {
	Server = {
		Scheduler = Scheduler,
		TaskScheduler = TaskScheduler,
		Priority = TaskScheduler.Priority,
	},
	Client = {
		Scheduler = Scheduler,
		TaskScheduler = TaskScheduler,
		Priority = TaskScheduler.Priority,
	},
	Identity = function(identityValue)
		Identity = identityValue
	end,
}
