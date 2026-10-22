--!strict
-- GloveSlotController
-- Replaces Roblox's default tool bar (which only showed the words "BoingGlove") with a custom
-- glove button at the bottom of the screen: a spinning 3D Boing Glove, a "1" key badge, a glow
-- while it's held, a punch and a cooldown sweep when you swing, and a "no entry" look while
-- you're carrying a stolen gadget. Press 1, tap or click the button to hold or put away the glove.
-- GloveService (server) still gives the glove and decides every hit.
-- Container: StarterPlayer/StarterPlayerScripts

----- Services -----
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

----- Modules -----
local Stealing = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Stealing"))

----- Constants -----
local TOOL_NAME = "BoingGlove"
local CARRY_NAME = "CarriedGadget" -- the stolen gadget StealService puts over a thief's head
local SLOT_SIZE = 84
local PANEL_COLOR = Color3.fromRGB(35, 25, 60)
local PINK = Color3.fromRGB(255, 90, 200)
local YELLOW = Color3.fromRGB(255, 200, 40)
local IDLE_STROKE = Color3.fromRGB(120, 100, 170)
local IDLE_SPIN = 40 -- degrees per second
local HELD_SPIN = 120
local BOUNCE = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, true)

----- Variables -----
local player = Players.LocalPlayer
local held = false
local blocked = false
local punchUntil = 0
local spinAngle = 0

----- Private Functions -----
-- Turns off Roblox's tool bar. It can fail for a moment while the core scripts load, so retry.
local function hideDefaultToolbar()
	for _ = 1, 20 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		end)
		if ok then
			return
		end
		task.wait(0.5)
	end
	warn("[GloveSlotController] Couldn't hide the default tool bar")
end

local function findGlove(): Tool?
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	local tool = (character and character:FindFirstChild(TOOL_NAME)) or (backpack and backpack:FindFirstChild(TOOL_NAME))
	return if tool and tool:IsA("Tool") then tool else nil
end

local function humanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

----- UI -----
local gui = Instance.new("ScreenGui")
gui.Name = "GloveSlot"
gui.ResetOnSpawn = false

local slot = Instance.new("TextButton")
slot.Name = "Slot"
slot.Text = ""
slot.AutoButtonColor = false
slot.AnchorPoint = Vector2.new(0.5, 1)
slot.Position = UDim2.new(0.5, 0, 1, -18)
slot.Size = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE)
slot.BackgroundColor3 = PANEL_COLOR
slot.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 18)
corner.Parent = slot
local stroke = Instance.new("UIStroke")
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Thickness = 3
stroke.Color = IDLE_STROKE
stroke.Parent = slot
local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new(Color3.fromRGB(90, 60, 150), Color3.fromRGB(25, 15, 45))
gradient.Rotation = 90
gradient.Parent = slot
local scale = Instance.new("UIScale")
scale.Parent = slot

-- The 3D glove
local viewport = Instance.new("ViewportFrame")
viewport.Name = "Glove"
viewport.BackgroundTransparency = 1
viewport.Size = UDim2.fromScale(1, 1)
viewport.Ambient = Color3.fromRGB(200, 190, 220)
viewport.LightColor = Color3.new(1, 1, 1)
viewport.LightDirection = Vector3.new(-1, -1, -1)
viewport.Parent = slot
local camera = Instance.new("Camera")
camera.FieldOfView = 40
camera.Parent = viewport
viewport.CurrentCamera = camera
local gloveModel = Instance.new("Model")
gloveModel.Parent = viewport

-- Cooldown sweep: a dark curtain that slides away after each swing
local cooldown = Instance.new("Frame")
cooldown.Name = "Cooldown"
cooldown.AnchorPoint = Vector2.new(0, 1)
cooldown.Position = UDim2.fromScale(0, 1)
cooldown.Size = UDim2.fromScale(1, 0)
cooldown.BackgroundColor3 = Color3.new(0, 0, 0)
cooldown.BackgroundTransparency = 0.45
cooldown.ZIndex = 3
cooldown.Parent = slot
local cooldownCorner = corner:Clone()
cooldownCorner.Parent = cooldown

-- "1" key badge
local badge = Instance.new("TextLabel")
badge.Name = "Key"
badge.Position = UDim2.fromOffset(-6, -6)
badge.Size = UDim2.fromOffset(26, 26)
badge.BackgroundColor3 = YELLOW
badge.Font = Enum.Font.FredokaOne
badge.TextSize = 18
badge.TextColor3 = PANEL_COLOR
badge.Text = "1"
badge.ZIndex = 4
badge.Parent = slot
local badgeCorner = Instance.new("UICorner")
badgeCorner.CornerRadius = UDim.new(1, 0)
badgeCorner.Parent = badge

-- Name tag under the button
local nameTag = Instance.new("TextLabel")
nameTag.Name = "NameTag"
nameTag.AnchorPoint = Vector2.new(0.5, 0)
nameTag.Position = UDim2.new(0.5, 0, 1, -14)
nameTag.Size = UDim2.fromOffset(SLOT_SIZE + 10, 20)
nameTag.BackgroundColor3 = PINK
nameTag.Font = Enum.Font.FredokaOne
nameTag.TextSize = 15
nameTag.TextColor3 = Color3.new(1, 1, 1)
nameTag.Text = "BOING!"
nameTag.ZIndex = 4
nameTag.Parent = slot
local tagCorner = Instance.new("UICorner")
tagCorner.CornerRadius = UDim.new(0, 8)
tagCorner.Parent = nameTag
local tagStroke = Instance.new("UIStroke")
tagStroke.Color = PANEL_COLOR
tagStroke.Thickness = 2
tagStroke.Parent = nameTag

-- "No entry" sign shown while carrying a stolen gadget
local blockedIcon = Instance.new("TextLabel")
blockedIcon.Name = "Blocked"
blockedIcon.Size = UDim2.fromScale(1, 1)
blockedIcon.BackgroundTransparency = 1
blockedIcon.Font = Enum.Font.FredokaOne
blockedIcon.TextScaled = true
blockedIcon.Text = "🚫"
blockedIcon.TextTransparency = 0.15
blockedIcon.ZIndex = 5
blockedIcon.Visible = false
blockedIcon.Parent = slot

gui.Parent = player:WaitForChild("PlayerGui")

----- Glove model and state -----
-- Copies the glove's parts into the button, so it always matches the real glove
local function loadGloveModel(tool: Tool)
	gloveModel:ClearAllChildren()
	local handle = tool:FindFirstChild("Handle")
	if not (handle and handle:IsA("BasePart")) then
		return
	end
	for _, child in tool:GetChildren() do
		if child:IsA("BasePart") then
			local copy = child:Clone()
			for _, extra in copy:GetChildren() do
				extra:Destroy() -- welds, sounds and the like aren't needed in a picture
			end
			copy.Anchored = true
			copy.CFrame = handle.CFrame:ToObjectSpace(child.CFrame) -- the handle sits at the origin
			copy.Parent = gloveModel
			if child == handle then
				gloveModel.PrimaryPart = copy
			end
		end
	end
	camera.CFrame = CFrame.lookAt(Vector3.new(3.4, 1.4, 3.4), Vector3.new(0, 0, 0.5))
end

local function refresh()
	local tool = findGlove()
	held = tool ~= nil and player.Character ~= nil and tool.Parent == player.Character
	local character = player.Character
	blocked = character ~= nil and character:FindFirstChild(CARRY_NAME) ~= nil
	stroke.Color = if blocked then IDLE_STROKE elseif held then YELLOW else IDLE_STROKE
	stroke.Thickness = if held then 4 else 3
	blockedIcon.Visible = blocked
	viewport.ImageTransparency = if blocked then 0.6 else 0
	slot.Visible = tool ~= nil
end

local function toggle()
	local h = humanoid()
	local tool = findGlove()
	if not (h and tool) or blocked then
		return
	end
	if tool.Parent == player.Character then
		h:UnequipTools()
	else
		h:EquipTool(tool)
	end
	scale.Scale = 1
	TweenService:Create(scale, BOUNCE, { Scale = 1.1 }):Play()
end

local function onSwing()
	if os.clock() < punchUntil then
		return
	end
	punchUntil = os.clock() + Stealing.GloveCooldownSeconds
	cooldown.Size = UDim2.fromScale(1, 1)
	TweenService:Create(cooldown, TweenInfo.new(Stealing.GloveCooldownSeconds, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 0) }):Play()
	scale.Scale = 1
	TweenService:Create(scale, BOUNCE, { Scale = 1.15 }):Play()
end

local watchedTools: { [Tool]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local function watchTool(tool: Instance)
	if not (tool:IsA("Tool") and tool.Name == TOOL_NAME) then
		return
	end
	if not watchedTools[tool] then
		watchedTools[tool] = true
		tool.Activated:Connect(onSwing)
		loadGloveModel(tool)
	end
	refresh()
end

local function watchCharacter(character: Model)
	for _, child in character:GetChildren() do
		watchTool(child)
	end
	character.ChildAdded:Connect(function(child)
		watchTool(child)
		refresh()
	end)
	character.ChildRemoved:Connect(refresh)
	refresh()
end

local function watchBackpack(backpack: Instance)
	for _, child in backpack:GetChildren() do
		watchTool(child)
	end
	backpack.ChildAdded:Connect(watchTool)
	backpack.ChildRemoved:Connect(refresh)
end

----- Initialization -----
task.spawn(hideDefaultToolbar)
slot.Visible = false
slot.Activated:Connect(toggle)
ContextActionService:BindAction("ToggleBoingGlove", function(_, state)
	if state == Enum.UserInputState.Begin then
		toggle()
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.One, Enum.KeyCode.ButtonL1)

player.CharacterAdded:Connect(watchCharacter)
if player.Character then
	watchCharacter(player.Character)
end
-- A new Backpack comes with each character
player.ChildAdded:Connect(function(child)
	if child:IsA("Backpack") then
		watchBackpack(child)
	end
end)
local backpack = player:FindFirstChildOfClass("Backpack")
if backpack then
	watchBackpack(backpack)
end

-- Spin the glove (faster while held) and punch it forward on a swing
RunService.RenderStepped:Connect(function(deltaTime)
	local root = gloveModel.PrimaryPart
	if not root or not slot.Visible then
		return
	end
	spinAngle += (if held then HELD_SPIN else IDLE_SPIN) * deltaTime
	local punch = math.max(0, punchUntil - os.clock() - (Stealing.GloveCooldownSeconds - 0.25)) / 0.25 -- 1 to 0 over the first 0.25s
	local bob = math.sin(os.clock() * 3) * 0.12
	gloveModel:PivotTo(CFrame.new(0, bob, -punch * 1.6) * CFrame.Angles(0, math.rad(spinAngle), 0))
end)
