--!strict
-- LeaderboardService
-- The global leaderboard: the top 10 players across every server, ranked by rebirths, with
-- Bolts breaking ties. Every minute it saves each player's score to an OrderedDataStore, reads the
-- top 10 back, shows them on the board in the plaza (Workspace.Decor.Leaderboard) and publishes
-- them for the 🏆 Top panel (ReplicatedStorage.Leaderboard, a JSON StringValue read by
-- LeaderboardController). A rebirth asks for an early update so it shows up quickly.
-- Container: ServerScriptService/Services

----- Services -----
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserService = game:GetService("UserService")

----- Modules -----
local DataService = require(script.Parent:WaitForChild("DataService"))

----- Constants -----
local STORE_NAME = "RebirthLeaderboard_v1"
local UPDATE_INTERVAL = 60 -- seconds between updates
local EARLY_UPDATE_GAP = 10 -- seconds; the soonest an early update (after a rebirth) can run
local TOP_COUNT = 10
-- Score = rebirths x BOLTS_SLOT + Bolts, so rebirths always count first. Bolts are capped so they
-- can't spill into the rebirths part (and the score stays a whole number a DataStore can hold).
local BOLTS_SLOT = 1e12

----- Types -----
export type Entry = {
	UserId: number,
	Name: string,
	Rebirths: number,
	Bolts: number,
}

----- Variables -----
local store = DataStoreService:GetOrderedDataStore(STORE_NAME)
local names: { [number]: string } = {} -- display names already looked up
local lastUpdate = 0
local earlyRequested = false
local published: StringValue? = nil

local LeaderboardService = {}

----- Private Functions -----
-- 1234567 -> "1,234,567"
local function formatNumber(n: number): string
	local text = tostring(math.floor(n))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

local function scoreFor(rebirths: number, bolts: number): number
	return rebirths * BOLTS_SLOT + math.clamp(math.floor(bolts), 0, BOLTS_SLOT - 1)
end

local function saveScores()
	for _, player in Players:GetPlayers() do
		local data = DataService.GetData(player)
		if data then
			names[player.UserId] = player.DisplayName
			local ok, err = pcall(function()
				store:SetAsync(tostring(player.UserId), scoreFor(data.Rebirths, data.Bolts))
			end)
			if not ok then
				warn(`[LeaderboardService] Couldn't save {player.Name}'s score: {err}`)
			end
		end
	end
end

-- Looks up display names for players who aren't in this server, in one request
local function fillNames(userIds: { number })
	local missing: { number } = {}
	for _, userId in userIds do
		if not names[userId] then
			table.insert(missing, userId)
		end
	end
	if #missing == 0 then
		return
	end
	local ok, infos = pcall(function()
		return UserService:GetUserInfosByUserIdsAsync(missing)
	end)
	if ok then
		for _, info in infos do
			names[info.Id] = info.DisplayName
		end
	end
end

local function readTop(): { Entry }?
	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, TOP_COUNT)
	end)
	if not ok then
		warn(`[LeaderboardService] Couldn't read the leaderboard: {pages}`)
		return nil
	end
	local rows = (pages :: DataStorePages):GetCurrentPage()
	local userIds: { number } = {}
	for _, row in rows do
		local userId = tonumber(row.key)
		if userId then
			table.insert(userIds, userId)
		end
	end
	fillNames(userIds)
	local entries: { Entry } = {}
	for _, row in rows do
		local userId = tonumber(row.key)
		if userId then
			local score = row.value :: number
			table.insert(entries, {
				UserId = userId,
				Name = names[userId] or `Player {userId}`,
				Rebirths = math.floor(score / BOLTS_SLOT),
				Bolts = score % BOLTS_SLOT,
			})
		end
	end
	return entries
end

-- Fills the rows of the board in the plaza
local function showOnBoard(entries: { Entry })
	local decor = workspace:FindFirstChild("Decor")
	local board = decor and decor:FindFirstChild("Leaderboard")
	local canvas = board and board:FindFirstChild("Canvas", true)
	if not canvas then
		return -- the board hasn't been built (tools/build-leaderboard.luau)
	end
	for i = 1, TOP_COUNT do
		local row = canvas:FindFirstChild(`Row{i}`)
		if not row then
			continue
		end
		local entry = entries[i]
		local avatar = row:FindFirstChild("Avatar") :: ImageLabel?
		local name = row:FindFirstChild("PlayerName") :: TextLabel?
		local rebirths = row:FindFirstChild("Rebirths") :: TextLabel?
		local bolts = row:FindFirstChild("Bolts") :: TextLabel?
		if avatar then
			avatar.Image = if entry then `rbxthumb://type=AvatarHeadShot&id={entry.UserId}&w=150&h=150` else ""
		end
		if name then
			name.Text = if entry then entry.Name else "—"
		end
		if rebirths then
			rebirths.Text = if entry then `♻ {formatNumber(entry.Rebirths)}` else ""
		end
		if bolts then
			bolts.Text = if entry then `⚙ {formatNumber(entry.Bolts)}` else ""
		end
	end
end

local function update()
	lastUpdate = os.clock()
	earlyRequested = false
	saveScores()
	local entries = readTop()
	if not entries then
		return
	end
	showOnBoard(entries)
	if published then
		published.Value = HttpService:JSONEncode(entries)
	end
end

----- Public Functions -----
-- Asks for an update soon (e.g. straight after a rebirth), without going over the DataStore limits
function LeaderboardService.RequestUpdate()
	earlyRequested = true
end

function LeaderboardService.Init()
	local value = ReplicatedStorage:FindFirstChild("Leaderboard")
	if not (value and value:IsA("StringValue")) then
		local newValue = Instance.new("StringValue")
		newValue.Name = "Leaderboard"
		newValue.Value = "[]"
		newValue.Parent = ReplicatedStorage
		value = newValue
	end
	published = value :: StringValue

	task.spawn(function()
		task.wait(5) -- give the first players' data a moment to load
		while true do
			update()
			repeat
				task.wait(1)
				local since = os.clock() - lastUpdate
			until since >= UPDATE_INTERVAL or (earlyRequested and since >= EARLY_UPDATE_GAP)
		end
	end)
end

return LeaderboardService
