-- @author Velumix
-- @version 0.0.1
-- Built-in unit-test harness. Usage: require(ServerStorage.UnitTest.RunUnitTest)(filter, timeout)
local ServerStorage = game:GetService("ServerStorage")

local function formatValue(value)
	return if type(value) == "string" then string.format("%q", value) else tostring(value)
end

local expect = {}
function expect.equal(actual, expected)
	if actual ~= expected then
		error(`expected {formatValue(expected)}, got {formatValue(actual)}`, 2)
	end
end
function expect.truthy(value)
	if not value then
		error(`expected truthy, got {formatValue(value)}`, 2)
	end
end
function expect.falsy(value)
	if value then
		error(`expected falsy, got {formatValue(value)}`, 2)
	end
end
function expect.throws(callback)
	local ok, message = pcall(callback)
	if ok then
		error("expected the function to throw", 2)
	end
	return message
end
function expect.deepEqual(actual, expected)
	local function equal(left, right)
		if left == right then
			return true
		end
		if type(left) ~= "table" or type(right) ~= "table" then
			return false
		end
		for key, value in pairs(left) do
			if not equal(value, right[key]) then
				return false
			end
		end
		for key in pairs(right) do
			if left[key] == nil then
				return false
			end
		end
		return true
	end
	if not equal(actual, expected) then
		error("tables are not deeply equal", 2)
	end
end

local function runOne(callback, timeout)
	local done, ok, message = false, false, nil
	local started = os.clock()
	task.spawn(function()
		ok, message = pcall(callback)
		done = true
	end)
	while not done and os.clock() - started < timeout do
		task.wait()
	end
	if not done then
		return "timeout", os.clock() - started, `exceeded {timeout}s`
	end
	return if ok then "pass" else "fail", os.clock() - started, message
end

return function(filter, timeout)
	timeout = timeout or 5
	local totals = { run = 0, passed = 0, failed = 0 }
	local started = os.clock()
	for _, module in ipairs(ServerStorage.UnitTest.Cases:GetDescendants()) do
		if not module:IsA("ModuleScript") or (filter and not string.find(module.Name, filter, 1, true)) then
			continue
		end
		local required, caseFunction = pcall(require, module)
		if not required or type(caseFunction) ~= "function" then
			totals.run += 1
			totals.failed += 1
			warn(`[FAIL] {module.Name} | case did not return a function: {caseFunction}`)
			continue
		end
		local context = { expect = expect }
		function context.test(name, callback)
			totals.run += 1
			local status, elapsed, message = runOne(callback, timeout)
			if status == "pass" then
				totals.passed += 1
				print(`[PASS] {module.Name} > {name} ({string.format("%.3f", elapsed)}s)`)
			else
				totals.failed += 1
				warn(`[{string.upper(status)}] {module.Name} > {name} | {message}`)
			end
		end
		local built, buildError = pcall(caseFunction, context)
		if not built then
			totals.run += 1
			totals.failed += 1
			warn(`[FAIL] {module.Name} | error while building cases: {buildError}`)
		end
	end
	print(
		`[SUMMARY] {totals.run} run, {totals.passed} passed, {totals.failed} failed, {string.format(
			"%.3f",
			os.clock() - started
		)}s`
	)
	return totals
end
