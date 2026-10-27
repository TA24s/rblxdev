--!strict
-- EventController
-- Shows the timed events (EventService) in the top-right corner: while an event runs, a big card
-- with its name, what it does and a countdown; between events, a small "Next event in 3:12" chip.
-- Reads the EventId, EventEndsAt and NextEventAt attributes on ReplicatedStorage.
-- Container: StarterPlayer/StarterPlayerScripts

----- Services -----
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

----- Modules -----
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Events = require(Shared:WaitForChild("Config"):WaitForChild("Events"))
local Ui = require(Shared:WaitForChild("Ui"))

----- Constants -----
local C = Ui.Colors
local REFRESH_SECONDS = 0.25
local POP_TWEEN = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

----- Variables -----
local player = Players.LocalPlayer

----- Private Functions -----
-- 125 -> "2:05"
local function clock(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

----- Initialization -----
local gui = Instance.new("ScreenGui")
gui.Name = "EventBanner"
gui.ResetOnSpawn = false
gui.DisplayOrder = 3
gui.Parent = player:WaitForChild("PlayerGui")

-- Big card while an event runs
local card = Instance.new("Frame")
card.Name = "Card"
card.AnchorPoint = Vector2.new(1, 0)
card.Position = UDim2.new(1, -12, 0, 60)
card.Size = UDim2.fromOffset(300, 74)
card.BackgroundColor3 = C.Panel
card.Visible = false
card.Parent = gui
Ui.Corner(card, 14)
local cardBorder = Ui.Border(card, C.Cyan, 3)
local scale = Instance.new("UIScale")
scale.Parent = card

local title = Ui.Text("Title", card, "", 22)
title.Position = UDim2.fromOffset(12, 6)
title.Size = UDim2.new(1, -90, 0, 28)
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextWrapped = false
title.TextTruncate = Enum.TextTruncate.AtEnd
Ui.TextOutline(title)
local timer = Ui.Text("Timer", card, "", 22, C.Text)
timer.AnchorPoint = Vector2.new(1, 0)
timer.Position = UDim2.new(1, -12, 0, 6)
timer.Size = UDim2.fromOffset(72, 28)
timer.TextXAlignment = Enum.TextXAlignment.Right
Ui.TextOutline(timer)
local description = Ui.Text("Description", card, "", 15, C.Muted)
description.Font = Enum.Font.GothamMedium
description.Position = UDim2.fromOffset(12, 36)
description.Size = UDim2.new(1, -24, 0, 32)
description.TextXAlignment = Enum.TextXAlignment.Left
description.TextYAlignment = Enum.TextYAlignment.Top

-- Small chip between events
local chip = Instance.new("Frame")
chip.Name = "NextChip"
chip.AnchorPoint = Vector2.new(1, 0)
chip.Position = UDim2.new(1, -12, 0, 60)
chip.Size = UDim2.fromOffset(190, 30)
chip.BackgroundColor3 = C.Panel
chip.BackgroundTransparency = 0.15
chip.Visible = false
chip.Parent = gui
Ui.Corner(chip, 15)
Ui.Border(chip, C.Purple, 2)
local chipText = Ui.Text("Text", chip, "", 16, C.Text)
chipText.Size = UDim2.fromScale(1, 1)
Ui.TextOutline(chipText, 1.5)

local shownId = ""
local function refresh()
	local now = workspace:GetServerTimeNow()
	local id = ReplicatedStorage:GetAttribute("EventId")
	local event = if typeof(id) == "string" then Events.List[id] else nil
	if event then
		if shownId ~= event.Id then
			shownId = event.Id
			title.Text = `{event.Icon} {string.upper(event.DisplayName)}!`
			title.TextColor3 = event.Color
			cardBorder.Color = event.Color
			description.Text = event.Description
			scale.Scale = 0.6
			TweenService:Create(scale, POP_TWEEN, { Scale = 1 }):Play()
		end
		local endsAt = ReplicatedStorage:GetAttribute("EventEndsAt")
		timer.Text = if typeof(endsAt) == "number" then clock(endsAt - now) else ""
		card.Visible = true
		chip.Visible = false
	else
		shownId = ""
		card.Visible = false
		local nextAt = ReplicatedStorage:GetAttribute("NextEventAt")
		chip.Visible = typeof(nextAt) == "number" and nextAt > now
		if chip.Visible then
			chipText.Text = `⏰ Next event in {clock((nextAt :: number) - now)}`
		end
	end
end

while true do
	refresh()
	task.wait(REFRESH_SECONDS)
end
