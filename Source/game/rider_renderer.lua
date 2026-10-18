import "CoreLibs/graphics"

local tuning <const> = import "game/tuning"
local gfx <const> = playdate.graphics

local RiderRenderer = {}

-- Draws one temporary wheel and its rotating white marker.
local function drawWheel(x, y, rotation)
	gfx.setColor(gfx.kColorBlack)
	gfx.fillCircleAtPoint(x, y, tuning.wheelRadius)

	local rotationMarkerX = x
		+ math.cos(rotation)
		* tuning.wheelMarkerOrbitRadius

	local rotationMarkerY = y
		+ math.sin(rotation)
		* tuning.wheelMarkerOrbitRadius

	gfx.setColor(gfx.kColorWhite)
	gfx.fillCircleAtPoint(
		rotationMarkerX,
		rotationMarkerY,
		tuning.wheelMarkerRadius
	)

	gfx.setColor(gfx.kColorBlack)
end

-- Positions a wheel one radius above the pool along its surface normal.
local function getWheelCenter(pool, contactX, actionOffsetY)
	local slope = pool:getSlope(contactX)
	local normalLength = math.sqrt(1 + slope * slope)

	local wheelX = contactX
		+ slope
		/ normalLength
		* tuning.wheelRadius

	local wheelY = pool:getY(contactX)
		- tuning.wheelRadius
		/ normalLength
		+ actionOffsetY

	return wheelX, wheelY
end

-- Draws the airborne bike as a rigid frame at its current angle.
local function drawAirborne(rider)
	local directionX = math.cos(rider.airborneAngle)
	local directionY = math.sin(rider.airborneAngle)
	local halfWheelbase = tuning.wheelBase / 2

	local rearWheelX = rider.airborneX
		- directionX * halfWheelbase
	local rearWheelY = rider.airborneY
		- directionY * halfWheelbase
	local frontWheelX = rider.airborneX
		+ directionX * halfWheelbase
	local frontWheelY = rider.airborneY
		+ directionY * halfWheelbase

	gfx.drawLine(
		rearWheelX,
		rearWheelY,
		frontWheelX,
		frontWheelY
	)

	drawWheel(rearWheelX, rearWheelY, rider.wheelRotation)
	drawWheel(frontWheelX, frontWheelY, rider.wheelRotation)
end

-- Draws both wheels tangent to the pool surface.
local function drawRiding(rider, pool)
	local centerSlope = pool:getSlope(rider.x)
	local centerTangentLength = math.sqrt(
		1 + centerSlope * centerSlope
	)

	-- Changing facing swaps the wheels without moving the bike's centre.
	local visualFacing = rider.facing
	local wheelbaseScale = 1
	local displayedWheelRotation = rider.wheelRotation

	if rider.isTurning then
		visualFacing = rider.turnStartFacing
		wheelbaseScale = math.cos(rider.turnRotation)
		displayedWheelRotation = (
			rider.wheelRotation + rider.turnRotation
		) % (math.pi * 2)
	end

	local contactOffsetX = visualFacing
		* wheelbaseScale
		/ centerTangentLength
		* tuning.wheelBase
		/ 2

	local rearWheelX, rearWheelY = getWheelCenter(
		pool,
		rider.x - contactOffsetX,
		rider.turnOffsetY
	)

	local frontWheelX, frontWheelY = getWheelCenter(
		pool,
		rider.x + contactOffsetX,
		rider.turnOffsetY
	)

	-- Draw the basic frame behind the wheels.
	gfx.drawLine(
		rearWheelX,
		rearWheelY,
		frontWheelX,
		frontWheelY
	)

	drawWheel(
		rearWheelX,
		rearWheelY,
		displayedWheelRotation
	)

	drawWheel(
		frontWheelX,
		frontWheelY,
		displayedWheelRotation
	)
end

-- Selects the appropriate temporary bike drawing for the rider state.
function RiderRenderer.draw(rider, pool)
	if rider.state == "airborne" or rider.state == "gameOver" then
		drawAirborne(rider)
	else
		drawRiding(rider, pool)
	end
end

return RiderRenderer
