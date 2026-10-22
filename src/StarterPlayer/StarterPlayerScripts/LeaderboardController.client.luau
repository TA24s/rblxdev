--!strict
-- LeaderboardController
-- The 🏆 Top button in the left menu and its panel: the top 10 rebirthers across every server,
-- with their avatar, rebirths and Bolts. Your own row is outlined. The list comes from
-- LeaderboardService (ReplicatedStorage.Leaderboard), which refreshes it every minute.
-- Container: StarterPlayer/StarterPlayerScripts

----- Services -----
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

----- Modules -----
local Ui = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ui"))

----- Constants -----
local C = Ui.Colors
local ACCENT = C.Bolt
local MEDALS = { Color3.fromRGB(255, 200, 40), Color3.fromRGB(210, 220, 235), Color3.fromRGB(230, 140, 70) }

----- Variables -----
local player = Players.LocalPlayer
local published = ReplicatedStorage:WaitForChild("Leaderboard") :: StringValue

----- Private Functions -----
local function clearRows(parent: Instance)
	for _, child in parent:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

local function addRow(parent: Instance, rank: number, entry: { [string]: any })
	local isMe = entry.UserId == player.UserId
	local row = Instance.new("Frame")
	row.Name = `Row{rank}`
	row.LayoutOrder = rank
	row.Size = UDim2.new(1, 0, 0, 56)
	row.BackgroundColor3 = if isMe then Color3.fromRGB(60, 50, 120) else C.Row
	row.Parent = parent
	Ui.Corner(row, 12)
	Ui.Border(row, if isMe then C.Cyan else ACCENT, if isMe then 2.5 else 1.5).Transparency = if isMe then 0 else 0.6

	local rankLabel = Ui.Text("Rank", row, `#{rank}`, 24, MEDALS[rank] or C.Text)
	rankLabel.Position = UDim2.fromOffset(8, 0)
	rankLabel.Size = UDim2.new(0, 46, 1, 0)
	Ui.TextOutline(rankLabel)

	local avatar = Instance.new("ImageLabel")
	avatar.Name = "Avatar"
	avatar.AnchorPoint = Vector2.new(0, 0.5)
	avatar.Position = UDim2.new(0, 58, 0.5, 0)
	avatar.Size = UDim2.fromOffset(44, 44)
	avatar.BackgroundColor3 = Color3.fromRGB(70, 60, 130)
	avatar.Image = `rbxthumb://type=AvatarHeadShot&id={entry.UserId}&w=150&h=150`
	avatar.Parent = row
	Ui.Corner(avatar, 22)
	Ui.Border(avatar, MEDALS[rank] or C.Muted, 2)

	local name = Ui.Text("PlayerName", row, if isMe then `{entry.Name} (you)` else entry.Name, 20)
	name.Position = UDim2.fromOffset(112, 0)
	name.Size = UDim2.new(1, -250, 1, 0)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.TextWrapped = false
	Ui.TextOutline(name)

	local rebirths = Ui.Text("Rebirths", row, `♻ {Ui.FormatNumber(entry.Rebirths)}`, 20, C.Purple)
	rebirths.AnchorPoint = Vector2.new(1, 0)
	rebirths.Position = UDim2.new(1, -12, 0, 5)
	rebirths.Size = UDim2.fromOffset(130, 24)
	rebirths.TextXAlignment = Enum.TextXAlignment.Right
	Ui.TextOutline(rebirths)
	local bolts = Ui.Text("Bolts", row, `⚙ {Ui.FormatNumber(entry.Bolts)}`, 15, C.Bolt)
	bolts.AnchorPoint = Vector2.new(1, 0)
	bolts.Position = UDim2.new(1, -12, 0, 30)
	bolts.Size = UDim2.fromOffset(130, 20)
	bolts.TextXAlignment = Enum.TextXAlignment.Right
	Ui.TextOutline(bolts, 1.5)
end

----- Initialization -----
while not player:GetAttribute("DataLoaded") do
	player:GetAttributeChangedSignal("DataLoaded"):Wait()
end

local panel = Ui.NewPanel("Leaderboard", "🏆 Top Rebirthers", ACCENT, Vector2.new(520, 470))
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 8)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = panel.Content

local note = Ui.Text("Note", panel.Content, "All servers · ranked by rebirths, then Bolts · updates every minute", 14, C.Muted)
note.Font = Enum.Font.GothamMedium
note.LayoutOrder = 0
note.Size = UDim2.new(1, 0, 0, 18)
local empty = Ui.Text("Empty", panel.Content, "Nobody's on the board yet. Check back in a minute!", 18, C.Muted)
empty.LayoutOrder = 100
empty.Size = UDim2.new(1, 0, 0, 40)

local rows = Instance.new("Frame")
rows.Name = "Rows"
rows.LayoutOrder = 1
rows.Size = UDim2.fromScale(1, 0)
rows.AutomaticSize = Enum.AutomaticSize.Y
rows.BackgroundTransparency = 1
rows.Parent = panel.Content
local rowsLayout = Instance.new("UIListLayout")
rowsLayout.Padding = UDim.new(0, 8)
rowsLayout.SortOrder = Enum.SortOrder.LayoutOrder
rowsLayout.Parent = rows

local function refresh()
	clearRows(rows)
	local ok, entries = pcall(function()
		return HttpService:JSONDecode(published.Value)
	end)
	if not (ok and typeof(entries) == "table") then
		entries = {}
	end
	for rank, entry in entries do
		addRow(rows, rank, entry)
	end
	empty.Visible = #entries == 0
end

local button = Ui.IconButton("Top", Ui.GetSideBar(), "🏆", "Top", Color3.fromRGB(255, 190, 50), Color3.fromRGB(190, 100, 20), 72)
button.LayoutOrder = 3
button.Activated:Connect(function()
	Ui.Toggle("Leaderboard")
end)
panel.OnOpen = refresh
published.Changed:Connect(function()
	if Ui.IsOpen("Leaderboard") then
		refresh()
	end
end)
