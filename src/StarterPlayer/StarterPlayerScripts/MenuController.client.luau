--!strict
-- MenuController
-- The menu buttons on the left (Upgrades, Index, Settings), the green Upgrade button next to the
-- Boing Glove, and their panels:
-- * Upgrades: buy More Benches, Better Gate and Income Boost (MenuService checks the price again).
-- * Index: every gadget, with the ones you've owned shown in 3D and the rest as dark shapes,
--   plus the rarity guide.
-- * Settings: Music and SFX switches, saved with your progress.
-- The look (buttons and panels) comes from Shared/Ui.
-- Container: StarterPlayer/StarterPlayerScripts

----- Services -----
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

----- Modules -----
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Ui = require(Shared:WaitForChild("Ui"))
local Gadgets = require(Config:WaitForChild("Gadgets"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Upgrades = require(Config:WaitForChild("Upgrades"))

----- Constants -----
local C = Ui.Colors
local UPGRADES_ACCENT = C.Green
local INDEX_ACCENT = C.Cyan
local SETTINGS_ACCENT = Color3.fromRGB(150, 160, 255)
local INDEX_SPIN = 40 -- degrees per second for the 3D gadgets in the Index
local SWITCH_TWEEN = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

----- Types -----
type UpgradeRow = {
	kind: string,
	describe: () -> (string, number?), -- "now → next" text, and the price (nil when maxed)
	line: TextLabel,
	buy: TextButton,
}

----- Variables -----
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local upgradeRemote = remotes:WaitForChild("UpgradeRequest") :: RemoteEvent
local settingRemote = remotes:WaitForChild("SettingChanged") :: RemoteEvent
local upgradeRows: { UpgradeRow } = {}
local indexCards: { [string]: { viewport: ViewportFrame, model: Model?, name: TextLabel, income: TextLabel } } = {}
local spinConnection: RBXScriptConnection? = nil

----- Private Functions -----
local function attribute(name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function bolts(): number
	local leaderstats = player:FindFirstChild("leaderstats")
	local value = leaderstats and leaderstats:FindFirstChild("Bolts")
	return if value and value:IsA("IntValue") then value.Value else 0
end

----- Upgrades panel -----
local function addUpgradeRow(parent: Instance, order: number, kind: string, icon: string, title: string, description: string, describe: () -> (string, number?))
	local row = Instance.new("Frame")
	row.Name = kind
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, 88)
	row.BackgroundColor3 = C.Row
	row.Parent = parent
	Ui.Corner(row, 14)
	Ui.Border(row, UPGRADES_ACCENT, 1.5).Transparency = 0.55

	local iconBox = Instance.new("Frame")
	iconBox.Name = "IconBox"
	iconBox.AnchorPoint = Vector2.new(0, 0.5)
	iconBox.Position = UDim2.new(0, 10, 0.5, 0)
	iconBox.Size = UDim2.fromOffset(64, 64)
	iconBox.BackgroundColor3 = Color3.new(1, 1, 1)
	iconBox.Parent = row
	Ui.Corner(iconBox, 12)
	Ui.Gradient(iconBox, Color3.fromRGB(80, 70, 170), Color3.fromRGB(40, 30, 95))
	Ui.Border(iconBox, Color3.new(1, 1, 1), 1.5).Transparency = 0.5
	local iconLabel = Ui.Text("Icon", iconBox, icon, 1)
	iconLabel.Size = UDim2.fromScale(1, 1)
	iconLabel.TextScaled = true
	local iconPadding = Instance.new("UIPadding")
	iconPadding.PaddingTop = UDim.new(0, 10)
	iconPadding.PaddingBottom = UDim.new(0, 10)
	iconPadding.Parent = iconLabel

	local titleLabel = Ui.Text("Title", row, title, 21)
	titleLabel.Position = UDim2.fromOffset(86, 8)
	titleLabel.Size = UDim2.new(1, -230, 0, 24)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	Ui.TextOutline(titleLabel)
	local descriptionLabel = Ui.Text("Description", row, description, 14, C.Muted)
	descriptionLabel.Font = Enum.Font.GothamMedium
	descriptionLabel.Position = UDim2.fromOffset(86, 33)
	descriptionLabel.Size = UDim2.new(1, -230, 0, 18)
	descriptionLabel.TextXAlignment = Enum.TextXAlignment.Left
	descriptionLabel.TextTruncate = Enum.TextTruncate.AtEnd
	local line = Ui.Text("Change", row, "", 17, C.Cyan)
	line.Position = UDim2.fromOffset(86, 56)
	line.Size = UDim2.new(1, -230, 0, 22)
	line.TextXAlignment = Enum.TextXAlignment.Left
	line.RichText = true

	local buy = Ui.TextButton("Buy", row, "")
	buy.AnchorPoint = Vector2.new(1, 0.5)
	buy.Position = UDim2.new(1, -12, 0.5, 0)
	buy.Size = UDim2.fromOffset(130, 46)
	buy.Activated:Connect(function()
		local _, cost = describe()
		if cost and bolts() >= cost then
			upgradeRemote:FireServer(kind)
		end
	end)

	table.insert(upgradeRows, { kind = kind, describe = describe, line = line, buy = buy })
end

local function refreshUpgrades()
	for _, row in upgradeRows do
		local text, cost = row.describe()
		row.line.Text = text
		if not cost then
			row.buy.Text = "MAX"
			Ui.SetButtonColor(row.buy, C.Bolt, Color3.fromRGB(200, 120, 20))
		else
			row.buy.Text = `⚙ {Ui.FormatNumber(cost)}`
			if bolts() >= cost then
				Ui.SetButtonColor(row.buy, C.Green, C.GreenDark)
			else
				Ui.SetButtonColor(row.buy, C.Disabled, Color3.fromRGB(60, 58, 75))
			end
		end
	end
end

-- "60s → <green>75s</green>"
local function change(now: string, nextValue: string): string
	return `{now}  →  <font color="#5BFF8A">{nextValue}</font>`
end

local function buildUpgradesPanel()
	local panel = Ui.NewPanel("Upgrades", "⬆ Lab Upgrades", UPGRADES_ACCENT, Vector2.new(540, 380))
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = panel.Content

	addUpgradeRow(panel.Content, 1, "Bench", "📦", "More Benches", "Room for one more gadget in your lab.", function()
		local extra = attribute("ExtraBenches")
		local now = Upgrades.BaseBenches + extra
		local cost = Upgrades.BenchUnlockCosts[extra + 1]
		if not cost then
			return `{now} benches (all unlocked)`, nil
		end
		return change(`{now} benches`, `{now + 1}`), cost
	end)
	addUpgradeRow(panel.Content, 2, "Gate", "🛡️", "Better Gate", "Your gate lock lasts longer.", function()
		local level = attribute("GateLevel")
		local now = Upgrades.GateLockSeconds[level + 1]
		local cost = Upgrades.GateUpgradeCosts[level + 1]
		if not cost then
			return `{now}s lock (best gate)`, nil
		end
		return change(`{now}s lock`, `{Upgrades.GateLockSeconds[level + 2]}s`), cost
	end)
	addUpgradeRow(panel.Content, 3, "Income", "💰", "Income Boost", "Every gadget earns more Bolts.", function()
		local level = attribute("IncomeLevel")
		local per = Upgrades.IncomeBoostPerLevel * 100
		local now = math.floor(per * level + 0.5)
		local cost = Upgrades.IncomeBoostCosts[level + 1]
		if not cost then
			return `+{now}% income (maxed)`, nil
		end
		return change(`+{now}%`, `+{math.floor(per * (level + 1) + 0.5)}%`), cost
	end)

	local note = Ui.Text("Note", panel.Content, "Upgrades are kept when you rebirth, except benches.", 14, C.Muted)
	note.Font = Enum.Font.GothamMedium
	note.LayoutOrder = 10
	note.Size = UDim2.new(1, 0, 0, 20)

	panel.OnOpen = refreshUpgrades
end

----- Index panel -----
-- Moves the gadget's centre to the middle of its little 3D window (so it spins on the spot)
-- and points the camera at it
local function frameModel(viewport: ViewportFrame, model: Model)
	local boxCFrame, boxSize = model:GetBoundingBox()
	model.WorldPivot = CFrame.new(boxCFrame.Position)
	model:PivotTo(CFrame.new())
	local radius = boxSize.Magnitude / 2
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	local distance = radius / math.tan(math.rad(camera.FieldOfView / 2)) * 1.05
	camera.CFrame = CFrame.lookAt(Vector3.new(0, radius * 0.35, distance), Vector3.zero)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
end

local function sortedGadgets(): { Gadgets.Gadget }
	local list: { Gadgets.Gadget } = {}
	for _, gadget in Gadgets do
		table.insert(list, gadget)
	end
	table.sort(list, function(a, b)
		local ra, rb = Rarities[a.Rarity].Order, Rarities[b.Rarity].Order
		if ra ~= rb then
			return ra < rb
		end
		return a.Cost < b.Cost
	end)
	return list
end

local function refreshIndex(countLabel: TextLabel)
	local found, total = 0, 0
	for id, card in indexCards do
		total += 1
		local gadget = Gadgets[id]
		local isFound = player:GetAttribute(`Found_{id}`) == true
		if isFound then
			found += 1
		end
		-- Not found yet: a black shape and question marks
		card.viewport.ImageColor3 = if isFound then Color3.new(1, 1, 1) else Color3.new(0, 0, 0)
		card.viewport.ImageTransparency = if isFound then 0 else 0.25
		card.name.Text = if isFound then gadget.DisplayName else "???"
		card.income.Text = if isFound then `⚙ {Ui.FormatNumber(gadget.Income)}/s` else "⚙ ?/s"
	end
	countLabel.Text = `Found {found} / {total} gadgets`
end

local function buildIndexPanel()
	local panel = Ui.NewPanel("Index", "📖 Gadget Index", INDEX_ACCENT, Vector2.new(620, 430))
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = panel.Content

	local countLabel = Ui.Text("Count", panel.Content, "", 18, C.Cyan)
	countLabel.LayoutOrder = 1
	countLabel.Size = UDim2.new(1, 0, 0, 22)
	countLabel.TextXAlignment = Enum.TextXAlignment.Left

	local grid = Instance.new("Frame")
	grid.Name = "Grid"
	grid.LayoutOrder = 2
	grid.Size = UDim2.fromScale(1, 0)
	grid.AutomaticSize = Enum.AutomaticSize.Y
	grid.BackgroundTransparency = 1
	grid.Parent = panel.Content
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.fromOffset(128, 160)
	gridLayout.CellPadding = UDim2.fromOffset(10, 10)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid

	local previews = ReplicatedStorage:WaitForChild("GadgetPreviews")
	for order, gadget in sortedGadgets() do
		local rarity = Rarities[gadget.Rarity]
		local card = Instance.new("Frame")
		card.Name = gadget.Id
		card.LayoutOrder = order
		card.BackgroundColor3 = Color3.new(1, 1, 1)
		card.Parent = grid
		Ui.Corner(card, 12)
		Ui.Gradient(card, rarity.Color:Lerp(C.Panel, 0.6), C.PanelDark)
		Ui.Border(card, rarity.Color, 2)

		local viewport = Instance.new("ViewportFrame")
		viewport.Name = "Model"
		viewport.Position = UDim2.fromOffset(6, 4)
		viewport.Size = UDim2.new(1, -12, 0, 92)
		viewport.BackgroundTransparency = 1
		viewport.Ambient = Color3.fromRGB(170, 160, 200)
		viewport.LightDirection = Vector3.new(-1, -1, -1)
		viewport.Parent = card
		local source = previews:FindFirstChild(gadget.Id)
		local model: Model? = nil
		if source and source:IsA("Model") then
			local copy = source:Clone()
			copy.Parent = viewport
			frameModel(viewport, copy)
			model = copy
		end

		local nameLabel = Ui.Text("GadgetName", card, "", 1)
		nameLabel.Position = UDim2.fromOffset(4, 96)
		nameLabel.Size = UDim2.new(1, -8, 0, 30)
		nameLabel.TextScaled = true
		Ui.TextOutline(nameLabel, 1.5)
		local sizeLimit = Instance.new("UITextSizeConstraint")
		sizeLimit.MaxTextSize = 16
		sizeLimit.Parent = nameLabel
		local rarityLabel = Ui.Text("Rarity", card, rarity.DisplayName, 14, rarity.Color)
		rarityLabel.Position = UDim2.fromOffset(4, 125)
		rarityLabel.Size = UDim2.new(1, -8, 0, 16)
		Ui.TextOutline(rarityLabel, 1.5)
		local incomeLabel = Ui.Text("Income", card, "", 13, C.Bolt)
		incomeLabel.Position = UDim2.fromOffset(4, 141)
		incomeLabel.Size = UDim2.new(1, -8, 0, 15)
		Ui.TextOutline(incomeLabel, 1.5)

		indexCards[gadget.Id] = { viewport = viewport, model = model, name = nameLabel, income = incomeLabel }
	end

	-- Rarity guide: one badge per tier, most common first
	local guideTitle = Ui.Text("GuideTitle", panel.Content, "Rarity Guide", 18, C.Cyan)
	guideTitle.LayoutOrder = 3
	guideTitle.Size = UDim2.new(1, 0, 0, 22)
	guideTitle.TextXAlignment = Enum.TextXAlignment.Left
	local guide = Instance.new("Frame")
	guide.Name = "RarityGuide"
	guide.LayoutOrder = 4
	guide.Size = UDim2.fromScale(1, 0)
	guide.AutomaticSize = Enum.AutomaticSize.Y
	guide.BackgroundTransparency = 1
	guide.Parent = panel.Content
	local guideLayout = Instance.new("UIGridLayout")
	guideLayout.CellSize = UDim2.fromOffset(76, 66)
	guideLayout.CellPadding = UDim2.fromOffset(6, 6)
	guideLayout.SortOrder = Enum.SortOrder.LayoutOrder
	guideLayout.Parent = guide
	for _, rarity in Rarities do
		local badge = Instance.new("Frame")
		badge.Name = rarity.Id
		badge.LayoutOrder = rarity.Order
		badge.BackgroundTransparency = 1
		badge.Parent = guide
		local gem = Instance.new("Frame")
		gem.Name = "Gem"
		gem.AnchorPoint = Vector2.new(0.5, 0)
		gem.Position = UDim2.fromScale(0.5, 0)
		gem.Size = UDim2.fromOffset(38, 38)
		gem.Rotation = 45
		gem.BackgroundColor3 = Color3.new(1, 1, 1)
		gem.Parent = badge
		Ui.Corner(gem, 8)
		Ui.Gradient(gem, rarity.Color:Lerp(Color3.new(1, 1, 1), 0.35), rarity.Color:Lerp(Color3.new(0, 0, 0), 0.35))
		Ui.Border(gem, Color3.new(1, 1, 1), 2)
		local star = Ui.Text("Star", badge, "★", 20)
		star.AnchorPoint = Vector2.new(0.5, 0)
		star.Position = UDim2.fromScale(0.5, 0)
		star.Size = UDim2.fromOffset(38, 38)
		Ui.TextOutline(star, 1.5)
		local name = Ui.Text("RarityName", badge, rarity.DisplayName, 13, rarity.Color)
		name.AnchorPoint = Vector2.new(0.5, 1)
		name.Position = UDim2.fromScale(0.5, 1)
		name.Size = UDim2.new(1, 0, 0, 16)
		Ui.TextOutline(name, 1.5)
	end

	-- The 3D gadgets turn slowly, only while the Index is open
	local angle = 0
	panel.OnOpen = function()
		refreshIndex(countLabel)
		if spinConnection then
			spinConnection:Disconnect()
		end
		spinConnection = RunService.RenderStepped:Connect(function(deltaTime)
			angle += math.rad(INDEX_SPIN) * deltaTime
			for _, card in indexCards do
				if card.model then
					card.model:PivotTo(CFrame.Angles(0, angle, 0))
				end
			end
		end)
	end
	panel.OnClose = function()
		if spinConnection then
			spinConnection:Disconnect()
			spinConnection = nil
		end
	end
	-- A newly found gadget shows up straight away if the Index is open
	player.AttributeChanged:Connect(function(name)
		if name:sub(1, 6) == "Found_" and Ui.IsOpen("Index") then
			refreshIndex(countLabel)
		end
	end)
end

----- Settings panel -----
local function addSwitch(parent: Instance, order: number, icon: string, title: string, setting: string)
	local row = Instance.new("Frame")
	row.Name = setting
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, 58)
	row.BackgroundColor3 = C.Row
	row.Parent = parent
	Ui.Corner(row, 12)
	Ui.Border(row, SETTINGS_ACCENT, 1.5).Transparency = 0.55
	local label = Ui.Text("Label", row, `{icon}  {title}`, 21)
	label.Position = UDim2.fromOffset(16, 0)
	label.Size = UDim2.new(1, -110, 1, 0)
	label.TextXAlignment = Enum.TextXAlignment.Left
	Ui.TextOutline(label)

	local switch = Instance.new("TextButton")
	switch.Name = "Switch"
	switch.AnchorPoint = Vector2.new(1, 0.5)
	switch.Position = UDim2.new(1, -14, 0.5, 0)
	switch.Size = UDim2.fromOffset(70, 34)
	switch.BackgroundColor3 = C.Green
	switch.AutoButtonColor = false
	switch.Text = ""
	switch.Parent = row
	Ui.Corner(switch, 17)
	Ui.Border(switch, Color3.new(1, 1, 1), 2).Transparency = 0.4
	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.AnchorPoint = Vector2.new(0, 0.5)
	knob.Size = UDim2.fromOffset(26, 26)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.Parent = switch
	Ui.Corner(knob, 13)

	local function show(on: boolean)
		TweenService:Create(switch, SWITCH_TWEEN, { BackgroundColor3 = if on then C.Green else C.Disabled }):Play()
		TweenService:Create(knob, SWITCH_TWEEN, { Position = if on then UDim2.new(1, -30, 0.5, 0) else UDim2.new(0, 4, 0.5, 0) }):Play()
	end
	local attributeName = `Setting{setting}`
	switch.Activated:Connect(function()
		local on = player:GetAttribute(attributeName) == false -- flip it
		player:SetAttribute(attributeName, on) -- straight away here; the server saves it
		settingRemote:FireServer(setting, on)
	end)
	player:GetAttributeChangedSignal(attributeName):Connect(function()
		show(player:GetAttribute(attributeName) ~= false)
	end)
	show(player:GetAttribute(attributeName) ~= false)
end

local function buildSettingsPanel()
	local panel = Ui.NewPanel("Settings", "⚙️ Settings", SETTINGS_ACCENT, Vector2.new(380, 190))
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = panel.Content
	addSwitch(panel.Content, 1, "🎵", "Music", "Music")
	addSwitch(panel.Content, 2, "🔊", "Sound effects", "Sfx")
end

----- Initialization -----
while not player:GetAttribute("DataLoaded") do
	player:GetAttributeChangedSignal("DataLoaded"):Wait()
end
local leaderstats = player:WaitForChild("leaderstats")
local boltsValue = leaderstats:WaitForChild("Bolts") :: IntValue

buildUpgradesPanel()
buildIndexPanel()
buildSettingsPanel()

-- Left-hand menu
local side = Ui.GetSideBar()
local upgradesButton = Ui.IconButton("Upgrades", side, "⬆️", "Upgrades", Color3.fromRGB(90, 80, 200), Color3.fromRGB(40, 30, 110), 72)
upgradesButton.LayoutOrder = 1
local indexButton = Ui.IconButton("Index", side, "📖", "Index", Color3.fromRGB(70, 150, 230), Color3.fromRGB(30, 60, 140), 72)
indexButton.LayoutOrder = 2
local settingsButton = Ui.IconButton("Settings", side, "⚙️", "Settings", Color3.fromRGB(60, 200, 190), Color3.fromRGB(20, 95, 110), 72)
settingsButton.LayoutOrder = 3

-- Green Upgrade button next to the Boing Glove
local upgradeButton = Ui.IconButton("Upgrade", Ui.GetBottomBar(), "▲", "Upgrade", C.Green, C.GreenDark, 76)
upgradeButton.LayoutOrder = 1

upgradesButton.Activated:Connect(function()
	Ui.Toggle("Upgrades")
end)
upgradeButton.Activated:Connect(function()
	Ui.Toggle("Upgrades")
end)
indexButton.Activated:Connect(function()
	Ui.Toggle("Index")
end)
settingsButton.Activated:Connect(function()
	Ui.Toggle("Settings")
end)

-- Keep the prices and levels up to date while the Upgrades panel is open
boltsValue.Changed:Connect(function()
	if Ui.IsOpen("Upgrades") then
		refreshUpgrades()
	end
end)
player.AttributeChanged:Connect(function(name)
	if (name == "ExtraBenches" or name == "GateLevel" or name == "IncomeLevel") and Ui.IsOpen("Upgrades") then
		refreshUpgrades()
	end
end)
