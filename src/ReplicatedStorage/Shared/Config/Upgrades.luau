--!strict
-- Upgrades
-- Prices for lab upgrades and the selling rate. Numbers are provisional, to balance in playtests.
-- Container: ReplicatedStorage/Shared/Config

local Upgrades = {
	-- Every lab starts with this many benches unlocked
	BaseBenches = 4,
	-- Bolts to unlock each extra bench, in order: Bench5, Bench6, Bench7, Bench8
	BenchUnlockCosts = { 1000, 5000, 25000, 100000 },
	-- Selling a gadget gives back this share of what it cost on the conveyor
	SellRefund = 0.5,
}

return Upgrades
