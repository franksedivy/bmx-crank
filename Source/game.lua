import "CoreLibs/graphics"

local Pool = import "game/pool"
local Rider = import "game/rider"
local Telemetry = import "ui/telemetry"

local gfx <const> = playdate.graphics

local Game = {}
Game.__index = Game

function Game.new()
	local game = setmetatable({}, Game)

	game.pool = Pool.new()
	game.rider = Rider.new()
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

	self.telemetry:draw(
		crankPosition,
		crankChange,
		self.rider:getSpeed(),
		self.rider:getTurnPower()
	)

	self.pool:draw()
	self.rider:draw(self.pool)
end

return Game
