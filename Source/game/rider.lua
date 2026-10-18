local tuning <const> = import "game/tuning"
local RiderRenderer <const> = import "game/rider_renderer"

-- Basic rider states
local riderState <const> = {
	riding = "riding",
	airborne = "airborne",
	gameOver = "gameOver",
}

local Rider = {}
Rider.__index = Rider

-- Creates a rider with its movement and charged-turn state reset.
function Rider.new()
	local rider = setmetatable({}, Rider)

	-- States
	rider.state = riderState.riding
	rider.takeoffWasSuccessful = false
	
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
	rider.takeoffPrepared = false
	rider.preparedTakeoffFacing = 1
	
	-- Airborne state
	rider.airborneX = 0
	rider.airborneY = 0
	rider.airborneVelocityX = 0
	rider.airborneVelocityY = 0
	rider.airborneAngle = 0
	rider.airborneTakeoffAngle = 0
	rider.airborneApexAngle = 0
	rider.airborneLaunchSpeed = 0
	rider.airborneLandingFacing = 1
	rider.takeoffSide = 0
	
	-- Lip-transition state
	rider.straddlingSide = 0

	return rider
end

-- Advances every part of the rider simulation for one frame.
function Rider:update(
	deltaTime,
	crankChange,
	actionPressed,
	actionReleased,
	actionHeld,
	pool
)
	if self.state == riderState.airborne then
		self:updateAirborne(deltaTime, pool)
		return
	elseif self.state == riderState.gameOver then
		return
	end
	
	self:updatePedalling(crankChange)
	self:updateGravity(deltaTime, pool)
	self:updateResistance(deltaTime)
	self:updateTurn(deltaTime, actionPressed, actionReleased)
	self:updatePosition(deltaTime, actionHeld, pool)
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

-- Handles charging, releasing and animating the shared button action.
function Rider:updateTurn(deltaTime, actionPressed, actionReleased)
	if actionPressed
		and not self.isTurning
		and not self.isChargingTurn then

		self.isChargingTurn = true
		self.turnChargeElapsed = 0
	end

	if self.isChargingTurn then
		self.turnChargeElapsed = self.turnChargeElapsed + deltaTime
	end

	if actionReleased and self.isChargingTurn then
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
	self.takeoffPrepared = chargeAmount > 0
	self.preparedTakeoffFacing = -self.facing

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

-- Launches the rider from the pool along the lip's tangent.
function Rider:beginTakeoff(pool, takeoffWasSuccessful)
	local slope = pool:getSlope(self.x)
	local tangentLength = math.sqrt(1 + slope * slope)
	local takeoffSide = self.speed > 0 and 1 or -1

	self.takeoffSide = takeoffSide
	self.takeoffWasSuccessful = takeoffWasSuccessful

	if takeoffWasSuccessful then
		-- Treat the lip as vertical for this first jump prototype. This lets
		-- the rider rise above it and fall back into the same side of the pool.
		local lipX = takeoffSide > 0
			and pool.rightX
			or pool.leftX
		local lipAngle = math.atan(pool:getSlope(lipX))

		-- The frame angle runs from the rear wheel toward the front wheel,
		-- so a left-facing rider uses the opposite end of the same tangent.
		if self.facing < 0 then
			lipAngle = lipAngle + math.pi
		end

		self.airborneLandingFacing = self.takeoffPrepared
			and self.preparedTakeoffFacing
			or -self.facing
		self.airborneX = lipX
		self.airborneY = pool.lipY - tuning.wheelRadius
		self.airborneVelocityX = 0
		self.airborneVelocityY = -math.abs(self.speed)
		self.airborneLaunchSpeed = math.abs(self.speed)
		self.airborneTakeoffAngle = lipAngle
		self.airborneApexAngle = self.facing > 0 and 0 or math.pi
		self.airborneAngle = self.airborneTakeoffAngle

		-- The stored button charge has now been used for the takeoff.
		self.takeoffPrepared = false
		self.isChargingTurn = false
		self.isTurning = false
		self.turnChargeElapsed = 0
		self.turnElapsed = 0
		self.turnOffsetY = 0
		self.turnRotation = 0
	else
		self.airborneX = self.x
			+ slope
			/ tangentLength
			* tuning.wheelRadius
		
		self.airborneY = pool:getY(self.x)
			- tuning.wheelRadius
			/ tangentLength
		
		self.airborneVelocityX = self.speed / tangentLength
		self.airborneVelocityY = self.speed
			* slope
			/ tangentLength
		
		self.airborneAngle = math.atan(slope)
	end
	self.state = riderState.airborne
	
	if takeoffWasSuccessful then
		print("Takeoff")
	else
		print("Missed takeoff")
	end
end

-- Applies gravity and free movement after leaving the pool.
function Rider:updateAirborne(deltaTime, pool)
	self.airborneVelocityY = self.airborneVelocityY
		+ tuning.airborneGravity * deltaTime

	self.airborneX = self.airborneX
		+ self.airborneVelocityX * deltaTime

	self.airborneY = self.airborneY
		+ self.airborneVelocityY * deltaTime

	-- Wheels continue spinning with their takeoff momentum.
	self.wheelRotation = (
		self.wheelRotation
			+ self.speed / tuning.wheelRadius * deltaTime
	) % (math.pi * 2)

	if self.takeoffWasSuccessful then
		-- Become horizontal at the apex, then return smoothly to the pool's
		-- tangent angle as downward speed builds again.
		local speedRatio = math.min(
			math.abs(self.airborneVelocityY)
				/ math.max(self.airborneLaunchSpeed, 1),
			1
		)
		local apexAmount = 1 - speedRatio
		local easedApexAmount = math.sin(apexAmount * math.pi / 2)

		self.airborneAngle = self.airborneTakeoffAngle
			+ (
				self.airborneApexAngle
					- self.airborneTakeoffAngle
			) * easedApexAmount

		-- Complete the prepared 180 at the apex so the rider lands facing
		-- the opposite direction even though the ground turn was consumed.
		if self.airborneVelocityY >= 0 then
			self.facing = self.airborneLandingFacing
		end
	end

	-- A prepared takeoff lands once the rider descends to lip height again.
	if self.takeoffWasSuccessful
		and self.airborneVelocityY > 0
		and self.airborneY >= pool.lipY - tuning.wheelRadius then

		local lipSlope = pool:getSlope(
			self.takeoffSide > 0 and pool.rightX or pool.leftX
		)
		local lipTangentLength = math.sqrt(1 + lipSlope * lipSlope)
		local halfWheelbaseX = tuning.wheelBase
			/ 2
			/ lipTangentLength

		if self.takeoffSide > 0 then
			self.x = pool.rightX - halfWheelbaseX - 1
		else
			self.x = pool.leftX + halfWheelbaseX + 1
		end

		-- Convert the downward landing speed into movement back into the pool.
		self.speed = -self.takeoffSide
			* math.min(
				math.abs(self.airborneVelocityY),
				tuning.maximumSpeed
			)
		self.straddlingSide = 0
		self.takeoffWasSuccessful = false
		self.state = riderState.riding
		print("Landed")
		return
	end

	local outsideHorizontally =
		self.airborneX < -tuning.wheelBase
		or self.airborneX
			> tuning.screenWidth + tuning.wheelBase

	local belowScreen =
		self.airborneY
			> tuning.screenHeight + tuning.wheelRadius

	if outsideHorizontally or belowScreen then
		self.state = riderState.gameOver
		print("Game over")
	end
end

-- Moves the rider along the pool and keeps them within its current bounds.
function Rider:updatePosition(deltaTime, actionHeld, pool)
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

	-- The bike leaves the pool only after its trailing wheel reaches the lip.
	-- Horizontal wheel spacing shrinks as the pool becomes steeper.
	local halfWheelbaseX = tuning.wheelBase
		/ 2
		/ tangentLength
	
	-- Remember when the leading wheel first crosses a lip.
	if self.straddlingSide == 0 then
		local leadingWheelX
	
		if self.speed > 0 then
			leadingWheelX = self.x + halfWheelbaseX
	
			if leadingWheelX >= pool.rightX then
				self.straddlingSide = 1
			end
		elseif self.speed < 0 then
			leadingWheelX = self.x - halfWheelbaseX
	
			if leadingWheelX <= pool.leftX then
				self.straddlingSide = -1
			end
		end
	end
	
	if self.straddlingSide == 1 then
		local trailingWheelX = self.x - halfWheelbaseX
	
		if self.speed > 0 and trailingWheelX >= pool.rightX then
			self.straddlingSide = 0
			self.x = pool.rightX + halfWheelbaseX
	
			self:beginTakeoff(
				pool,
				actionHeld or self.takeoffPrepared
			)
		elseif self.speed <= 0 then
			-- Let gravity pull the rider back when momentum runs out.
			self.straddlingSide = 0
		end
	elseif self.straddlingSide == -1 then
		local trailingWheelX = self.x + halfWheelbaseX
	
		if self.speed < 0 and trailingWheelX <= pool.leftX then
			self.straddlingSide = 0
			self.x = pool.leftX - halfWheelbaseX
	
			self:beginTakeoff(
				pool,
				actionHeld or self.takeoffPrepared
			)
		elseif self.speed >= 0 then
			-- Let gravity pull the rider back when momentum runs out.
			self.straddlingSide = 0
		end
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

-- Returns whether the rider has finished an unsuccessful run.
function Rider:isGameOver()
	return self.state == riderState.gameOver
end

-- Delegates temporary bike drawing to the renderer.
function Rider:draw(pool)
	RiderRenderer.draw(self, pool)
end

return Rider
