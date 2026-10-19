--!strict
-- NotificationController
-- Shows short messages from the server (NotifyService) near the bottom of the screen,
-- then fades them out. A new message replaces the old one.
-- Container: StarterPlayer/StarterPlayerScripts

----- Services -----
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

----- Constants -----
local SHOW_SECONDS = 2.5
local FADE = TweenInfo.new(0.4)

----- Variables -----
local player = Players.LocalPlayer
local notifyRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent
local showCount = 0 -- so an old message's fade doesn't hide a newer one

----- Private Functions -----
local function buildGui(): TextLabel
	local gui = Instance.new("ScreenGui")
	gui.Name = "Notifications"
	gui.ResetOnSpawn = false

	local label = Instance.new("TextLabel")
	label.Name = "Message"
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 1, -110)
	label.Size = UDim2.fromOffset(520, 44)
	label.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextTransparency = 1
	label.Text = ""
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = label

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = label

	gui.Parent = player:WaitForChild("PlayerGui")
	return label
end

----- Initialization -----
local label = buildGui()

notifyRemote.OnClientEvent:Connect(function(text: string)
	showCount += 1
	local myCount = showCount
	label.Text = text
	label.TextTransparency = 0
	label.BackgroundTransparency = 0.2
	task.delay(SHOW_SECONDS, function()
		if showCount == myCount then
			TweenService:Create(label, FADE, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		end
	end)
end)
