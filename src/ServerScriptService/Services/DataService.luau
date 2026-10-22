--!strict
-- DataService
-- Loads each player's saved progress when they join, keeps it in memory while they play,
-- and saves it. Saving is done by ProfileStore (ServerStorage.ProfileStore, by loleris), which
-- autosaves, saves when the player leaves or the server shuts down, and session-locks each save
-- so two servers can never load the same player at once (that would let stolen gadgets be copied).
-- Bolts are only ever changed here, on the server. The client just displays them.
-- Saved: Bolts, which gadget sits on each lab bench with the Bolts piled up on it, how many
-- extra benches the player has unlocked, their gate lock level, new-player shield time left and
-- how far through the new-player tips they are, how many times they've rebirthed, their income
-- boost level, which gadgets they've found (the Index) and their Music and SFX settings.
-- Upgrade levels, found gadgets and settings are copied to player attributes so the menu panels
-- (MenuController) can show them; call SyncAttributes after changing any of them.
-- Saves made before ProfileStore (DataStore "PlayerData_v1") are copied in once, on first join,
-- and the old store is never written again, so it stays as a backup.
-- Container: ServerScriptService/Services

----- Services -----
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

----- Modules -----
local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Rebirth = require(Config:WaitForChild("Rebirth"))
local Upgrades = require(Config:WaitForChild("Upgrades"))
local Stealing = require(Config:WaitForChild("Stealing"))
local ProfileStore = require(ServerStorage:WaitForChild("ProfileStore") :: ModuleScript)

----- Constants -----
local STORE_NAME = "PlayerProfiles_v1"
local LEGACY_STORE_NAME = "PlayerData_v1" -- the old saves, read once and never written
local STARTING_BOLTS = 100
local AUTOSAVE_INTERVAL = 120 -- seconds
local MAX_RETRIES = 3
local RETRY_DELAY = 2 -- seconds, multiplied by the attempt number

----- Types -----
export type BenchEntry = {
	GadgetId: string,
	Stored: number, -- Bolts earned on this bench and not collected yet
}

export type Settings = {
	Music: boolean,
	Sfx: boolean,
}

export type PlayerData = {
	DataVersion: number,
	Bolts: number,
	Benches: { [string]: BenchEntry }, -- keyed by BenchIndex as text ("1".."8"), as DataStores need text keys
	ExtraBenches: number, -- benches unlocked beyond the first 4 (0 to 4)
	GateLevel: number, -- gate lock upgrades bought (0 to 3)
	ShieldSeconds: number, -- new-player shield time left; nobody can steal from you while it's above 0
	TipsDone: number, -- how many new-player tips have been finished (TipsService)
	Rebirths: number, -- how many times the player has rebirthed (RebirthService)
	IncomeLevel: number, -- income boost upgrades bought (0 to 3)
	Discovered: { [string]: boolean }, -- GadgetIds the player has ever had on a bench (the Index)
	Settings: Settings,
	LegacyChecked: boolean, -- true once the old PlayerData_v1 save has been copied in (or there was none)
}

----- Variables -----
-- What a brand-new player starts with (also ProfileStore's template)
local function defaultData(): PlayerData
	return {
		DataVersion = 9,
		Bolts = STARTING_BOLTS,
		Benches = {},
		ExtraBenches = 0,
		GateLevel = 0,
		ShieldSeconds = Stealing.ShieldSeconds,
		TipsDone = 0,
		Rebirths = 0,
		IncomeLevel = 0,
		Discovered = {},
		Settings = { Music = true, Sfx = true },
		LegacyChecked = false,
	}
end

local playerStore = ProfileStore.New(STORE_NAME, defaultData())
type Profile = typeof(assert(playerStore:StartSessionAsync("")))
local profiles: { [Player]: Profile } = {}

local DataService = {}

----- Private Functions -----
-- Fills in any fields added since this save was made, so old saves keep working
local function reconcile(saved: any): PlayerData
	local data = defaultData()
	if typeof(saved) == "table" then
		if typeof(saved.Bolts) == "number" then
			data.Bolts = math.max(0, math.floor(saved.Bolts))
		end
		if typeof(saved.ExtraBenches) == "number" then
			data.ExtraBenches = math.clamp(math.floor(saved.ExtraBenches), 0, 4)
		end
		if typeof(saved.GateLevel) == "number" then
			data.GateLevel = math.clamp(math.floor(saved.GateLevel), 0, 3)
		end
		if typeof(saved.TipsDone) == "number" then
			data.TipsDone = math.clamp(math.floor(saved.TipsDone), 0, 100)
		end
		if typeof(saved.Rebirths) == "number" then
			data.Rebirths = math.max(0, math.floor(saved.Rebirths))
		end
		if typeof(saved.IncomeLevel) == "number" then
			data.IncomeLevel = math.clamp(math.floor(saved.IncomeLevel), 0, #Upgrades.IncomeBoostCosts)
		end
		if typeof(saved.Discovered) == "table" then
			for gadgetId, found in saved.Discovered do
				if typeof(gadgetId) == "string" and found == true then
					data.Discovered[gadgetId] = true
				end
			end
		end
		if typeof(saved.Settings) == "table" then
			for name in data.Settings do
				local value = saved.Settings[name]
				if typeof(value) == "boolean" then
					(data.Settings :: any)[name] = value
				end
			end
		end
		if typeof(saved.ShieldSeconds) == "number" then
			data.ShieldSeconds = math.clamp(math.floor(saved.ShieldSeconds), 0, Stealing.ShieldSeconds)
		end
		-- Version 1 saves had no benches; anything malformed is skipped rather than trusted
		if typeof(saved.Benches) == "table" then
			for key, entry in saved.Benches do
				if typeof(key) == "string" and typeof(entry) == "table" and typeof(entry.GadgetId) == "string" then
					local stored = if typeof(entry.Stored) == "number" then math.max(0, math.floor(entry.Stored)) else 0
					data.Benches[key] = { GadgetId = entry.GadgetId, Stored = stored }
					data.Discovered[entry.GadgetId] = true -- saves from before the Index
				end
			end
		end
	end
	return data
end

-- Puts `source`'s fields into `target`, keeping `target` the same table
local function replaceContents(target: { [any]: any }, source: { [any]: any })
	for key in target do
		target[key] = nil
	end
	for key, value in source do
		target[key] = value
	end
end

local function keyFor(player: Player): string
	return `Player_{player.UserId}`
end

-- Shows the player's Bolts in the player list and lets the HUD read it
local function updateLeaderstats(player: Player, bolts: number)
	local leaderstats = player:FindFirstChild("leaderstats")
	local value = leaderstats and leaderstats:FindFirstChild("Bolts")
	if value and value:IsA("IntValue") then
		value.Value = bolts
	end
end

local function updateRebirthsStat(player: Player, rebirths: number)
	local leaderstats = player:FindFirstChild("leaderstats")
	local value = leaderstats and leaderstats:FindFirstChild("Rebirths")
	if value and value:IsA("IntValue") then
		value.Value = rebirths
	end
end

local function createLeaderstats(player: Player, bolts: number, rebirths: number)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local value = Instance.new("IntValue")
	value.Name = "Bolts"
	value.Value = bolts
	value.Parent = leaderstats
	-- Bolts per second from benches; BenchService keeps it up to date
	local income = Instance.new("IntValue")
	income.Name = "Income"
	income.Parent = leaderstats
	local rebirthsValue = Instance.new("IntValue")
	rebirthsValue.Name = "Rebirths"
	rebirthsValue.Value = rebirths
	rebirthsValue.Parent = leaderstats
	leaderstats.Parent = player
end

-- Reads the player's pre-ProfileStore save. Returns (true, savedValueOrNil) on success,
-- (false, errorMessage) after every retry fails.
local function loadLegacy(player: Player): (boolean, any)
	local lastError: any = nil
	for attempt = 1, MAX_RETRIES do
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore(LEGACY_STORE_NAME):GetAsync(keyFor(player))
		end)
		if ok then
			return true, result
		end
		lastError = result
		warn(`[DataService] Old-save read {attempt} for {player.Name} failed: {result}`)
		if attempt < MAX_RETRIES and player.Parent == Players then
			task.wait(RETRY_DELAY * attempt)
		end
	end
	return false, lastError
end

local function onPlayerAdded(player: Player)
	local profile = playerStore:StartSessionAsync(keyFor(player), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if profile == nil then
		if player.Parent == Players then
			player:Kick("Your progress couldn't be loaded. Please rejoin in a moment.")
		end
		return
	end
	local data = profile.Data :: PlayerData

	-- First join since the switch to ProfileStore: copy the old save in
	if data.LegacyChecked ~= true then
		local ok, legacy = loadLegacy(player)
		if not ok then
			-- Don't mark it checked, so the copy is tried again next time
			profile:EndSession()
			if player.Parent == Players then
				player:Kick("Your progress couldn't be loaded. Please rejoin in a moment.")
			end
			return
		end
		if legacy ~= nil then
			replaceContents(data, reconcile(legacy))
			print(`[DataService] Copied {player.Name}'s old save into ProfileStore`)
		end
		data.LegacyChecked = true
	end
	-- Clean up anything malformed, the same way old saves are checked
	local checked = reconcile(data)
	checked.LegacyChecked = true
	replaceContents(data, checked)

	profile:AddUserId(player.UserId)
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		if player.Parent == Players then
			player:Kick("Your game was opened on another server. Please rejoin.")
		end
	end)
	if player.Parent ~= Players then
		profile:EndSession() -- left while loading
		return
	end

	profiles[player] = profile
	createLeaderstats(player, data.Bolts, data.Rebirths)
	DataService.SyncAttributes(player)
	player:SetAttribute("DataLoaded", true)
	if ProfileStore.DataStoreState ~= "Access" then
		warn("[DataService] Saving is OFF for this test: turn on Studio access to API services to test saving.")
	end
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	profiles[player] = nil
	if profile then
		profile:EndSession() -- saves one last time and releases the session lock
	end
end

----- Public Functions -----
-- The player's live data, for other server services to read and change (e.g. BenchService).
-- Nil until it has loaded, and after the player leaves.
function DataService.GetData(player: Player): PlayerData?
	local profile = profiles[player]
	return if profile then profile.Data :: PlayerData else nil
end

function DataService.GetBolts(player: Player): number?
	local data = DataService.GetData(player)
	return data and data.Bolts
end

-- Saves the player's data soon, without waiting for the next auto-save (e.g. after a theft, so
-- a server crash can't leave the gadget on both players' benches)
function DataService.SaveNow(player: Player)
	local profile = profiles[player]
	if profile and profile:IsActive() then
		profile:Save()
	end
end

-- How much the player's gadgets earn: the rebirth boost times the income boost upgrade
-- (1 for a new player)
function DataService.GetIncomeMultiplier(player: Player): number
	local data = DataService.GetData(player)
	if not data then
		return 1
	end
	return Rebirth.MultiplierFor(data.Rebirths) * (1 + Upgrades.IncomeBoostPerLevel * data.IncomeLevel)
end

-- Copies upgrade levels, found gadgets and settings to player attributes for the menu panels
function DataService.SyncAttributes(player: Player)
	local data = DataService.GetData(player)
	if not data then
		return
	end
	player:SetAttribute("ExtraBenches", data.ExtraBenches)
	player:SetAttribute("GateLevel", data.GateLevel)
	player:SetAttribute("IncomeLevel", data.IncomeLevel)
	player:SetAttribute("SettingMusic", data.Settings.Music)
	player:SetAttribute("SettingSfx", data.Settings.Sfx)
	for gadgetId in data.Discovered do
		player:SetAttribute(`Found_{gadgetId}`, true)
	end
end

-- Records that the player has had this gadget (for the Index)
function DataService.MarkDiscovered(player: Player, gadgetId: string)
	local data = DataService.GetData(player)
	if data and not data.Discovered[gadgetId] then
		data.Discovered[gadgetId] = true
		player:SetAttribute(`Found_{gadgetId}`, true)
	end
end

-- Rebirth: Bolts back to the starting amount, no gadgets, no extra benches, one more rebirth.
-- Everything else (gate level, income boost, found gadgets, shield, tips, settings) is kept. RebirthService checks the cost first;
-- BenchService.ReloadLab clears the gadgets off the benches afterwards.
function DataService.ResetForRebirth(player: Player): boolean
	local data = DataService.GetData(player)
	if not data then
		return false
	end
	data.Bolts = STARTING_BOLTS
	data.Benches = {}
	data.ExtraBenches = 0
	data.Rebirths += 1
	updateLeaderstats(player, data.Bolts)
	updateRebirthsStat(player, data.Rebirths)
	DataService.SyncAttributes(player)
	return true
end

-- Adds Bolts (amount must be a positive whole number). Returns true if it worked.
function DataService.AddBolts(player: Player, amount: number): boolean
	local data = DataService.GetData(player)
	if not data or amount <= 0 or amount ~= math.floor(amount) then
		return false
	end
	data.Bolts += amount
	updateLeaderstats(player, data.Bolts)
	return true
end

-- Spends Bolts only if the player can afford it. Returns true if the Bolts were taken.
function DataService.SpendBolts(player: Player, amount: number): boolean
	local data = DataService.GetData(player)
	if not data or amount <= 0 or amount ~= math.floor(amount) then
		return false
	end
	if data.Bolts < amount then
		return false
	end
	data.Bolts -= amount
	updateLeaderstats(player, data.Bolts)
	return true
end

function DataService.Init()
	-- ProfileStore autosaves every 300s by default; save more often so a crash loses less
	ProfileStore.SetConstant("AUTO_SAVE_PERIOD", AUTOSAVE_INTERVAL)
	-- ProfileStore saves everyone and waits when the server shuts down, so there's no BindToClose here
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return DataService
