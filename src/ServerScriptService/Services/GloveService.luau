--!strict
-- GloveService
-- Gives everyone a Boing Glove: a boxing glove on a spring. Click to swing; the nearest player in
-- front of you (within 7 studs) is bounced away, with no damage. If you hit someone who is
-- carrying one of YOUR gadgets, it snaps straight back to your bench. You can't swing while
-- carrying a stolen gadget. The knockback is applied by KnockbackController on the hit player's
-- own device, because each player's device controls their character's movement.
-- Container: ServerScriptService/Services

----- Services -----
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

----- Modules -----
local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Stealing = require(Config:WaitForChild("Stealing"))
local StealService = require(script.Parent:WaitForChild("StealService"))

----- Constants -----
local TOOL_NAME = "BoingGlove"
local GLOVE_COLOR = Color3.fromRGB(230, 50, 60)
local SPRING_COLOR = Color3.fromRGB(255, 220, 60)
local FACING_DOT = 0.3 -- how directly in front the target must be (1 = straight ahead)

----- Variables -----
local knockbackRemote: RemoteEvent
local lastSwing: { [Player]: number } = {}
local gloveTemplate: Tool

local GloveService = {}

----- Private Functions -----
local function buildGlove(): Tool
	local tool = Instance.new("Tool")
	tool.Name = TOOL_NAME
	tool.ToolTip = "Boing! Bounce thieves away"
	tool.CanBeDropped = false
	tool.Grip = CFrame.new(0, 0, -1.6) -- the glove sits out in front of the hand, on its spring

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Shape = Enum.PartType.Ball
	handle.Size = Vector3.new(1.6, 1.6, 1.6)
	handle.Color = GLOVE_COLOR
	handle.Material = Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local spring = Instance.new("Part")
	spring.Name = "Spring"
	spring.Shape = Enum.PartType.Cylinder
	spring.Size = Vector3.new(1.4, 0.35, 0.35) -- a cylinder's length is along X
	spring.Color = SPRING_COLOR
	spring.Material = Enum.Material.Neon
	spring.CanCollide = false
	spring.Massless = true
	-- from the back of the glove towards the hand (+Z in the handle's space)
	spring.CFrame = handle.CFrame * CFrame.new(0, 0, 1.4) * CFrame.Angles(0, math.rad(90), 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = spring
	weld.Parent = spring
	spring.Parent = tool
	return tool
end

-- The nearest other living player in front of `player` within reach
local function findTarget(player: Player, root: BasePart): (Player?, BasePart?)
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 0.01 then
		return nil, nil
	end
	look = look.Unit
	local best: Player? = nil
	local bestRoot: BasePart? = nil
	local bestDistance = Stealing.GloveRange
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local otherRoot = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if other ~= player and otherRoot and otherRoot:IsA("BasePart") and humanoid and humanoid.Health > 0 then
			local offset = (otherRoot.Position - root.Position) * Vector3.new(1, 0, 1)
			local distance = offset.Magnitude
			if distance <= bestDistance and distance > 0.01 and offset.Unit:Dot(look) >= FACING_DOT then
				best, bestRoot, bestDistance = other, otherRoot, distance
			end
		end
	end
	return best, bestRoot
end

local function onSwing(player: Player, tool: Tool)
	local now = os.clock()
	if now - (lastSwing[player] or 0) < Stealing.GloveCooldownSeconds then
		return
	end
	lastSwing[player] = now
	if StealService.IsCarrying(player) then
		return -- the glove is unequipped when a carry starts; this covers re-equipping
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 and tool.Parent == character) then
		return
	end

	-- The default character Animate script plays a swing when it finds this value in the tool
	local swing = Instance.new("StringValue")
	swing.Name = "toolanim"
	swing.Value = "Slash"
	swing.Parent = tool

	local target, targetRoot = findTarget(player, root)
	if not (target and targetRoot) then
		return
	end
	local away = ((targetRoot.Position - root.Position) * Vector3.new(1, 0, 1)).Unit
	knockbackRemote:FireClient(target, away * Stealing.KnockbackSpeed + Vector3.new(0, Stealing.KnockbackUpSpeed, 0))
	StealService.KnockLoose(target, player)
end

local function giveGlove(player: Player)
	local backpack = player:WaitForChild("Backpack", 10)
	if not backpack or backpack:FindFirstChild(TOOL_NAME) then
		return
	end
	local tool = gloveTemplate:Clone()
	tool.Activated:Connect(function()
		onSwing(player, tool)
	end)
	tool.Parent = backpack
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function()
		giveGlove(player)
	end)
	if player.Character then
		task.spawn(giveGlove, player)
	end
end

----- Public Functions -----
function GloveService.Init()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local remote = remotes:FindFirstChild("Knockback")
	if not (remote and remote:IsA("RemoteEvent")) then
		local newRemote = Instance.new("RemoteEvent")
		newRemote.Name = "Knockback"
		newRemote.Parent = remotes
		remote = newRemote
	end
	knockbackRemote = remote :: RemoteEvent
	gloveTemplate = buildGlove()

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		lastSwing[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return GloveService
