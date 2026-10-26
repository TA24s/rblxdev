--!strict
-- Mutations
-- Now and then a gadget rolls onto the conveyor mutated: Golden, Electrified or Rubber. It costs
-- the same as a plain one but earns more (and sells for more), and keeps its mutation when it's
-- saved, stolen or sold. Apply() gives a gadget model its mutation's look.
-- Chances are provisional, to balance in playtests.
-- Container: ReplicatedStorage/Shared/Config

export type Mutation = {
	Id: string,
	DisplayName: string,
	Multiplier: number, -- income and sell price multiplier
	Chance: number, -- chance each conveyor gadget has this mutation (0 to 1)
	Color: Color3, -- label colour
	Tint: Color3, -- the colour the model's parts are blended towards
	TintAmount: number, -- 0 = keep the colours, 1 = all one colour
}

local Mutations = {
	List = {
		Rubber = { Id = "Rubber", DisplayName = "Rubber", Multiplier = 1.5, Chance = 0.06, Color = Color3.fromRGB(255, 130, 200), Tint = Color3.fromRGB(255, 140, 210), TintAmount = 0.55 },
		Golden = { Id = "Golden", DisplayName = "Golden", Multiplier = 2, Chance = 0.03, Color = Color3.fromRGB(255, 205, 50), Tint = Color3.fromRGB(255, 210, 40), TintAmount = 0.85 },
		Electrified = { Id = "Electrified", DisplayName = "Electrified", Multiplier = 3, Chance = 0.01, Color = Color3.fromRGB(90, 225, 255), Tint = Color3.fromRGB(110, 220, 255), TintAmount = 0.5 },
	} :: { [string]: Mutation },
	-- Rarest first, so the roll checks Electrified, then Golden, then Rubber
	Order = { "Electrified", "Golden", "Rubber" },
}

-- A random mutation Id, or nil for a plain gadget (most of the time)
function Mutations.Roll(rng: Random): string?
	local roll = rng:NextNumber()
	for _, id in Mutations.Order do
		local mutation = Mutations.List[id]
		if roll < mutation.Chance then
			return id
		end
		roll -= mutation.Chance
	end
	return nil
end

-- 1 for a plain gadget, otherwise the mutation's multiplier (an unknown Id counts as plain)
function Mutations.Multiplier(id: string?): number
	local mutation = id and Mutations.List[id]
	return if mutation then mutation.Multiplier else 1
end

-- "Golden Toaster Cannon", or just the name for a plain gadget
function Mutations.Name(id: string?, gadgetName: string): string
	local mutation = id and Mutations.List[id]
	return if mutation then `{mutation.DisplayName} {gadgetName}` else gadgetName
end

-- Gives a gadget model its mutation's look: tinted parts, plus shine and sparkles (Golden), a glowing
-- outline and sparks (Electrified) or a bounce (Rubber). Does nothing for a plain gadget.
function Mutations.Apply(model: Model, id: string?)
	local mutation = id and Mutations.List[id]
	if not mutation then
		return
	end
	model:SetAttribute("Mutation", mutation.Id)
	local base = model.PrimaryPart
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part ~= base and part.Transparency < 1 then
			part.Color = part.Color:Lerp(mutation.Tint, mutation.TintAmount)
			if mutation.Id == "Golden" and part.Material ~= Enum.Material.Neon and part.Material ~= Enum.Material.Glass then
				part.Material = Enum.Material.SmoothPlastic
				part.Reflectance = 0.3
			elseif mutation.Id == "Rubber" and part:GetAttribute("Anim") == nil then
				-- Parts that don't already move bounce together, so the whole gadget bounces
				part:SetAttribute("Anim", "Bob")
				part:SetAttribute("AnimAmplitude", 0.35)
				part:SetAttribute("AnimSpeed", 1.4)
			end
		end
	end
	if not base then
		return
	end
	local glow = Instance.new("PointLight")
	glow.Name = "MutationGlow"
	glow.Color = mutation.Color
	glow.Range = 8
	glow.Brightness = 1.5
	glow.Parent = base
	if mutation.Id == "Golden" then
		local sparkles = Instance.new("Sparkles")
		sparkles.Name = "MutationSparkles"
		sparkles.SparkleColor = mutation.Color
		sparkles.Parent = base
	elseif mutation.Id == "Electrified" then
		local sparks = Instance.new("ParticleEmitter")
		sparks.Name = "MutationSparks"
		sparks.Rate = 30
		sparks.Lifetime = NumberRange.new(0.15, 0.3)
		sparks.Speed = NumberRange.new(4, 8)
		sparks.SpreadAngle = Vector2.new(70, 70)
		sparks.Size = NumberSequence.new(0.15, 0)
		sparks.Color = ColorSequence.new(mutation.Color)
		sparks.LightEmission = 1
		sparks.EmissionDirection = Enum.NormalId.Top
		sparks.Parent = base
		-- The rarest mutation gets an outline, so it stands out from across the lab
		local outline = Instance.new("Highlight")
		outline.Name = "MutationOutline"
		outline.FillTransparency = 1
		outline.OutlineColor = mutation.Color
		outline.DepthMode = Enum.HighlightDepthMode.Occluded
		outline.Parent = model
	end
end

return Mutations
