local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer

--============================================================
-- UTILITIES
--============================================================

local function Create(class, props, children)
	local inst = Instance.new(class)
	for k, v in pairs(props or {}) do
		inst[k] = v
	end
	for _, c in ipairs(children or {}) do
		c.Parent = inst
	end
	return inst
end

local function Tween(obj, props, time, style, dir)
	time = time or 0.22
	style = style or Enum.EasingStyle.Quad
	dir = dir or Enum.EasingDirection.Out
	local tw = TweenService:Create(obj, TweenInfo.new(time, style, dir), props)
	tw:Play()
	return tw
end

-- Pop-in animation using a UIScale
local function PopIn(inst, time)
	local scale = inst:FindFirstChildOfClass("UIScale") or Create("UIScale", { Scale = 0.85, Parent = inst })
	scale.Scale = 0.85
	Tween(scale, { Scale = 1 }, time or 0.18, Enum.EasingStyle.Back)
end

-- Makes `target` draggable by clicking/touching `handle`.
--
-- A UIDragDetector always drags whatever GuiObject it is parented under - it has
-- no built-in concept of "drag this handle but move that other frame". So we set
-- DragStyle to Scriptable and hand it a function that always returns nil (meaning
-- "don't move the handle yourself"), then read the detector's DragUDim2 (the
-- cumulative drag offset) each frame and apply it to `target` ourselves. This is
-- the standard trick for "drag the window by its titlebar" with this API.
local function MakeDraggable(handle, target)
	local Detector = Create("UIDragDetector", {
		DragStyle = Enum.UIDragDetectorDragStyle.Scriptable,
		Parent = handle,
	})

	Detector:SetDragStyleFunction(function()
		return nil -- prevent the detector from moving `handle` on its own
	end)

	local startPos

	Detector.DragStart:Connect(function()
		startPos = target.Position
	end)

	Detector.DragContinue:Connect(function()
		if not startPos then return end
		local offset = Detector.DragUDim2
		target.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + offset.X.Offset,
			startPos.Y.Scale, startPos.Y.Offset + offset.Y.Offset
		)
	end)

	Detector.DragEnd:Connect(function()
		startPos = nil
	end)

	return Detector
end

--============================================================
-- LIBRARY
--============================================================

local Library = {}
Library.__index = Library

function Library.new(config)
	config = config or {}

	local self = setmetatable({}, Library)

	self.Title = config.Title or "UI Library"
	self.PrimaryColor = config.PrimaryColor or Color3.fromRGB(24, 24, 28)
	self.SecondaryColor = config.SecondaryColor or Color3.fromRGB(32, 32, 38)
	self.AccentColor = config.AccentColor or Color3.fromRGB(88, 101, 242)
	self.TextColor = config.TextColor or Color3.fromRGB(235, 235, 240)
	self.Font = config.Font or Enum.Font.GothamMedium

	self.Tabs = {}       -- ordered list of Tab objects
	self.ActiveTab = nil
	self.Minimized = false

	-- Theme registry: instances that should update live when SetXColor/SetFont is called
	self._Theme = { Primary = {}, Secondary = {}, Text = {}, Font = {} }

	-- Connections that need to be cleaned up when the GUI is destroyed
	self._Connections = {}

	self:_Build()

	-- Auto-build the Statistics tab last. task.defer runs after the current
	-- resumption cycle finishes - i.e. after your setup script (which creates all
	-- your other tabs/groups/game-detector synchronously) has finished running.
	-- That guarantees Statistics always ends up as the final tab in the sidebar
	-- without you ever having to call CreateStatsTab() yourself.
	task.defer(function()
		self:CreateStatsTab()
	end)

	return self
end

--------------------------------------------------------------
-- Theme registration + live setters
--------------------------------------------------------------

function Library:_Reg(kind, inst, prop)
	table.insert(self._Theme[kind], { Instance = inst, Property = prop })
	if kind == "Primary" then inst[prop] = self.PrimaryColor
	elseif kind == "Secondary" then inst[prop] = self.SecondaryColor
	elseif kind == "Text" then inst[prop] = self.TextColor
	elseif kind == "Font" then inst[prop] = self.Font end
end

function Library:SetPrimaryColor(color)
	self.PrimaryColor = color
	for _, e in ipairs(self._Theme.Primary) do
		Tween(e.Instance, { [e.Property] = color }, 0.25)
	end
end

function Library:SetSecondaryColor(color)
	self.SecondaryColor = color
	for _, e in ipairs(self._Theme.Secondary) do
		Tween(e.Instance, { [e.Property] = color }, 0.25)
	end
end

function Library:SetTextColor(color)
	self.TextColor = color
	for _, e in ipairs(self._Theme.Text) do
		Tween(e.Instance, { [e.Property] = color }, 0.25)
	end
end

function Library:SetFont(font)
	self.Font = font
	for _, e in ipairs(self._Theme.Font) do
		e.Instance[e.Property] = font
	end
end

function Library:SetAccentColor(color)
	self.AccentColor = color
end

--------------------------------------------------------------
-- Base window construction
--------------------------------------------------------------

function Library:_Build()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")

	local ScreenGui = Create("ScreenGui", {
		Name = "UILibrary_" .. self.Title:gsub("%s+", ""),
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})
	self.ScreenGui = ScreenGui

	local Main = Create("Frame", {
		Name = "Main",
		Size = UDim2.fromOffset(560, 380),
		Position = UDim2.new(0.5, -280, 0.5, -190),
		BackgroundColor3 = self.SecondaryColor,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = ScreenGui,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, 10) }),
		Create("UIStroke", { Color = Color3.fromRGB(0, 0, 0), Transparency = 0.6 }),
	})
	self.Main = Main
	self:_Reg("Secondary", Main, "BackgroundColor3")

	local MainScale = Create("UIScale", { Scale = 0.85, Parent = Main })
	Tween(MainScale, { Scale = 1 }, 0.25, Enum.EasingStyle.Back)

	-- Top bar --------------------------------------------------
	local TopBar = Create("Frame", {
		Name = "TopBar",
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = self.PrimaryColor,
		BorderSizePixel = 0,
		Parent = Main,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, 10) }),
	})
	self:_Reg("Primary", TopBar, "BackgroundColor3")
	-- square off the bottom corners of the topbar
	Create("Frame", { BackgroundColor3 = self.PrimaryColor, BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 10), Position = UDim2.new(0, 0, 1, -10), Parent = TopBar })

	local Title = Create("TextLabel", {
		Text = self.Title,
		Font = self.Font,
		TextSize = 16,
		TextColor3 = self.TextColor,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -90, 1, 0),
		Position = UDim2.fromOffset(14, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = TopBar,
	})
	self:_Reg("Text", Title, "TextColor3")
	self:_Reg("Font", Title, "Font")

	local CloseBtn = Create("TextButton", {
		Text = "✕",
		Font = self.Font,
		TextSize = 16,
		TextColor3 = self.TextColor,
		BackgroundColor3 = self.SecondaryColor,
		Size = UDim2.fromOffset(26, 26),
		Position = UDim2.new(1, -34, 0.5, -13),
		AutoButtonColor = false,
		Parent = TopBar,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, 6) }) })
	self:_Reg("Secondary", CloseBtn, "BackgroundColor3")
	self:_Reg("Text", CloseBtn, "TextColor3")

	local MinBtn = Create("TextButton", {
		Text = "—",
		Font = self.Font,
		TextSize = 16,
		TextColor3 = self.TextColor,
		BackgroundColor3 = self.SecondaryColor,
		Size = UDim2.fromOffset(26, 26),
		Position = UDim2.new(1, -66, 0.5, -13),
		AutoButtonColor = false,
		Parent = TopBar,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, 6) }) })
	self:_Reg("Secondary", MinBtn, "BackgroundColor3")
	self:_Reg("Text", MinBtn, "TextColor3")

	for _, btn in ipairs({ CloseBtn, MinBtn }) do
		btn.MouseEnter:Connect(function() Tween(btn, { BackgroundColor3 = self.AccentColor }, 0.15) end)
		btn.MouseLeave:Connect(function() Tween(btn, { BackgroundColor3 = self.SecondaryColor }, 0.15) end)
	end

	-- TopBar is the drag handle; dragging it moves Main.
	MakeDraggable(TopBar, Main)

	CloseBtn.MouseButton1Click:Connect(function() self:Destroy() end)
	MinBtn.MouseButton1Click:Connect(function() self:Minimize() end)

	-- Body: Sidebar + Content ----------------------------------
	local Body = Create("Frame", {
		Name = "Body",
		Size = UDim2.new(1, 0, 1, -40),
		Position = UDim2.fromOffset(0, 40),
		BackgroundTransparency = 1,
		Parent = Main,
	})

	local Sidebar = Create("ScrollingFrame", {
		Name = "Sidebar",
		Size = UDim2.new(0, 150, 1, 0),
		BackgroundColor3 = self.PrimaryColor,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = Body,
	})
	self:_Reg("Primary", Sidebar, "BackgroundColor3")
	Create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = Sidebar })
	Create("UIPadding", {
		PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
		Parent = Sidebar,
	})
	self.Sidebar = Sidebar

	local Content = Create("Frame", {
		Name = "Content",
		Size = UDim2.new(1, -150, 1, 0),
		Position = UDim2.fromOffset(150, 0),
		BackgroundTransparency = 1,
		Parent = Body,
	})
	self.Content = Content

	-- Minimized pill (hidden by default) ------------------------
	local MinPill = Create("TextButton", {
		Name = "MinimizedPill",
		Text = "☰  " .. self.Title,
		Font = self.Font,
		TextSize = 14,
		TextColor3 = self.TextColor,
		BackgroundColor3 = self.PrimaryColor,
		Size = UDim2.fromOffset(160, 36),
		Position = UDim2.new(0.5, -80, 1, -60),
		AutoButtonColor = false,
		Visible = false,
		Parent = ScreenGui,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIStroke", { Color = Color3.new(0, 0, 0), Transparency = 0.5 }),
	})
	self:_Reg("Primary", MinPill, "BackgroundColor3")
	self:_Reg("Text", MinPill, "TextColor3")
	self:_Reg("Font", MinPill, "Font")
	self.MinPill = MinPill

	MinPill.MouseEnter:Connect(function() Tween(MinPill, { BackgroundColor3 = self.AccentColor }, 0.15) end)
	MinPill.MouseLeave:Connect(function() Tween(MinPill, { BackgroundColor3 = self.PrimaryColor }, 0.15) end)
	MinPill.MouseButton1Click:Connect(function() self:Restore() end)
end

--------------------------------------------------------------
-- Minimize / Restore / Destroy
--------------------------------------------------------------

function Library:Minimize()
	if self.Minimized then return end
	self.Minimized = true

	local scale = self.Main:FindFirstChildOfClass("UIScale")
	Tween(scale, { Scale = 0.85 }, 0.18, Enum.EasingStyle.Quad)
	Tween(self.Main, { BackgroundTransparency = 1 }, 0.18)
	task.delay(0.18, function()
		if self.Minimized then
			self.Main.Visible = false
			self.Main.BackgroundTransparency = 0
			self.MinPill.Visible = true
			PopIn(self.MinPill, 0.2)
		end
	end)
end

function Library:Restore()
	if not self.Minimized then return end
	self.Minimized = false
	self.MinPill.Visible = false
	self.Main.Visible = true
	local scale = self.Main:FindFirstChildOfClass("UIScale")
	scale.Scale = 0.85
	Tween(scale, { Scale = 1 }, 0.2, Enum.EasingStyle.Back)
end

function Library:Destroy()
	for _, conn in ipairs(self._Connections) do
		pcall(function() conn:Disconnect() end)
	end
	table.clear(self._Connections)

	if self.ScreenGui then
		self.ScreenGui:Destroy()
	end
end

--============================================================
-- TABS  (sidebar, expandable groups)
--============================================================

local Tab = {}
Tab.__index = Tab

-- internal helper: creates a sidebar button (used for both plain tabs and grouped sub-tabs)
function Library:_CreateSidebarButton(parent, name, indent)
	local Btn = Create("TextButton", {
		Text = "",
		BackgroundColor3 = self.PrimaryColor,
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, 32),
		Parent = parent,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, 6) }) })

	local Label = Create("TextLabel", {
		Text = name,
		Font = self.Font,
		TextSize = 13,
		TextColor3 = self.TextColor,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -(14 + indent), 1, 0),
		Position = UDim2.fromOffset(10 + indent, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = Btn,
	})
	self:_Reg("Text", Label, "TextColor3")
	self:_Reg("Font", Label, "Font")

	return Btn, Label
end

function Library:_SelectTab(tabObj)
	if self.ActiveTab == tabObj then return end
	if self.ActiveTab then
		self.ActiveTab.Page.Visible = false
		Tween(self.ActiveTab.Button, { BackgroundColor3 = self.PrimaryColor }, 0.15)
	end
	self.ActiveTab = tabObj
	tabObj.Page.Visible = true
	local sc = tabObj.Page:FindFirstChildOfClass("UIScale") or Create("UIScale", { Parent = tabObj.Page })
	sc.Scale = 0.96
	Tween(sc, { Scale = 1 }, 0.18, Enum.EasingStyle.Back)
	Tween(tabObj.Button, { BackgroundColor3 = self.AccentColor }, 0.15)
end

-- Creates the ScrollingFrame + layout that backs a Tab's page. Elements created
-- via Tab:CreateX are parented straight into this - there is no intermediate
-- "Section" anymore, so the UIListLayout + AutomaticCanvasSize handle all sizing
-- automatically (including while things like dropdowns are mid-tween).
function Library:_CreatePage()
	local Page = Create("ScrollingFrame", {
		Visible = false,
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = self.Content,
	})
	Create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = Page })
	Create("UIPadding", {
		PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
		Parent = Page,
	})
	return Page
end

-- Creates a top-level (ungrouped) tab
function Library:CreateTab(name, order)
	local Btn, Label = self:_CreateSidebarButton(self.Sidebar, name, 0)
	Btn.LayoutOrder = order or (#self.Tabs + 1)

	local Page = self:_CreatePage()

	local tabObj = setmetatable({
		_lib = self,
		Name = name,
		Button = Btn,
		Page = Page,
	}, Tab)

	Btn.MouseEnter:Connect(function()
		if self.ActiveTab ~= tabObj then Tween(Btn, { BackgroundColor3 = self.SecondaryColor }, 0.15) end
	end)
	Btn.MouseLeave:Connect(function()
		if self.ActiveTab ~= tabObj then Tween(Btn, { BackgroundColor3 = self.PrimaryColor }, 0.15) end
	end)
	Btn.MouseButton1Click:Connect(function() self:_SelectTab(tabObj) end)

	table.insert(self.Tabs, tabObj)
	if not self.ActiveTab then self:_SelectTab(tabObj) end

	return tabObj
end

-- Creates an expandable group of tabs in the sidebar
function Library:CreateTabGroup(name)
	local GroupHeader, GLabel = self:_CreateSidebarButton(self.Sidebar, name, 0)
	GLabel.Font = self.Font

	local Arrow = Create("TextLabel", {
		Text = "▸",
		Font = self.Font,
		TextSize = 13,
		TextColor3 = self.TextColor,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(20, 32),
		Position = UDim2.new(1, -22, 0, 0),
		Parent = GroupHeader,
	})
	self:_Reg("Text", Arrow, "TextColor3")

	local SubHolder = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		ClipsDescendants = true,
		Parent = self.Sidebar,
	})
	Create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = SubHolder })

	local expanded = false
	local group = { Tabs = {}, _libRef = self }

	local function relayout()
		local h = 0
		for _, t in ipairs(group.Tabs) do h += 36 end
		if expanded then
			Tween(SubHolder, { Size = UDim2.new(1, 0, 0, h) }, 0.2)
			Tween(Arrow, { Rotation = 90 }, 0.2)
		else
			Tween(SubHolder, { Size = UDim2.new(1, 0, 0, 0) }, 0.2)
			Tween(Arrow, { Rotation = 0 }, 0.2)
		end
	end

	GroupHeader.MouseButton1Click:Connect(function()
		expanded = not expanded
		relayout()
	end)
	GroupHeader.MouseEnter:Connect(function() Tween(GroupHeader, { BackgroundColor3 = self.SecondaryColor }, 0.15) end)
	GroupHeader.MouseLeave:Connect(function() Tween(GroupHeader, { BackgroundColor3 = self.PrimaryColor }, 0.15) end)

	function group:CreateTab(tabName)
		local libSelf = self._libRef
		local Btn, Label = libSelf:_CreateSidebarButton(SubHolder, tabName, 16)

		local Page = libSelf:_CreatePage()

		local tabObj = setmetatable({
			_lib = libSelf,
			Name = tabName,
			Button = Btn,
			Page = Page,
		}, Tab)

		Btn.MouseEnter:Connect(function()
			if libSelf.ActiveTab ~= tabObj then Tween(Btn, { BackgroundColor3 = libSelf.SecondaryColor }, 0.15) end
		end)
		Btn.MouseLeave:Connect(function()
			if libSelf.ActiveTab ~= tabObj then Tween(Btn, { BackgroundColor3 = libSelf.PrimaryColor }, 0.15) end
		end)
		Btn.MouseButton1Click:Connect(function() libSelf:_SelectTab(tabObj) end)

		table.insert(libSelf.Tabs, tabObj)
		table.insert(self.Tabs, tabObj)
		if not libSelf.ActiveTab then libSelf:_SelectTab(tabObj) end
		relayout()

		return tabObj
	end

	return group
end

--============================================================
-- ELEMENTS
-- (parented directly onto Tab.Page - no Section wrapper anymore)
--============================================================

function Tab:CreateLabel(text)
	local lib = self._lib
	local Lbl = Create("TextLabel", {
		Text = text,
		Font = lib.Font,
		TextSize = 13,
		TextColor3 = lib.TextColor,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = self.Page,
	})
	lib:_Reg("Text", Lbl, "TextColor3")
	lib:_Reg("Font", Lbl, "Font")
	return Lbl
end

function Tab:CreateButton(text, callback)
	local lib = self._lib
	callback = callback or function() end

	local Btn = Create("TextButton", {
		Text = "",
		BackgroundColor3 = lib.SecondaryColor,
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, 32),
		Parent = self.Page,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, 6) }) })
	lib:_Reg("Secondary", Btn, "BackgroundColor3")

	local Lbl = Create("TextLabel", {
		Text = text,
		Font = lib.Font,
		TextSize = 13,
		TextColor3 = lib.TextColor,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = Btn,
	})
	lib:_Reg("Text", Lbl, "TextColor3")
	lib:_Reg("Font", Lbl, "Font")

	Btn.MouseEnter:Connect(function() Tween(Btn, { BackgroundColor3 = lib.AccentColor }, 0.15) end)
	Btn.MouseLeave:Connect(function() Tween(Btn, { BackgroundColor3 = lib.SecondaryColor }, 0.15) end)
	Btn.MouseButton1Click:Connect(function()
		local sc = Btn:FindFirstChildOfClass("UIScale") or Create("UIScale", { Parent = Btn })
		Tween(sc, { Scale = 0.95 }, 0.08)
		task.delay(0.08, function() Tween(sc, { Scale = 1 }, 0.12) end)
		local ok, err = pcall(callback)
		if not ok then warn("[UILibrary] Button callback error: " .. tostring(err)) end
	end)

	return Btn
end

function Tab:CreateToggle(text, default, callback)
	local lib = self._lib
	default = default or false
	callback = callback or function() end

	local Holder = Create("Frame", {
		BackgroundColor3 = lib.SecondaryColor,
		Size = UDim2.new(1, 0, 0, 32),
		Parent = self.Page,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, 6) }) })
	lib:_Reg("Secondary", Holder, "BackgroundColor3")

	local Lbl = Create("TextLabel", {
		Text = text,
		Font = lib.Font,
		TextSize = 13,
		TextColor3 = lib.TextColor,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -60, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = Holder,
	})
	lib:_Reg("Text", Lbl, "TextColor3")
	lib:_Reg("Font", Lbl, "Font")

	local Switch = Create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = default and lib.AccentColor or Color3.fromRGB(70, 70, 78),
		Size = UDim2.fromOffset(38, 20),
		Position = UDim2.new(1, -46, 0.5, -10),
		Parent = Holder,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })

	local Knob = Create("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromOffset(16, 16),
		Position = default and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8),
		Parent = Switch,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })

	local state = default
	local toggleObj = {}

	local function apply(animated)
		local col = state and lib.AccentColor or Color3.fromRGB(70, 70, 78)
		local pos = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
		if animated then
			Tween(Switch, { BackgroundColor3 = col }, 0.18)
			Tween(Knob, { Position = pos }, 0.18, Enum.EasingStyle.Back)
		else
			Switch.BackgroundColor3 = col
			Knob.Position = pos
		end
	end

	Switch.MouseButton1Click:Connect(function()
		state = not state
		apply(true)
		local ok, err = pcall(callback, state)
		if not ok then warn("[UILibrary] Toggle callback error: " .. tostring(err)) end
	end)

	function toggleObj:Set(value)
		state = value
		apply(true)
	end
	function toggleObj:Get() return state end

	return toggleObj
end

function Tab:CreateDropdown(text, options, default, callback)
	local lib = self._lib
	options = options or {}
	callback = callback or function() end

	-- Holder starts collapsed (32px) and clips its own contents. Because it's a
	-- direct child of Page's UIListLayout, growing/shrinking Holder automatically
	-- pushes every element below it up/down in real time - even mid-tween - with
	-- no manual refresh calls needed.
	local Holder = Create("Frame", {
		BackgroundColor3 = lib.SecondaryColor,
		Size = UDim2.new(1, 0, 0, 32),
		ClipsDescendants = true,
		Parent = self.Page,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, 6) }) })
	lib:_Reg("Secondary", Holder, "BackgroundColor3")

	local Header = Create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 32),
		Parent = Holder,
	})

	local Lbl = Create("TextLabel", {
		Text = text,
		Font = lib.Font,
		TextSize = 13,
		TextColor3 = lib.TextColor,
		BackgroundTransparency = 1,
		Size = UDim2.new(0.5, -8, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = Header,
	})
	lib:_Reg("Text", Lbl, "TextColor3")
	lib:_Reg("Font", Lbl, "Font")

	local Selected = Create("TextLabel", {
		Text = default or "Select...",
		Font = lib.Font,
		TextSize = 13,
		TextColor3 = lib.AccentColor,
		BackgroundTransparency = 1,
		Size = UDim2.new(0.5, -30, 1, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = Header,
	})

	local Arrow = Create("TextLabel", {
		Text = "▾", Font = lib.Font, TextSize = 13, TextColor3 = lib.TextColor,
		BackgroundTransparency = 1, Size = UDim2.fromOffset(20, 32),
		Position = UDim2.new(1, -22, 0, 0), Parent = Header,
	})
	lib:_Reg("Text", Arrow, "TextColor3")

	local Panel = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 150),
		Position = UDim2.fromOffset(0, 32),
		Parent = Holder,
	})

	local SearchBox = Create("TextBox", {
		PlaceholderText = "Search...",
		Text = "",
		Font = lib.Font,
		TextSize = 12,
		TextColor3 = lib.TextColor,
		BackgroundColor3 = lib.PrimaryColor,
		ClearTextOnFocus = false,
		Size = UDim2.new(1, -16, 0, 26),
		Position = UDim2.fromOffset(8, 4),
		Parent = Panel,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, 6) }) })
	lib:_Reg("Primary", SearchBox, "BackgroundColor3")
	lib:_Reg("Text", SearchBox, "TextColor3")

	local List = Create("ScrollingFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -16, 1, -38),
		Position = UDim2.fromOffset(8, 34),
		ScrollBarThickness = 3,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = Panel,
	})
	Create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = List })

	local optionButtons = {}
	local expanded = false
	local selectedValue = default

	local function setSelected(value)
		selectedValue = value
		Selected.Text = tostring(value)
	end
	if default then setSelected(default) end

	local function collapse()
		expanded = false
		Tween(Holder, { Size = UDim2.new(1, 0, 0, 32) }, 0.22)
		Tween(Arrow, { Rotation = 0 }, 0.22)
	end

	local function buildOptions(list)
		for _, b in ipairs(optionButtons) do b:Destroy() end
		table.clear(optionButtons)

		for _, opt in ipairs(list) do
			local OptBtn = Create("TextButton", {
				Text = tostring(opt),
				Font = lib.Font,
				TextSize = 12,
				TextColor3 = lib.TextColor,
				BackgroundColor3 = lib.PrimaryColor,
				AutoButtonColor = false,
				Size = UDim2.new(1, 0, 0, 24),
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = List,
			}, { Create("UICorner", { CornerRadius = UDim.new(0, 4) }),
				 Create("UIPadding", { PaddingLeft = UDim.new(0, 8) }) })
			lib:_Reg("Primary", OptBtn, "BackgroundColor3")
			lib:_Reg("Text", OptBtn, "TextColor3")

			OptBtn.MouseEnter:Connect(function() Tween(OptBtn, { BackgroundColor3 = lib.AccentColor }, 0.12) end)
			OptBtn.MouseLeave:Connect(function() Tween(OptBtn, { BackgroundColor3 = lib.PrimaryColor }, 0.12) end)
			OptBtn.MouseButton1Click:Connect(function()
				setSelected(opt)
				local ok, err = pcall(callback, opt)
				if not ok then warn("[UILibrary] Dropdown callback error: " .. tostring(err)) end
				collapse()
			end)

			table.insert(optionButtons, OptBtn)
		end
	end
	buildOptions(options)

	SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
		local query = SearchBox.Text:lower()
		if query == "" then
			buildOptions(options)
			return
		end
		local filtered = {}
		for _, opt in ipairs(options) do
			if tostring(opt):lower():find(query, 1, true) then
				table.insert(filtered, opt)
			end
		end
		buildOptions(filtered)
	end)

	Header.MouseButton1Click:Connect(function()
		if expanded then
			collapse()
		else
			expanded = true
			Tween(Holder, { Size = UDim2.new(1, 0, 0, 32 + 150) }, 0.22)
			Tween(Arrow, { Rotation = 180 }, 0.22)
		end
	end)

	local dropdownObj = {}
	function dropdownObj:Get() return selectedValue end
	function dropdownObj:Set(value) setSelected(value) end
	function dropdownObj:Refresh(newOptions)
		options = newOptions
		buildOptions(options)
	end

	return dropdownObj
end

--============================================================
-- BUILT-IN TAB: Server / Client statistics
--============================================================
-- You don't need to call this yourself - Library.new() schedules it
-- automatically so it always ends up as the last tab in the sidebar.

function Library:CreateStatsTab()
	local tab = self:CreateTab("Statistics")

	local pingLabel = tab:CreateLabel("Ping: -- ms")
	local fpsLabel = tab:CreateLabel("FPS: --")
	local memLabel = tab:CreateLabel("Memory: -- MB")
	local playersLabel = tab:CreateLabel("Players: -- / --")
	local sendLabel = tab:CreateLabel("Data Sent: -- kb/s")
	local recvLabel = tab:CreateLabel("Data Received: -- kb/s")

	local frames = 0
	local lastClock = os.clock()
	local fps = 0

	local heartbeatConn = RunService.Heartbeat:Connect(function()
		frames += 1
		local now = os.clock()
		if now - lastClock >= 1 then
			fps = frames
			frames = 0
			lastClock = now
		end
	end)
	table.insert(self._Connections, heartbeatConn)

	task.spawn(function()
		while tab.Page and tab.Page.Parent do
			pcall(function()
				local pingMs = 0
				local net = Stats.Network
				pcall(function()
					pingMs = math.floor(net.ServerStatsItem["Data Ping"]:GetValue())
				end)
				pingLabel.Text = "Ping: " .. pingMs .. " ms"

				fpsLabel.Text = "FPS: " .. fps

				memLabel.Text = string.format("Memory: %.1f MB", Stats:GetTotalMemoryUsageMb())

				playersLabel.Text = "Players: " .. #Players:GetPlayers() .. " / " .. Players.MaxPlayers

				pcall(function()
					sendLabel.Text = string.format("Data Sent: %.1f kb/s", net.ServerStatsItem["Data Send Kbps"]:GetValue())
					recvLabel.Text = string.format("Data Received: %.1f kb/s", net.ServerStatsItem["Data Receive Kbps"]:GetValue())
				end)
			end)
			task.wait(1)
		end
	end)

	return tab
end

--============================================================
-- BUILT-IN TAB: Version check
--============================================================
-- opts.CurrentVersion (string)          -- the version this client/session is running
-- opts.GetLatestVersion (function -> string)  -- developer-supplied lookup (e.g. RemoteFunction,
--                                                MessagingService, DataStore, HTTP, etc.)

function Library:CreateVersionTab(opts)
	opts = opts or {}
	local tab = self:CreateTab("Version")

	local currentLabel = tab:CreateLabel("Current Version: " .. tostring(opts.CurrentVersion or "unknown"))
	local statusLabel = tab:CreateLabel("Checking for updates...")

	tab:CreateButton("Check Now", function()
		statusLabel.Text = "Checking for updates..."
		task.spawn(function()
			local latest
			if opts.GetLatestVersion then
				local ok, result = pcall(opts.GetLatestVersion)
				if ok then latest = result end
			end
			if latest == nil then
				statusLabel.Text = "Could not reach version server."
			elseif tostring(latest) == tostring(opts.CurrentVersion) then
				statusLabel.Text = "✅ You are on the newest version (" .. tostring(latest) .. ")"
			else
				statusLabel.Text = "⚠️ Outdated! Latest is " .. tostring(latest) .. ", you have " .. tostring(opts.CurrentVersion)
			end
		end)
	end)

	if opts.GetLatestVersion then
		task.spawn(function()
			local ok, result = pcall(opts.GetLatestVersion)
			if ok and result ~= nil then
				if tostring(result) == tostring(opts.CurrentVersion) then
					statusLabel.Text = "✅ You are on the newest version (" .. tostring(result) .. ")"
				else
					statusLabel.Text = "⚠️ Outdated! Latest is " .. tostring(result) .. ", you have " .. tostring(opts.CurrentVersion)
				end
			else
				statusLabel.Text = "Could not reach version server."
			end
		end)
	else
		statusLabel.Text = "No version-check function provided (see opts.GetLatestVersion)."
	end

	return tab
end

--============================================================
-- GAME DETECTOR
--============================================================
-- Lets you ship one GUI with per-game scripts baked in. Pass a table keyed by
-- PlaceId, where each value is either:
--   * a function(Library) ...          -- called directly, build whatever you want
--   * a ModuleScript                   -- require()'d; if it returns a function,
--                                          that function is called with (Library);
--                                          if it returns a table with an Init
--                                          function, Init(Library) is called
--
-- Example:
--   Library:CreateGameDetector({
--       [606849621] = function(Lib)
--           local tab = Lib:CreateTab("Game")
--           tab:CreateButton("Do the thing", function() ... end)
--       end,
--       [920587237] = script.Games.SomeOtherGame, -- a ModuleScript
--   })
--
-- opts.ShowWarning (default true)  -- if no script matches this PlaceId (or the
--                                       matching script errors), drop a warning
--                                       label into the GUI instead of doing
--                                       nothing. Set to false to just stay blank.
-- opts.TabName (default "Game")    -- name of the tab used to show that warning

function Library:CreateGameDetector(games, opts)
	games = games or {}
	opts = opts or {}
	local showWarning = opts.ShowWarning
	if showWarning == nil then showWarning = true end
	local tabName = opts.TabName or "Game"

	local placeId = game.PlaceId
	local entry = games[placeId] or games[tostring(placeId)]

	local function warnInGui(message)
		if not showWarning then return end
		local tab = self:CreateTab(tabName)
		tab:CreateLabel("⚠️ " .. message)
	end

	if entry == nil then
		warn("[UILibrary] GameDetector: no script registered for PlaceId " .. tostring(placeId))
		warnInGui("No script found for this game.\nPlaceId: " .. tostring(placeId))
		return
	end

	local ok, err = pcall(function()
		if typeof(entry) == "function" then
			entry(self)
		elseif typeof(entry) == "Instance" and entry:IsA("ModuleScript") then
			local mod = require(entry)
			if type(mod) == "function" then
				mod(self)
			elseif type(mod) == "table" and type(mod.Init) == "function" then
				mod.Init(self)
			else
				error("ModuleScript for PlaceId " .. tostring(placeId) .. " must return a function or a table with an Init function")
			end
		else
			error("Unsupported game script type for PlaceId " .. tostring(placeId) .. ": " .. typeof(entry))
		end
	end)

	if not ok then
		warn("[UILibrary] GameDetector: script for PlaceId " .. tostring(placeId) .. " errored: " .. tostring(err))
		warnInGui("The script for this game failed to load:\n" .. tostring(err))
	end
end

return Library