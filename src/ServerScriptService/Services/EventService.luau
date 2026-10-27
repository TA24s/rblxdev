--!strict
-- EventService
-- Runs the timed events (Config/Events) for the whole server: waits, starts a random event, tells
-- everyone, ends it after its duration, and repeats. Other services ask it what the current event
-- changes (conveyor speed and odds, mutation chances, income). The current event and the timings
-- are shown to clients as attributes on ReplicatedStorage, read by EventController:
--   EventId (text, "" when none), EventEndsAt and NextEventAt (workspace:GetServerTimeNow() times).
-- Container: ServerScriptService/Services

----- Services -----
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

----- Modules -----
local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Events = require(Config:WaitForChild("Events"))
local NotifyService = require(script.Parent:WaitForChild("NotifyService"))

----- Variables -----
local current: Events.Event? = nil
local lastId: string? = nil
local rng = Random.new()

local EventService = {}

----- Private Functions -----
local function announce(text: string, sound: string?)
	for _, player in Players:GetPlayers() do
		NotifyService.Send(player, text, sound)
	end
end

-- A random event Id, never the same as the last one
local function pickEvent(): string
	local ids: { string } = {}
	for id in Events.List do
		if id ~= lastId then
			table.insert(ids, id)
		end
	end
	table.sort(ids) -- the same order every time, so the roll is the only randomness
	return ids[rng:NextInteger(1, #ids)]
end

local function startEvent(id: string)
	local event = Events.List[id]
	if not event then
		return
	end
	current = event
	lastId = id
	ReplicatedStorage:SetAttribute("EventId", id)
	ReplicatedStorage:SetAttribute("EventEndsAt", workspace:GetServerTimeNow() + Events.DurationSeconds)
	ReplicatedStorage:SetAttribute("NextEventAt", 0)
	announce(`{event.Icon} {event.DisplayName}! {event.Description}`, "good")
end

local function endEvent()
	local event = current
	current = nil
	ReplicatedStorage:SetAttribute("EventId", "")
	ReplicatedStorage:SetAttribute("EventEndsAt", 0)
	if event then
		announce(`The {event.DisplayName} is over. Another event soon!`)
	end
end

----- Public Functions -----
-- The event running now, or nil
function EventService.GetCurrent(): Events.Event?
	return current
end

-- How many times as often the conveyor spawns gadgets (1 normally)
function EventService.SpawnSpeed(): number
	return if current and current.SpawnSpeed then current.SpawnSpeed else 1
end

-- How many times as common Rare and rarer gadgets are on the conveyor (1 normally)
function EventService.RareBoost(): number
	return if current and current.RareBoost then current.RareBoost else 1
end

-- What mutation chances are multiplied by (1 normally)
function EventService.MutationBoost(): number
	return if current and current.MutationBoost then current.MutationBoost else 1
end

-- What every gadget's income is multiplied by (1 normally)
function EventService.IncomeMultiplier(): number
	return if current and current.IncomeMultiplier then current.IncomeMultiplier else 1
end

function EventService.Init()
	ReplicatedStorage:SetAttribute("EventId", "")
	ReplicatedStorage:SetAttribute("EventEndsAt", 0)
	task.spawn(function()
		local waitSeconds = Events.FirstDelaySeconds
		while true do
			ReplicatedStorage:SetAttribute("NextEventAt", workspace:GetServerTimeNow() + waitSeconds)
			task.wait(waitSeconds)
			startEvent(pickEvent())
			task.wait(Events.DurationSeconds)
			endEvent()
			waitSeconds = Events.GapSeconds
		end
	end)
end

return EventService
