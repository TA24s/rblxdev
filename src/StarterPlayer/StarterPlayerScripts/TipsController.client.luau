--!strict
-- TipsController
-- Walks a new player through their first few minutes: a tip banner under the Bolts counter and a
-- glowing line from their character to what the tip is about. Each tip finishes when the player
-- has done it (or after a few seconds for tips that only explain something). Progress is saved
-- by TipsService, so finished tips don't come back next visit. "Skip tips" ends them all.
-- Container: StarterPlayer/StarterPlayerScripts

----- Services -----
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

----- Types -----
type Tip = {
	text: string,
	target: () -> BasePart?, -- what the glowing line points at, or nil for no line
	isDone: () -> boolean,
	readSeconds: number?, -- for tips that only explain: done after this long on screen
}

----- Constants -----
local CHECK_INTERVAL = 0.25 -- seconds between checks
local GUIDE_COLOR = Color3.fromRGB(255, 220, 60)
local NEAR_BENCH = 6 -- studs; standing this close to your bench counts as collecting
local BANNER_FADE = TweenInfo.new(0.3)

----- Variables -----
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local progressRemote = remotes:WaitForChild("TipsProgress") :: RemoteEvent
local labsFolder = workspace:WaitForChild("Map"):WaitForChild("Labs")
local beltFolder = workspace:WaitForChild("ConveyorGadgets")

----- Private Functions -----
local function myLab(): Model?
	local index = player:GetAttribute("LabIndex")
	for _, lab in labsFolder:GetChildren() do
		if lab:IsA("Model") and index ~= nil and lab:GetAttribute("LabIndex") == index then
			return lab
		end
	end
	return nil
end

local function myRoot(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function bolts(): number
	local leaderstats = player:FindFirstChild("leaderstats")
	local value = leaderstats and leaderstats:FindFirstChild("Bolts")
	return if value and value:IsA("IntValue") then value.Value else 0
end

-- Benches in my lab that have a gadget on them (BenchService puts a BenchLabel on those)
local function myFilledBenches(): { BasePart }
	local filled = {}
	local lab = myLab()
	local benches = lab and lab:FindFirstChild("Benches")
	if benches then
		for _, bench in benches:GetChildren() do
			if bench:IsA("BasePart") and bench:FindFirstChild("BenchLabel") then
				table.insert(filled, bench)
			end
		end
	end
	return filled
end

local function nearest(parts: { BasePart }): BasePart?
	local root = myRoot()
	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, part in parts do
		local distance = if root then (part.Position - root.Position).Magnitude else 0
		if distance < bestDistance then
			best, bestDistance = part, distance
		end
	end
	return best
end

-- The closest gadget on the conveyor that I can afford (or any, if none is affordable)
local function affordableBeltGadget(): BasePart?
	local affordable, any = {}, {}
	for _, model in beltFolder:GetChildren() do
		local base = model:IsA("Model") and model.PrimaryPart
		if base then
			table.insert(any, base)
			local cost = model:GetAttribute("Cost")
			if typeof(cost) == "number" and cost <= bolts() then
				table.insert(affordable, base)
			end
		end
	end
	return nearest(if #affordable > 0 then affordable else any)
end

local function gateButton(): BasePart?
	local lab = myLab()
	local model = lab and lab:FindFirstChild("GateButton")
	local button = model and model:FindFirstChild("Button")
	return if button and button:IsA("BasePart") then button else nil
end

local function isNearFilledBench(): boolean
	local root = myRoot()
	if not root then
		return false
	end
	for _, bench in myFilledBenches() do
		local flat = (bench.Position - root.Position) * Vector3.new(1, 0, 1)
		if flat.Magnitude <= NEAR_BENCH then
			return true
		end
	end
	return false
end

local function isGateLocked(): boolean
	local lab = myLab()
	local lockedUntil = lab and lab:GetAttribute("GateLockedUntil")
	return typeof(lockedUntil) == "number" and workspace:GetServerTimeNow() < lockedUntil
end

local function holdingGlove(): boolean
	local character = player.Character
	return character ~= nil and character:FindFirstChild("BoingGlove") ~= nil
end

-- The tips, in order. TipsService's TIP_COUNT must match how many there are.
local TIPS: { Tip } = {
	{
		text = "Buy your first gadget! Walk to the conveyor and hold E on one you can afford.",
		target = affordableBeltGadget,
		isDone = function()
			return #myFilledBenches() > 0
		end,
	},
	{
		text = "Your gadget is making Bolts! Step on its bench to collect them.",
		target = function()
			return nearest(myFilledBenches())
		end,
		isDone = isNearFilledBench,
	},
	{
		text = "Thieves can raid your lab! Hold E on the glowing button by your gate to lock it.",
		target = gateButton,
		isDone = isGateLocked,
	},
	{
		text = "Other labs have gadgets too. Walk in, hold E on one to grab it, and run it back to your lab's dock!",
		target = function()
			return nil
		end,
		isDone = function()
			return false
		end,
		readSeconds = 10,
	},
	{
		text = "Press 1 for your Boing Glove. Bounce thieves to get your gadgets back!",
		target = function()
			return nil
		end,
		isDone = holdingGlove,
		readSeconds = 12,
	},
}

local function buildBanner(): (Frame, TextLabel, TextLabel, TextButton)
	local gui = Instance.new("ScreenGui")
	gui.Name = "Tips"
	gui.ResetOnSpawn = false

	local frame = Instance.new("Frame")
	frame.Name = "Banner"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 76) -- just under the Bolts counter
	frame.Size = UDim2.new(0.92, 0, 0, 74)
	frame.BackgroundColor3 = Color3.fromRGB(35, 25, 60)
	frame.BackgroundTransparency = 0.1
	frame.Visible = false
	frame.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(560, 74)
	limit.Parent = frame
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = GUIDE_COLOR
	stroke.Thickness = 2
	stroke.Parent = frame

	local step = Instance.new("TextLabel")
	step.Name = "Step"
	step.Position = UDim2.fromOffset(14, 6)
	step.Size = UDim2.new(1, -110, 0, 18)
	step.BackgroundTransparency = 1
	step.Font = Enum.Font.FredokaOne
	step.TextSize = 15
	step.TextXAlignment = Enum.TextXAlignment.Left
	step.TextColor3 = GUIDE_COLOR
	step.Parent = frame

	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.Position = UDim2.fromOffset(14, 24)
	text.Size = UDim2.new(1, -28, 1, -30)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextWrapped = true
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextColor3 = Color3.new(1, 1, 1)
	text.Parent = frame
	local textLimit = Instance.new("UITextSizeConstraint")
	textLimit.MaxTextSize = 20
	textLimit.Parent = text

	local skip = Instance.new("TextButton")
	skip.Name = "Skip"
	skip.AnchorPoint = Vector2.new(1, 0)
	skip.Position = UDim2.new(1, -8, 0, 5)
	skip.Size = UDim2.fromOffset(88, 20)
	skip.BackgroundTransparency = 1
	skip.Font = Enum.Font.FredokaOne
	skip.TextSize = 14
	skip.TextColor3 = Color3.fromRGB(190, 180, 220)
	skip.Text = "Skip tips ✕"
	skip.Parent = frame

	gui.Parent = player:WaitForChild("PlayerGui")
	return frame, step, text, skip
end

-- A glowing line from the character to the target, with a bouncing arrow above the target
local function buildGuide(): (Beam, Attachment, BillboardGui)
	local targetAttachment = Instance.new("Attachment")
	targetAttachment.Name = "TipTarget"
	local beam = Instance.new("Beam")
	beam.Name = "TipGuide"
	beam.Color = ColorSequence.new(GUIDE_COLOR)
	beam.Transparency = NumberSequence.new(0.6, 0.1)
	beam.LightEmission = 1
	beam.Width0 = 0.4
	beam.Width1 = 0.4
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Attachment1 = targetAttachment

	local arrow = Instance.new("BillboardGui")
	arrow.Name = "TipArrow"
	arrow.Size = UDim2.fromOffset(60, 60)
	arrow.AlwaysOnTop = true
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = GUIDE_COLOR
	label.TextStrokeTransparency = 0
	label.Text = "⬇"
	label.Parent = arrow
	return beam, targetAttachment, arrow
end

----- Initialization -----
while not player:GetAttribute("DataLoaded") do
	player:GetAttributeChangedSignal("DataLoaded"):Wait()
end
local deadline = os.clock() + 10
while typeof(player:GetAttribute("TipsDone")) ~= "number" and os.clock() < deadline do
	task.wait(0.2)
end
local done = player:GetAttribute("TipsDone")
local current = (if typeof(done) == "number" then done else 0) + 1
if current > #TIPS then
	return -- every tip finished on an earlier visit
end

local banner, stepLabel, textLabel, skipButton = buildBanner()
local beam, targetAttachment, arrow = buildGuide()
local shownAt = os.clock()
local sinceCheck = 0
local finished = false

local function hideGuide()
	beam.Parent = nil
	arrow.Parent = nil
	targetAttachment.Parent = nil
end

local function finish()
	finished = true
	hideGuide()
	TweenService:Create(banner, BANNER_FADE, { BackgroundTransparency = 1 }):Play()
	task.delay(BANNER_FADE.Time, function()
		banner.Visible = false
	end)
end

local function show(index: number)
	local tip = TIPS[index]
	stepLabel.Text = `TIP {index} OF {#TIPS}`
	textLabel.Text = tip.text
	banner.Visible = true
	shownAt = os.clock()
end

-- Points the line and arrow at the current tip's target, or hides them
local function updateGuide(tip: Tip)
	local target = tip.target()
	local root = myRoot()
	local rootAttachment = root and root:FindFirstChild("RootAttachment")
	if not (target and rootAttachment and rootAttachment:IsA("Attachment")) then
		hideGuide()
		return
	end
	if targetAttachment.Parent ~= target then
		targetAttachment.Parent = target
	end
	beam.Attachment0 = rootAttachment
	beam.Parent = target
	arrow.Adornee = target
	arrow.StudsOffsetWorldSpace = Vector3.new(0, 5 + math.sin(os.clock() * 4) * 0.6, 0)
	arrow.Parent = target
end

skipButton.Activated:Connect(function()
	progressRemote:FireServer(#TIPS)
	finish()
end)

show(current)
RunService.Heartbeat:Connect(function(deltaTime)
	if finished then
		return
	end
	local tip = TIPS[current]
	updateGuide(tip)
	sinceCheck += deltaTime
	if sinceCheck < CHECK_INTERVAL then
		return
	end
	sinceCheck = 0
	local readEnough = tip.readSeconds ~= nil and os.clock() - shownAt >= tip.readSeconds
	if tip.isDone() or readEnough then
		progressRemote:FireServer(current)
		current += 1
		if current > #TIPS then
			finish()
		else
			show(current)
		end
	end
end)
