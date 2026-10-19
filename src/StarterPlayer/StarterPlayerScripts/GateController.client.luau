--!strict
-- GateController
-- Makes a locked lab gate solid on this player's screen, unless it's their own lab.
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
local function updateGates()
	local now = workspace:GetServerTimeNow()
	for _, lab in labsFolder:GetChildren() do
		local gate = lab:FindFirstChild("Gate")
		if gate and gate:IsA("BasePart") then
			local lockedUntil = lab:GetAttribute("GateLockedUntil")
			local locked = typeof(lockedUntil) == "number" and now < lockedUntil
			local mine = lab:GetAttribute("OwnerUserId") == player.UserId
			gate.CanCollide = locked and not mine
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
