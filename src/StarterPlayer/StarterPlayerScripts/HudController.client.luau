--!strict
-- HudController
-- Builds the on-screen Bolts counter and keeps it in sync with the player's Bolts.
-- It only displays the number: Bolts are changed on the server by DataService.
-- Container: StarterPlayer/StarterPlayerScripts

----- Services -----
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

----- Constants -----
local BOLT_COLOR = Color3.fromRGB(255, 200, 40)
local POP_TWEEN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true)

----- Variables -----
local player = Players.LocalPlayer

----- Private Functions -----
-- 1234567 -> "1,234,567"
local function formatNumber(n: number): string
	local text = tostring(math.floor(n))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

local function buildHud(): (TextLabel, UIScale)
	local gui = Instance.new("ScreenGui")
	gui.Name = "HUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false

	local frame = Instance.new("Frame")
	frame.Name = "BoltsCounter"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 10)
	frame.Size = UDim2.fromOffset(220, 56)
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	frame.BackgroundTransparency = 0.15
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = BOLT_COLOR
	stroke.Thickness = 3
	stroke.Parent = frame

	local scale = Instance.new("UIScale")
	scale.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name = "Amount"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = BOLT_COLOR
	label.Text = "⚙ ..."
	label.Parent = frame

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.Parent = label

	gui.Parent = player:WaitForChild("PlayerGui")
	return label, scale
end

----- Initialization -----
local label, scale = buildHud()

-- Saved data can take a few seconds to load, so wait for DataService to finish first
while not player:GetAttribute("DataLoaded") do
	player:GetAttributeChangedSignal("DataLoaded"):Wait()
end
local leaderstats = player:WaitForChild("leaderstats")
local bolts = leaderstats:WaitForChild("Bolts") :: IntValue

local lastValue = bolts.Value
label.Text = `⚙ {formatNumber(bolts.Value)}`

bolts.Changed:Connect(function(value: number)
	label.Text = `⚙ {formatNumber(value)}`
	-- Little "pop" whenever Bolts go up
	if value > lastValue then
		scale.Scale = 1
		TweenService:Create(scale, POP_TWEEN, { Scale = 1.12 }):Play()
	end
	lastValue = value
end)
