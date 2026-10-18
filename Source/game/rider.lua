local gfx <const> = playdate.graphics

-- Riding-model tuning. Units are pixels, seconds and degrees.
local tuning <const> = {
	speedGainPerDegree = 0.5,
	rollingResistance = 35,
	maximumSpeed = 160,
	gravity = 90,
	minimumTurnHeight = 8,
	maximumTurnHeight = 42,
	maximumChargeDuration = 1.0,
	minimumTurnDuration = 0.25,
	maximumTurnDuration = 0.55,
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

	-- Charged-turn state
	rider.isChargingTurn = false
	rider.turnChargeElapsed = 0
	rider.isTurning = false
	rider.turnElapsed = 0
	rider.turnOffsetY = 0
	rider.turnFacingChanged = false
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

-- Handles charging, releasing and animating the A-button turn action.
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

	self.turnOffsetY = -math.sin(turnProgress * math.pi)
		* self.activeTurnHeight

	if turnProgress >= 0.5 and not self.turnFacingChanged then
		self.facing = -self.facing
		self.turnFacingChanged = true
	end

	if turnProgress >= 1 then
		self.isTurning = false
		self.turnOffsetY = 0
	end
end

-- Moves the rider along the pool and keeps them within its current bounds.
function Rider:updatePosition(deltaTime, pool)
	local trackSlope = pool:getSlope(self.x)
	local tangentLength = math.sqrt(1 + trackSlope * trackSlope)

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

-- Draws the temporary rider marker at its current pool position.
function Rider:draw(pool)
	local riderY = pool:getY(self.x) - 8 + self.turnOffsetY

	gfx.fillCircleAtPoint(self.x, riderY, 8)

	-- Temporary direction marker showing which way the rider faces.
	gfx.drawLine(
		self.x,
		riderY,
		self.x + 12 * self.facing,
		riderY
	)
end

return Rider
