--!strict
-- TrackingService
-- Logs playtest numbers to Roblox's analytics (Creator Hub > Analytics), so we can answer the
-- brief's "how we'll know it's fun" questions with data instead of guesses:
--   Onboarding funnel (new players only): Joined, First buy, First collect, 5 gadgets, First Rare,
--     First steal. Shows where new players stop.
--   Custom events: SecondsToFirstBuy and SecondsToFirstCollect (new players), GadgetBought,
--     StealStarted, StealDelivered, GotStolenFrom and Rebirth, with the gadget, rarity and mutation
--     as fields, so we can see the most-bought and most-stolen gadgets.
--   Economy events: where Bolts come from (bench income, selling, insurance) and go (gadgets, benches,
--     gate upgrades). Bench income is added up and sent once a minute so it doesn't flood the limit.
-- Roblox only records these in live servers. In Studio every event is printed to Output instead,
-- as "[Tracking] ...", so it can be checked in a playtest.
-- Container: ServerScriptService/Services

----- Services -----
local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

----- Modules -----
local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Gadgets = require(Config:WaitForChild("Gadgets"))
local Rarities = require(Config:WaitForChild("Rarities"))
local DataService = require(script.Parent:WaitForChild("DataService"))

----- Constants -----
local IN_STUDIO = RunService:IsStudio()
local CURRENCY = "Bolts"
local INCOME_FLUSH_SECONDS = 60
local DATA_WAIT_SECONDS = 30
local RARE_ORDER = 3 -- Rarities Order of "Rare"; this and above count as a first Rare
local FIELD_KEYS = {
	Enum.AnalyticsCustomFieldKeys.CustomField01.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField02.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField03.Name,
}
-- The onboarding funnel, in the order we expect new players to reach each step
local STEPS = { "Joined", "FirstBuy", "FirstCollect", "FiveGadgets", "FirstRare", "FirstSteal" }
local STEP_NUMBER: { [string]: number } = {}
for i, name in STEPS do
	STEP_NUMBER[name] = i
end

----- Types -----
type Session = {
	joinedAt: number,
	isNew: boolean, -- first time in the game (nothing ever discovered, never rebirthed)
	stepsDone: { [string]: boolean },
	pendingIncome: number, -- bench income collected since the last flush
}

----- Variables -----
local sessions: { [Player]: Session } = {}

local TrackingService = {}

----- Private Functions -----
local function debugPrint(text: string)
	if IN_STUDIO then
		print(`[Tracking] {text}`)
	end
end

-- { "SelfStirringSpoon", "Common" } -> { CustomField01 = "SelfStirringSpoon", CustomField02 = "Common" }
local function toFields(fields: { string }?): { [string]: string }?
	if not fields then
		return nil
	end
	local result = {}
	for i, value in fields do
		if FIELD_KEYS[i] then
			result[FIELD_KEYS[i]] = value
		end
	end
	return result
end

-- Analytics must never break gameplay, so every call is protected
local function safely(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if not ok then
		warn(`[TrackingService] {name} failed: {err}`)
	end
end

local function flushIncome(player: Player)
	local session = sessions[player]
	if not (session and session.pendingIncome > 0) then
		return
	end
	local amount = session.pendingIncome
	session.pendingIncome = 0
	TrackingService.Bolts(player, "Source", amount, "Gameplay", "BenchIncome")
end

local function onPlayerAdded(player: Player)
	local started = os.clock()
	while not player:GetAttribute("DataLoaded") and os.clock() - started < DATA_WAIT_SECONDS do
		task.wait(0.5)
		if not player.Parent then
			return
		end
	end
	local data = DataService.GetData(player)
	if not data then
		return
	end
	sessions[player] = {
		joinedAt = started,
		isNew = next(data.Discovered) == nil and data.Rebirths == 0,
		stepsDone = {},
		pendingIncome = 0,
	}
	TrackingService.Step(player, "Joined")
end

local function onPlayerRemoving(player: Player)
	flushIncome(player)
	sessions[player] = nil
end

----- Public Functions -----
-- Logs an onboarding funnel step (see STEPS) once, for a new player only. FirstBuy and
-- FirstCollect also log how many seconds after joining they happened.
function TrackingService.Step(player: Player, stepName: string)
	local session = sessions[player]
	local step = STEP_NUMBER[stepName]
	if not (session and session.isNew and step) or session.stepsDone[stepName] then
		return
	end
	session.stepsDone[stepName] = true
	debugPrint(`{player.Name} onboarding step {step} {stepName}`)
	safely("LogOnboardingFunnelStepEvent", function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, stepName)
	end)
	if stepName == "FirstBuy" or stepName == "FirstCollect" then
		TrackingService.Custom(player, `SecondsTo{stepName}`, math.floor(os.clock() - session.joinedAt))
	end
end

-- Logs a custom event with up to three text fields (for example gadget, rarity, mutation)
function TrackingService.Custom(player: Player, eventName: string, value: number?, fields: { string }?)
	debugPrint(`{player.Name} {eventName} = {value or 1}{if fields then " (" .. table.concat(fields, ", ") .. ")" else ""}`)
	safely("LogCustomEvent", function()
		AnalyticsService:LogCustomEvent(player, eventName, value or 1, toFields(fields))
	end)
end

-- Logs Bolts coming in ("Source") or going out ("Sink"). transactionType is an
-- Enum.AnalyticsEconomyTransactionType name, such as "Shop" or "Gameplay"; itemSku says what for.
function TrackingService.Bolts(player: Player, flow: "Source" | "Sink", amount: number, transactionType: string, itemSku: string)
	if amount <= 0 then
		return
	end
	local balance = DataService.GetBolts(player) or 0
	debugPrint(`{player.Name} Bolts {flow} {amount} for {itemSku} ({transactionType}), now {balance}`)
	safely("LogEconomyEvent", function()
		local flowType = if flow == "Source" then Enum.AnalyticsEconomyFlowType.Source else Enum.AnalyticsEconomyFlowType.Sink
		AnalyticsService:LogEconomyEvent(player, flowType, CURRENCY, amount, balance, transactionType, itemSku)
	end)
end

-- Bench income the player just collected; added up and sent once a minute
function TrackingService.Collected(player: Player, amount: number)
	local session = sessions[player]
	if session then
		session.pendingIncome += amount
	end
	TrackingService.Step(player, "FirstCollect")
end

-- A gadget was just put on one of the player's benches (bought or stolen): checks the
-- "5 gadgets" and "first Rare" funnel steps
function TrackingService.GadgetPlaced(player: Player, gadgetId: string)
	local data = DataService.GetData(player)
	if data then
		local count = 0
		for _ in data.Benches do
			count += 1
		end
		if count >= 5 then
			TrackingService.Step(player, "FiveGadgets")
		end
	end
	local gadget = Gadgets[gadgetId]
	local rarity = gadget and Rarities[gadget.Rarity]
	if rarity and rarity.Order >= RARE_ORDER then
		TrackingService.Step(player, "FirstRare")
	end
end

-- { gadgetId, rarity, mutation or "Plain" }, the usual fields for a gadget event
function TrackingService.GadgetFields(gadgetId: string, mutation: string?): { string }
	local gadget = Gadgets[gadgetId]
	return { gadgetId, if gadget then gadget.Rarity else "Unknown", mutation or "Plain" }
end

function TrackingService.Init()
	Players.PlayerAdded:Connect(function(player)
		onPlayerAdded(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	task.spawn(function()
		while true do
			task.wait(INCOME_FLUSH_SECONDS)
			for player in sessions do
				flushIncome(player)
			end
		end
	end)
end

return TrackingService
