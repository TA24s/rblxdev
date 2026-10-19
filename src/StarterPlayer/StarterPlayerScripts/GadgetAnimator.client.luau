--!strict
-- GadgetAnimator
-- Plays the little idle animations on every gadget in the world (spinning spoons, popping toast,
-- slapping hands) and on the animated map decorations (DNA towers, atom electrons, Tesla sparks). Runs only on each player's own screen, so the server never spends effort on it.
-- What each part does comes from attributes set on the model (see tools/build-gadget-models.luau),
-- so new gadgets animate without changing this script.
-- Container: StarterPlayer/StarterPlayerScripts

----- Services -----
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

----- Constants -----
local ANIMATED_TAGS = { "Gadget", "AnimatedDecor" }
local AXES: { [string]: Vector3 } = { X = Vector3.xAxis, Y = Vector3.yAxis, Z = Vector3.zAxis }

----- Types -----
type AnimatedPart = {
	part: BasePart,
	offset: CFrame, -- the part's resting position relative to the gadget's Base
	kind: string,
	axis: Vector3,
	speed: number,
	amplitude: number,
	pivot: Vector3, -- Spin/Swing turn around this point (part-local); zero = the part's centre
}

type Entry = {
	base: BasePart,
	parts: { AnimatedPart },
}

----- Variables -----
local entries: { [Model]: Entry } = {}

----- Private Functions -----
local function register(instance: Instance)
	if not instance:IsA("Model") or entries[instance] then
		return
	end
	local base = instance.PrimaryPart
	if not base then
		return
	end
	local parts: { AnimatedPart } = {}
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then
			local kind = descendant:GetAttribute("Anim")
			if typeof(kind) == "string" then
				table.insert(parts, {
					part = descendant,
					offset = base.CFrame:ToObjectSpace(descendant.CFrame),
					kind = kind,
					axis = AXES[descendant:GetAttribute("AnimAxis") :: string? or "Y"] or Vector3.yAxis,
					speed = (descendant:GetAttribute("AnimSpeed") :: number?) or 1,
					amplitude = (descendant:GetAttribute("AnimAmplitude") :: number?) or 0,
					pivot = (descendant:GetAttribute("AnimPivot") :: Vector3?) or Vector3.zero,
				})
			end
		end
	end
	if #parts > 0 then
		entries[instance] = { base = base, parts = parts }
	end
end

local function unregister(instance: Instance)
	if instance:IsA("Model") then
		entries[instance] = nil
	end
end

-- Where a part should be at time t, relative to its resting position
local function animatedOffset(a: AnimatedPart, t: number): CFrame
	if a.kind == "Spin" then
		return CFrame.new(a.pivot) * CFrame.fromAxisAngle(a.axis, math.rad(a.speed * t)) * CFrame.new(-a.pivot)
	elseif a.kind == "Bob" then
		return CFrame.new(0, (math.sin(t * a.speed * 2 * math.pi) + 1) * 0.5 * a.amplitude, 0)
	elseif a.kind == "Swing" then
		local angle = math.rad(a.amplitude) * math.sin(t * a.speed * 2 * math.pi)
		return CFrame.new(a.pivot) * CFrame.fromAxisAngle(a.axis, angle) * CFrame.new(-a.pivot)
	end
	return CFrame.identity
end

local function step()
	local t = os.clock()
	local movedParts: { BasePart } = {}
	local targets: { CFrame } = {}
	for model, entry in entries do
		if not entry.base.Parent or model:GetAttribute("Carried") then
			continue
		end
		local baseCFrame = entry.base.CFrame
		for _, a in entry.parts do
			if a.kind == "Blink" then
				a.part.LocalTransparencyModifier = (math.sin(t * a.speed * 2 * math.pi) + 1) * 0.5
			else
				table.insert(movedParts, a.part)
				table.insert(targets, baseCFrame * a.offset * animatedOffset(a, t))
			end
		end
	end
	if #movedParts > 0 then
		-- One bulk move is much cheaper than setting each part's CFrame separately
		workspace:BulkMoveTo(movedParts, targets, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

----- Initialization -----
for _, tag in ANIMATED_TAGS do
	CollectionService:GetInstanceAddedSignal(tag):Connect(register)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(unregister)
	for _, instance in CollectionService:GetTagged(tag) do
		register(instance)
	end
end

RunService.RenderStepped:Connect(step)
