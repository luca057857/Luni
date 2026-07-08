--[[
	Luni-UI
	A light, Apple-style Roblox UI library with smooth animations.
	https://github.com/YOUR_ORG/Luni-UI

	Quick start:
		local LuniUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_ORG/Luni-UI/main/src/LuniUI.lua"))()
		local Window = LuniUI:CreateWindow({ Title = "My Script" })
		local Tab = Window:AddTab("Main")
		local Section = Tab:AddSection("General")
		Section:AddButton({ Text = "Click me", Callback = function() print("clicked") end })

	Everything you'd want to tweak lives in LuniUI.Theme (colors, fonts, radius, animation speed).
	Everything you'd want to add lives in LuniUI.Elements — add a new key and it becomes a
	Section:AddXxx(...) method automatically. See the "Adding new elements" section at the bottom.
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local LuniUI = {}
LuniUI.__index = LuniUI

--============================================================
-- THEME — edit these to reskin the whole library
--============================================================
LuniUI.Theme = {
	Background   = Color3.fromRGB(245, 245, 247), -- page background
	Surface      = Color3.fromRGB(255, 255, 255), -- cards / panels
	SurfaceAlt   = Color3.fromRGB(250, 250, 251), -- inputs / wells
	Border       = Color3.fromRGB(225, 225, 229),
	Text         = Color3.fromRGB(16, 16, 18),
	MutedText    = Color3.fromRGB(110, 110, 115),
	Accent       = Color3.fromRGB(0, 88, 230),
	AccentDark   = Color3.fromRGB(0, 67, 179),
	Success      = Color3.fromRGB(52, 199, 89),
	Danger       = Color3.fromRGB(255, 59, 48),

	Font         = Enum.Font.GothamMedium,
	FontBold     = Enum.Font.GothamBold,
	TextSize     = 14,

	CornerRadius = UDim.new(0, 10),
	AnimSpeed    = 0.18,
	EasingStyle  = Enum.EasingStyle.Quint,
	EasingDir    = Enum.EasingDirection.Out,
}

--============================================================
-- SMALL HELPERS — reused by every element, safe to reuse in your own additions
--============================================================
local function tween(instance, props, duration, style, dir)
	local t = TweenService:Create(instance, TweenInfo.new(
		duration or LuniUI.Theme.AnimSpeed,
		style or LuniUI.Theme.EasingStyle,
		dir or LuniUI.Theme.EasingDir
	), props)
	t:Play()
	return t
end

local function new(class, props, children)
	local inst = Instance.new(class)
	for k, v in pairs(props or {}) do
		inst[k] = v
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	return inst
end

local function corner(radius)
	return new("UICorner", { CornerRadius = radius or LuniUI.Theme.CornerRadius })
end

local function stroke(color, thickness)
	return new("UIStroke", {
		Color = color or LuniUI.Theme.Border,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function padding(all)
	return new("UIPadding", {
		PaddingLeft = UDim.new(0, all),
		PaddingRight = UDim.new(0, all),
		PaddingTop = UDim.new(0, all),
		PaddingBottom = UDim.new(0, all),
	})
end

local function ripple(target, x, y)
	local circle = new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.75,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(0, 0),
		ZIndex = target.ZIndex + 1,
		Parent = target,
	})
	corner(UDim.new(1, 0)).Parent = circle
	local size = math.max(target.AbsoluteSize.X, target.AbsoluteSize.Y) * 1.6
	tween(circle, { Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1 }, 0.5)
	task.delay(0.5, function() circle:Destroy() end)
end

-- Global input tracking so the drag keeps following the cursor even when it
-- moves faster than the handle (the old per-handle InputChanged lost tracking
-- the moment the mouse left the title bar). Position is set directly, not
-- tweened, so the window never lags behind the cursor.
local function makeDraggable(handle, target)
	local dragging = false
	local dragStart, startPos

	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = target.Position
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local delta = input.Position - dragStart
			target.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

--============================================================
-- WINDOW
--============================================================
function LuniUI:CreateWindow(config)
	config = config or {}
	local Theme = self.Theme

	local screenGui = new("ScreenGui", {
		Name = config.Name or "LuniUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = PlayerGui,
	})

	local width = config.Width or 300
	local height = config.Height or 420
	local tabBarHeight = 40

	local root = new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = Theme.Background,
		ClipsDescendants = true,
		Parent = screenGui,
	})
	corner(UDim.new(0, 16)).Parent = root
	stroke(Theme.Border).Parent = root

	-- title bar
	local titleBar = new("Frame", {
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = Theme.Surface,
		Parent = root,
	})
	corner(UDim.new(0, 16)).Parent = titleBar
	new("Frame", { -- square off the bottom corners of the title bar
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.new(0, 0, 1, -16),
		BackgroundColor3 = Theme.Surface,
		BorderSizePixel = 0,
		Parent = titleBar,
	})
	new("UIStroke", { Color = Theme.Border, Thickness = 1 }).Parent = titleBar

	new("TextLabel", {
		Text = config.Title or "Luni-UI",
		Font = Theme.FontBold,
		TextSize = 14,
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -24, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = titleBar,
	})

	makeDraggable(titleBar, root)

	-- horizontal tab bar
	local tabBar = new("Frame", {
		Name = "TabBar",
		Size = UDim2.new(1, 0, 0, tabBarHeight),
		Position = UDim2.fromOffset(0, 40),
		BackgroundColor3 = Theme.Background,
		Parent = root,
	})
	new("UIStroke", { Color = Theme.Border, Thickness = 1 }).Parent = tabBar
	local tabList = new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})
	tabList.Parent = tabBar
	padding(6).Parent = tabBar

	-- page container
	local pageContainer = new("Frame", {
		Name = "Pages",
		Size = UDim2.new(1, 0, 1, -(40 + tabBarHeight)),
		Position = UDim2.fromOffset(0, 40 + tabBarHeight),
		BackgroundTransparency = 1,
		Parent = root,
	})

	root.Size = UDim2.fromOffset(width, 0)
	root.BackgroundTransparency = 1
	tween(root, { Size = UDim2.fromOffset(width, height) }, 0.3)
	tween(root, { BackgroundTransparency = 0 }, 0.3)

	if config.ToggleKey then
		UserInputService.InputBegan:Connect(function(input, gpe)
			if gpe then return end
			if input.KeyCode == config.ToggleKey then
				root.Visible = not root.Visible
			end
		end)
	end

	local Window = setmetatable({
		ScreenGui = screenGui,
		Root = root,
		TabBar = tabBar,
		PageContainer = pageContainer,
		Tabs = {},
		_activeTab = nil,
	}, { __index = self._WindowMethods })

	return Window
end

--============================================================
-- WINDOW METHODS
--============================================================
LuniUI._WindowMethods = {}
local WindowMethods = LuniUI._WindowMethods

function WindowMethods:AddTab(name)
	local Theme = LuniUI.Theme
	local self_ = self

	local button = new("TextButton", {
		Text = name,
		Font = Theme.Font,
		TextSize = 13,
		TextColor3 = Theme.MutedText,
		BackgroundColor3 = Theme.Surface,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 0, 28),
		AutoButtonColor = false,
		Parent = self.TabBar,
	})
	corner(UDim.new(0, 8)).Parent = button
	new("UIPadding", {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	}).Parent = button

	local page = new("ScrollingFrame", {
		Name = name .. "Page",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Border,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = self.PageContainer,
	})
	padding(16).Parent = page
	local layout = new("UIListLayout", {
		Padding = UDim.new(0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	layout.Parent = page

	local Tab = setmetatable({
		Name = name,
		Button = button,
		Page = page,
		Window = self_,
	}, { __index = LuniUI._TabMethods })

	button.MouseButton1Click:Connect(function()
		Tab:Select()
	end)
	button.MouseEnter:Connect(function()
		if self_._activeTab ~= Tab then
			tween(button, { BackgroundTransparency = 0.5 }, 0.12)
		end
	end)
	button.MouseLeave:Connect(function()
		if self_._activeTab ~= Tab then
			tween(button, { BackgroundTransparency = 1 }, 0.12)
		end
	end)

	table.insert(self.Tabs, Tab)
	if not self._activeTab then
		Tab:Select()
	end
	return Tab
end

--============================================================
-- TAB METHODS
--============================================================
LuniUI._TabMethods = {}
local TabMethods = LuniUI._TabMethods

function TabMethods:Select()
	local Theme = LuniUI.Theme
	local window = self.Window
	if window._activeTab then
		local prev = window._activeTab
		prev.Page.Visible = false
		tween(prev.Button, { BackgroundTransparency = 1, TextColor3 = Theme.MutedText }, 0.15)
	end
	window._activeTab = self
	self.Page.Visible = true
	tween(self.Button, { BackgroundTransparency = 0, TextColor3 = Theme.Accent }, 0.15)
end

function TabMethods:AddSection(name)
	local Theme = LuniUI.Theme

	local card = new("Frame", {
		Name = name .. "Section",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Surface,
		Parent = self.Page,
	})
	corner().Parent = card
	stroke(Theme.Border).Parent = card
	padding(14).Parent = card

	local layout = new("UIListLayout", {
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	layout.Parent = card

	if name then
		new("TextLabel", {
			Text = name,
			Font = Theme.FontBold,
			TextSize = 13,
			TextColor3 = Theme.Text,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 18),
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 0,
			Parent = card,
		})
	end

	local Section = setmetatable({
		Frame = card,
		_order = 1,
	}, { __index = LuniUI._SectionMethods })

	return Section
end
-- Alias: "Category" reads better for grouped settings, identical behaviour.
TabMethods.AddCategory = TabMethods.AddSection

--============================================================
-- SECTION METHODS + ELEMENT REGISTRY
--============================================================
LuniUI._SectionMethods = {}
local SectionMethods = LuniUI._SectionMethods

-- Every entry here becomes Section:AddXxx(config) automatically.
-- To add a new element type from your own script:
--   LuniUI.Elements.MyThing = function(Section, config) ... return handle end
LuniUI.Elements = {}

function SectionMethods:_nextOrder()
	self._order += 1
	return self._order
end

-- generic wrapper so every AddXxx call goes through one place (sets LayoutOrder,
-- error handling, etc.) without each element needing to repeat that logic.
local function registerAdders(methodsTable, elements)
	for elementName, builder in pairs(elements) do
		methodsTable["Add" .. elementName] = function(self, config)
			config = config or {}
			local order = self:_nextOrder()
			local handle = builder(self, config, LuniUI.Theme)
			if handle and handle.Instance then
				handle.Instance.LayoutOrder = order
			end
			return handle
		end
	end
end

--============================================================
-- ELEMENTS
--============================================================

LuniUI.Elements.Label = function(section, config, Theme)
	local label = new("TextLabel", {
		Text = config.Text or "Label",
		Font = config.Bold and Theme.FontBold or Theme.Font,
		TextSize = config.TextSize or Theme.TextSize,
		TextColor3 = config.Muted and Theme.MutedText or Theme.Text,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Parent = section.Frame,
	})
	return {
		Instance = label,
		SetText = function(_, text) label.Text = text end,
	}
end

LuniUI.Elements.Button = function(section, config, Theme)
	local btn = new("TextButton", {
		Text = config.Text or "Button",
		Font = Theme.Font,
		TextSize = Theme.TextSize,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = Theme.Accent,
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, 36),
		ClipsDescendants = true,
		Parent = section.Frame,
	})
	corner(UDim.new(0, 8)).Parent = btn

	btn.MouseEnter:Connect(function() tween(btn, { BackgroundColor3 = Theme.AccentDark }, 0.12) end)
	btn.MouseLeave:Connect(function() tween(btn, { BackgroundColor3 = Theme.Accent }, 0.12) end)
	btn.MouseButton1Down:Connect(function(x, y)
		ripple(btn, x - btn.AbsolutePosition.X, y - btn.AbsolutePosition.Y)
		tween(btn, { Size = UDim2.new(1, 0, 0, 34) }, 0.08)
	end)
	btn.MouseButton1Up:Connect(function()
		tween(btn, { Size = UDim2.new(1, 0, 0, 36) }, 0.1)
	end)
	btn.MouseButton1Click:Connect(function()
		if config.Callback then
			task.spawn(config.Callback)
		end
	end)

	return { Instance = btn }
end

LuniUI.Elements.Toggle = function(section, config, Theme)
	local state = config.Default or false

	local row = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 24),
		Parent = section.Frame,
	})
	new("TextLabel", {
		Text = config.Text or "Toggle",
		Font = Theme.Font,
		TextSize = Theme.TextSize,
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -50, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})

	local track = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromOffset(40, 22),
		Position = UDim2.new(1, -40, 0.5, -11),
		BackgroundColor3 = state and Theme.Accent or Theme.Border,
		Parent = row,
	})
	corner(UDim.new(1, 0)).Parent = track

	local knob = new("Frame", {
		Size = UDim2.fromOffset(18, 18),
		Position = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = track,
	})
	corner(UDim.new(1, 0)).Parent = knob

	local function apply(newState, silent)
		state = newState
		tween(track, { BackgroundColor3 = state and Theme.Accent or Theme.Border }, Theme.AnimSpeed)
		tween(knob, { Position = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9) }, Theme.AnimSpeed)
		if not silent and config.Callback then
			task.spawn(config.Callback, state)
		end
	end

	track.MouseButton1Click:Connect(function() apply(not state) end)

	return {
		Instance = row,
		Get = function() return state end,
		Set = function(_, v) apply(v) end,
	}
end

LuniUI.Elements.Slider = function(section, config, Theme)
	local min = config.Min or 0
	local max = config.Max or 100
	local value = math.clamp(config.Default or min, min, max)
	local decimals = config.Decimals or 0

	local row = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 40),
		Parent = section.Frame,
	})
	local label = new("TextLabel", {
		Text = config.Text or "Slider",
		Font = Theme.Font,
		TextSize = Theme.TextSize,
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -50, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})
	local valueLabel = new("TextLabel", {
		Text = tostring(value),
		Font = Theme.Font,
		TextSize = Theme.TextSize,
		TextColor3 = Theme.MutedText,
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 50, 0, 18),
		Position = UDim2.new(1, -50, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = row,
	})

	local bar = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, 6),
		Position = UDim2.new(0, 0, 0, 26),
		BackgroundColor3 = Theme.Border,
		Parent = row,
	})
	corner(UDim.new(1, 0)).Parent = bar

	local fill = new("Frame", {
		Size = UDim2.new((value - min) / (max - min), 0, 1, 0),
		BackgroundColor3 = Theme.Accent,
		Parent = bar,
	})
	corner(UDim.new(1, 0)).Parent = fill

	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(14, 14),
		Position = UDim2.new((value - min) / (max - min), 0, 0.5, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = bar,
	})
	corner(UDim.new(1, 0)).Parent = knob
	stroke(Theme.Accent, 2).Parent = knob

	local function round(n)
		local mult = 10 ^ decimals
		return math.floor(n * mult + 0.5) / mult
	end

	local function setFromAlpha(alpha, silent)
		alpha = math.clamp(alpha, 0, 1)
		value = round(min + (max - min) * alpha)
		valueLabel.Text = tostring(value)
		tween(fill, { Size = UDim2.new(alpha, 0, 1, 0) }, 0.05, Enum.EasingStyle.Linear)
		tween(knob, { Position = UDim2.new(alpha, 0, 0.5, 0) }, 0.05, Enum.EasingStyle.Linear)
		if not silent and config.Callback then
			task.spawn(config.Callback, value)
		end
	end

	local dragging = false
	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromAlpha((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFromAlpha((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	return {
		Instance = row,
		Get = function() return value end,
		Set = function(_, v) setFromAlpha((v - min) / (max - min)) end,
	}
end

LuniUI.Elements.Dropdown = function(section, config, Theme)
	local options = config.Options or {}
	local selected = config.Default or options[1]
	local open = false

	local row = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ClipsDescendants = true,
		Parent = section.Frame,
	})

	if config.Text then
		new("TextLabel", {
			Text = config.Text,
			Font = Theme.Font,
			TextSize = Theme.TextSize,
			TextColor3 = Theme.Text,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 18),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
	end

	local head = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, 34),
		Position = UDim2.new(0, 0, 0, config.Text and 22 or 0),
		BackgroundColor3 = Theme.SurfaceAlt,
		Parent = row,
	})
	corner(UDim.new(0, 8)).Parent = head
	stroke(Theme.Border).Parent = head

	local selectedLabel = new("TextLabel", {
		Text = tostring(selected or "Select..."),
		Font = Theme.Font,
		TextSize = Theme.TextSize,
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -34, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = head,
	})

	local arrow = new("TextLabel", {
		Text = "▾",
		Font = Theme.Font,
		TextSize = 14,
		TextColor3 = Theme.MutedText,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(24, 34),
		Position = UDim2.new(1, -30, 0, 0),
		Parent = head,
	})

	local list = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		Position = UDim2.new(0, 0, 0, (config.Text and 22 or 0) + 38),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.SurfaceAlt,
		Visible = false,
		Parent = row,
	})
	corner(UDim.new(0, 8)).Parent = list
	stroke(Theme.Border).Parent = list
	local listLayout = new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder })
	listLayout.Parent = list
	padding(4).Parent = list

	local optionHandle = { Set = nil }

	local function select(option, silent)
		selected = option
		selectedLabel.Text = tostring(option)
		if not silent and config.Callback then
			task.spawn(config.Callback, option)
		end
	end

	local function rebuild()
		for _, child in ipairs(list:GetChildren()) do
			if child:IsA("TextButton") then child:Destroy() end
		end
		for i, option in ipairs(options) do
			local optBtn = new("TextButton", {
				Text = tostring(option),
				Font = Theme.Font,
				TextSize = Theme.TextSize,
				TextColor3 = Theme.Text,
				BackgroundColor3 = Theme.SurfaceAlt,
				BackgroundTransparency = 1,
				AutoButtonColor = false,
				Size = UDim2.new(1, 0, 0, 28),
				LayoutOrder = i,
				Parent = list,
			})
			corner(UDim.new(0, 6)).Parent = optBtn
			optBtn.MouseEnter:Connect(function() tween(optBtn, { BackgroundTransparency = 0.5, BackgroundColor3 = Theme.Border }, 0.1) end)
			optBtn.MouseLeave:Connect(function() tween(optBtn, { BackgroundTransparency = 1 }, 0.1) end)
			optBtn.MouseButton1Click:Connect(function()
				select(option)
				open = false
				list.Visible = false
				tween(arrow, { Rotation = 0 }, 0.15)
			end)
		end
	end
	rebuild()

	head.MouseButton1Click:Connect(function()
		open = not open
		list.Visible = open
		tween(arrow, { Rotation = open and 180 or 0 }, 0.15)
	end)

	return {
		Instance = row,
		Get = function() return selected end,
		Set = function(_, v) select(v, true) end,
		SetOptions = function(_, newOptions)
			options = newOptions
			rebuild()
		end,
	}
end

-- Wire up Section:AddXxx for every element registered above (and any added later).
registerAdders(SectionMethods, LuniUI.Elements)

-- If you add elements to LuniUI.Elements *after* requiring the module (e.g. from
-- your own script), call this to wire the new Section:AddXxx method in too.
function LuniUI:RegisterElement(name, builder)
	self.Elements[name] = builder
	registerAdders(self._SectionMethods, { [name] = builder })
end

return LuniUI
