import "CoreLibs/graphics"

local gfx <const> = playdate.graphics

local RiderRenderer = {}

local spriteRight
local spriteLeft

-- Prepares wheel-free artwork and its mirrored copy once per game session.
local function loadRiderSprites(tuning)
	if spriteRight then
		return
	end

	local image, errorMessage = gfx.image.new(tuning.riderSpritePath)
	assert(image, "Cannot load rider sprite: " .. tuning.riderSpritePath
		.. ": " .. tostring(errorMessage))
	spriteRight = image:copy()

	-- Clear both static wheels so the procedural wheels remain visible beneath.
	gfx.pushContext(spriteRight)
	gfx.setColor(gfx.kColorClear)
	gfx.fillCircleAtPoint(
		tuning.riderSpritePivotX - tuning.riderSpriteWheelBase / 2,
		tuning.riderSpritePivotY,
		tuning.riderSpriteWheelMaskRadius
	)
	gfx.fillCircleAtPoint(
		tuning.riderSpritePivotX + tuning.riderSpriteWheelBase / 2,
		tuning.riderSpritePivotY,
		tuning.riderSpriteWheelMaskRadius
	)
	gfx.popContext()

	local width, height = spriteRight:getSize()
	spriteLeft = gfx.image.new(width, height, gfx.kColorClear)
	gfx.pushContext(spriteLeft)
	spriteRight:draw(0, 0, gfx.kImageFlippedX)
	gfx.popContext()
end

-- Anchors the sprite at the axle midpoint, preserving alignment on slopes.
local function drawRiderSprite(
	rearX, rearY, frontX, frontY, facing, widthScale, tuning, riderSpriteEnabled
)
	if not riderSpriteEnabled then
		return
	end
	loadRiderSprites(tuning)

	local image = facing > 0 and spriteRight or spriteLeft
	local width, height = image:getSize()
	local pivotX = tuning.riderSpritePivotX
	if facing < 0 then
		pivotX = width - 1 - pivotX
	end

	-- Remove the facing flip from the axle vector to keep the rider upright.
	local angle = math.atan(
		(frontY - rearY) * facing,
		(frontX - rearX) * facing
	) + math.rad(tuning.riderSpriteAngleOffset * facing)
	local scale = tuning.riderSpriteScale
	local scaleX = scale * math.max(math.abs(widthScale), 0.01)

	-- drawRotated uses the image centre; translate it around the axle pivot.
	local offsetX = (width / 2 - pivotX) * scaleX
		+ tuning.riderSpriteOffsetX * facing
	local offsetY = (height / 2 - tuning.riderSpritePivotY) * scale
		+ tuning.riderSpriteOffsetY
	local cosine = math.cos(angle)
	local sine = math.sin(angle)
	local drawX = (rearX + frontX) / 2 + offsetX * cosine - offsetY * sine
	local drawY = (rearY + frontY) / 2 + offsetX * sine + offsetY * cosine

	image:drawRotated(drawX, drawY, math.deg(angle), scaleX, scale)
end

-- Extends a short fork from the front axle toward the bike's upper side.
-- Draw behind the wheel so its rotating marker remains unobstructed.
local function drawFork(x, y, upX, upY, tuning)
	gfx.setColor(gfx.kColorBlack)
	gfx.drawLine(
		x,
		y,
		x + upX * tuning.forkLength,
		y + upY * tuning.forkLength
	)
end

-- Draws one temporary wheel and its rotating white marker.
local function drawWheel(x, y, rotation, tuning)
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
local function getWheelCenter(pool, contactX, actionOffsetY, tuning)
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
local function drawAirborne(rider, tuning, riderSpriteEnabled)
	local directionX = math.cos(rider.airborneAngle)
	local directionY = math.sin(rider.airborneAngle)
	-- Missed takeoffs store only the surface angle, without the facing flip.
	if not rider.takeoffWasSuccessful and rider.facing < 0 then
		directionX = -directionX
		directionY = -directionY
	end
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

	-- The frame angle includes facing; remove that flip for the upward normal.
	local visualFacing = rider.facing
	if rider.takeoffWasSuccessful then
		visualFacing = rider.airborneApexAngle == 0 and 1 or -1
	end
	drawFork(
		frontWheelX,
		frontWheelY,
		directionY * visualFacing,
		-directionX * visualFacing,
		tuning
	)

	drawWheel(rearWheelX, rearWheelY, rider.wheelRotation, tuning)
	drawWheel(frontWheelX, frontWheelY, rider.wheelRotation, tuning)
	drawRiderSprite(
		rearWheelX, rearWheelY, frontWheelX, frontWheelY,
		visualFacing, 1, tuning, riderSpriteEnabled
	)
end

-- Draws both wheels tangent to the pool surface.
local function drawRiding(rider, pool, tuning, riderSpriteEnabled)
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
		rider.turnOffsetY,
		tuning
	)

	local frontWheelX, frontWheelY = getWheelCenter(
		pool,
		rider.x + contactOffsetX,
		rider.turnOffsetY,
		tuning
	)

	-- Draw the basic frame behind the wheels.
	gfx.drawLine(
		rearWheelX,
		rearWheelY,
		frontWheelX,
		frontWheelY
	)

	local frontSlope = pool:getSlope(rider.x + contactOffsetX)
	local frontNormalLength = math.sqrt(1 + frontSlope * frontSlope)
	drawFork(
		frontWheelX,
		frontWheelY,
		frontSlope / frontNormalLength,
		-1 / frontNormalLength,
		tuning
	)

	drawWheel(
		rearWheelX,
		rearWheelY,
		displayedWheelRotation,
		tuning
	)

	drawWheel(
		frontWheelX,
		frontWheelY,
		displayedWheelRotation,
		tuning
	)

	local spriteFacing = visualFacing * (wheelbaseScale < 0 and -1 or 1)
	drawRiderSprite(
		rearWheelX, rearWheelY, frontWheelX, frontWheelY,
		spriteFacing, wheelbaseScale, tuning, riderSpriteEnabled
	)
end

-- Uses the rider's tuning table because Playdate imports execute only once.
function RiderRenderer.draw(rider, pool, tuning, riderSpriteEnabled)
	if rider.state == "airborne" or rider.state == "gameOver" then
		drawAirborne(rider, tuning, riderSpriteEnabled)
	else
		drawRiding(rider, pool, tuning, riderSpriteEnabled)
	end
end

return RiderRenderer
