--!strict
-- build-rooftop-lab.luau
-- One-off builder for the Rooftop Lab, the game's second area: a tall tower on the west edge of
-- the arena (opposite Professor Grudge), with a second conveyor on its roof that only carries Rare
-- and rarer gadgets. Players who have rebirthed at least once ride the lift pad at its foot up to
-- the roof (AreaService checks this); the down pad on the roof brings them back.
-- Builds Workspace.Map.RooftopLab: Tower, Trim, Roof, Rails, Belts (4), Pipe, Sign, LiftPad and
-- DownPad (attribute Destination "Roof"/"Ground"), plus a Path from the plaza. The roof belt's
-- path is in Config/Rooftop and must match the Belts built here.
-- Also moves the DNA helix that stood here 110 studs south, out of the tower.
-- Run once in Edit mode; it is one undo step. Stops if Workspace.Map.RooftopLab already exists.

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local map = workspace:FindFirstChild("Map")
assert(map, "Workspace.Map is missing")
if map:FindFirstChild("RooftopLab") then
	error("Workspace.Map.RooftopLab already exists. Undo or delete it first to rebuild.")
end

----- Constants -----
local CENTRE = Vector3.new(-115, 0, 0) -- west edge, between Lab 5 and Lab 6
local TOWER = 44 -- footprint of the tower
local TOWER_HEIGHT = 40
local ROOF = 48 -- the roof overhangs the tower a little
local ROOF_TOP = TOWER_HEIGHT + 1
local BELT_HALF = 10 -- the belt path is a square CENTRE +- this (see Config/Rooftop)
local BELT_WIDTH = 5
local PLAZA_EDGE = -62 -- where the plaza floor ends towards the west
local LIFT_X = CENTRE.X + TOWER / 2 + 5 -- just in front of the tower's plaza-facing wall
local WALL = Color3.fromRGB(55, 40, 100)
local TRIM = Color3.fromRGB(80, 220, 255)
local MOON = Color3.fromRGB(255, 130, 220)
local FLOOR = Color3.fromRGB(70, 62, 96)
local BELT = Color3.fromRGB(45, 45, 50)

local recording = ChangeHistoryService:TryBeginRecording("Build Rooftop Lab")

----- Helpers -----
local function part(props: { [string]: any }, parent: Instance): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

local function text(name: string, parent: Instance, value: string, color: Color3, position: UDim2, size: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = value
	label.TextColor3 = color
	label.Position = position
	label.Size = size
	label.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(20, 10, 40)
	stroke.Parent = label
	return label
end

-- A glowing pad with a floating label; AreaService moves players who step on it
local function pad(name: string, position: Vector3, size: number, destination: string, line1: string, line2: string, parent: Instance)
	local p = part({
		Name = name,
		Size = Vector3.new(size, 1, size),
		Position = position,
		Color = TRIM,
		Material = Enum.Material.Neon,
	}, parent)
	p:SetAttribute("Destination", destination)
	local gui = Instance.new("BillboardGui")
	gui.Name = "PadLabel"
	gui.Size = UDim2.fromOffset(220, 70)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
	gui.MaxDistance = 80
	gui.Parent = p
	text("Title", gui, line1, Color3.new(1, 1, 1), UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.55))
	text("Hint", gui, line2, MOON, UDim2.fromScale(0, 0.55), UDim2.fromScale(1, 0.45))
end

----- Build -----
local model = Instance.new("Model")
model.Name = "RooftopLab"

-- Tower, with a glowing band near the top
part({ Name = "Tower", Size = Vector3.new(TOWER, TOWER_HEIGHT, TOWER), Position = CENTRE + Vector3.new(0, TOWER_HEIGHT / 2, 0), Color = WALL }, model)
part({
	Name = "Trim",
	Size = Vector3.new(TOWER + 0.4, 1, TOWER + 0.4),
	Position = CENTRE + Vector3.new(0, TOWER_HEIGHT - 3, 0),
	Color = TRIM,
	Material = Enum.Material.Neon,
}, model)

-- Roof floor and see-through rails so nobody falls off
part({ Name = "Roof", Size = Vector3.new(ROOF, 1, ROOF), Position = CENTRE + Vector3.new(0, ROOF_TOP - 0.5, 0), Color = FLOOR, Material = Enum.Material.Slate }, model)
local rails = Instance.new("Folder")
rails.Name = "Rails"
rails.Parent = model
for i, offset in { Vector3.new(ROOF / 2, 0, 0), Vector3.new(-ROOF / 2, 0, 0), Vector3.new(0, 0, ROOF / 2), Vector3.new(0, 0, -ROOF / 2) } do
	local alongX = offset.X == 0
	part({
		Name = `Rail{i}`,
		Size = if alongX then Vector3.new(ROOF, 5, 1) else Vector3.new(1, 5, ROOF),
		Position = CENTRE + offset + Vector3.new(0, ROOF_TOP + 2.5, 0),
		Color = TRIM,
		Material = Enum.Material.Glass,
		Transparency = 0.6,
	}, rails)
end

-- The roof conveyor: four belts round a square, like the plaza's
local belts = Instance.new("Folder")
belts.Name = "Belts"
belts.Parent = model
local beltY = ROOF_TOP + 0.25 -- belt tops at ROOF_TOP + 0.5
local long = BELT_HALF * 2 + BELT_WIDTH
for name, info in {
	BeltNorth = { Vector3.new(0, 0, -BELT_HALF), Vector3.new(long, 0.5, BELT_WIDTH) },
	BeltSouth = { Vector3.new(0, 0, BELT_HALF), Vector3.new(long, 0.5, BELT_WIDTH) },
	BeltWest = { Vector3.new(-BELT_HALF, 0, 0), Vector3.new(BELT_WIDTH, 0.5, long - BELT_WIDTH * 2) },
	BeltEast = { Vector3.new(BELT_HALF, 0, 0), Vector3.new(BELT_WIDTH, 0.5, long - BELT_WIDTH * 2) },
} do
	part({ Name = name, Size = info[2], Position = CENTRE + info[1] + Vector3.new(0, beltY, 0), Color = BELT, Material = Enum.Material.DiamondPlate }, belts)
end

-- A pink gadget pipe in the middle, like a smaller twin of the plaza's
local pipe = Instance.new("Model")
pipe.Name = "Pipe"
pipe.Parent = model
local sideways = CFrame.Angles(0, 0, math.rad(90)) -- cylinders run along X, so turn them upright
part({ Name = "Base", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 9, 9), CFrame = CFrame.new(CENTRE + Vector3.new(0, ROOF_TOP + 1, 0)) * sideways, Color = Color3.fromRGB(90, 90, 100), Material = Enum.Material.Metal }, pipe)
part({ Name = "Tube", Shape = Enum.PartType.Cylinder, Size = Vector3.new(12, 6, 6), CFrame = CFrame.new(CENTRE + Vector3.new(0, ROOF_TOP + 8, 0)) * sideways, Color = MOON, Material = Enum.Material.Glass, Transparency = 0.3 }, pipe)
part({ Name = "Cap", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 8, 8), CFrame = CFrame.new(CENTRE + Vector3.new(0, ROOF_TOP + 15, 0)) * sideways, Color = Color3.fromRGB(255, 170, 0), Material = Enum.Material.Metal }, pipe)
local glow = Instance.new("PointLight")
glow.Color = MOON
glow.Range = 24
glow.Brightness = 2
glow.Parent = pipe:FindFirstChild("Tube")

-- Sign on the plaza-facing wall
local sign = part({
	Name = "Sign",
	Size = Vector3.new(1, 10, 30),
	Position = Vector3.new(CENTRE.X + TOWER / 2 + 0.5, 28, 0),
	Color = Color3.fromRGB(25, 15, 45),
}, model)
local surface = Instance.new("SurfaceGui")
surface.Face = Enum.NormalId.Right
surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
surface.PixelsPerStud = 30
surface.LightInfluence = 0
surface.Parent = sign
text("Title", surface, "🌙 ROOFTOP LAB", MOON, UDim2.fromScale(0.03, 0.05), UDim2.fromScale(0.94, 0.55))
text("Hint", surface, "Rare gadgets only · Rebirth once to ride up", TRIM, UDim2.fromScale(0.03, 0.62), UDim2.fromScale(0.94, 0.32))

-- Lift pad at the foot of the tower, and the way back down on the roof
pad("LiftPad", Vector3.new(LIFT_X, 0.6, 0), 8, "Roof", "⬆ Rooftop Lift", "Rebirth once to unlock", model)
pad("DownPad", CENTRE + Vector3.new(ROOF / 2 - 5, ROOF_TOP + 0.1, ROOF / 2 - 5), 6, "Ground", "⬇ Back down", "", model)

-- A path from the plaza to the lift, like the paths to the labs
local pathLength = (LIFT_X - 4) - PLAZA_EDGE
part({
	Name = "Path7",
	Size = Vector3.new(math.abs(pathLength), 1, 10),
	Position = Vector3.new(PLAZA_EDGE + pathLength / 2, 0.5, 0),
	Color = Color3.fromRGB(180, 180, 190),
	Material = Enum.Material.Slate,
}, model)

model.Parent = map

-- The DNA helix stood where the tower is; move it south, out of the way
local decor = workspace:FindFirstChild("Decor")
local outskirts = decor and decor:FindFirstChild("Outskirts")
local helix = outskirts and outskirts:FindFirstChild("DNAHelix")
if helix and helix:IsA("Model") then
	helix:PivotTo(helix:GetPivot() + Vector3.new(0, 0, 110))
end

if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
print("Built Workspace.Map.RooftopLab")
