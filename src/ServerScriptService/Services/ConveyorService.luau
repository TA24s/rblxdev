--!strict
-- ConveyorService
-- Drops a random gadget onto each conveyor every few seconds (rarer gadgets less often) and
-- carries it once round the belt. A player holds E on a gadget to buy it with Bolts, and
-- BenchService puts it on the first empty bench in their lab.
-- There are two conveyors: the plaza's, with every rarity, and the Rooftop Lab's (Config/Rooftop),
-- with Rare and rarer gadgets only, which only players who have rebirthed can buy from.
-- Container: ServerScriptService/Services

----- Services -----
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

----- Modules -----
local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Gadgets = require(Config:WaitForChild("Gadgets"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Mutations = require(Config:WaitForChild("Mutations"))
local BenchService = require(script.Parent:WaitForChild("BenchService"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local LabService = require(script.Parent:WaitForChild("LabService"))
local NotifyService = require(script.Parent:WaitForChild("NotifyService"))
local EventService = require(script.Parent:WaitForChild("EventService"))
local TrackingService = require(script.Parent:WaitForChild("TrackingService"))
local Events = require(Config:WaitForChild("Events"))
local Rooftop = require(Config:WaitForChild("Rooftop"))

----- Constants -----
local SPAWN_INTERVAL = 3 -- seconds between new gadgets
local BELT_SPEED = 4 -- studs per second
local BELT_TOP_Y = 1.6 -- top of the belts (1.5) plus half the gadget's Base
-- Corners of the plaza's square belt in travel order; a gadget does one lap, then goes back into the pipe
local PLAZA_PATH = {
	Vector3.new(-14, BELT_TOP_Y, -14),
	Vector3.new(14, BELT_TOP_Y, -14),
	Vector3.new(14, BELT_TOP_Y, 14),
	Vector3.new(-14, BELT_TOP_Y, 14),
	Vector3.new(-14, BELT_TOP_Y, -14),
}
local BUY_HOLD_SECONDS = 0.5
local PROMPT_DISTANCE = 10

----- Types -----
type Belt = {
	name: string,
	path: { Vector3 },
	segmentLengths: { number },
	pathLength: number,
	rarities: { [string]: boolean }?, -- only these rarities roll here (nil = all)
	spawnInterval: number,
	minRebirths: number, -- rebirths needed to buy from this belt
	folder: Folder,
	items: { BeltItem },
}

type BeltItem = {
	model: Model,
	gadget: Gadgets.Gadget,
	mutation: string?, -- Config/Mutations Id, or nil for a plain gadget
	distance: number, -- how far along the belt's path it has travelled
	sold: boolean,
}

----- Variables -----
local modelsFolder = ServerStorage:WaitForChild("GadgetModels")
local belts: { Belt } = {}
local rng = Random.new()

local ConveyorService = {}

----- Private Functions -----
-- 1234567 -> "1,234,567"
local function formatNumber(n: number): string
	local text = tostring(math.floor(n))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

-- Pick a rarity by its ConveyorWeight (only rarities that have gadgets), then a gadget of that rarity.
-- A Gadget Rush event makes Rare and rarer gadgets more common. A belt with a rarity list only
-- rolls those rarities.
local function pickGadget(belt: Belt): Gadgets.Gadget?
	local byRarity: { [string]: { Gadgets.Gadget } } = {}
	for _, gadget in Gadgets do
		if belt.rarities and not belt.rarities[gadget.Rarity] then
			continue
		end
		byRarity[gadget.Rarity] = byRarity[gadget.Rarity] or {}
		table.insert(byRarity[gadget.Rarity], gadget)
	end
	local boost = EventService.RareBoost()
	local function weightOf(rarityId: string): number
		return Rarities[rarityId].ConveyorWeight * (if Events.RareRarities[rarityId] then boost else 1)
	end
	local totalWeight = 0
	for rarityId in byRarity do
		totalWeight += weightOf(rarityId)
	end
	local roll = rng:NextNumber() * totalWeight
	for rarityId, list in byRarity do
		roll -= weightOf(rarityId)
		if roll <= 0 then
			return list[rng:NextInteger(1, #list)]
		end
	end
	return nil
end

-- Where a gadget is, and which way it faces, after travelling `distance` along the belt
local function cframeAt(belt: Belt, distance: number): CFrame
	for i, length in belt.segmentLengths do
		if distance <= length then
			local from, to = belt.path[i], belt.path[i + 1]
			local position = from:Lerp(to, distance / length)
			return CFrame.lookAt(position, position + (to - from).Unit)
		end
		distance -= length
	end
	return CFrame.new(belt.path[#belt.path])
end

local function createLabel(gadget: Gadgets.Gadget, mutation: string?, parent: BasePart)
	local rarity = Rarities[gadget.Rarity]
	local info = mutation and Mutations.List[mutation]
	local gui = Instance.new("BillboardGui")
	gui.Name = "GadgetLabel"
	gui.Size = UDim2.fromOffset(170, 66)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 6.5, 0)
	gui.MaxDistance = 60
	gui.AlwaysOnTop = false

	local lines = {
		{ text = gadget.DisplayName, color = Color3.new(1, 1, 1) },
		{ text = if info then `✨ {info.DisplayName} {rarity.DisplayName} (x{info.Multiplier})` else rarity.DisplayName, color = if info then info.Color else rarity.Color },
		{ text = `⚙ {formatNumber(gadget.Cost)}  ·  +{formatNumber(gadget.Income * Mutations.Multiplier(mutation))}/s`, color = Color3.fromRGB(255, 200, 40) },
	}
	for i, line in lines do
		local label = Instance.new("TextLabel")
		label.Name = `Line{i}`
		label.Size = UDim2.fromScale(1, 1 / 3)
		label.Position = UDim2.fromScale(0, (i - 1) / 3)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.Text = line.text
		label.TextColor3 = line.color
		label.TextStrokeTransparency = 0.3
		label.Parent = gui
	end
	gui.Parent = parent
end

local function removeFromBelt(belt: Belt, item: BeltItem)
	local index = table.find(belt.items, item)
	if index then
		table.remove(belt.items, index)
	end
end

local function onBuy(belt: Belt, item: BeltItem, player: Player)
	if item.sold then
		return
	end
	local gadget = item.gadget
	local data = DataService.GetData(player)
	if belt.minRebirths > 0 and (not data or data.Rebirths < belt.minRebirths) then
		-- The lift checks this too; this stops anyone who got up here some other way
		NotifyService.Send(player, `Rebirth {belt.minRebirths} time{if belt.minRebirths == 1 then "" else "s"} to buy from the {belt.name}.`)
		return
	end
	if not LabService.GetLab(player) then
		NotifyService.Send(player, "You need a lab to keep gadgets in.")
		return
	end
	if not BenchService.IsReady(player) then
		NotifyService.Send(player, "Your lab is still loading. Try again in a moment.")
		return
	end
	local bench = BenchService.FindFreeBench(player)
	if not bench then
		NotifyService.Send(player, "Your lab is full! Every bench has a gadget on it.")
		return
	end
	-- SpendBolts checks the player can afford it, so Bolts can never go below zero
	if not DataService.SpendBolts(player, gadget.Cost) then
		NotifyService.Send(player, `You need ⚙ {formatNumber(gadget.Cost)} to buy the {gadget.DisplayName}.`)
		return
	end
	if not BenchService.PlaceGadget(player, bench, gadget.Id, item.mutation) then
		DataService.AddBolts(player, gadget.Cost) -- give the Bolts back
		NotifyService.Send(player, "Something went wrong placing that gadget. Your Bolts were refunded.")
		return
	end

	item.sold = true
	removeFromBelt(belt, item)
	TrackingService.Bolts(player, "Sink", gadget.Cost, "Shop", gadget.Id)
	TrackingService.Custom(player, "GadgetBought", gadget.Cost, TrackingService.GadgetFields(gadget.Id, item.mutation))
	TrackingService.Step(player, "FirstBuy")
	item.model:Destroy()
	NotifyService.Send(player, `You bought the {Mutations.Name(item.mutation, gadget.DisplayName)}! It's on a bench in your lab.`, "good")
end

local function spawnGadget(belt: Belt)
	local gadget = pickGadget(belt)
	local template = gadget and modelsFolder:FindFirstChild(gadget.Id)
	if not (gadget and template and template:IsA("Model")) then
		warn(`[ConveyorService] No model for gadget {gadget and gadget.Id}`)
		return
	end
	local model = template:Clone()
	local base = model.PrimaryPart
	if not base then
		warn(`[ConveyorService] {gadget.Id} has no PrimaryPart`)
		return
	end

	local mutation = Mutations.Roll(rng, EventService.MutationBoost())
	local item: BeltItem = { model = model, gadget = gadget, mutation = mutation, distance = 0, sold = false }
	Mutations.Apply(model, mutation)
	model:SetAttribute("Cost", gadget.Cost) -- lets the new-player tips point at one you can afford

	createLabel(gadget, mutation, base)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = `Buy for ⚙ {formatNumber(gadget.Cost)}`
	prompt.ObjectText = Mutations.Name(mutation, gadget.DisplayName)
	prompt.HoldDuration = BUY_HOLD_SECONDS
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = base
	prompt.Triggered:Connect(function(player)
		onBuy(belt, item, player)
	end)

	model:PivotTo(cframeAt(belt, 0))
	model.Parent = belt.folder
	table.insert(belt.items, item)
end

local function moveItems(deltaTime: number)
	for _, belt in belts do
		-- Backwards, so removing an item doesn't skip the next one
		for i = #belt.items, 1, -1 do
			local item = belt.items[i]
			item.distance += BELT_SPEED * deltaTime
			if item.distance >= belt.pathLength then
				table.remove(belt.items, i)
				item.model:Destroy()
			else
				item.model:PivotTo(cframeAt(belt, item.distance))
			end
		end
	end
end

-- Sets up a belt and starts dropping gadgets onto it
local function addBelt(name: string, folderName: string, path: { Vector3 }, spawnInterval: number, rarities: { [string]: boolean }?, minRebirths: number)
	local folder = Instance.new("Folder")
	folder.Name = folderName
	folder.Parent = workspace
	local belt: Belt = {
		name = name,
		path = path,
		segmentLengths = {},
		pathLength = 0,
		rarities = rarities,
		spawnInterval = spawnInterval,
		minRebirths = minRebirths,
		folder = folder,
		items = {},
	}
	for i = 1, #path - 1 do
		belt.segmentLengths[i] = (path[i + 1] - path[i]).Magnitude
		belt.pathLength += belt.segmentLengths[i]
	end
	table.insert(belts, belt)
	task.spawn(function()
		while true do
			spawnGadget(belt)
			task.wait(belt.spawnInterval / EventService.SpawnSpeed()) -- a Gadget Rush spawns them faster
		end
	end)
end

----- Public Functions -----
function ConveyorService.Init()
	addBelt("conveyor", "ConveyorGadgets", PLAZA_PATH, SPAWN_INTERVAL, nil, 0)
	local map = workspace:FindFirstChild("Map")
	if map and map:FindFirstChild("RooftopLab") then
		addBelt("Rooftop Lab", "RooftopGadgets", Rooftop.Path, Rooftop.SpawnInterval, Rooftop.Rarities, Rooftop.MinRebirths)
	else
		warn("[ConveyorService] Workspace.Map.RooftopLab is missing, so the rooftop conveyor is off")
	end
	RunService.Heartbeat:Connect(moveItems)
end

return ConveyorService
