--!strict
-- RebirthController
-- The ♻ Rebirth button on the left of the screen. It opens a panel showing what the next
-- rebirth costs, how close you are, and what you get and lose. Pressing "Rebirth!" asks the
-- server (RebirthService), which checks everything again before doing it.
-- Container: StarterPlayer/StarterPlayerScripts

----- Services -----
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

----- Modules -----
local Rebirth = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Rebirth"))

----- Constants -----
local REBIRTH_COLOR = Color3.fromRGB(80, 230, 140)
local PANEL_COLOR = Color3.fromRGB(35, 25, 60)
local DISABLED_COLOR = Color3.fromRGB(90, 90, 100)

----- Variables -----
local player = Players.LocalPlayer
local rebirthRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RebirthRequest") :: RemoteEvent

----- Private Functions -----
-- 1234567 -> "1,234,567"
local function formatNumber(n: number): string
	local text = tostring(math.floor(n))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

local function round(instance: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

local function newText(name: string, parent: Instance, position: UDim2, size: UDim2, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = color
	label.Parent = parent
	return label
end

local function newButton(name: string, parent: Instance, text: string, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.BackgroundColor3 = color
	button.Font = Enum.Font.FredokaOne
	button.TextScaled = true
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Text = text
	button.AutoButtonColor = true
	round(button, 10)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = button
	button.Parent = parent
	return button
end

----- Initialization -----
while not player:GetAttribute("DataLoaded") do
	player:GetAttributeChangedSignal("DataLoaded"):Wait()
end
local leaderstats = player:WaitForChild("leaderstats")
local bolts = leaderstats:WaitForChild("Bolts") :: IntValue
local rebirths = leaderstats:WaitForChild("Rebirths") :: IntValue

local gui = Instance.new("ScreenGui")
gui.Name = "Rebirth"
gui.ResetOnSpawn = false

-- The button that opens the panel
local openButton = newButton("OpenRebirth", gui, "♻ Rebirth", REBIRTH_COLOR)
openButton.AnchorPoint = Vector2.new(0, 0.5)
openButton.Position = UDim2.new(0, 12, 0.5, 0)
openButton.Size = UDim2.fromOffset(140, 44)
local openStroke = Instance.new("UIStroke")
openStroke.Thickness = 2
openStroke.Color = Color3.new(1, 1, 1)
openStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
openStroke.Parent = openButton

-- The panel
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.new(0.9, 0, 0, 280)
panel.BackgroundColor3 = PANEL_COLOR
panel.Visible = false
panel.Parent = gui
round(panel, 16)
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(420, 280)
limit.Parent = panel
local panelStroke = Instance.new("UIStroke")
panelStroke.Color = REBIRTH_COLOR
panelStroke.Thickness = 3
panelStroke.Parent = panel

local title = newText("Title", panel, UDim2.fromOffset(16, 12), UDim2.new(1, -32, 0, 34), REBIRTH_COLOR)
local info = newText("Info", panel, UDim2.fromOffset(16, 52), UDim2.new(1, -32, 0, 96), Color3.new(1, 1, 1))
info.TextXAlignment = Enum.TextXAlignment.Left
local infoLimit = Instance.new("UITextSizeConstraint")
infoLimit.MaxTextSize = 18
infoLimit.Parent = info

local bar = Instance.new("Frame")
bar.Name = "ProgressBar"
bar.Position = UDim2.fromOffset(16, 158)
bar.Size = UDim2.new(1, -32, 0, 26)
bar.BackgroundColor3 = Color3.fromRGB(20, 15, 35)
bar.Parent = panel
round(bar, 8)
local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.BackgroundColor3 = REBIRTH_COLOR
fill.Size = UDim2.fromScale(0, 1)
fill.Parent = bar
round(fill, 8)
local progressText = newText("Progress", bar, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), Color3.new(1, 1, 1))
progressText.ZIndex = 2
progressText.TextStrokeTransparency = 0.4

local confirmButton = newButton("Confirm", panel, "Rebirth!", REBIRTH_COLOR)
confirmButton.Position = UDim2.new(0, 16, 1, -70)
confirmButton.Size = UDim2.new(0.5, -24, 0, 54)
local closeButton = newButton("Close", panel, "Not yet", DISABLED_COLOR)
closeButton.Position = UDim2.new(0.5, 8, 1, -70)
closeButton.Size = UDim2.new(0.5, -24, 0, 54)

gui.Parent = player:WaitForChild("PlayerGui")

local function refresh()
	local cost = Rebirth.CostFor(rebirths.Value)
	local now = Rebirth.MultiplierFor(rebirths.Value)
	local nextMultiplier = Rebirth.MultiplierFor(rebirths.Value + 1)
	local ready = bolts.Value >= cost
	title.Text = `♻ Rebirth {rebirths.Value + 1}`
	info.Text = `Start your lab over: you lose your Bolts, gadgets and extra benches, but keep your gate upgrades.\nYour gadgets earn x{nextMultiplier} forever (now x{now}).`
	fill.Size = UDim2.fromScale(math.clamp(bolts.Value / cost, 0, 1), 1)
	progressText.Text = `⚙ {formatNumber(math.min(bolts.Value, cost))} / {formatNumber(cost)}`
	confirmButton.Active = ready
	confirmButton.AutoButtonColor = ready
	confirmButton.BackgroundColor3 = if ready then REBIRTH_COLOR else DISABLED_COLOR
	confirmButton.Text = if ready then "Rebirth!" else "Not enough Bolts"
	openButton.Text = if ready then "♻ Rebirth!" else "♻ Rebirth"
end

openButton.Activated:Connect(function()
	panel.Visible = not panel.Visible
	refresh()
end)
closeButton.Activated:Connect(function()
	panel.Visible = false
end)
confirmButton.Activated:Connect(function()
	if bolts.Value >= Rebirth.CostFor(rebirths.Value) then
		rebirthRemote:FireServer()
		panel.Visible = false
	end
end)
bolts.Changed:Connect(refresh)
rebirths.Changed:Connect(refresh)
refresh()
