--!strict
-- BenchService
-- Puts each player's saved gadgets back on their lab benches when they join. Every second each
-- gadget earns its Income, which piles up on its bench; the owner steps on the bench to collect.
-- What's on each bench (and how much is piled up) is saved by DataService.
-- Container: ServerScriptService/Services

----- Services -----
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

----- Modules -----
local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Gadgets = require(Config:WaitForChild("Gadgets"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local LabService = require(script.Parent:WaitForChild("LabService"))

----- Constants -----
local INCOME_INTERVAL = 1 -- seconds
local COLLECT_COOLDOWN = 0.5 -- seconds, so one step doesn't collect many times
local SETUP_TIMEOUT = 30 -- seconds to wait for a player's lab and data
local LABEL_NAME = "BenchLabel"
local BOLT_COLOR = Color3.fromRGB(255, 200, 40)

----- Variables -----
local modelsFolder = ServerStorage:WaitForChild("GadgetModels")
local labsFolder = workspace:WaitForChild("Map"):WaitForChild("Labs")
local readyLabs: { [Player]: Model } = {} -- players whose benches are set up
local lastCollect: { [BasePart]: number } = {}

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

local function createLabel(bench: BasePart, gadget: Gadgets.Gadget)
	local gui = Instance.new("BillboardGui")
	gui.Name = LABEL_NAME
	gui.Size = UDim2.fromOffset(160, 70)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 7.5, 0)
	gui.MaxDistance = 50

	local lines = {
		{ name = "GadgetName", text = gadget.DisplayName, color = Color3.new(1, 1, 1) },
		{ name = "Income", text = `+{formatNumber(gadget.Income)}/s`, color = Color3.fromRGB(140, 255, 140) },
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
local function showOnBench(player: Player, bench: BasePart, gadget: Gadgets.Gadget, stored: number): boolean
	local lab = readyLabs[player] or LabService.GetLab(player)
	local template = modelsFolder:FindFirstChild(gadget.Id)
	if not (lab and template and template:IsA("Model")) then
		warn(`[BenchService] Can't show {gadget.Id} for {player.Name}`)
		return false
	end
	local model = template:Clone()
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("BenchIndex", bench:GetAttribute("BenchIndex"))
	model:PivotTo(bench.CFrame * CFrame.new(0, bench.Size.Y / 2 + 0.1, 0))
	model.Parent = getPlacedFolder(lab)
	createLabel(bench, gadget)
	setStoredText(bench, stored)
	return true
end

local function clearLab(lab: Model)
	getPlacedFolder(lab):ClearAllChildren()
	for _, bench in getBenches(lab) do
		local gui = bench:FindFirstChild(LABEL_NAME)
		if gui then
			gui:Destroy()
		end
	end
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
	for _, bench in getBenches(lab) do
		local entry = data.Benches[benchKey(bench)]
		local gadget = entry and Gadgets[entry.GadgetId]
		if entry and gadget then
			showOnBench(player, bench, gadget, entry.Stored)
		elseif entry then
			warn(`[BenchService] Unknown gadget {entry.GadgetId} on bench {benchKey(bench)} for {player.Name}`)
		end
	end
end

local function onPlayerRemoving(player: Player)
	local lab = readyLabs[player]
	readyLabs[player] = nil
	if lab then
		clearLab(lab)
	end
end

local function earnIncome()
	for player, lab in readyLabs do
		local data = DataService.GetData(player)
		if not data then
			continue
		end
		for _, bench in getBenches(lab) do
			local entry = data.Benches[benchKey(bench)]
			local gadget = entry and Gadgets[entry.GadgetId]
			if entry and gadget then
				entry.Stored += gadget.Income * INCOME_INTERVAL
				setStoredText(bench, entry.Stored)
			end
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

----- Public Functions -----
-- True once the player's lab and saved gadgets are set up
function BenchService.IsReady(player: Player): boolean
	return readyLabs[player] ~= nil
end

-- The first empty bench in the player's lab (lowest BenchIndex), or nil if all are taken
function BenchService.FindFreeBench(player: Player): BasePart?
	local lab = readyLabs[player]
	local data = DataService.GetData(player)
	if not (lab and data) then
		return nil
	end
	for _, bench in getBenches(lab) do
		if not data.Benches[benchKey(bench)] then
			return bench
		end
	end
	return nil
end

-- Puts a new gadget on an empty bench and records it in the player's data. Returns true if placed.
function BenchService.PlaceGadget(player: Player, bench: BasePart, gadgetId: string): boolean
	local data = DataService.GetData(player)
	local gadget = Gadgets[gadgetId]
	local lab = readyLabs[player]
	if not (data and gadget and lab and bench:IsDescendantOf(lab)) or data.Benches[benchKey(bench)] then
		return false
	end
	if not showOnBench(player, bench, gadget, 0) then
		return false
	end
	data.Benches[benchKey(bench)] = { GadgetId = gadgetId, Stored = 0 }
	return true
end

function BenchService.Init()
	for _, lab in labsFolder:GetChildren() do
		if lab:IsA("Model") then
			for _, bench in getBenches(lab) do
				bench.Touched:Connect(function(hit)
					onBenchTouched(bench, hit)
				end)
			end
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
