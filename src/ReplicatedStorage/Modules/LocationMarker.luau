local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local LocationMarker = {}
LocationMarker.__index = LocationMarker

local DEFAULT_ICON = "rbxassetid://8239527343"
local DEFAULT_RANGE = 250
local DEFAULT_OFFSET = Vector3.new(0, 4, 0)

local function resolveBasePart(target)
	if not target then
		return nil
	end
	if target:IsA("BasePart") then
		return target
	end
	if target:IsA("Model") then
		return target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart", true)
	end
	if target:IsA("Attachment") then
		return target.Parent and target.Parent:IsA("BasePart") and target.Parent or nil
	end
	return nil
end

local function resolveIcon(icon)
	if type(icon) == "string" and (icon:find("rbxassetid://") or icon:find("http")) then
		return icon
	end
	return DEFAULT_ICON
end

function LocationMarker.new(config)
	if not config or not config.Target then
		return nil
	end

	local basePart = resolveBasePart(config.Target)
	if not basePart then
		return nil
	end

	local offset = config.Offset or DEFAULT_OFFSET
	local attachment = Instance.new("Attachment")
	attachment.Name = "TutorialMarker"
	attachment.Position = offset
	attachment.Parent = basePart

	attachment:SetAttribute("Image", resolveIcon(config.Icon))
	attachment:SetAttribute("Color", config.Color or Color3.fromRGB(255, 200, 0))
	attachment:SetAttribute("Enabled", config.Enabled ~= false)
	attachment:SetAttribute("Range", config.Range or DEFAULT_RANGE)
	attachment:SetAttribute("TutorialId", config.TutorialId)

	CollectionService:AddTag(attachment, "Marker")

	local self = setmetatable({}, LocationMarker)
	self._attachment = attachment
	return self
end

function LocationMarker:Destroy()
	if self._attachment then
		CollectionService:RemoveTag(self._attachment, "Marker")
		self._attachment:Destroy()
		self._attachment = nil
	end
end

function LocationMarker:SetTarget(target)
	if not self._attachment then
		return
	end
	local basePart = resolveBasePart(target)
	if basePart then
		self._attachment.Parent = basePart
	end
end

function LocationMarker:SetIcon(icon)
	if self._attachment then
		self._attachment:SetAttribute("Image", resolveIcon(icon))
	end
end

function LocationMarker:SetColor(color)
	if self._attachment then
		self._attachment:SetAttribute("Color", color)
	end
end

return LocationMarker
