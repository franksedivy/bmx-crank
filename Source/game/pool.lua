local gfx <const> = playdate.graphics

local Pool = {}
Pool.__index = Pool

function Pool.new()
	local pool = setmetatable({}, Pool)

	-- Left curve endpoint and takeoff threshold, in pixels from screen left.
	-- Increasing this narrows the left side and makes it steeper.
	pool.leftX = 15

	-- Right curve endpoint and takeoff threshold, in pixels from screen left.
	-- Decreasing this narrows the right side and makes it steeper.
	pool.rightX = 345

	-- X position of the lowest point, where the left and right curves meet.
	-- Moving it changes each side's width while leaving the lips fixed.
	-- Keep between leftX and rightX.
	pool.centerX = 200

	-- Y position of the lowest riding surface; Y increases down the screen.
	-- 239 is the last visible row. Smaller values raise the bottom of the pool.
	pool.bottomY = 239

	-- Left lip/deck Y position. Smaller values raise it and deepen that side.
	-- Keep below bottomY numerically; the curve reaches this height at leftX.
	pool.leftLipY = 195

	-- Left curve strength: higher values flatten the bottom and steepen the edge.
	-- Keep greater than 1 for a smooth, flat join at the centre.
	pool.leftShapePower = 14

	-- Right lip/deck Y position. Smaller values raise it and deepen that side.
	-- Keep below bottomY numerically; the curve reaches this height at rightX.
	pool.rightLipY = 165

	-- Right curve strength: higher values flatten the bottom and steepen the edge.
	-- Keep greater than 1 for a smooth, flat join at the centre.
	pool.rightShapePower = 8

	assert(pool.leftX < pool.centerX and pool.centerX < pool.rightX,
		"Pool centerX must be between leftX and rightX")

	return pool
end

-- Returns the lip height for a negative (left) or positive (right) side.
function Pool:getLipY(side)
	return side > 0 and self.rightLipY or self.leftLipY
end

-- Uses the same side-specific curve strength for surface and slope calculations.
function Pool:getShapePower(side)
	return side > 0 and self.rightShapePower or self.leftShapePower
end

-- Derives each side's width from its real endpoints, keeping the lips aligned.
function Pool:getWidth(side)
	return side > 0
		and self.rightX - self.centerX
		or self.centerX - self.leftX
end

-- Returns the pool surface height at a horizontal position.
-- Screen coordinates increase downwards, so the bottom has the largest Y.
function Pool:getY(x)
	local offsetX = x - self.centerX
	local normalizedX = offsetX / self:getWidth(offsetX)
	local distanceFromCenter = math.abs(normalizedX)
	local depth = self.bottomY - self:getLipY(normalizedX)
	local shapePower = self:getShapePower(normalizedX)

	return self.bottomY
		- depth * distanceFromCenter ^ shapePower
end

-- Returns the direction and steepness of the pool at a position.
-- Positive slopes descend to the right; negative slopes descend to the left.
function Pool:getSlope(x)
	local offsetX = x - self.centerX

	if offsetX == 0 then
		return 0
	end

	local slopeDirection = offsetX > 0 and 1 or -1
	local width = self:getWidth(slopeDirection)
	local normalizedX = offsetX / width
	local depth = self.bottomY - self:getLipY(slopeDirection)
	local shapePower = self:getShapePower(slopeDirection)

	return -depth
		* shapePower
		* math.abs(normalizedX) ^ (shapePower - 1)
		* slopeDirection
		/ width
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
		self.leftLipY,
		self.leftX,
		self.leftLipY
	)
	
	gfx.drawLine(
		self.rightX,
		self.rightLipY,
		400,
		self.rightLipY
	)
end

return Pool
