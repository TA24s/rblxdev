--!strict
-- KnockbackController
-- When someone hits you with a Boing Glove, the server (GloveService) sends the bounce here,
-- because your own device moves your character. Pops you up and away; no damage.
-- Container: StarterPlayer/StarterPlayerScripts

----- Services -----
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

----- Constants -----
local MAX_SPEED = 120 -- ignore anything faster, just in case
local PUSH_SECONDS = 0.3 -- keep pushing this long, or the character's own movement slows it at once

----- Variables -----
local player = Players.LocalPlayer
local knockbackRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Knockback") :: RemoteEvent

----- Initialization -----
knockbackRemote.OnClientEvent:Connect(function(velocity: any)
	if typeof(velocity) ~= "Vector3" or velocity.Magnitude > MAX_SPEED then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (root and root:IsA("BasePart") and humanoid and humanoid.Health > 0) then
		return
	end
	-- Leave the ground first, or the floor's friction cancels the push straight away
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	task.wait()
	root.AssemblyLinearVelocity = velocity
	-- Hold the sideways speed for a moment; gravity still handles the up-and-down
	local rootPart = root :: BasePart
	local flat = velocity * Vector3.new(1, 0, 1)
	local ends = os.clock() + PUSH_SECONDS
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		if os.clock() >= ends or not rootPart:IsDescendantOf(workspace) then
			connection:Disconnect()
			return
		end
		rootPart.AssemblyLinearVelocity = flat + Vector3.new(0, rootPart.AssemblyLinearVelocity.Y, 0)
	end)
end)
