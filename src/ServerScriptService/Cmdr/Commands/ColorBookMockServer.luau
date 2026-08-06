local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local MapManager = require(ServerScriptService:WaitForChild("MapManager"))
local ColoringBookConfig = require(ReplicatedStorage:WaitForChild("ColoringBookConfig"))

return function(_context, pages, partsPerPage)
	local map = MapManager.getActiveMap and MapManager.getActiveMap()
	if not map then return "No active map loaded to add a ColoringBook to." end
	if pages <= 0 or partsPerPage <= 0 then return "Pages and PartsPerPage must both be positive." end

	local folderName = ColoringBookConfig.FOLDER_NAME
	local existing = map:FindFirstChild(folderName)
	if existing then existing:Destroy() end

	local book = Instance.new("Folder")
	book.Name = folderName
	for p = 1, pages do
		local page = Instance.new("Folder")
		page.Name = "Page" .. p
		page.Parent = book
		for q = 1, partsPerPage do
			local part = Instance.new("Part")
			part.Name = "Part" .. q
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Transparency = 1
			part.Size = Vector3.new(1, 1, 1)
			part.Parent = page
		end
	end
	book.Parent = map

	local name = (MapManager.getActiveMapName and MapManager.getActiveMapName()) or map.Name
	return ("Authored mock ColoringBook on '%s': %d pages x %d parts (runtime only, not saved)."):format(
		name, pages, partsPerPage
	)
end
