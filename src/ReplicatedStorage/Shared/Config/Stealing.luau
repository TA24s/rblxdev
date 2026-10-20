--!strict
-- Stealing
-- Timings for stealing a gadget from another player's lab and carrying it home.
-- Numbers are provisional, to balance in playtests.
-- Container: ReplicatedStorage/Shared/Config

local Stealing = {
	-- Seconds to hold E on a gadget to grab it, by rarity (rarer takes longer, so the owner can react)
	HoldSeconds = {
		Common = 1,
		Uncommon = 1.5,
		Rare = 2,
		Epic = 2.5,
		Legendary = 3,
		Mythic = 3,
		Forbidden = 3,
	} :: { [string]: number },
	-- Seconds the thief has to reach their own lab's Receiving Dock before the gadget goes back
	CarrySeconds = 60,
	-- The thief's walk speed and jump height while carrying (normal is 16 and 7.2)
	CarryWalkSpeed = 12,
	CarryJumpHeight = 4,
}

return Stealing
