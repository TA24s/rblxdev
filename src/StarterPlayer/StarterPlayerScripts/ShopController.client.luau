--!strict
-- ShopController
-- The Shop button in the side menu and its panel (Config/Shop, ShopService on the server): one row
-- for the Lab Assistant and one per Lab Theme. Each row shows the Robux price and a Buy button,
-- "Owned" once you have it (themes get an On/Off switch instead), or "Coming soon" while the
-- pass isn't on sale yet (GamePassId 0).
-- Container: StarterPlayer/StarterPlayerScripts

----- Services -----
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

----- Modules -----
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Ui = require(Shared:WaitForChild("Ui"))
local Shop = require(Shared:WaitForChild("Config"):WaitForChild("Shop"))

----- Constants -----
local C = Ui.Colors
local SHOP_ACCENT = Color3.fromRGB(255, 120, 200)

----- Types -----
type Row = { item: Shop.Pass, isTheme: boolean, button: TextButton, price: string? }

----- Variables -----
local player = Players.LocalPlayer
local shopRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ShopRequest") :: RemoteEvent
local rows: { Row } = {}

----- Private Functions -----
local function refresh()
	for _, row in rows do
		local id = row.item.Id
		local ownsIt = player:GetAttribute(`Owns{id}`) == true
		if ownsIt and row.isTheme then
			if player:GetAttribute("Theme") == id then
				row.button.Text = "ON"
				Ui.SetButtonColor(row.button, C.Green, C.GreenDark)
			else
				row.button.Text = "OFF"
				Ui.SetButtonColor(row.button, C.Disabled, Color3.fromRGB(60, 58, 75))
			end
		elseif ownsIt then
			row.button.Text = "Owned ✓"
			Ui.SetButtonColor(row.button, C.Green, C.GreenDark)
		elseif row.item.GamePassId <= 0 then
			row.button.Text = "Coming soon"
			Ui.SetButtonColor(row.button, C.Disabled, Color3.fromRGB(60, 58, 75))
		else
			row.button.Text = if row.price then `R$ {row.price}` else "Buy"
			Ui.SetButtonColor(row.button, C.Purple, C.PurpleDark)
		end
	end
end

-- Looks up the Robux price set on the Creator Hub (only for passes that are on sale)
local function loadPrice(row: Row)
	if row.item.GamePassId <= 0 then
		return
	end
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(row.item.GamePassId, Enum.InfoType.GamePass)
	end)
	if ok and typeof(info) == "table" and typeof(info.PriceInRobux) == "number" then
		row.price = Ui.FormatNumber(info.PriceInRobux)
		refresh()
	end
end

local function onPressed(row: Row)
	local id = row.item.Id
	local ownsIt = player:GetAttribute(`Owns{id}`) == true
	if ownsIt and row.isTheme then
		shopRemote:FireServer({ action = "EquipTheme", id = if player:GetAttribute("Theme") == id then "" else id })
	elseif not ownsIt then
		shopRemote:FireServer({ action = "Buy", id = id })
	end
end

local function addRow(parent: Instance, order: number, item: Shop.Pass, isTheme: boolean)
	local frame = Instance.new("Frame")
	frame.Name = item.Id
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, 0, 0, 88)
	frame.BackgroundColor3 = C.Row
	frame.Parent = parent
	Ui.Corner(frame, 14)
	Ui.Border(frame, SHOP_ACCENT, 1.5).Transparency = 0.55

	local iconBox = Instance.new("Frame")
	iconBox.Name = "IconBox"
	iconBox.AnchorPoint = Vector2.new(0, 0.5)
	iconBox.Position = UDim2.new(0, 10, 0.5, 0)
	iconBox.Size = UDim2.fromOffset(64, 64)
	iconBox.BackgroundColor3 = Color3.new(1, 1, 1)
	iconBox.Parent = frame
	Ui.Corner(iconBox, 12)
	Ui.Gradient(iconBox, Color3.fromRGB(170, 70, 150), Color3.fromRGB(90, 30, 95))
	Ui.Border(iconBox, Color3.new(1, 1, 1), 1.5).Transparency = 0.5
	local iconLabel = Ui.Text("Icon", iconBox, item.Icon, 1)
	iconLabel.Size = UDim2.fromScale(1, 1)
	iconLabel.TextScaled = true
	local iconPadding = Instance.new("UIPadding")
	iconPadding.PaddingTop = UDim.new(0, 10)
	iconPadding.PaddingBottom = UDim.new(0, 10)
	iconPadding.Parent = iconLabel

	local title = Ui.Text("Title", frame, item.DisplayName, 21)
	title.Position = UDim2.fromOffset(86, 10)
	title.Size = UDim2.new(1, -240, 0, 24)
	title.TextXAlignment = Enum.TextXAlignment.Left
	Ui.TextOutline(title)
	local description = Ui.Text("Description", frame, item.Description, 14, C.Muted)
	description.Font = Enum.Font.GothamMedium
	description.Position = UDim2.fromOffset(86, 36)
	description.Size = UDim2.new(1, -240, 0, 40)
	description.TextXAlignment = Enum.TextXAlignment.Left
	description.TextYAlignment = Enum.TextYAlignment.Top
	description.TextWrapped = true

	local button = Ui.TextButton("Buy", frame, "")
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -12, 0.5, 0)
	button.Size = UDim2.fromOffset(140, 46)

	local row: Row = { item = item, isTheme = isTheme, button = button }
	button.Activated:Connect(function()
		onPressed(row)
	end)
	table.insert(rows, row)
	task.spawn(loadPrice, row)
end

local function buildShopPanel()
	local panel = Ui.NewPanel("Shop", "🛒 Shop", SHOP_ACCENT, Vector2.new(560, 360))
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = panel.Content

	addRow(panel.Content, 1, Shop.LabAssistant, false)
	local order = 2
	for _, theme in Shop.Themes do
		addRow(panel.Content, order, (theme :: any) :: Shop.Pass, true)
		order += 1
	end

	local note = Ui.Text("Note", panel.Content, "Themes only change how your lab looks. Switch them on and off any time.", 14, C.Muted)
	note.Font = Enum.Font.GothamMedium
	note.LayoutOrder = 100
	note.Size = UDim2.new(1, 0, 0, 20)

	panel.OnOpen = refresh
end

----- Start -----
buildShopPanel()
local shopButton = Ui.IconButton("Shop", Ui.GetSideBar(), "🛒", "Shop", Color3.fromRGB(255, 120, 200), Color3.fromRGB(170, 40, 120), 72)
shopButton.LayoutOrder = 5
shopButton.Activated:Connect(function()
	Ui.Toggle("Shop")
end)

player.AttributeChanged:Connect(function(name)
	if (name == "Theme" or name:sub(1, 4) == "Owns") and Ui.IsOpen("Shop") then
		refresh()
	end
end)
refresh()
