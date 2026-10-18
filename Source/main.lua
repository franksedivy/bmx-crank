local Game = import "game"

local game <const> = Game.new()

-- Playdate calls this once per frame.
function playdate.update()
	game:update()
end
