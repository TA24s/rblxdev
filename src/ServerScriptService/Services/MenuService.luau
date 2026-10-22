--!strict
-- MenuService
-- The server side of the menu panels (MenuController on the client):
-- * Upgrades panel: buys More Benches, Better Gate or Income Boost. Benches and the gate go
--   through BenchService and GateService, the same as the prompts in the lab; Income Boost is
--   handled here. Every price is checked again on the server.
-- * Settings panel: saves the Music and SFX switches.
-- * Index panel: copies the gadget models into ReplicatedStorage.GadgetPreviews so the client can
--   show them (the real ones stay in ServerStorage for the conveyor).
-- Container: ServerScriptService/Services

----- Services -----
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

----- Modules -----
local Upgrades = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Upgrades"))
local BenchService = require(script.Parent:WaitForChild("BenchService"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local GateService = require(script.Parent:WaitForChild("GateService"))
local NotifyService = require(script.Parent:WaitForChild("NotifyService"))

----- Constants -----
local MIN_SECONDS_BETWEEN = 0.5 -- ignore repeated clicks
local SETTING_NAMES = { Music = true, Sfx = true }

----- Variables -----
local lastRequest: { [Player]: number } = {}

local MenuService = {}

----- Private Functions -----
-- 1234567 -> "1,234,567"
local function formatNumber(n: number): string
	local text = tostring(math.floor(n))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

local function tooSoon(player: Player): boolean
	local now = os.clock()
	if now - (lastRequest[player] or 0) < MIN_SECONDS_BETWEEN then
		return true
	end
	lastRequest[player] = now
	return false
end

local function buyIncomeBoost(player: Player)
	local data = DataService.GetData(player)
	if not data then
		return
	end
	local cost = Upgrades.IncomeBoostCosts[data.IncomeLevel + 1]
	if not cost then
		NotifyService.Send(player, "Your income boost is already maxed out.")
		return
	end
	if not DataService.SpendBolts(player, cost) then
		NotifyService.Send(player, `You need ⚙ {formatNumber(cost)} for the next income boost.`)
		return
	end
	data.IncomeLevel += 1
	DataService.SyncAttributes(player)
	local percent = math.floor(Upgrades.IncomeBoostPerLevel * data.IncomeLevel * 100 + 0.5)
	NotifyService.Send(player, `Income boosted! Your gadgets now earn +{percent}%.`, "good")
end

local function onUpgradeRequested(player: Player, kind: unknown)
	if tooSoon(player) or not BenchService.IsReady(player) then
		return
	end
	if kind == "Bench" then
		BenchService.UnlockNext(player)
	elseif kind == "Gate" then
		GateService.UpgradeFor(player)
	elseif kind == "Income" then
		buyIncomeBoost(player)
	end
end

local function onSettingChanged(player: Player, name: unknown, value: unknown)
	local data = DataService.GetData(player)
	if not (data and typeof(name) == "string" and SETTING_NAMES[name] and typeof(value) == "boolean") then
		return
	end
	(data.Settings :: any)[name] = value
	player:SetAttribute(`Setting{name}`, value)
end

local function getRemote(remotes: Instance, name: string): RemoteEvent
	local remote = remotes:FindFirstChild(name)
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end
	local newRemote = Instance.new("RemoteEvent")
	newRemote.Name = name
	newRemote.Parent = remotes
	return newRemote
end

----- Public Functions -----
function MenuService.Init()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	getRemote(remotes, "UpgradeRequest").OnServerEvent:Connect(onUpgradeRequested)
	getRemote(remotes, "SettingChanged").OnServerEvent:Connect(onSettingChanged)

	-- Plain copies of the gadget models for the Index, with no scripts, prompts or tags
	if not ReplicatedStorage:FindFirstChild("GadgetPreviews") then
		local previews = ServerStorage:WaitForChild("GadgetModels"):Clone()
		previews.Name = "GadgetPreviews"
		for _, descendant in previews:GetDescendants() do
			if descendant:IsA("BaseScript") or descendant:IsA("ProximityPrompt") then
				descendant:Destroy()
			else
				-- Untagged so GadgetAnimator leaves them alone (the Index spins them itself)
				for _, tag in descendant:GetTags() do
					descendant:RemoveTag(tag)
				end
			end
		end
		previews.Parent = ReplicatedStorage
	end

	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return MenuService
