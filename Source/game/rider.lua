local gfx <const> = playdate.graphics

-- Riding-model tuning. Units are pixels, seconds and degrees.
local tuning <const> = {
	-- Globals
	gravity = 90,
	screenWidth = 400,
	screenHeight = 240,
	
	-- Bike properties
	wheelBase = 48,
	wheelRadius = 12,
	wheelMarkerOrbitRadius = 7,
	wheelMarkerRadius = 2,
	
	-- Bike movement
	speedGainPerDegree = 0.3,
	rollingResistance = 35,
	maximumSpeed = 280,
	
	-- Direction turning
	minimumTurnHeight = 8,
	maximumTurnHeight = 42,
	maximumChargeDuration = 1.0,
	minimumTurnDuration = 0.25,
	maximumTurnDuration = 0.55,
	turnPoseCount = 4,
	
	-- Jumping
	airborneGravity = 420,
	stallSettleDuration = 0.3,
}

-- Basic rider states
local riderState <const> = {
	riding = "riding",
	lipStall = "lipStall",
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
	rider.stallSide = 0
	rider.stallStartX = 0
	rider.stallTargetX = 0
	rider.stallSettleElapsed = 0
	rider.stallLockProgress = 0

	return rider
end

-- Advances every part of the rider simulation for one frame.
function Rider:update(deltaTime, crankChange, turnPressed, turnReleased, jumpHeld, pool)
	if self.state == riderState.airborne then
		self:updateAirborne(deltaTime, pool)
		return
	elseif self.state == riderState.gameOver then
		return
	elseif self.state == riderState.lipStall then
		self:updateLipStallSettlement(deltaTime)
		return
	end
	
	self:updatePedalling(crankChange)
	self:updateGravity(deltaTime, pool)
	self:updateResistance(deltaTime)
	self:updateTurn(deltaTime, turnPressed, turnReleased)
	self:updatePosition(deltaTime, jumpHeld, pool)
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

-- Begins the short fall from the straddling position onto the deck.
function Rider:beginLipStall(side, pool, halfWheelbaseX)
	self.state = riderState.lipStall
	self.stallSide = side
	self.straddlingSide = 0
	self.speed = 0
	self.stallStartX = self.x
	self.stallSettleElapsed = 0
	self.stallLockProgress = 0

	if side > 0 then
		self.stallTargetX = pool.rightX - halfWheelbaseX
	else
		self.stallTargetX = pool.leftX + halfWheelbaseX
	end

	print("Lip stall")
end

-- Eases the bike into its locked position under simulated gravity.
function Rider:updateLipStallSettlement(deltaTime)
	if self.stallLockProgress >= 1 then
		return
	end

	self.stallSettleElapsed = self.stallSettleElapsed + deltaTime

	local progress = math.min(
		self.stallSettleElapsed / tuning.stallSettleDuration,
		1
	)

	-- Start slowly, then accelerate into the deck like a short fall.
	self.stallLockProgress = progress * progress
end

-- Moves the rider along the pool and keeps them within its current bounds.
function Rider:updatePosition(deltaTime, jumpHeld, pool)
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
				jumpHeld or self.takeoffPrepared
			)
		elseif self.speed <= 0 then
			-- Lip stalls are disabled for now. Let gravity pull the rider
			-- naturally back into the pool when momentum runs out.
			self.straddlingSide = 0
		end
	elseif self.straddlingSide == -1 then
		local trailingWheelX = self.x + halfWheelbaseX
	
		if self.speed < 0 and trailingWheelX <= pool.leftX then
			self.straddlingSide = 0
			self.x = pool.leftX - halfWheelbaseX
	
			self:beginTakeoff(
				pool,
				jumpHeld or self.takeoffPrepared
			)
		elseif self.speed >= 0 then
			-- Lip stalls are disabled for now. Let gravity pull the rider
			-- naturally back into the pool when momentum runs out.
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

-- Finds the inner wheel position that keeps a rigid bike connected to a
-- wheel resting on the deck. The search follows the pool surface inward.
local function getLockedInnerWheelCenter(
	pool,
	stallSide,
	outerWheelX,
	outerWheelY,
	wheelSpan,
	jumpOffsetY
)
	local lipContactX = stallSide > 0
		and pool.rightX
		or pool.leftX

	local nearLip = 0
	local nearCenter = 1

	for _ = 1, 12 do
		local position = (nearLip + nearCenter) / 2
		local contactX = lipContactX
			+ (pool.centerX - lipContactX) * position

		local wheelX, wheelY = getWheelCenter(
			pool,
			contactX,
			jumpOffsetY
		)

		local distanceX = outerWheelX - wheelX
		local distanceY = outerWheelY - wheelY
		local distance = math.sqrt(
			distanceX * distanceX + distanceY * distanceY
		)

		if distance < wheelSpan then
			nearLip = position
		else
			nearCenter = position
		end
	end

	local position = (nearLip + nearCenter) / 2
	local contactX = lipContactX
		+ (pool.centerX - lipContactX) * position

	return getWheelCenter(pool, contactX, jumpOffsetY)
end

-- Draws both wheels tangent to the pool surface.
function Rider:draw(pool)
	if self.state == riderState.airborne
	or self.state == riderState.gameOver then
		local directionX = math.cos(self.airborneAngle)
		local directionY = math.sin(self.airborneAngle)
		local halfWheelbase = tuning.wheelBase / 2
	
		local rearWheelX = self.airborneX
			- directionX * halfWheelbase
	
		local rearWheelY = self.airborneY
			- directionY * halfWheelbase
	
		local frontWheelX = self.airborneX
			+ directionX * halfWheelbase
	
		local frontWheelY = self.airborneY
			+ directionY * halfWheelbase
			
		gfx.drawLine(
			rearWheelX,
			rearWheelY,
			frontWheelX,
			frontWheelY
		)
	
		drawWheel(
			rearWheelX,
			rearWheelY,
			self.wheelRotation
		)
	
		drawWheel(
			frontWheelX,
			frontWheelY,
			self.wheelRotation
		)
	
		return
	end
	
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

	-- Move between two rigid bike poses: the straddling pose and a locked
	-- pose with one wheel on the deck and the other resting on the pool.
	if self.state == riderState.lipStall then
		local lockProgress = self.stallLockProgress
		local deckWheelY = pool.lipY
			- tuning.wheelRadius
			+ self.turnOffsetY

		local innerWheelX
		local innerWheelY
		local outerWheelX
		local outerWheelY
		local lockedOuterWheelX
		local outerIsFront

		if self.stallSide > 0 then
			lockedOuterWheelX = pool.rightX

			if frontContactX > rearContactX then
				outerIsFront = true
				outerWheelX = frontWheelX
				outerWheelY = frontWheelY
				innerWheelX = rearWheelX
				innerWheelY = rearWheelY
			else
				outerIsFront = false
				outerWheelX = rearWheelX
				outerWheelY = rearWheelY
				innerWheelX = frontWheelX
				innerWheelY = frontWheelY
			end
		else
			lockedOuterWheelX = pool.leftX

			if frontContactX < rearContactX then
				outerIsFront = true
				outerWheelX = frontWheelX
				outerWheelY = frontWheelY
				innerWheelX = rearWheelX
				innerWheelY = rearWheelY
			else
				outerIsFront = false
				outerWheelX = rearWheelX
				outerWheelY = rearWheelY
				innerWheelX = frontWheelX
				innerWheelY = frontWheelY
			end
		end

		local initialX = outerWheelX - innerWheelX
		local initialY = outerWheelY - innerWheelY
		local wheelSpan = math.sqrt(
			initialX * initialX + initialY * initialY
		)

		local lockedInnerWheelX, lockedInnerWheelY =
			getLockedInnerWheelCenter(
				pool,
				self.stallSide,
				lockedOuterWheelX,
				deckWheelY,
				wheelSpan,
				self.turnOffsetY
			)

		local initialCenterX = (innerWheelX + outerWheelX) / 2
		local initialCenterY = (innerWheelY + outerWheelY) / 2
		local lockedCenterX = (
			lockedInnerWheelX + lockedOuterWheelX
		) / 2
		local lockedCenterY = (
			lockedInnerWheelY + deckWheelY
		) / 2

		local centerX = initialCenterX
			+ (lockedCenterX - initialCenterX) * lockProgress
		local centerY = initialCenterY
			+ (lockedCenterY - initialCenterY) * lockProgress

		local initialAngle = math.atan(initialY, initialX)
		local lockedAngle = math.atan(
			deckWheelY - lockedInnerWheelY,
			lockedOuterWheelX - lockedInnerWheelX
		)
		local angle = initialAngle
			+ (lockedAngle - initialAngle) * lockProgress

		local halfSpanX = math.cos(angle) * wheelSpan / 2
		local halfSpanY = math.sin(angle) * wheelSpan / 2

		if self.stallSide > 0 then
			innerWheelX = centerX - halfSpanX
			innerWheelY = centerY - halfSpanY
			outerWheelX = centerX + halfSpanX
			outerWheelY = centerY + halfSpanY
		else
			innerWheelX = centerX + halfSpanX
			innerWheelY = centerY + halfSpanY
			outerWheelX = centerX - halfSpanX
			outerWheelY = centerY - halfSpanY
		end

		if outerIsFront then
			frontWheelX = outerWheelX
			frontWheelY = outerWheelY
			rearWheelX = innerWheelX
			rearWheelY = innerWheelY
		else
			frontWheelX = innerWheelX
			frontWheelY = innerWheelY
			rearWheelX = outerWheelX
			rearWheelY = outerWheelY
		end
	end

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
