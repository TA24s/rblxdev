--!strict
-- GateService
-- The lock button inside each lab. The owner holds E on it to lock their gate (60s at first),
-- then it recharges (30s) before it can lock again. Holding F upgrades how long the lock lasts.
-- The lock time is stored on the lab as the attribute GateLockedUntil (server clock), so
-- GateController on each client can make the gate solid for everyone except the owner.
-- Container: ServerScriptService/Services

----- Services -----
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

----- Modules -----
local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Upgrades = require(Config:WaitForChild("Upgrades"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local NotifyService = require(script.Parent:WaitForChild("NotifyService"))

----- Constants -----
local REFRESH_INTERVAL = 0.5 -- seconds between countdown updates
local LOCK_HOLD_SECONDS = 0.3
local UPGRADE_HOLD_SECONDS = 1
local PROMPT_DISTANCE = 8
local READY_COLOR = Color3.fromRGB(80, 230, 120)
local LOCKED_COLOR = Color3.fromRGB(255, 70, 90)
local RECHARGE_COLOR = Color3.fromRGB(255, 170, 40)
local LABEL_NAME = "GateButtonLabel"

----- Types -----
type GateParts = {
	gate: BasePart,
	button: BasePart,
	label: TextLabel,
	lockPrompt: ProximityPrompt,
	upgradePrompt: ProximityPrompt,
	accent: Color3, -- the lab's colour, used for the locked gate
}

----- Variables -----
local labsFolder = workspace:WaitForChild("Map"):WaitForChild("Labs")
local gates: { [Model]: GateParts } = {}

local GateService = {}

----- Private Functions -----
-- 1234567 -> "1,234,567"
local function formatNumber(n: number): string
	local text = tostring(math.floor(n))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

local function now(): number
	return workspace:GetServerTimeNow()
end

local function lockedUntil(lab: Model): number
	local value = lab:GetAttribute("GateLockedUntil")
	return if typeof(value) == "number" then value else 0
end

local function ownerOf(lab: Model): Player?
	local userId = lab:GetAttribute("OwnerUserId")
	if typeof(userId) ~= "number" or userId == 0 then
		return nil
	end
	return Players:GetPlayerByUserId(userId)
end

local function lockSeconds(gateLevel: number): number
	return Upgrades.GateLockSeconds[gateLevel + 1]
end

-- Updates the gate's look, the button colour and text, and which prompts can be used
local function refresh(lab: Model)
	local parts = gates[lab]
	if not parts then
		return
	end
	local owner = ownerOf(lab)
	local data = owner and DataService.GetData(owner)
	local t = now()
	local lockEnd = lockedUntil(lab)
	local rechargeEnd = lockEnd + Upgrades.GateCooldownSeconds

	if t < lockEnd then
		parts.gate.Transparency = 0.35
		parts.gate.Material = Enum.Material.ForceField
		parts.gate.Color = parts.accent
		parts.button.Color = LOCKED_COLOR
		parts.label.Text = `🔒 Locked {math.ceil(lockEnd - t)}s`
		parts.lockPrompt.Enabled = false
	else
		parts.gate.Transparency = 1
		parts.gate.Material = Enum.Material.Plastic
		if t < rechargeEnd then
			parts.button.Color = RECHARGE_COLOR
			parts.label.Text = `Recharging {math.ceil(rechargeEnd - t)}s`
			parts.lockPrompt.Enabled = false
		else
			parts.button.Color = READY_COLOR
			parts.label.Text = "Lock ready"
			parts.lockPrompt.Enabled = data ~= nil
		end
	end

	if data then
		parts.lockPrompt.ActionText = `Lock gate ({lockSeconds(data.GateLevel)}s)`
		local cost = Upgrades.GateUpgradeCosts[data.GateLevel + 1]
		parts.upgradePrompt.Enabled = cost ~= nil
		if cost then
			parts.upgradePrompt.ActionText = `Upgrade to {lockSeconds(data.GateLevel + 1)}s for ⚙ {formatNumber(cost)}`
		end
	else
		parts.upgradePrompt.Enabled = false
	end
end

-- The lab's owner, if `player` is them; otherwise tells the player and returns nil
local function ownerData(player: Player, lab: Model): DataService.PlayerData?
	if lab:GetAttribute("OwnerUserId") ~= player.UserId then
		NotifyService.Send(player, "Only the owner of this lab can use its lock.")
		return nil
	end
	return DataService.GetData(player)
end

local function onLock(player: Player, lab: Model)
	local data = ownerData(player, lab)
	if not data then
		return
	end
	local t = now()
	if t < lockedUntil(lab) + Upgrades.GateCooldownSeconds then
		return -- still locked or recharging; the prompt is normally hidden then
	end
	local seconds = lockSeconds(data.GateLevel)
	lab:SetAttribute("GateLockedUntil", t + seconds)
	refresh(lab)
	NotifyService.Send(player, `Gate locked for {seconds} seconds!`)
end

local function onUpgrade(player: Player, lab: Model)
	local data = ownerData(player, lab)
	if not data then
		return
	end
	local cost = Upgrades.GateUpgradeCosts[data.GateLevel + 1]
	if not cost then
		return
	end
	if not DataService.SpendBolts(player, cost) then
		NotifyService.Send(player, `You need ⚙ {formatNumber(cost)} to upgrade your lock.`)
		return
	end
	data.GateLevel += 1
	refresh(lab)
	NotifyService.Send(player, `Lock upgraded! It now lasts {lockSeconds(data.GateLevel)} seconds.`)
end

local function createLabel(button: BasePart): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = LABEL_NAME
	gui.Size = UDim2.fromOffset(150, 34)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2, 0)
	gui.MaxDistance = 40
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = "Lock ready"
	label.Parent = gui
	gui.Parent = button
	return label
end

local function newPrompt(name: string, parent: BasePart, hold: number, key: Enum.KeyCode, gamepad: Enum.KeyCode): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ObjectText = "Gate lock"
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = key
	prompt.GamepadKeyCode = gamepad
	prompt.Enabled = false
	prompt.Parent = parent
	return prompt
end

local function setUpLab(lab: Model)
	local gate = lab:FindFirstChild("Gate")
	local buttonModel = lab:FindFirstChild("GateButton")
	local button = buttonModel and buttonModel:FindFirstChild("Button")
	if not (gate and gate:IsA("BasePart") and button and button:IsA("BasePart")) then
		warn(`[GateService] {lab.Name} has no Gate or GateButton.Button; lock not set up`)
		return
	end
	local walls = lab:FindFirstChild("Walls")
	local back = walls and walls:FindFirstChild("Back")

	-- Two prompts on one button: they use different keys so both show at once
	local lockPrompt = newPrompt("LockPrompt", button, LOCK_HOLD_SECONDS, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
	local upgradePrompt = newPrompt("UpgradePrompt", button, UPGRADE_HOLD_SECONDS, Enum.KeyCode.F, Enum.KeyCode.ButtonY)
	lockPrompt.Triggered:Connect(function(player)
		onLock(player, lab)
	end)
	upgradePrompt.Triggered:Connect(function(player)
		onUpgrade(player, lab)
	end)

	gates[lab] = {
		gate = gate,
		button = button,
		label = createLabel(button),
		lockPrompt = lockPrompt,
		upgradePrompt = upgradePrompt,
		accent = if back and back:IsA("BasePart") then back.Color else LOCKED_COLOR,
	}
	-- A new owner (or an empty lab) always starts unlocked
	lab:SetAttribute("GateLockedUntil", 0)
	lab:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
		lab:SetAttribute("GateLockedUntil", 0)
		refresh(lab)
	end)
	refresh(lab)
end

----- Public Functions -----
-- True while the lab's gate is locked (for stealing in Stage 9)
function GateService.IsLocked(lab: Model): boolean
	return now() < lockedUntil(lab)
end

function GateService.Init()
	for _, lab in labsFolder:GetChildren() do
		if lab:IsA("Model") then
			setUpLab(lab)
		end
	end
	task.spawn(function()
		while true do
			task.wait(REFRESH_INTERVAL)
			for lab in gates do
				refresh(lab)
			end
		end
	end)
end

return GateService
