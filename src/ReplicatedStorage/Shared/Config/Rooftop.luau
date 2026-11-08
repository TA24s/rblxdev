--!strict
-- Rooftop
-- The Rooftop Lab, the second area (built by tools/build-rooftop-lab.luau): a tower on the west edge
-- of the arena with its own conveyor of Rare and rarer gadgets. Only players who have rebirthed at
-- least once can ride the lift up or buy from its conveyor. Numbers are provisional.
-- Container: ReplicatedStorage/Shared/Config

local CENTRE = Vector3.new(-115, 0, 0) -- must match the builder
local BELT_TOP_Y = 41.6 -- top of the roof belts (41.5) plus half the gadget's Base
local HALF = 10 -- the belt is a square CENTRE +- this

local Rooftop = {
	MinRebirths = 1,
	SpawnInterval = 4, -- seconds between new gadgets (the plaza's is 3)
	-- Only these rarities roll on the roof, using their usual ConveyorWeight between them
	Rarities = { Rare = true, Epic = true, Legendary = true, Mythic = true, Forbidden = true } :: { [string]: boolean },
	-- Corners of the roof belt in travel order, like the plaza's
	Path = {
		CENTRE + Vector3.new(-HALF, BELT_TOP_Y, -HALF),
		CENTRE + Vector3.new(HALF, BELT_TOP_Y, -HALF),
		CENTRE + Vector3.new(HALF, BELT_TOP_Y, HALF),
		CENTRE + Vector3.new(-HALF, BELT_TOP_Y, HALF),
		CENTRE + Vector3.new(-HALF, BELT_TOP_Y, -HALF),
	},
	RoofArrival = CENTRE + Vector3.new(18, 44, 0), -- where the lift drops you, between belt and rail
	GroundArrival = Vector3.new(-80, 4, 0), -- on the path, a few steps from the lift pad
}

return Rooftop
