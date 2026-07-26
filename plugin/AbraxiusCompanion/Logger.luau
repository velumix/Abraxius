--!strict
-- Abraxius Companion Logger
-- Emoji-forward output generated from code points to avoid source encoding damage.

local Logger = {}

local function emoji(...: number): string
	return utf8.char(...)
end

local LEVELS = {
	info = { icon = emoji(0x2139, 0xFE0F), warning = false },
	ok = { icon = emoji(0x2728), warning = false },
	warn = { icon = emoji(0x26A0, 0xFE0F), warning = true },
	error = { icon = emoji(0x274C), warning = true },
	http = { icon = emoji(0x1F310), warning = false },
	cli = { icon = emoji(0x25B6, 0xFE0F), warning = false },
	studio = { icon = emoji(0x1F3AE), warning = false },
	plugin = { icon = emoji(0x1F50C), warning = false },
	connect = { icon = emoji(0x2705), warning = false },
	disconnect = { icon = emoji(0x1F504), warning = true },
}

function Logger.log(level: string, message: string)
	local cfg = LEVELS[level] or LEVELS.info
	local clean = string.gsub(tostring(message), "[\r\n]+", " ")
	local output = cfg.icon .. " " .. clean
	if cfg.warning then
		warn(output)
	else
		print(output)
	end
end

function Logger.isOwnMessage(message: string): boolean
	for _, cfg in pairs(LEVELS) do
		if string.sub(message, 1, #cfg.icon) == cfg.icon then return true end
	end
	return false
end

function Logger.info(message: string)
	Logger.log("info", message)
end

function Logger.ok(message: string)
	Logger.log("ok", message)
end

function Logger.warn(message: string)
	Logger.log("warn", message)
end

function Logger.error(message: string)
	Logger.log("error", message)
end

function Logger.http(message: string)
	Logger.log("http", message)
end

function Logger.cli(message: string)
	Logger.log("cli", message)
end

function Logger.studio(message: string)
	Logger.log("studio", message)
end

function Logger.plugin(message: string)
	Logger.log("plugin", message)
end

function Logger.connect(message: string)
	Logger.log("connect", message)
end

function Logger.disconnect(message: string)
	Logger.log("disconnect", message)
end

return Logger
