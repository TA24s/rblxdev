--!strict
-- Stealing
-- Timings for stealing a gadget from another player's lab and carrying it home, the rules
-- that keep stealing fair, and the Boing Glove.
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

	-- Protection (Stage 10)
	-- New players can't be stolen from for their first 10 minutes of play (counted while online)
	ShieldSeconds = 600,
	-- After losing a gadget, a lab can't be stolen from for this long
	VictimCooldownSeconds = 90,
	-- The same thief can't steal from the same player again for this long
	RepeatTheftCooldownSeconds = 300,
	-- You can't steal from someone earning less than this share of your income per second
	PunchDownRatio = 0.2,
	-- The victim gets this share of the stolen gadget's cost back as insurance
	InsuranceShare = 0.25,

	-- Boing Glove
	GloveCooldownSeconds = 0.8,
	GloveRange = 7, -- studs in front of you
	KnockbackSpeed = 60, -- studs/s away from the hitter
	KnockbackUpSpeed = 35, -- studs/s upward
}

return Stealing
