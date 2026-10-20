--!strict
-- LabPromptController
-- Shows each player only the prompts that make sense for them: in your own lab you see Sell,
-- Unlock and the gate lock prompts but never Steal; in other labs you only see Steal.
-- The server still checks every prompt, so this is only about what's shown on this screen.
-- Container: StarterPlayer/StarterPlayerScripts

----- Services -----
local Players = game:GetService("Players")

----- Constants -----
local OWNER_PROMPTS = { SellPrompt = true, UnlockPrompt = true, LockPrompt = true, UpgradePrompt = true }
local VISITOR_PROMPTS = { StealPrompt = true }
local LAB_WAIT_SECONDS = 30

----- Variables -----
local player = Players.LocalPlayer
local labsFolder = workspace:WaitForChild("Map"):WaitForChild("Labs")

----- Private Functions -----
-- Keeps a prompt hidden on this screen, even when the server turns it on again
local function keepHidden(prompt: ProximityPrompt)
	prompt.Enabled = false
	prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
		if prompt.Enabled then
			prompt.Enabled = false
		end
	end)
end

local function watchLab(lab: Instance, isMine: boolean)
	local hide = if isMine then VISITOR_PROMPTS else OWNER_PROMPTS
	local function check(descendant: Instance)
		if descendant:IsA("ProximityPrompt") and hide[descendant.Name] then
			keepHidden(descendant)
		end
	end
	for _, descendant in lab:GetDescendants() do
		check(descendant)
	end
	lab.DescendantAdded:Connect(check)
end

----- Initialization -----
-- Wait until the server has given us a lab, so we know which one is ours
local deadline = os.clock() + LAB_WAIT_SECONDS
while player:GetAttribute("LabIndex") == nil and os.clock() < deadline do
	task.wait(0.2)
end
local myIndex = player:GetAttribute("LabIndex")
for _, lab in labsFolder:GetChildren() do
	watchLab(lab, myIndex ~= nil and lab:GetAttribute("LabIndex") == myIndex)
end
