--!strict
-- AreaService
-- Moves players between the plaza and the Rooftop Lab (Config/Rooftop). Stepping on the LiftPad at
-- the foot of the tower takes a player who has rebirthed at least once up to the roof; anyone else
-- is told how to unlock it. The DownPad on the roof brings players back down.
-- Container: ServerScriptService/Services

----- Services -----
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

----- Modules -----
local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Rooftop = require(Config:WaitForChild("Rooftop"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local NotifyService = require(script.Parent:WaitForChild("NotifyService"))
local StealService = require(script.Parent:WaitForChild("StealService"))
local TrackingService = require(script.Parent:WaitForChild("TrackingService"))

----- Constants -----
local PAD_COOLDOWN = 1.5 -- seconds before the same player can use a pad again
local LOCKED_MESSAGE_COOLDOWN = 5 -- so standing on the lift doesn't repeat the message

----- Variables -----
local lastUsed: { [Player]: number } = {}
local lastLockedMessage: { [Player]: number } = {}

local AreaService = {}

----- Private Functions -----
local function moveTo(player: Player, position: Vector3)
	local character = player.Character
	if character then
		character:PivotTo(CFrame.new(position))
	end
end

local function goUp(player: Player)
	local data = DataService.GetData(player)
	if not data or data.Rebirths < Rooftop.MinRebirths then
		local now = os.clock()
		if now - (lastLockedMessage[player] or 0) >= LOCKED_MESSAGE_COOLDOWN then
			lastLockedMessage[player] = now
			NotifyService.Send(player, "🔒 The Rooftop Lab opens after your first rebirth. Rare gadgets only up there!")
		end
		return
	end
	if StealService.IsCarrying(player) then
		NotifyService.Send(player, "Take your stolen gadget home before you ride up!")
		return
	end
	moveTo(player, Rooftop.RoofArrival)
	NotifyService.Send(player, "🌙 Welcome to the Rooftop Lab! Only Rare and rarer gadgets roll up here.", "good")
	TrackingService.Custom(player, "RooftopVisit", data.Rebirths)
end

local function onPadTouched(pad: BasePart, hit: BasePart)
	local character = hit:FindFirstAncestorOfClass("Model")
	local player = character and Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end
	local now = os.clock()
	if now - (lastUsed[player] or 0) < PAD_COOLDOWN then
		return
	end
	lastUsed[player] = now
	if pad:GetAttribute("Destination") == "Roof" then
		goUp(player)
	else
		moveTo(player, Rooftop.GroundArrival)
	end
end

function AreaService.Init()
	local map = workspace:FindFirstChild("Map")
	local lab = map and map:FindFirstChild("RooftopLab")
	if not lab then
		warn("[AreaService] Workspace.Map.RooftopLab is missing, so the lift is off")
		return
	end
	for _, name in { "LiftPad", "DownPad" } do
		local pad = lab:FindFirstChild(name)
		if pad and pad:IsA("BasePart") then
			pad.Touched:Connect(function(hit)
				onPadTouched(pad, hit)
			end)
		else
			warn(`[AreaService] RooftopLab.{name} is missing`)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		lastUsed[player] = nil
		lastLockedMessage[player] = nil
	end)
end

return AreaService
