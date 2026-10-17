import "CoreLibs/graphics"

local gfx = playdate.graphics

-- Tuning values
-- These control how quickly the bike accelerates, coasts and tops out.
local groundY = 180
local speedGainPerDegree = 0.5
local rollingResistance = 35
local maximumSpeed = 160

-- Rider state
-- These value change while the game is running.
local riderX = 40
local riderSpeed = 0

-- Frame timing
-- We use elapsed time so movement isn't tied to a specific frame rate.
local lastUpdateTime = playdate.getCurrentTimeMilliseconds()

function playdate.update()	
	
	-- Input
	local crankPosition = playdate.getCrankPosition()
	local crankChange = playdate.getCrankChange()
	local crankDocked = playdate.isCrankDocked()
	
	-- Calculate the time since the previous frame in seconds.
	local currentTime = playdate.getCurrentTimeMilliseconds()
	local deltaTime = (currentTime - lastUpdateTime) / 1000
	lastUpdateTime = currentTime
	
	-- Pedalling forwards adds energy to the bike.
	if crankChange > 0 then
		riderSpeed = riderSpeed + crankChange * speedGainPerDegree
		riderSpeed = math.min(riderSpeed, maximumSpeed)
	end
	
	-- Rolling resistance gradually brings an unpowered bike to rest.
	riderSpeed = math.max(
		0,
		riderSpeed - rollingResistance * deltaTime
	)
	
	-- Move according to velocity rather than directly from crank input.
	riderX = riderX + riderSpeed * deltaTime
	
	-- Temporary wraparound lets us test continous movement
	if riderX > 390 then 
		riderX = 10
	end
	
	-- Drawing
	gfx.clear(gfx.kColorWhite)
	
	gfx.drawText("BMX Crank", 160, 10)
	gfx.drawText("Crank to ride", 150, 30)
	
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
		20,
		85
	)
	
	-- Temporary rider and ground placeholders.
	gfx.drawLine(0, groundY, 400, groundY)
	gfx.fillCircleAtPoint(riderX, groundY - 8, 8)
end