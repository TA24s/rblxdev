--!strict
-- StealService
-- Stealing. In another player's lab (gate not locked), hold E on a gadget to grab it. A copy of it
-- rides over the thief's head while they walk slower; touching their own lab's Receiving Dock
-- within 60 seconds moves it onto one of their free benches. If time runs out, the thief dies or
-- resets, either player leaves, or the owner hits them with the Boing Glove, the gadget goes back.
-- ProtectionService decides whether a theft is allowed (shields, cooldowns, punch-down rule).
-- The gadget stays in the owner's data until the moment it's delivered, so it can't be duplicated.
-- Professor Grudge's Lab (GrudgeService) uses the same carry through StartNpcSteal: there's no
-- owner, no protection rules, and the gadget goes back to his bench if the carry fails.
-- Every steal prompt is checked here too: the player must have held it for (nearly) its full
-- hold time and be standing close to it, so a cheat can't grab gadgets instantly or from afar.
-- Container: ServerScriptService/Services

----- Services -----
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

----- Modules -----
local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Gadgets = require(Config:WaitForChild("Gadgets"))
local Stealing = require(Config:WaitForChild("Stealing"))
local BenchService = require(script.Parent:WaitForChild("BenchService"))
local GateService = require(script.Parent:WaitForChild("GateService"))
local LabService = require(script.Parent:WaitForChild("LabService"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local NotifyService = require(script.Parent:WaitForChild("NotifyService"))
local ProtectionService = require(script.Parent:WaitForChild("ProtectionService"))

----- Constants -----
local TIMER_INTERVAL = 0.25 -- seconds between countdown updates
local CARRY_NAME = "CarriedGadget"
local HOLD_SLACK = 0.3 -- seconds of hold time forgiven for network lag
local DISTANCE_SLACK = 6 -- studs past the prompt's range forgiven for lag and big characters
local HOLD_MAX_LATE = 2 -- seconds after a full hold that the trigger must arrive by

----- Types -----
-- Where an NPC steal came from: how to put the gadget back, and how to hand it over
export type NpcSource = {
	name: string, -- e.g. "Professor Grudge", for messages
	giveBack: () -> (),
	take: (thief: Player) -> boolean,
}

type Carry = {
	owner: Player?, -- nil for an NPC steal
	npc: NpcSource?,
	bench: BasePart,
	gadget: Gadgets.Gadget,
	deadline: number, -- os.clock() time the carry runs out
	visual: Model, -- the copy over the thief's head
	timerLabel: TextLabel,
	humanoid: Humanoid,
	oldWalkSpeed: number,
	oldJumpHeight: number,
	connections: { RBXScriptConnection },
}

----- Variables -----
local modelsFolder = ServerStorage:WaitForChild("GadgetModels")
local labsFolder = workspace:WaitForChild("Map"):WaitForChild("Labs")
local carries: { [Player]: Carry } = {} -- keyed by thief
local benchCarrier: { [BasePart]: Player } = {} -- which thief has each bench's gadget
-- Each player's latest prompt hold: when it began, and when they let go (if they did)
local holdStarts: { [Player]: { prompt: ProximityPrompt, time: number, endedAt: number? } } = {}

local StealService = {}

----- Private Functions -----
local function labOf(bench: BasePart): Instance?
	local folder = bench.Parent
	return folder and folder.Parent
end

-- A copy of the gadget, welded above the thief's head
local function buildVisual(gadget: Gadgets.Gadget, head: BasePart): (Model?, TextLabel?)
	local template = modelsFolder:FindFirstChild(gadget.Id)
	if not (template and template:IsA("Model")) then
		return nil, nil
	end
	local model = template:Clone()
	model.Name = CARRY_NAME
	-- The client animator moves tagged gadgets with PivotTo, which would fight the welds
	for _, tag in CollectionService:GetTags(model) do
		model:RemoveTag(tag)
	end
	local _, size = model:GetBoundingBox()
	model:PivotTo(head.CFrame * CFrame.new(0, head.Size.Y / 2 + size.Y / 2 + 0.75, 0))
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = head
			weld.Part1 = part
			weld.Parent = part
		end
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "CarryTimer"
	gui.Size = UDim2.fromOffset(120, 30)
	gui.StudsOffsetWorldSpace = Vector3.new(0, size.Y / 2 + 1.5, 0)
	gui.MaxDistance = 80
	gui.AlwaysOnTop = true
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 90, 110)
	label.TextStrokeTransparency = 0.3
	label.Text = `⏱ {Stealing.CarrySeconds}s`
	label.Parent = gui
	gui.Adornee = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	gui.Parent = model
	return model, label
end

-- Ends a carry. `delivered` means the gadget already moved to the thief; otherwise it goes home.
local function endCarry(thief: Player, delivered: boolean)
	local carry = carries[thief]
	if not carry then
		return
	end
	carries[thief] = nil
	benchCarrier[carry.bench] = nil
	for _, connection in carry.connections do
		connection:Disconnect()
	end
	carry.visual:Destroy()
	if carry.humanoid.Parent and carry.humanoid.Health > 0 then
		carry.humanoid.WalkSpeed = carry.oldWalkSpeed
		carry.humanoid.JumpHeight = carry.oldJumpHeight
	end
	if not delivered then
		if carry.npc then
			carry.npc.giveBack()
		elseif carry.owner then
			BenchService.SetCarried(carry.owner, carry.bench, false)
		end
	end
end

-- Sends the gadget back to its owner and tells both players why
local function cancelCarry(thief: Player, thiefMessage: string, ownerMessage: string?)
	local carry = carries[thief]
	if not carry then
		return
	end
	local owner = carry.owner
	endCarry(thief, false)
	if thiefMessage ~= "" and thief.Parent == Players then
		NotifyService.Send(thief, thiefMessage)
	end
	if ownerMessage and owner and owner.Parent == Players then
		NotifyService.Send(owner, ownerMessage, "good") -- every owner message here means the gadget came back
	end
end

-- True if some other thief is already carrying a gadget from this owner
local function isOwnerBeingRobbed(owner: Player): boolean
	for _, carry in carries do
		if carry.owner == owner then
			return true
		end
	end
	return false
end

local function deliverFromNpc(thief: Player, carry: Carry, npc: NpcSource)
	local name = carry.gadget.DisplayName
	local freeBench = BenchService.FindFreeBench(thief, true)
	if not freeBench then
		cancelCarry(thief, `No free bench at home, so the {name} went back to {npc.name}.`)
		return
	end
	if not npc.take(thief) then
		cancelCarry(thief, `The {name} went back to {npc.name}.`)
		return
	end
	endCarry(thief, true)
	if not BenchService.PlaceGadget(thief, freeBench, carry.gadget.Id) then
		warn(`[StealService] Couldn't place {carry.gadget.Id} from {npc.name} for {thief.Name}`)
		npc.giveBack()
		NotifyService.Send(thief, `Something went wrong, so the {name} went back.`)
		return
	end
	NotifyService.Send(thief, `You stole the {name} from {npc.name}! 🎉`, "good")
	DataService.SaveNow(thief)
end

local function deliver(thief: Player)
	local carry = carries[thief]
	if not carry then
		return
	end
	if carry.npc then
		deliverFromNpc(thief, carry, carry.npc)
		return
	end
	local owner = carry.owner :: Player
	local name = carry.gadget.DisplayName
	if ProtectionService.IsVictimProtected(owner) then
		-- Someone else robbed this lab first; it's protected now, so this gadget goes home
		cancelCarry(thief, `That lab was just robbed by someone else, so the {name} went back.`, `Your {name} came back!`)
		return
	end
	local freeBench = BenchService.FindFreeBench(thief, true)
	if not freeBench then
		cancelCarry(thief, `No free bench at home, so the {name} went back.`, `Your {name} came back!`)
		return
	end
	local bench = carry.bench
	local gadgetId = BenchService.TakeCarried(owner, bench)
	if not gadgetId then
		cancelCarry(thief, `The {name} went back to its owner.`)
		return
	end
	endCarry(thief, true)
	if not BenchService.PlaceGadget(thief, freeBench, gadgetId) then
		-- Shouldn't happen (a free bench was checked just above), but never let a gadget vanish
		warn(`[StealService] Couldn't place stolen {gadgetId} for {thief.Name}; returning it`)
		BenchService.PlaceGadget(owner, bench, gadgetId)
		NotifyService.Send(thief, `Something went wrong, so the {name} went back.`)
		return
	end
	NotifyService.Send(thief, `You stole the {name}! 🎉`, "good")
	local insurance = ProtectionService.OnStolen(thief, owner, gadgetId)
	DataService.SaveNow(thief)
	DataService.SaveNow(owner)
	if owner.Parent == Players then
		NotifyService.Send(owner, `{thief.DisplayName} stole your {name}! Insurance paid ⚙ {insurance}.`)
	end
end

-- True if the trigger looks real: the player held this prompt for (nearly) its full hold time and
-- is standing near it. Roblox runs the hold on the player's device, so the server checks it again.
local function isFairTrigger(player: Player, prompt: ProximityPrompt): boolean
	local hold = holdStarts[player]
	holdStarts[player] = nil
	if prompt.HoldDuration > 0 then
		-- The hold must be this prompt's, long enough, not let go early, and not an old one
		if not (hold and hold.prompt == prompt) then
			return false
		end
		local now = os.clock()
		local heldFor = (hold.endedAt or now) - hold.time
		if heldFor < prompt.HoldDuration - HOLD_SLACK or now - hold.time > prompt.HoldDuration + HOLD_MAX_LATE then
			return false
		end
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local part = prompt.Parent
	if not (root and root:IsA("BasePart") and part and part:IsA("BasePart")) then
		return false
	end
	return (root.Position - part.Position).Magnitude <= prompt.MaxActivationDistance + DISTANCE_SLACK
end

-- Puts the gadget over the thief's head and starts the countdown. Returns false if the thief's
-- character isn't ready. `owner` is nil for an NPC steal (then `npc` says where it goes back to).
local function beginCarry(thief: Player, owner: Player?, npc: NpcSource?, bench: BasePart, gadget: Gadgets.Gadget): boolean
	local character = thief.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local head = character and character:FindFirstChild("Head")
	if not (character and humanoid and humanoid.Health > 0 and head and head:IsA("BasePart")) then
		return false
	end
	local visual, timerLabel = buildVisual(gadget, head)
	if not (visual and timerLabel) then
		warn(`[StealService] No model for {gadget.Id}; steal cancelled`)
		return false
	end

	local carry: Carry = {
		owner = owner,
		npc = npc,
		bench = bench,
		gadget = gadget,
		deadline = os.clock() + Stealing.CarrySeconds,
		visual = visual,
		timerLabel = timerLabel,
		humanoid = humanoid,
		oldWalkSpeed = humanoid.WalkSpeed,
		oldJumpHeight = humanoid.JumpHeight,
		connections = {},
	}
	carries[thief] = carry
	benchCarrier[bench] = thief
	humanoid:UnequipTools() -- no Boing Glove while carrying
	humanoid.WalkSpeed = Stealing.CarryWalkSpeed
	humanoid.JumpHeight = Stealing.CarryJumpHeight
	visual.Parent = character

	local backMessage = if owner then `Your {gadget.DisplayName} came back!` else nil
	table.insert(carry.connections, humanoid.Died:Connect(function()
		cancelCarry(thief, `You dropped the {gadget.DisplayName}!`, backMessage)
	end))
	table.insert(carry.connections, thief.CharacterRemoving:Connect(function()
		cancelCarry(thief, `You dropped the {gadget.DisplayName}!`, backMessage)
	end))
	return true
end

local function onStealRequested(thief: Player, bench: BasePart)
	local owner = BenchService.GetBenchOwner(bench)
	local lab = labOf(bench)
	if not (owner and owner ~= thief and lab and lab:IsA("Model")) then
		return
	end
	if bench:GetAttribute("IsVault") == true then
		return -- the Vault can never be stolen from
	end
	local prompt = bench:FindFirstChild("StealPrompt")
	if not (prompt and prompt:IsA("ProximityPrompt") and isFairTrigger(thief, prompt)) then
		return
	end
	if GateService.IsLocked(lab) then
		NotifyService.Send(thief, "This lab's gate is locked. Wait for it to open!")
		return
	end
	if carries[thief] then
		NotifyService.Send(thief, "You're already carrying a gadget! Take it home first.")
		return
	end
	if benchCarrier[bench] then
		return -- someone else grabbed it first
	end
	if isOwnerBeingRobbed(owner) then
		NotifyService.Send(thief, "Someone is already stealing from this lab. Try again soon!")
		return
	end
	local allowed, reason = ProtectionService.CanSteal(thief, owner)
	if not allowed then
		NotifyService.Send(thief, reason or "You can't steal from this lab right now.")
		return
	end
	local entry = BenchService.GetEntry(owner, bench)
	local gadget = entry and Gadgets[entry.GadgetId]
	if not gadget then
		return
	end
	if not BenchService.FindFreeBench(thief, true) then
		NotifyService.Send(thief, "You need a free bench at home (not the Vault) to steal a gadget.")
		return
	end
	if not beginCarry(thief, owner, nil, bench, gadget) then
		return
	end
	BenchService.SetCarried(owner, bench, true)
	ProtectionService.OnStealStarted(thief)

	NotifyService.Send(thief, `Got it! Run to your lab's dock within {Stealing.CarrySeconds}s!`)
	NotifyService.Send(owner, `🚨 {thief.DisplayName} is stealing your {gadget.DisplayName}!`, "alarm")
end

-- The thief stepped on a Receiving Dock: deliver if it's their own lab's dock
local function onDockTouched(lab: Model, hit: BasePart)
	local character = hit:FindFirstAncestorOfClass("Model")
	local player = character and Players:GetPlayerFromCharacter(character)
	if player and carries[player] and LabService.GetLab(player) == lab then
		deliver(player)
	end
end

local function onPlayerRemoving(player: Player)
	holdStarts[player] = nil
	-- A thief leaving drops what they carry; an owner leaving takes their gadget with them
	local own = carries[player]
	if own then
		cancelCarry(player, "", `The thief left, so your {own.gadget.DisplayName} came back!`)
	end
	for thief, carry in carries do
		if carry.owner == player then
			cancelCarry(thief, `The owner left, so the {carry.gadget.DisplayName} went with them.`)
		end
	end
end

local function updateTimers()
	local now = os.clock()
	for thief, carry in carries do
		local left = carry.deadline - now
		if left <= 0 then
			cancelCarry(thief, `Too slow! The {carry.gadget.DisplayName} went back.`, `Your {carry.gadget.DisplayName} came back!`)
		else
			carry.timerLabel.Text = `⏱ {math.ceil(left)}s`
		end
	end
end

----- Public Functions -----
-- An NPC's bench was triggered (GrudgeService). Checks the trigger and the thief, then starts the
-- carry. Returns true if the thief is now carrying the gadget; the caller hides it from the bench.
function StealService.StartNpcSteal(thief: Player, bench: BasePart, prompt: ProximityPrompt, gadgetId: string, npc: NpcSource): boolean
	local gadget = Gadgets[gadgetId]
	if not (gadget and isFairTrigger(thief, prompt)) then
		return false
	end
	if carries[thief] then
		NotifyService.Send(thief, "You're already carrying a gadget! Take it home first.")
		return false
	end
	if benchCarrier[bench] then
		return false
	end
	if not LabService.GetLab(thief) then
		return false
	end
	if not BenchService.FindFreeBench(thief, true) then
		NotifyService.Send(thief, "You need a free bench at home (not the Vault) to steal a gadget.")
		return false
	end
	if not beginCarry(thief, nil, npc, bench, gadget) then
		return false
	end
	NotifyService.Send(thief, `Got it! Run to your lab's dock within {Stealing.CarrySeconds}s!`)
	return true
end

-- True while someone is carrying off one of the owner's gadgets
function StealService.IsBeingRobbed(owner: Player): boolean
	return isOwnerBeingRobbed(owner)
end

-- True while the player is carrying a stolen gadget
function StealService.IsCarrying(player: Player): boolean
	return carries[player] ~= nil
end

-- The owner hit the thief with the Boing Glove: the gadget snaps back home. Returns true if it did.
function StealService.KnockLoose(thief: Player, hitter: Player): boolean
	local carry = carries[thief]
	if not (carry and carry.owner == hitter) then
		return false
	end
	local name = carry.gadget.DisplayName
	cancelCarry(thief, `{hitter.DisplayName} boinged the {name} out of your hands!`, `Boing! You got your {name} back!`)
	return true
end

function StealService.Init()
	BenchService.SetStealHandler(onStealRequested)
	for _, lab in labsFolder:GetChildren() do
		local dock = lab:FindFirstChild("ReceivingDock")
		if lab:IsA("Model") and dock and dock:IsA("BasePart") then
			dock.Touched:Connect(function(hit)
				onDockTouched(lab, hit)
			end)
		elseif lab:IsA("Model") then
			warn(`[StealService] {lab.Name} has no ReceivingDock; stolen gadgets can't be delivered there`)
		end
	end
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt, player)
		holdStarts[player] = { prompt = prompt, time = os.clock() }
	end)
	ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt, player)
		local hold = holdStarts[player]
		if hold and hold.prompt == prompt and not hold.endedAt then
			hold.endedAt = os.clock()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(TIMER_INTERVAL)
			updateTimers()
		end
	end)
end

return StealService
