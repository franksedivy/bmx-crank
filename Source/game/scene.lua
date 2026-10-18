local Clouds = import "game/clouds"
local gfx <const> = playdate.graphics

local Scene = {}
Scene.__index = Scene

-- Loads one exported layer. Only the main pool artwork is required for now.
local function loadLayer(path, required)
	-- pdc converts source PNGs into PDI files inside the game bundle.
	if not playdate.file.exists(path .. ".pdi") then
		assert(not required, "Missing scene layer: " .. path)
		return nil
	end

	local image, errorMessage = gfx.image.new(path)
	assert(image, "Cannot load scene layer: " .. path .. ": "
		.. tostring(errorMessage))

	local width, height = image:getSize()
	assert(width == 400 and height == 240,
		"Scene layers must be 400 x 240 pixels: " .. path)

	return image
end

-- Draws a full-screen layer at its shared origin if an export exists.
local function drawLayer(image)
	if image then
		image:draw(0, 0)
	end
end

-- Loads artwork once per game session rather than once per frame or respawn.
function Scene.new(cloudsEnabled)
	local scene = setmetatable({}, Scene)

	if cloudsEnabled then
		scene.clouds = Clouds.new()
	end
	scene.background = loadLayer("images/background", false)
	scene.pool = loadLayer("images/pool/middle", true)
	scene.foreground = loadLayer("images/pool/front", false)

	return scene
end

-- Keeps cloud motion running across rider turns, jumps and respawns.
function Scene:update(deltaTime, windSpeed)
	if self.clouds then
		self.clouds:update(deltaTime, windSpeed)
	end
end

-- Clouds sit behind the city silhouette; the main pool sits behind the rider.
function Scene:drawBehindRider()
	if self.clouds then
		self.clouds:draw()
	end
	drawLayer(self.background)
	drawLayer(self.pool)
end

-- The near edge of the pool can obscure the rider after it has been drawn.
function Scene:drawForeground()
	drawLayer(self.foreground)
end

return Scene
