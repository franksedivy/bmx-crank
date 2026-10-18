local gfx <const> = playdate.graphics

-- Both depths follow the shared wind, with smaller motion farther away.
-- Y is the top of each cloud; keep it below telemetry and above the skyline.
local settings <const> = {
	screenWidth = 400,
	layers = {
		{
			name = "far",
			count = 2,
			scale = 0.6,
			windMultiplier = 0.35,
			minimumY = 45,
			maximumY = 80,
			minimumGap = 35,
			maximumGap = 100,
		},
		{
			name = "near",
			count = 2,
			scale = 1,
			windMultiplier = 1,
			minimumY = 65,
			maximumY = 110,
			minimumGap = 50,
			maximumGap = 140,
		},
	},
}

local imagePaths <const> = {
	"images/clouds/cloud-a",
	"images/clouds/cloud-b",
	"images/clouds/cloud-c",
	"images/clouds/cloud-d",
	"images/clouds/cloud-e",
	"images/clouds/cloud-f",
}

local Clouds = {}
Clouds.__index = Clouds

-- Picks fresh properties without allocating another cloud or loading an image.
local function randomizeCloud(cloud, layer)
	local config = layer.settings
	local variant = layer.images[math.random(1, #layer.images)]
	cloud.image = variant.image
	cloud.width = variant.width
	cloud.y = math.random(config.minimumY, config.maximumY)
	-- Slight variation keeps clouds from travelling in a perfectly rigid group.
	cloud.speedMultiplier = 0.85 + math.random() * 0.3
	cloud.flip = math.random(1, 2) == 1
		and gfx.kImageUnflipped
		or gfx.kImageFlippedX
end

-- Re-enters from the upwind edge, preserving spacing in either wind direction.
local function recycleCloud(cloud, layer, direction)
	local config = layer.settings
	local gap = math.random(config.minimumGap, config.maximumGap)
	local entryEdge = direction > 0 and 0 or settings.screenWidth

	for _, other in ipairs(layer.clouds) do
		if other ~= cloud then
			if direction > 0 then
				entryEdge = math.min(entryEdge, other.x)
			else
				entryEdge = math.max(entryEdge, other.x + other.width)
			end
		end
	end

	randomizeCloud(cloud, layer)
	cloud.x = direction > 0
		and entryEdge - gap - cloud.width
		or entryEdge + gap
end

-- Loads and scales the reusable cloud images once for each depth.
function Clouds.new()
	local renderer = setmetatable({ layers = {} }, Clouds)
	local originals = {}
	for _, path in ipairs(imagePaths) do
		local image, errorMessage = gfx.image.new(path)
		assert(image, "Cannot load cloud: " .. path .. ": "
			.. tostring(errorMessage))
		originals[#originals + 1] = image
	end

	for _, config in ipairs(settings.layers) do
		local layer = { settings = config, images = {}, clouds = {} }
		for _, original in ipairs(originals) do
			local image = config.scale == 1
				and original
				or original:scaledImage(config.scale)
			local width = image:getSize()
			layer.images[#layer.images + 1] = { image = image, width = width }
		end

		-- Spread initial clouds across the sky so the first frame is populated.
		local spacing = settings.screenWidth / math.max(config.count, 1)
		for index = 1, config.count do
			local cloud = {}
			randomizeCloud(cloud, layer)
			cloud.x = (index - 1) * spacing
				+ math.random(0, math.floor(spacing / 3))
			layer.clouds[index] = cloud
		end
		renderer.layers[#renderer.layers + 1] = layer
	end

	return renderer
end

-- Advances wind-driven motion independently of rider speed and frame rate.
function Clouds:update(deltaTime, windSpeed)
	for _, layer in ipairs(self.layers) do
		for _, cloud in ipairs(layer.clouds) do
			local speed = windSpeed * layer.settings.windMultiplier
				* cloud.speedMultiplier
			cloud.x = cloud.x + speed * deltaTime
			if speed < 0 and cloud.x + cloud.width < 0 then
				recycleCloud(cloud, layer, -1)
			elseif speed > 0 and cloud.x > settings.screenWidth then
				recycleCloud(cloud, layer, 1)
			end
		end
	end
end

-- Far clouds draw first; rounded coordinates keep image placement pixel-aligned.
function Clouds:draw()
	for _, layer in ipairs(self.layers) do
		for _, cloud in ipairs(layer.clouds) do
			cloud.image:draw(math.floor(cloud.x + 0.5), cloud.y, cloud.flip)
		end
	end
end

return Clouds
