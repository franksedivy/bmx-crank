local gfx <const> = playdate.graphics

local Pool = {}
Pool.__index = Pool

function Pool.new()
	local pool = setmetatable({}, Pool)

	pool.leftX = 10
	pool.rightX = 390
	pool.centerX = 200
	pool.halfWidth = 190
	pool.lipY = 95
	pool.bottomY = 220
	pool.depth = pool.bottomY - pool.lipY
	pool.shapePower = 4

	return pool
end

-- Returns the pool surface height at a horizontal position.
-- Screen coordinates increase downwards, so the bottom has the largest Y.
function Pool:getY(x)
	local normalizedX = (x - self.centerX) / self.halfWidth
	local distanceFromCenter = math.abs(normalizedX)

	return self.bottomY
		- self.depth * distanceFromCenter ^ self.shapePower
end

-- Returns the direction and steepness of the pool at a position.
-- Positive slopes descend to the right; negative slopes descend to the left.
function Pool:getSlope(x)
	local normalizedX = (x - self.centerX) / self.halfWidth

	if normalizedX == 0 then
		return 0
	end

	local slopeDirection = normalizedX > 0 and 1 or -1

	return -self.depth
		* self.shapePower
		* math.abs(normalizedX) ^ (self.shapePower - 1)
		* slopeDirection
		/ self.halfWidth
end

function Pool:draw()
	local previousX = self.leftX
	local previousY = self:getY(previousX)

	-- Draw the curve as a series of short connected lines.
	for x = self.leftX + 2, self.rightX do
		local y = self:getY(x)
		gfx.drawLine(previousX, previousY, x, y)

		previousX = x
		previousY = y
	end
	
	-- Draw the flat decks extending outward from both pool lips.
	gfx.drawLine(
		0,
		self.lipY,
		self.leftX,
		self.lipY
	)
	
	gfx.drawLine(
		self.rightX,
		self.lipY,
		400,
		self.lipY
	)
end

return Pool
