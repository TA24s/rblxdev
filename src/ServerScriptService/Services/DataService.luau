--!strict
-- DataService
-- Loads each player's saved progress when they join, keeps it in memory while they play,
-- and saves it on a timer, when they leave, and when the server shuts down.
-- Bolts are only ever changed here, on the server. The client just displays them.
-- Saved: Bolts, and which gadget sits on each lab bench with the Bolts piled up on it.
-- Container: ServerScriptService/Services

----- Services -----
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

----- Constants -----
local STORE_NAME = "PlayerData_v1"
local STARTING_BOLTS = 100
local AUTOSAVE_INTERVAL = 120 -- seconds
local MAX_RETRIES = 3
local RETRY_DELAY = 2 -- seconds, multiplied by the attempt number

----- Types -----
export type BenchEntry = {
	GadgetId: string,
	Stored: number, -- Bolts earned on this bench and not collected yet
}

export type PlayerData = {
	DataVersion: number,
	Bolts: number,
	Benches: { [string]: BenchEntry }, -- keyed by BenchIndex as text ("1".."4"), as DataStores need text keys
}

type Session = {
	data: PlayerData,
	canSave: boolean, -- false when we couldn't load real data, so we never overwrite a save
}

----- Variables -----
local playerStore: DataStore? = nil
local sessions: { [Player]: Session } = {}
local activeSaves = 0 -- saves still talking to the DataStore; shutdown waits for these

local DataService = {}

----- Private Functions -----
local function defaultData(): PlayerData
	return {
		DataVersion = 2,
		Bolts = STARTING_BOLTS,
		Benches = {},
	}
end

-- Fills in any fields added since this save was made, so old saves keep working
local function reconcile(saved: any): PlayerData
	local data = defaultData()
	if typeof(saved) == "table" then
		if typeof(saved.Bolts) == "number" then
			data.Bolts = math.max(0, math.floor(saved.Bolts))
		end
		-- Version 1 saves had no benches; anything malformed is skipped rather than trusted
		if typeof(saved.Benches) == "table" then
			for key, entry in saved.Benches do
				if typeof(key) == "string" and typeof(entry) == "table" and typeof(entry.GadgetId) == "string" then
					local stored = if typeof(entry.Stored) == "number" then math.max(0, math.floor(entry.Stored)) else 0
					data.Benches[key] = { GadgetId = entry.GadgetId, Stored = stored }
				end
			end
		end
	end
	return data
end

local function deepCopy<T>(value: T): T
	if typeof(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value :: any do
		copy[k] = deepCopy(v)
	end
	return copy :: any
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

local function createLeaderstats(player: Player, bolts: number)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local value = Instance.new("IntValue")
	value.Name = "Bolts"
	value.Value = bolts
	value.Parent = leaderstats
	leaderstats.Parent = player
end

-- Returns (true, savedValueOrNil) on success, (false, errorMessage) after every retry fails
local function loadWithRetries(player: Player): (boolean, any)
	local store = playerStore
	if not store then
		return false, "DataStore unavailable"
	end
	local lastError: any = nil
	for attempt = 1, MAX_RETRIES do
		local ok, result = pcall(function()
			return store:GetAsync(keyFor(player))
		end)
		if ok then
			return true, result
		end
		lastError = result
		warn(`[DataService] Load attempt {attempt} for {player.Name} failed: {result}`)
		if attempt < MAX_RETRIES and player.Parent == Players then
			task.wait(RETRY_DELAY * attempt)
		end
	end
	return false, lastError
end

local function save(player: Player)
	local session = sessions[player]
	local store = playerStore
	if not (session and session.canSave and store) then
		return
	end
	local snapshot = deepCopy(session.data)
	activeSaves += 1
	for attempt = 1, MAX_RETRIES do
		local ok, err = pcall(function()
			store:UpdateAsync(keyFor(player), function(_old: any)
				return snapshot
			end)
		end)
		if ok then
			break
		end
		warn(`[DataService] Save attempt {attempt} for {player.Name} failed: {err}`)
		if attempt < MAX_RETRIES then
			task.wait(RETRY_DELAY * attempt)
		end
	end
	activeSaves -= 1
end

local function onPlayerAdded(player: Player)
	local ok, saved = loadWithRetries(player)
	if player.Parent ~= Players then
		return -- left while loading
	end

	local session: Session
	if ok then
		session = { data = reconcile(saved), canSave = true }
	elseif RunService:IsStudio() then
		-- Usually means Studio access to API services is off. Play on with fresh data,
		-- but never save it, so a real save can't be overwritten.
		warn("[DataService] Saving is OFF for this test: turn on Studio access to API services to test saving.")
		session = { data = defaultData(), canSave = false }
	else
		-- Never start a live player on default data: saving later would wipe their real progress
		player:Kick("Your progress couldn't be loaded. Please rejoin in a moment.")
		return
	end

	sessions[player] = session
	createLeaderstats(player, session.data.Bolts)
	player:SetAttribute("DataLoaded", true)
end

local function onPlayerRemoving(player: Player)
	save(player)
	sessions[player] = nil
end

----- Public Functions -----
-- The player's live data, for other server services to read and change (e.g. BenchService).
-- Nil until it has loaded, and after the player leaves.
function DataService.GetData(player: Player): PlayerData?
	local session = sessions[player]
	return session and session.data
end

function DataService.GetBolts(player: Player): number?
	local session = sessions[player]
	return session and session.data.Bolts
end

-- Adds Bolts (amount must be a positive whole number). Returns true if it worked.
function DataService.AddBolts(player: Player, amount: number): boolean
	local session = sessions[player]
	if not session or amount <= 0 or amount ~= math.floor(amount) then
		return false
	end
	session.data.Bolts += amount
	updateLeaderstats(player, session.data.Bolts)
	return true
end

-- Spends Bolts only if the player can afford it. Returns true if the Bolts were taken.
function DataService.SpendBolts(player: Player, amount: number): boolean
	local session = sessions[player]
	if not session or amount <= 0 or amount ~= math.floor(amount) then
		return false
	end
	if session.data.Bolts < amount then
		return false
	end
	session.data.Bolts -= amount
	updateLeaderstats(player, session.data.Bolts)
	return true
end

function DataService.Init()
	local ok, storeOrError = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		playerStore = storeOrError
	else
		warn(`[DataService] Couldn't open the DataStore: {storeOrError}`)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	-- Autosave so a crash never loses more than a couple of minutes
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for _, player in Players:GetPlayers() do
				task.spawn(save, player)
			end
		end
	end)

	-- When the server shuts down, save anyone still loaded and wait for every save to finish,
	-- including ones started by players leaving (the server would otherwise close mid-save)
	game:BindToClose(function()
		for player in sessions do
			task.spawn(save, player)
		end
		local deadline = os.clock() + 25
		while activeSaves > 0 and os.clock() < deadline do
			task.wait(0.25)
		end
	end)
end

return DataService
