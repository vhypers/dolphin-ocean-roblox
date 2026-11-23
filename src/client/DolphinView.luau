--!strict
-- Spring, built from smooth shapes in code: a dark cape, grey flanks and a pale belly like a
-- bottlenose dolphin, with a beating tail and a pink scar on her tail that fades as it heals.
-- Built facing -z in its own space; sizes and places are in metres.

local World = require(script.Parent:WaitForChild("World"))

local DolphinView = {}
DolphinView.__index = DolphinView

local S = World.S

local CAPE = Color3.fromRGB(0x3a, 0x48, 0x56)
local FLANK = Color3.fromRGB(0x75, 0x87, 0x9a)
local BELLY = Color3.fromRGB(0xee, 0xe5, 0xdf)
local FIN = Color3.fromRGB(0x34, 0x40, 0x4c)
local SCAR = Color3.fromRGB(0xd9, 0x9a, 0x9a)

-- at: where the piece sits now; home, size and color: at full size and natural colour
type Piece = { part: BasePart, at: CFrame, group: number, home: CFrame, size: Vector3, color: Color3 }

export type DolphinView = typeof(setmetatable(
	{} :: {
		model: Model,
		pieces: { Piece },
		scars: { BasePart },
		trail: ParticleEmitter,
		beat: number,
		parts: { BasePart },
		frames: { CFrame },
		scale: number,
		tint: number,
	},
	DolphinView
))

-- the tail bends at two hinges (metres, in the dolphin's own space)
local HINGE1 = Vector3.new(0, 0, 0.7)
local HINGE2 = Vector3.new(0, 0, 0.72) -- from hinge 1

local function ellipsoid(size: Vector3, color: Color3): BasePart
	local part = Instance.new("Part")
	part.Size = size * S
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Reflectance = 0.04
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = true
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

local function wedge(size: Vector3, color: Color3): BasePart
	local part = Instance.new("WedgePart")
	part.Size = size * S
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	return part
end

-- name: "Spring" for her, or a family member's; scale and tint as in the Godot game's pod
function DolphinView.new(parent: Instance, name: string?, scale: number?, tint: number?): DolphinView
	local model = Instance.new("Model")
	model.Name = name or "Spring"
	local pieces: { Piece } = {}
	local scars: { BasePart } = {}
	local function add(part: BasePart, at: CFrame, group: number)
		part.Parent = model
		local home = CFrame.new(at.Position * S) * at.Rotation
		table.insert(pieces, { part = part, at = home, group = group, home = home, size = part.Size, color = part.Color })
	end
	local function m(x: number, y: number, z: number): CFrame
		return CFrame.new(x, y, z)
	end

	-- body (group 0)
	add(ellipsoid(Vector3.new(0.58, 0.62, 1.75), FLANK), m(0, -0.02, 0.02), 0)
	add(ellipsoid(Vector3.new(0.46, 0.4, 1.6), CAPE), m(0, 0.13, 0.05), 0)
	add(ellipsoid(Vector3.new(0.5, 0.44, 1.5), BELLY), m(0, -0.13, -0.06), 0)
	add(ellipsoid(Vector3.new(0.44, 0.42, 0.62), FLANK), m(0, 0.02, -0.82), 0) -- melon
	add(ellipsoid(Vector3.new(0.34, 0.26, 0.52), CAPE), m(0, 0.1, -0.8), 0)
	add(ellipsoid(Vector3.new(0.36, 0.28, 0.5), BELLY), m(0, -0.1, -0.84), 0)
	add(ellipsoid(Vector3.new(0.17, 0.12, 0.44), FLANK), m(0, -0.08, -1.17), 0) -- beak
	add(ellipsoid(Vector3.new(0.15, 0.08, 0.4), BELLY), m(0, -0.12, -1.15), 0)
	for _, side in { -1, 1 } do
		local eye = ellipsoid(Vector3.new(0.06, 0.06, 0.07), Color3.fromRGB(15, 15, 18))
		eye.Reflectance = 0.3
		add(eye, m(side * 0.19, -0.02, -0.92), 0)
		local fin = ellipsoid(Vector3.new(0.34, 0.04, 0.17), FIN)
		add(fin, m(side * 0.32, -0.2, -0.42) * CFrame.Angles(0, side * 0.55, side * -0.55), 0)
	end
	-- dorsal fin: the slope leads, the tall side trails
	add(wedge(Vector3.new(0.05, 0.36, 0.44), FIN), m(0, 0.42, 0.18), 0)

	-- tail stock (group 1) and flukes (group 2), placed relative to their hinges
	add(ellipsoid(Vector3.new(0.3, 0.36, 0.86), FLANK), m(0, 0.02, 0.32), 1)
	add(ellipsoid(Vector3.new(0.22, 0.24, 0.8), CAPE), m(0, 0.09, 0.32), 1)
	add(ellipsoid(Vector3.new(0.24, 0.22, 0.74), BELLY), m(0, -0.07, 0.28), 1)
	for _, side in { -1, 1 } do
		local scar = ellipsoid(Vector3.new(0.02, 0.07, 0.3), SCAR)
		scar.Material = Enum.Material.SmoothPlastic
		add(scar, m(side * 0.135, 0.03, 0.38) * CFrame.Angles(0.25, 0, 0), 1)
		table.insert(scars, scar)
	end
	add(ellipsoid(Vector3.new(0.84, 0.05, 0.3), FIN), m(0, 0, 0.13), 2)
	for _, side in { -1, 1 } do
		add(ellipsoid(Vector3.new(0.36, 0.045, 0.22), FIN), m(side * 0.24, 0, 0.2) * CFrame.Angles(0, side * -0.5, 0), 2)
	end

	-- bubbles off her tail when she boosts under water
	local holder = Instance.new("Part")
	holder.Name = "Trail"
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.Transparency = 1
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Parent = model
	local trail = Instance.new("ParticleEmitter")
	trail.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	trail.Color = ColorSequence.new(Color3.fromRGB(220, 245, 255))
	trail.LightEmission = 0.4
	trail.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25 * S), NumberSequenceKeypoint.new(1, 0.05 * S) })
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	trail.Lifetime = NumberRange.new(0.8, 1.4)
	trail.Speed = NumberRange.new(0.5 * S, 1.5 * S)
	trail.SpreadAngle = Vector2.new(40, 40)
	trail.Acceleration = Vector3.new(0, 2.5 * S, 0)
	trail.Rate = 40
	trail.Enabled = false
	trail.Parent = holder
	local trailAt = CFrame.new(0, 0, 0.3 * S)
	table.insert(pieces, { part = holder, at = trailAt, group = 2, home = trailAt, size = holder.Size, color = holder.Color })

	model.Parent = parent
	local parts = {}
	for _, piece in pieces do
		table.insert(parts, piece.part)
	end
	local self = setmetatable({
		model = model,
		pieces = pieces,
		scars = scars,
		trail = trail,
		beat = 0,
		parts = parts,
		frames = table.create(#pieces, CFrame.identity),
		scale = 1,
		tint = 1,
	}, DolphinView)
	self:setScale(scale or 1)
	self:setTint(tint or 1)
	return self
end

-- grown-ups are 0.8 to 1 of her size, a calf about half
function DolphinView.setScale(self: DolphinView, scale: number)
	if math.abs(scale - self.scale) < 0.005 and scale ~= 1 then
		return
	end
	self.scale = scale
	for _, piece in self.pieces do
		if piece.part.Name ~= "Trail" then
			piece.part.Size = piece.size * scale
		end
		piece.at = CFrame.new(piece.home.Position * scale) * piece.home.Rotation
	end
end

-- a shade lighter or darker, like each dolphin in a real pod
function DolphinView.setTint(self: DolphinView, tint: number)
	if tint == self.tint and tint ~= 1 then
		return
	end
	self.tint = tint
	for _, piece in self.pieces do
		if piece.part.Name ~= "Trail" then
			local c = piece.color
			piece.part.Color = Color3.new(math.min(1, c.R * tint), math.min(1, c.G * tint), math.min(1, c.B * tint))
		end
	end
end

-- swimmer: the game's Swimmer; tail: how healed her tail is (0.6 to 1); under: under water
function DolphinView.update(self: DolphinView, dt: number, swimmer: any, tail: number, time: number, under: boolean)
	local root = World.frame(swimmer.x, swimmer.y, swimmer.z, swimmer.yaw, swimmer.pitch, swimmer.roll)
	local swimming = not swimmer.jumping
	local pace = 3.2 + swimmer.speed * 0.32
	if swimming then
		self.beat += dt * pace
	end
	local amp = if swimming then (if swimmer.boosting then 0.32 else 0.2) else 0.05
	local a1 = math.sin(self.beat) * amp
	local a2 = math.sin(self.beat - 0.9) * amp * 1.5
	local hinge1 = root * CFrame.new(HINGE1 * S * self.scale) * CFrame.Angles(a1, 0, 0)
	local hinge2 = hinge1 * CFrame.new(HINGE2 * S * self.scale) * CFrame.Angles(a2, 0, 0)
	local body = root * CFrame.Angles(-a1 * 0.15, 0, 0)
	for i, piece in self.pieces do
		local base = if piece.group == 0 then body elseif piece.group == 1 then hinge1 else hinge2
		self.frames[i] = base * piece.at
	end
	workspace:BulkMoveTo(self.parts, self.frames, Enum.BulkMoveMode.FireCFrameChanged)

	-- the scar fades as her tail heals
	local healed = math.clamp((tail - 0.6) / 0.4, 0, 1)
	for _, scar in self.scars do
		scar.Transparency = 0.1 + 0.9 * healed
	end
	-- blink while she is safe after being hurt
	local hidden = swimmer.invulnerable > 0 and math.floor(time * 10) % 2 == 0
	local modifier = if hidden then 0.7 else 0
	for _, part in self.parts do
		part.LocalTransparencyModifier = modifier
	end
	self.trail.Enabled = under and swimmer.boosting and swimming
end

function DolphinView.setVisible(self: DolphinView, visible: boolean)
	for _, part in self.parts do
		if part.Name ~= "Trail" then
			part.LocalTransparencyModifier = if visible then 0 else 1
		end
	end
end

return DolphinView
