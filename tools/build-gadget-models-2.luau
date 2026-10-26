--!strict
-- build-gadget-models-2
-- Run once in the Studio command bar (or through MCP execute_luau) to add the three gadgets from
-- Stage 15 to ServerStorage/GadgetModels: Weather Remote (Epic), Gravity Toggle (Mythic) and The
-- Do-Everything Machine (Forbidden). Same model conventions as build-gadget-models.luau.
-- It stops if any of the three already exists, so it never overwrites hand edits. One undo step.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ServerStorage = game:GetService("ServerStorage")

local folder = ServerStorage:FindFirstChild("GadgetModels")
if not folder then
	return "ABORT: ServerStorage.GadgetModels is missing; run build-gadget-models.luau first"
end
for _, id in { "WeatherRemote", "GravityToggle", "DoEverythingMachine" } do
	if folder:FindFirstChild(id) then
		return `ABORT: ServerStorage.GadgetModels.{id} already exists, nothing changed`
	end
end

type PartProps = { [string]: any }

local function makePart(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3, props: PartProps?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Anchored = true
	p.CanCollide = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	if props then
		for key, value in props do
			if key == "Attributes" then
				for attr, attrValue in value do
					p:SetAttribute(attr, attrValue)
				end
			else
				(p :: any)[key] = value
			end
		end
	end
	p.Parent = model
	return p
end

local function newGadget(id: string): Model
	local model = Instance.new("Model")
	model.Name = id
	model:SetAttribute("GadgetId", id)
	model:AddTag("Gadget") -- GadgetAnimator finds gadgets by this tag
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- clients always receive the whole model
	local base = makePart(model, "Base", Vector3.new(4, 0.2, 4), CFrame.new(0, 0.1, 0), Color3.new(1, 1, 1), {
		Transparency = 1,
	})
	model.PrimaryPart = base
	return model
end

local function light(parent: BasePart, color: Color3, range: number)
	local glow = Instance.new("PointLight")
	glow.Color = color
	glow.Range = range
	glow.Brightness = 2
	glow.Parent = parent
end

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- turns a Cylinder's axis to vertical
local FACING = CFrame.Angles(0, math.rad(90), 0) -- turns a Cylinder's axis to point forwards (Z)
local recording = ChangeHistoryService:TryBeginRecording("Build Stage 15 gadgets")
local built: { Model } = {}

-- Weather Remote (Epic): a TV remote with its own tiny rain cloud and the odd flash of lightning
do
	local m = newGadget("WeatherRemote")
	local plastic = Color3.fromRGB(45, 45, 55)
	makePart(m, "Stand", Vector3.new(2.2, 0.4, 2.2), CFrame.new(0, 0.4, 0), Color3.fromRGB(90, 90, 105))
	makePart(m, "Remote", Vector3.new(1.4, 3, 0.6), CFrame.new(0, 2, 0) * CFrame.Angles(math.rad(-15), 0, 0), plastic)
	local buttons = { Color3.fromRGB(255, 80, 80), Color3.fromRGB(80, 200, 255), Color3.fromRGB(255, 220, 60), Color3.fromRGB(120, 255, 120) }
	for i, color in buttons do
		local row = math.floor((i - 1) / 2)
		local col = (i - 1) % 2
		makePart(m, "Button", Vector3.new(0.15, 0.4, 0.4), CFrame.new(0, 2, 0) * CFrame.Angles(math.rad(-15), 0, 0) * CFrame.new(-0.3 + col * 0.6, 0.6 - row * 0.6, -0.35) * FACING, color, {
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.Neon,
		})
	end
	-- The cloud floats above the remote, raining
	local float = { Anim = "Bob", AnimAmplitude = 0.3, AnimSpeed = 0.6 }
	local grey = Color3.fromRGB(150, 155, 170)
	local core = makePart(m, "Cloud", Vector3.new(1.6, 1.6, 1.6), CFrame.new(0, 4.6, 0), grey, { Shape = Enum.PartType.Ball, Attributes = float })
	makePart(m, "CloudLeft", Vector3.new(1.2, 1.2, 1.2), CFrame.new(-0.9, 4.4, 0.1), grey, { Shape = Enum.PartType.Ball, Attributes = float })
	makePart(m, "CloudRight", Vector3.new(1.3, 1.3, 1.3), CFrame.new(0.9, 4.45, -0.1), grey, { Shape = Enum.PartType.Ball, Attributes = float })
	makePart(m, "Lightning", Vector3.new(0.15, 1.1, 0.3), CFrame.new(0.4, 3.5, 0) * CFrame.Angles(0, 0, math.rad(20)), Color3.fromRGB(255, 240, 90), {
		Material = Enum.Material.Neon,
		Attributes = { Anim = "Blink", AnimSpeed = 0.4 },
	})
	local rain = Instance.new("ParticleEmitter")
	rain.Name = "Rain"
	rain.Rate = 25
	rain.Lifetime = NumberRange.new(0.5, 0.7)
	rain.Speed = NumberRange.new(5, 6)
	rain.SpreadAngle = Vector2.new(12, 12)
	rain.Size = NumberSequence.new(0.08)
	rain.Squash = NumberSequence.new(-2) -- long thin drops
	rain.Color = ColorSequence.new(Color3.fromRGB(120, 190, 255))
	rain.LightEmission = 0.4
	rain.EmissionDirection = Enum.NormalId.Bottom
	rain.Parent = core
	table.insert(built, m)
end

-- Gravity Toggle (Mythic): a big lever on a pedestal, with blocks floating round it
do
	local m = newGadget("GravityToggle")
	local metal = Color3.fromRGB(70, 70, 90)
	local purple = Color3.fromRGB(190, 90, 255)
	makePart(m, "Pedestal", Vector3.new(0.8, 3.8, 3.8), CFrame.new(0, 0.4, 0) * UPRIGHT, metal, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Metal })
	makePart(m, "Rim", Vector3.new(0.2, 3.9, 3.9), CFrame.new(0, 0.85, 0) * UPRIGHT, purple, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon })
	makePart(m, "Box", Vector3.new(1.6, 1.2, 1.2), CFrame.new(0, 1.4, 0), Color3.fromRGB(40, 40, 55))
	makePart(m, "Label", Vector3.new(1.2, 0.3, 0.05), CFrame.new(0, 1.55, -0.62), Color3.fromRGB(255, 220, 60), { Material = Enum.Material.Neon })
	-- The lever rocks back and forth about its hinge at the bottom
	local rock = { Anim = "Swing", AnimAxis = "X", AnimAmplitude = 30, AnimSpeed = 0.5, AnimPivot = Vector3.new(0, -1, 0) }
	makePart(m, "Lever", Vector3.new(0.3, 2, 0.3), CFrame.new(0, 3, 0), Color3.fromRGB(200, 200, 210), { Material = Enum.Material.Metal, Attributes = rock })
	makePart(m, "Knob", Vector3.new(0.7, 0.7, 0.7), CFrame.new(0, 4.1, 0), Color3.fromRGB(255, 60, 90), {
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.Neon,
		Attributes = { Anim = "Swing", AnimAxis = "X", AnimAmplitude = 30, AnimSpeed = 0.5, AnimPivot = Vector3.new(0, -2.1, 0) },
	})
	-- Odds and ends floating up and down, each at its own pace
	local junk = {
		{ Vector3.new(1.5, 2.4, 0.9), Vector3.new(0.5, 0.5, 0.5), Color3.fromRGB(255, 180, 60) },
		{ Vector3.new(-1.5, 3, 0.7), Vector3.new(0.6, 0.4, 0.4), Color3.fromRGB(90, 200, 255) },
		{ Vector3.new(1.2, 3.6, -1.2), Vector3.new(0.4, 0.4, 0.4), Color3.fromRGB(120, 255, 140) },
		{ Vector3.new(-1.1, 2.2, -1.3), Vector3.new(0.5, 0.3, 0.5), Color3.fromRGB(255, 120, 200) },
	}
	for i, piece in junk do
		makePart(m, "Floater", piece[2], CFrame.new(piece[1]) * CFrame.Angles(math.rad(i * 25), math.rad(i * 40), 0), piece[3], {
			Attributes = { Anim = "Bob", AnimAmplitude = 0.45, AnimSpeed = 0.35 + i * 0.12 },
		})
	end
	-- A ring of glowing orbs circling the lever
	for i = 1, 6 do
		local angle = math.rad(i * 60)
		local offset = Vector3.new(math.cos(angle) * 1.7, 0, math.sin(angle) * 1.7)
		local orb = makePart(m, "Orb", Vector3.new(0.3, 0.3, 0.3), CFrame.new(offset + Vector3.new(0, 1.3, 0)), purple, {
			Shape = Enum.PartType.Ball,
			Material = Enum.Material.Neon,
			Attributes = { Anim = "Spin", AnimAxis = "Y", AnimSpeed = 60, AnimPivot = -offset },
		})
		if i == 1 then
			light(orb, purple, 10)
		end
	end
	table.insert(built, m)
end

-- The Do-Everything Machine (Forbidden): one machine doing every other gadget's gag at once
do
	local m = newGadget("DoEverythingMachine")
	local white = Color3.fromRGB(235, 235, 245)
	local body = makePart(m, "Body", Vector3.new(3.6, 3, 3), CFrame.new(0, 1.7, 0), white, { Material = Enum.Material.Metal })
	makePart(m, "Stripe", Vector3.new(3.7, 0.25, 3.1), CFrame.new(0, 2.6, 0), Color3.fromRGB(255, 200, 40), { Material = Enum.Material.Neon })
	makePart(m, "Dome", Vector3.new(2.2, 2.2, 2.2), CFrame.new(0, 3.3, 0), Color3.fromRGB(160, 230, 255), {
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.Glass,
		Transparency = 0.4,
	})
	-- Gear on the front (Cat-Powered Wi-Fi's wheel)
	makePart(m, "Gear", Vector3.new(0.3, 1.6, 1.6), CFrame.new(-0.7, 1.5, -1.6) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(255, 190, 40), {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Metal,
		Attributes = { Anim = "Spin", AnimAxis = "X", AnimSpeed = 200 },
	})
	-- Three lights winking at different speeds (Sock Teleporter)
	local lights = { Color3.fromRGB(255, 70, 70), Color3.fromRGB(80, 255, 120), Color3.fromRGB(80, 160, 255) }
	for i, color in lights do
		makePart(m, "Light", Vector3.new(0.4, 0.4, 0.4), CFrame.new(0.4 + (i - 1) * 0.5, 1.9, -1.55), color, {
			Shape = Enum.PartType.Ball,
			Material = Enum.Material.Neon,
			Attributes = { Anim = "Blink", AnimSpeed = 0.6 + i * 0.35 },
		})
	end
	-- A hand slapping the side (Self-Slapping Alarm Clock)
	makePart(m, "Arm", Vector3.new(0.35, 1.6, 0.35), CFrame.new(2, 2.6, 0), white, {
		Attributes = { Anim = "Swing", AnimAxis = "Z", AnimAmplitude = 35, AnimSpeed = 1.5, AnimPivot = Vector3.new(0, -0.8, 0) },
	})
	makePart(m, "Hand", Vector3.new(0.6, 0.6, 0.6), CFrame.new(2, 3.6, 0), Color3.fromRGB(255, 205, 160), {
		Shape = Enum.PartType.Ball,
		Attributes = { Anim = "Swing", AnimAxis = "Z", AnimAmplitude = 35, AnimSpeed = 1.5, AnimPivot = Vector3.new(0, -1.8, 0) },
	})
	-- Toast popping out of the top (Toaster Cannon)
	makePart(m, "Toast", Vector3.new(0.9, 1, 0.25), CFrame.new(-1, 4.3, 0.8), Color3.fromRGB(220, 160, 80), {
		Attributes = { Anim = "Bob", AnimAmplitude = 0.8, AnimSpeed = 1.1 },
	})
	-- A spoon stirring in the dome (Self-Stirring Spoon)
	makePart(m, "Spoon", Vector3.new(0.2, 2, 0.4), CFrame.new(0, 3.6, 0) * CFrame.Angles(0, 0, math.rad(15)), Color3.fromRGB(200, 205, 215), {
		Material = Enum.Material.Metal,
		Attributes = { Anim = "Spin", AnimAxis = "Y", AnimSpeed = 240 },
	})
	-- An antenna bobbing on top (Squeaky Shoe Phone)
	makePart(m, "Antenna", Vector3.new(0.15, 1.2, 0.15), CFrame.new(1.1, 3.8, 1), Color3.fromRGB(60, 60, 70), {
		Attributes = { Anim = "Bob", AnimAmplitude = 0.3, AnimSpeed = 2 },
	})
	makePart(m, "AntennaTip", Vector3.new(0.35, 0.35, 0.35), CFrame.new(1.1, 4.5, 1), Color3.fromRGB(255, 80, 160), {
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.Neon,
		Attributes = { Anim = "Bob", AnimAmplitude = 0.3, AnimSpeed = 2 },
	})
	-- Smoke from a chimney at the back (Pocket Volcano)
	local chimney = makePart(m, "Chimney", Vector3.new(0.6, 1.2, 0.6), CFrame.new(-1.2, 3.6, 1.1), Color3.fromRGB(90, 90, 100))
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "Smoke"
	smoke.Rate = 5
	smoke.Lifetime = NumberRange.new(1.5, 2.5)
	smoke.Speed = NumberRange.new(2, 3)
	smoke.SpreadAngle = Vector2.new(15, 15)
	smoke.Size = NumberSequence.new(0.5, 1.4)
	smoke.Transparency = NumberSequence.new(0.3, 1)
	smoke.Color = ColorSequence.new(Color3.fromRGB(200, 180, 255))
	smoke.EmissionDirection = Enum.NormalId.Top
	smoke.Parent = chimney
	light(body, Color3.fromRGB(255, 255, 255), 12)
	table.insert(built, m)
end

local summary = {}
for _, model in built do
	model.Parent = folder
	local size = model:GetExtentsSize()
	table.insert(summary, string.format("%s %.1fx%.1fx%.1f", model.Name, size.X, size.Y, size.Z))
end
if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
return "Built " .. #summary .. " gadgets:\n" .. table.concat(summary, "\n")
