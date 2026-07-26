--!strict
local AXL = {}

local VERSION = "axl/1"
local MAX_SOURCE = 262144
local MAX_BUDGET = 32000

local function trim(value: string): string
	return (string.gsub(value, "^%s*(.-)%s*$", "%1"))
end

local function tokenize(line: string): { string }
	local tokens = {}
	local current = ""
	local quote: string? = nil
	local active = false
	local index = 1
	while index <= #line do
		local character = string.sub(line, index, index)
		if quote then
			if character == "\\" then
				index += 1
				if index > #line then error("Trailing escape in quoted text") end
				local escaped = string.sub(line, index, index)
				if escaped == "n" then current ..= "\n"
				elseif escaped == "r" then current ..= "\r"
				elseif escaped == "t" then current ..= "\t"
				else current ..= escaped end
			elseif character == quote then
				quote = nil
			else
				current ..= character
			end
			active = true
		elseif character == '"' or character == "'" then
			quote = character
			active = true
		elseif string.match(character, "%s") then
			if active then
				table.insert(tokens, current)
				current = ""
				active = false
			end
		else
			current ..= character
			active = true
		end
		index += 1
	end
	if quote then error("Unterminated quoted text") end
	if active then table.insert(tokens, current) end
	return tokens
end

local function estimateTokens(text: string): number
	return math.max(1, math.ceil(#text / 4))
end

local function bounded(text: string, budget: number): string
	local maximum = budget * 4
	if #text <= maximum then return text end
	return string.sub(text, 1, math.max(0, maximum - 16)) .. "\n...TRUNCATED"
end

local function revision(hashSource: (string) -> string, source: string): number
	return tonumber(hashSource(source), 16) or 0
end

local function parseBudget(tokens: { string }, startIndex: number, defaultValue: number): number
	local budget = defaultValue
	for index = startIndex, #tokens do
		local token = tokens[index]
		local value = string.match(token, "^budget=(%d+)$")
		if value then
			budget = tonumber(value) or defaultValue
		else
			error("Unknown option: " .. token)
		end
	end
	if budget < 64 or budget > MAX_BUDGET then error("budget must be between 64 and 32000") end
	return budget
end

local function rejectIdentifier(target: string)
	if string.match(target, "^[@#$%%]") then
		error("NONAMESPACE No namespace entry for " .. target)
	end
end

local function readBlock(lines: { string }, startIndex: number, name: string): (string, number)
	local tag = string.match(trim(lines[startIndex] or ""), "^" .. name .. "%s+<<([%a][%w_-]*)$")
	if not tag then error("Expected " .. name .. " <<TAG") end
	local body = {}
	local index = startIndex + 1
	while index <= #lines and lines[index] ~= tag do
		table.insert(body, lines[index])
		index += 1
	end
	if index > #lines then error("Missing closing " .. tag) end
	return table.concat(body, "\n"), index + 1
end

local function listSymbols(source: string): { any }
	local symbols = {}
	for lineNumber, line in ipairs(string.split(source, "\n")) do
		local clean = trim(line)
		local name = string.match(clean, "^local%s+function%s+([%w_%.:]+)%s*%(")
			or string.match(clean, "^function%s+([%w_%.:]+)%s*%(")
			or string.match(clean, "^local%s+([%w_]+)%s*=%s*function%s*%(")
		if name then table.insert(symbols, { name = name, line = lineNumber }) end
	end
	return symbols
end

function AXL.create(dependencies: any): any
	local nextOperation = 1

	local function operationId(): number
		local id = nextOperation
		nextOperation += 1
		return id
	end

	local function execute(sourceText: string): string
		if typeof(sourceText) ~= "string" or sourceText == "" then return "ERR EMPTY AXL command is empty" end
		if #sourceText > MAX_SOURCE then return "ERR LIMIT AXL command exceeds 256 KiB" end
		local normalized = string.gsub(string.gsub(sourceText, "\r\n", "\n"), "\r", "\n")
		local lines = string.split(normalized, "\n")
		local tokens = tokenize(trim(lines[1] or ""))
		local command = string.lower(table.remove(tokens, 1) or "")

		if command == "hello" then
			local requested = tokens[1] or VERSION
			if requested ~= VERSION then return "ERR VERSION expected=" .. VERSION end
			return "READY " .. VERSION .. " ns=0 tools=core,studio"
		elseif command == "context" then
			if #tokens < 1 then error('Usage: context "task" budget=N') end
			local taskText = tokens[1]
			local budget = parseBudget(tokens, 2, 800)
			local snapshot = dependencies.contextSnapshot()
			local content = bounded(dependencies.jsonEncode(snapshot), budget)
			return "CTX $0 t=" .. tostring(estimateTokens(content)) .. "\nTASK " .. taskText .. "\n" .. content
		elseif command == "find" then
			if #tokens < 1 then error('Usage: find "query" budget=N') end
			local query = string.lower(tokens[1])
			if query == "" then error("Query cannot be empty") end
			local budget = parseBudget(tokens, 2, 800)
			local matches = {}
			for _, descendant in ipairs(game:GetDescendants()) do
				if descendant:IsA("LuaSourceContainer") then
					local source = descendant.Source
					local lower = string.lower(source)
					local cursor = 1
					while #matches < 100 do
						local startAt = string.find(lower, query, cursor, true)
						if not startAt then break end
						local before = string.sub(source, 1, startAt - 1)
						local line = 1 + select(2, string.gsub(before, "\n", "\n"))
						table.insert(matches, string.gsub(descendant:GetFullName(), "^game%.", "") .. ":" .. tostring(line))
						cursor = startAt + math.max(1, #query)
					end
				end
				if #matches >= 100 then break end
			end
			local content = bounded(table.concat(matches, "\n"), budget)
			return "OK FIND n=" .. tostring(#matches) .. " t=" .. tostring(estimateTokens(content)) .. "\n" .. content
		elseif command == "read" then
			local target = table.remove(tokens, 1)
			if not target then error("Usage: read target [summary|symbols|source|full|lines A..B]") end
			rejectIdentifier(target)
			if string.match(tokens[1] or "", "^%^%d+$") then table.remove(tokens, 1) end
			local detail = string.lower(table.remove(tokens, 1) or "source")
			local instance = dependencies.resolvePath(target)
			if not instance or not instance:IsA("LuaSourceContainer") then error("NOTFOUND Script not found: " .. target) end
			local scriptInstance = instance :: LuaSourceContainer
			local source = scriptInstance.Source
			local currentRevision = revision(dependencies.hashSource, source)
			if detail == "summary" then
				return "SUM " .. target .. "@" .. tostring(currentRevision)
					.. " lines=" .. tostring(#string.split(source, "\n"))
					.. " bytes=" .. tostring(#source)
					.. " symbols=" .. tostring(#listSymbols(source))
			elseif detail == "symbols" then
				local symbols = listSymbols(source)
				local output = { "SYM " .. target .. "@" .. tostring(currentRevision) .. " n=" .. tostring(#symbols) }
				for _, symbol in ipairs(symbols) do table.insert(output, tostring(symbol.line) .. " " .. symbol.name) end
				return table.concat(output, "\n")
			elseif detail == "lines" then
				local range = table.remove(tokens, 1)
				local firstText, lastText = string.match(range or "", "^(%d+)%.%.(%d+)$")
				if not firstText then error("RANGE Line range must use start..end") end
				local first, last = tonumber(firstText) :: number, tonumber(lastText) :: number
				local sourceLines = string.split(source, "\n")
				if first < 1 or last < first or first > #sourceLines then error("RANGE Invalid line range") end
				local selected = {}
				for index = first, math.min(last, #sourceLines) do table.insert(selected, sourceLines[index]) end
				local content = table.concat(selected, "\n")
				return "SRC " .. target .. "@" .. tostring(currentRevision) .. " "
					.. tostring(first) .. ".." .. tostring(math.min(last, #sourceLines))
					.. " t=" .. tostring(estimateTokens(content)) .. "\n" .. content
			elseif detail == "source" or detail == "full" then
				if #tokens > 0 then error("Unexpected tokens after read command") end
				return "SRC " .. target .. "@" .. tostring(currentRevision) .. " 1.."
					.. tostring(#string.split(source, "\n")) .. " t=" .. tostring(estimateTokens(source)) .. "\n" .. source
			end
			error("Unknown read detail: " .. detail)
		elseif command == "patch" then
			if #tokens ~= 1 then error("Usage: patch target@revision") end
			local targetWithRevision = tokens[1]
			if not targetWithRevision then error("Usage: patch target@revision") end
			local target, expectedText = string.match(targetWithRevision, "^(.-)@(%d+)$")
			if not target then error("REVISION Patch requires target@revision") end
			rejectIdentifier(target)
			local oldText, nextLine = readBlock(lines, 2, "old")
			local newText, after = readBlock(lines, nextLine, "new")
			for index = after, #lines do
				if trim(lines[index]) ~= "" then error("Unexpected text after patch heredocs") end
			end
			if oldText == "" or oldText == newText then error("PATCH Old and new text must be non-empty and different") end
			local editable, editError = dependencies.requireEditMode()
			if not editable then error(editError or "Edit mode required") end
			local instance = dependencies.resolvePath(target)
			if not instance or not instance:IsA("LuaSourceContainer") then error("NOTFOUND Script not found: " .. target) end
			local scriptInstance = instance :: LuaSourceContainer
			local previous = scriptInstance.Source
			local currentRevision = revision(dependencies.hashSource, previous)
			local expected = tonumber(expectedText) :: number
			if currentRevision ~= expected then
				return "ERR STALE expected=" .. tostring(expected) .. " current=" .. tostring(currentRevision)
			end
			local first = string.find(previous, oldText, 1, true)
			if not first then return "ERR NOMATCH Patch old text does not match the current source" end
			if string.find(previous, oldText, first + #oldText, true) then
				return "ERR AMBIGUOUS Patch old text matches more than once"
			end
			local nextSource = string.sub(previous, 1, first - 1) .. newText .. string.sub(previous, first + #oldText)
			local recording = dependencies.beginRecording("AXL patch " .. target)
			local ok, updateError, pending = dependencies.updateSource(scriptInstance, nextSource)
			if not ok then
				dependencies.finishRecording(recording, false)
				error("WRITE " .. tostring(updateError))
			end
			dependencies.finishRecording(recording, true)
			local id = operationId()
			return "OK %" .. tostring(id) .. " " .. target .. "@"
				.. tostring(revision(dependencies.hashSource, nextSource))
				.. " changed=" .. tostring(math.abs(#newText - #oldText))
				.. (if pending then " pending=1" else " verified=1")
		elseif command == "execute" then
			local code = tokens[1]
			if not code then error('Usage: execute "code" or execute <<TAG') end
			local tag = string.match(code, "^<<([%a][%w_-]*)$")
			if tag then
				local body = {}
				local index = 2
				while index <= #lines and lines[index] ~= tag do
					table.insert(body, lines[index])
					index += 1
				end
				if index > #lines then error("Missing closing " .. tag) end
				for trailing = index + 1, #lines do
					if trim(lines[trailing]) ~= "" then error("Unexpected text after execute heredoc") end
				end
				code = table.concat(body, "\n")
			elseif #lines > 1 then
				for index = 2, #lines do
					if trim(lines[index]) ~= "" then error("Unexpected text after execute command") end
				end
			end
			if code == "" then error("Execute code cannot be empty") end
			local mode = "Edit"
			for index = 2, #tokens do
				local requested = string.match(tokens[index], "^mode=(%a+)$")
				if not requested then error("Unknown option: " .. tokens[index]) end
				mode = requested
			end
			if mode ~= "Edit" then error("UNSUPPORTED execute mode must be Edit") end
			local result = dependencies.executeLuau(code)
			if result.ok ~= true then error("EXEC " .. tostring(result.error)) end
			local content = dependencies.jsonEncode(result.result)
			return "OK EXEC t=" .. tostring(estimateTokens(content)) .. "\n" .. content
		elseif command == "state" then
			if #tokens > 1 then error("Usage: state [target]") end
			local target = tokens[1]
			if not target then return "OK STATE\n" .. dependencies.jsonEncode(dependencies.getState()) end
			rejectIdentifier(target)
			local instance = dependencies.resolvePath(target)
			if not instance then error("NOTFOUND Instance not found: " .. target) end
			return "OK STATE\n" .. dependencies.jsonEncode(dependencies.instanceInfo(instance))
		elseif command == "undo" then
			return "ERR UNSUPPORTED Operation-owned undo is not available in " .. VERSION
		end
		error("Unknown AXL command: " .. command)
	end

	return {
		execute = function(sourceText: string): string
			local ok, result = pcall(execute, sourceText)
			if ok then return result end
			local message = tostring(result)
			message = string.gsub(message, "^.-:%d+:%s*", "")
			if string.match(message, "^[A-Z]+ ") then return "ERR " .. message end
			return "ERR SYNTAX " .. message
		end,
	}
end

return AXL
