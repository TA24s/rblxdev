--!strict
-- RebirthService
-- Rebirth: once a player has enough Bolts, they can start their lab over. They lose their Bolts,
-- gadgets and extra benches, and every gadget they own from then on earns more (see
-- Config/Rebirth). Their gate upgrades are kept. RebirthController (client) shows the button and
-- asks here; the server checks everything again before doing it.
-- Container: ServerScriptService/Services

----- Services -----
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

----- Modules -----
local Rebirth = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Rebirth"))
local BenchService = require(script.Parent:WaitForChild("BenchService"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local NotifyService = require(script.Parent:WaitForChild("NotifyService"))
local StealService = require(script.Parent:WaitForChild("StealService"))

----- Constants -----
local MIN_SECONDS_BETWEEN = 2 -- ignore repeated clicks

----- Variables -----
local lastRequest: { [Player]: number } = {}

local RebirthService = {}

----- Private Functions -----
-- 1234567 -> "1,234,567"
local function formatNumber(n: number): string
	local text = tostring(math.floor(n))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

local function onRebirthRequested(player: Player)
	local now = os.clock()
	if now - (lastRequest[player] or 0) < MIN_SECONDS_BETWEEN then
		return
	end
	lastRequest[player] = now
	local data = DataService.GetData(player)
	if not (data and BenchService.IsReady(player)) then
		return
	end
	local cost = Rebirth.CostFor(data.Rebirths)
	if data.Bolts < cost then
		NotifyService.Send(player, `You need ⚙ {formatNumber(cost)} to rebirth.`)
		return
	end
	-- A gadget in someone's hands would have nowhere to go back to, so wait for it to finish
	if StealService.IsCarrying(player) then
		NotifyService.Send(player, "Take your stolen gadget home before you rebirth!")
		return
	end
	if StealService.IsBeingRobbed(player) then
		NotifyService.Send(player, "Someone is stealing from you! Deal with them before you rebirth.")
		return
	end

	if not DataService.ResetForRebirth(player) then
		return
	end
	BenchService.ReloadLab(player)
	DataService.SaveNow(player)
	local multiplier = Rebirth.MultiplierFor(data.Rebirths)
	NotifyService.Send(player, `♻ Rebirth {data.Rebirths}! Your gadgets now earn x{multiplier}. Time to rebuild!`, "good")
	for _, other in Players:GetPlayers() do
		if other ~= player then
			NotifyService.Send(other, `♻ {player.DisplayName} just rebirthed! (Rebirth {data.Rebirths})`)
		end
	end
end

----- Public Functions -----
function RebirthService.Init()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local remote = remotes:FindFirstChild("RebirthRequest")
	if not (remote and remote:IsA("RemoteEvent")) then
		local newRemote = Instance.new("RemoteEvent")
		newRemote.Name = "RebirthRequest"
		newRemote.Parent = remotes
		remote = newRemote
	end
	(remote :: RemoteEvent).OnServerEvent:Connect(onRebirthRequested)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return RebirthService
