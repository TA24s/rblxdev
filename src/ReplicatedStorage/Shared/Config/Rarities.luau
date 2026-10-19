--!strict
-- Rarities
-- The rarity tiers, in order from most common to rarest. Shared so the server (conveyor odds)
-- and the client (label colours) read the same numbers.
-- Container: ReplicatedStorage/Shared/Config

export type Rarity = {
	Id: string,
	DisplayName: string,
	Order: number, -- 1 = most common
	Color: Color3,
	ConveyorWeight: number, -- relative chance of spawning on the conveyor (provisional)
}

local Rarities: { [string]: Rarity } = {
	Common = { Id = "Common", DisplayName = "Common", Order = 1, Color = Color3.fromRGB(190, 190, 195), ConveyorWeight = 55 },
	Uncommon = { Id = "Uncommon", DisplayName = "Uncommon", Order = 2, Color = Color3.fromRGB(90, 210, 90), ConveyorWeight = 25 },
	Rare = { Id = "Rare", DisplayName = "Rare", Order = 3, Color = Color3.fromRGB(70, 150, 255), ConveyorWeight = 12 },
	Epic = { Id = "Epic", DisplayName = "Epic", Order = 4, Color = Color3.fromRGB(170, 90, 240), ConveyorWeight = 5.5 },
	Legendary = { Id = "Legendary", DisplayName = "Legendary", Order = 5, Color = Color3.fromRGB(255, 190, 30), ConveyorWeight = 2 },
	Mythic = { Id = "Mythic", DisplayName = "Mythic", Order = 6, Color = Color3.fromRGB(255, 60, 60), ConveyorWeight = 0.45 },
	Forbidden = { Id = "Forbidden", DisplayName = "Forbidden", Order = 7, Color = Color3.fromRGB(255, 255, 255), ConveyorWeight = 0.05 },
}

return Rarities
