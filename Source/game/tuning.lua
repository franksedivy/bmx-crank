-- Shared rider tuning. Units are pixels, seconds and degrees.
local tuning <const> = {
	-- Globals
	gravity = 90,
	screenWidth = 400,
	screenHeight = 240,

	-- Bike properties
	wheelBase = 38,
	wheelRadius = 8,
	forkLength = 20,
	wheelMarkerOrbitRadius = 7,
	wheelMarkerRadius = 2,

	-- Rider artwork alignment. The visibility toggle lives in game.lua.
	riderSpritePath = "images/rider/default-side",
	riderSpriteScale = 1.4,
	-- Offsets are pixels in bike-local space: positive X is forward, Y is down.
	riderSpriteOffsetX = 0,
	riderSpriteOffsetY = 0,
	-- Extra clockwise rotation in degrees, mirrored when facing left.
	riderSpriteAngleOffset = 0,
	-- Source-image axle midpoint; rotation and placement are anchored here.
	riderSpritePivotX = 31.5,
	riderSpritePivotY = 49,
	-- Source-image wheel spacing/radius, used to erase the sprite's static wheels.
	-- Adjust these if the PNG's wheel positions change; rebuild to refresh.
	riderSpriteWheelBase = 27,
	riderSpriteWheelMaskRadius = 8,

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
