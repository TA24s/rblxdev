--!strict
-- GrudgeService
-- Professor Grudge's Lab (Workspace.Map.GrudgeLab, built by tools/build-grudge-lab.luau): a rival
-- lab run by a grumpy inventor that anyone can always steal from, so a player alone in a server
-- can still learn stealing. His three benches each hold a random Common, Uncommon or Rare gadget.
-- Hold E to grab one and carry it home like any stolen gadget (StealService.StartNpcSteal). A
-- stolen gadget is restocked after a while, and a thief has to wait before robbing him again.
-- Container: ServerScriptService/Services

----- Services -----
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

----- Modules -----
local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Gadgets = require(Config:WaitForChild("Gadgets"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Stealing = require(Config:WaitForChild("Stealing"))
local NotifyService = require(script.Parent:WaitForChild("NotifyService"))
local StealService = require(script.Parent:WaitForChild("StealService"))

----- Constants -----
local NPC_NAME = "Professor Grudge"
local RARITY_WEIGHTS = { Common = 60, Uncommon = 30, Rare = 10 } -- chance of each rarity on his benches
local RESTOCK_SECONDS = 45 -- an empty bench gets a new gadget after this long
local THIEF_COOLDOWN_SECONDS = 120 -- a thief must wait this long before robbing him again
local PROMPT_DISTANCE = 8
local SPEECH_SECONDS = 4
local LINES = {
	Started = { "Hey! Put that DOWN!", "Thief! THIEF!", "That's MY invention!", "Not my gadget!" },
	Stolen = { "Curses! Foiled again!", "I'll invent a better one!", "You'll regret this!", "Grrr... fine. FINE." },
	Back = { "Ha! Back where it belongs.", "Too slow, little thief!", "Mwahaha! Mine again!" },
}

----- Types -----
type Bench = {
	part: BasePart,
	prompt: ProximityPrompt,
	label: TextLabel,
	gadgetId: string?,
	model: Model?,
	carried: boolean,
	restockAt: number?, -- os.clock() time a new gadget appears
}

----- Variables -----
local modelsFolder = ServerStorage:WaitForChild("GadgetModels")
local benches: { Bench } = {}
local cooldowns: { [Player]: number } = {} -- os.clock() time each thief may rob him again
local gadgetsFolder: Folder? = nil
local speech: BillboardGui? = nil
local speechToken = 0

local GrudgeService = {}

----- Private Functions -----
local function say(kind: string)
	local gui = speech
	if not gui then
		return
	end
	local options = LINES[kind]
	local line = gui:FindFirstChild("Line", true)
	if line and line:IsA("TextLabel") then
		line.Text = options[math.random(#options)]
	end
	gui.Enabled = true
	speechToken += 1
	local token = speechToken
	task.delay(SPEECH_SECONDS, function()
		if speechToken == token then
			gui.Enabled = false
		end
	end)
end

-- A random gadget of a rarity Grudge keeps, picked by RARITY_WEIGHTS
local function pickGadget(): string?
	local pool: { { id: string, weight: number } } = {}
	local total = 0
	for id, gadget in Gadgets do
		local rarityWeight = RARITY_WEIGHTS[gadget.Rarity]
		if rarityWeight and modelsFolder:FindFirstChild(id) then
			-- Share the rarity's weight between its gadgets so each rarity keeps its overall chance
			local count = 0
			for _, other in Gadgets do
				if other.Rarity == gadget.Rarity and modelsFolder:FindFirstChild(other.Id) then
					count += 1
				end
			end
			table.insert(pool, { id = id, weight = rarityWeight / count })
			total += rarityWeight / count
		end
	end
	local roll = math.random() * total
	for _, entry in pool do
		roll -= entry.weight
		if roll <= 0 then
			return entry.id
		end
	end
	return if #pool > 0 then pool[#pool].id else nil
end

local function setLabel(bench: Bench)
	local gadget = bench.gadgetId and Gadgets[bench.gadgetId]
	if bench.carried then
		bench.label.Text = "Being stolen!"
		bench.label.TextColor3 = Color3.fromRGB(255, 90, 110)
	elseif gadget then
		bench.label.Text = gadget.DisplayName
		bench.label.TextColor3 = Rarities[gadget.Rarity].Color
	elseif bench.restockAt then
		bench.label.Text = `Restocking in {math.max(0, math.ceil(bench.restockAt - os.clock()))}s`
		bench.label.TextColor3 = Color3.fromRGB(200, 200, 210)
	else
		bench.label.Text = ""
	end
end

local function setModelVisible(model: Model, visible: boolean)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local original = part:GetAttribute("GrudgeTransparency")
			if original == nil then
				part:SetAttribute("GrudgeTransparency", part.Transparency)
				original = part.Transparency
			end
			part.Transparency = if visible then original :: number else 1
		elseif part:IsA("BillboardGui") or part:IsA("SurfaceGui") then
			part.Enabled = visible
		elseif part:IsA("ParticleEmitter") or part:IsA("Light") then
			part.Enabled = visible
		end
	end
end

local function stock(bench: Bench)
	if bench.model then
		bench.model:Destroy()
		bench.model = nil
	end
	bench.gadgetId = nil
	bench.carried = false
	bench.restockAt = nil
	local id = pickGadget()
	local template = id and modelsFolder:FindFirstChild(id)
	if not (id and template and template:IsA("Model")) then
		warn("[GrudgeService] No gadget models to stock his benches with")
		bench.prompt.Enabled = false
		setLabel(bench)
		return
	end
	local model = template:Clone()
	model:PivotTo(bench.part.CFrame * CFrame.new(0, bench.part.Size.Y / 2 + 0.1, 0))
	model.Parent = gadgetsFolder
	bench.model = model
	bench.gadgetId = id
	local gadget = Gadgets[id]
	bench.prompt.ObjectText = gadget.DisplayName
	bench.prompt.HoldDuration = Stealing.HoldSeconds[gadget.Rarity] or 1
	bench.prompt.Enabled = true
	setLabel(bench)
end

local function onTriggered(bench: Bench, thief: Player)
	local gadgetId = bench.gadgetId
	if not gadgetId or bench.carried then
		return
	end
	local readyAt = cooldowns[thief]
	if readyAt and os.clock() < readyAt then
		NotifyService.Send(thief, `Professor Grudge is watching you... try again in {math.ceil(readyAt - os.clock())}s.`)
		return
	end
	local started = StealService.StartNpcSteal(thief, bench.part, bench.prompt, gadgetId, {
		name = NPC_NAME,
		giveBack = function()
			bench.carried = false
			if bench.model then
				setModelVisible(bench.model, true)
			end
			bench.prompt.Enabled = bench.gadgetId ~= nil
			setLabel(bench)
			say("Back")
		end,
		take = function(who: Player): boolean
			if not (bench.carried and bench.gadgetId == gadgetId) then
				return false
			end
			if bench.model then
				bench.model:Destroy()
				bench.model = nil
			end
			bench.gadgetId = nil
			bench.carried = false
			bench.restockAt = os.clock() + RESTOCK_SECONDS
			cooldowns[who] = os.clock() + THIEF_COOLDOWN_SECONDS
			setLabel(bench)
			say("Stolen")
			return true
		end,
	})
	if not started then
		return
	end
	bench.carried = true
	bench.prompt.Enabled = false
	if bench.model then
		setModelVisible(bench.model, false)
	end
	setLabel(bench)
	say("Started")
end

local function createLabel(part: BasePart): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = "GrudgeLabel"
	gui.Size = UDim2.fromOffset(160, 26)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 4.5, 0)
	gui.MaxDistance = 40
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	gui.Parent = part
	return label
end

local function setUpBench(part: BasePart)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StealPrompt"
	prompt.ActionText = "Steal"
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = part
	local bench: Bench = {
		part = part,
		prompt = prompt,
		label = createLabel(part),
		gadgetId = nil,
		model = nil,
		carried = false,
		restockAt = nil,
	}
	prompt.Triggered:Connect(function(player)
		onTriggered(bench, player)
	end)
	table.insert(benches, bench)
	stock(bench)
end

----- Public Functions -----
function GrudgeService.Init()
	local map = workspace:WaitForChild("Map")
	local lab = map:FindFirstChild("GrudgeLab")
	local benchFolder = lab and lab:FindFirstChild("Benches")
	if not (lab and benchFolder) then
		warn("[GrudgeService] Workspace.Map.GrudgeLab is missing; run tools/build-grudge-lab.luau")
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Gadgets"
	folder.Parent = lab
	gadgetsFolder = folder
	local prof = lab:FindFirstChild("ProfessorGrudge")
	local found = prof and prof:FindFirstChild("Speech", true)
	if found and found:IsA("BillboardGui") then
		speech = found
	end

	for _, part in benchFolder:GetChildren() do
		if part:IsA("BasePart") then
			setUpBench(part)
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		cooldowns[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			for _, bench in benches do
				if bench.restockAt and os.clock() >= bench.restockAt then
					stock(bench)
				elseif bench.restockAt then
					setLabel(bench)
				end
			end
		end
	end)
end

return GrudgeService
