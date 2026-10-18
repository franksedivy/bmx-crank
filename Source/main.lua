import "CoreLibs/graphics"

local gfx = playdate.graphics

-- Tuning values
-- These control how quickly the bike accelerates, coasts and tops out.
local speedGainPerDegree = 0.5
local rollingResistance = 35
local maximumSpeed = 160
local gravity = 90
local minimumTurnHeight = 8
local maximumTurnHeight = 42
local maximumChargeDuration = 1.0

local minimumTurnDuration = 0.25
local maximumTurnDuration = 0.55

local isChargingTurn = false
local turnChargeElapsed = 0

local activeTurnHeight = minimumTurnHeight
local activeTurnDuration = minimumTurnDuration

-- Pool geometry
local poolLeftX = 10
local poolRightX = 390
local poolCenterX = 200
local poolHalfWidth = 190
local poolLipY = 95
local poolBottomY = 220
local poolDepth = poolBottomY - poolLipY
local poolShapePower = 4

-- Rider state
-- These value change while the game is running.
local riderX = 40
local riderSpeed = 0
local riderFacing = 1
local isTurning = false
local turnElapsed = 0
local turnOffsetY = 0
local turnFacingChanged = false

-- Frame timing
-- We use elapsed time so movement isn't tied to a specific frame rate.
local lastUpdateTime = playdate.getCurrentTimeMilliseconds()

-- Returns the track height at a given horizontal position.
-- Screen coordinates increase downwards, so the centre has the largest Y.
local function getTrackY(x)
	local normalizedX = (x - poolCenterX) / poolHalfWidth
	local distanceFromCenter = math.abs(normalizedX)
	
	return poolBottomY
		- poolDepth * distanceFromCenter ^ poolShapePower
end

-- Returns the direction and steepness of the pool at a position.
-- Positive slopes descend right' negative slopes descend left.
local function getTrackSlope(x)
	local normalizedX = (x - poolCenterX) / poolHalfWidth
	
	if normalizedX == 0 then
		return 0
	end
	
	local slopeDirection = normalizedX > 0 and 1 or -1
	
	return -poolDepth
		* poolShapePower
		* math.abs(normalizedX) ^ (poolShapePower - 1)
		* slopeDirection
		/ poolHalfWidth
end

-- Main game running loop
function playdate.update()	
	
	-- Input
	local crankPosition = playdate.getCrankPosition()
	local crankChange = playdate.getCrankChange()
	local crankDocked = playdate.isCrankDocked()
	
	-- Calculate the time since the previous frame in seconds.
	local currentTime = playdate.getCurrentTimeMilliseconds()
	local deltaTime = (currentTime - lastUpdateTime) / 1000
	lastUpdateTime = currentTime
	
	-- Pedalling drives the bike in the direction the rider is facing.
	-- Rolling backwards does not automatically rotate the rider.
	if crankChange > 0 then
		riderSpeed = riderSpeed
			+ crankChange * speedGainPerDegree * riderFacing
	end			
	
	-- Gravity acts along the pool's slope.
	local trackSlope  = getTrackSlope(riderX)
	local tangentLength = math.sqrt(1 + trackSlope * trackSlope)
	
	local gravityAcceleration = gravity
		* trackSlope
		/ tangentLength
		
	riderSpeed = riderSpeed + gravityAcceleration * deltaTime
	
	-- Rolling resistance always opposes the current movement.
	local resistance = rollingResistance * deltaTime
	
	if riderSpeed > 0 then
		riderSpeed = math.max(0, riderSpeed - resistance)
	elseif riderSpeed < 0 then
		riderSpeed = math.min(0, riderSpeed + resistance)
	end
	
	riderSpeed = math.max(
		-maximumSpeed,
		math.min(maximumSpeed, riderSpeed)
	)
	
	-- ACTIONS -------------------------------------------------------------------
	--- TURNING
	--- Begin gathering energy when A is pressed
	if playdate.buttonJustPressed(playdate.kButtonA)
		and not isTurning
		and not isChargingTurn then
		
		isChargingTurn = true
		turnChargeElapsed = 0
	end
	
	--- Continue charging for as long as A remains held.
	if isChargingTurn then
		turnChargeElapsed = turnChargeElapsed + deltaTime
	end
	
	-- Release the stored energy when A is released.
	if playdate.buttonJustReleased(playdate.kButtonA)
		and isChargingTurn then
		
		isChargingTurn = false
		
		local chargeAmount = math.min(
			turnChargeElapsed / maximumChargeDuration,
			1
		)
		
		activeTurnHeight = minimumTurnHeight
			+ (maximumTurnHeight - minimumTurnHeight)
			* chargeAmount
		
		activeTurnDuration = minimumTurnDuration
			+ (maximumTurnDuration - minimumTurnDuration)
			* chargeAmount
		
		isTurning = true
		turnElapsed = 0
		turnFacingChanged = false
	end
	
	--- Animate the charged hop and change facing at the apex.
	if isTurning then
		turnElapsed = turnElapsed + deltaTime
		
		local turnProgress = math.min(
			turnElapsed / activeTurnDuration,
			1
		)
		
		turnOffsetY = -math.sin(turnProgress * math.pi)
			* activeTurnHeight
		
		if turnProgress >= 0.5
			and not turnFacingChanged then
			
			riderFacing = -riderFacing
			turnFacingChanged = true
		end
		
		if turnProgress >= 1 then
			isTurning = false
			turnOffsetY = 0
		end
	end
	
	-- Convert track speed into horizontal movement.
	local horiznotalSpeed = riderSpeed / tangentLength
	riderX = riderX + horiznotalSpeed * deltaTime
	
	-- Keep the rider attached to the pool until jumping is introduced.
	if riderX >= poolRightX then
		riderX = poolRightX
		riderSpeed = 0
	elseif riderX <= poolLeftX then
		riderX = poolLeftX
		riderSpeed = 0
	end

	
	-- Drawing
	gfx.clear(gfx.kColorWhite)	
	
	gfx.drawText("BMX Crank", 160, 10)
	gfx.drawText("Crank to ride", 150, 30)
	
	local turnPower = math.min(
		turnChargeElapsed / maximumChargeDuration,
		1
	)
	
	-- Temporary telemetry for tuning the riding model.
	gfx.drawText(
		"Position: " .. math.floor(crankPosition) .. " deg",
		20,
		45 
	)
	
	gfx.drawText(
		"Change: " .. string.format("%.1f", crankChange) .. "deg",
		20, 
		65
	)

	gfx.drawText(
		"Speed: " .. string.format("%.1f", riderSpeed) .. "px/s",
		275,
		45
	)
	gfx.drawText(
		"Power: " .. math.floor(turnPower * 100 + 0.5) .. "%",
		275,
		65
	)
	
	-- Draw the pool as a series of short connected lines.
	local previousX = poolLeftX
	local previousY = getTrackY(previousX)
	
	for x = poolLeftX + 2, poolRightX do
		local y = getTrackY(x)
		
		gfx.drawLine(previousX, previousY, x, y)
		
		previousX = x
		previousY = y
	end
	
	-- Keep the temporary rider resting on the pool surface.
	local riderY = getTrackY(riderX) - 8 + turnOffsetY
	gfx.fillCircleAtPoint(riderX, riderY, 8)
	
	-- Temporary direction marker showing the rider faces.
	gfx.drawLine(
		riderX,
		riderY,
		riderX + 12 * riderFacing,
		riderY
	)
end