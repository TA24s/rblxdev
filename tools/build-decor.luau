--!strict
-- build-decor.luau
-- One-off builder for the science-lab look: decorations in Workspace.Decor, the lab sign
-- makeover, plaza and ground colours, and the lighting mood. Run it once in Edit mode
-- (Studio command bar or MCP execute_luau). It stops if Workspace.Decor already exists.
-- Animated pieces carry the "AnimatedDecor" tag and are moved by GadgetAnimator on each client.

local CollectionService = game:GetService("CollectionService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Lighting = game:GetService("Lighting")

if workspace:FindFirstChild("Decor") then
	error("Workspace.Decor already exists. Delete it first if you want to rebuild.")
end
local map = workspace:FindFirstChild("Map")
assert(map and map:FindFirstChild("Plaza") and map:FindFirstChild("Labs"), "Workspace.Map is missing")

----- Constants -----
local DECOR_TAG = "AnimatedDecor"
local CYAN = Color3.fromRGB(70, 220, 255)
local GREEN = Color3.fromRGB(110, 255, 120)
local PURPLE = Color3.fromRGB(190, 110, 255)
local PINK = Color3.fromRGB(255, 90, 200)
local ORANGE = Color3.fromRGB(255, 160, 40)
local DARK_METAL = Color3.fromRGB(45, 48, 60)
local SILVER = Color3.fromRGB(200, 205, 215)
local COPPER = Color3.fromRGB(184, 115, 51)
local GLASS = Color3.fromRGB(200, 235, 255)
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- cylinders run along X, this stands them up
local PLAZA_TOP = 1

local recording = ChangeHistoryService:TryBeginRecording("Build science decor")
local rng = Random.new(42) -- fixed seed, so a rebuild looks the same

----- Helpers -----
-- Position on the map by angle (0 = Lab1's direction, 60 = Lab2 ...) and distance from the centre
local function polar(angleDeg: number, radius: number, y: number): Vector3
	local a = math.rad(angleDeg)
	return Vector3.new(radius * math.sin(a), y, radius * math.cos(a))
end

-- Standing at `position`, facing the middle of the map
local function facingCentre(position: Vector3): CFrame
	return CFrame.lookAt(position, Vector3.new(0, position.Y, 0))
end

local function part(props: { [string]: any }, parent: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	if p.Material == Enum.Material.Neon or p.Material == Enum.Material.Glass then
		p.CastShadow = false
	end
	p.Parent = parent
	return p
end

-- A model with an invisible Base at `cf`, used as its PrimaryPart (animations are relative to it)
local function newModel(name: string, cf: CFrame, animated: boolean): Model
	local model = Instance.new("Model")
	model.Name = name
	local base = part({
		Name = "Base",
		Size = Vector3.one,
		CFrame = cf,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	}, model)
	model.PrimaryPart = base
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	if animated then
		CollectionService:AddTag(model, DECOR_TAG)
	end
	return model
end

-- Spin a part around a world-space point, about the part's own Y axis
local function spinAround(p: BasePart, centre: Vector3, degreesPerSecond: number)
	p:SetAttribute("Anim", "Spin")
	p:SetAttribute("AnimAxis", "Y")
	p:SetAttribute("AnimSpeed", degreesPerSecond)
	p:SetAttribute("AnimPivot", p.CFrame:PointToObjectSpace(centre))
end

local function bubbles(parent: BasePart, color: Color3, rate: number, offset: Vector3)
	local attachment = Instance.new("Attachment")
	attachment.Position = offset
	attachment.Parent = parent
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Bubbles"
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.6
	emitter.Size = NumberSequence.new(0.5, 1.2)
	emitter.Transparency = NumberSequence.new(0.2, 1)
	emitter.Speed = NumberRange.new(4, 7)
	emitter.Lifetime = NumberRange.new(1.5, 2.5)
	emitter.SpreadAngle = Vector2.new(15, 15)
	emitter.Rate = rate
	emitter.Parent = attachment
end

local function glow(parent: BasePart, color: Color3, range: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = 2
	light.Parent = parent
end

----- Pieces -----
local function teslaCoil(cf: CFrame): Model
	local m = newModel("TeslaCoil", cf, true)
	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end
	part({ Name = "Plinth", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 10, 10), CFrame = at(0, 1, 0) * UPRIGHT, Material = Enum.Material.Metal, Color = DARK_METAL }, m)
	part({ Name = "Column", Shape = Enum.PartType.Cylinder, Size = Vector3.new(14, 3, 3), CFrame = at(0, 9, 0) * UPRIGHT, Material = Enum.Material.Metal, Color = COPPER }, m)
	for i = 0, 5 do
		part({ Name = "Coil", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 4.2, 4.2), CFrame = at(0, 3.5 + i * 2, 0) * UPRIGHT, Material = Enum.Material.Metal, Color = COPPER:Lerp(Color3.new(0, 0, 0), 0.25) }, m)
	end
	part({ Name = "TopRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 10, 10), CFrame = at(0, 17, 0) * UPRIGHT, Material = Enum.Material.Metal, Color = SILVER }, m)
	local top = part({ Name = "Top", Shape = Enum.PartType.Ball, Size = Vector3.new(6, 6, 6), CFrame = at(0, 18.5, 0), Material = Enum.Material.Metal, Color = SILVER }, m)
	glow(top, CYAN, 26)
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks"
	sparks.Color = ColorSequence.new(CYAN)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.4, 0)
	sparks.Speed = NumberRange.new(8, 14)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Lifetime = NumberRange.new(0.2, 0.4)
	sparks.Rate = 30
	sparks.Parent = top
	-- Zig-zag lightning bolts that flicker
	for bolt = 1, 4 do
		local previous = Vector3.new(0, 18.5, 0)
		for step = 1, 3 do
			local direction = CFrame.Angles(0, math.rad(bolt * 90 + rng:NextInteger(-25, 25)), 0)
			local nextPoint = Vector3.new(0, 18.5 + rng:NextNumber(-2, 2), 0) + direction:VectorToWorldSpace(Vector3.new(0, 0, -(3 + step * 2.2)))
			local segment = part({
				Name = "Bolt",
				Size = Vector3.new(0.25, 0.25, (nextPoint - previous).Magnitude),
				CFrame = cf * CFrame.lookAt((previous + nextPoint) / 2, nextPoint),
				Material = Enum.Material.Neon,
				Color = CYAN,
				CanCollide = false,
			}, m)
			segment:SetAttribute("Anim", "Blink")
			segment:SetAttribute("AnimSpeed", 1.5 + bolt * 0.6)
			previous = nextPoint
		end
	end
	return m
end

local function flask(cf: CFrame, liquidColor: Color3): Model
	local m = newModel("BubblingFlask", cf, false)
	local function at(y: number): CFrame
		return cf * CFrame.new(0, y, 0)
	end
	part({ Name = "Stand", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 10, 10), CFrame = at(0.5) * UPRIGHT, Material = Enum.Material.Metal, Color = DARK_METAL }, m)
	part({ Name = "Bulb", Shape = Enum.PartType.Ball, Size = Vector3.new(12, 12, 12), CFrame = at(7), Material = Enum.Material.Glass, Color = GLASS, Transparency = 0.6 }, m)
	local liquid = part({ Name = "Liquid", Shape = Enum.PartType.Ball, Size = Vector3.new(10.4, 10.4, 10.4), CFrame = at(6.6), Material = Enum.Material.Neon, Color = liquidColor, Transparency = 0.15, CanCollide = false }, m)
	part({ Name = "Neck", Shape = Enum.PartType.Cylinder, Size = Vector3.new(7, 3.5, 3.5), CFrame = at(15.5) * UPRIGHT, Material = Enum.Material.Glass, Color = GLASS, Transparency = 0.6 }, m)
	part({ Name = "Rim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 4.2, 4.2), CFrame = at(19) * UPRIGHT, Material = Enum.Material.Metal, Color = SILVER }, m)
	glow(liquid, liquidColor, 22)
	bubbles(liquid, liquidColor, 6, Vector3.new(0, 12.5, 0)) -- out of the neck
	return m
end

local function dnaHelix(cf: CFrame, colorA: Color3, colorB: Color3): Model
	local m = newModel("DNAHelix", cf, true)
	part({ Name = "Plinth", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 14, 14), CFrame = cf * CFrame.new(0, 1, 0) * UPRIGHT, Material = Enum.Material.Metal, Color = DARK_METAL }, m)
	local RUNGS, HEIGHT, RADIUS = 20, 40, 4
	for i = 0, RUNGS - 1 do
		local centreCf = cf * CFrame.new(0, 4 + i * HEIGHT / RUNGS, 0)
		local rung = centreCf * CFrame.Angles(0, math.rad(i * 30), 0)
		local pieces = {
			part({ Name = "StrandA", Shape = Enum.PartType.Ball, Size = Vector3.new(1.8, 1.8, 1.8), CFrame = rung * CFrame.new(RADIUS, 0, 0), Material = Enum.Material.Neon, Color = colorA, CanCollide = false }, m),
			part({ Name = "StrandB", Shape = Enum.PartType.Ball, Size = Vector3.new(1.8, 1.8, 1.8), CFrame = rung * CFrame.new(-RADIUS, 0, 0), Material = Enum.Material.Neon, Color = colorB, CanCollide = false }, m),
			part({ Name = "Rung", Size = Vector3.new(RADIUS * 2, 0.4, 0.4), CFrame = rung, Material = Enum.Material.SmoothPlastic, Color = Color3.new(1, 1, 1), CanCollide = false }, m),
		}
		for _, piece in pieces do
			spinAround(piece, centreCf.Position, 25)
		end
	end
	return m
end

local function tubeRack(cf: CFrame): Model
	local m = newModel("TestTubeRack", cf, false)
	local function at(x: number, y: number): CFrame
		return cf * CFrame.new(x, y, 0)
	end
	part({ Name = "Shelf", Size = Vector3.new(24, 1.5, 6), CFrame = at(0, 0.75), Material = Enum.Material.Metal, Color = DARK_METAL }, m)
	part({ Name = "TopBar", Size = Vector3.new(24, 1, 6), CFrame = at(0, 14), Material = Enum.Material.Metal, Color = DARK_METAL }, m)
	part({ Name = "LegLeft", Size = Vector3.new(1, 13, 6), CFrame = at(-11.5, 7.5), Material = Enum.Material.Metal, Color = DARK_METAL }, m)
	part({ Name = "LegRight", Size = Vector3.new(1, 13, 6), CFrame = at(11.5, 7.5), Material = Enum.Material.Metal, Color = DARK_METAL }, m)
	local colors = { GREEN, PINK, CYAN, ORANGE, PURPLE }
	for i, color in colors do
		local x = -10 + i * 4 - 2
		part({ Name = "Tube", Shape = Enum.PartType.Cylinder, Size = Vector3.new(22, 3, 3), CFrame = at(x, 12.5) * UPRIGHT, Material = Enum.Material.Glass, Color = GLASS, Transparency = 0.6 }, m)
		local height = rng:NextNumber(7, 15)
		local liquid = part({ Name = "Liquid", Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, 2.6, 2.6), CFrame = at(x, 1.6 + height / 2) * UPRIGHT, Material = Enum.Material.Neon, Color = color, Transparency = 0.1, CanCollide = false }, m)
		-- The tube is turned on its side, so the liquid's "up" is its local X
		bubbles(liquid, color, 2, Vector3.new(height / 2, 0, 0))
		local attachment = liquid:FindFirstChildOfClass("Attachment")
		if attachment then
			attachment.Orientation = Vector3.new(0, 0, -90)
		end
	end
	return m
end

local function atom(centre: Vector3): Model
	local m = newModel("Atom", CFrame.new(centre), true)
	local nucleus = part({ Name = "Nucleus", Shape = Enum.PartType.Ball, Size = Vector3.new(4.5, 4.5, 4.5), CFrame = CFrame.new(centre), Material = Enum.Material.Neon, Color = PINK, CanCollide = false }, m)
	glow(nucleus, PINK, 30)
	local RADIUS, SEGMENTS = 9, 32
	for ring = 1, 3 do
		local ringCf = CFrame.new(centre) * CFrame.Angles(0, math.rad(ring * 60), 0) * CFrame.Angles(math.rad(70), 0, 0)
		local segmentLength = 2 * math.pi * RADIUS / SEGMENTS + 0.1
		for k = 0, SEGMENTS - 1 do
			part({
				Name = "Orbit",
				Size = Vector3.new(segmentLength, 0.25, 0.25),
				CFrame = ringCf * CFrame.Angles(0, math.rad(k * 360 / SEGMENTS), 0) * CFrame.new(0, 0, -RADIUS),
				Material = Enum.Material.Neon,
				Color = CYAN,
				Transparency = 0.35,
				CanCollide = false,
			}, m)
		end
		local electron = part({ Name = "Electron", Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 1.6, 1.6), CFrame = ringCf * CFrame.new(0, 0, -RADIUS), Material = Enum.Material.Neon, Color = Color3.new(1, 1, 1), CanCollide = false }, m)
		spinAround(electron, centre, 90 + ring * 35)
	end
	return m
end

local function pylon(cf: CFrame): Model
	local m = newModel("FencePylon", cf, false)
	part({ Name = "Post", Size = Vector3.new(2, 12, 2), CFrame = cf * CFrame.new(0, 6, 0), Material = Enum.Material.Metal, Color = DARK_METAL }, m)
	part({ Name = "Lamp", Shape = Enum.PartType.Ball, Size = Vector3.new(2.6, 2.6, 2.6), CFrame = cf * CFrame.new(0, 12.5, 0), Material = Enum.Material.Neon, Color = CYAN }, m)
	return m
end

----- Build -----
local decor = Instance.new("Folder")
decor.Name = "Decor"
decor.Parent = workspace

local function section(name: string): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	return folder
end

-- Plaza: Tesla coils and bubbling flasks between the paths, an atom floating over the pipe
local plaza = section("Plaza")
local flaskColors = { GREEN, PURPLE, ORANGE }
for i = 0, 5 do
	local angle = 30 + i * 60
	local cf = facingCentre(polar(angle, 44, PLAZA_TOP))
	if i % 2 == 0 then
		teslaCoil(cf).Parent = plaza
	else
		flask(cf, flaskColors[(i + 1) // 2]).Parent = plaza
	end
end
atom(Vector3.new(0, 36, 0)).Parent = plaza
-- Glowing edges on both sides of the conveyor, and a glowing rim round the plaza
local edges = Instance.new("Model")
edges.Name = "GlowEdges"
for _, half in { 17.3, 10.7 } do
	for _, side in { -1, 1 } do
		part({ Name = "Edge", Size = Vector3.new(half * 2, 0.5, 0.3), CFrame = CFrame.new(0, 1.25, side * half), Material = Enum.Material.Neon, Color = CYAN, CanCollide = false }, edges)
		part({ Name = "Edge", Size = Vector3.new(0.3, 0.5, half * 2), CFrame = CFrame.new(side * half, 1.25, 0), Material = Enum.Material.Neon, Color = CYAN, CanCollide = false }, edges)
	end
end
part({ Name = "PlazaRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.9, 123, 123), CFrame = CFrame.new(0, 0.5, 0) * UPRIGHT, Material = Enum.Material.Neon, Color = CYAN }, edges)
-- Glowing strips along both sides of each path to the labs
for i = 0, 5 do
	local pathCf = CFrame.new(polar(i * 60, 67.5, 1.25)) * CFrame.Angles(0, math.rad(i * 60), 0)
	for _, side in { -1, 1 } do
		part({ Name = "PathEdge", Size = Vector3.new(0.3, 0.5, 17), CFrame = pathCf * CFrame.new(side * 5.2, 0, 0), Material = Enum.Material.Neon, Color = CYAN, CanCollide = false }, edges)
	end
end
edges.Parent = plaza
plaza.Parent = decor
task.wait()

-- Between the labs: spinning DNA towers and giant test-tube racks
local outskirts = section("Outskirts")
for i = 0, 5 do
	local angle = 30 + i * 60
	local cf = facingCentre(polar(angle, 118, 0)) -- the ground (Baseplate) top is at y=0
	if i % 2 == 0 then
		dnaHelix(cf, CYAN, PINK).Parent = outskirts
	else
		tubeRack(cf).Parent = outskirts
	end
end
outskirts.Parent = decor
task.wait()

-- A glowing fence of pylons and laser beams round the edge of the map
local fence = section("Fence")
local FENCE_RADIUS, PYLONS = 150, 24
for i = 0, PYLONS - 1 do
	local here = polar(i * 360 / PYLONS, FENCE_RADIUS, 0)
	local nextPylon = polar((i + 1) * 360 / PYLONS, FENCE_RADIUS, 0)
	pylon(facingCentre(here)).Parent = fence
	for _, height in { 4, 8 } do
		local a, b = here + Vector3.new(0, height, 0), nextPylon + Vector3.new(0, height, 0)
		part({ Name = "Laser", Size = Vector3.new(0.2, 0.2, (b - a).Magnitude), CFrame = CFrame.lookAt((a + b) / 2, b), Material = Enum.Material.Neon, Color = PINK, CanCollide = false }, fence)
	end
end
fence.Parent = decor
task.wait()

----- Recolour the existing ground and plaza -----
local baseplate = workspace:FindFirstChild("Baseplate")
if baseplate and baseplate:IsA("BasePart") then
	baseplate.Color = Color3.fromRGB(38, 42, 58)
	baseplate.Material = Enum.Material.SmoothPlastic
end
local plazaFloor = map.Plaza:FindFirstChild("Floor")
if plazaFloor and plazaFloor:IsA("BasePart") then
	plazaFloor.Color = Color3.fromRGB(70, 78, 102)
end

----- Lighting: late-afternoon light with a purple science-fiction haze -----
Lighting.ClockTime = 16.8
Lighting.Ambient = Color3.fromRGB(70, 60, 100)
Lighting.OutdoorAmbient = Color3.fromRGB(120, 110, 160)
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
if atmosphere then
	atmosphere.Color = Color3.fromRGB(200, 170, 255)
	atmosphere.Decay = Color3.fromRGB(110, 80, 170)
	atmosphere.Density = 0.3
	atmosphere.Haze = 1.2
	atmosphere.Glare = 0.2
end

----- Lab signs: metal panel, glowing frame in the lab's colour, lab number and a little flask -----
for _, lab in map.Labs:GetChildren() do
	local sign = lab:FindFirstChild("Sign")
	local gui = sign and sign:FindFirstChild("SignGui")
	local ownerName = gui and gui:FindFirstChild("OwnerName")
	if not (lab:IsA("Model") and sign and sign:IsA("BasePart") and gui and gui:IsA("SurfaceGui") and ownerName and ownerName:IsA("TextLabel")) then
		warn(`[build-decor] {lab.Name} has no Sign/SignGui/OwnerName, skipped`)
		continue
	end
	local walls = lab:FindFirstChild("Walls")
	local back = walls and walls:FindFirstChild("Back")
	local accent = if back and back:IsA("BasePart") then back.Color else CYAN
	local labIndex = lab:GetAttribute("LabIndex") or 0

	sign.Size = Vector3.new(16, 4, 0.6)
	sign.CFrame = sign.CFrame * CFrame.new(0, 0.5, 0)
	sign.Material = Enum.Material.Metal
	sign.Color = Color3.fromRGB(30, 32, 42)

	local signDecor = Instance.new("Model")
	signDecor.Name = "SignDecor"
	local c = sign.CFrame
	part({ Name = "FrameTop", Size = Vector3.new(16.6, 0.3, 0.8), CFrame = c * CFrame.new(0, 2.15, 0), Material = Enum.Material.Neon, Color = accent, CanCollide = false }, signDecor)
	part({ Name = "FrameBottom", Size = Vector3.new(16.6, 0.3, 0.8), CFrame = c * CFrame.new(0, -2.15, 0), Material = Enum.Material.Neon, Color = accent, CanCollide = false }, signDecor)
	part({ Name = "FrameLeft", Size = Vector3.new(0.3, 4.6, 0.8), CFrame = c * CFrame.new(-8.15, 0, 0), Material = Enum.Material.Neon, Color = accent, CanCollide = false }, signDecor)
	part({ Name = "FrameRight", Size = Vector3.new(0.3, 4.6, 0.8), CFrame = c * CFrame.new(8.15, 0, 0), Material = Enum.Material.Neon, Color = accent, CanCollide = false }, signDecor)
	-- A little flask on top of the sign, glowing in the lab's colour
	part({ Name = "FlaskBulb", Shape = Enum.PartType.Ball, Size = Vector3.new(2.4, 2.4, 2.4), CFrame = c * CFrame.new(0, 3.4, 0), Material = Enum.Material.Glass, Color = GLASS, Transparency = 0.5, CanCollide = false }, signDecor)
	local flaskLiquid = part({ Name = "FlaskLiquid", Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2, 2), CFrame = c * CFrame.new(0, 3.3, 0), Material = Enum.Material.Neon, Color = accent, CanCollide = false }, signDecor)
	part({ Name = "FlaskNeck", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4, 0.8, 0.8), CFrame = c * CFrame.new(0, 4.9, 0) * UPRIGHT, Material = Enum.Material.Glass, Color = GLASS, Transparency = 0.5, CanCollide = false }, signDecor)
	glow(flaskLiquid, accent, 12)
	signDecor.Parent = lab

	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0
	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.new(1, 1, 1)
	background.BorderSizePixel = 0
	background.ZIndex = 0
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.fromRGB(20, 22, 34), accent:Lerp(Color3.fromRGB(20, 22, 34), 0.55))
	gradient.Rotation = 90
	gradient.Parent = background
	background.Parent = gui

	local labNumber = Instance.new("TextLabel")
	labNumber.Name = "LabNumber"
	labNumber.BackgroundTransparency = 1
	labNumber.Position = UDim2.fromScale(0.05, 0.06)
	labNumber.Size = UDim2.fromScale(0.9, 0.3)
	labNumber.Font = Enum.Font.FredokaOne
	labNumber.TextScaled = true
	labNumber.TextColor3 = accent
	labNumber.Text = `🧪 LAB {labIndex} 🧪`
	labNumber.ZIndex = 2
	labNumber.Parent = gui

	ownerName.BackgroundTransparency = 1
	ownerName.Position = UDim2.fromScale(0.05, 0.38)
	ownerName.Size = UDim2.fromScale(0.9, 0.55)
	ownerName.Font = Enum.Font.FredokaOne
	ownerName.TextScaled = true
	ownerName.TextColor3 = Color3.new(1, 1, 1)
	ownerName.ZIndex = 2
	local stroke = ownerName:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	stroke.Color = accent
	stroke.Thickness = 3
	stroke.Parent = ownerName
end

if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
print("[build-decor] Done")
