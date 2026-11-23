--!strict
-- Boats, people, a fishing net and the lighthouse, built from parts in code, after the Godot
-- game's boat_shapes.gd, human_shapes.gd and reef_shapes.gd: Sam's white-and-orange rescue boat
-- with Sam, a rescuer and a flag; a navy fishing boat with its crew and net drum; Sam (a boy of
-- 1.32 m in a yellow top and red cap), rescuers in orange jackets, fishermen in bib overalls; and a
-- red-and-white lighthouse. Everything is laid out in metres facing -z (a boat's bow, a person's
-- face), feet or waterline at y = 0. Left arms are pivots, so people can wave.

local World = require(script.Parent:WaitForChild("World"))

local Shapes = {}

local S = World.S
local HIDDEN = CFrame.new(0, -400, 0)

type Piece = { part: BasePart, at: CFrame, arm: number }

export type Thing = {
	model: Model,
	pieces: { Piece },
	pivots: { CFrame }, -- each arm's shoulder, from the thing's root (studs)
	angles: { number }, -- each arm's turn about z: 0 hangs, about -2.6 waves over the head
	parts: { BasePart },
	frames: { CFrame },
}

local SKIN = Color3.new(0.86, 0.66, 0.52)

local function color(r: number, g: number, b: number): Color3
	return Color3.new(r, g, b)
end

function Shapes.new(name: string, parent: Instance): Thing
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return { model = model, pieces = {}, pivots = {}, angles = {}, parts = {}, frames = {} }
end

local function setup(part: BasePart, size: Vector3, c: Color3, material: Enum.Material?)
	part.Size = size * S
	part.Color = c
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CFrame = HIDDEN
end

-- at: in metres, from the thing's root (or from the arm's shoulder when arm > 0)
local function add(thing: Thing, part: BasePart, at: CFrame, arm: number?)
	part.Parent = thing.model
	table.insert(thing.pieces, { part = part, at = CFrame.new(at.Position * S) * at.Rotation, arm = arm or 0 })
	table.insert(thing.parts, part)
	table.insert(thing.frames, HIDDEN)
end

local function box(thing: Thing, size: Vector3, at: Vector3, c: Color3, arm: number?, material: Enum.Material?): BasePart
	local part = Instance.new("Part")
	setup(part, size, c, material)
	add(thing, part, CFrame.new(at), arm)
	return part
end

local function ball(thing: Thing, size: Vector3, at: Vector3, c: Color3, arm: number?): BasePart
	local part = Instance.new("Part")
	setup(part, size, c)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	add(thing, part, CFrame.new(at), arm)
	return part
end

-- a round rod from a to b (metres)
local function rod(thing: Thing, a: Vector3, b: Vector3, radius: number, c: Color3, arm: number?, material: Enum.Material?): BasePart
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Cylinder
	local along = b - a
	setup(part, Vector3.new(along.Magnitude, radius * 2, radius * 2), c, material)
	local up = if math.abs(along.Unit.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	add(thing, part, CFrame.lookAt((a + b) / 2, b, up) * CFrame.Angles(0, math.pi / 2, 0), arm)
	return part
end

-- half of a pointed bow: full width at the back (+z), a point at the front (-z)
local function bowHalf(thing: Thing, side: number, width: number, low: number, high: number, back: number, front: number, c: Color3)
	local part = Instance.new("WedgePart")
	setup(part, Vector3.new(high - low, width, back - front), c)
	local at = CFrame.new(side * width / 2, (low + high) / 2, (back + front) / 2) * CFrame.Angles(0, 0, -side * math.pi / 2)
	add(thing, part, at)
end

-- moves every part: root is the thing's place in studs (World.frame), arms wave by `angles`
function Shapes.place(thing: Thing, root: CFrame)
	local shoulders = {}
	for i, pivot in thing.pivots do
		shoulders[i] = root * pivot * CFrame.Angles(0, 0, thing.angles[i] or 0)
	end
	for i, piece in thing.pieces do
		local base = if piece.arm > 0 then shoulders[piece.arm] else root
		thing.frames[i] = base * piece.at
	end
	workspace:BulkMoveTo(thing.parts, thing.frames, Enum.BulkMoveMode.FireCFrameChanged)
end

function Shapes.hide(thing: Thing)
	for i in thing.frames do
		thing.frames[i] = HIDDEN
	end
	workspace:BulkMoveTo(thing.parts, thing.frames, Enum.BulkMoveMode.FireCFrameChanged)
end

function Shapes.wave(thing: Thing, waving: boolean, time: number)
	for j in thing.angles do
		thing.angles[j] = if waving then -2.6 + math.sin(time * 9.0 + j) * 0.6 else -0.2
	end
end

-- ---------- people ----------

export type Look = {
	top: Color3,
	sleeves: Color3,
	bottom: Color3,
	bib: boolean?,
	shorts: boolean?,
	stripes: boolean?,
	feet: Color3,
	boots: boolean?,
	hair: Color3,
	hat: string?, -- "cap" or "beanie"
	hatColor: Color3?,
	skin: Color3?,
}

-- a person standing (or kneeling) at `at` (metres, in the thing's space), turned by `turn` about y
function Shapes.person(thing: Thing, at: CFrame, height: number, look: Look, kneel: boolean?, child: boolean?)
	local k = height / (if child then 1.45 else 1.75)
	local h = k * (if child then 1.18 else 1.0)
	local skin = look.skin or SKIN
	local hip = (if kneel then 0.6 else 0.9) * k
	local function p(x: number, y: number, z: number): Vector3
		return (at * CFrame.new(x, y, z)).Position
	end
	-- legs: thigh, shin and shoe (her face is toward -z)
	for _, side in { -1, 1 } do
		local x = 0.095 * k * side
		local knee = if kneel then Vector3.new(x, 0.14 * k, -0.36 * k) else Vector3.new(x * 0.95, 0.5 * k, -0.025 * k)
		local ankle = if kneel then Vector3.new(x, 0.08 * k, 0.1 * k) else Vector3.new(x * 0.9, 0.085 * k, 0)
		local thigh = if look.shorts then look.bottom else look.bottom
		rod(thing, p(x, hip, 0), p(knee.X, knee.Y, knee.Z), 0.075 * k, thigh)
		local shin = if look.shorts then skin elseif look.boots then look.feet else look.bottom
		rod(thing, p(knee.X, knee.Y, knee.Z), p(ankle.X, ankle.Y, ankle.Z), 0.052 * k, shin)
		local toe = if kneel then Vector3.new(0, -0.02 * k, 0.12 * k) else Vector3.new(0, -0.04 * k, -0.06 * k)
		local foot = ankle + toe
		local shoe = Instance.new("Part")
		setup(shoe, Vector3.new(0.1 * k, 0.08 * k, 0.25 * k), look.feet)
		add(thing, shoe, at * CFrame.new(foot) * (if kneel then CFrame.Angles(-1.2, 0, 0) else CFrame.identity))
	end
	-- body, wider than deep
	local torso = 0.56 * k
	box(thing, Vector3.new(0.33 * k, torso, 0.22 * k), p(0, hip + torso / 2 - 0.02 * k, 0), look.top)
	if look.bib then
		box(thing, Vector3.new(0.335 * k, 0.36 * k, 0.225 * k), p(0, hip + 0.16 * k, 0), look.bottom)
		box(thing, Vector3.new(0.2 * k, 0.16 * k, 0.02 * k), p(0, hip + 0.42 * k, -0.115 * k), look.bottom)
	end
	if look.stripes then
		box(thing, Vector3.new(0.34 * k, 0.04 * k, 0.23 * k), p(0, hip + 0.24 * k, 0), color(0.92, 0.94, 0.9))
	end
	-- arms: the right hangs, the left is a pivot at the shoulder so it can wave
	local shoulder = hip + 0.5 * k
	local function arm(origin: Vector3, side: number, pivot: number?)
		local elbow = origin + Vector3.new(0.025 * k * side, -0.28 * k, 0.01 * k)
		local wrist = origin + Vector3.new(0.03 * k * side, -0.52 * k, -0.01 * k)
		local fore = if child then skin else look.sleeves
		if pivot then
			rod(thing, origin, elbow, 0.048 * k, look.sleeves, pivot)
			rod(thing, elbow, wrist, 0.04 * k, fore, pivot)
			ball(thing, Vector3.new(0.07, 0.1, 0.05) * k, wrist + Vector3.new(0, -0.05 * k, 0), skin, pivot)
		else
			rod(thing, p(origin.X, origin.Y, origin.Z), p(elbow.X, elbow.Y, elbow.Z), 0.048 * k, look.sleeves)
			rod(thing, p(elbow.X, elbow.Y, elbow.Z), p(wrist.X, wrist.Y, wrist.Z), 0.04 * k, fore)
			ball(thing, Vector3.new(0.07, 0.1, 0.05) * k, p(wrist.X, wrist.Y - 0.05 * k, wrist.Z), skin)
		end
	end
	arm(Vector3.new(0.205 * k, shoulder, 0), 1)
	table.insert(thing.pivots, CFrame.new((at * CFrame.new(-0.205 * k, shoulder, 0)).Position * S) * at.Rotation)
	table.insert(thing.angles, -0.2)
	arm(Vector3.zero, -1, #thing.pivots)
	-- neck and head, eyes, hair and a hat
	local neck = shoulder + 0.05 * k
	rod(thing, p(0, shoulder - 0.02 * k, 0), p(0, neck + 0.06 * k, 0), 0.05 * k, skin)
	local chin = neck + 0.05 * k
	local headAt = chin + 0.12 * h
	ball(thing, Vector3.new(0.18, 0.24, 0.2) * h, p(0, headAt, 0), skin)
	for _, side in { -1, 1 } do
		ball(thing, Vector3.new(0.022, 0.026, 0.012) * h, p(0.034 * h * side, chin + 0.12 * h, -0.095 * h), color(0.12, 0.08, 0.05))
	end
	ball(thing, Vector3.new(0.19, 0.16, 0.21) * h, p(0, chin + 0.17 * h, 0.012 * h), look.hair)
	if look.hat == "cap" then
		local cap = look.hatColor or color(0.86, 0.18, 0.16)
		ball(thing, Vector3.new(0.2, 0.11, 0.22) * h, p(0, chin + 0.2 * h, 0.005 * h), cap)
		box(thing, Vector3.new(0.13, 0.015, 0.11) * h, p(0, chin + 0.185 * h, -0.13 * h), cap)
	elseif look.hat == "beanie" then
		ball(thing, Vector3.new(0.2, 0.14, 0.22) * h, p(0, chin + 0.2 * h, 0.008 * h), look.hatColor or color(0.8, 0.2, 0.15))
	end
end

Shapes.SAM = {
	top = color(1.0, 0.78, 0.16),
	sleeves = color(1.0, 0.78, 0.16),
	bottom = color(0.2, 0.32, 0.55),
	shorts = true,
	feet = color(0.92, 0.92, 0.9),
	hair = color(0.36, 0.22, 0.12),
	hat = "cap",
	hatColor = color(0.86, 0.18, 0.16),
} :: Look

function Shapes.rescuerLook(index: number): Look
	return {
		top = color(0.96, 0.42, 0.1),
		sleeves = color(0.96, 0.42, 0.1),
		stripes = true,
		bottom = color(0.13, 0.15, 0.2),
		boots = true,
		feet = color(0.1, 0.1, 0.1),
		hair = if index % 2 == 0 then color(0.12, 0.09, 0.07) else color(0.62, 0.45, 0.25),
		skin = if index % 2 == 0 then SKIN else color(0.74, 0.55, 0.42),
	}
end

function Shapes.fishermanLook(index: number): Look
	local i = index % 3 + 1
	return {
		top = ({ color(0.14, 0.18, 0.28), color(0.38, 0.12, 0.1), color(0.3, 0.32, 0.3) })[i],
		sleeves = ({ color(0.14, 0.18, 0.28), color(0.38, 0.12, 0.1), color(0.3, 0.32, 0.3) })[i],
		bottom = ({ color(0.98, 0.78, 0.08), color(0.95, 0.4, 0.08), color(0.98, 0.78, 0.08) })[i],
		bib = true,
		boots = true,
		feet = color(0.12, 0.16, 0.12),
		hair = ({ color(0.18, 0.13, 0.09), color(0.55, 0.5, 0.45), color(0.3, 0.2, 0.12) })[i],
		hat = ({ "beanie", nil, "beanie" } :: { string? })[i],
		hatColor = ({ color(0.8, 0.2, 0.15), color(0.2, 0.2, 0.2), color(0.15, 0.3, 0.6) })[i],
		skin = ({ SKIN, color(0.76, 0.56, 0.44), color(0.8, 0.6, 0.48) })[i],
	}
end

-- ---------- boats ----------

local STERN = 4.6 -- the stern is toward +z, the bow toward -z
local BOW = -5.0
local MIDSHIP = -1.2 -- where the hull starts to narrow to the bow
local DECK = 1.05
local RED_BOTTOM = color(0.42, 0.07, 0.05)
local BOOT = color(0.93, 0.93, 0.9)

-- style: "rescue" (Sam's) or "fishing"
function Shapes.boat(parent: Instance, style: string): Thing
	local rescue = style == "rescue"
	local thing = Shapes.new(if rescue then "SamsBoat" else "FishingBoat", parent)
	local topside = if rescue then color(0.93, 0.94, 0.93) else color(0.07, 0.17, 0.33)
	local stripe = if rescue then color(0.98, 0.42, 0.06) else color(0.92, 0.92, 0.9)
	local white = color(0.94, 0.94, 0.92)
	local trim = if rescue then color(0.98, 0.42, 0.06) else color(0.12, 0.2, 0.34)
	-- the hull in bands: red bottom, white boot stripe, topside, a stripe under the deck, the deck
	local bands = {
		{ -0.85, -0.05, RED_BOTTOM, 3.3 },
		{ -0.05, 0.11, BOOT, 3.6 },
		{ 0.11, 0.85, topside, 3.7 },
		{ 0.85, 1.0, stripe, 3.72 },
		{ 1.0, DECK, color(0.55, 0.5, 0.42), 3.6 },
	}
	for _, band in bands do
		local low, high, c, width = band[1], band[2], band[3], band[4]
		box(thing, Vector3.new(width, high - low, STERN - MIDSHIP), Vector3.new(0, (low + high) / 2, (STERN + MIDSHIP) / 2), c)
		for _, side in { -1, 1 } do
			bowHalf(thing, side, width / 2, low, high, MIDSHIP, BOW, c)
		end
	end
	-- a bulwark round the deck: low walls along the sides and across the stern
	for _, side in { -1, 1 } do
		box(thing, Vector3.new(0.08, 0.55, STERN - MIDSHIP), Vector3.new(side * 1.82, DECK + 0.27, (STERN + MIDSHIP) / 2), topside)
		box(thing, Vector3.new(0.1, 0.06, STERN - MIDSHIP), Vector3.new(side * 1.82, DECK + 0.57, (STERN + MIDSHIP) / 2), color(0.5, 0.38, 0.25))
	end
	box(thing, Vector3.new(3.7, 0.55, 0.08), Vector3.new(0, DECK + 0.27, STERN - 0.04), topside)

	-- the wheelhouse a little aft of the middle, its front leaning back
	local houseZ = 0.6
	box(thing, Vector3.new(2.2, 2.0, 2.6), Vector3.new(0, DECK + 1.0, houseZ), white)
	box(thing, Vector3.new(2.5, 0.12, 3.05), Vector3.new(0, DECK + 2.06, houseZ + 0.1), trim)
	box(thing, Vector3.new(2.26, 0.3, 2.66), Vector3.new(0, DECK + 0.15, houseZ), trim)
	local glass = color(0.05, 0.1, 0.14)
	for kk = 0, 2 do
		local pane = box(thing, Vector3.new(0.56, 0.62, 0.04), Vector3.new(-0.68 + kk * 0.68, DECK + 1.45, houseZ - 1.31), glass, nil, Enum.Material.Glass)
		pane.Reflectance = 0.3
	end
	for _, side in { -1, 1 } do
		for kk = 0, 1 do
			box(thing, Vector3.new(0.04, 0.55, 0.48), Vector3.new(side * 1.11, DECK + 1.45, houseZ + 0.25 - kk * 0.62), glass, nil, Enum.Material.Glass)
		end
		box(thing, Vector3.new(0.04, 1.5, 0.7), Vector3.new(side * 1.11, DECK + 0.85, houseZ + 0.7), white:Lerp(Color3.new(0, 0, 0), 0.12))
	end
	-- a life ring on the back of the house
	local ring = rod(thing, Vector3.new(0, DECK + 1.2, houseZ + 1.31), Vector3.new(0, DECK + 1.2, houseZ + 1.36), 0.36, color(0.98, 0.4, 0.1))
	ring.Name = "LifeRing"
	-- mast with a spreader, radar and a light on top
	local top = DECK + 2.12
	rod(thing, Vector3.new(0, top, houseZ + 0.3), Vector3.new(0, top + 3.6, houseZ + 0.3), 0.06, white)
	rod(thing, Vector3.new(-0.8, top + 2.4, houseZ + 0.3), Vector3.new(0.8, top + 2.4, houseZ + 0.3), 0.03, white)
	box(thing, Vector3.new(1.4, 0.08, 0.16), Vector3.new(0, top + 1.5, houseZ + 0.3), color(0.15, 0.15, 0.16))
	ball(thing, Vector3.new(0.14, 0.14, 0.14), Vector3.new(0, top + 3.65, houseZ + 0.3), color(1, 1, 0.95))
	-- fenders hanging over the sides
	for _, side in { -1, 1 } do
		for _, z in { 2.0, -0.5, -2.4 } do
			rod(thing, Vector3.new(side * 1.95, 0.53, z), Vector3.new(side * 1.95, 1.0, z), 0.11, if rescue then color(0.95, 0.95, 0.95) else color(0.2, 0.42, 0.75))
		end
	end

	if rescue then
		-- a blue light bar on the roof, a flag at the masthead, Sam at the bow and a rescuer aft
		box(thing, Vector3.new(0.9, 0.1, 0.18), Vector3.new(0, top + 0.08, houseZ - 0.6), color(0.2, 0.45, 1.0), nil, Enum.Material.Neon)
		for j = 0, 2 do
			local band = box(thing, Vector3.new(0.02, 0.18, 0.95), Vector3.new(0, top + 3.5 - j * 0.18, houseZ + 0.3 + 0.5), if j == 1 then color(0.96, 0.97, 1.0) else color(0.3, 0.68, 1.0))
			band.Name = "Flag"
		end
		Shapes.person(thing, CFrame.new(0.35, DECK, -3.4) * CFrame.Angles(0, -math.pi / 2, 0), 1.32, Shapes.SAM, false, true)
		Shapes.person(thing, CFrame.new(-0.5, DECK, 2.6), 1.72, Shapes.rescuerLook(0))
	else
		-- the stern gantry that hauls the net, the net drum, orange buoys, and the crew
		local steel = color(0.85, 0.55, 0.12)
		for _, side in { -1, 1 } do
			rod(thing, Vector3.new(side * 1.3, DECK, 4.3), Vector3.new(side * 1.1, DECK + 3.2, 4.75), 0.07, steel)
		end
		rod(thing, Vector3.new(-1.15, DECK + 3.15, 4.74), Vector3.new(1.15, DECK + 3.15, 4.74), 0.07, steel)
		rod(thing, Vector3.new(-0.9, DECK + 0.6, 3.3), Vector3.new(0.9, DECK + 0.6, 3.3), 0.48, color(0.16, 0.36, 0.22))
		for _, side in { -1, 1 } do
			rod(thing, Vector3.new(side * 0.95, DECK + 0.6, 3.3), Vector3.new(side * 1.0, DECK + 0.6, 3.3), 0.62, steel)
		end
		for kk = 0, 4 do
			ball(thing, Vector3.new(0.36, 0.4, 0.36), Vector3.new(1.92, DECK + 0.2, -0.6 - kk * 0.5), color(0.98, 0.36, 0.08))
		end
		local crew = { { 0.7, -1.4, 0.4 }, { -0.6, -2.7, -0.6 }, { 0.5, 3.0, 3.0 } }
		for i, c in crew do
			Shapes.person(thing, CFrame.new(c[1], DECK, c[2]) * CFrame.Angles(0, c[3], 0), 1.74 + 0.04 * (i % 2), Shapes.fishermanLook(i - 1))
		end
	end
	return thing
end

-- a fishing net hanging in the water, 16 m wide and 10 m deep, its top at y = 5 (metres)
function Shapes.net(parent: Instance): Thing
	local thing = Shapes.new("Net", parent)
	local twine = color(0.16, 0.36, 0.22)
	local TWINE = 0.015 -- metres; thin, so it reads as a net, not a fence
	for i = 0, 16 do
		local x = i - 8
		local sag = math.sin(i / 16 * math.pi) * 0.6
		rod(thing, Vector3.new(x, 5, 0), Vector3.new(x, -5, sag), TWINE, twine)
	end
	for j = 0, 10 do
		local y = 5 - j
		local sag = math.sin(j / 10 * math.pi * 0.8) * 0.8
		rod(thing, Vector3.new(-8, y, 0), Vector3.new(8, y, sag * 0.5), TWINE, twine)
	end
	-- floats along the top
	for i = 0, 8 do
		ball(thing, Vector3.new(0.3, 0.3, 0.3), Vector3.new(-8 + i * 2, 5.1, 0), color(0.98, 0.5, 0.1))
	end
	return thing
end

-- the red-and-white lighthouse, 10.8 m tall, standing at `base` (studs) on the first island
function Shapes.lighthouse(parent: Instance, base: Vector3)
	local thing = Shapes.new("Lighthouse", parent)
	local white = color(0.93, 0.93, 0.9)
	local red = color(0.71, 0.21, 0.16)
	local metal = color(0.2, 0.22, 0.24)
	for i = 0, 4 do
		local low = i * 1.7
		local radius = 1.2 - (low + 0.85) * 0.05
		rod(thing, Vector3.new(0, low, 0), Vector3.new(0, low + 1.72, 0), radius, if i % 2 == 0 then white else red)
	end
	rod(thing, Vector3.new(0, 8.5, 0), Vector3.new(0, 8.67, 0), 1.2, metal)
	for i = 0, 13 do
		local a = i / 14 * 2 * math.pi
		rod(thing, Vector3.new(math.cos(a) * 1.12, 8.6, math.sin(a) * 1.12), Vector3.new(math.cos(a) * 1.12, 9.2, math.sin(a) * 1.12), 0.025, metal)
	end
	local lamp = rod(thing, Vector3.new(0, 8.66, 0), Vector3.new(0, 9.7, 0), 0.58, color(1.0, 0.89, 0.6), nil, Enum.Material.Neon)
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 226, 150)
	glow.Range = 40
	glow.Brightness = 2
	glow.Shadows = false
	glow.Parent = lamp
	rod(thing, Vector3.new(0, 9.66, 0), Vector3.new(0, 9.8, 0), 0.8, red)
	rod(thing, Vector3.new(0, 9.8, 0), Vector3.new(0, 10.1, 0), 0.55, red)
	rod(thing, Vector3.new(0, 10.1, 0), Vector3.new(0, 10.4, 0), 0.3, red)
	ball(thing, Vector3.new(0.14, 0.4, 0.14), Vector3.new(0, 10.6, 0), red)
	for _, part in thing.parts do
		part.CastShadow = true
	end
	Shapes.place(thing, CFrame.new(base))
	return thing
end

return Shapes
