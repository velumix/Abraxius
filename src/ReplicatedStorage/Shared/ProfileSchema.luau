--!strict
-- @author Velumix
-- @version 0.0.1
-- Shared, pure helpers for safe profile snapshots and patch replication.
--[=[
	@class ProfileSchema
	@server
	@client
	Pure helpers for cloning profile data, validating paths, producing client-safe
	snapshots, and applying replication patches.
]=]
local ProfileSchema = {}

--[=[
	@interface ProfilePatch
	.Path string -- Dotted client-visible path.
	.Value any? -- Detached changed value.
	.Remove boolean -- Whether the selected key should be removed.
	@within ProfileSchema
]=]
export type ProfilePatch = {
	Path: string,
	Value: any?,
	Remove: boolean,
}

local CLIENT_VISIBLE_ROOTS: { [string]: boolean } = table.freeze({
	Points = true,
	Coins = true,
	Level = true,
	Experience = true,
	Inventory = true,
	Settings = true,
})

--[=[
	Deep-clones an acyclic DataStore-safe value.

	@param value any
	@return any
]=]
function ProfileSchema.Clone(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in pairs(value) do
		copy[ProfileSchema.Clone(key)] = ProfileSchema.Clone(child)
	end
	return copy
end

--[=[
	Normalizes a dotted path or existing path array.

	@param path string | {any}
	@return {any}
]=]
function ProfileSchema.PathToArray(path: string | { any }): { any }
	if type(path) == "table" then
		return path
	end
	return string.split(path, ".")
end

--[=[
	Converts a path into dotted text for replication and logging.

	@param path string | {any}
	@return string
]=]
function ProfileSchema.PathToString(path: string | { any }): string
	if type(path) == "string" then
		return path
	end
	local parts = {}
	for _, key in ipairs(path) do
		table.insert(parts, tostring(key))
	end
	return table.concat(parts, ".")
end

--[=[
	Checks that an untrusted remote path is short and consists only of valid
	identifier segments.

	@param path any
	@return boolean
]=]
function ProfileSchema.IsValidRemotePath(path: any): boolean
	if type(path) ~= "string" or #path == 0 or #path > 128 then
		return false
	end
	local parts = string.split(path, ".")
	if #parts == 0 then
		return false
	end
	for _, part in ipairs(parts) do
		if string.match(part, "^[%a_][%w_]*$") == nil then
			return false
		end
	end
	return true
end

--[=[
	Returns whether the root of a path is allow-listed for client replication.

	@param path string | {any}
	@return boolean
]=]
function ProfileSchema.IsClientVisible(path: string | { any }): boolean
	local parts = ProfileSchema.PathToArray(path)
	return #parts > 0 and CLIENT_VISIBLE_ROOTS[tostring(parts[1])] == true
end

--[=[
	Reads a nested value without modifying the source table.

	@param data {[any]: any}
	@param path string | {any}
	@return any
]=]
function ProfileSchema.Read(data: { [any]: any }, path: string | { any }): any
	local current: any = data
	for _, key in ipairs(ProfileSchema.PathToArray(path)) do
		if type(current) ~= "table" then
			return nil
		end
		current = current[key]
	end
	return current
end

--[=[
	Writes a nested value, creating intermediate tables when necessary.

	@param data {[any]: any}
	@param path string | {any}
	@param value any
]=]
function ProfileSchema.Write(data: { [any]: any }, path: string | { any }, value: any)
	local parts = ProfileSchema.PathToArray(path)
	assert(#parts > 0, "path must not be empty")
	local current = data
	for index = 1, #parts - 1 do
		local key = parts[index]
		if type(current[key]) ~= "table" then
			current[key] = {}
		end
		current = current[key]
	end
	current[parts[#parts]] = value
end

--[=[
	Creates a detached snapshot containing only client-visible profile roots.

	@param data {[any]: any} -- Complete server profile data.
	@return {[any]: any} -- Safe client snapshot.
]=]
function ProfileSchema.ClientSnapshot(data: { [any]: any }): { [any]: any }
	local snapshot = {}
	for root in pairs(CLIENT_VISIBLE_ROOTS) do
		if data[root] ~= nil then
			snapshot[root] = ProfileSchema.Clone(data[root])
		end
	end
	return snapshot
end

--[=[
	Creates a serializable changed-value or removal patch.

	@param path string | {any}
	@param value any -- `nil` creates a removal patch.
	@return ProfilePatch
]=]
function ProfileSchema.MakePatch(path: string | { any }, value: any): ProfilePatch
	return {
		Path = ProfileSchema.PathToString(path),
		Value = ProfileSchema.Clone(value),
		Remove = value == nil,
	}
end

--[=[
	Applies a replication patch to a client cache.

	@param data {[any]: any}
	@param patch ProfilePatch
]=]
function ProfileSchema.ApplyPatch(data: { [any]: any }, patch: ProfilePatch)
	assert(type(patch.Path) == "string", "patch.Path must be a string")
	ProfileSchema.Write(data, patch.Path, if patch.Remove then nil else ProfileSchema.Clone(patch.Value))
end

return table.freeze(ProfileSchema)
