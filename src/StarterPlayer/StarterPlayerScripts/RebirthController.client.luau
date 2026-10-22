--!strict
-- RebirthController
-- The purple ♻ Rebirth button next to the Boing Glove. It opens a panel showing what the next
-- rebirth costs, how close you are, and what you get and lose. Pressing "Rebirth!" asks the
-- server (RebirthService), which checks everything again before doing it.
-- Container: StarterPlayer/StarterPlayerScripts

----- Services -----
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

----- Modules -----
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rebirth = require(Shared:WaitForChild("Config"):WaitForChild("Rebirth"))
local Ui = require(Shared:WaitForChild("Ui"))

----- Constants -----
local C = Ui.Colors

----- Variables -----
local player = Players.LocalPlayer
local rebirthRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RebirthRequest") :: RemoteEvent

----- Initialization -----
while not player:GetAttribute("DataLoaded") do
	player:GetAttributeChangedSignal("DataLoaded"):Wait()
end
local leaderstats = player:WaitForChild("leaderstats")
local bolts = leaderstats:WaitForChild("Bolts") :: IntValue
local rebirths = leaderstats:WaitForChild("Rebirths") :: IntValue

-- The purple button next to the Boing Glove (and the Upgrade button)
local openButton, openWord = Ui.IconButton("Rebirth", Ui.GetBottomBar(), "♻", "Rebirth", C.Purple, C.PurpleDark, 76)
openButton.LayoutOrder = 2
local openStroke = openButton:FindFirstChildOfClass("UIStroke") :: UIStroke

-- The panel
local panel = Ui.NewPanel("Rebirth", "♻ Rebirth", C.Purple, Vector2.new(440, 270))
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 10)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = panel.Content

local heading = Ui.Text("Heading", panel.Content, "", 24, C.Purple)
heading.LayoutOrder = 1
heading.Size = UDim2.new(1, 0, 0, 28)
Ui.TextOutline(heading)
local info = Ui.Text("Info", panel.Content, "", 16)
info.Font = Enum.Font.GothamMedium
info.LayoutOrder = 2
info.Size = UDim2.new(1, 0, 0, 0)
info.AutomaticSize = Enum.AutomaticSize.Y
info.RichText = true
info.TextXAlignment = Enum.TextXAlignment.Left

local bar = Instance.new("Frame")
bar.Name = "ProgressBar"
bar.LayoutOrder = 3
bar.Size = UDim2.new(1, 0, 0, 30)
bar.BackgroundColor3 = C.PanelDark
bar.Parent = panel.Content
Ui.Corner(bar, 10)
Ui.Border(bar, C.Purple, 2).Transparency = 0.4
local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.BackgroundColor3 = Color3.new(1, 1, 1)
fill.Size = UDim2.fromScale(0, 1)
fill.Parent = bar
Ui.Corner(fill, 10)
Ui.Gradient(fill, C.Purple, C.PurpleDark)
local progressText = Ui.Text("Progress", bar, "", 18)
progressText.Size = UDim2.fromScale(1, 1)
progressText.ZIndex = 2
Ui.TextOutline(progressText)

local confirmButton = Ui.TextButton("Confirm", panel.Content, "Rebirth!")
confirmButton.LayoutOrder = 4
confirmButton.Size = UDim2.new(1, 0, 0, 52)

local function refresh()
	local cost = Rebirth.CostFor(rebirths.Value)
	local now = Rebirth.MultiplierFor(rebirths.Value)
	local nextMultiplier = Rebirth.MultiplierFor(rebirths.Value + 1)
	local ready = bolts.Value >= cost
	heading.Text = `Rebirth {rebirths.Value + 1}: gadgets earn x{nextMultiplier} forever`
	info.Text = `Start your lab over for a permanent boost (now x{now}).\n<font color="#FF7A8A">You lose:</font> Bolts, gadgets, extra benches.\n<font color="#5BFF8A">You keep:</font> gate and income upgrades, your Index.`
	fill.Size = UDim2.fromScale(math.clamp(bolts.Value / cost, 0, 1), 1)
	progressText.Text = `⚙ {Ui.FormatNumber(math.min(bolts.Value, cost))} / {Ui.FormatNumber(cost)}`
	confirmButton.Text = if ready then "♻ Rebirth!" else "Not enough Bolts"
	if ready then
		Ui.SetButtonColor(confirmButton, C.Purple, C.PurpleDark)
	else
		Ui.SetButtonColor(confirmButton, C.Disabled, Color3.fromRGB(60, 58, 75))
	end
	-- The button glows gold when a rebirth is ready
	openWord.Text = if ready then "Rebirth!" else "Rebirth"
	openStroke.Color = if ready then C.Bolt else Color3.new(1, 1, 1)
	openStroke.Thickness = if ready then 3 else 2
	openStroke.Transparency = if ready then 0 else 0.35
end

panel.OnOpen = refresh
openButton.Activated:Connect(function()
	Ui.Toggle("Rebirth")
end)
confirmButton.Activated:Connect(function()
	if bolts.Value >= Rebirth.CostFor(rebirths.Value) then
		rebirthRemote:FireServer()
		Ui.Close("Rebirth")
	end
end)
bolts.Changed:Connect(refresh)
rebirths.Changed:Connect(refresh)
refresh()
