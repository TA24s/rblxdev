--!strict
-- LabService
-- Gives each player their own lab when they join, puts their name on the sign,
-- spawns them inside it, and frees the lab again when they leave.
-- Container: ServerScriptService/Services

----- Services -----
local Players = game:GetService("Players")

----- Constants -----
local EMPTY_SIGN_TEXT = "Empty Lab"
local SPAWN_OFFSET = CFrame.new(0, 4, -4) -- just inside the gate, above the floor

----- Variables -----
local labsFolder = workspace:WaitForChild("Map"):WaitForChild("Labs")
local labByPlayer: { [Player]: Model } = {}

local LabService = {}

----- Private Functions -----
local function setSignText(lab: Model, text: string)
	local sign = lab:FindFirstChild("Sign")
	local gui = sign and sign:FindFirstChild("SignGui")
	local label = gui and gui:FindFirstChild("OwnerName")
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

-- Labs in LabIndex order, so players fill Lab1, Lab2, ... predictably
local function getLabsInOrder(): { Model }
	local labs = {}
	for _, child in labsFolder:GetChildren() do
		if child:IsA("Model") then
			table.insert(labs, child)
		end
	end
	table.sort(labs, function(a, b)
		return (a:GetAttribute("LabIndex") or 0) < (b:GetAttribute("LabIndex") or 0)
	end)
	return labs
end

local function findFreeLab(): Model?
	for _, lab in getLabsInOrder() do
		if lab:GetAttribute("OwnerUserId") == 0 then
			return lab
		end
	end
	return nil
end

local function moveCharacterToLab(character: Model, lab: Model)
	local floor = lab:FindFirstChild("Floor")
	if not (floor and floor:IsA("BasePart")) then
		return
	end
	-- Wait until the character is fully built before moving it
	character:WaitForChild("HumanoidRootPart", 5)
	if character.Parent then
		character:PivotTo(floor.CFrame * SPAWN_OFFSET)
	end
end

local function onPlayerAdded(player: Player)
	local lab = findFreeLab()
	if not lab then
		-- More players than labs: they can still play in the plaza. Server size should match
		-- the lab count (set in Game Settings) so this normally never happens.
		warn(`[LabService] No free lab for {player.Name}`)
		return
	end

	labByPlayer[player] = lab
	lab:SetAttribute("OwnerUserId", player.UserId)
	player:SetAttribute("LabIndex", lab:GetAttribute("LabIndex"))
	setSignText(lab, `{player.DisplayName}'s Lab`)

	player.CharacterAdded:Connect(function(character)
		moveCharacterToLab(character, lab)
	end)
	if player.Character then
		task.spawn(moveCharacterToLab, player.Character, lab)
	end
end

local function onPlayerRemoving(player: Player)
	local lab = labByPlayer[player]
	if not lab then
		return
	end
	labByPlayer[player] = nil
	lab:SetAttribute("OwnerUserId", 0)
	setSignText(lab, EMPTY_SIGN_TEXT)
end

----- Public Functions -----
-- Returns the lab a player owns, or nil if they have none
function LabService.GetLab(player: Player): Model?
	return labByPlayer[player]
end

function LabService.Init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	-- Players who joined before this ran (common in Studio)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return LabService
