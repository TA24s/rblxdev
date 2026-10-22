--!strict
-- HudController
-- Builds the on-screen Bolts counter and keeps it in sync with the player's Bolts: a glossy
-- panel with a spinning 3D gold gear (it whirs faster when you earn), the amount, a pop when
-- it goes up and a "+N" that floats away, with a green "+N/s" income tag underneath. It only
-- displays the numbers: Bolts are changed on the server by DataService.
-- Container: StarterPlayer/StarterPlayerScripts

----- Services -----
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

----- Constants -----
local BOLT_COLOR = Color3.fromRGB(255, 200, 40)
local DARK = Color3.fromRGB(35, 25, 60)
local POP_TWEEN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true)
local FLOAT_TWEEN = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local IDLE_SPIN = 25 -- degrees per second
local BURST_SPIN = 540 -- added when Bolts go up, then slows back down
local SPIN_DECAY = 3 -- how quickly the burst fades (per second)
local GEAR_TEETH = 10

----- Variables -----
local player = Players.LocalPlayer
local spinBoost = 0
local spinAngle = 0

----- Private Functions -----
-- 1234567 -> "1,234,567"
local function formatNumber(n: number): string
	local text = tostring(math.floor(n))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

local function gearPart(props: { [string]: any }, parent: Instance): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

-- A gold gear like the one on the title sign, facing the camera (its axis is the X axis)
local function buildGear(parent: Instance): Model
	local gear = Instance.new("Model")
	gear.Name = "Gear"
	local face = CFrame.Angles(0, math.rad(90), 0) -- turns the cylinder's X axis towards the camera
	local ring = gearPart({ Name = "Ring", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 3, 3), CFrame = face, Color = BOLT_COLOR }, gear)
	gearPart({ Name = "Hole", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.7, 1.5, 1.5), CFrame = face, Color = DARK }, gear)
	gearPart({ Name = "Axle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 0.6, 0.6), CFrame = face, Color = Color3.fromRGB(255, 240, 180) }, gear)
	for k = 0, GEAR_TEETH - 1 do
		gearPart({
			Name = "Tooth",
			Size = Vector3.new(0.6, 0.6, 0.7),
			CFrame = face * CFrame.Angles(math.rad(360 / GEAR_TEETH * k), 0, 0) * CFrame.new(0, 1.65, 0),
			Color = BOLT_COLOR,
		}, gear)
	end
	gear.PrimaryPart = ring
	gear.Parent = parent
	return gear
end

local function buildHud(): (TextLabel, UIScale, Model, Frame)
	local gui = Instance.new("ScreenGui")
	gui.Name = "HUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false

	local frame = Instance.new("Frame")
	frame.Name = "BoltsCounter"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 10)
	frame.Size = UDim2.fromOffset(240, 58)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0) -- a pill shape
	corner.Parent = frame

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.fromRGB(80, 50, 140), Color3.fromRGB(25, 15, 45))
	gradient.Rotation = 90
	gradient.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = BOLT_COLOR
	stroke.Thickness = 3
	stroke.Parent = frame

	local scale = Instance.new("UIScale")
	scale.Parent = frame

	-- The spinning 3D gear, poking out of the left end of the pill
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "GearIcon"
	viewport.AnchorPoint = Vector2.new(0, 0.5)
	viewport.Position = UDim2.new(0, -14, 0.5, 0)
	viewport.Size = UDim2.fromOffset(74, 74)
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(200, 170, 110)
	viewport.LightColor = Color3.new(1, 1, 1)
	viewport.LightDirection = Vector3.new(-1, -1, -2)
	viewport.ZIndex = 2
	viewport.Parent = frame
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, -5.6), Vector3.zero)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local gear = buildGear(viewport)

	local label = Instance.new("TextLabel")
	label.Name = "Amount"
	label.Position = UDim2.fromOffset(62, 0)
	label.Size = UDim2.new(1, -78, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = BOLT_COLOR
	label.Text = "..."
	label.Parent = frame
	local textStroke = Instance.new("UIStroke")
	textStroke.Color = DARK
	textStroke.Thickness = 2
	textStroke.Parent = label
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 9)
	padding.PaddingBottom = UDim.new(0, 9)
	padding.Parent = label

	gui.Parent = player:WaitForChild("PlayerGui")
	return label, scale, gear, frame
end

-- The green "+12/s" tag hanging under the counter
local function buildIncomeTag(frame: Frame): TextLabel
	local tag = Instance.new("Frame")
	tag.Name = "IncomeTag"
	tag.AnchorPoint = Vector2.new(0.5, 0)
	tag.Position = UDim2.new(0.5, 8, 1, 2)
	tag.Size = UDim2.fromOffset(0, 26)
	tag.AutomaticSize = Enum.AutomaticSize.X
	tag.BackgroundColor3 = Color3.new(1, 1, 1)
	tag.Parent = frame
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = tag
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.fromRGB(40, 150, 70), Color3.fromRGB(15, 70, 35))
	gradient.Rotation = 90
	gradient.Parent = tag
	local tagStroke = Instance.new("UIStroke")
	tagStroke.Color = Color3.fromRGB(120, 255, 160)
	tagStroke.Thickness = 1.5
	tagStroke.Parent = tag
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = tag
	local text = Instance.new("TextLabel")
	text.Name = "Amount"
	text.Size = UDim2.fromScale(0, 1)
	text.AutomaticSize = Enum.AutomaticSize.X
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextSize = 18
	text.TextColor3 = Color3.fromRGB(150, 255, 180)
	text.Text = "+0/s"
	text.Parent = tag
	local textStroke = Instance.new("UIStroke")
	textStroke.Color = DARK
	textStroke.Thickness = 1.5
	textStroke.Parent = text
	return text
end

-- "+25" rising from the counter and fading out
local function floatGain(frame: Frame, amount: number)
	local gain = Instance.new("TextLabel")
	gain.AnchorPoint = Vector2.new(0, 0.5)
	gain.Position = UDim2.new(1, 6, 0.5, 0)
	gain.Size = UDim2.fromOffset(120, 26)
	gain.BackgroundTransparency = 1
	gain.Font = Enum.Font.FredokaOne
	gain.TextSize = 24
	gain.TextXAlignment = Enum.TextXAlignment.Left
	gain.TextColor3 = Color3.fromRGB(120, 255, 160)
	gain.Text = `+{formatNumber(amount)}`
	local gainStroke = Instance.new("UIStroke")
	gainStroke.Color = DARK
	gainStroke.Thickness = 2
	gainStroke.Parent = gain
	gain.Parent = frame
	TweenService:Create(gain, FLOAT_TWEEN, { Position = UDim2.new(1, 6, 0.5, -34), TextTransparency = 1 }):Play()
	TweenService:Create(gainStroke, FLOAT_TWEEN, { Transparency = 1 }):Play()
	task.delay(FLOAT_TWEEN.Time, function()
		gain:Destroy()
	end)
end

----- Initialization -----
local label, scale, gear, frame = buildHud()
local incomeText = buildIncomeTag(frame)

RunService.RenderStepped:Connect(function(deltaTime)
	spinBoost = math.max(0, spinBoost - spinBoost * SPIN_DECAY * deltaTime)
	spinAngle += (IDLE_SPIN + spinBoost) * deltaTime
	gear:PivotTo(CFrame.Angles(0, 0, math.rad(spinAngle)) * CFrame.Angles(0, math.rad(90), 0))
end)

-- Saved data can take a few seconds to load, so wait for DataService to finish first
while not player:GetAttribute("DataLoaded") do
	player:GetAttributeChangedSignal("DataLoaded"):Wait()
end
local leaderstats = player:WaitForChild("leaderstats")
local bolts = leaderstats:WaitForChild("Bolts") :: IntValue

local income = leaderstats:WaitForChild("Income") :: IntValue
local function showIncome()
	incomeText.Text = `+{formatNumber(income.Value)}/s`
end
income.Changed:Connect(showIncome)
showIncome()

local lastValue = bolts.Value
label.Text = formatNumber(bolts.Value)

bolts.Changed:Connect(function(value: number)
	label.Text = formatNumber(value)
	-- Little "pop", a gear whirr and a floating "+N" whenever Bolts go up
	if value > lastValue then
		scale.Scale = 1
		TweenService:Create(scale, POP_TWEEN, { Scale = 1.12 }):Play()
		spinBoost = BURST_SPIN
		floatGain(frame, value - lastValue)
	end
	lastValue = value
end)
