--!strict
-- Shop
-- Everything sold for Robux, all as one-time game passes (see the design brief's monetisation
-- plan: convenience and looks only, nothing that helps you steal or stops others stealing).
-- A GamePassId of 0 means the pass hasn't been made on the Creator Hub yet: the shop shows it as
-- "Coming soon" and nobody can buy it. To put one on sale, create the game pass on the Creator
-- Hub, set its price there, and paste its ID here.
-- Container: ReplicatedStorage/Shared/Config

export type Pass = {
	Id: string,
	DisplayName: string,
	Icon: string,
	Description: string,
	GamePassId: number, -- 0 = not on sale yet
}

export type Look = {
	Color: Color3,
	Material: Enum.Material,
}

export type Theme = {
	Id: string,
	DisplayName: string,
	Icon: string,
	Description: string,
	GamePassId: number, -- 0 = not on sale yet
	Walls: Look,
	Floor: Look,
	Benches: Look, -- every bench except the Vault (Bench 1), which keeps its gold glow
}

local Shop = {
	LabAssistant = {
		Id = "LabAssistant",
		DisplayName = "Lab Assistant",
		Icon = "🤖",
		Description = "A little robot that collects the Bolts from all your benches for you.",
		GamePassId = 2074402573,
	} :: Pass,
	AssistantCollectSeconds = 10, -- how often the assistant empties your benches

	Themes = {
		VolcanoLair = {
			Id = "VolcanoLair",
			DisplayName = "Volcano Lair",
			Icon = "🌋",
			Description = "Reskin your lab with black rock walls and a glowing lava floor.",
			GamePassId = 2075962477,
			Walls = { Color = Color3.fromRGB(45, 35, 35), Material = Enum.Material.Basalt },
			Floor = { Color = Color3.fromRGB(255, 110, 30), Material = Enum.Material.CrackedLava },
			Benches = { Color = Color3.fromRGB(90, 60, 50), Material = Enum.Material.Slate },
		} :: Theme,
	} :: { [string]: Theme },

	-- Studio only: pretend every player owns every pass, to test them before they're on sale.
	-- Never has any effect in a live server.
	StudioOwnsAll = false,
}

return Shop
