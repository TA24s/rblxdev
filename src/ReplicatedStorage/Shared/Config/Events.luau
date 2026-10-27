--!strict
-- Events
-- Timed events that every player in a server shares. Every few minutes EventService starts one at
-- random (never the same one twice in a row) and it runs for a couple of minutes. Each event
-- changes one thing: how fast and how rare the conveyor is, how often mutations roll, or how much
-- every gadget earns. Numbers are provisional, to balance in playtests.
-- Container: ReplicatedStorage/Shared/Config

export type Event = {
	Id: string,
	DisplayName: string,
	Icon: string,
	Description: string, -- one short line for the banner
	Color: Color3,
	SpawnSpeed: number?, -- conveyor gadgets arrive this many times as often
	RareBoost: number?, -- Rare and rarer gadgets turn up this many times as often
	MutationBoost: number?, -- mutation chances are multiplied by this
	IncomeMultiplier: number?, -- every gadget earns this many times as much
}

local Events = {
	FirstDelaySeconds = 180, -- the first event starts this long after the server opens
	GapSeconds = 480, -- time between one event ending and the next starting
	DurationSeconds = 120,
	List = {
		GadgetRush = {
			Id = "GadgetRush",
			DisplayName = "Gadget Rush",
			Icon = "🚀",
			Description = "Gadgets roll twice as fast, and rare ones are 3x as common!",
			Color = Color3.fromRGB(80, 220, 255),
			SpawnSpeed = 2,
			RareBoost = 3,
		},
		MutationStorm = {
			Id = "MutationStorm",
			DisplayName = "Mutation Storm",
			Icon = "🌩",
			Description = "Mutations are 4x as likely on the conveyor!",
			Color = Color3.fromRGB(255, 130, 220),
			MutationBoost = 4,
		},
		DoubleBolts = {
			Id = "DoubleBolts",
			DisplayName = "Double Bolts",
			Icon = "⚙",
			Description = "Every gadget earns 2x Bolts!",
			Color = Color3.fromRGB(255, 200, 40),
			IncomeMultiplier = 2,
		},
	} :: { [string]: Event },
	-- The rarities a Gadget Rush makes more common
	RareRarities = { Rare = true, Epic = true, Legendary = true, Mythic = true, Forbidden = true } :: { [string]: boolean },
}

return Events
