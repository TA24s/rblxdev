--!strict
-- build-title-sign.luau
-- One-off builder for the giant "GIZMO GRAB" title sign standing in the mountains behind Lab 4,
-- facing the plaza (the side players see first from the spawn). Hollywood-style letters on
-- scaffolding legs, with the O as a spinning gear, a crane claw bobbing over "GRAB" with a
-- glowing gadget in its grip, a row of twinkling bulbs, a tagline and two sweeping searchlights.
-- The letters are SurfaceGui text (FredokaOne, like the HUD); everything else is parts.
-- Moving pieces carry the "AnimatedDecor" tag and are moved by GadgetAnimator on each client.
-- Run once in Edit mode; it is one undo step. Stops if Workspace.Decor.TitleSign already exists.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")

local decor = workspace:FindFirstChild("Decor")
assert(decor, "Run build-decor.luau first (Workspace.Decor is missing)")
if decor:FindFirstChild("TitleSign") then
	error("Workspace.Decor.TitleSign already exists. Undo or delete it first to rebuild.")
end

----- Constants -----
local DECOR_TAG = "AnimatedDecor"
local CYAN = Color3.fromRGB(70, 220, 255)
local PINK = Color3.fromRGB(255, 90, 200)
local PURPLE = Color3.fromRGB(190, 110, 255)
local YELLOW = Color3.fromRGB(255, 200, 40)
local SHADOW = Color3.fromRGB(40, 18, 70)
local METAL = Color3.fromRGB(60, 56, 78)

local CENTRE_ANGLE = 178 -- degrees round the arena (0 = Lab 1, 180 = Lab 4)
local RADIUS = 200 -- studs from the arena centre, on the foothills in front of the peaks
local BASE_Y = 96 -- bottom of the letters, above most of the ridge behind
local CAP = 24 -- letter height in studs
local PIXELS_PER_STUD = 100 * 0.72 / CAP -- a 100px font has capitals about 72px tall
local PANEL_HEIGHT = 40
local LOOK_AT_Y = 60 -- letters lean forward a little, towards players on the ground
local GAP = 2

-- Each slot: the character and how wide it is (glyph width as a share of the letter height)
local SLOTS = {
	{ char = "G", ratio = 0.95, color = CYAN },
	{ char = "I", ratio = 0.42, color = CYAN },
	{ char = "Z", ratio = 0.85, color = CYAN },
	{ char = "M", ratio = 1.2, color = CYAN },
	{ char = "GEAR", ratio = 1.25 },
	{ char = " ", ratio = 0.5 },
	{ char = "G", ratio = 0.95, color = PINK },
	{ char = "R", ratio = 0.88, color = PINK },
	{ char = "A", ratio = 0.95, color = PINK },
	{ char = "B", ratio = 0.88, color = PINK },
}

local recording = ChangeHistoryService:TryBeginRecording("Build title sign")
local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }

----- Helpers -----
local function part(props: { [string]: any }, parent: Instance): BasePart
	local p = Instance.new(props.ClassName or "Part") :: BasePart
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		if key ~= "ClassName" then
			(p :: any)[key] = value
		end
	end
	p.Parent = parent
	return p
end

-- A point on the sign's arc, `along` studs from the middle (positive = to the right as seen
-- from the plaza), at height y
local function onArc(along: number, y: number, radius: number?): Vector3
	local r = radius or RADIUS
	local angle = math.rad(CENTRE_ANGLE) - along / r -- seen from the centre, right is clockwise
	return Vector3.new(r * math.sin(angle), y, r * math.cos(angle))
end

local function facingPlaza(position: Vector3): CFrame
	return CFrame.lookAt(position, Vector3.new(0, LOOK_AT_Y, 0))
end

local function groundBelow(position: Vector3): number
	local hit = workspace:Raycast(position, Vector3.new(0, -300, 0), terrainOnly)
	return if hit then hit.Position.Y else 0
end

-- Text on the front of an invisible panel
local function textPanel(name: string, cf: CFrame, width: number, height: number, text: string, color: Color3, stroke: number, parent: Instance, capHeight: number?)
	local panel = part({ Name = name, Size = Vector3.new(width, height, 0.2), CFrame = cf, Transparency = 1 }, parent)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = if capHeight then 100 * 0.72 / capHeight else PIXELS_PER_STUD
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.MaxDistance = 2000
	gui.Parent = panel
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 100
	label.TextColor3 = color
	label.Text = text
	label.Parent = gui
	if stroke > 0 then
		local outline = Instance.new("UIStroke")
		outline.Color = SHADOW
		outline.Thickness = stroke
		outline.Parent = label
	end
	return panel
end

local function spin(p: BasePart, centre: Vector3, axis: string, degreesPerSecond: number)
	p:SetAttribute("Anim", "Spin")
	p:SetAttribute("AnimAxis", axis)
	p:SetAttribute("AnimSpeed", degreesPerSecond)
	p:SetAttribute("AnimPivot", p.CFrame:PointToObjectSpace(centre))
end

local function bob(p: BasePart, amplitude: number, speed: number)
	p:SetAttribute("Anim", "Bob")
	p:SetAttribute("AnimAmplitude", amplitude)
	p:SetAttribute("AnimSpeed", speed)
end

-- A dark metal beam between two points
local function beam(name: string, a: Vector3, b: Vector3, thickness: number, parent: Instance)
	return part({
		Name = name,
		Size = Vector3.new(thickness, thickness, (b - a).Magnitude),
		CFrame = CFrame.lookAt((a + b) / 2, b),
		Color = METAL,
		Material = Enum.Material.DiamondPlate,
	}, parent)
end

----- The sign -----
local sign = Instance.new("Model")
sign.Name = "TitleSign"
local base = part({ Name = "Base", Size = Vector3.one, CFrame = facingPlaza(onArc(0, BASE_Y)), Transparency = 1 }, sign)
sign.PrimaryPart = base
-- Always loaded, so it can be seen from anywhere in the arena
sign.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
CollectionService:AddTag(sign, DECOR_TAG)

local letters = Instance.new("Folder")
letters.Name = "Letters"
letters.Parent = sign
local legs = Instance.new("Folder")
legs.Name = "Scaffolding"
legs.Parent = sign

-- Lay the slots out along the arc, centred on the middle
local widths = {}
local total = 0
for i, slot in SLOTS do
	widths[i] = slot.ratio * CAP
	total += widths[i] + (if i > 1 then GAP else 0)
end
local cursor = -total / 2
local letterCentreY = BASE_Y + CAP / 2
local slotCentres: { number } = {}
for i, slot in SLOTS do
	local along = cursor + widths[i] / 2
	slotCentres[i] = along
	cursor += widths[i] + GAP
	local cf = facingPlaza(onArc(along, letterCentreY))

	if slot.char == "GEAR" then
		-- The O is a big spinning gear, like the Bolts icon
		local gear = Instance.new("Model")
		gear.Name = "GearO"
		gear.Parent = letters
		local centre = cf.Position
		local disc = cf * CFrame.Angles(0, math.rad(90), 0) -- the cylinder's X axis points at the plaza
		local outer = CAP * 0.62
		part({ Name = "Ring", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, outer * 2, outer * 2), CFrame = disc, Material = Enum.Material.Neon, Color = YELLOW }, gear)
		part({ Name = "Hole", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.3, outer * 1.25, outer * 1.25), CFrame = disc, Color = SHADOW }, gear)
		for k = 0, 9 do
			local tooth = part({
				Name = "Tooth",
				Size = Vector3.new(2, 3.2, 3.4),
				CFrame = disc * CFrame.Angles(math.rad(36 * k), 0, 0) * CFrame.new(0, outer + 1.2, 0),
				Material = Enum.Material.Neon,
				Color = YELLOW,
			}, gear)
			spin(tooth, centre, "X", 40)
		end
		for k = 0, 2 do
			local spoke = part({
				Name = "Spoke",
				Size = Vector3.new(2.5, outer * 1.15, 1.4),
				CFrame = disc * CFrame.Angles(math.rad(60 * k), 0, 0),
				Material = Enum.Material.Neon,
				Color = YELLOW,
			}, gear)
			spin(spoke, centre, "X", 40)
		end
		part({ Name = "Axle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.8, 3, 3), CFrame = disc, Material = Enum.Material.Neon, Color = PINK }, gear)
	elseif slot.char ~= " " then
		local width = widths[i] + 4
		textPanel(`Letter{i}`, cf, width, PANEL_HEIGHT, slot.char, slot.color, 4, letters)
		-- A dark copy just behind and down-right (as seen from the plaza), so the letters look thick
		textPanel(`Shadow{i}`, cf * CFrame.new(-0.9, -0.9, 1.2), width, PANEL_HEIGHT, slot.char, SHADOW, 0, letters)
	end

	-- Two legs and a cross brace down to the mountain under every letter
	if slot.char ~= " " then
		local legTops = {}
		for _, side in { -1, 1 } do
			local top = (cf * CFrame.new(side * widths[i] * 0.25, -CAP / 2, 1.8)).Position
			local bottom = Vector3.new(top.X, groundBelow(top) - 2, top.Z)
			beam("Leg", top, bottom, 1.2, legs)
			table.insert(legTops, top)
		end
		local braceDrop = math.min(12, (legTops[1].Y - groundBelow(legTops[1])) * 0.6)
		beam("Brace", legTops[1], legTops[2] - Vector3.new(0, braceDrop, 0), 0.7, legs)
		beam("Brace", legTops[2], legTops[1] - Vector3.new(0, braceDrop, 0), 0.7, legs)
	end
end

----- Twinkling bulbs along the bottom, and the tagline -----
local bulbs = Instance.new("Folder")
bulbs.Name = "Bulbs"
bulbs.Parent = sign
local stripY = BASE_Y - 2.5
local halfWidth = total / 2 + 2
local bulbCount = math.floor(total / 4)
for b = 0, bulbCount do
	local along = -halfWidth + (2 * halfWidth) * b / bulbCount
	if b > 0 then
		-- The rail is made of short straight pieces between bulbs, so it follows the curve
		local previous = -halfWidth + (2 * halfWidth) * (b - 1) / bulbCount
		beam("BulbRail", onArc(previous, stripY - 1), onArc(along, stripY - 1), 1, bulbs)
	end
	local bulb = part({
		Name = "Bulb",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.4, 1.4, 1.4),
		CFrame = CFrame.new(onArc(along, stripY, RADIUS - 0.8)),
		Material = Enum.Material.Neon,
		Color = if b % 3 == 0 then YELLOW elseif b % 3 == 1 then PINK else CYAN,
	}, bulbs)
	bulb:SetAttribute("Anim", "Blink")
	bulb:SetAttribute("AnimSpeed", if b % 2 == 0 then 1.1 else 1.6)
end
textPanel("Tagline", facingPlaza(onArc(0, stripY - 7, RADIUS - 6)), 130, 9, "GRAB  ⚙  COLLECT  ⚙  BOING!", PURPLE, 2, sign, 6)

----- Crane claw over "GRAB" -----
local claw = Instance.new("Folder")
claw.Name = "Claw"
claw.Parent = sign
local grabMiddle = (slotCentres[7] + slotCentres[10]) / 2
local poleAlong = total / 2 + 8
local armY = BASE_Y + CAP + 16
local poleTop = onArc(poleAlong, armY + 2, RADIUS + 3)
beam("Pole", poleTop, Vector3.new(poleTop.X, groundBelow(poleTop) - 2, poleTop.Z), 2.4, claw)
local armEnd = onArc(grabMiddle, armY, RADIUS + 3)
beam("Arm", onArc(poleAlong + 1.5, armY, RADIUS + 3), armEnd, 2.4, claw)
-- Upright pieces only, so the bob moves them straight up and down
local clawTop = armEnd - Vector3.new(0, 1.2, 0)
local hubY = BASE_Y + CAP + 5
local cable = part({ Name = "Cable", Size = Vector3.new(0.4, clawTop.Y - hubY, 0.4), CFrame = CFrame.new(armEnd.X, (clawTop.Y + hubY) / 2, armEnd.Z), Color = METAL }, claw)
local hub = part({ Name = "Hub", Size = Vector3.new(3.4, 1.6, 3.4), CFrame = CFrame.new(armEnd.X, hubY, armEnd.Z), Color = METAL, Material = Enum.Material.DiamondPlate }, claw)
local clawParts = { cable, hub }
for k = 0, 2 do
	local turn = CFrame.new(hub.Position) * CFrame.Angles(0, math.rad(120 * k), 0)
	table.insert(clawParts, part({ Name = "Finger", Size = Vector3.new(0.7, 4, 0.7), CFrame = turn * CFrame.new(0, -2.6, -2.2), Color = YELLOW, Material = Enum.Material.Neon }, claw))
	table.insert(clawParts, part({ Name = "FingerTip", Size = Vector3.new(0.7, 0.7, 1.6), CFrame = turn * CFrame.new(0, -4.3, -1.6), Color = YELLOW, Material = Enum.Material.Neon }, claw))
end
local prize = part({
	Name = "Prize",
	Shape = Enum.PartType.Ball,
	Size = Vector3.new(2.6, 2.6, 2.6),
	CFrame = CFrame.new(hub.Position - Vector3.new(0, 3.6, 0)),
	Color = PINK,
	Material = Enum.Material.Neon,
}, claw)
table.insert(clawParts, prize)
local glow = Instance.new("PointLight")
glow.Color = PINK
glow.Range = 16
glow.Brightness = 2
glow.Parent = prize
for _, p in clawParts do
	bob(p, 3, 0.35)
end

----- Searchlights at both ends -----
for _, side in { -1, 1 } do
	local spot = onArc(side * (total / 2 + 14), 0, RADIUS - 6)
	local ground = groundBelow(Vector3.new(spot.X, 300, spot.Z))
	local lamp = part({
		Name = "Searchlight",
		Size = Vector3.new(3, 3, 3),
		CFrame = CFrame.new(spot.X, ground + 1.5, spot.Z) * CFrame.Angles(0, math.rad(CENTRE_ANGLE), 0),
		Color = METAL,
		Material = Enum.Material.DiamondPlate,
	}, sign)
	local from = Instance.new("Attachment")
	from.Position = Vector3.new(0, 1.5, 0)
	from.Parent = lamp
	local to = Instance.new("Attachment")
	to.Position = Vector3.new(0, 170, 0)
	to.Parent = lamp
	local light = Instance.new("Beam")
	light.Attachment0 = from
	light.Attachment1 = to
	light.Color = ColorSequence.new(if side < 0 then CYAN else PINK)
	light.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	light.LightEmission = 1
	light.Width0 = 3
	light.Width1 = 18
	light.FaceCamera = true
	light.Segments = 1
	light.Parent = lamp
	lamp:SetAttribute("Anim", "Swing")
	lamp:SetAttribute("AnimAxis", "Z") -- sweeps side to side, as seen from the plaza
	lamp:SetAttribute("AnimAmplitude", 28)
	lamp:SetAttribute("AnimSpeed", if side < 0 then 0.12 else 0.09)
end

sign.Parent = decor
if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
local count = 0
for _, d in sign:GetDescendants() do
	if d:IsA("BasePart") then
		count += 1
	end
end
print(`[build-title-sign] Built the title sign: {count} parts, {math.floor(total)} studs wide`)
