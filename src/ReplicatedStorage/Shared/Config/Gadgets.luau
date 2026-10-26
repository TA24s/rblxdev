--!strict
-- Gadgets
-- Every gadget in the game. To add one: build its model in ServerStorage/GadgetModels
-- (named exactly like its Id) and add a row here. Numbers are provisional, to balance in playtests.
-- Container: ReplicatedStorage/Shared/Config

export type Gadget = {
	Id: string, -- also the model's name in ServerStorage/GadgetModels
	DisplayName: string,
	Rarity: string, -- a key in Rarities
	Cost: number, -- Bolts to buy from the conveyor
	Income: number, -- Bolts per second while on a bench
}

local Gadgets: { [string]: Gadget } = {
	SelfStirringSpoon = { Id = "SelfStirringSpoon", DisplayName = "Self-Stirring Spoon", Rarity = "Common", Cost = 50, Income = 1 },
	SqueakyShoePhone = { Id = "SqueakyShoePhone", DisplayName = "Squeaky Shoe Phone", Rarity = "Common", Cost = 120, Income = 2 },
	ToasterCannon = { Id = "ToasterCannon", DisplayName = "Toaster Cannon", Rarity = "Uncommon", Cost = 500, Income = 6 },
	SockTeleporter = { Id = "SockTeleporter", DisplayName = "Sock Teleporter", Rarity = "Uncommon", Cost = 1200, Income = 12 },
	CatPoweredWifi = { Id = "CatPoweredWifi", DisplayName = "Cat-Powered Wi-Fi", Rarity = "Rare", Cost = 4000, Income = 30 },
	SelfSlappingAlarmClock = { Id = "SelfSlappingAlarmClock", DisplayName = "Self-Slapping Alarm Clock", Rarity = "Rare", Cost = 9000, Income = 60 },
	InflatableAnchor = { Id = "InflatableAnchor", DisplayName = "Inflatable Anchor", Rarity = "Epic", Cost = 25000, Income = 140 },
	WeatherRemote = { Id = "WeatherRemote", DisplayName = "Weather Remote", Rarity = "Epic", Cost = 60000, Income = 300 },
	PocketVolcano = { Id = "PocketVolcano", DisplayName = "Pocket Volcano", Rarity = "Legendary", Cost = 180000, Income = 800 },
	GravityToggle = { Id = "GravityToggle", DisplayName = "Gravity Toggle", Rarity = "Mythic", Cost = 600000, Income = 2400 },
	DoEverythingMachine = { Id = "DoEverythingMachine", DisplayName = "The Do-Everything Machine", Rarity = "Forbidden", Cost = 2500000, Income = 9000 },
}

return Gadgets
