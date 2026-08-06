local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Modules.Signal)
local Trove = require(ReplicatedStorage.Modules.Trove)

local CameraControlManager = {
	Priority = {
		NORMAL = 0,
		CAMERA_ANGLES = 1,
		EXHIBIT = 2,
		SCAN = 3,
		SEQUENCE = 4,
	},

	ControlChanged = Signal.new(),
	ControlRequested = Signal.new(),
	ControlReleased = Signal.new(),

	_activeControllers = {},
	_currentOwner = nil,
	_currentPriority = -1,
	_trove = Trove.new(),
}

function CameraControlManager:RequestControl(systemName, priority, data)
	if not systemName or not priority then
		error("CameraControlManager:RequestControl requires systemName and priority")
	end

	if priority < self.Priority.NORMAL or priority > self.Priority.SEQUENCE then
		error("Invalid priority level: " .. tostring(priority))
	end

	if self._activeControllers[systemName] then
		local currentData = self._activeControllers[systemName]

		if currentData.priority == priority then
			currentData.data = data
			return true
		end

		if priority > currentData.priority then
			currentData.priority = priority
			currentData.data = data
		else
			return false
		end
	else
		self._activeControllers[systemName] = {
			priority = priority,
			data = data,
		}
	end

	self.ControlRequested:Fire(systemName, priority)

	self:_updateCameraOwnership()

	return self:HasControl(systemName)
end

function CameraControlManager:ReleaseControl(systemName)
	if not self._activeControllers[systemName] then
		return
	end

	self._activeControllers[systemName] = nil
	self.ControlReleased:Fire(systemName)

	self:_updateCameraOwnership()
end

function CameraControlManager:HasControl(systemName)
	return self._currentOwner == systemName
end

function CameraControlManager:GetCurrentOwner()
	return self._currentOwner, self._currentPriority
end

function CameraControlManager:GetOwnerData()
	if self._currentOwner and self._activeControllers[self._currentOwner] then
		return self._activeControllers[self._currentOwner].data
	end
	return nil
end

function CameraControlManager:GetActiveControllers()
	local controllers = {}
	for systemName, control in pairs(self._activeControllers) do
		table.insert(controllers, {
			systemName = systemName,
			priority = control.priority,
			data = control.data,
		})
	end

	table.sort(controllers, function(a, b)
		return a.priority > b.priority
	end)

	return controllers
end

function CameraControlManager:_updateCameraOwnership()
	local newOwner = nil
	local newPriority = -1

	for systemName, control in pairs(self._activeControllers) do
		if control.priority > newPriority then
			newOwner = systemName
			newPriority = control.priority
		end
	end

	if newOwner ~= self._currentOwner or newPriority ~= self._currentPriority then
		local previousOwner = self._currentOwner
		local previousPriority = self._currentPriority

		self._currentOwner = newOwner
		self._currentPriority = newPriority

		self.ControlChanged:Fire(previousOwner, newOwner, previousPriority, newPriority)
	end
end

function CameraControlManager:DebugPrintState()
	print("=== CameraControlManager State ===")
	print("Current Owner:", self._currentOwner or "NONE", "| Priority:", self._currentPriority)
	print("Active Controllers:")
	for systemName, control in pairs(self._activeControllers) do
		local priorityName = nil
		for name, level in pairs(self.Priority) do
			if level == control.priority then
				priorityName = name
				break
			end
		end
		print(string.format("  - %s: Priority=%d (%s)", systemName, control.priority, priorityName or "UNKNOWN"))
	end
	print("================================")
end

return CameraControlManager
