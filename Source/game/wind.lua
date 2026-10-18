-- One shared wind value for the scene and telemetry. Units are pixels/second.
-- Positive blows right; negative blows left. Jump influence is a future mechanic.
local settings <const> = {
	initialSpeed = -12,
	minimumSpeed = 6,
	maximumSpeed = 20,
	-- Seconds between choosing a new strength and reversing direction.
	minimumChangeInterval = 20,
	maximumChangeInterval = 45,
	-- Speed change per second; lower values make reversals more gradual.
	acceleration = 2.5,
}

local Wind = {}
Wind.__index = Wind

-- Creates persistent weather state; rider respawns do not reset the wind.
function Wind.new()
	local wind = setmetatable({}, Wind)
	wind.speed = settings.initialSpeed
	wind.targetSpeed = settings.initialSpeed
	wind.changeRemaining = math.random(
		settings.minimumChangeInterval, settings.maximumChangeInterval
	)
	return wind
end

-- Occasionally reverses the target, easing through calm rather than snapping.
function Wind:update(deltaTime)
	self.changeRemaining = self.changeRemaining - deltaTime
	if self.changeRemaining <= 0 then
		local nextDirection = self.targetSpeed < 0 and 1 or -1
		self.targetSpeed = nextDirection
			* math.random(settings.minimumSpeed, settings.maximumSpeed)
		self.changeRemaining = math.random(
			settings.minimumChangeInterval, settings.maximumChangeInterval
		)
	end

	local maximumChange = settings.acceleration * deltaTime
	if self.speed < self.targetSpeed then
		self.speed = math.min(self.targetSpeed, self.speed + maximumChange)
	else
		self.speed = math.max(self.targetSpeed, self.speed - maximumChange)
	end
end

-- Supplies the same signed speed to every consumer without exposing mutation.
function Wind:getSpeed()
	return self.speed
end

return Wind
