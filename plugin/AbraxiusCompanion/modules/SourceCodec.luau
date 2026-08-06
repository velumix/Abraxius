--!strict
local SourceCodec = {}

function SourceCodec.create(resolvePath: (string) -> Instance?): any
	local function encode(value: any): any
		local kind = typeof(value)
		if kind == "Vector3" then return { ["$type"] = "Vector3", x = value.X, y = value.Y, z = value.Z }
		elseif kind == "Vector2" then return { ["$type"] = "Vector2", x = value.X, y = value.Y }
		elseif kind == "CFrame" then return { ["$type"] = "CFrame", components = { value:GetComponents() } }
		elseif kind == "Color3" then return { ["$type"] = "Color3", r = value.R, g = value.G, b = value.B }
		elseif kind == "UDim" then return { ["$type"] = "UDim", scale = value.Scale, offset = value.Offset }
		elseif kind == "UDim2" then return { ["$type"] = "UDim2", x = { scale = value.X.Scale, offset = value.X.Offset }, y = { scale = value.Y.Scale, offset = value.Y.Offset } }
		elseif kind == "BrickColor" then return { ["$type"] = "BrickColor", number = value.Number, name = value.Name }
		elseif kind == "EnumItem" then return { ["$type"] = "EnumItem", enum = tostring(value.EnumType), name = value.Name }
		elseif kind == "NumberRange" then return { ["$type"] = "NumberRange", min = value.Min, max = value.Max }
		elseif kind == "Rect" then return { ["$type"] = "Rect", min = encode(value.Min), max = encode(value.Max) }
		elseif kind == "Instance" then return { ["$type"] = "Instance", path = string.gsub(value:GetFullName(), "^game%.", "") }
		elseif kind == "table" then local out = {}; for key, child in pairs(value) do out[key] = encode(child) end; return out
		elseif kind == "nil" or kind == "boolean" or kind == "number" or kind == "string" then return value end
		return { ["$type"] = kind, value = tostring(value), unsupported = true }
	end

	local function decode(value: any): any
		if typeof(value) ~= "table" or value["$type"] == nil then return value end
		local kind = value["$type"]
		if kind == "Vector3" then return Vector3.new(value.x, value.y, value.z)
		elseif kind == "Vector2" then return Vector2.new(value.x, value.y)
		elseif kind == "CFrame" then return CFrame.new(table.unpack(value.components))
		elseif kind == "Color3" then return Color3.new(value.r, value.g, value.b)
		elseif kind == "Color3uint8" then return Color3.fromRGB(value.r, value.g, value.b)
		elseif kind == "UDim" then return UDim.new(value.scale, value.offset)
		elseif kind == "UDim2" then return UDim2.new(value.x.scale, value.x.offset, value.y.scale, value.y.offset)
		elseif kind == "BrickColor" then return BrickColor.new(value.number or value.name)
		elseif kind == "EnumItem" then local enumName = string.gsub(tostring(value.enum), "^Enum%.", ""); local enumType = (Enum :: any)[enumName]; return if enumType then enumType[value.name] else nil
		elseif kind == "NumberRange" then return NumberRange.new(value.min, value.max)
		elseif kind == "Rect" then return Rect.new(decode(value.min), decode(value.max))
		elseif kind == "Instance" then return resolvePath(value.path) end
		error("Unsupported encoded value type: " .. tostring(kind))
	end

	return { encode = encode, decode = decode }
end

function SourceCodec.diff(before: string, after: string): any
	local beforeLines, afterLines = string.split(before, "\n"), string.split(after, "\n")
	local prefix = 0
	while prefix < #beforeLines and prefix < #afterLines and beforeLines[prefix + 1] == afterLines[prefix + 1] do prefix += 1 end
	local suffix = 0
	while suffix < (#beforeLines - prefix) and suffix < (#afterLines - prefix) and beforeLines[#beforeLines - suffix] == afterLines[#afterLines - suffix] do suffix += 1 end
	local removed, added = {}, {}
	for i = prefix + 1, #beforeLines - suffix do table.insert(removed, beforeLines[i]) end
	for i = prefix + 1, #afterLines - suffix do table.insert(added, afterLines[i]) end
	return { startLine = prefix + 1, removed = removed, added = added }
end

function SourceCodec.hash(source: string): string
	local hash = 5381
	for i = 1, #source do hash = (hash * 33 + string.byte(source, i)) % 4294967296 end
	return string.format("%08x", hash)
end

return SourceCodec
