--!strict
-- build-mountains.luau
-- One-off builder for the scenery outside the arena: a ring of terrain mountains, four cave
-- mouths with glowing crystals (look only, they sit behind the barrier), and an invisible wall
-- along the laser fence so players can't leave the arena. Run once in Edit mode; it is one
-- undo step. Stops if Workspace.Decor.Caves already exists.

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local decor = workspace:FindFirstChild("Decor")
assert(decor, "Run build-decor.luau first (Workspace.Decor is missing)")
if decor:FindFirstChild("Caves") then
	error("Workspace.Decor.Caves already exists. Undo or delete it first to rebuild.")
end

----- Constants -----
local terrain = workspace.Terrain
local CYAN = Color3.fromRGB(70, 220, 255)
local PINK = Color3.fromRGB(255, 90, 200)
local PURPLE = Color3.fromRGB(190, 110, 255)
local FENCE_RADIUS, FENCE_SEGMENTS = 150, 24 -- must match the Fence in build-decor.luau
local BARRIER_HEIGHT = 80
local CAVE_ANGLES = { 15, 105, 195, 285 } -- between labs, so each cave can be seen from the plaza

local rng = Random.new(7) -- fixed seed, so a rebuild makes the same mountains
local recording = ChangeHistoryService:TryBeginRecording("Build mountains and caves")

local function polar(angleDeg: number, radius: number, y: number): Vector3
	local a = math.rad(angleDeg)
	return Vector3.new(radius * math.sin(a), y, radius * math.cos(a))
end

----- Terrain colours (affects every Rock/Basalt/Slate voxel in the place) -----
terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(96, 88, 122))
terrain:SetMaterialColor(Enum.Material.Basalt, Color3.fromRGB(58, 52, 74))
terrain:SetMaterialColor(Enum.Material.Slate, Color3.fromRGB(78, 72, 100))

----- Mountains: low foothills in front, tall peaks behind, a back ridge to close the view -----
for i = 0, 71 do
	local angle = i * 5 + rng:NextNumber(-2, 2)
	local footRadius = rng:NextNumber(18, 26)
	terrain:FillBall(polar(angle, rng:NextNumber(180, 192), rng:NextNumber(18, 34) - footRadius), footRadius, Enum.Material.Basalt)

	local peakRadius = rng:NextNumber(32, 46)
	local peakHeight = rng:NextNumber(55, 100)
	local peakCentre = polar(angle, rng:NextNumber(212, 240), peakHeight - peakRadius)
	terrain:FillBall(peakCentre, peakRadius, Enum.Material.Rock)
	if peakHeight > 85 then
		-- Icy tips on the tallest peaks
		terrain:FillBall(peakCentre + Vector3.new(0, peakRadius - 6, 0), 9, Enum.Material.Glacier)
	end

	local backRadius = rng:NextNumber(40, 55)
	terrain:FillBall(polar(angle + 2.5, rng:NextNumber(270, 300), rng:NextNumber(70, 130) - backRadius), backRadius, Enum.Material.Slate)

	if i % 4 == 0 then
		task.wait() -- keep Studio responsive
	end
end

----- Caves: solid rock round each mouth, a tunnel going in, crystals glowing inside -----
local caves = Instance.new("Folder")
caves.Name = "Caves"
local crystalColors = { CYAN, PINK, PURPLE }
for caveIndex, angle in CAVE_ANGLES do
	terrain:FillBall(polar(angle, 196, 14), 28, Enum.Material.Basalt)
	for step, radius in { 12, 11, 10, 9 } do
		terrain:FillBall(polar(angle, 172 + step * 8, 8 + step), radius, Enum.Material.Air)
	end
	-- The foothills cover the front of the cave, so open the mouth from closer in too
	terrain:FillBall(polar(angle, 164, 8), 12, Enum.Material.Air)
	terrain:FillBall(polar(angle, 172, 9), 12, Enum.Material.Air)

	local cave = Instance.new("Model")
	cave.Name = `Cave{caveIndex}`
	local inward = CFrame.lookAt(polar(angle, 195, 0), Vector3.new(0, 0, 0)) -- facing the arena
	for c = 1, 7 do
		local height = rng:NextNumber(4, 11)
		local crystal = Instance.new("Part")
		crystal.Name = "Crystal"
		crystal.Anchored = true
		crystal.CanCollide = false
		crystal.CastShadow = false
		crystal.Material = Enum.Material.Neon
		crystal.Color = crystalColors[(c % #crystalColors) + 1]
		crystal.Size = Vector3.new(rng:NextNumber(1.2, 2.2), height, rng:NextNumber(1.2, 2.2))
		local spot = inward * CFrame.new(rng:NextNumber(-7, 7), 0, rng:NextNumber(-6, 4))
		crystal.CFrame = spot
			* CFrame.Angles(math.rad(rng:NextNumber(-25, 25)), math.rad(rng:NextNumber(0, 90)), math.rad(rng:NextNumber(-25, 25)))
			* CFrame.new(0, height / 2 - 0.5, 0)
		crystal.Parent = cave
		if c == 1 then
			local light = Instance.new("PointLight")
			light.Color = PURPLE
			light.Range = 35
			light.Brightness = 3
			light.Parent = crystal
		end
	end
	cave.Parent = caves
end
caves.Parent = decor

----- Barrier: invisible walls along the laser fence, so nobody walks out to the mountains -----
local fence = decor:FindFirstChild("Fence") or decor
for i = 0, FENCE_SEGMENTS - 1 do
	local a = polar(i * 360 / FENCE_SEGMENTS, FENCE_RADIUS, BARRIER_HEIGHT / 2)
	local b = polar((i + 1) * 360 / FENCE_SEGMENTS, FENCE_RADIUS, BARRIER_HEIGHT / 2)
	local wall = Instance.new("Part")
	wall.Name = "Barrier"
	wall.Anchored = true
	wall.Transparency = 1
	wall.CanQuery = false
	wall.CastShadow = false
	wall.Size = Vector3.new(2, BARRIER_HEIGHT, (b - a).Magnitude + 2)
	wall.CFrame = CFrame.lookAt((a + b) / 2, b)
	wall.Parent = fence
end

if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
print("[build-mountains] Done")
