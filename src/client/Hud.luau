--!strict
-- Everything on screen: loading, the title, the game's panels (hearts, food, air, boost, the
-- calf, day, fish and pod), the sonar, the mark on the shark Hit would charge, messages, pause,
-- the rescue and the end. Every button shows its key, and any mouse button works on a button.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Spring = ReplicatedStorage:WaitForChild("Spring")
local Rules = require(Spring:WaitForChild("Rules"))
local Lang = require(Spring:WaitForChild("Lang"))
local Input = require(script.Parent:WaitForChild("Input"))
local Sonar = require(script.Parent:WaitForChild("Sonar"))
local World = require(script.Parent:WaitForChild("World"))

local Hud = {}
Hud.__index = Hud

local NAVY = Color3.fromRGB(8, 26, 48)
local WHITE = Color3.fromRGB(255, 255, 255)
local SOFT = Color3.fromRGB(196, 222, 240)
local TITLE_FONT = Enum.Font.FredokaOne
local TEXT_FONT = Enum.Font.GothamMedium
local BOLD_FONT = Enum.Font.GothamBold

type Bar = { fill: Frame, label: TextLabel, extra: TextLabel }

export type Hud = typeof(setmetatable(
	{} :: {
		gui: ScreenGui,
		cover: ScreenGui,
		scale: UIScale,
		onAction: (string) -> (),
		screens: { [string]: GuiObject },
		texts: { [string]: TextLabel | TextButton },
		bars: { [string]: Bar },
		hearts: TextLabel,
		dayFill: Frame,
		banner: TextLabel,
		bannerStroke: UIStroke,
		bannerLeft: number,
		say: TextLabel,
		sayLeft: number,
		rescue: Frame,
		gentle: boolean,
		overStats: { string },
		vitals: Frame,
		sonar: Sonar.Sonar,
		marks: ScreenGui,
		reticle: Frame,
		hintsShown: string,
	},
	Hud
))

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function panel(parent: Instance, name: string, size: UDim2, position: UDim2, anchor: Vector2?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.Position = position
	f.AnchorPoint = anchor or Vector2.zero
	f.BackgroundColor3 = NAVY
	f.BackgroundTransparency = 0.35
	f.BorderSizePixel = 0
	corner(f, 14)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(120, 190, 230)
	stroke.Transparency = 0.7
	stroke.Thickness = 1.5
	stroke.Parent = f
	f.Parent = parent
	return f
end

local function label(parent: Instance, name: string, font: Enum.Font, size: number, position: UDim2, box: UDim2, align: Enum.TextXAlignment?): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.Font = font
	t.TextSize = size
	t.TextColor3 = WHITE
	t.Position = position
	t.Size = box
	t.TextXAlignment = align or Enum.TextXAlignment.Left
	t.TextWrapped = true
	t.RichText = true
	t.Text = ""
	t.Parent = parent
	return t
end

local function list(parent: Instance, padding: number)
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, padding)
	l.HorizontalAlignment = Enum.HorizontalAlignment.Center
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = parent
end

function Hud.new(parent: Instance, onAction: (string) -> ()): Hud
	local gui = Instance.new("ScreenGui")
	gui.Name = "SpringHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local scale = Instance.new("UIScale")
	scale.Parent = gui

	local self = setmetatable({
		gui = gui,
		cover = (nil :: any) :: ScreenGui,
		scale = scale,
		onAction = onAction,
		screens = {},
		texts = {},
		bars = {},
		hearts = (nil :: any) :: TextLabel,
		dayFill = (nil :: any) :: Frame,
		banner = (nil :: any) :: TextLabel,
		bannerStroke = (nil :: any) :: UIStroke,
		bannerLeft = 0,
		say = (nil :: any) :: TextLabel,
		sayLeft = 0,
		rescue = (nil :: any) :: Frame,
		gentle = true,
		overStats = {},
		vitals = (nil :: any) :: Frame,
		sonar = (nil :: any) :: Sonar.Sonar,
		marks = (nil :: any) :: ScreenGui,
		reticle = (nil :: any) :: Frame,
		hintsShown = "",
	}, Hud)

	self:_buildLoading()
	self:_buildPlay()
	self:_buildTitle()
	self:_buildPause()
	self:_buildOver()
	self:_buildMarks()
	gui.Parent = parent
	self.cover.Parent = parent
	self.marks.Parent = parent
	self:show("loading")
	return self
end

function Hud._button(self: Hud, parent: Instance, name: string, action: string, order: number): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.LayoutOrder = order
	b.Size = UDim2.new(0, 360, 0, 50)
	b.BackgroundColor3 = Color3.fromRGB(28, 120, 170)
	b.BackgroundTransparency = 0.1
	b.AutoButtonColor = true
	b.Font = BOLD_FONT
	b.TextSize = 22
	b.TextColor3 = WHITE
	b.RichText = true
	b.Text = ""
	corner(b, 12)
	b.Activated:Connect(function()
		self.onAction(action)
	end)
	b.MouseButton2Click:Connect(function()
		self.onAction(action)
	end)
	b.Parent = parent
	self.texts[name] = b
	return b
end

function Hud._buildLoading(self: Hud)
	-- its own screen that also covers Roblox's top bar, so no half-built sea peeks out above it
	local cover = Instance.new("ScreenGui")
	cover.Name = "SpringLoading"
	cover.ResetOnSpawn = false
	cover.IgnoreGuiInset = true
	cover.DisplayOrder = 10
	self.cover = cover
	local f = Instance.new("Frame")
	f.Name = "Loading"
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = Color3.fromRGB(6, 40, 70)
	f.BorderSizePixel = 0
	f.Parent = cover
	self.texts.loading = label(f, "Text", TITLE_FONT, 34, UDim2.fromScale(0, 0.45), UDim2.new(1, 0, 0, 50), Enum.TextXAlignment.Center)
	self.screens.loading = f
end

function Hud._buildTitle(self: Hud)
	local f = panel(self.gui, "Title", UDim2.new(0, 560, 0, 0), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.BackgroundTransparency = 0.25
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 22)
	pad.PaddingBottom = UDim.new(0, 22)
	pad.PaddingLeft = UDim.new(0, 26)
	pad.PaddingRight = UDim.new(0, 26)
	pad.Parent = f
	list(f, 10)
	local function line(name: string, font: Enum.Font, size: number, height: number, order: number, color: Color3?)
		local t = label(f, name, font, size, UDim2.new(), UDim2.new(1, 0, 0, height), Enum.TextXAlignment.Center)
		t.LayoutOrder = order
		t.TextColor3 = color or WHITE
		self.texts[name] = t
	end
	line("titleName", TITLE_FONT, 64, 72, 1)
	line("titleGoal", TEXT_FONT, 22, 30, 2, SOFT)
	line("titleStep", TEXT_FONT, 15, 20, 3, Color3.fromRGB(140, 180, 210))
	self:_button(f, "playButton", "play", 4)
	self:_button(f, "languageButton", "language", 5)
	self:_button(f, "difficultyButton", "difficulty", 6)
	line("difficultyNote", TEXT_FONT, 15, 40, 7, SOFT)
	local help = label(f, "help", TEXT_FONT, 16, UDim2.new(), UDim2.new(1, 0, 0, 0), Enum.TextXAlignment.Left)
	help.AutomaticSize = Enum.AutomaticSize.Y
	help.LayoutOrder = 8
	help.TextColor3 = SOFT
	help.LineHeight = 1.15
	self.texts.help = help
	self.screens.title = f
end

function Hud._buildPause(self: Hud)
	local f = panel(self.gui, "Pause", UDim2.new(0, 420, 0, 0), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.BackgroundTransparency = 0.2
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 20)
	pad.PaddingBottom = UDim.new(0, 22)
	pad.Parent = f
	list(f, 10)
	local t = label(f, "pauseTitle", TITLE_FONT, 44, UDim2.new(), UDim2.new(1, 0, 0, 54), Enum.TextXAlignment.Center)
	t.LayoutOrder = 1
	self.texts.pauseTitle = t
	self:_button(f, "continueButton", "pause", 2)
	self:_button(f, "pauseLanguageButton", "language", 3)
	self:_button(f, "menuButton", "menu", 4)
	self.screens.pause = f
end

function Hud._buildOver(self: Hud)
	local f = panel(self.gui, "Over", UDim2.new(0, 460, 0, 0), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.BackgroundTransparency = 0.2
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 20)
	pad.PaddingBottom = UDim.new(0, 22)
	pad.PaddingLeft = UDim.new(0, 20)
	pad.PaddingRight = UDim.new(0, 20)
	pad.Parent = f
	list(f, 10)
	local t = label(f, "overTitle", TITLE_FONT, 38, UDim2.new(), UDim2.new(1, 0, 0, 0), Enum.TextXAlignment.Center)
	t.AutomaticSize = Enum.AutomaticSize.Y
	t.LayoutOrder = 1
	self.texts.overTitle = t
	local s = label(f, "overStats", TEXT_FONT, 20, UDim2.new(), UDim2.new(1, 0, 0, 0), Enum.TextXAlignment.Center)
	s.AutomaticSize = Enum.AutomaticSize.Y
	s.LayoutOrder = 2
	s.TextColor3 = SOFT
	self.texts.overStats = s
	self:_button(f, "againButton", "play", 3)
	self:_button(f, "overMenuButton", "menu", 4)
	self.screens.over = f
end

function Hud._bar(self: Hud, parent: Instance, name: string, y: number, color: Color3)
	local l = label(parent, name .. "Label", BOLD_FONT, 17, UDim2.new(0, 14, 0, y), UDim2.new(0, 84, 0, 20))
	local back = Instance.new("Frame")
	back.Position = UDim2.new(0, 100, 0, y + 3)
	back.Size = UDim2.new(0, 120, 0, 14)
	back.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	back.BackgroundTransparency = 0.5
	back.BorderSizePixel = 0
	corner(back, 7)
	back.Parent = parent
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	corner(fill, 7)
	fill.Parent = back
	local extra = label(parent, name .. "Extra", TEXT_FONT, 15, UDim2.new(0, 226, 0, y), UDim2.new(0, 60, 0, 20))
	extra.TextColor3 = SOFT
	self.bars[name] = { fill = fill, label = l, extra = extra }
end

function Hud._buildPlay(self: Hud)
	local f = Instance.new("Frame")
	f.Name = "Play"
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundTransparency = 1
	f.Parent = self.gui
	self.screens.play = f

	local vitals = panel(f, "Vitals", UDim2.new(0, 290, 0, 132), UDim2.new(0, 16, 0, 12))
	self.vitals = vitals
	self.hearts = label(vitals, "Hearts", BOLD_FONT, 26, UDim2.new(0, 14, 0, 6), UDim2.new(1, -28, 0, 30))
	self:_bar(vitals, "food", 42, Color3.fromRGB(255, 166, 64))
	self:_bar(vitals, "air", 70, Color3.fromRGB(96, 214, 255))
	self:_bar(vitals, "boost", 98, Color3.fromRGB(255, 226, 92))
	self:_bar(vitals, "calf", 126, Color3.fromHex("ff9ecb")) -- shown while there is a calf
	self.bars.calf.extra.Size = UDim2.new(0, 100, 0, 20)
	self.bars.calf.extra.TextWrapped = false

	local day = panel(f, "Day", UDim2.new(0, 300, 0, 58), UDim2.new(0.5, 0, 0, 12), Vector2.new(0.5, 0))
	self.texts.day = label(day, "DayText", TITLE_FONT, 24, UDim2.new(0, 0, 0, 4), UDim2.new(1, 0, 0, 30), Enum.TextXAlignment.Center)
	local track = Instance.new("Frame")
	track.Position = UDim2.new(0, 20, 0, 38)
	track.Size = UDim2.new(1, -40, 0, 8)
	track.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	track.BackgroundTransparency = 0.5
	track.BorderSizePixel = 0
	corner(track, 4)
	track.Parent = day
	self.dayFill = Instance.new("Frame")
	self.dayFill.Size = UDim2.fromScale(0, 1)
	self.dayFill.BackgroundColor3 = Color3.fromRGB(255, 214, 110)
	self.dayFill.BorderSizePixel = 0
	corner(self.dayFill, 4)
	self.dayFill.Parent = track

	local fish = panel(f, "FishCount", UDim2.new(0, 230, 0, 46), UDim2.new(1, -16, 0, 12), Vector2.new(1, 0))
	self.texts.fish = label(fish, "FishText", TITLE_FONT, 22, UDim2.new(0, 0, 0, 8), UDim2.new(1, 0, 0, 30), Enum.TextXAlignment.Center)
	self.sonar = Sonar.new(f)

	self.banner = label(f, "Banner", TITLE_FONT, 44, UDim2.new(0.5, 0, 0.2, 0), UDim2.new(0, 900, 0, 60), Enum.TextXAlignment.Center)
	self.banner.AnchorPoint = Vector2.new(0.5, 0)
	-- a text's UIStroke does not fade with the text, so _fadeBanner moves both
	local bannerStroke = Instance.new("UIStroke")
	bannerStroke.Thickness = 2
	bannerStroke.Color = Color3.fromRGB(0, 30, 60)
	bannerStroke.Parent = self.banner
	self.bannerStroke = bannerStroke
	self:_fadeBanner(1)

	local sayBox = panel(f, "Say", UDim2.new(0, 640, 0, 0), UDim2.new(0.5, 0, 0.3, 0), Vector2.new(0.5, 0))
	sayBox.AutomaticSize = Enum.AutomaticSize.Y
	sayBox.Visible = false
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.PaddingLeft = UDim.new(0, 16)
	pad.PaddingRight = UDim.new(0, 16)
	pad.Parent = sayBox
	self.say = label(sayBox, "SayText", TEXT_FONT, 21, UDim2.new(), UDim2.new(1, 0, 0, 0), Enum.TextXAlignment.Center)
	self.say.AutomaticSize = Enum.AutomaticSize.Y

	-- on a dark strip of its own, so it reads over white sand and bright sky alike
	local hints = label(f, "Hints", TEXT_FONT, 16, UDim2.new(0.5, 0, 1, -10), UDim2.new(0, 0, 0, 28), Enum.TextXAlignment.Center)
	hints.AnchorPoint = Vector2.new(0.5, 1)
	hints.AutomaticSize = Enum.AutomaticSize.X
	hints.TextWrapped = false
	hints.TextColor3 = SOFT
	hints.BackgroundColor3 = NAVY
	hints.BackgroundTransparency = 0.45
	corner(hints, 14)
	local hintsPad = Instance.new("UIPadding")
	hintsPad.PaddingLeft = UDim.new(0, 16)
	hintsPad.PaddingRight = UDim.new(0, 16)
	hintsPad.Parent = hints
	self.texts.hints = hints

	local rescue = Instance.new("Frame")
	rescue.Name = "Rescue"
	rescue.Size = UDim2.fromScale(1, 1)
	rescue.BackgroundColor3 = Color3.fromRGB(4, 22, 44)
	rescue.BackgroundTransparency = 1
	rescue.BorderSizePixel = 0
	rescue.Visible = false
	rescue.ZIndex = 5
	rescue.Parent = self.cover -- full screen, over Roblox's top bar too
	local rescueText = label(rescue, "Text", TITLE_FONT, 34, UDim2.new(0.5, 0, 0.42, 0), UDim2.new(0, 800, 0, 100), Enum.TextXAlignment.Center)
	rescueText.AnchorPoint = Vector2.new(0.5, 0)
	rescueText.ZIndex = 6
	self.rescue = rescue
	self.texts.rescue = rescueText
end

-- The red sight on the shark Hit would charge (or is charging), drawn without the HUD's scale
-- so it sits right on the shark. A ring with four ticks, pulsing faster during the charge.
function Hud._buildMarks(self: Hud)
	local marks = Instance.new("ScreenGui")
	marks.Name = "SpringMarks"
	marks.ResetOnSpawn = false
	marks.IgnoreGuiInset = false
	marks.DisplayOrder = -1
	self.marks = marks
	local reticle = Instance.new("Frame")
	reticle.Name = "Reticle"
	reticle.AnchorPoint = Vector2.new(0.5, 0.5)
	reticle.BackgroundTransparency = 1
	reticle.Visible = false
	reticle.Parent = marks
	local red = Color3.fromHex("ff4d6a")
	local circle = Instance.new("Frame")
	circle.AnchorPoint = Vector2.new(0.5, 0.5)
	circle.Position = UDim2.fromScale(0.5, 0.5)
	circle.Size = UDim2.fromScale(1, 1)
	circle.BackgroundTransparency = 1
	corner(circle, 999)
	local stroke = Instance.new("UIStroke")
	stroke.Color = red
	stroke.Thickness = 3
	stroke.Parent = circle
	circle.Parent = reticle
	for i = 0, 3 do
		local tick = Instance.new("Frame")
		tick.AnchorPoint = Vector2.new(0.5, 0.5)
		tick.BackgroundColor3 = red
		tick.BorderSizePixel = 0
		local across = i % 2 == 0
		tick.Size = if across then UDim2.new(0.33, 0, 0, 3) else UDim2.new(0, 3, 0.33, 0)
		local out = ({ { 1, 0 }, { 0, 1 }, { -1, 0 }, { 0, -1 } })[i + 1]
		tick.Position = UDim2.fromScale(0.5 + out[1] * 0.49, 0.5 + out[2] * 0.49)
		tick.Parent = reticle
	end
	self.reticle = reticle
end

-- the sight follows the shark: the one she charges, or the nearest within reach when Hit is ready
function Hud.mark(self: Hud, session: any, camera: Camera, playing: boolean, time: number)
	local aim = session.attack
	if
		aim == nil
		and session.target
		and session.targetDistance < Rules.ATTACK_RANGE
		and session.attackCooldown <= 0
	then
		aim = session.target
	end
	if not playing or aim == nil then
		self.reticle.Visible = false
		return
	end
	local at = World.point(aim.x, aim.y, aim.z)
	local screen, inFront = camera:WorldToScreenPoint(at)
	if not inFront then
		self.reticle.Visible = false
		return
	end
	local lunging = session.attack ~= nil
	local away = (camera.CFrame.Position - at).Magnitude / World.S
	local near = math.clamp(22.0 / math.max(away, 1.0), 0.45, 1.6)
	local r = ((if lunging then 30.0 else 36.0) + math.sin(time * (if lunging then 16.0 else 8.0)) * 4.0) * near
	self.reticle.Visible = true
	self.reticle.Position = UDim2.fromOffset(screen.X, screen.Y)
	self.reticle.Size = UDim2.fromOffset(r * 2, r * 2)
end

-- which panel is up: "loading", "title", "play", "pause" or "over"
function Hud.show(self: Hud, name: string)
	self.screens.loading.Visible = name == "loading"
	self.screens.title.Visible = name == "title"
	self.screens.play.Visible = name == "play" or name == "pause"
	self.screens.pause.Visible = name == "pause"
	self.screens.over.Visible = name == "over"
end

function Hud.setLoading(self: Hud, fraction: number)
	self.texts.loading.Text = Lang.f("Building the ocean... %d%%", math.floor(fraction * 100))
end

local function key(text: string, action: string): string
	return string.format('%s   <font transparency="0.35">[%s]</font>', text, Input.badge(action))
end

-- all fixed texts, in the chosen language
function Hud.refresh(self: Hud, gentle: boolean)
	self.gentle = gentle
	local t = self.texts
	t.titleName.Text = Lang.t("Spring")
	t.titleGoal.Text = Lang.t("Find your family across the oceans in 30 days!")
	t.titleStep.Text = Lang.t('Roblox step R2 "Sharks and the pod"')
	t.playButton.Text = key(Lang.t("Swim!"), "jump")
	local languageName = if Lang.language == "ru" then Lang.t("Russian") else Lang.t("English")
	t.languageButton.Text = key(Lang.f("Language: %s", languageName), "language")
	t.pauseLanguageButton.Text = t.languageButton.Text
	t.difficultyButton.Text = key(Lang.f("Difficulty: %s", Lang.t(if gentle then "Gentle" else "Hard")), "difficulty")
	t.difficultyNote.Text = if gentle
		then Lang.t("Fewer and slower sharks, more time before hunger. When your hearts run out, Sam and the rescuers help.")
		else ""
	t.help.Text = table.concat({
		Lang.t("Swim: WASD or arrows, or hold the left mouse button and drag"),
		Lang.t("Boost: Space, Shift or hold the right mouse button"),
		Lang.t("Hit: X, Q or click. Pod: F or E"),
		Lang.t("Hit rams a shark, your Pod chases it off"),
		Lang.t("Jump: J, Enter or the mouse wheel. Rise steeply to leap"),
		Lang.t("Hold Boost in the air to spin"),
		Lang.t("Look back: B   Spring's eyes: V   Pause: P"),
		Lang.t("Come up to breathe every minute"),
		Lang.t("Catch fish so Spring isn't hungry"),
		Lang.t("Spring's tail heals day by day and at healing corals"),
	}, "\n")
	t.pauseTitle.Text = Lang.t("Paused")
	t.continueButton.Text = key(Lang.t("Continue!"), "pause")
	t.menuButton.Text = key(Lang.t("Back to the menu"), "menu")
	t.againButton.Text = key(Lang.t("Play again"), "jump")
	t.overMenuButton.Text = t.menuButton.Text
	self.bars.food.label.Text = Lang.t("Food")
	self.bars.air.label.Text = Lang.t("Air")
	self.bars.boost.label.Text = Lang.t("Boost")
	self.bars.calf.label.Text = Lang.t("Calf")
	self.hintsShown = ""
	t.hints.Text = self:_hintText(true, false)
end

-- the keys along the bottom; Hit and Pod fade while they rest
function Hud._hintText(self: Hud, hitReady: boolean, podReady: boolean): string
	local function dim(text: string, ready: boolean): string
		return if ready then text else '<font transparency="0.6">' .. text .. "</font>"
	end
	return string.format(
		"%s %s   ·   %s   ·   %s   ·   %s %s   ·   %s B   ·   %s V   ·   %s P",
		Lang.t("Boost"),
		Input.badge("boost"),
		dim(Lang.t("Hit") .. " " .. Input.badge("attack"), hitReady),
		dim(Lang.t("Pod") .. " " .. Input.badge("pod"), podReady),
		Lang.t("Jump"),
		Input.badge("jump"),
		Lang.t("Back"),
		Lang.t("View"),
		Lang.t("Pause")
	)
end

-- 0 shows the banner, 1 hides it; its outline goes with it
function Hud._fadeBanner(self: Hud, transparency: number)
	self.banner.TextTransparency = transparency
	self.bannerStroke.Transparency = 0.3 + 0.7 * transparency
end

function Hud.message(self: Hud, kind: string, text: string, big: boolean, seconds: number)
	if kind == "banner" then
		self.banner.Text = text
		self.banner.TextSize = if big then 48 else 34
		self:_fadeBanner(0)
		self.bannerLeft = seconds
	else
		self.say.Text = text
		self.say.Parent.Visible = true
		self.sayLeft = seconds
	end
end

function Hud.clearMessages(self: Hud)
	self.bannerLeft = 0
	self:_fadeBanner(1)
	self.sayLeft = 0
	self.say.Parent.Visible = false
end

function Hud.update(self: Hud, dt: number, session: any, screenHeight: number)
	self.scale.Scale = math.clamp(screenHeight / 900, 0.7, 1.35)
	local s = session.swimmer
	local hearts = {}
	for i = 1, Rules.LIVES do
		table.insert(hearts, if i <= session.lives then '<font color="#ff5a6e">♥</font>' else '<font color="#56606b">♥</font>')
	end
	self.hearts.Text = table.concat(hearts, " ")
	self.bars.food.fill.Size = UDim2.fromScale(math.clamp(session.food / Rules.FOOD_MAX, 0, 1), 1)
	self.bars.air.fill.Size = UDim2.fromScale(math.clamp(s.air / Rules.AIR_MAX, 0, 1), 1)
	self.bars.boost.fill.Size = UDim2.fromScale(math.clamp(s.energy, 0, 1), 1)
	local low = s.air < Rules.AIR_LOW and math.floor(os.clock() * 4) % 2 == 0
	self.bars.air.fill.BackgroundColor3 = if low then Color3.fromRGB(255, 90, 90) else Color3.fromRGB(96, 214, 255)
	local depth = math.max(0, math.floor(Rules.SEA_LEVEL - s.y + 0.5))
	self.bars.air.extra.Text = Lang.f("%d m", depth)
	self.texts.day.Text = Lang.f("Day %d of %d", session.day, Rules.DAYS)
	self.dayFill.Size = UDim2.fromScale(math.clamp(session.dayTime / Rules.DAY_LENGTH, 0, 1), 1)
	self.dayFill.BackgroundColor3 = if session:isNight() then Color3.fromRGB(150, 170, 255) else Color3.fromRGB(255, 214, 110)
	self.texts.fish.Text = Lang.f("Fish %d   Pod %d", session.fish, session:familySize())
	self.sonar:update(session, os.clock())

	-- the calf's hunger, while there is a calf
	local calf = session.calf
	local calfBar = self.bars.calf
	local showCalf = calf ~= nil
	calfBar.label.Visible = showCalf
	calfBar.extra.Visible = showCalf
	local track = calfBar.fill.Parent :: Frame
	track.Visible = showCalf
	self.vitals.Size = UDim2.new(0, if showCalf then 330 else 290, 0, if showCalf then 160 else 132)
	if calf then
		local little = calf.food / 100
		calfBar.fill.Size = UDim2.fromScale(math.clamp(little, 0, 1), 1)
		calfBar.extra.Text = Lang.t(if little > 0.5 then "well fed" elseif little > 0.25 then "hungry" else "very hungry!")
		calfBar.extra.TextColor3 = if little > 0.25 then SOFT else Color3.fromRGB(255, 120, 120)
	end

	local hitReady = session.attackCooldown <= 0
	local podReady = #session.pod > 0 and session.podCooldown <= 0
	local shown = Lang.language .. tostring(hitReady) .. tostring(podReady)
	if shown ~= self.hintsShown then
		self.hintsShown = shown
		self.texts.hints.Text = self:_hintText(hitReady, podReady)
	end

	if self.bannerLeft > 0 then
		self.bannerLeft -= dt
		if self.bannerLeft < 0.5 then
			self:_fadeBanner(1 - math.max(self.bannerLeft, 0) / 0.5)
		end
	end
	if self.sayLeft > 0 then
		self.sayLeft -= dt
		if self.sayLeft <= 0 then
			self.say.Parent.Visible = false
		end
	end

	local rescuing = session.rescueLeft > 0
	if rescuing then
		self.rescue.Visible = true
		local t = Rules.RESCUE_TIME - session.rescueLeft
		local fade = math.min(1, t / 0.6, session.rescueLeft / 0.6)
		self.rescue.BackgroundTransparency = 1 - 0.85 * fade
		self.texts.rescue.Text = (if session.rescueReason ~= "" then session.rescueReason .. "\n" else "")
			.. Lang.t("Sam and the rescuers are on their way...")
		self.texts.rescue.TextTransparency = 1 - fade
	elseif self.rescue.Visible then
		self.rescue.Visible = false
	end
end

function Hud.showOver(self: Hud, session: any)
	self.texts.overTitle.Text = if session.reunited
		then Lang.t("Spring found her mother. The whole family is together again!")
		elseif session.won then Lang.t("You swam through all 30 days!")
		else (if session.rescueReason ~= "" then session.rescueReason else Lang.t("The game is over"))
	self.texts.overStats.Text = string.format(
		"%s: %d\n%s: %d\n%s: %s\n%s: %d\n%s: %d",
		Lang.t("fish caught"),
		session.fish,
		Lang.t("days lived"),
		math.min(session.day, Rules.DAYS),
		Lang.t("family found"),
		Lang.f("%d of %d", session.familyFound, #Rules.FAMILY_DAYS),
		Lang.t("sharks driven off"),
		session.driven,
		Lang.t("spins in the air"),
		session.tricks
	)
end

function Hud.tween(object: Instance, seconds: number, goal: { [string]: any })
	TweenService:Create(object, TweenInfo.new(seconds), goal):Play()
end

return Hud
