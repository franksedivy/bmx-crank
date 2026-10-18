local gfx <const> = playdate.graphics

-- Riding-model tuning. Units are pixels, seconds and degrees.
local tuning <const> = {
	speedGainPerDegree = 0.8,
	rollingResistance = 35,
	maximumSpeed = 220,
	gravity = 90,
	minimumTurnHeight = 8,
	maximumTurnHeight = 42,
	maximumChargeDuration = 1.0,
	minimumTurnDuration = 0.25,
	maximumTurnDuration = 0.55,
	turnPoseCount = 4,
	wheelBase = 32,
	wheelRadius = 12,
	wheelMarkerOrbitRadius = 7,
	wheelMarkerRadius = 2,
}

local Rider = {}
Rider.__index = Rider

-- Creates a rider with its movement and charged-turn state reset.
function Rider.new()
	local rider = setmetatable({}, Rider)

	-- Movement state
	rider.x = 40
	rider.speed = 0
	rider.facing = 1
	rider.wheelRotation = 0

	-- Charged-turn state
	rider.isChargingTurn = false
	rider.turnChargeElapsed = 0
	rider.isTurning = false
	rider.turnElapsed = 0
	rider.turnOffsetY = 0
	rider.turnFacingChanged = false
	rider.turnRotation = 0
	rider.turnStartFacing = 1
	rider.activeTurnHeight = tuning.minimumTurnHeight
	rider.activeTurnDuration = tuning.minimumTurnDuration

	return rider
end

-- Advances every part of the rider simulation for one frame.
function Rider:update(deltaTime, crankChange, turnPressed, turnReleased, pool)
	self:updatePedalling(crankChange)
	self:updateGravity(deltaTime, pool)
	self:updateResistance(deltaTime)
	self:updateTurn(deltaTime, turnPressed, turnReleased)
	self:updatePosition(deltaTime, pool)
end

-- Converts forward crank movement into speed in the facing direction.
function Rider:updatePedalling(crankChange)
	-- Forward cranking drives the bike in the direction the rider faces.
	-- Rolling backwards does not automatically rotate the rider.
	if crankChange > 0 then
		self.speed = self.speed
			+ crankChange * tuning.speedGainPerDegree * self.facing
	end
end

-- Accelerates the rider downhill based on the pool's local slope.
function Rider:updateGravity(deltaTime, pool)
	local trackSlope = pool:getSlope(self.x)
	local tangentLength = math.sqrt(1 + trackSlope * trackSlope)
	local gravityAcceleration = tuning.gravity
		* trackSlope
		/ tangentLength

	self.speed = self.speed + gravityAcceleration * deltaTime
end

-- Slows the rider while preserving the sign of forward or reverse movement.
function Rider:updateResistance(deltaTime)
	-- Rolling resistance always opposes the current movement.
	local resistance = tuning.rollingResistance * deltaTime

	if self.speed > 0 then
		self.speed = math.max(0, self.speed - resistance)
	elseif self.speed < 0 then
		self.speed = math.min(0, self.speed + resistance)
	end

	self.speed = math.max(
		-tuning.maximumSpeed,
		math.min(tuning.maximumSpeed, self.speed)
	)
end

-- Handles charging, releasing and animating the down-button turn action.
function Rider:updateTurn(deltaTime, turnPressed, turnReleased)
	if turnPressed
		and not self.isTurning
		and not self.isChargingTurn then

		self.isChargingTurn = true
		self.turnChargeElapsed = 0
	end

	if self.isChargingTurn then
		self.turnChargeElapsed = self.turnChargeElapsed + deltaTime
	end

	if turnReleased and self.isChargingTurn then
		self:releaseTurn()
	end

	if self.isTurning then
		self:animateTurn(deltaTime)
	end
end

-- Converts the stored charge into the height and duration of a turn.
function Rider:releaseTurn()
	self.isChargingTurn = false

	local chargeAmount = self:getTurnPower()

	self.activeTurnHeight = tuning.minimumTurnHeight
		+ (tuning.maximumTurnHeight - tuning.minimumTurnHeight)
		* chargeAmount

	self.activeTurnDuration = tuning.minimumTurnDuration
		+ (tuning.maximumTurnDuration - tuning.minimumTurnDuration)
		* chargeAmount

	self.turnStartFacing = self.facing
	self.turnRotation = 0
	self.isTurning = true
	self.turnElapsed = 0
	self.turnFacingChanged = false
end

-- Moves the rider through the turn arc and flips their facing at its apex.
function Rider:animateTurn(deltaTime)
	self.turnElapsed = self.turnElapsed + deltaTime

	local turnProgress = math.min(
		self.turnElapsed / self.activeTurnDuration,
		1
	)

	-- A parabolic arc gives maximum speed at takeoff and landing,
	-- slowing smoothly  to zero vertical speed at the apex.
	self.turnOffsetY = -4
		* self.activeTurnHeight
		* turnProgress
		* (1 - turnProgress)

	-- Quantise the 180-degree turn into four temporary animation poses.
	local poseIndex = math.min(
		tuning.turnPoseCount - 1,
		math.floor(turnProgress * tuning.turnPoseCount)
	)

	self.turnRotation = poseIndex
		/ (tuning.turnPoseCount - 1)
		* math.pi

	if turnProgress >= 0.5 and not self.turnFacingChanged then
		self.facing = -self.facing
		self.turnFacingChanged = true
	end

	if turnProgress >= 1 then
		-- Preserve the wheel-marker rotation produced by the flip.
		self.wheelRotation = (
			self.wheelRotation + self.turnRotation
		) % (math.pi * 2)

		self.turnRotation = 0
		self.isTurning = false
		self.turnOffsetY = 0
	end
end

-- Moves the rider along the pool and keeps them within its current bounds.
function Rider:updatePosition(deltaTime, pool)
	local trackSlope = pool:getSlope(self.x)
	local tangentLength = math.sqrt(1 + trackSlope * trackSlope)

	-- Convert surface travel into wheel rotation.
	-- Positive speed rotates clockwise; reverse speed rotates anticlockwise.
	self.wheelRotation = (
		self.wheelRotation
			+ self.speed / tuning.wheelRadius * deltaTime
	) % (math.pi * 2)

	-- Surface speed produces less horizontal movement on steep walls.
	local horizontalSpeed = self.speed / tangentLength
	self.x = self.x + horizontalSpeed * deltaTime

	-- Keep the rider attached to the pool until jumping is introduced.
	if self.x >= pool.rightX then
		self.x = pool.rightX
		self.speed = 0
	elseif self.x <= pool.leftX then
		self.x = pool.leftX
		self.speed = 0
	end
end

-- Returns signed surface speed in pixels per second.
function Rider:getSpeed()
	return self.speed
end

-- Returns the current turn charge as a value between zero and one.
function Rider:getTurnPower()
	return math.min(
		self.turnChargeElapsed / tuning.maximumChargeDuration,
		1
	)
end

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
local function getWheelCenter(pool, contactX, jumpOffsetY)
	local slope = pool:getSlope(contactX)
	local normalLength = math.sqrt(1 + slope * slope)

	local wheelX = contactX
		+ slope
		/ normalLength
		* tuning.wheelRadius

	local wheelY = pool:getY(contactX)
		- tuning.wheelRadius
		/ normalLength
		+ jumpOffsetY

	return wheelX, wheelY
end

-- Draws both wheels tangent to the pool surface.
function Rider:draw(pool)
	local centerSlope = pool:getSlope(self.x)
	local centerTangentLength = math.sqrt(
		1 + centerSlope * centerSlope
	)

	-- Keep the bike centred on self.x.
	-- Changing facing swaps the front and rear wheels without moving the bike.
	local visualFacing = self.facing
	local wheelbaseScale = 1
	local displayedWheelRotation = self.wheelRotation

	if self.isTurning then
		visualFacing = self.turnStartFacing
		wheelbaseScale = math.cos(self.turnRotation)
		displayedWheelRotation = (
			self.wheelRotation + self.turnRotation
		) % (math.pi * 2)
	end

	local contactOffsetX = visualFacing
		* wheelbaseScale
		/ centerTangentLength
		* tuning.wheelBase
		/ 2

	local rearContactX = self.x - contactOffsetX
	local frontContactX = self.x + contactOffsetX

	local rearWheelX, rearWheelY = getWheelCenter(
		pool,
		rearContactX,
		self.turnOffsetY
	)

	local frontWheelX, frontWheelY = getWheelCenter(
		pool,
		frontContactX,
		self.turnOffsetY
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

return Rider
