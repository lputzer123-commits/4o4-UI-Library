

	USAGE (see Example.lua for a full walkthrough):

		local UILibrary = require(path.to.UILibrary)

		local Window = UILibrary.new({
			Title = "My Script Hub",
			PrimaryColor = Color3.fromRGB(24, 24, 28),
			SecondaryColor = Color3.fromRGB(32, 32, 38),
			AccentColor = Color3.fromRGB(88, 101, 242),
			TextColor = Color3.fromRGB(235, 235, 240),
			Font = Enum.Font.GothamMedium,
		})

		local MainTab = Window:CreateTab("Main")
		local Section = MainTab:CreateSection("General")

		Section:CreateButton("Say Hi", function()
			print("Hi!")
		end)

--]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
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

local function MakeDraggable(dragHandle, target)
	local dragging = false
	local dragStart, startPos

	dragHandle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = target.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	dragHandle.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			target.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end)
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

	self:_Build()

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

-- Creates a top-level (ungrouped) tab
function Library:CreateTab(name, order)
	local Btn, Label = self:_CreateSidebarButton(self.Sidebar, name, 0)
	Btn.LayoutOrder = order or (#self.Tabs + 1)

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
	Create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = Page })
	Create("UIPadding", {
		PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
		Parent = Page,
	})

	local tabObj = setmetatable({
		_lib = self,
		Name = name,
		Button = Btn,
		Page = Page,
		Sections = {},
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
	local group = { Tabs = {} }

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
		local libSelf = group._libRef
		local Btn, Label = libSelf:_CreateSidebarButton(SubHolder, tabName, 16)

		local Page = Create("ScrollingFrame", {
			Visible = false,
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 3,
			CanvasSize = UDim2.new(0, 0, 0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Parent = libSelf.Content,
		})
		Create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = Page })
		Create("UIPadding", {
			PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
			Parent = Page,
		})

		local tabObj = setmetatable({
			_lib = libSelf,
			Name = tabName,
			Button = Btn,
			Page = Page,
			Sections = {},
		}, Tab)

		Btn.MouseEnter:Connect(function()
			if libSelf.ActiveTab ~= tabObj then Tween(Btn, { BackgroundColor3 = libSelf.SecondaryColor }, 0.15) end
		end)
		Btn.MouseLeave:Connect(function()
			if libSelf.ActiveTab ~= tabObj then Tween(Btn, { BackgroundColor3 = libSelf.PrimaryColor }, 0.15) end
		end)
		Btn.MouseButton1Click:Connect(function() libSelf:_SelectTab(tabObj) end)

		table.insert(libSelf.Tabs, tabObj)
		table.insert(group.Tabs, tabObj)
		if not libSelf.ActiveTab then libSelf:_SelectTab(tabObj) end
		relayout()

		return tabObj
	end

	group._libRef = self
	return group
end

--============================================================
-- SECTIONS (collapsible, live inside a Tab page)
--============================================================

local Section = {}
Section.__index = Section

function Tab:CreateSection(name)
	local lib = self._lib

	local Holder = Create("Frame", {
		BackgroundColor3 = lib.PrimaryColor,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 36),
		AutomaticSize = Enum.AutomaticSize.None,
		Parent = self.Page,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, 8) }) })
	lib:_Reg("Primary", Holder, "BackgroundColor3")

	local Header = Create("TextButton", {
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 36),
		AutoButtonColor = false,
		Parent = Holder,
	})

	local HLabel = Create("TextLabel", {
		Text = name,
		Font = lib.Font,
		TextSize = 14,
		TextColor3 = lib.TextColor,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -34, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = Header,
	})
	lib:_Reg("Text", HLabel, "TextColor3")
	lib:_Reg("Font", HLabel, "Font")

	local Arrow = Create("TextLabel", {
		Text = "▾",
		Font = lib.Font,
		TextSize = 14,
		TextColor3 = lib.TextColor,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(24, 36),
		Position = UDim2.new(1, -30, 0, 0),
		Parent = Header,
	})
	lib:_Reg("Text", Arrow, "TextColor3")

	local Body = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		Position = UDim2.fromOffset(0, 36),
		Parent = Holder,
	})
	Create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = Body })
	Create("UIPadding", {
		PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
		Parent = Body,
	})

	local expanded = true

	local sectionObj = setmetatable({ _lib = lib, Body = Body, Elements = {} }, Section)

	local function refreshHeight()
		local contentH = 0
		local layout = Body:FindFirstChildOfClass("UIListLayout")
		for _, c in ipairs(Body:GetChildren()) do
			if c:IsA("GuiObject") then contentH += c.AbsoluteSize.Y + layout.Padding.Offset end
		end
		contentH += 8 -- bottom padding
		local target = expanded and (36 + contentH) or 36
		Tween(Holder, { Size = UDim2.new(1, 0, 0, target) }, 0.22)
	end
	sectionObj._refresh = refreshHeight

	Header.MouseButton1Click:Connect(function()
		expanded = not expanded
		Tween(Arrow, { Rotation = expanded and 0 or -90 }, 0.2)
		refreshHeight()
	end)

	task.defer(refreshHeight)
	table.insert(self.Sections, sectionObj)
	return sectionObj
end

-- convenience: tabs get a default section so simple UIs need zero boilerplate
function Tab:_Default()
	if not self._defaultSection then
		self._defaultSection = self:CreateSection("General")
	end
	return self._defaultSection
end

function Tab:CreateButton(...) return self:_Default():CreateButton(...) end
function Tab:CreateToggle(...) return self:_Default():CreateToggle(...) end
function Tab:CreateDropdown(...) return self:_Default():CreateDropdown(...) end
function Tab:CreateLabel(...) return self:_Default():CreateLabel(...) end

--============================================================
-- ELEMENTS
--============================================================

function Section:CreateLabel(text)
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
		Parent = self.Body,
	})
	lib:_Reg("Text", Lbl, "TextColor3")
	lib:_Reg("Font", Lbl, "Font")
	task.defer(self._refresh)
	return Lbl
end

function Section:CreateButton(text, callback)
	local lib = self._lib
	callback = callback or function() end

	local Btn = Create("TextButton", {
		Text = "",
		BackgroundColor3 = lib.SecondaryColor,
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, 32),
		Parent = self.Body,
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

	task.defer(self._refresh)
	return Btn
end

function Section:CreateToggle(text, default, callback)
	local lib = self._lib
	default = default or false
	callback = callback or function() end

	local Holder = Create("Frame", {
		BackgroundColor3 = lib.SecondaryColor,
		Size = UDim2.new(1, 0, 0, 32),
		Parent = self.Body,
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

	task.defer(self._refresh)
	return toggleObj
end

function Section:CreateDropdown(text, options, default, callback)
	local lib = self._lib
	options = options or {}
	callback = callback or function() end

	local Holder = Create("Frame", {
		BackgroundColor3 = lib.SecondaryColor,
		Size = UDim2.new(1, 0, 0, 32),
		ClipsDescendants = true,
		Parent = self.Body,
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
		Selected.Text = value
	end
	if default then setSelected(default) end

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
				expanded = false
				Tween(Holder, { Size = UDim2.new(1, 0, 0, 32) }, 0.2)
				Tween(Arrow, { Rotation = 0 }, 0.2)
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
		expanded = not expanded
		if expanded then
			Tween(Holder, { Size = UDim2.new(1, 0, 0, 32 + 150) }, 0.22)
			Tween(Arrow, { Rotation = 180 }, 0.22)
		else
			Tween(Holder, { Size = UDim2.new(1, 0, 0, 32) }, 0.22)
			Tween(Arrow, { Rotation = 0 }, 0.22)
		end
		task.defer(self._refresh)
	end)

	local dropdownObj = {}
	function dropdownObj:Get() return selectedValue end
	function dropdownObj:Set(value) setSelected(value) end
	function dropdownObj:Refresh(newOptions)
		options = newOptions
		buildOptions(options)
	end

	task.defer(self._refresh)
	return dropdownObj
end

--============================================================
-- BUILT-IN TAB: Server / Client statistics
--============================================================

function Library:CreateStatsTab()
	local tab = self:CreateTab("Statistics")
	local sec = tab:CreateSection("Live Stats")

	local pingLabel = sec:CreateLabel("Ping: -- ms")
	local fpsLabel = sec:CreateLabel("FPS: --")
	local memLabel = sec:CreateLabel("Memory: -- MB")
	local playersLabel = sec:CreateLabel("Players: -- / --")
	local sendLabel = sec:CreateLabel("Data Sent: -- kb/s")
	local recvLabel = sec:CreateLabel("Data Received: -- kb/s")

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

	local updateConn = RunService.Heartbeat:Connect(function() end)
	task.spawn(function()
		while tab.Page and tab.Page.Parent do
			local ok = pcall(function()
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
			if not ok then task.wait(1) end
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
	local sec = tab:CreateSection("Build Info")

	local currentLabel = sec:CreateLabel("Current Version: " .. tostring(opts.CurrentVersion or "unknown"))
	local statusLabel = sec:CreateLabel("Checking for updates...")

	sec:CreateButton("Check Now", function()
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

return Library
