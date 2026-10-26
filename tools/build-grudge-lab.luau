--!strict
-- build-grudge-lab.luau
-- One-off builder for Professor Grudge's Lab: a small rival lab run by a grumpy inventor (an NPC),
-- between Lab 2 and Lab 3 at the edge of the arena, opening towards the plaza. Anyone can steal
-- from its three benches (GrudgeService fills them), so even a player alone in a server can
-- learn stealing. Builds Workspace.Map.GrudgeLab: Floor, Walls, a Path from the plaza, a Sign,
-- Benches/GrudgeBench1-3 (attribute BenchIndex) and the Professor (tagged AnimatedDecor: his
-- arms rub together). Also moves the test-tube rack that stood here to just behind the lab.
-- Run once in Edit mode; it is one undo step. Stops if Workspace.Map.GrudgeLab already exists.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")

local map = workspace:FindFirstChild("Map")
assert(map, "Workspace.Map is missing")
if map:FindFirstChild("GrudgeLab") then
	error("Workspace.Map.GrudgeLab already exists. Undo or delete it first to rebuild.")
end

----- Constants -----
local DECOR_TAG = "AnimatedDecor"
local CENTRE = Vector3.new(124, 0, 0) -- between Lab 2 and Lab 3, inside the fence
local SIZE = 32
local PLAZA_EDGE = 58 -- where the plaza floor ends along this direction
local TOXIC = Color3.fromRGB(120, 255, 80)
local WALL = Color3.fromRGB(45, 75, 50)
local FLOOR = Color3.fromRGB(55, 60, 66)
local DARK = Color3.fromRGB(35, 30, 45)
local COAT = Color3.fromRGB(240, 240, 235)
local SKIN = Color3.fromRGB(255, 205, 160)
local HAIR = Color3.fromRGB(200, 200, 210)

local recording = ChangeHistoryService:TryBeginRecording("Build Grudge lab")

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
	stroke.Color = Color3.fromRGB(15, 25, 10)
	stroke.Thickness = 3
	stroke.Parent = label
	return label
end

----- Build -----
-- Local space: -Z points at the plaza (the open front), +Z is the back wall
local origin = CFrame.lookAt(CENTRE, Vector3.zero)
local function at(x: number, y: number, z: number): CFrame
	return origin * CFrame.new(x, y, z)
end

local lab = Instance.new("Model")
lab.Name = "GrudgeLab"
lab:SetAttribute("IsNpcLab", true)
local half = SIZE / 2

part({ Name = "Floor", Size = Vector3.new(SIZE, 1, SIZE), CFrame = at(0, 0.5, 0), Material = Enum.Material.DiamondPlate, Color = FLOOR }, lab)

local walls = Instance.new("Folder")
walls.Name = "Walls"
walls.Parent = lab
local gapHalf = 6 -- the doorway is 12 wide
local frontPiece = half - gapHalf
part({ Name = "Back", Size = Vector3.new(SIZE, 10, 1), CFrame = at(0, 6, half - 0.5), Color = WALL }, walls)
part({ Name = "Left", Size = Vector3.new(1, 4, SIZE), CFrame = at(-half + 0.5, 3, 0), Color = WALL }, walls)
part({ Name = "Right", Size = Vector3.new(1, 4, SIZE), CFrame = at(half - 0.5, 3, 0), Color = WALL }, walls)
part({ Name = "FrontLeft", Size = Vector3.new(frontPiece, 4, 1), CFrame = at(-half + frontPiece / 2, 3, -half + 0.5), Color = WALL }, walls)
part({ Name = "FrontRight", Size = Vector3.new(frontPiece, 4, 1), CFrame = at(half - frontPiece / 2, 3, -half + 0.5), Color = WALL }, walls)
-- Toxic green trim along the tops
for _, wall in walls:GetChildren() do
	local w = wall :: BasePart
	part({ Name = "Trim", Size = Vector3.new(w.Size.X + 0.2, 0.4, w.Size.Z + 0.2), CFrame = w.CFrame * CFrame.new(0, w.Size.Y / 2 + 0.2, 0), Material = Enum.Material.Neon, Color = TOXIC }, walls)
end
-- A big skull-and-gear emblem on the back wall
local back = walls:FindFirstChild("Back") :: BasePart
local emblem = Instance.new("SurfaceGui")
emblem.Name = "Emblem"
emblem.Face = Enum.NormalId.Front
emblem.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
emblem.PixelsPerStud = 30
emblem.LightInfluence = 0.3
emblem.Parent = back
text("Skull", emblem, "☠", TOXIC, UDim2.fromScale(0.35, 0.05), UDim2.fromScale(0.3, 0.6))

-- Path from the plaza to the doorway
local pathLength = (CENTRE.Magnitude - half) - PLAZA_EDGE
local pathCf = at(0, 0.5, -half - pathLength / 2)
part({ Name = "Path", Size = Vector3.new(10, 1, pathLength), CFrame = pathCf, Material = Enum.Material.Slate, Color = Color3.fromRGB(180, 180, 190) }, lab)
for _, side in { -1, 1 } do
	part({ Name = "PathEdge", Size = Vector3.new(0.3, 0.5, pathLength), CFrame = pathCf * CFrame.new(side * 5.2, 0.4, 0), Material = Enum.Material.Neon, Color = TOXIC, CanCollide = false }, lab)
end

-- Sign over the doorway
local signCf = at(0, 10, -half - 0.5)
local sign = part({ Name = "Sign", Size = Vector3.new(20, 5, 0.6), CFrame = signCf, Color = DARK }, lab)
part({ Name = "SignFrame", Size = Vector3.new(20.8, 5.8, 0.4), CFrame = signCf * CFrame.new(0, 0, 0.4), Material = Enum.Material.Neon, Color = TOXIC }, lab)
for _, side in { -1, 1 } do
	part({ Name = "SignPost", Size = Vector3.new(0.6, 8, 0.6), CFrame = at(side * 9, 5, -half - 0.5), Color = DARK }, lab)
end
local signGui = Instance.new("SurfaceGui")
signGui.Name = "SignGui"
signGui.Face = Enum.NormalId.Front
signGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
signGui.PixelsPerStud = 40
signGui.LightInfluence = 0
signGui.Parent = sign
text("Title", signGui, "☠ PROFESSOR GRUDGE'S LAB ☠", TOXIC, UDim2.fromScale(0.03, 0.08), UDim2.fromScale(0.94, 0.5))
text("Dare", signGui, "Steal from me... if you DARE!", Color3.fromRGB(255, 120, 200), UDim2.fromScale(0.1, 0.6), UDim2.fromScale(0.8, 0.32))

-- Three benches in a row near the back
local benches = Instance.new("Folder")
benches.Name = "Benches"
benches.Parent = lab
for i, x in { -10, 0, 10 } do
	local bench = part({ Name = `GrudgeBench{i}`, Size = Vector3.new(7, 1, 7), CFrame = at(x, 1.5, 7), Material = Enum.Material.Neon, Color = TOXIC }, benches)
	bench:SetAttribute("BenchIndex", i)
end

-- Professor Grudge, standing behind his benches, facing the doorway
local prof = Instance.new("Model")
prof.Name = "ProfessorGrudge"
local base = part({ Name = "Base", Size = Vector3.new(2, 0.2, 2), CFrame = at(0, 1.1, 12.5), Transparency = 1, CanCollide = false }, prof)
local function body(name: string, size: Vector3, x: number, y: number, z: number, color: Color3, extra: { [string]: any }?): BasePart
	local props: { [string]: any } = { Name = name, Size = size, CFrame = at(x, y, 12.5 + z), Color = color }
	for key, value in extra or {} do
		props[key] = value
	end
	return part(props, prof)
end
for _, side in { -1, 1 } do
	body("Leg", Vector3.new(0.9, 2.8, 0.9), side * 0.55, 2.4, 0, DARK)
	body("Shoe", Vector3.new(1, 0.5, 1.4), side * 0.55, 1.25, -0.2, Color3.fromRGB(20, 20, 25))
	-- Arms rub his hands together, plotting (swing about the shoulder)
	local arm = body("Arm", Vector3.new(0.8, 2.8, 0.8), side * 1.7, 5.3, -0.3, COAT, { Rotation = Vector3.zero })
	arm.CFrame = arm.CFrame * CFrame.Angles(math.rad(-25), 0, math.rad(side * 15))
	arm:SetAttribute("Anim", "Swing")
	arm:SetAttribute("AnimAxis", "Z")
	arm:SetAttribute("AnimSpeed", 0.6)
	arm:SetAttribute("AnimAmplitude", 12)
	arm:SetAttribute("AnimPivot", Vector3.new(0, 1.4, 0))
	body("Eyebrow", Vector3.new(0.6, 0.15, 0.15), side * 0.45, 8.75, -0.95, Color3.fromRGB(60, 60, 70)).CFrame *= CFrame.Angles(0, 0, math.rad(side * -20))
	body("Goggle", Vector3.new(0.3, 0.7, 0.7), side * 0.45, 8.25, -0.9, TOXIC, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon }).CFrame *= CFrame.Angles(0, math.rad(90), 0)
	body("HairPuff", Vector3.new(1.1, 1.1, 1.1), side * 1.05, 8.5, 0.3, HAIR, { Shape = Enum.PartType.Ball })
	body("HairTuft", Vector3.new(0.9, 0.9, 0.9), side * 0.55, 9.15, 0.2, HAIR, { Shape = Enum.PartType.Ball })
end
body("CoatTail", Vector3.new(2.8, 1.4, 1.5), 0, 3.6, 0, COAT)
body("Coat", Vector3.new(2.6, 3.2, 1.4), 0, 5.4, 0, COAT)
body("Belt", Vector3.new(2.7, 0.3, 1.5), 0, 4.2, 0, DARK)
body("Head", Vector3.new(2, 2, 2), 0, 8, 0, SKIN, { Shape = Enum.PartType.Ball })
body("HairTop", Vector3.new(1.2, 1.2, 1.2), 0, 9.3, 0.4, HAIR, { Shape = Enum.PartType.Ball })
body("Strap", Vector3.new(2.05, 0.25, 2.05), 0, 8.25, 0, Color3.fromRGB(25, 25, 30), { Shape = Enum.PartType.Cylinder }).CFrame *= CFrame.Angles(0, 0, math.rad(90))
body("Mustache", Vector3.new(1.4, 0.3, 0.3), 0, 7.55, -0.95, Color3.fromRGB(110, 110, 120))
prof.PrimaryPart = base
prof.Parent = lab
CollectionService:AddTag(prof, DECOR_TAG)

-- His name, and a speech bubble GrudgeService fills in when someone steals
local head = prof:FindFirstChild("Head") :: BasePart
local nameGui = Instance.new("BillboardGui")
nameGui.Name = "NameTag"
nameGui.Size = UDim2.fromOffset(240, 32)
nameGui.StudsOffsetWorldSpace = Vector3.new(0, 2.4, 0)
nameGui.MaxDistance = 80
nameGui.AlwaysOnTop = true
nameGui.Parent = head
text("Name", nameGui, "Professor Grudge", TOXIC, UDim2.new(), UDim2.fromScale(1, 1))
local speech = Instance.new("BillboardGui")
speech.Name = "Speech"
speech.Size = UDim2.fromOffset(240, 60)
speech.StudsOffsetWorldSpace = Vector3.new(0, 4.6, 0)
speech.MaxDistance = 120
speech.Enabled = false
speech.Parent = head
local bubble = Instance.new("Frame")
bubble.Name = "Bubble"
bubble.Size = UDim2.fromScale(1, 1)
bubble.BackgroundColor3 = Color3.new(1, 1, 1)
bubble.Parent = speech
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = bubble
local line = Instance.new("TextLabel")
line.Name = "Line"
line.Position = UDim2.fromScale(0.05, 0.08)
line.Size = UDim2.fromScale(0.9, 0.84)
line.BackgroundTransparency = 1
line.Font = Enum.Font.FredokaOne
line.TextScaled = true
line.TextColor3 = Color3.fromRGB(30, 30, 40)
line.Text = ""
line.Parent = bubble

lab.Parent = map

-- The test-tube rack that stood here goes just behind the back wall, as a backdrop
local outskirts = workspace:FindFirstChild("Decor") and workspace.Decor:FindFirstChild("Outskirts")
if outskirts then
	for _, item in outskirts:GetChildren() do
		if item.Name == "TestTubeRack" and item:IsA("Model") and (item:GetPivot().Position - Vector3.new(118, 0, 0)).Magnitude < 2 then
			item:PivotTo(item:GetPivot() + Vector3.new(26, 0, 0))
		end
	end
end

if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
print(`[build-grudge-lab] Built with {#lab:GetDescendants()} pieces`)
