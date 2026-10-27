--!strict
-- BenchService
-- Puts each player's saved gadgets back on their lab benches when they join. Every second each
-- gadget earns its Income, which piles up on its bench; the owner steps on the bench to collect.
-- Owners can also sell a gadget (hold E on its bench) and unlock benches 5 to 8 with Bolts.
-- Other players see a Steal prompt instead (not on the Vault bench); StealService handles the theft.
-- What's on each bench, how much is piled up and how many benches are unlocked is saved by DataService.
-- Each rebirth makes every gadget earn more (DataService.GetIncomeMultiplier).
-- Container: ServerScriptService/Services

----- Services -----
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

----- Modules -----
local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Gadgets = require(Config:WaitForChild("Gadgets"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Upgrades = require(Config:WaitForChild("Upgrades"))
local Stealing = require(Config:WaitForChild("Stealing"))
local Mutations = require(Config:WaitForChild("Mutations"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local LabService = require(script.Parent:WaitForChild("LabService"))
local NotifyService = require(script.Parent:WaitForChild("NotifyService"))
local EventService = require(script.Parent:WaitForChild("EventService"))

----- Constants -----
local INCOME_INTERVAL = 1 -- seconds
local COLLECT_COOLDOWN = 0.5 -- seconds, so one step doesn't collect many times
local SETUP_TIMEOUT = 30 -- seconds to wait for a player's lab and data
local LABEL_NAME = "BenchLabel"
local LOCKED_LABEL_NAME = "LockedLabel"
local LOCKED_TRANSPARENCY = 0.7
local SELL_HOLD_SECONDS = 1.5 -- long enough that nobody sells by accident
local UNLOCK_HOLD_SECONDS = 1
local PROMPT_DISTANCE = 8
local BOLT_COLOR = Color3.fromRGB(255, 200, 40)

----- Variables -----
local modelsFolder = ServerStorage:WaitForChild("GadgetModels")
local labsFolder = workspace:WaitForChild("Map"):WaitForChild("Labs")
local readyLabs: { [Player]: Model } = {} -- players whose benches are set up
local lastCollect: { [BasePart]: number } = {}
local leftover: { [BasePart]: number } = {} -- part-Bolts earned with a rebirth boost, paid once they add up to 1
local sellPrompts: { [BasePart]: ProximityPrompt } = {}
local unlockPrompts: { [BasePart]: ProximityPrompt } = {} -- only benches above BaseBenches
local stealPrompts: { [BasePart]: ProximityPrompt } = {} -- every bench except the Vault
local carriedModels: { [BasePart]: Model } = {} -- gadgets being carried off by a thief, hidden until they return
local stealHandler: ((thief: Player, bench: BasePart) -> ())? = nil

local BenchService = {}

----- Private Functions -----
-- 1234567 -> "1,234,567"
local function formatNumber(n: number): string
	local text = tostring(math.floor(n))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

local function getPlacedFolder(lab: Model): Folder
	local folder = lab:FindFirstChild("PlacedGadgets")
	if folder and folder:IsA("Folder") then
		return folder
	end
	local newFolder = Instance.new("Folder")
	newFolder.Name = "PlacedGadgets"
	newFolder.Parent = lab
	return newFolder
end

-- The lab's benches, sorted by BenchIndex
local function getBenches(lab: Model): { BasePart }
	local benches = {}
	local folder = lab:FindFirstChild("Benches")
	if folder then
		for _, bench in folder:GetChildren() do
			if bench:IsA("BasePart") and typeof(bench:GetAttribute("BenchIndex")) == "number" then
				table.insert(benches, bench)
			end
		end
	end
	table.sort(benches, function(a, b)
		return (a:GetAttribute("BenchIndex") :: number) < (b:GetAttribute("BenchIndex") :: number)
	end)
	return benches
end

local function benchKey(bench: BasePart): string
	return tostring(bench:GetAttribute("BenchIndex"))
end

local function benchIndex(bench: BasePart): number
	return bench:GetAttribute("BenchIndex") :: number
end

local function unlockedCount(data: DataService.PlayerData): number
	return Upgrades.BaseBenches + data.ExtraBenches
end

-- Bolts to unlock this bench, or nil for the benches every lab starts with
local function unlockCost(bench: BasePart): number?
	return Upgrades.BenchUnlockCosts[benchIndex(bench) - Upgrades.BaseBenches]
end

local function sellPrice(gadget: Gadgets.Gadget, mutation: string?): number
	return math.floor(gadget.Cost * Upgrades.SellRefund * Mutations.Multiplier(mutation))
end

-- Bolts per second a gadget earns before the player's own boosts (a mutation multiplies it)
local function baseIncome(gadget: Gadgets.Gadget, mutation: string?): number
	return gadget.Income * Mutations.Multiplier(mutation)
end

-- The name on a bench label, in the mutation's colour if it has one
local function nameStyle(gadget: Gadgets.Gadget, mutation: string?): (string, Color3)
	local info = mutation and Mutations.List[mutation]
	if info then
		return `✨ {Mutations.Name(mutation, gadget.DisplayName)}`, info.Color
	end
	return gadget.DisplayName, Rarities[gadget.Rarity].Color
end

-- The lab a bench belongs to (Lab > Benches > Bench)
local function labOf(bench: BasePart): Instance?
	local folder = bench.Parent
	return folder and folder.Parent
end

local function createLabel(bench: BasePart, gadget: Gadgets.Gadget, mutation: string?)
	local gui = Instance.new("BillboardGui")
	gui.Name = LABEL_NAME
	gui.Size = UDim2.fromOffset(160, 70)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 7.5, 0)
	gui.MaxDistance = 50

	local name, nameColor = nameStyle(gadget, mutation)
	local lines = {
		{ name = "GadgetName", text = name, color = nameColor },
		{ name = "Income", text = `+{formatNumber(baseIncome(gadget, mutation))}/s`, color = Color3.fromRGB(140, 255, 140) },
		{ name = "Stored", text = "⚙ 0", color = BOLT_COLOR },
	}
	for i, line in lines do
		local label = Instance.new("TextLabel")
		label.Name = line.name
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
	gui.Parent = bench
end

local function setStoredText(bench: BasePart, stored: number)
	local gui = bench:FindFirstChild(LABEL_NAME)
	local label = gui and gui:FindFirstChild("Stored")
	if label and label:IsA("TextLabel") then
		label.Text = `⚙ {formatNumber(stored)}`
	end
end

-- Builds the gadget model and label on a bench (visuals only; the data is changed by the caller)
local function showOnBench(player: Player, bench: BasePart, gadget: Gadgets.Gadget, stored: number, mutation: string?): boolean
	local lab = readyLabs[player] or LabService.GetLab(player)
	local template = modelsFolder:FindFirstChild(gadget.Id)
	if not (lab and template and template:IsA("Model")) then
		warn(`[BenchService] Can't show {gadget.Id} for {player.Name}`)
		return false
	end
	local model = template:Clone()
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("BenchIndex", bench:GetAttribute("BenchIndex"))
	Mutations.Apply(model, mutation)
	model:PivotTo(bench.CFrame * CFrame.new(0, bench.Size.Y / 2 + 0.1, 0))
	model.Parent = getPlacedFolder(lab)
	createLabel(bench, gadget, mutation)
	setStoredText(bench, stored)
	return true
end

local function setLockedLabel(bench: BasePart, cost: number?)
	local existing = bench:FindFirstChild(LOCKED_LABEL_NAME)
	if not cost then
		if existing then
			existing:Destroy()
		end
		return
	end
	if existing then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = LOCKED_LABEL_NAME
	gui.Size = UDim2.fromOffset(140, 50)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	gui.MaxDistance = 40
	local lines = {
		{ text = `🔒 Bench {benchIndex(bench)}`, color = Color3.new(1, 1, 1) },
		{ text = `⚙ {formatNumber(cost)}`, color = BOLT_COLOR },
	}
	for i, line in lines do
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 0.5)
		label.Position = UDim2.fromScale(0, (i - 1) * 0.5)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.Text = line.text
		label.TextColor3 = line.color
		label.TextStrokeTransparency = 0.3
		label.Parent = gui
	end
	gui.Parent = bench
end

-- Shows which benches are locked, and turns the sell and unlock prompts on or off to match.
-- `data` is the owner's data, or nil for an empty lab (every extra bench shows as locked).
local function refreshLab(lab: Model, data: DataService.PlayerData?)
	local unlocked = if data then unlockedCount(data) else Upgrades.BaseBenches
	for _, bench in getBenches(lab) do
		local index = benchIndex(bench)
		local locked = index > unlocked
		local cost = unlockCost(bench)
		if cost then
			bench.Transparency = if locked then LOCKED_TRANSPARENCY else 0
			setLockedLabel(bench, if locked then cost else nil)
		end
		local unlockPrompt = unlockPrompts[bench]
		if unlockPrompt then
			-- Only the next bench in order can be unlocked
			unlockPrompt.Enabled = data ~= nil and index == unlocked + 1
		end
		local sellPrompt = sellPrompts[bench]
		if sellPrompt then
			local entry = data and data.Benches[benchKey(bench)]
			local gadget = entry and Gadgets[entry.GadgetId]
			sellPrompt.Enabled = entry ~= nil
			sellPrompt.ActionText = if gadget then `Sell for ⚙ {formatNumber(sellPrice(gadget, entry and entry.Mutation))}` else "Sell"
			sellPrompt.ObjectText = if gadget then Mutations.Name(entry and entry.Mutation, gadget.DisplayName) else ""
		end
		local stealPrompt = stealPrompts[bench]
		if stealPrompt then
			local entry = data and data.Benches[benchKey(bench)]
			local gadget = entry and Gadgets[entry.GadgetId]
			stealPrompt.Enabled = gadget ~= nil and not carriedModels[bench]
			stealPrompt.ObjectText = if gadget then Mutations.Name(entry and entry.Mutation, gadget.DisplayName) else ""
			stealPrompt.HoldDuration = if gadget then Stealing.HoldSeconds[gadget.Rarity] or 1 else 1
		end
	end
end

local function clearLab(lab: Model)
	getPlacedFolder(lab):ClearAllChildren()
	for _, bench in getBenches(lab) do
		leftover[bench] = nil
		local hidden = carriedModels[bench]
		if hidden then
			hidden:Destroy()
			carriedModels[bench] = nil
		end
		local gui = bench:FindFirstChild(LABEL_NAME)
		if gui then
			gui:Destroy()
		end
	end
end

-- Puts the player's saved gadgets on their benches
local function showSavedGadgets(player: Player, lab: Model, data: DataService.PlayerData)
	for _, bench in getBenches(lab) do
		local entry = data.Benches[benchKey(bench)]
		local gadget = entry and Gadgets[entry.GadgetId]
		if entry and gadget then
			showOnBench(player, bench, gadget, entry.Stored, entry.Mutation)
		elseif entry then
			warn(`[BenchService] Unknown gadget {entry.GadgetId} on bench {benchKey(bench)} for {player.Name}`)
		end
	end
	refreshLab(lab, data)
end

local function setUpPlayer(player: Player)
	-- The lab (LabService) and saved data (DataService) arrive separately; wait for both
	local deadline = os.clock() + SETUP_TIMEOUT
	while player.Parent == Players and not (player:GetAttribute("DataLoaded") and LabService.GetLab(player)) do
		if os.clock() > deadline then
			warn(`[BenchService] {player.Name} has no lab or data after {SETUP_TIMEOUT}s; benches not set up`)
			return
		end
		task.wait(0.25)
	end
	local lab = LabService.GetLab(player)
	local data = DataService.GetData(player)
	if not (lab and data and player.Parent == Players) then
		return
	end

	readyLabs[player] = lab
	showSavedGadgets(player, lab, data)
end

local function onPlayerRemoving(player: Player)
	local lab = readyLabs[player]
	readyLabs[player] = nil
	if lab then
		clearLab(lab)
		refreshLab(lab, nil)
	end
end

local function earnIncome()
	for player, lab in readyLabs do
		local data = DataService.GetData(player)
		if not data then
			continue
		end
		-- Rebirths and boosts, times a Double Bolts event if one is running
		local multiplier = DataService.GetIncomeMultiplier(player) * EventService.IncomeMultiplier()
		local total = 0
		for _, bench in getBenches(lab) do
			local entry = data.Benches[benchKey(bench)]
			local gadget = entry and Gadgets[entry.GadgetId]
			if entry and gadget then
				-- Bolts are whole numbers, so any part-Bolt from the boost waits for the next second
				local income = baseIncome(gadget, entry.Mutation) * multiplier
				local earned = income * INCOME_INTERVAL + (leftover[bench] or 0)
				local whole = math.floor(earned)
				leftover[bench] = earned - whole
				entry.Stored += whole
				setStoredText(bench, entry.Stored)
				total += income
			end
		end
		-- The player list shows everyone's Bolts per second (DataService makes the value)
		local leaderstats = player:FindFirstChild("leaderstats")
		local income = leaderstats and leaderstats:FindFirstChild("Income")
		if income and income:IsA("IntValue") then
			income.Value = math.floor(total)
		end
	end
end

local function onBenchTouched(bench: BasePart, hit: BasePart)
	local character = hit:FindFirstAncestorOfClass("Model")
	local player = character and Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end
	-- Only the lab's owner collects here (stealing comes later and works differently)
	local lab = readyLabs[player]
	if not (lab and bench:IsDescendantOf(lab)) then
		return
	end
	local now = os.clock()
	if now - (lastCollect[bench] or 0) < COLLECT_COOLDOWN then
		return
	end
	lastCollect[bench] = now

	local data = DataService.GetData(player)
	local entry = data and data.Benches[benchKey(bench)]
	if entry and entry.Stored > 0 then
		local amount = entry.Stored
		entry.Stored = 0
		if DataService.AddBolts(player, amount) then
			setStoredText(bench, 0)
		else
			entry.Stored = amount -- couldn't pay out; keep it on the bench
		end
	end
end

-- The player who owns the lab this bench is in, if they triggered the prompt themselves
local function ownerOnly(player: Player, bench: BasePart): (Model?, DataService.PlayerData?)
	local lab = readyLabs[player]
	local data = DataService.GetData(player)
	if not (lab and data and labOf(bench) == lab) then
		NotifyService.Send(player, "Only the owner of this lab can do that.")
		return nil, nil
	end
	return lab, data
end

-- Unlocks the next locked bench in the player's lab if they can pay for it
local function unlockNext(player: Player, lab: Model, data: DataService.PlayerData)
	local index = unlockedCount(data) + 1
	local cost = Upgrades.BenchUnlockCosts[index - Upgrades.BaseBenches]
	if not cost then
		NotifyService.Send(player, "All your benches are already unlocked.")
		return
	end
	if not DataService.SpendBolts(player, cost) then
		NotifyService.Send(player, `You need ⚙ {formatNumber(cost)} to unlock bench {index}.`)
		return
	end
	data.ExtraBenches += 1
	refreshLab(lab, data)
	DataService.SyncAttributes(player)
	NotifyService.Send(player, `Bench {index} unlocked! Buy a gadget to put on it.`, "good")
end

local function onUnlock(player: Player, bench: BasePart)
	local lab, data = ownerOnly(player, bench)
	if not (lab and data and unlockCost(bench)) then
		return
	end
	if benchIndex(bench) ~= unlockedCount(data) + 1 then
		return -- only the next bench in order; the prompt is normally hidden for the others
	end
	unlockNext(player, lab, data)
end

local function onSell(player: Player, bench: BasePart)
	local lab, data = ownerOnly(player, bench)
	if not (lab and data) then
		return
	end
	local key = benchKey(bench)
	local entry = data.Benches[key]
	if not entry then
		return
	end
	if carriedModels[bench] then
		NotifyService.Send(player, "Someone is running off with that gadget! Catch them first.")
		return
	end
	local gadget = Gadgets[entry.GadgetId]
	local price = if gadget then sellPrice(gadget, entry.Mutation) else 0
	local payout = price + entry.Stored -- the Bolts piled up on the bench come too
	data.Benches[key] = nil

	for _, model in getPlacedFolder(lab):GetChildren() do
		if model:GetAttribute("BenchIndex") == benchIndex(bench) then
			model:Destroy()
		end
	end
	local label = bench:FindFirstChild(LABEL_NAME)
	if label then
		label:Destroy()
	end
	if payout > 0 then
		DataService.AddBolts(player, payout)
	end
	refreshLab(lab, data)
	local name = if gadget then Mutations.Name(entry.Mutation, gadget.DisplayName) else "gadget"
	NotifyService.Send(player, `Sold the {name} for ⚙ {formatNumber(payout)}.`)
end

local function createPrompts(bench: BasePart)
	local sell = Instance.new("ProximityPrompt")
	sell.Name = "SellPrompt"
	sell.ActionText = "Sell"
	sell.HoldDuration = SELL_HOLD_SECONDS
	sell.MaxActivationDistance = PROMPT_DISTANCE
	sell.RequiresLineOfSight = false
	sell.Enabled = false
	sell.Parent = bench
	sell.Triggered:Connect(function(player)
		onSell(player, bench)
	end)
	sellPrompts[bench] = sell

	local cost = unlockCost(bench)
	if cost then
		local unlock = Instance.new("ProximityPrompt")
		unlock.Name = "UnlockPrompt"
		unlock.ActionText = `Unlock for ⚙ {formatNumber(cost)}`
		unlock.ObjectText = `Bench {benchIndex(bench)}`
		unlock.HoldDuration = UNLOCK_HOLD_SECONDS
		unlock.MaxActivationDistance = PROMPT_DISTANCE
		unlock.RequiresLineOfSight = false
		unlock.Enabled = false
		unlock.Parent = bench
		unlock.Triggered:Connect(function(player)
			onUnlock(player, bench)
		end)
		unlockPrompts[bench] = unlock
	end

	if bench:GetAttribute("IsVault") ~= true then
		local steal = Instance.new("ProximityPrompt")
		steal.Name = "StealPrompt"
		steal.ActionText = "Steal"
		steal.MaxActivationDistance = PROMPT_DISTANCE
		steal.RequiresLineOfSight = false
		steal.Enabled = false
		steal.Parent = bench
		steal.Triggered:Connect(function(player)
			if stealHandler then
				stealHandler(player, bench)
			end
		end)
		stealPrompts[bench] = steal
	end
end

-- The placed gadget model sitting on a bench, if any
local function findPlacedModel(lab: Model, bench: BasePart): Model?
	for _, model in getPlacedFolder(lab):GetChildren() do
		if model:IsA("Model") and model:GetAttribute("BenchIndex") == benchIndex(bench) then
			return model
		end
	end
	return nil
end

local function setNameText(bench: BasePart, text: string)
	local gui = bench:FindFirstChild(LABEL_NAME)
	local label = gui and gui:FindFirstChild("GadgetName")
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

----- Public Functions -----
-- True once the player's lab and saved gadgets are set up
function BenchService.IsReady(player: Player): boolean
	return readyLabs[player] ~= nil
end

-- The first empty unlocked bench in the player's lab (lowest BenchIndex), or nil if all are taken.
-- With skipVault, the Vault bench doesn't count (stolen gadgets can't land somewhere unstealable).
function BenchService.FindFreeBench(player: Player, skipVault: boolean?): BasePart?
	local lab = readyLabs[player]
	local data = DataService.GetData(player)
	if not (lab and data) then
		return nil
	end
	for _, bench in getBenches(lab) do
		local isVault = bench:GetAttribute("IsVault") == true
		if benchIndex(bench) <= unlockedCount(data) and not data.Benches[benchKey(bench)] and not (skipVault and isVault) then
			return bench
		end
	end
	return nil
end

-- Puts a new gadget on an empty bench and records it in the player's data. Returns true if placed.
-- `mutation` is a Config/Mutations Id, or nil for a plain gadget.
function BenchService.PlaceGadget(player: Player, bench: BasePart, gadgetId: string, mutation: string?): boolean
	local data = DataService.GetData(player)
	local gadget = Gadgets[gadgetId]
	local lab = readyLabs[player]
	if not (data and gadget and lab and bench:IsDescendantOf(lab)) or data.Benches[benchKey(bench)] then
		return false
	end
	if benchIndex(bench) > unlockedCount(data) then
		return false
	end
	if mutation and not Mutations.List[mutation] then
		mutation = nil
	end
	if not showOnBench(player, bench, gadget, 0, mutation) then
		return false
	end
	data.Benches[benchKey(bench)] = { GadgetId = gadgetId, Stored = 0, Mutation = mutation }
	DataService.MarkDiscovered(player, gadgetId)
	refreshLab(lab, data)
	return true
end

-- The Upgrades panel's "More Benches" button (MenuService): unlocks the next bench in order
function BenchService.UnlockNext(player: Player)
	local lab = readyLabs[player]
	local data = DataService.GetData(player)
	if lab and data then
		unlockNext(player, lab, data)
	end
end

-- The player whose set-up lab this bench is in, or nil for an empty lab
function BenchService.GetBenchOwner(bench: BasePart): Player?
	local lab = labOf(bench)
	for player, ownedLab in readyLabs do
		if ownedLab == lab then
			return player
		end
	end
	return nil
end

-- What sits on a bench in the owner's data, or nil if it's empty
function BenchService.GetEntry(owner: Player, bench: BasePart): DataService.BenchEntry?
	local data = DataService.GetData(owner)
	return data and data.Benches[benchKey(bench)]
end

-- StealService calls this function when someone triggers a Steal prompt
function BenchService.SetStealHandler(handler: (thief: Player, bench: BasePart) -> ())
	stealHandler = handler
end

-- Hides the gadget on a bench while a thief carries it (true), or puts it back (false).
-- The gadget stays in the owner's data the whole time, so it's only lost once the theft completes.
function BenchService.SetCarried(owner: Player, bench: BasePart, carried: boolean)
	local lab = readyLabs[owner]
	if not (lab and bench:IsDescendantOf(lab)) then
		return -- the owner left; their lab was already cleared
	end
	local entry = BenchService.GetEntry(owner, bench)
	local gadget = entry and Gadgets[entry.GadgetId]
	if carried and not carriedModels[bench] then
		local model = findPlacedModel(lab, bench)
		if model then
			model.Parent = nil
			carriedModels[bench] = model
			setNameText(bench, "🚨 Being stolen!")
		end
	elseif not carried and carriedModels[bench] then
		carriedModels[bench].Parent = getPlacedFolder(lab)
		carriedModels[bench] = nil
		setNameText(bench, if gadget then (nameStyle(gadget, entry and entry.Mutation)) else "")
	end
	refreshLab(lab, DataService.GetData(owner))
end

-- Finishes a theft: takes the carried gadget out of the owner's data and pays the owner the
-- Bolts that had piled up on it. Returns the gadget's Id and mutation, or nil if there was nothing
-- to take.
function BenchService.TakeCarried(owner: Player, bench: BasePart): (string?, string?)
	local lab = readyLabs[owner]
	local data = DataService.GetData(owner)
	local key = benchKey(bench)
	local entry = data and data.Benches[key]
	if not (lab and data and entry and carriedModels[bench]) then
		return nil, nil
	end
	data.Benches[key] = nil
	carriedModels[bench]:Destroy()
	carriedModels[bench] = nil
	local label = bench:FindFirstChild(LABEL_NAME)
	if label then
		label:Destroy()
	end
	if entry.Stored > 0 then
		DataService.AddBolts(owner, entry.Stored)
	end
	refreshLab(lab, data)
	return entry.GadgetId, entry.Mutation
end

-- After a rebirth (DataService.ResetForRebirth): clears the player's benches and shows their
-- lab as it is now (no gadgets, only the starting benches unlocked)
function BenchService.ReloadLab(player: Player)
	local lab = readyLabs[player]
	local data = DataService.GetData(player)
	if not (lab and data) then
		return
	end
	clearLab(lab)
	showSavedGadgets(player, lab, data)
end

function BenchService.Init()
	for _, lab in labsFolder:GetChildren() do
		if lab:IsA("Model") then
			for _, bench in getBenches(lab) do
				bench.Touched:Connect(function(hit)
					onBenchTouched(bench, hit)
				end)
				createPrompts(bench)
			end
			refreshLab(lab, nil)
		end
	end

	Players.PlayerAdded:Connect(setUpPlayer)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(setUpPlayer, player)
	end

	task.spawn(function()
		while true do
			task.wait(INCOME_INTERVAL)
			earnIncome()
		end
	end)
end

return BenchService
