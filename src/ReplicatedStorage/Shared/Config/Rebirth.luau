--!strict
-- Rebirth
-- Rebirth resets a player's Bolts, gadgets and extra benches, and in return every gadget they
-- own earns more, forever. Read by RebirthService (server) and RebirthController (the button).
-- Numbers are provisional, to balance in playtests.
-- Container: ReplicatedStorage/Shared/Config

local Rebirth = {
	-- Bolts needed for the first rebirth; each rebirth after that needs this much more
	-- (1st: 1,000,000, 2nd: 2,000,000, 3rd: 3,000,000 ...)
	BaseCost = 1000000,
	-- Extra income per rebirth: 0.5 means +50% each time (1 rebirth = x1.5, 2 = x2, 3 = x2.5 ...)
	IncomeBonus = 0.5,
}

-- Bolts needed for the next rebirth, for a player who has rebirthed `rebirths` times
function Rebirth.CostFor(rebirths: number): number
	return Rebirth.BaseCost * (rebirths + 1)
end

-- How much a player's gadgets earn compared with a player who never rebirthed
function Rebirth.MultiplierFor(rebirths: number): number
	return 1 + Rebirth.IncomeBonus * rebirths
end

return Rebirth
