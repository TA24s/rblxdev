--!strict
-- ShopService
-- The Robux shop (Config/Shop, ShopController on the client). Everything is a one-time game pass:
-- * Lab Assistant: a little robot floats in your lab and collects the Bolts from all your benches
--   every few seconds (BenchService.CollectAll).
-- * Lab Themes: reskin your lab's walls, floor and benches. Owners can switch a theme on or off
--   from the shop; the choice is saved (PlayerData.Theme) and the lab goes back to its own look
--   when they switch it off or leave.
-- Who owns what is checked with MarketplaceService when a player joins and again after a purchase,
-- and shown as player attributes (Owns<Id> true, Theme "<Id>" or "") for the client.
-- A pass whose GamePassId is still 0 can't be bought ("not on sale yet").
-- Container: ServerScriptService/Services

----- Services -----
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

----- Modules -----
local Shop = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Shop"))
local BenchService = require(script.Parent:WaitForChild("BenchService"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local LabService = require(script.Parent:WaitForChild("LabService"))
local NotifyService = require(script.Parent:WaitForChild("NotifyService"))
local TrackingService = require(script.Parent:WaitForChild("TrackingService"))

----- Constants -----
local MIN_SECONDS_BETWEEN = 0.5 -- ignore repeated clicks
local READY_TIMEOUT = 60 -- seconds to wait for a joining player's lab to be set up
local ASSISTANT_HEIGHT = 9 -- studs above the lab floor
local BOB_TWEEN = TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

----- Types -----
type Original = { part: BasePart, color: Color3, material: Enum.Material }

----- Variables -----
local owned: { [Player]: { [string]: boolean } } = {}
local lastRequest: { [Player]: number } = {}
local assistants: { [Player]: BasePart } = {}
local themedLabs: { [Model]: { Original } } = {} -- the lab's own look, to put back
local labOf: { [Player]: Model } = {} -- each player's lab, remembered so it can be reset when they leave

local ShopService = {}

----- Private Functions -----
local function tooSoon(player: Player): boolean
	local now = os.clock()
	if now - (lastRequest[player] or 0) < MIN_SECONDS_BETWEEN then
		return true
	end
	lastRequest[player] = now
	return false
end

-- Every pass and theme by Id
local function findItem(id: string): Shop.Pass?
	if id == Shop.LabAssistant.Id then
		return Shop.LabAssistant
	end
	local theme = Shop.Themes[id]
	return if theme then (theme :: any) :: Shop.Pass else nil
end

local function allItems(): { Shop.Pass }
	local items: { Shop.Pass } = { Shop.LabAssistant }
	for _, theme in Shop.Themes do
		table.insert(items, (theme :: any) :: Shop.Pass)
	end
	return items
end

local function checkOwnership(player: Player, item: Shop.Pass): boolean
	if RunService:IsStudio() and Shop.StudioOwnsAll then
		return true
	end
	if item.GamePassId <= 0 then
		return false
	end
	local ok, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, item.GamePassId)
	end)
	if not ok then
		warn(`[ShopService] Couldn't check {player.Name}'s {item.Id} pass: {result}`)
		return false
	end
	return result == true
end

local function owns(player: Player, id: string): boolean
	local list = owned[player]
	return list ~= nil and list[id] == true
end

-- The parts a theme recolours: all walls, the floor, and every bench except the Vault (Bench1)
local function themeParts(lab: Model): { walls: { BasePart }, floor: { BasePart }, benches: { BasePart } }
	local function partsIn(name: string): { BasePart }
		local found: { BasePart } = {}
		local holder = lab:FindFirstChild(name)
		if holder then
			if holder:IsA("BasePart") then
				table.insert(found, holder)
			end
			for _, descendant in holder:GetDescendants() do
				if descendant:IsA("BasePart") then
					table.insert(found, descendant)
				end
			end
		end
		return found
	end
	local benches: { BasePart } = {}
	local benchFolder = lab:FindFirstChild("Benches")
	if benchFolder then
		for _, bench in benchFolder:GetChildren() do
			if bench:IsA("BasePart") and bench.Name ~= "Bench1" then
				table.insert(benches, bench)
			end
		end
	end
	return { walls = partsIn("Walls"), floor = partsIn("Floor"), benches = benches }
end

local function revertTheme(lab: Model)
	local originals = themedLabs[lab]
	if not originals then
		return
	end
	for _, original in originals do
		original.part.Color = original.color
		original.part.Material = original.material
	end
	themedLabs[lab] = nil
end

local function applyTheme(lab: Model, theme: Shop.Theme)
	revertTheme(lab)
	local originals: { Original } = {}
	local parts = themeParts(lab)
	for _, group in { { parts.walls, theme.Walls }, { parts.floor, theme.Floor }, { parts.benches, theme.Benches } } do
		local list = group[1] :: { BasePart }
		local look = group[2] :: Shop.Look
		for _, part in list do
			table.insert(originals, { part = part, color = part.Color, material = part.Material })
			part.Color = look.Color
			part.Material = look.Material
		end
	end
	themedLabs[lab] = originals
end

-- Shows the player's saved theme on their lab (or their lab's own look if they have none)
local function showTheme(player: Player)
	local lab = LabService.GetLab(player)
	local data = DataService.GetData(player)
	if not (lab and data) then
		return
	end
	labOf[player] = lab
	local theme = Shop.Themes[data.Theme]
	if theme and owns(player, theme.Id) then
		applyTheme(lab, theme)
	else
		revertTheme(lab)
	end
	player:SetAttribute("Theme", if theme and owns(player, theme.Id) then theme.Id else "")
end

----- Lab Assistant -----
local function removeAssistant(player: Player)
	local robot = assistants[player]
	if robot then
		robot:Destroy()
		assistants[player] = nil
	end
end

-- A glowing ball with a robot face that floats over the middle of the lab
local function makeAssistant(player: Player)
	removeAssistant(player)
	local lab = LabService.GetLab(player)
	local floor = lab and lab:FindFirstChild("Floor")
	if not (lab and floor and floor:IsA("BasePart")) then
		return
	end
	local robot = Instance.new("Part")
	robot.Name = "LabAssistant"
	robot.Shape = Enum.PartType.Ball
	robot.Size = Vector3.new(2.5, 2.5, 2.5)
	robot.Anchored = true
	robot.CanCollide = false
	robot.CanQuery = false
	robot.CanTouch = false
	robot.Material = Enum.Material.Neon
	robot.Color = Color3.fromRGB(80, 220, 255)
	robot.Transparency = 0.35
	local home = floor.Position + Vector3.new(0, floor.Size.Y / 2 + ASSISTANT_HEIGHT, 0)
	robot.CFrame = CFrame.new(home)

	local gui = Instance.new("BillboardGui")
	gui.Name = "Face"
	gui.Size = UDim2.fromOffset(150, 80)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 0.6, 0)
	gui.MaxDistance = 90
	gui.Parent = robot
	local face = Instance.new("TextLabel")
	face.Name = "Icon"
	face.BackgroundTransparency = 1
	face.Size = UDim2.fromScale(1, 0.65)
	face.Font = Enum.Font.FredokaOne
	face.TextScaled = true
	face.Text = Shop.LabAssistant.Icon
	face.Parent = gui
	local line = Instance.new("TextLabel")
	line.Name = "Collected"
	line.BackgroundTransparency = 1
	line.Position = UDim2.fromScale(0, 0.65)
	line.Size = UDim2.fromScale(1, 0.35)
	line.Font = Enum.Font.FredokaOne
	line.TextScaled = true
	line.TextColor3 = Color3.fromRGB(255, 200, 40)
	line.TextStrokeTransparency = 0.3
	line.Text = "Lab Assistant"
	line.Parent = gui

	robot.Parent = lab
	TweenService:Create(robot, BOB_TWEEN, { CFrame = CFrame.new(home + Vector3.new(0, 1.2, 0)) }):Play()
	assistants[player] = robot
end

local function runAssistants()
	while true do
		task.wait(Shop.AssistantCollectSeconds)
		for player, robot in assistants do
			if player.Parent and BenchService.IsReady(player) then
				local amount = BenchService.CollectAll(player)
				local face = robot:FindFirstChild("Face")
				local line = face and face:FindFirstChild("Collected")
				if amount > 0 and line and line:IsA("TextLabel") then
					line.Text = `+⚙ {amount}`
				end
			end
		end
	end
end

----- Ownership -----
local function setOwned(player: Player, item: Shop.Pass)
	local list = owned[player]
	if not list then
		return
	end
	list[item.Id] = true
	player:SetAttribute(`Owns{item.Id}`, true)
	if item.Id == Shop.LabAssistant.Id and BenchService.IsReady(player) then
		makeAssistant(player)
	end
end

local function onPlayerAdded(player: Player)
	local list: { [string]: boolean } = {}
	owned[player] = list
	for _, item in allItems() do
		if checkOwnership(player, item) then
			list[item.Id] = true
			player:SetAttribute(`Owns{item.Id}`, true)
		end
	end
	-- The lab and the save need to be ready before the robot or the theme can appear
	local waited = 0
	while player.Parent and not BenchService.IsReady(player) and waited < READY_TIMEOUT do
		waited += task.wait(0.5)
	end
	if not (player.Parent and BenchService.IsReady(player)) then
		return
	end
	if owns(player, Shop.LabAssistant.Id) then
		makeAssistant(player)
	end
	showTheme(player)
end

local function onPlayerRemoving(player: Player)
	removeAssistant(player)
	local lab = labOf[player] or LabService.GetLab(player)
	if lab then
		revertTheme(lab)
	end
	labOf[player] = nil
	owned[player] = nil
	lastRequest[player] = nil
end

----- Requests from the shop panel -----
local function promptPurchase(player: Player, item: Shop.Pass)
	if owns(player, item.Id) then
		NotifyService.Send(player, `You already own {item.DisplayName}!`)
		return
	end
	if item.GamePassId <= 0 then
		NotifyService.Send(player, `{item.Icon} {item.DisplayName} isn't on sale yet. Check back soon!`)
		return
	end
	TrackingService.Custom(player, "ShopPrompt", 1, { item.Id })
	MarketplaceService:PromptGamePassPurchase(player, item.GamePassId)
end

local function equipTheme(player: Player, themeId: string)
	local data = DataService.GetData(player)
	if not data then
		return
	end
	if themeId ~= "" then
		local theme = Shop.Themes[themeId]
		if not (theme and owns(player, themeId)) then
			return
		end
	end
	data.Theme = themeId
	showTheme(player)
	if themeId ~= "" then
		NotifyService.Send(player, `{Shop.Themes[themeId].Icon} {Shop.Themes[themeId].DisplayName} is on!`, "good")
	end
	TrackingService.Custom(player, "ThemeEquipped", 1, { if themeId == "" then "None" else themeId })
end

local function onShopRequest(player: Player, request: unknown)
	if tooSoon(player) or typeof(request) ~= "table" then
		return
	end
	local action = (request :: any).action
	local id = (request :: any).id
	if typeof(id) ~= "string" then
		return
	end
	if action == "Buy" then
		local item = findItem(id)
		if item then
			promptPurchase(player, item)
		end
	elseif action == "EquipTheme" then
		equipTheme(player, id)
	end
end

local function onPurchaseFinished(player: Player, gamePassId: number, purchased: boolean)
	if not purchased or gamePassId <= 0 then
		return
	end
	for _, item in allItems() do
		if item.GamePassId == gamePassId then
			setOwned(player, item)
			NotifyService.Send(player, `{item.Icon} Thanks! {item.DisplayName} is yours.`, "good")
			TrackingService.Custom(player, "PassBought", 1, { item.Id })
			if Shop.Themes[item.Id] then
				equipTheme(player, item.Id)
			end
		end
	end
end

local function getRemote(remotes: Instance, name: string): RemoteEvent
	local remote = remotes:FindFirstChild(name)
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end
	local newRemote = Instance.new("RemoteEvent")
	newRemote.Name = name
	newRemote.Parent = remotes
	return newRemote
end

----- Public Functions -----
function ShopService.Owns(player: Player, id: string): boolean
	return owns(player, id)
end

function ShopService.Init()
	if RunService:IsStudio() and Shop.StudioOwnsAll then
		warn("[ShopService] StudioOwnsAll is on: everyone owns every pass in this Studio test")
	end
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	getRemote(remotes, "ShopRequest").OnServerEvent:Connect(onShopRequest)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(onPurchaseFinished)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	task.spawn(runAssistants)
end

return ShopService
