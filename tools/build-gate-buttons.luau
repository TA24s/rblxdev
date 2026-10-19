--!strict
-- build-gate-buttons.luau
-- One-off builder: puts a lock button (a pedestal with a glowing dome) inside every lab, just
-- right of the gate. GateService adds the prompts and colours at runtime. Run once in Edit mode.
-- Stops if any lab already has a GateButton.

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local BUTTON_SPOT = CFrame.new(8.5, 0.5, -16) -- lab-local: on the floor, inside, right of the gate

local labs = workspace:WaitForChild("Map"):WaitForChild("Labs")
for _, lab in labs:GetChildren() do
	if lab:FindFirstChild("GateButton") then
		error(`{lab.Name} already has a GateButton; nothing built`)
	end
end

local recording = ChangeHistoryService:TryBeginRecording("Build gate buttons")
for _, lab in labs:GetChildren() do
	if not lab:IsA("Model") then
		continue
	end
	local spot = lab:GetPivot() * BUTTON_SPOT
	local model = Instance.new("Model")
	model.Name = "GateButton"

	local pedestal = Instance.new("Part")
	pedestal.Name = "Pedestal"
	pedestal.Anchored = true
	pedestal.Size = Vector3.new(1.6, 3, 1.6)
	pedestal.CFrame = spot * CFrame.new(0, 1.5, 0)
	pedestal.Material = Enum.Material.Metal
	pedestal.Color = Color3.fromRGB(45, 48, 60)
	pedestal.TopSurface = Enum.SurfaceType.Smooth
	pedestal.Parent = model

	local button = Instance.new("Part")
	button.Name = "Button"
	button.Anchored = true
	button.Shape = Enum.PartType.Ball
	button.Size = Vector3.new(1.4, 1.4, 1.4)
	button.CFrame = spot * CFrame.new(0, 3.1, 0)
	button.Material = Enum.Material.Neon
	button.Color = Color3.fromRGB(80, 230, 120)
	button.CastShadow = false
	button.Parent = model

	model.PrimaryPart = pedestal
	model.Parent = lab
end
if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
print("[build-gate-buttons] Done")
