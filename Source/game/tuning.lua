-- Shared rider tuning. Units are pixels, seconds and degrees.
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
}

return tuning
