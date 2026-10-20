--!strict
-- GateController
-- Makes a locked lab gate solid on this player's screen, unless it's their own lab, or they are
-- already inside it (so someone caught inside by a lock can always walk out).
-- The server (GateService) sets GateLockedUntil on the lab; collisions with your own character
-- are worked out on your own device, so the gate is solid only where it needs to be.
-- Container: StarterPlayer/StarterPlayerScripts

----- Services -----
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

----- Constants -----
local CHECK_INTERVAL = 0.1 -- seconds

----- Variables -----
local player = Players.LocalPlayer
local labsFolder = workspace:WaitForChild("Map"):WaitForChild("Labs")
local sinceCheck = 0

----- Private Functions -----
-- True if this player's character is standing on the lab's floor, behind the gate
local function isInside(lab: Instance, gate: BasePart): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local floor = lab:FindFirstChild("Floor")
	if not (root and root:IsA("BasePart") and floor and floor:IsA("BasePart")) then
		return false
	end
	local spot = floor.CFrame:PointToObjectSpace(root.Position)
	local gateZ = floor.CFrame:PointToObjectSpace(gate.Position).Z
	local halfX, halfZ = floor.Size.X / 2, floor.Size.Z / 2
	-- the gate is on the floor's -Z edge; inside means past the gate's inner face
	return math.abs(spot.X) < halfX and spot.Z > gateZ + gate.Size.Z / 2 and spot.Z < halfZ and spot.Y < 30
end

local function updateGates()
	local now = workspace:GetServerTimeNow()
	for _, lab in labsFolder:GetChildren() do
		local gate = lab:FindFirstChild("Gate")
		if gate and gate:IsA("BasePart") then
			local lockedUntil = lab:GetAttribute("GateLockedUntil")
			local locked = typeof(lockedUntil) == "number" and now < lockedUntil
			local mine = lab:GetAttribute("OwnerUserId") == player.UserId
			gate.CanCollide = locked and not mine and not isInside(lab, gate)
		end
	end
end

----- Initialization -----
RunService.Heartbeat:Connect(function(deltaTime)
	sinceCheck += deltaTime
	if sinceCheck >= CHECK_INTERVAL then
		sinceCheck = 0
		updateGates()
	end
end)
