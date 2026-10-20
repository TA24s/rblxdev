--!strict
-- LabPromptController
-- Shows each player only the prompts that make sense for them: in your own lab you see Sell,
-- Unlock and the gate lock prompts but never Steal; in other labs you only see Steal.
-- Until the server says which lab is ours, all of these prompts stay hidden.
-- A prompt is hidden by shrinking its reach to 0 on this screen only. The server still turns
-- prompts on and off as usual, and still checks every prompt.
-- Container: StarterPlayer/StarterPlayerScripts

----- Services -----
local Players = game:GetService("Players")

----- Constants -----
local OWNER_PROMPTS: { [string]: boolean } = { SellPrompt = true, UnlockPrompt = true, LockPrompt = true, UpgradePrompt = true }
local VISITOR_PROMPTS: { [string]: boolean } = { StealPrompt = true }

----- Variables -----
local player = Players.LocalPlayer
local labsFolder = workspace:WaitForChild("Map"):WaitForChild("Labs")
local myIndex: any = nil -- our lab's LabIndex, once the server has given us one
local reach: { [ProximityPrompt]: number } = setmetatable({}, { __mode = "k" }) :: any -- each prompt's real reach

----- Private Functions -----
local function shouldShow(lab: Instance, prompt: ProximityPrompt): boolean
	if myIndex == nil then
		return false
	end
	local isMine = lab:GetAttribute("LabIndex") == myIndex
	return if isMine then OWNER_PROMPTS[prompt.Name] == true else VISITOR_PROMPTS[prompt.Name] == true
end

local function apply(lab: Instance, prompt: ProximityPrompt)
	if not (OWNER_PROMPTS[prompt.Name] or VISITOR_PROMPTS[prompt.Name]) then
		return
	end
	if reach[prompt] == nil then
		reach[prompt] = prompt.MaxActivationDistance
	end
	prompt.MaxActivationDistance = if shouldShow(lab, prompt) then reach[prompt] else 0
end

local function applyLab(lab: Instance)
	for _, descendant in lab:GetDescendants() do
		if descendant:IsA("ProximityPrompt") then
			apply(lab, descendant)
		end
	end
end

----- Initialization -----
-- Hide everything first, so nothing wrong shows while we wait for our lab
for _, lab in labsFolder:GetChildren() do
	applyLab(lab)
	lab.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("ProximityPrompt") then
			apply(lab, descendant)
		end
	end)
end

-- Then show the right prompts once the server has given us a lab (and again if it ever changes)
local function onLabIndex()
	myIndex = player:GetAttribute("LabIndex")
	for _, lab in labsFolder:GetChildren() do
		applyLab(lab)
	end
end
player:GetAttributeChangedSignal("LabIndex"):Connect(onLabIndex)
onLabIndex()
