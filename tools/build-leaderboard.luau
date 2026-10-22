--!strict
-- build-leaderboard.luau
-- One-off builder for the global leaderboard board on the plaza, between Lab 1 and Lab 2, facing
-- the spawn (from the plaza centre a Tesla coil would block it). A tall screen on two legs with a neon frame, a spinning gold trophy on top and
-- a SurfaceGui with a title and 10 empty rows (Row1..Row10, each with Rank, Avatar, PlayerName,
-- Rebirths and Bolts). LeaderboardService fills the rows on the server.
-- Run once in Edit mode; it is one undo step. Stops if Workspace.Decor.Leaderboard already exists.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")

local decor = workspace:FindFirstChild("Decor")
assert(decor, "Run build-decor.luau first (Workspace.Decor is missing)")
if decor:FindFirstChild("Leaderboard") then
	error("Workspace.Decor.Leaderboard already exists. Undo or delete it first to rebuild.")
end

----- Constants -----
local DECOR_TAG = "AnimatedDecor"
local CYAN = Color3.fromRGB(70, 220, 255)
local PURPLE = Color3.fromRGB(190, 110, 255)
local YELLOW = Color3.fromRGB(255, 200, 40)
local METAL = Color3.fromRGB(60, 56, 78)
local SCREEN = Color3.fromRGB(18, 14, 40)

local SPOT = Vector3.new(38, 0, 62) -- between Lab 1 and Lab 2, just off the plaza
local LOOK_AT = Vector3.new(0, 0, 40) -- the SpawnLocation
local WIDTH = 22
local HEIGHT = 28
local LEG_HEIGHT = 4
local PIXELS_PER_STUD = 40
local ROWS = 10

local recording = ChangeHistoryService:TryBeginRecording("Build leaderboard")

----- Helpers -----
local function part(props: { [string]: any }, parent: Instance): BasePart
	local p = Instance.new(props.ClassName or "Part") :: BasePart
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		if key ~= "ClassName" then
			(p :: any)[key] = value
		end
	end
	p.Parent = parent
	return p
end

local function corner(instance: GuiObject, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = instance
end

local function label(name: string, parent: Instance, text: string, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = color
	l.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(20, 12, 40)
	stroke.Thickness = 3
	stroke.Parent = l
	return l
end

----- Build -----
-- Stand it on whatever is underneath, facing the spawn
local hit = workspace:Raycast(SPOT + Vector3.new(0, 50, 0), Vector3.new(0, -100, 0))
local groundY = if hit then hit.Position.Y else 0
local base = Vector3.new(SPOT.X, groundY, SPOT.Z)
local facing = CFrame.lookAt(base, Vector3.new(LOOK_AT.X, groundY, LOOK_AT.Z))

local model = Instance.new("Model")
model.Name = "Leaderboard"
model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

local screenCf = facing * CFrame.new(0, LEG_HEIGHT + HEIGHT / 2, 0)
local screen = part({ Name = "Screen", Size = Vector3.new(WIDTH, HEIGHT, 1), CFrame = screenCf, Color = SCREEN }, model)
part({ Name = "Back", Size = Vector3.new(WIDTH + 1, HEIGHT + 1, 1), CFrame = screenCf * CFrame.new(0, 0, 0.8), Color = METAL }, model)
-- Neon frame round the screen
for _, side in { -1, 1 } do
	part({ Name = "FrameSide", Size = Vector3.new(0.6, HEIGHT + 1.2, 0.6), CFrame = screenCf * CFrame.new(side * (WIDTH / 2 + 0.3), 0, -0.3), Material = Enum.Material.Neon, Color = CYAN }, model)
	part({ Name = "FrameEdge", Size = Vector3.new(WIDTH + 1.2, 0.6, 0.6), CFrame = screenCf * CFrame.new(0, side * (HEIGHT / 2 + 0.3), -0.3), Material = Enum.Material.Neon, Color = PURPLE }, model)
	-- Legs
	part({ Name = "Leg", Size = Vector3.new(1.4, LEG_HEIGHT + 2, 1.4), CFrame = facing * CFrame.new(side * (WIDTH / 2 - 2), LEG_HEIGHT / 2 + 1, 0.4), Color = METAL }, model)
	part({ Name = "Foot", Size = Vector3.new(3, 0.6, 4), CFrame = facing * CFrame.new(side * (WIDTH / 2 - 2), 0.3, 0.4), Color = METAL }, model)
end

-- Spinning gold trophy on top
local trophy = Instance.new("Model")
trophy.Name = "Trophy"
local topY = LEG_HEIGHT + HEIGHT + 0.6
local trophyBase = part({ Name = "Base", Size = Vector3.new(3, 1, 3), CFrame = facing * CFrame.new(0, topY + 0.5, 0), Color = METAL }, trophy)
-- Spins round the upright axis through the trophy. `axis` and `pivot` are in the part's own
-- space (cylinders lie on their X axis, so the upright ones spin about X).
local function trophyPart(props: { [string]: any }, axis: string, pivot: Vector3)
	local p = part(props, trophy)
	p:SetAttribute("Anim", "Spin")
	p:SetAttribute("AnimAxis", axis)
	p:SetAttribute("AnimSpeed", 50)
	p:SetAttribute("AnimPivot", pivot)
end
local upright = CFrame.Angles(0, 0, math.rad(90))
trophyPart({ Name = "Stem", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 0.8, 0.8), CFrame = facing * CFrame.new(0, topY + 2, 0) * upright, Material = Enum.Material.Metal, Color = YELLOW }, "X", Vector3.zero)
trophyPart({ Name = "Cup", Shape = Enum.PartType.Ball, Size = Vector3.new(3.4, 3.4, 3.4), CFrame = facing * CFrame.new(0, topY + 4, 0), Material = Enum.Material.Metal, Color = YELLOW }, "Y", Vector3.zero)
trophyPart({ Name = "Rim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 3.8, 3.8), CFrame = facing * CFrame.new(0, topY + 5.3, 0) * upright, Material = Enum.Material.Neon, Color = YELLOW }, "X", Vector3.zero)
for _, side in { -1, 1 } do
	-- Rings facing forwards on each side; the pivot points back to the middle of the trophy
	trophyPart({ Name = "Handle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 1.6, 1.6), CFrame = facing * CFrame.new(side * 2, topY + 4.2, 0) * CFrame.Angles(0, math.rad(90), 0), Material = Enum.Material.Metal, Color = YELLOW }, "Y", Vector3.new(0, 0, -2 * side))
end
local glow = Instance.new("PointLight")
glow.Color = YELLOW
glow.Range = 14
glow.Brightness = 2
glow.Parent = trophyBase
trophy.PrimaryPart = trophyBase
trophy.Parent = model
CollectionService:AddTag(trophy, DECOR_TAG)

-- The display
local gui = Instance.new("SurfaceGui")
gui.Name = "Display"
gui.Face = Enum.NormalId.Front
gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
gui.PixelsPerStud = PIXELS_PER_STUD
gui.LightInfluence = 0
gui.Parent = screen
local canvas = Instance.new("Frame")
canvas.Name = "Canvas"
canvas.Size = UDim2.fromScale(1, 1)
canvas.BackgroundColor3 = Color3.new(1, 1, 1)
canvas.Parent = gui
local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new(Color3.fromRGB(40, 30, 90), SCREEN)
gradient.Rotation = 90
gradient.Parent = canvas

local title = label("Title", canvas, "🏆 TOP REBIRTHERS", YELLOW)
title.Position = UDim2.fromScale(0.04, 0.015)
title.Size = UDim2.fromScale(0.92, 0.085)
local subtitle = label("Subtitle", canvas, "All servers · updates every minute", CYAN)
subtitle.Position = UDim2.fromScale(0.1, 0.1)
subtitle.Size = UDim2.fromScale(0.8, 0.035)

local rowTop, rowHeight, rowGap = 0.15, 0.077, 0.006
for i = 1, ROWS do
	local row = Instance.new("Frame")
	row.Name = `Row{i}`
	row.Position = UDim2.fromScale(0.03, rowTop + (i - 1) * (rowHeight + rowGap))
	row.Size = UDim2.fromScale(0.94, rowHeight)
	row.BackgroundColor3 = if i % 2 == 1 then Color3.fromRGB(45, 36, 95) else Color3.fromRGB(34, 27, 75)
	row.Parent = canvas
	corner(row, 14)
	local rankColor = if i == 1 then YELLOW elseif i == 2 then Color3.fromRGB(210, 220, 235) elseif i == 3 then Color3.fromRGB(230, 140, 70) else Color3.new(1, 1, 1)
	local rank = label("Rank", row, `#{i}`, rankColor)
	rank.Position = UDim2.fromScale(0.01, 0.1)
	rank.Size = UDim2.fromScale(0.11, 0.8)
	local avatar = Instance.new("ImageLabel")
	avatar.Name = "Avatar"
	avatar.Position = UDim2.fromScale(0.13, 0.08)
	avatar.SizeConstraint = Enum.SizeConstraint.RelativeYY
	avatar.Size = UDim2.fromScale(0.84, 0.84)
	avatar.BackgroundColor3 = Color3.fromRGB(70, 60, 130)
	avatar.Image = ""
	avatar.Parent = row
	corner(avatar, 40)
	local name = label("PlayerName", row, "—", Color3.new(1, 1, 1))
	name.Position = UDim2.fromScale(0.25, 0.12)
	name.Size = UDim2.fromScale(0.44, 0.76)
	name.TextXAlignment = Enum.TextXAlignment.Left
	local rebirths = label("Rebirths", row, "", PURPLE)
	rebirths.Position = UDim2.fromScale(0.7, 0.06)
	rebirths.Size = UDim2.fromScale(0.28, 0.5)
	rebirths.TextXAlignment = Enum.TextXAlignment.Right
	local bolts = label("Bolts", row, "", YELLOW)
	bolts.Position = UDim2.fromScale(0.7, 0.56)
	bolts.Size = UDim2.fromScale(0.28, 0.36)
	bolts.TextXAlignment = Enum.TextXAlignment.Right
end
local footer = label("Footer", canvas, "Rebirth to climb the board!", CYAN)
footer.Position = UDim2.fromScale(0.1, 0.96)
footer.Size = UDim2.fromScale(0.8, 0.03)

model.PrimaryPart = screen
model.Parent = decor

if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
print(`[build-leaderboard] Built at {base} with {#model:GetDescendants()} pieces`)
