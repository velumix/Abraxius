--!strict
-- Abraxius Companion Logger
-- Plain Studio output for Abraxius events.

local Logger = {}

local LEVELS = {
	info = { icon = "🔷", label = "INFO" },
	ok = { icon = "🟢", label = "OK" },
	warn = { icon = "🟡", label = "WARN" },
	error = { icon = "🔴", label = "ERROR" },
	http = { icon = "🌐", label = "HTTP" },
	cli = { icon = "⌨️", label = "CLI" },
	studio = { icon = "🎮", label = "STUDIO" },
	plugin = { icon = "🔌", label = "PLUGIN" },
	connect = { icon = "✅", label = "CONNECT" },
	disconnect = { icon = "❌", label = "DISCONNECT" },
}

function Logger.log(level: string, message: string)
	local cfg = LEVELS[level] or LEVELS.info
	print(string.format("%s %s │ %s", cfg.icon, cfg.label, message))
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