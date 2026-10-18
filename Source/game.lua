import "CoreLibs/graphics"

local Pool = import "game/pool"
local Rider = import "game/rider"
local Scene = import "game/scene"
local Wind = import "game/wind"
local Telemetry = import "ui/telemetry"

local gfx <const> = playdate.graphics

-- Set false for a white background and the original wireframe pool.
local useSceneArtwork <const> = true
-- Overlay the physics surface while aligning artwork with the riding model.
local showPoolTrace <const> = false
-- Set false to draw only the procedural bike and rotating wheels.
local riderSpriteEnabled <const> = true
-- Set false to hide both moving cloud depths while keeping the landscape.
local cloudsEnabled <const> = true

local Game = {}
Game.__index = Game

function Game.new()
	local game = setmetatable({}, Game)
	-- Seed once at startup, so cloud arrangements vary between game sessions.
	math.randomseed(playdate.getSecondsSinceEpoch())

	game.wind = Wind.new()
	game.pool = Pool.new()
	game.rider = Rider.new()
	if useSceneArtwork then
		game.scene = Scene.new(cloudsEnabled)
	end
	game.telemetry = Telemetry.new()
	game.lastUpdateTime = playdate.getCurrentTimeMilliseconds()

	return game
end

-- Coordinates input, simulation and drawing for one frame.
function Game:update()
	local crankPosition = playdate.getCrankPosition()
	local crankChange = playdate.getCrankChange()
	local actionPressed = playdate.buttonJustPressed(playdate.kButtonDown)
	local actionReleased = playdate.buttonJustReleased(playdate.kButtonDown)
	local actionHeld = playdate.buttonIsPressed(playdate.kButtonDown)

	-- Use elapsed time so movement is independent of frame rate.
	local currentTime = playdate.getCurrentTimeMilliseconds()
	local deltaTime = (currentTime - self.lastUpdateTime) / 1000
	self.lastUpdateTime = currentTime

	-- Weather exists even with artwork hidden, ready for future gameplay use.
	self.wind:update(deltaTime)
	local windSpeed = self.wind:getSpeed()
	if self.scene then
		self.scene:update(deltaTime, windSpeed)
	end

	self.rider:update(
		deltaTime,
		crankChange,
		actionPressed,
		actionReleased,
		actionHeld,
		self.pool
	)
	
	-- Respawn with fresh movement and action state after leaving the screen.
	if self.rider:isGameOver() then
		self.rider = Rider.new()
	end

	gfx.clear(gfx.kColorWhite)

	if self.scene then
		self.scene:drawBehindRider()

		if showPoolTrace then
			-- XOR keeps the debug curve visible over both light and dark art.
			gfx.setColor(gfx.kColorXOR)
			self.pool:draw()
		end
	else
		gfx.setColor(gfx.kColorBlack)
		self.pool:draw()
	end

	gfx.setColor(gfx.kColorBlack)
	self.rider:draw(self.pool, riderSpriteEnabled)

	if self.scene then
		self.scene:drawForeground()
	end

	-- Development readouts stay above every artwork layer.
	self.telemetry:draw(
		crankPosition,
		crankChange,
		self.rider:getSpeed(),
		self.rider:getTurnPower(),
		windSpeed
	)
end

return Game
