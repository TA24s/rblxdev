--!strict
-- build-gadget-models
-- Run once in the Studio command bar (or through MCP execute_luau) to build the 8 MVP gadget
-- models into ServerStorage/GadgetModels. Kept here so the models can be rebuilt or tweaked.
-- It refuses to run if GadgetModels already exists, so it never overwrites hand edits.
--
-- Model conventions (other scripts rely on these):
--   * Model name == Gadgets config Id, plus a GadgetId attribute and the "Gadget" tag
--   * ModelStreamingMode Atomic, so a client never sees half a gadget
--   * PrimaryPart "Base": invisible 4x0.2x4 plate; the model's bottom-centre sits at its pivot
--   * Fits inside a 5x5 footprint, about 3-6 studs tall
--   * All parts Anchored, CanCollide off (gadgets never block players)
--   * Parts with an Anim attribute are animated on each client by GadgetAnimator:
--       Anim = "Spin"  AnimAxis ("X"/"Y"/"Z"), AnimSpeed (degrees per second)
--       Anim = "Bob"   AnimAmplitude (studs), AnimSpeed (cycles per second)
--       Anim = "Swing" AnimAxis, AnimAmplitude (degrees), AnimSpeed (cycles per second),
--                      optional AnimPivot (Vector3, hinge point in the part's local space)
--       Anim = "Blink" AnimSpeed (cycles per second): fades in and out

local ServerStorage = game:GetService("ServerStorage")

if ServerStorage:FindFirstChild("GadgetModels") then
	return "ABORT: ServerStorage.GadgetModels already exists, nothing changed"
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

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- turns a Cylinder's axis to vertical
local folder = Instance.new("Folder")
folder.Name = "GadgetModels"

-- 1. Self-Stirring Spoon (Common): a mug with a spoon that stirs itself
do
	local m = newGadget("SelfStirringSpoon")
	makePart(m, "Mug", Vector3.new(2.4, 2.6, 2.6), CFrame.new(0, 1.2, 0) * UPRIGHT, Color3.fromRGB(240, 240, 245), { Shape = Enum.PartType.Cylinder })
	makePart(m, "Coffee", Vector3.new(0.1, 2.3, 2.3), CFrame.new(0, 2.45, 0) * UPRIGHT, Color3.fromRGB(110, 70, 40), { Shape = Enum.PartType.Cylinder })
	makePart(m, "Handle", Vector3.new(0.4, 1.4, 0.9), CFrame.new(1.5, 1.3, 0), Color3.fromRGB(240, 240, 245))
	makePart(m, "Spoon", Vector3.new(0.25, 3, 0.5), CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, math.rad(12)), Color3.fromRGB(200, 205, 215), {
		Material = Enum.Material.Metal,
		Attributes = { Anim = "Spin", AnimAxis = "Y", AnimSpeed = 240 },
	})
	m.Parent = folder
end

-- 2. Squeaky Shoe Phone (Common): a sneaker with an antenna that squeaks up and down
do
	local m = newGadget("SqueakyShoePhone")
	local bob = { Anim = "Bob", AnimAmplitude = 0.35, AnimSpeed = 2 }
	makePart(m, "Sole", Vector3.new(1.8, 0.4, 3.6), CFrame.new(0, 0.4, 0), Color3.fromRGB(245, 245, 245), { Attributes = bob })
	makePart(m, "Upper", Vector3.new(1.7, 1.2, 2.4), CFrame.new(0, 1.2, 0.5), Color3.fromRGB(230, 60, 60), { Attributes = bob })
	makePart(m, "Toe", Vector3.new(1.7, 0.8, 1.2), CFrame.new(0, 0.95, -1.2), Color3.fromRGB(230, 60, 60), { Attributes = bob })
	makePart(m, "Antenna", Vector3.new(0.2, 1.8, 0.2), CFrame.new(0.5, 2.6, 1.2), Color3.fromRGB(40, 40, 45), { Attributes = bob })
	makePart(m, "AntennaTip", Vector3.new(0.45, 0.45, 0.45), CFrame.new(0.5, 3.6, 1.2), Color3.fromRGB(80, 255, 120), {
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.Neon,
		Attributes = bob,
	})
	m.Parent = folder
end

-- 3. Toaster Cannon (Uncommon): a toaster with a barrel that keeps launching toast
do
	local m = newGadget("ToasterCannon")
	makePart(m, "Body", Vector3.new(3, 2, 2), CFrame.new(0, 1.2, 0), Color3.fromRGB(200, 205, 215), { Material = Enum.Material.Metal })
	makePart(m, "Lever", Vector3.new(0.3, 0.3, 0.6), CFrame.new(1.65, 1.6, 0), Color3.fromRGB(40, 40, 45))
	makePart(m, "Barrel", Vector3.new(2.2, 1, 1), CFrame.new(-1.2, 2.6, 0) * CFrame.Angles(0, 0, math.rad(-35)), Color3.fromRGB(60, 60, 70), {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Metal,
	})
	makePart(m, "Toast", Vector3.new(1.4, 1.5, 0.3), CFrame.new(0.4, 2.4, 0), Color3.fromRGB(205, 150, 80), {
		Attributes = { Anim = "Bob", AnimAmplitude = 1.4, AnimSpeed = 1.2 },
	})
	m.Parent = folder
end

-- 4. Sock Teleporter (Uncommon): a glowing pad where a single sock keeps vanishing
do
	local m = newGadget("SockTeleporter")
	makePart(m, "Pad", Vector3.new(0.5, 4, 4), CFrame.new(0, 0.3, 0) * UPRIGHT, Color3.fromRGB(70, 70, 90), {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Metal,
	})
	makePart(m, "Ring", Vector3.new(0.2, 3.2, 3.2), CFrame.new(0, 0.6, 0) * UPRIGHT, Color3.fromRGB(80, 200, 255), {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Neon,
	})
	local blink = { Anim = "Blink", AnimSpeed = 0.8 }
	makePart(m, "SockLeg", Vector3.new(0.8, 1.6, 0.8), CFrame.new(0, 2, 0.2), Color3.fromRGB(250, 250, 250), { Attributes = blink })
	makePart(m, "SockFoot", Vector3.new(0.8, 0.7, 1.4), CFrame.new(0, 1.4, -0.5), Color3.fromRGB(250, 250, 250), { Attributes = blink })
	makePart(m, "SockStripe", Vector3.new(0.85, 0.25, 0.85), CFrame.new(0, 2.5, 0.2), Color3.fromRGB(230, 60, 60), { Attributes = blink })
	m.Parent = folder
end

-- 5. Cat-Powered Wi-Fi (Rare): a hamster-style wheel driving a router
do
	local m = newGadget("CatPoweredWifi")
	makePart(m, "Stand", Vector3.new(0.4, 2.2, 3.6), CFrame.new(-0.6, 1.1, 0), Color3.fromRGB(120, 85, 50), { Material = Enum.Material.Wood })
	makePart(m, "Wheel", Vector3.new(1, 3.4, 3.4), CFrame.new(0.2, 2.2, 0), Color3.fromRGB(255, 160, 60), {
		Shape = Enum.PartType.Cylinder,
		Transparency = 0.2,
		Attributes = { Anim = "Spin", AnimAxis = "X", AnimSpeed = 300 },
	})
	makePart(m, "Router", Vector3.new(1.6, 0.6, 1.4), CFrame.new(1.6, 0.5, 1.2), Color3.fromRGB(30, 30, 35))
	for i = 1, 3 do
		makePart(m, `SignalBar{i}`, Vector3.new(0.2, 0.3 * i, 0.2), CFrame.new(1.1 + i * 0.3, 0.8 + 0.15 * i, 1.2), Color3.fromRGB(80, 255, 120), {
			Material = Enum.Material.Neon,
			Attributes = { Anim = "Blink", AnimSpeed = 1 + i * 0.4 },
		})
	end
	m.Parent = folder
end

-- 6. Self-Slapping Alarm Clock (Rare): an alarm clock with a hand that slaps it
do
	local m = newGadget("SelfSlappingAlarmClock")
	makePart(m, "Clock", Vector3.new(1.2, 2.8, 2.8), CFrame.new(0, 1.8, 0) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(230, 60, 60), {
		Shape = Enum.PartType.Cylinder,
	})
	makePart(m, "Face", Vector3.new(0.1, 2.3, 2.3), CFrame.new(0, 1.8, -0.62) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(250, 250, 240), {
		Shape = Enum.PartType.Cylinder,
	})
	makePart(m, "BellLeft", Vector3.new(0.9, 0.9, 0.9), CFrame.new(-0.9, 3.3, 0), Color3.fromRGB(255, 200, 40), { Shape = Enum.PartType.Ball, Material = Enum.Material.Metal })
	makePart(m, "BellRight", Vector3.new(0.9, 0.9, 0.9), CFrame.new(0.9, 3.3, 0), Color3.fromRGB(255, 200, 40), { Shape = Enum.PartType.Ball, Material = Enum.Material.Metal })
	makePart(m, "Arm", Vector3.new(0.35, 2.4, 0.35), CFrame.new(1.9, 2.6, 0), Color3.fromRGB(60, 60, 70), {
		Attributes = { Anim = "Swing", AnimAxis = "Z", AnimAmplitude = 35, AnimSpeed = 1.5, AnimPivot = Vector3.new(0, -1.2, 0) },
	})
	makePart(m, "Hand", Vector3.new(0.4, 0.9, 1), CFrame.new(1.9, 4, 0), Color3.fromRGB(255, 205, 160), {
		Attributes = { Anim = "Swing", AnimAxis = "Z", AnimAmplitude = 35, AnimSpeed = 1.5, AnimPivot = Vector3.new(0, -2.6, 0) },
	})
	m.Parent = folder
end

-- 7. Inflatable Anchor (Epic): a pool-toy anchor that floats instead of sinking
do
	local m = newGadget("InflatableAnchor")
	local float = { Anim = "Bob", AnimAmplitude = 0.6, AnimSpeed = 0.5 }
	local yellow = Color3.fromRGB(255, 220, 60)
	makePart(m, "Shank", Vector3.new(0.8, 3.2, 0.8), CFrame.new(0, 3, 0), yellow, { Material = Enum.Material.Plastic, Attributes = float })
	makePart(m, "Ring", Vector3.new(0.5, 1.4, 1.4), CFrame.new(0, 5, 0), Color3.fromRGB(255, 120, 160), {
		Shape = Enum.PartType.Cylinder,
		Attributes = float,
	})
	makePart(m, "Stock", Vector3.new(2.6, 0.6, 0.6), CFrame.new(0, 4.2, 0), yellow, { Attributes = float })
	makePart(m, "ArmLeft", Vector3.new(1.8, 0.7, 0.7), CFrame.new(-0.8, 1.7, 0) * CFrame.Angles(0, 0, math.rad(-35)), yellow, { Attributes = float })
	makePart(m, "ArmRight", Vector3.new(1.8, 0.7, 0.7), CFrame.new(0.8, 1.7, 0) * CFrame.Angles(0, 0, math.rad(35)), yellow, { Attributes = float })
	makePart(m, "Valve", Vector3.new(0.3, 0.3, 0.3), CFrame.new(0, 2.4, -0.5), Color3.fromRGB(255, 120, 160), { Shape = Enum.PartType.Ball, Attributes = float })
	m.Parent = folder
end

-- 8. Pocket Volcano (Legendary): a tiny volcano that glows and smokes
do
	local m = newGadget("PocketVolcano")
	local rock = Color3.fromRGB(90, 70, 60)
	makePart(m, "Tier1", Vector3.new(1.2, 4.4, 4.4), CFrame.new(0, 0.6, 0) * UPRIGHT, rock, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Basalt })
	makePart(m, "Tier2", Vector3.new(1.2, 3.4, 3.4), CFrame.new(0, 1.7, 0) * UPRIGHT, rock, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Basalt })
	makePart(m, "Tier3", Vector3.new(1.2, 2.4, 2.4), CFrame.new(0, 2.8, 0) * UPRIGHT, rock, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Basalt })
	local lava = makePart(m, "Lava", Vector3.new(0.3, 1.6, 1.6), CFrame.new(0, 3.45, 0) * UPRIGHT, Color3.fromRGB(255, 110, 20), {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Neon,
		Attributes = { Anim = "Blink", AnimSpeed = 0.7 },
	})
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "Smoke"
	smoke.Rate = 6
	smoke.Lifetime = NumberRange.new(1.5, 2.5)
	smoke.Speed = NumberRange.new(2, 3)
	smoke.SpreadAngle = Vector2.new(15, 15)
	smoke.Size = NumberSequence.new(0.6, 1.6)
	smoke.Transparency = NumberSequence.new(0.3, 1)
	smoke.Color = ColorSequence.new(Color3.fromRGB(120, 120, 120))
	smoke.EmissionDirection = Enum.NormalId.Right -- the cylinder's axis points up after UPRIGHT
	smoke.Parent = lava
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 120, 30)
	glow.Range = 8
	glow.Brightness = 2
	glow.Parent = lava
	m.Parent = folder
end

folder.Parent = ServerStorage

local summary = {}
for _, model in folder:GetChildren() do
	if model:IsA("Model") then
		local size = model:GetExtentsSize()
		table.insert(summary, string.format("%s %.1fx%.1fx%.1f", model.Name, size.X, size.Y, size.Z))
	end
end
table.sort(summary)
return "Built " .. #summary .. " gadgets:\n" .. table.concat(summary, "\n")
