--!strict
-- DataService
-- Loads each player's saved progress when they join, keeps it in memory while they play,
-- and saves it on a timer, when they leave, and when the server shuts down.
-- Bolts are only ever changed here, on the server. The client just displays them.
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
export type PlayerData = {
	DataVersion: number,
	Bolts: number,
}

type Session = {
	data: PlayerData,
	canSave: boolean, -- false when we couldn't load real data, so we never overwrite a save
}

----- Variables -----
local playerStore: DataStore? = nil
local sessions: { [Player]: Session } = {}

local DataService = {}

----- Private Functions -----
local function defaultData(): PlayerData
	return {
		DataVersion = 1,
		Bolts = STARTING_BOLTS,
	}
end

-- Fills in any fields added since this save was made, so old saves keep working
local function reconcile(saved: any): PlayerData
	local data = defaultData()
	if typeof(saved) == "table" then
		if typeof(saved.Bolts) == "number" then
			data.Bolts = math.max(0, math.floor(saved.Bolts))
		end
	end
	return data
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
	local snapshot = table.clone(session.data)
	for attempt = 1, MAX_RETRIES do
		local ok, err = pcall(function()
			store:UpdateAsync(keyFor(player), function(_old: any)
				return snapshot
			end)
		end)
		if ok then
			return
		end
		warn(`[DataService] Save attempt {attempt} for {player.Name} failed: {err}`)
		if attempt < MAX_RETRIES then
			task.wait(RETRY_DELAY * attempt)
		end
	end
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

	-- Save everyone when the server shuts down
	game:BindToClose(function()
		local pending = 0
		for _, player in Players:GetPlayers() do
			pending += 1
			task.spawn(function()
				save(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.5)
		end
	end)
end

return DataService
