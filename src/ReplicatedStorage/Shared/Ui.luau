--!strict
-- Ui
-- Shared look for the menus (client only): colours, the big square icon buttons, and the panels
-- (dark glass box, neon border, title tab and red close button). Only one panel is open at a time.
-- Used by MenuController and RebirthController.
-- Container: ReplicatedStorage/Shared

----- Services -----
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

----- Constants -----
local OPEN_TWEEN = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local HOVER_TWEEN = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

----- Types -----
export type Panel = {
	Frame: Frame,
	Content: ScrollingFrame,
	OnOpen: (() -> ())?,
	OnClose: (() -> ())?,
}

----- Variables -----
local Ui = {}
local panels: { [string]: Panel } = {}
local openName: string? = nil
local layer: ScreenGui? = nil
local bottomBar: Frame? = nil
local sideBar: Frame? = nil

Ui.Colors = {
	Panel = Color3.fromRGB(24, 20, 52),
	PanelDark = Color3.fromRGB(12, 10, 28),
	Row = Color3.fromRGB(36, 30, 76),
	Text = Color3.new(1, 1, 1),
	Muted = Color3.fromRGB(190, 180, 225),
	Outline = Color3.fromRGB(20, 12, 40),
	Bolt = Color3.fromRGB(255, 200, 40),
	Cyan = Color3.fromRGB(80, 220, 255),
	Green = Color3.fromRGB(70, 230, 110),
	GreenDark = Color3.fromRGB(25, 150, 70),
	Purple = Color3.fromRGB(190, 110, 255),
	PurpleDark = Color3.fromRGB(100, 45, 200),
	Red = Color3.fromRGB(255, 70, 90),
	Disabled = Color3.fromRGB(95, 92, 115),
}

----- Private Functions -----
local function getPlayerGui(): PlayerGui
	return Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
end

local function newGui(name: string, displayOrder: number): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = displayOrder
	gui.Parent = getPlayerGui()
	return gui
end

----- Public Functions -----
function Ui.Corner(instance: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

-- A border round a box (Border mode, so on a button it outlines the box, not the text)
function Ui.Border(instance: GuiObject, color: Color3, thickness: number): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = instance
	return stroke
end

-- A dark outline round text, so it reads on any background
function Ui.TextOutline(label: TextLabel | TextButton, thickness: number?)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Ui.Colors.Outline
	stroke.Thickness = thickness or 2
	stroke.Parent = label
end

function Ui.Gradient(instance: GuiObject, top: Color3, bottom: Color3)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(top, bottom)
	gradient.Rotation = 90
	gradient.Parent = instance
end

function Ui.Text(name: string, parent: Instance, text: string, size: number, color: Color3?): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextSize = size
	label.TextColor3 = color or Ui.Colors.Text
	label.TextWrapped = true
	label.Parent = parent
	return label
end

-- Grows a little under the mouse and squashes when pressed
function Ui.Bouncy(button: GuiButton)
	local scale = Instance.new("UIScale")
	scale.Parent = button
	local function to(value: number)
		TweenService:Create(scale, HOVER_TWEEN, { Scale = value }):Play()
	end
	button.MouseEnter:Connect(function()
		to(1.07)
	end)
	button.MouseLeave:Connect(function()
		to(1)
	end)
	button.MouseButton1Down:Connect(function()
		to(0.93)
	end)
	button.MouseButton1Up:Connect(function()
		to(1.07)
	end)
end

-- A square button with a big icon on top and a word underneath, like the side menu and the
-- Upgrade and Rebirth buttons. Returns the button and its word label (to change the text later).
function Ui.IconButton(name: string, parent: Instance, icon: string, word: string, top: Color3, bottom: Color3, size: number): (TextButton, TextLabel)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.fromOffset(size, size)
	button.BackgroundColor3 = Color3.new(1, 1, 1)
	button.AutoButtonColor = false
	button.Text = ""
	button.Parent = parent
	Ui.Corner(button, 14)
	Ui.Gradient(button, top, bottom)
	Ui.Border(button, Color3.fromRGB(255, 255, 255), 2).Transparency = 0.35
	Ui.Bouncy(button)

	local iconLabel = Ui.Text("Icon", button, icon, 1)
	iconLabel.Position = UDim2.fromScale(0, 0.06)
	iconLabel.Size = UDim2.fromScale(1, 0.56)
	iconLabel.TextScaled = true
	Ui.TextOutline(iconLabel)
	local wordLabel = Ui.Text("Word", button, word, 1)
	wordLabel.AnchorPoint = Vector2.new(0.5, 1)
	wordLabel.Position = UDim2.new(0.5, 0, 1, -5)
	wordLabel.Size = UDim2.new(1, -6, 0.27, 0)
	wordLabel.TextScaled = true
	Ui.TextOutline(wordLabel)
	return button, wordLabel
end

-- A wide button with text (e.g. a price). Colour it with Ui.SetButtonColor.
function Ui.TextButton(name: string, parent: Instance, text: string): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.BackgroundColor3 = Color3.new(1, 1, 1)
	button.AutoButtonColor = false
	button.Font = Enum.Font.FredokaOne
	button.TextScaled = true
	button.TextColor3 = Ui.Colors.Text
	button.Text = text
	button.Parent = parent
	Ui.Corner(button, 10)
	Ui.Gradient(button, Ui.Colors.Green, Ui.Colors.GreenDark)
	Ui.Border(button, Color3.new(1, 1, 1), 2).Transparency = 0.4
	Ui.TextOutline(button)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 7)
	padding.PaddingBottom = UDim.new(0, 7)
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = button
	Ui.Bouncy(button)
	return button
end

function Ui.SetButtonColor(button: GuiObject, top: Color3, bottom: Color3)
	local gradient = button:FindFirstChildOfClass("UIGradient")
	if gradient then
		gradient.Color = ColorSequence.new(top, bottom)
	end
end

-- The full-screen layer the panels live in
function Ui.GetLayer(): ScreenGui
	if not layer then
		layer = newGui("Menus", 5)
	end
	return layer :: ScreenGui
end

-- The row to the right of the Boing Glove button (Upgrade, Rebirth). Order with LayoutOrder.
function Ui.GetBottomBar(): Frame
	if not bottomBar then
		local gui = newGui("ActionBar", 1)
		local bar = Instance.new("Frame")
		bar.Name = "Bar"
		bar.AnchorPoint = Vector2.new(0, 1)
		bar.Position = UDim2.new(0.5, 54, 1, -24) -- the glove button is 84 wide in the middle
		bar.Size = UDim2.fromOffset(0, 76)
		bar.AutomaticSize = Enum.AutomaticSize.X
		bar.BackgroundTransparency = 1
		bar.Parent = gui
		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Horizontal
		list.Padding = UDim.new(0, 10)
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = bar
		bottomBar = bar
	end
	return bottomBar :: Frame
end

-- The column of menu buttons on the left of the screen. Order with LayoutOrder.
function Ui.GetSideBar(): Frame
	if not sideBar then
		local gui = newGui("SideMenu", 1)
		local bar = Instance.new("Frame")
		bar.Name = "Bar"
		bar.AnchorPoint = Vector2.new(0, 0.5)
		bar.Position = UDim2.new(0, 12, 0.5, 0)
		bar.Size = UDim2.fromOffset(72, 0)
		bar.AutomaticSize = Enum.AutomaticSize.Y
		bar.BackgroundTransparency = 1
		bar.Parent = gui
		local list = Instance.new("UIListLayout")
		list.Padding = UDim.new(0, 10)
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = bar
		sideBar = bar
	end
	return sideBar :: Frame
end

-- Makes a panel (hidden at first). Put things in panel.Content, which scrolls if it overflows.
function Ui.NewPanel(name: string, title: string, accent: Color3, maxSize: Vector2): Panel
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.new(0.5, 0, 0.5, 14)
	frame.Size = UDim2.fromScale(0.9, 0.78)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.Visible = false
	frame.Parent = Ui.GetLayer()
	Ui.Corner(frame, 18)
	Ui.Gradient(frame, Ui.Colors.Panel, Ui.Colors.PanelDark)
	Ui.Border(frame, accent, 3)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = maxSize
	limit.Parent = frame
	local scale = Instance.new("UIScale")
	scale.Parent = frame

	-- Title tab sticking out of the top-left corner
	local tab = Instance.new("Frame")
	tab.Name = "TitleTab"
	tab.Position = UDim2.fromOffset(18, -20)
	tab.Size = UDim2.fromOffset(0, 40)
	tab.AutomaticSize = Enum.AutomaticSize.X
	tab.BackgroundColor3 = Color3.new(1, 1, 1)
	tab.ZIndex = 3
	tab.Parent = frame
	Ui.Corner(tab, 10)
	Ui.Gradient(tab, accent, accent:Lerp(Color3.new(0, 0, 0), 0.45))
	Ui.Border(tab, Color3.new(1, 1, 1), 2).Transparency = 0.3
	local tabPadding = Instance.new("UIPadding")
	tabPadding.PaddingLeft = UDim.new(0, 16)
	tabPadding.PaddingRight = UDim.new(0, 16)
	tabPadding.Parent = tab
	local titleLabel = Ui.Text("Title", tab, title, 26)
	titleLabel.Size = UDim2.fromScale(0, 1)
	titleLabel.AutomaticSize = Enum.AutomaticSize.X
	titleLabel.TextWrapped = false
	titleLabel.ZIndex = 3
	Ui.TextOutline(titleLabel)

	-- Red close button in the top-right corner
	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, 10, 0, -14)
	close.Size = UDim2.fromOffset(42, 42)
	close.BackgroundColor3 = Color3.new(1, 1, 1)
	close.AutoButtonColor = false
	close.Font = Enum.Font.FredokaOne
	close.Text = "X"
	close.TextSize = 24
	close.TextColor3 = Ui.Colors.Text
	close.ZIndex = 3
	close.Parent = frame
	Ui.Corner(close, 10)
	Ui.Gradient(close, Color3.fromRGB(255, 100, 110), Color3.fromRGB(200, 30, 60))
	Ui.Border(close, Color3.new(1, 1, 1), 2)
	Ui.TextOutline(close)
	Ui.Bouncy(close)

	local content = Instance.new("ScrollingFrame")
	content.Name = "Content"
	content.Position = UDim2.fromOffset(14, 32)
	content.Size = UDim2.new(1, -28, 1, -46)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.ScrollBarThickness = 6
	content.ScrollBarImageColor3 = accent
	content.CanvasSize = UDim2.new()
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.ScrollingDirection = Enum.ScrollingDirection.Y
	content.Parent = frame
	local contentPadding = Instance.new("UIPadding")
	contentPadding.PaddingTop = UDim.new(0, 4)
	contentPadding.PaddingRight = UDim.new(0, 10)
	contentPadding.PaddingBottom = UDim.new(0, 4)
	contentPadding.Parent = content

	local panel: Panel = { Frame = frame, Content = content }
	panels[name] = panel
	close.Activated:Connect(function()
		Ui.Close(name)
	end)
	return panel
end

function Ui.IsOpen(name: string): boolean
	return openName == name
end

function Ui.Close(name: string)
	local panel = panels[name]
	if panel and openName == name then
		openName = nil
		panel.Frame.Visible = false
		if panel.OnClose then
			panel.OnClose()
		end
	end
end

-- Opens a panel with a little pop, closing any other one
function Ui.Open(name: string)
	local panel = panels[name]
	if not panel then
		return
	end
	if openName and openName ~= name then
		Ui.Close(openName)
	end
	openName = name
	local scale = panel.Frame:FindFirstChildOfClass("UIScale")
	if scale then
		scale.Scale = 0.85
		TweenService:Create(scale, OPEN_TWEEN, { Scale = 1 }):Play()
	end
	panel.Frame.Visible = true
	if panel.OnOpen then
		panel.OnOpen()
	end
end

function Ui.Toggle(name: string)
	if openName == name then
		Ui.Close(name)
	else
		Ui.Open(name)
	end
end

-- 1234567 -> "1,234,567"
function Ui.FormatNumber(n: number): string
	local text = tostring(math.floor(n))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

return Ui
