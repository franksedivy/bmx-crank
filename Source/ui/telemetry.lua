local gfx <const> = playdate.graphics

local Telemetry = {}
Telemetry.__index = Telemetry

function Telemetry.new()
	return setmetatable({}, Telemetry)
end

-- Temporary readouts used while tuning the riding model.
function Telemetry:draw(crankPosition, crankChange, riderSpeed, turnPower, windSpeed)
	gfx.drawText(
		"Position: " .. math.floor(crankPosition) .. " deg",
		2,
		2
	)

	gfx.drawText(
		"Change: " .. string.format("%.1f", crankChange) .. "deg",
		2,
		22
	)

	gfx.drawText(
		"Speed: " .. string.format("%.1f", riderSpeed) .. "px/s",
		280,
		2
	)

	gfx.drawText(
		"Turn power: " .. math.floor(turnPower * 100 + 0.5) .. "%",
		270,
		22
	)

	local windDirection = windSpeed < -0.05 and "<"
		or windSpeed > 0.05 and ">"
		or "-"
	gfx.drawText(
		"Wind: " .. windDirection
			.. string.format("%.1f", math.abs(windSpeed)) .. "px/s",
		135,
		2
	)
end

return Telemetry
