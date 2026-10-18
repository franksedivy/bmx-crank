local gfx <const> = playdate.graphics

local Telemetry = {}
Telemetry.__index = Telemetry

function Telemetry.new()
	return setmetatable({}, Telemetry)
end

-- Temporary readouts used while tuning the riding model.
function Telemetry:draw(crankPosition, crankChange, riderSpeed, turnPower)
	gfx.drawText("BMX Crank", 160, 10)
	gfx.drawText("Crank to ride", 150, 30)

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
		"Turn power: " .. math.floor(turnPower * 100 + 0.5) .. "%",
		275,
		65
	)
end

return Telemetry
