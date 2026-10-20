--!strict
-- StealService
-- Stealing. In another player's lab (gate not locked), hold E on a gadget to grab it. A copy of it
-- rides over the thief's head while they walk slower; touching their own lab's Receiving Dock
-- within 60 seconds moves it onto one of their free benches. If time runs out, the thief dies or
-- resets, or either player leaves, the gadget goes back to its owner.
-- The gadget stays in the owner's data until the moment it's delivered, so it can't be duplicated.
-- Container: ServerScriptService/Services

----- Services -----
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

----- Modules -----
local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Gadgets = require(Config:WaitForChild("Gadgets"))
local Stealing = require(Config:WaitForChild("Stealing"))
local BenchService = require(script.Parent:WaitForChild("BenchService"))
local GateService = require(script.Parent:WaitForChild("GateService"))
local LabService = require(script.Parent:WaitForChild("LabService"))
local NotifyService = require(script.Parent:WaitForChild("NotifyService"))

----- Constants -----
local TIMER_INTERVAL = 0.25 -- seconds between countdown updates
local CARRY_NAME = "CarriedGadget"

----- Types -----
type Carry = {
	owner: Player,
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
		BenchService.SetCarried(carry.owner, carry.bench, false)
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
	if ownerMessage and owner.Parent == Players then
		NotifyService.Send(owner, ownerMessage)
	end
end

local function deliver(thief: Player)
	local carry = carries[thief]
	if not carry then
		return
	end
	local name = carry.gadget.DisplayName
	local freeBench = BenchService.FindFreeBench(thief)
	if not freeBench then
		cancelCarry(thief, `No free bench at home, so the {name} went back.`, `Your {name} came back!`)
		return
	end
	local owner = carry.owner
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
	NotifyService.Send(thief, `You stole the {name}! 🎉`)
	if owner.Parent == Players then
		NotifyService.Send(owner, `{thief.DisplayName} stole your {name}!`)
	end
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
	local entry = BenchService.GetEntry(owner, bench)
	local gadget = entry and Gadgets[entry.GadgetId]
	if not gadget then
		return
	end
	if not BenchService.FindFreeBench(thief) then
		NotifyService.Send(thief, "You need a free bench at home to steal a gadget.")
		return
	end
	local character = thief.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local head = character and character:FindFirstChild("Head")
	if not (character and humanoid and humanoid.Health > 0 and head and head:IsA("BasePart")) then
		return
	end
	local visual, timerLabel = buildVisual(gadget, head)
	if not (visual and timerLabel) then
		warn(`[StealService] No model for {gadget.Id}; steal cancelled`)
		return
	end

	local carry: Carry = {
		owner = owner,
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
	BenchService.SetCarried(owner, bench, true)
	humanoid.WalkSpeed = Stealing.CarryWalkSpeed
	humanoid.JumpHeight = Stealing.CarryJumpHeight
	visual.Parent = character

	local backMessage = `Your {gadget.DisplayName} came back!`
	table.insert(carry.connections, humanoid.Died:Connect(function()
		cancelCarry(thief, `You dropped the {gadget.DisplayName}!`, backMessage)
	end))
	table.insert(carry.connections, thief.CharacterRemoving:Connect(function()
		cancelCarry(thief, `You dropped the {gadget.DisplayName}!`, backMessage)
	end))

	NotifyService.Send(thief, `Got it! Run to your lab's dock within {Stealing.CarrySeconds}s!`)
	NotifyService.Send(owner, `🚨 {thief.DisplayName} is stealing your {gadget.DisplayName}!`)
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
-- True while the player is carrying a stolen gadget
function StealService.IsCarrying(player: Player): boolean
	return carries[player] ~= nil
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
	task.spawn(function()
		while true do
			task.wait(TIMER_INTERVAL)
			updateTimers()
		end
	end)
end

return StealService
