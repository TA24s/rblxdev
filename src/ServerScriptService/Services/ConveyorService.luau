--!strict
-- ConveyorService
-- Drops a random gadget onto the conveyor every few seconds (rarer gadgets less often) and
-- carries it once round the belt. A player holds E on a gadget to buy it with Bolts, and
-- BenchService puts it on the first empty bench in their lab.
-- Container: ServerScriptService/Services

----- Services -----
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

----- Modules -----
local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Gadgets = require(Config:WaitForChild("Gadgets"))
local Rarities = require(Config:WaitForChild("Rarities"))
local BenchService = require(script.Parent:WaitForChild("BenchService"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local LabService = require(script.Parent:WaitForChild("LabService"))
local NotifyService = require(script.Parent:WaitForChild("NotifyService"))

----- Constants -----
local SPAWN_INTERVAL = 3 -- seconds between new gadgets
local BELT_SPEED = 4 -- studs per second
local BELT_TOP_Y = 1.6 -- top of the belts (1.5) plus half the gadget's Base
-- Corners of the square belt in travel order; a gadget does one lap, then goes back into the pipe
local PATH = {
	Vector3.new(-14, BELT_TOP_Y, -14),
	Vector3.new(14, BELT_TOP_Y, -14),
	Vector3.new(14, BELT_TOP_Y, 14),
	Vector3.new(-14, BELT_TOP_Y, 14),
	Vector3.new(-14, BELT_TOP_Y, -14),
}
local BUY_HOLD_SECONDS = 0.5
local PROMPT_DISTANCE = 10

----- Types -----
type BeltItem = {
	model: Model,
	gadget: Gadgets.Gadget,
	distance: number, -- how far along PATH it has travelled
	sold: boolean,
}

----- Variables -----
local modelsFolder = ServerStorage:WaitForChild("GadgetModels")
local beltFolder: Folder
local items: { BeltItem } = {}
local segmentLengths: { number } = {}
local pathLength = 0
local rng = Random.new()

local ConveyorService = {}

----- Private Functions -----
-- 1234567 -> "1,234,567"
local function formatNumber(n: number): string
	local text = tostring(math.floor(n))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

-- Pick a rarity by its ConveyorWeight (only rarities that have gadgets), then a gadget of that rarity
local function pickGadget(): Gadgets.Gadget?
	local byRarity: { [string]: { Gadgets.Gadget } } = {}
	for _, gadget in Gadgets do
		byRarity[gadget.Rarity] = byRarity[gadget.Rarity] or {}
		table.insert(byRarity[gadget.Rarity], gadget)
	end
	local totalWeight = 0
	for rarityId in byRarity do
		totalWeight += Rarities[rarityId].ConveyorWeight
	end
	local roll = rng:NextNumber() * totalWeight
	for rarityId, list in byRarity do
		roll -= Rarities[rarityId].ConveyorWeight
		if roll <= 0 then
			return list[rng:NextInteger(1, #list)]
		end
	end
	return nil
end

-- Where a gadget is, and which way it faces, after travelling `distance` along the belt
local function cframeAt(distance: number): CFrame
	for i, length in segmentLengths do
		if distance <= length then
			local from, to = PATH[i], PATH[i + 1]
			local position = from:Lerp(to, distance / length)
			return CFrame.lookAt(position, position + (to - from).Unit)
		end
		distance -= length
	end
	return CFrame.new(PATH[#PATH])
end

local function createLabel(gadget: Gadgets.Gadget, parent: BasePart)
	local rarity = Rarities[gadget.Rarity]
	local gui = Instance.new("BillboardGui")
	gui.Name = "GadgetLabel"
	gui.Size = UDim2.fromOffset(170, 66)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 6.5, 0)
	gui.MaxDistance = 60
	gui.AlwaysOnTop = false

	local lines = {
		{ text = gadget.DisplayName, color = Color3.new(1, 1, 1) },
		{ text = rarity.DisplayName, color = rarity.Color },
		{ text = `⚙ {formatNumber(gadget.Cost)}  ·  +{formatNumber(gadget.Income)}/s`, color = Color3.fromRGB(255, 200, 40) },
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

local function removeFromBelt(item: BeltItem)
	local index = table.find(items, item)
	if index then
		table.remove(items, index)
	end
end

local function onBuy(item: BeltItem, player: Player)
	if item.sold then
		return
	end
	local gadget = item.gadget
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
	if not BenchService.PlaceGadget(player, bench, gadget.Id) then
		DataService.AddBolts(player, gadget.Cost) -- give the Bolts back
		NotifyService.Send(player, "Something went wrong placing that gadget. Your Bolts were refunded.")
		return
	end

	item.sold = true
	removeFromBelt(item)
	item.model:Destroy()
	NotifyService.Send(player, `You bought the {gadget.DisplayName}! It's on a bench in your lab.`, "good")
end

local function spawnGadget()
	local gadget = pickGadget()
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

	local item: BeltItem = { model = model, gadget = gadget, distance = 0, sold = false }
	model:SetAttribute("Cost", gadget.Cost) -- lets the new-player tips point at one you can afford

	createLabel(gadget, base)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = `Buy for ⚙ {gadget.Cost}`
	prompt.ObjectText = gadget.DisplayName
	prompt.HoldDuration = BUY_HOLD_SECONDS
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = base
	prompt.Triggered:Connect(function(player)
		onBuy(item, player)
	end)

	model:PivotTo(cframeAt(0))
	model.Parent = beltFolder
	table.insert(items, item)
end

local function moveItems(deltaTime: number)
	-- Backwards, so removing an item doesn't skip the next one
	for i = #items, 1, -1 do
		local item = items[i]
		item.distance += BELT_SPEED * deltaTime
		if item.distance >= pathLength then
			table.remove(items, i)
			item.model:Destroy()
		else
			item.model:PivotTo(cframeAt(item.distance))
		end
	end
end

----- Public Functions -----
function ConveyorService.Init()
	for i = 1, #PATH - 1 do
		segmentLengths[i] = (PATH[i + 1] - PATH[i]).Magnitude
		pathLength += segmentLengths[i]
	end

	beltFolder = Instance.new("Folder")
	beltFolder.Name = "ConveyorGadgets"
	beltFolder.Parent = workspace

	RunService.Heartbeat:Connect(moveItems)
	task.spawn(function()
		while true do
			spawnGadget()
			task.wait(SPAWN_INTERVAL)
		end
	end)
end

return ConveyorService
