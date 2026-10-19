--!strict
-- Upgrades
-- Prices and timings for lab upgrades (benches and the gate lock) and the selling rate.
-- Numbers are provisional, to balance in playtests.
-- Container: ReplicatedStorage/Shared/Config

local Upgrades = {
	-- Every lab starts with this many benches unlocked
	BaseBenches = 4,
	-- Bolts to unlock each extra bench, in order: Bench5, Bench6, Bench7, Bench8
	BenchUnlockCosts = { 1000, 5000, 25000, 100000 },
	-- Selling a gadget gives back this share of what it cost on the conveyor
	SellRefund = 0.5,
	-- How long the gate stays locked at each gate level (level 0 = the start)
	GateLockSeconds = { 60, 75, 90, 120 },
	-- Bolts to reach gate level 1, 2 and 3
	GateUpgradeCosts = { 2000, 15000, 100000 },
	-- After the lock ends, the button recharges for this long before it can lock again
	GateCooldownSeconds = 30,
}

return Upgrades
