--!strict
-- @author Velumix
-- @version 0.0.1
-- Shared, asset-driven weapon conventions. A Tool only needs the Weapon tag;
-- optional attributes and attachments specialize its behavior.
local WeaponDefinitions = {}

WeaponDefinitions.Tag = "Weapon"
WeaponDefinitions.OffHandGripName = "OffHandGrip"
WeaponDefinitions.Types = table.freeze({
	Melee = "Melee",
	Firearm = "Firearm",
})
WeaponDefinitions.Actions = table.freeze({
	BlockStart = "BlockStart",
	BlockEnd = "BlockEnd",
})

function WeaponDefinitions.IsFirearm(tool: Tool): boolean
	return tool:GetAttribute("WeaponType") == WeaponDefinitions.Types.Firearm
end

function WeaponDefinitions.FindOffHandGrip(tool: Tool): Attachment?
	local found = tool:FindFirstChild(WeaponDefinitions.OffHandGripName, true)
	return if found and found:IsA("Attachment") then found else nil
end

function WeaponDefinitions.GetOffHandGripCFrame(tool: Tool, handle: BasePart): CFrame
	local position = tool:GetAttribute("OffHandGripPosition")
	local orientation = tool:GetAttribute("OffHandGripOrientation")
	local localPosition = if typeof(position) == "Vector3"
		then position
		else Vector3.new(-math.min(handle.Size.X * 0.22, 0.38), 0, 0)
	local rotation = if typeof(orientation) == "Vector3"
		then CFrame.fromOrientation(math.rad(orientation.X), math.rad(orientation.Y), math.rad(orientation.Z))
		else tool.Grip.Rotation
	return CFrame.new(localPosition) * rotation
end

return table.freeze(WeaponDefinitions)
