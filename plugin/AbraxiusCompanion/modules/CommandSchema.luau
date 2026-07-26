--!strict
local Schema = {}
Schema.capabilities = {
	"inspect", "selection", "source.read", "source.write", "source.create", "source.export", "luau.execute",
	"properties.read", "properties.write", "instance.create", "instance.clone", "instance.rename", "instance.reparent",
	"instance.delete", "instance.transform", "assistant.context", "transaction.batch", "model.import",
	"axl.core",
}
local commands: { [string]: any } = {}
local function schema(properties: any?, required: any?): any return { type = "object", properties = properties or {}, required = required or {}, additionalProperties = true } end
local stringArg, booleanArg, objectArg, arrayArg = { type = "string" }, { type = "boolean" }, { type = "object" }, { type = "array" }
commands.read_source = schema({ path = stringArg }, { "path" })
commands.write_source = schema({ path = stringArg, source = stringArg, expectedHash = stringArg, dryRun = booleanArg }, { "path", "source" })
commands.create_script = schema({ path = stringArg, parent = stringArg, name = stringArg, className = { type = "string", enum = { "Script", "LocalScript", "ModuleScript" } }, source = stringArg, properties = objectArg })
commands.create_script.anyOf = { { required = { "path" } }, { required = { "parent", "name" } } }
commands.execute_luau = schema({ code = stringArg, confirm = booleanArg }, { "code", "confirm" })
commands.get_selection = schema(); commands.get_children = schema({ path = stringArg }, { "path" }); commands.set_selection = schema({ paths = arrayArg }, { "paths" })
commands.open_script = schema({ path = stringArg, line = { type = "number" } }, { "path" }); commands.export_scripts = schema({ services = arrayArg })
commands.get_state = schema(); commands.get_context_snapshot = schema(); commands.resolve_path = schema({ path = stringArg }, { "path" })
commands.subscribe = schema({ events = arrayArg }, { "events" }); commands.ping = schema(); commands.get_capabilities = schema(); commands.get_play_data_settings = schema()
commands.set_play_data_enabled = schema({ enabled = booleanArg }, { "enabled" }); commands.get_assistant_context = schema(); commands.get_watched_sources = schema()
commands.axl = schema({ source = stringArg }, { "source" })
commands.set_properties = schema({ path = stringArg, properties = objectArg }, { "path", "properties" }); commands.get_properties = schema({ path = stringArg, properties = arrayArg }, { "path", "properties" })
commands.create_instance = schema({ parent = stringArg, className = stringArg, name = stringArg, properties = objectArg }, { "className" })
commands.import_model = schema({ parent = stringArg, name = stringArg, format = { type = "string", enum = { "rbxm", "rbxmx" } }, contentBase64 = stringArg, replace = booleanArg, confirm = booleanArg }, { "parent", "name", "format", "contentBase64", "confirm" })
commands.clone_instance = schema({ path = stringArg, parent = stringArg, name = stringArg }, { "path" }); commands.rename_instance = schema({ path = stringArg, name = stringArg }, { "path", "name" })
commands.reparent_instance = schema({ path = stringArg, parent = stringArg }, { "path", "parent" }); commands.transform_instance = schema({ path = stringArg, cframe = objectArg, position = objectArg }, { "path" })
commands.delete_instance = schema({ path = stringArg, confirm = booleanArg }, { "path", "confirm" }); commands.batch = schema({ operations = arrayArg, name = stringArg }, { "operations" })
Schema.commands = commands
return Schema
