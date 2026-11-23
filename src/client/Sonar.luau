--!strict
-- The round map that turns with the dolphin, from the Godot game's scripts/sonar.gd: islands,
-- the rim of the world, fish (yellow), sharks (red, ringed while one chases her, faded while it
-- flees), a pink heart for whoever from her family is waiting (at the rim when out of range),
-- and an arrow to the nearest fish when none is in range. Up is the way she swims.

local Sonar = {}
Sonar.__index = Sonar

local RANGE = 80.0 -- metres from her to the rim
local RADIUS = 78 -- pixels, before the HUD's scale
local WORLD = 300.0

local FISH = Color3.fromHex("ffd23f")
local SHARK = Color3.fromHex("ff4d3d")
local TIRED = Color3.fromHex("b8766c")
local LAND = Color3.fromHex("e8d59a")
local REEF = Color3.fromRGB(69, 199, 204)
local FAMILY = Color3.fromHex("ff7fbf")
local AQUA = Color3.fromRGB(120, 220, 240)

export type Sonar = typeof(setmetatable(
	{} :: {
		root: Frame,
		canvas: CanvasGroup,
		pulse: Frame,
		reefs: { Frame },
		lands: { Frame },
		rim: { Frame },
		fish: { Frame },
		sharks: { Frame },
		rings: { Frame },
		heart: TextLabel,
		arrow: TextLabel,
		sam: Frame,
	},
	Sonar
))

local function round(parent: Instance, size: number, color: Color3, transparency: number, z: number): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = UDim2.fromOffset(size, size)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency
	f.BorderSizePixel = 0
	f.ZIndex = z
	f.Visible = false
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = f
	f.Parent = parent
	return f
end

local function ring(parent: Instance, color: Color3, thickness: number, transparency: number, z: number): Frame
	local f = round(parent, 10, color, 1, z)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = transparency
	stroke.Parent = f
	return f
end

local function mark(parent: Instance, text: string, size: number, color: Color3, z: number): TextLabel
	local t = Instance.new("TextLabel")
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Size = UDim2.fromOffset(size, size)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextSize = size
	t.TextColor3 = color
	t.Text = text
	t.ZIndex = z
	t.Visible = false
	t.Parent = parent
	return t
end

function Sonar.new(parent: Instance): Sonar
	local root = Instance.new("Frame")
	root.Name = "Sonar"
	root.AnchorPoint = Vector2.new(1, 0)
	root.Position = UDim2.new(1, -16, 0, 68)
	root.Size = UDim2.fromOffset(RADIUS * 2, RADIUS * 2)
	root.BackgroundColor3 = Color3.fromRGB(4, 31, 51)
	root.BackgroundTransparency = 0.32
	root.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = root
	local edge = Instance.new("UIStroke")
	edge.Color = AQUA
	edge.Transparency = 0.55
	edge.Thickness = 1.5
	edge.Parent = root
	root.Parent = parent

	-- islands are clipped to the round sonar
	local canvas = Instance.new("CanvasGroup")
	canvas.Size = UDim2.fromScale(1, 1)
	canvas.BackgroundTransparency = 1
	local canvasCorner = Instance.new("UICorner")
	canvasCorner.CornerRadius = UDim.new(0.5, 0)
	canvasCorner.Parent = canvas
	canvas.Parent = root

	local half = ring(root, Color3.new(1, 1, 1), 1, 0.84, 2)
	half.Size = UDim2.fromOffset(RADIUS, RADIUS)
	half.Position = UDim2.fromOffset(RADIUS, RADIUS)
	half.Visible = true
	local pulse = ring(root, AQUA, 2, 0.5, 2)
	pulse.Position = UDim2.fromOffset(RADIUS, RADIUS)

	local self = setmetatable({
		root = root,
		canvas = canvas,
		pulse = pulse,
		reefs = {},
		lands = {},
		rim = {},
		fish = {},
		sharks = {},
		rings = {},
		heart = mark(root, "♥", 20, FAMILY, 8),
		arrow = mark(root, "▲", 13, FISH, 7),
		sam = (nil :: any) :: Frame,
	}, Sonar)
	for _ = 1, 10 do
		table.insert(self.reefs, round(canvas, 10, REEF, 0.5, 1))
		table.insert(self.lands, round(canvas, 10, LAND, 0, 2))
	end
	for _ = 1, 36 do
		table.insert(self.rim, round(root, 3, Color3.new(1, 1, 1), 0.6, 3))
	end
	for _ = 1, 16 do
		table.insert(self.fish, round(root, 8, FISH, 0, 4))
	end
	for _ = 1, 8 do
		table.insert(self.sharks, round(root, 9, SHARK, 0, 5))
		table.insert(self.rings, ring(root, SHARK, 1.5, 0, 5))
	end
	-- Sam's boat: a little light blue hull with a mast
	local sam = Instance.new("Frame")
	sam.AnchorPoint = Vector2.new(0.5, 0.5)
	sam.Size = UDim2.fromOffset(13, 12)
	sam.BackgroundTransparency = 1
	sam.Visible = false
	sam.ZIndex = 6
	local hull = Instance.new("Frame")
	hull.AnchorPoint = Vector2.new(0.5, 1)
	hull.Position = UDim2.fromScale(0.5, 1)
	hull.Size = UDim2.fromOffset(13, 5)
	hull.BackgroundColor3 = Color3.fromHex("9fd6ff")
	hull.BorderSizePixel = 0
	hull.ZIndex = 6
	local hullCorner = Instance.new("UICorner")
	hullCorner.CornerRadius = UDim.new(0, 3)
	hullCorner.Parent = hull
	hull.Parent = sam
	local mast = Instance.new("Frame")
	mast.AnchorPoint = Vector2.new(0.5, 0)
	mast.Position = UDim2.fromScale(0.5, 0)
	mast.Size = UDim2.fromOffset(2, 8)
	mast.BackgroundColor3 = Color3.fromHex("9fd6ff")
	mast.BorderSizePixel = 0
	mast.ZIndex = 6
	mast.Parent = sam
	sam.Parent = root
	self.sam = sam
	local me = mark(root, "▲", 15, Color3.new(1, 1, 1), 9)
	me.Position = UDim2.fromOffset(RADIUS, RADIUS)
	me.Visible = true
	return self
end

function Sonar.update(self: Sonar, session: any, time: number)
	local s = session.swimmer
	local px, pz = s.x, s.z
	local c, sn = math.cos(s.yaw), math.sin(s.yaw)
	local k = RADIUS / RANGE
	-- where a point of the sea shows, from the sonar's middle
	local function map(x: number, z: number): (number, number)
		local dx, dz = x - px, z - pz
		return -(dx * c - dz * sn) * k, -(dx * sn + dz * c) * k
	end
	local function place(f: GuiObject, mx: number, my: number, margin: number): boolean
		local inside = mx * mx + my * my < (RADIUS - margin) ^ 2
		f.Visible = inside
		if inside then
			f.Position = UDim2.fromOffset(RADIUS + mx, RADIUS + my)
		end
		return inside
	end

	local pulse = (time * 0.55) % 1
	self.pulse.Visible = true
	self.pulse.Size = UDim2.fromOffset(math.max(pulse * RADIUS * 2, 2), math.max(pulse * RADIUS * 2, 2))
	local stroke = self.pulse:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Transparency = 1 - 0.5 * (1 - pulse)
	end

	local used = 0
	for _, island in session.bed.islands do
		local away = math.sqrt((island.cx - px) ^ 2 + (island.cz - pz) ^ 2)
		if away < RANGE + island.radius * 1.3 and used < #self.reefs then
			used += 1
			local mx, my = map(island.cx, island.cz)
			local reef, land = self.reefs[used], self.lands[used]
			for _, pair in { { reef, 0.62 }, { land, 0.33 } } do
				local f: Frame = pair[1]
				local size = island.radius * pair[2] * 2 * k
				f.Size = UDim2.fromOffset(size, size)
				f.Position = UDim2.fromOffset(RADIUS + mx, RADIUS + my)
				f.Visible = true
			end
		end
	end
	for i = used + 1, #self.reefs do
		self.reefs[i].Visible = false
		self.lands[i].Visible = false
	end

	for i, dot in self.rim do
		local a = (i - 1) / #self.rim * 2 * math.pi
		local mx, my = map(math.cos(a) * WORLD, math.sin(a) * WORLD)
		place(dot, mx, my, 2)
	end

	local nearest, near = nil, math.huge
	for i, dot in self.fish do
		local school = session.schools.list[i]
		if school and school.alive > 0 then
			local mx, my = map(school.cx, school.cz)
			place(dot, mx, my, 4)
			local d = math.sqrt((school.cx - px) ^ 2 + (school.cz - pz) ^ 2)
			if d < near then
				near, nearest = d, school
			end
		else
			dot.Visible = false
		end
	end

	for i, dot in self.sharks do
		local shark = session.sharks[i]
		local ringFrame = self.rings[i]
		if shark then
			local mx, my = map(shark.x, shark.z)
			dot.BackgroundColor3 = if shark.mood == "flee" then TIRED else SHARK
			local inside = place(dot, mx, my, 4)
			local chasing = inside and shark.mood == "chase"
			ringFrame.Visible = chasing
			if chasing then
				local r = (7.5 + 2.0 * math.sin(time * 9.0)) * 2
				ringFrame.Size = UDim2.fromOffset(r, r)
				ringFrame.Position = dot.Position
			end
		else
			dot.Visible = false
			ringFrame.Visible = false
		end
	end

	do
		local mx, my = map(session.samX, session.samZ)
		place(self.sam, mx, my, 6)
	end

	local lost = session.lost
	if lost then
		local mx, my = map(lost.x, lost.z)
		local out = math.sqrt(mx * mx + my * my)
		if out > RADIUS - 9 then
			mx, my = mx / out * (RADIUS - 9), my / out * (RADIUS - 9)
		end
		self.heart.Visible = true
		self.heart.Position = UDim2.fromOffset(RADIUS + mx, RADIUS + my)
		self.heart.TextSize = 18 + 3 * math.sin(time * 5.0)
	else
		self.heart.Visible = false
	end

	if nearest and near > RANGE then
		local mx, my = map(nearest.cx, nearest.cz)
		local out = math.sqrt(mx * mx + my * my)
		local ox, oy = mx / out, my / out
		self.arrow.Visible = true
		self.arrow.Position = UDim2.fromOffset(RADIUS + ox * (RADIUS - 6), RADIUS + oy * (RADIUS - 6))
		self.arrow.Rotation = math.deg(math.atan2(ox, -oy))
	else
		self.arrow.Visible = false
	end
end

return Sonar
