--!strict
-- TipsService
-- Remembers how far each player has got through the new-player tips, so they don't repeat on
-- the next visit. TipsController (client) shows the tips and reports each one it finishes; the
-- server only accepts moving forward, one number at a time, up to the last tip.
-- The player's progress is copied to their "TipsDone" attribute so the client can read it.
-- Container: ServerScriptService/Services

----- Services -----
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

----- Modules -----
local DataService = require(script.Parent:WaitForChild("DataService"))

----- Constants -----
local TIP_COUNT = 5 -- must match the number of tips in TipsController
local MIN_SECONDS_BETWEEN = 0.2 -- ignore floods (the client checks every 0.25s)

----- Variables -----
local lastRequest: { [Player]: number } = {}

local TipsService = {}

----- Private Functions -----
local function onProgress(player: Player, done: any)
	local now = os.clock()
	if now - (lastRequest[player] or 0) < MIN_SECONDS_BETWEEN then
		return
	end
	lastRequest[player] = now
	local data = DataService.GetData(player)
	if not data or typeof(done) ~= "number" or done ~= math.floor(done) then
		return
	end
	-- Only forward, never past the last tip (skipping all tips sends TIP_COUNT)
	if done > data.TipsDone and done <= TIP_COUNT then
		data.TipsDone = done
		player:SetAttribute("TipsDone", done)
	end
end

local function waitForData(player: Player)
	while player.Parent == Players and not player:GetAttribute("DataLoaded") do
		task.wait(0.25)
	end
	local data = DataService.GetData(player)
	if data then
		player:SetAttribute("TipsDone", data.TipsDone)
	end
end

----- Public Functions -----
function TipsService.Init()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local remote = remotes:FindFirstChild("TipsProgress")
	if not (remote and remote:IsA("RemoteEvent")) then
		local newRemote = Instance.new("RemoteEvent")
		newRemote.Name = "TipsProgress"
		newRemote.Parent = remotes
		remote = newRemote
	end
	(remote :: RemoteEvent).OnServerEvent:Connect(onProgress)

	Players.PlayerAdded:Connect(waitForData)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(waitForData, player)
	end
end

return TipsService
