--!strict
-- ProtectionService
-- The rules that keep stealing fair:
--   New-player shield: nobody can steal from you for your first 10 minutes of play (it ends early
--   if you steal from someone yourself).
--   Victim cooldown: after losing a gadget, your lab is protected for 90 seconds.
--   Repeat-theft cooldown: the same thief can't rob the same player again for 5 minutes.
--   Punch-down rule: you can't steal from someone earning under 20% of what you earn.
--   Insurance: the victim gets 25% of the stolen gadget's cost back.
-- A label above each lab's gate shows when it's protected. StealService asks CanSteal before a
-- grab and reports thefts here.
-- Container: ServerScriptService/Services

----- Services -----
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

----- Modules -----
local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Gadgets = require(Config:WaitForChild("Gadgets"))
local Stealing = require(Config:WaitForChild("Stealing"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local LabService = require(script.Parent:WaitForChild("LabService"))
local NotifyService = require(script.Parent:WaitForChild("NotifyService"))

----- Constants -----
local TICK_SECONDS = 1
local LABEL_NAME = "ProtectionLabel"
local SHIELD_COLOR = Color3.fromRGB(120, 200, 255)

----- Variables -----
local labsFolder = workspace:WaitForChild("Map"):WaitForChild("Labs")
local victimCooldownEnds: { [Player]: number } = {} -- os.clock() time each victim's protection ends
-- thief UserId -> victim UserId -> os.clock() end. Kept by UserId and not cleared when players
-- leave, so leaving and rejoining doesn't reset it.
local repeatCooldownEnds: { [number]: { [number]: number } } = {}

local ProtectionService = {}

----- Private Functions -----
-- 95 -> "1:35"
local function formatTime(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

-- Bolts per second from every gadget on the player's benches, with their rebirth boost
local function incomeOf(player: Player): number
	local data = DataService.GetData(player)
	local total = 0
	if data then
		for _, entry in data.Benches do
			local gadget = Gadgets[entry.GadgetId]
			if gadget then
				total += gadget.Income
			end
		end
	end
	return total * DataService.GetIncomeMultiplier(player)
end

local function victimSecondsLeft(player: Player): number
	local ends = victimCooldownEnds[player]
	return if ends then math.max(0, ends - os.clock()) else 0
end

local function shieldSecondsLeft(player: Player): number
	local data = DataService.GetData(player)
	return if data then data.ShieldSeconds else 0
end

local function getLabel(lab: Model): TextLabel?
	local gate = lab:FindFirstChild("Gate")
	if not (gate and gate:IsA("BasePart")) then
		return nil
	end
	local gui = gate:FindFirstChild(LABEL_NAME)
	if not gui then
		local newGui = Instance.new("BillboardGui")
		newGui.Name = LABEL_NAME
		newGui.Size = UDim2.fromOffset(220, 36)
		newGui.StudsOffsetWorldSpace = Vector3.new(0, 4.5, 0)
		newGui.MaxDistance = 70
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = SHIELD_COLOR
		label.TextStrokeTransparency = 0.3
		label.Parent = newGui
		newGui.Parent = gate
		gui = newGui
	end
	local label = (gui :: Instance):FindFirstChild("Text")
	return if label and label:IsA("TextLabel") then label else nil
end

-- Shows the owner's protection above their gate, or nothing
local function refreshLabel(lab: Model, owner: Player?)
	local label = getLabel(lab)
	if not label then
		return
	end
	local shield = if owner then shieldSecondsLeft(owner) else 0
	local cooldown = if owner then victimSecondsLeft(owner) else 0
	if shield > 0 then
		label.Text = `🛡 New player shield {formatTime(shield)}`
	elseif cooldown > 0 then
		label.Text = `🛡 Protected {formatTime(cooldown)}`
	else
		label.Text = ""
	end
	local gui = label.Parent
	if gui and gui:IsA("BillboardGui") then
		gui.Enabled = label.Text ~= ""
	end
end

local function endShield(player: Player, message: string)
	local data = DataService.GetData(player)
	if data and data.ShieldSeconds > 0 then
		data.ShieldSeconds = 0
		NotifyService.Send(player, message)
	end
end

-- Forgets repeat-theft cooldowns that have run out
local function pruneCooldowns()
	local now = os.clock()
	for thiefId, victims in repeatCooldownEnds do
		for victimId, ends in victims do
			if ends <= now then
				victims[victimId] = nil
			end
		end
		if next(victims) == nil then
			repeatCooldownEnds[thiefId] = nil
		end
	end
end

-- Counts down every online player's shield, and updates the gate labels
local function updateEverySecond()
	for _, player in Players:GetPlayers() do
		local data = DataService.GetData(player)
		if data and data.ShieldSeconds > 0 then
			data.ShieldSeconds = math.max(0, data.ShieldSeconds - TICK_SECONDS)
			if data.ShieldSeconds == 0 then
				NotifyService.Send(player, "Your new-player shield has ended. Lock your gate to keep your gadgets safe!")
			end
		end
	end
	for _, lab in labsFolder:GetChildren() do
		if lab:IsA("Model") then
			local userId = lab:GetAttribute("OwnerUserId")
			local owner = if typeof(userId) == "number" and userId ~= 0 then Players:GetPlayerByUserId(userId) else nil
			refreshLabel(lab, owner)
		end
	end
end

----- Public Functions -----
-- Whether `thief` may steal from `owner` right now. If not, also returns the reason to show.
function ProtectionService.CanSteal(thief: Player, owner: Player): (boolean, string?)
	local shield = shieldSecondsLeft(owner)
	if shield > 0 then
		return false, `{owner.DisplayName} has a new-player shield for {formatTime(shield)}.`
	end
	local cooldown = victimSecondsLeft(owner)
	if cooldown > 0 then
		return false, `This lab was just robbed. It's protected for {formatTime(cooldown)}.`
	end
	local thiefCooldowns = repeatCooldownEnds[thief.UserId]
	local repeatEnds = thiefCooldowns and thiefCooldowns[owner.UserId]
	if repeatEnds and repeatEnds > os.clock() then
		return false, `You stole from {owner.DisplayName} recently. Try again in {formatTime(repeatEnds - os.clock())}.`
	end
	local thiefIncome = incomeOf(thief)
	if thiefIncome > 0 and incomeOf(owner) < thiefIncome * Stealing.PunchDownRatio then
		return false, `{owner.DisplayName} earns much less than you. Pick on someone your own size!`
	end
	return true, nil
end

-- True while the owner's lab is protected after a theft. StealService checks this again on
-- delivery, in case two thieves grabbed from the same lab at once.
function ProtectionService.IsVictimProtected(owner: Player): boolean
	return victimSecondsLeft(owner) > 0
end

-- Called when a grab starts: stealing while shielded ends your own shield
function ProtectionService.OnStealStarted(thief: Player)
	endShield(thief, "You started stealing, so your new-player shield has ended.")
end

-- Called when a theft is delivered: protects the victim, starts the repeat cooldown and pays
-- insurance. Returns the insurance paid, for StealService's message to the victim.
function ProtectionService.OnStolen(thief: Player, owner: Player, gadgetId: string): number
	local now = os.clock()
	victimCooldownEnds[owner] = now + Stealing.VictimCooldownSeconds
	local thiefCooldowns = repeatCooldownEnds[thief.UserId] or {}
	thiefCooldowns[owner.UserId] = now + Stealing.RepeatTheftCooldownSeconds
	repeatCooldownEnds[thief.UserId] = thiefCooldowns

	local gadget = Gadgets[gadgetId]
	local insurance = if gadget then math.floor(gadget.Cost * Stealing.InsuranceShare) else 0
	if insurance > 0 and not DataService.AddBolts(owner, insurance) then
		insurance = 0 -- the owner's data is gone (they left)
	end
	local lab = LabService.GetLab(owner)
	if lab then
		refreshLabel(lab, owner)
	end
	return insurance
end

function ProtectionService.Init()
	Players.PlayerRemoving:Connect(function(player)
		victimCooldownEnds[player] = nil
	end)
	task.spawn(function()
		local ticks = 0
		while true do
			task.wait(TICK_SECONDS)
			updateEverySecond()
			ticks += 1
			if ticks % 60 == 0 then
				pruneCooldowns()
			end
		end
	end)
end

return ProtectionService
