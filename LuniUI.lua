--[[
	Luni-UI
	A light, Apple-style Roblox UI library with smooth animations.
	https://github.com/luca057857/Luni

	Quick start:
		local LuniUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/luca057857/Luni/refs/heads/main/LuniUI.lua"))()
		local Window = LuniUI:CreateWindow({ Title = "My Script" })
		local Section = Window:AddSection("General")
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

local function ripple(target, x, y, color)
	local circle = new("Frame", {
		BackgroundColor3 = color or Color3.new(1, 1, 1),
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(0, 0),
		ZIndex = target.ZIndex + 1,
		Parent = target,
	})
	corner(UDim.new(1, 0)).Parent = circle
	local size = math.max(target.AbsoluteSize.X, target.AbsoluteSize.Y) * 1.8
	tween(circle, { Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1 }, 0.55)
	task.delay(0.55, function() circle:Destroy() end)
end

-- Fades + slides an element in from below. Used for anything that appears
-- dynamically (sections, dropdown lists) so the UI never just pops.
local function playIn(instance, offsetY)
	offsetY = offsetY or 10
	local goalPos = instance.Position
	local goalTransparency = instance.BackgroundTransparency
	instance.Position = goalPos + UDim2.fromOffset(0, offsetY)
	instance.BackgroundTransparency = 1
	tween(instance, { Position = goalPos, BackgroundTransparency = goalTransparency }, 0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
end

-- A soft glow ring used on focus/hover for interactive elements — an UIStroke
-- whose transparency and color tween together to fake a light "focus ring".
local function glow(instance, color)
	local ring = new("UIStroke", {
		Color = color or LuniUI.Theme.Accent,
		Thickness = 2,
		Transparency = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = instance,
	})
	return {
		On = function() tween(ring, { Transparency = 0.35 }, 0.15) end,
		Off = function() tween(ring, { Transparency = 1 }, 0.2) end,
	}
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
-- WINDOW — a single scrollable page, no tabs. Group things with AddSection.
--============================================================
function LuniUI:CreateWindow(config)
	config = config or {}
	local Theme = self.Theme
	local name = config.Name or "LuniUI"

	-- Re-running a Luni-UI script (dev iteration, or a second script that
	-- also uses the library) shouldn't stack windows on top of each other —
	-- tear down whatever's already there under this name first.
	local old = PlayerGui:FindFirstChild(name)
	if old then old:Destroy() end

	local screenGui = new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = PlayerGui,
	})

	local width = config.Width or 300
	local height = config.Height or 420

	-- Windows open middle-right by default (out of the way of the game's own
	-- HUD/center). Override with config.AnchorPoint / config.Position if you
	-- want it somewhere else — e.g. AnchorPoint = Vector2.new(0.5, 0.5),
	-- Position = UDim2.fromScale(0.5, 0.5) for dead-center.
	local anchor = config.AnchorPoint or Vector2.new(1, 0.5)
	local finalPosition = config.Position or UDim2.new(1, -24, 0.5, 0)

	local root = new("Frame", {
		Name = "Window",
		AnchorPoint = anchor,
		Position = finalPosition,
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

	local dot = new("Frame", {
		Size = UDim2.fromOffset(8, 8),
		Position = UDim2.fromOffset(12, 16),
		BackgroundColor3 = Theme.Accent,
		Parent = titleBar,
	})
	corner(UDim.new(1, 0)).Parent = dot
	task.spawn(function()
		while dot.Parent do
			tween(dot, { BackgroundTransparency = 0.5 }, 0.9, Enum.EasingStyle.Sine)
			task.wait(0.9)
			tween(dot, { BackgroundTransparency = 0 }, 0.9, Enum.EasingStyle.Sine)
			task.wait(0.9)
		end
	end)

	new("TextLabel", {
		Text = config.Title or "Luni-UI",
		Font = Theme.FontBold,
		TextSize = 14,
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -32, 1, 0),
		Position = UDim2.fromOffset(26, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = titleBar,
	})

	makeDraggable(titleBar, root)

	-- page
	local page = new("ScrollingFrame", {
		Name = "Page",
		Size = UDim2.new(1, 0, 1, -40),
		Position = UDim2.fromOffset(0, 40),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Border,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = root,
	})
	padding(14).Parent = page
	local layout = new("UIListLayout", {
		Padding = UDim.new(0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	layout.Parent = page

	-- Slide + fade toward finalPosition from whichever side the anchor faces
	-- (a right-anchored window slides in from further right, etc.) so the
	-- entrance direction always matches where the window actually lives.
	local slideX = (anchor.X > 0.5 and 36) or (anchor.X < 0.5 and -36) or 0
	local slideY = (anchor.Y > 0.5 and 24) or (anchor.Y < 0.5 and -24) or 0
	local offscreenPos = finalPosition + UDim2.fromOffset(slideX, slideY)

	local function show()
		root.Visible = true
		root.Position = offscreenPos
		root.BackgroundTransparency = 1
		tween(root, { Position = finalPosition, BackgroundTransparency = 0 }, 0.3, Enum.EasingStyle.Back)
	end

	local function hide()
		tween(root, { Position = offscreenPos, BackgroundTransparency = 1 }, 0.2)
		task.delay(0.2, function() root.Visible = false end)
	end

	show()

	if config.ToggleKey then
		UserInputService.InputBegan:Connect(function(input, gpe)
			if gpe then return end
			if input.KeyCode == config.ToggleKey then
				if root.Visible then hide() else show() end
			end
		end)
	end

	local Window = setmetatable({
		ScreenGui = screenGui,
		Root = root,
		Page = page,
		_order = 0,
	}, { __index = self._WindowMethods })

	return Window
end

--============================================================
-- WINDOW METHODS
--============================================================
LuniUI._WindowMethods = {}
local WindowMethods = LuniUI._WindowMethods

function WindowMethods:_nextOrder()
	self._order += 1
	return self._order
end

function WindowMethods:AddSection(name)
	local Theme = LuniUI.Theme

	local card = new("Frame", {
		Name = (name or "Section") .. "Section",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Surface,
		LayoutOrder = self:_nextOrder(),
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

	playIn(card, 14)

	local Section = setmetatable({
		Frame = card,
		_order = 1,
	}, { __index = LuniUI._SectionMethods })

	return Section
end
-- Alias: "Category" reads better for grouped settings, identical behaviour.
WindowMethods.AddCategory = WindowMethods.AddSection

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
	local ring = glow(btn)

	btn.MouseEnter:Connect(function()
		tween(btn, { BackgroundColor3 = Theme.AccentDark, Size = UDim2.new(1, 0, 0, 37) }, 0.12)
		ring.On()
	end)
	btn.MouseLeave:Connect(function()
		tween(btn, { BackgroundColor3 = Theme.Accent, Size = UDim2.new(1, 0, 0, 36) }, 0.12)
		ring.Off()
	end)
	btn.MouseButton1Down:Connect(function(x, y)
		ripple(btn, x - btn.AbsolutePosition.X, y - btn.AbsolutePosition.Y)
		tween(btn, { Size = UDim2.new(1, 0, 0, 33) }, 0.08)
	end)
	btn.MouseButton1Up:Connect(function()
		tween(btn, { Size = UDim2.new(1, 0, 0, 37) }, 0.12, Enum.EasingStyle.Back)
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
	local label = new("TextLabel", {
		Text = config.Text or "Toggle",
		Font = Theme.Font,
		TextSize = Theme.TextSize,
		TextColor3 = state and Theme.Accent or Theme.Text,
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
		tween(label, { TextColor3 = state and Theme.Accent or Theme.Text }, Theme.AnimSpeed)
		-- knob "squishes" while it travels, then snaps back — reads as a bouncier flip
		tween(knob, { Size = UDim2.fromOffset(24, 18) }, 0.1)
		tween(knob, {
			Position = state and UDim2.new(1, -26, 0.5, -9) or UDim2.new(0, 2, 0.5, -9),
		}, 0.14)
		task.delay(0.12, function()
			tween(knob, { Size = UDim2.fromOffset(18, 18) }, 0.12, Enum.EasingStyle.Back)
			tween(knob, {
				Position = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9),
			}, 0.14, Enum.EasingStyle.Back)
		end)
		if not silent and config.Callback then
			task.spawn(config.Callback, state)
		end
	end

	track.MouseButton1Click:Connect(function() apply(not state) end)
	track.MouseEnter:Connect(function() tween(track, { Size = UDim2.fromOffset(42, 23) }, 0.1) end)
	track.MouseLeave:Connect(function() tween(track, { Size = UDim2.fromOffset(40, 22) }, 0.1) end)

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
			tween(knob, { Size = UDim2.fromOffset(18, 18) }, 0.1, Enum.EasingStyle.Back)
			tween(bar, { Size = UDim2.new(1, 0, 0, 8) }, 0.1)
			setFromAlpha((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFromAlpha((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			tween(knob, { Size = UDim2.fromOffset(14, 14) }, 0.12, Enum.EasingStyle.Back)
			tween(bar, { Size = UDim2.new(1, 0, 0, 6) }, 0.12)
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
	local headRing = glow(head)

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
			optBtn.MouseEnter:Connect(function()
				tween(optBtn, { BackgroundTransparency = 0.5, BackgroundColor3 = Theme.Accent }, 0.1)
				tween(optBtn, { TextColor3 = Color3.new(1, 1, 1) }, 0.1)
			end)
			optBtn.MouseLeave:Connect(function()
				tween(optBtn, { BackgroundTransparency = 1 }, 0.1)
				tween(optBtn, { TextColor3 = Theme.Text }, 0.1)
			end)
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
		if open then
			list.Visible = true
			playIn(list, 6)
			-- each option eases in a beat after the last, instead of appearing all at once
			for i, child in ipairs(list:GetChildren()) do
				if child:IsA("TextButton") then
					local goal = child.BackgroundTransparency
					child.BackgroundTransparency = 1
					task.delay((i - 1) * 0.03, function()
						if child.Parent then tween(child, { BackgroundTransparency = goal }, 0.15) end
					end)
				end
			end
		else
			list.Visible = false
		end
		tween(arrow, { Rotation = open and 180 or 0 }, 0.18, Enum.EasingStyle.Back)
	end)
	head.MouseEnter:Connect(headRing.On)
	head.MouseLeave:Connect(headRing.Off)

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
