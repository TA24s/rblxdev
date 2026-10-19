--!strict
-- build-extra-benches.luau
-- One-off builder: adds Bench5..Bench8 (a second row in front of the first) to every lab,
-- copied from Bench2 so they look the same. They start locked; BenchService shows them as
-- see-through with a price until the owner unlocks them. Run once in Edit mode.
-- Stops if any lab already has a Bench5.

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local ROW_Z = 3 -- lab-local Z: between the back row (z=12) and the spawn point (z=-4)
local XS = { -15, -5, 5, 15 }

local labs = workspace:WaitForChild("Map"):WaitForChild("Labs")
for _, lab in labs:GetChildren() do
	local benches = lab:FindFirstChild("Benches")
	if benches and benches:FindFirstChild("Bench5") then
		error(`{lab.Name} already has Bench5; nothing built`)
	end
end

local recording = ChangeHistoryService:TryBeginRecording("Build extra benches")
for _, lab in labs:GetChildren() do
	local benches = lab:FindFirstChild("Benches")
	local template = benches and benches:FindFirstChild("Bench2")
	if not (lab:IsA("Model") and template and template:IsA("BasePart")) then
		warn(`[build-extra-benches] {lab.Name} has no Benches/Bench2, skipped`)
		continue
	end
	local pivot = lab:GetPivot()
	for i, x in XS do
		local index = 4 + i
		local bench = template:Clone()
		bench.Name = `Bench{index}`
		bench:SetAttribute("BenchIndex", index)
		bench:SetAttribute("IsVault", false)
		bench.CFrame = pivot * CFrame.new(x, 1, ROW_Z)
		bench.Parent = benches
	end
end
if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
print("[build-extra-benches] Done")
