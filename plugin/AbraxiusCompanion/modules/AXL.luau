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
	return math.ceil(#text / 4)
end

local function packRecords(records: { string }, budget: number): any
	local maximum = math.max(0, budget) * 4
	local output = {}
	local used = 0
	for _, record in ipairs(records) do
		local separator = if #output == 0 then 0 else 1
		local required = separator + #record
		if used + required <= maximum then
			table.insert(output, record)
			used += required
		else
			break
		end
	end
	local content = table.concat(output, "\n")
	return {
		content = content,
		shown = #output,
		total = #records,
		truncated = #output < #records,
		tokens = estimateTokens(content),
	}
end

local STOP_WORDS: { [string]: boolean } = {
	about = true, after = true, again = true, also = true, ["and"] = true,
	are = true, can = true, code = true, could = true, from = true,
	have = true, into = true, just = true, need = true, roblox = true,
	script = true, should = true, studio = true, that = true, the = true,
	their = true, ["then"] = true, this = true, want = true, what = true,
	when = true, where = true, with = true, would = true,
}

local function normalizeTerm(raw: string): string
	if #raw > 4 and string.sub(raw, -1) == "s" and string.sub(raw, -2) ~= "ss" then
		return string.sub(raw, 1, -2)
	end
	return raw
end

local function taskTerms(taskText: string): { string }
	local terms = {}
	local seen: { [string]: boolean } = {}
	for raw in string.gmatch(string.lower(taskText), "[%w_]+") do
		local term = normalizeTerm(raw)
		if #term >= 3 and not STOP_WORDS[raw] and not seen[term] then
			seen[term] = true
			table.insert(terms, term)
			if #terms >= 12 then break end
		end
	end
	return terms
end

local function termCounts(text: string, wanted: { [string]: boolean }): { [string]: number }
	local counts: { [string]: number } = {}
	local separated = string.gsub(text, "(%l)(%u)", "%1 %2")
	separated = string.gsub(separated, "_", " ")
	for raw in string.gmatch(string.lower(separated), "[%w]+") do
		local term = normalizeTerm(raw)
		if wanted[term] and (counts[term] or 0) < 4 then
			counts[term] = (counts[term] or 0) + 1
		end
	end
	return counts
end

local function isVendoredPath(lowerPath: string): boolean
	return string.find(lowerPath, ".dependencies.", 1, true) ~= nil
		or string.find(lowerPath, ".packages.", 1, true) ~= nil
		or string.find(lowerPath, "._index.", 1, true) ~= nil
		or string.find(lowerPath, "._reactpackages.", 1, true) ~= nil
		or string.find(lowerPath, ".node_modules.", 1, true) ~= nil
end

local function relevantScripts(taskText: string, budget: number): any
	local terms = taskTerms(taskText)
	if #terms == 0 then
		local message = "No distinctive task terms were available."
		return {
			content = message,
			shown = 0,
			total = 0,
			truncated = false,
			tokens = estimateTokens(message),
		}
	end
	local wanted: { [string]: boolean } = {}
	for _, term in ipairs(terms) do wanted[term] = true end
	local minimumScore = if #terms >= 3 then 20 else 1

	local ranked = {}
	for _, descendant in ipairs(game:GetDescendants()) do
		if descendant:IsA("LuaSourceContainer") then
			local path = string.gsub(descendant:GetFullName(), "^game%.", "")
			local lowerPath = string.lower(path)
			local source = descendant.Source
			local pathCounts = termCounts(path, wanted)
			local sourceCounts = termCounts(source, wanted)
			local score = 0
			local matchedTerms = {}
			local pathCoverage = 0
			for _, term in ipairs(terms) do
				local matched = false
				if pathCounts[term] then
					score += 18
					pathCoverage += 1
					matched = true
				end
				if sourceCounts[term] then
					score += sourceCounts[term]
					matched = true
				end
				if matched then table.insert(matchedTerms, term) end
			end
			local coverage = #matchedTerms
			if coverage > 0 then
				score += coverage * 20
				if coverage == 1 and #terms >= 3 then score -= 10 end
				if isVendoredPath(lowerPath) then
					if pathCoverage == 0 then score = -1 else score -= 60 end
				end
				if #source > 100000 then score -= 5 end
			end
			if score >= minimumScore then
				table.insert(ranked, {
					path = path,
					source = source,
					score = score,
					coverage = coverage,
					matchedTerms = matchedTerms,
				})
			end
		end
	end

	table.sort(ranked, function(left, right)
		if left.score == right.score then return left.path < right.path end
		return left.score > right.score
	end)

	local records = {}
	for _, item in ipairs(ranked) do
		if #records >= 12 then break end
		local record = { "SCRIPT " .. item.path
			.. " score=" .. tostring(item.score)
			.. " matched=" .. table.concat(item.matchedTerms, ",") }
		local snippets = 0
		for lineNumber, line in ipairs(string.split(item.source, "\n")) do
			local matched = false
			local lineCounts = termCounts(line, wanted)
			for term in pairs(lineCounts) do
				if wanted[term] then
					matched = true
					break
				end
			end
			if matched then
				local compact = trim(string.gsub(line, "%s+", " "))
				if #compact > 220 then compact = string.sub(compact, 1, 217) .. "..." end
				table.insert(record, tostring(lineNumber) .. ": " .. compact)
				snippets += 1
				if snippets >= 3 then break end
			end
		end
		table.insert(records, table.concat(record, "\n"))
	end
	if #records == 0 then
		local message = "No live scripts matched: " .. table.concat(terms, ", ")
		return {
			content = message,
			shown = 0,
			total = 0,
			truncated = false,
			tokens = estimateTokens(message),
		}
	end
	local packed = packRecords(records, budget)
	packed.total = #ranked
	packed.truncated = packed.shown < packed.total
	return packed
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
			local requested = VERSION
			local sawVersion = false
			local sawProject = false
			for _, token in ipairs(tokens) do
				if string.match(token, "^axl/%d+$") and not sawVersion then
					requested = token
					sawVersion = true
				elseif string.match(token, "^project=.+$") then
					if sawProject then error("Duplicate option: project") end
					sawProject = true
					-- Project identity is a host hint in AXL/1; Studio does not resolve it yet.
				else
					error("Unknown hello argument: " .. token)
				end
			end
			if requested ~= VERSION then return "ERR VERSION expected=" .. VERSION end
			return "READY " .. VERSION .. " ns=0 tools=core,studio"
		elseif command == "context" then
			if #tokens < 1 then error('Usage: context "task" budget=N') end
			local taskText = tokens[1]
			local budget = parseBudget(tokens, 2, 800)
			local snapshot = dependencies.contextSnapshot()
			local headings = "RELEVANT LIVE SCRIPTS\n\nSTUDIO STATE\n"
			local available = math.max(0, budget - estimateTokens(headings))
			local stateJson = dependencies.jsonEncode(snapshot)
			local reservedState = math.min(estimateTokens(stateJson), math.floor(available * 0.3))
			local retrieval = relevantScripts(taskText, available - reservedState)
			local stateBudget = math.max(0, available - retrieval.tokens)
			local state = packRecords({ stateJson }, stateBudget)
			if state.shown == 0 then
				state = packRecords({
					dependencies.jsonEncode({ truncated = true, bytes = #stateJson }),
				}, stateBudget)
				state.truncated = true
			end
			local content = "RELEVANT LIVE SCRIPTS\n"
				.. retrieval.content
				.. "\n\nSTUDIO STATE\n"
				.. state.content
			return "CTX $0 t=" .. tostring(estimateTokens(content))
				.. " scripts=" .. tostring(retrieval.shown) .. "/" .. tostring(retrieval.total)
				.. " truncated=" .. (if retrieval.truncated or state.truncated then "1" else "0")
				.. " stateTokens=" .. tostring(state.tokens)
				.. "\n" .. content
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
			local packed = packRecords(matches, budget)
			return "OK FIND n=" .. tostring(#matches)
				.. " shown=" .. tostring(packed.shown)
				.. " truncated=" .. (if packed.truncated then "1" else "0")
				.. " capped=" .. (if #matches >= 100 then "1" else "0")
				.. " t=" .. tostring(packed.tokens)
				.. "\n" .. packed.content
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
				.. " removedBytes=" .. tostring(#oldText)
				.. " addedBytes=" .. tostring(#newText)
				.. " removedLines=" .. tostring(#string.split(oldText, "\n"))
				.. " addedLines=" .. tostring(#string.split(newText, "\n"))
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
