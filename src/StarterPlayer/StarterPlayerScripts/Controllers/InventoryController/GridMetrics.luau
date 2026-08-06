local GridMetrics = {}
GridMetrics.__index = GridMetrics

local COLUMNS = 5
local COLUMN_GAP = 16
local ROW_GAP = 10
local CELL_ASPECT = 1.12

local function resolvedPadding(udim, axisSize)
	return math.floor((udim.Scale * axisSize) + udim.Offset + 0.5)
end

function GridMetrics.new(grid, layout, padding)
	return setmetatable({
		grid = grid,
		layout = layout,
		padding = padding,
		applying = false,
	}, GridMetrics)
end

function GridMetrics:Apply()
	if self.applying then
		return
	end

	local gridWidth = self.grid.AbsoluteSize.X
	if gridWidth <= 0 then
		return
	end

	self.applying = true
	local left, right = 0, 0
	if self.padding then
		left = resolvedPadding(self.padding.PaddingLeft, gridWidth)
		right = resolvedPadding(self.padding.PaddingRight, gridWidth)
	end
	local gaps = COLUMN_GAP * (COLUMNS - 1)
	local availableWidth = math.max(0, gridWidth - left - right - gaps)
	local cellWidth = math.max(24, math.floor(availableWidth / COLUMNS))
	local cellHeight = math.max(24, math.floor(cellWidth / CELL_ASPECT))
	self.layout.CellPadding = UDim2.fromOffset(COLUMN_GAP, ROW_GAP)
	self.layout.CellSize = UDim2.fromOffset(cellWidth, cellHeight)
	self.applying = false
end

function GridMetrics:SyncCanvas()
	self:Apply()
	local paddingY = 0
	if self.padding then
		local height = self.grid.AbsoluteSize.Y
		paddingY = resolvedPadding(self.padding.PaddingTop, height)
			+ resolvedPadding(self.padding.PaddingBottom, height)
	end
	self.grid.CanvasSize = UDim2.fromOffset(0, math.ceil(self.layout.AbsoluteContentSize.Y + paddingY))
end

function GridMetrics:Start()
	self.layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		self:SyncCanvas()
	end)
	self.grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:SyncCanvas()
	end)
	self:Apply()
end

return GridMetrics
