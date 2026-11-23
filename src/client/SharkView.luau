--!strict
-- Sharks built from smooth shapes in code, laid out like the Godot game's AnimalShapes.shark():
-- a great white 6.3 m long with its mouth 2.6 m ahead of its middle, a slate back, grey flanks,
-- a white belly, gills, a tall back fin, and a tail that sweeps side to side. Built facing -z in
-- metres; the tail stock and the tail fin bend at two hinges. A shark hit by the pod rolls over
-- and reels.

local World = require(script.Parent:WaitForChild("World"))

local SharkView = {}
SharkView.__index = SharkView

local S = World.S
local HIDDEN = CFrame.new(0, -400, 0)

local BACK = Color3.fromHex("46545e")
local SIDE = Color3.fromHex("6d7c85")
local BELLY = Color3.fromHex("e8ebe8")
local LINE = Color3.fromHex("1a2025")

-- hinges in metres, in the shark's own space (nose toward -z)
local HINGE1 = Vector3.new(0, 0, 1.1)
local HINGE2 = Vector3.new(0, 0, 1.2) -- from hinge 1

type Piece = { part: BasePart, at: CFrame, group: number }
type One = { model: Model, pieces: { Piece } }

export type SharkView = typeof(setmetatable(
	{} :: {
		folder: Folder,
		ones: { One },
		parts: { BasePart },
		frames: { CFrame },
	},
	SharkView
))

local function plain(className: string, size: Vector3, color: Color3): BasePart
	local part = Instance.new(className) :: BasePart
	part.Size = size * S
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CFrame = HIDDEN
	return part
end

local function ellipsoid(size: Vector3, color: Color3): BasePart
	local part = plain("Part", size, color)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

-- a thin fin from root to tip (metres), chord wide; `thin` is the way its flat sides face
-- (up for the side fins, sideways for the tail fin)
local function fin(root: Vector3, tip: Vector3, chord: number, thick: number, color: Color3, thin: Vector3?): (BasePart, CFrame)
	local part = ellipsoid(Vector3.new(chord, thick, (tip - root).Magnitude * 1.08), color)
	local middle = (root + tip) / 2
	return part, CFrame.lookAt(middle, tip, thin or Vector3.yAxis)
end

local function build(folder: Instance, index: number): One
	local model = Instance.new("Model")
	model.Name = "Shark" .. index
	local pieces: { Piece } = {}
	local function add(part: BasePart, at: CFrame, group: number)
		part.Parent = model
		table.insert(pieces, { part = part, at = CFrame.new(at.Position * S) * at.Rotation, group = group })
	end
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(x, y, z)
	end

	-- body and head (group 0)
	add(ellipsoid(Vector3.new(1.45, 1.42, 4.3), SIDE), at(0, 0.02, -0.45), 0)
	add(ellipsoid(Vector3.new(1.12, 1.0, 4.1), BACK), at(0, 0.3, -0.42), 0)
	add(ellipsoid(Vector3.new(1.28, 0.92, 3.9), BELLY), at(0, -0.3, -0.55), 0)
	add(ellipsoid(Vector3.new(0.9, 0.78, 1.5), SIDE), at(0, 0.02, -2.2), 0) -- snout
	add(ellipsoid(Vector3.new(0.7, 0.5, 1.4), BACK), at(0, 0.16, -2.15), 0)
	add(ellipsoid(Vector3.new(0.78, 0.46, 1.25), BELLY), at(0, -0.17, -2.15), 0)
	add(plain("Part", Vector3.new(0.5, 0.035, 0.06), LINE), at(0, -0.24, -2.42), 0) -- mouth
	for _, side in { -1, 1 } do
		local eye = ellipsoid(Vector3.new(0.09, 0.09, 0.09), Color3.fromRGB(8, 8, 10))
		eye.Reflectance = 0.25
		add(eye, at(side * 0.33, 0.14, -2.28), 0)
		for k = 0, 4 do -- gills
			add(plain("Part", Vector3.new(0.02, 0.48, 0.035), LINE), at(side * 0.69, 0.02, -1.62 + k * 0.11), 0)
		end
		local pectoral, pf = fin(Vector3.new(side * 0.55, -0.4, -0.8), Vector3.new(side * 1.68, -0.88, 0.05), 0.62, 0.09, BACK)
		add(pectoral, pf, 0)
		local pelvic, vf = fin(Vector3.new(side * 0.3, -0.38, 0.95), Vector3.new(side * 0.66, -0.62, 1.45), 0.3, 0.06, SIDE)
		add(pelvic, vf, 0)
	end
	-- the tall back fin: its slope leads, the tall side trails
	local dorsal = plain("WedgePart", Vector3.new(0.12, 1.15, 1.2), BACK)
	add(dorsal, at(0, 1.18, -0.05), 0)
	local hook = ellipsoid(Vector3.new(0.1, 0.42, 0.38), BACK) -- the back fin's rounded tip
	add(hook, at(0, 1.66, 0.45), 0)

	-- tail stock (group 1), placed from hinge 1
	add(ellipsoid(Vector3.new(0.78, 0.88, 2.3), SIDE), at(0, 0.05, 0.85), 1)
	add(ellipsoid(Vector3.new(0.56, 0.55, 2.1), BACK), at(0, 0.22, 0.8), 1)
	add(ellipsoid(Vector3.new(0.6, 0.5, 1.8), BELLY), at(0, -0.17, 0.7), 1)
	local second = plain("WedgePart", Vector3.new(0.06, 0.3, 0.4), BACK)
	add(second, at(0, 0.48, 0.75), 1)
	local anal = plain("WedgePart", Vector3.new(0.05, 0.25, 0.35), SIDE)
	add(anal, at(0, -0.48, 0.8) * CFrame.Angles(0, 0, math.pi), 1)

	-- tail fin (group 2), placed from hinge 2: a tall upper lobe and a shorter lower one
	local upper, uf = fin(Vector3.new(0, 0.02, 0.0), Vector3.new(0, 1.3, 1.15), 0.42, 0.09, BACK, Vector3.xAxis)
	add(upper, uf, 2)
	local lower, lf = fin(Vector3.new(0, -0.02, 0.0), Vector3.new(0, -0.72, 0.7), 0.36, 0.08, BACK, Vector3.xAxis)
	add(lower, lf, 2)

	model.Parent = folder
	return { model = model, pieces = pieces }
end

function SharkView.new(sharks: { any }, parent: Instance): SharkView
	local folder = Instance.new("Folder")
	folder.Name = "Sharks"
	local ones = {}
	local parts = {}
	for i = 1, #sharks do
		local one = build(folder, i)
		table.insert(ones, one)
		for _, piece in one.pieces do
			table.insert(parts, piece.part)
		end
	end
	folder.Parent = parent
	return setmetatable({ folder = folder, ones = ones, parts = parts, frames = table.create(#parts, HIDDEN) }, SharkView)
end

-- eyeX/Y/Z: the camera in metres; sharks farther than 125 m are not drawn, nor any while `shown`
-- is false (behind the title they would hang still: nothing moves them until the game starts)
function SharkView.update(self: SharkView, sharks: { any }, eyeX: number, eyeY: number, eyeZ: number, shown: boolean)
	local n = 0
	for i, one in self.ones do
		local shark = sharks[i]
		local far = not shown
			or shark == nil
			or (shark.x - eyeX) ^ 2 + (shark.y - eyeY) ^ 2 + (shark.z - eyeZ) ^ 2 > 125 * 125
		if far then
			for _ in one.pieces do
				n += 1
				self.frames[n] = HIDDEN
			end
		else
			local d = math.clamp(shark.dy, -1, 1)
			local stagger = if shark.stun > 0 then math.sin(shark.stun * 11.0) * 0.7 else 0
			local root =
				World.frame(shark.x, shark.y, shark.z, math.atan2(shark.dx, shark.dz), math.asin(d), stagger + shark.roll)
			local amp = if shark.mood == "chase" then 0.3 else 0.2
			local a1 = math.sin(shark.phase) * amp
			local a2 = math.sin(shark.phase - 0.9) * amp * 1.6
			local body = root * CFrame.Angles(0, -a1 * 0.15, 0)
			local hinge1 = root * CFrame.new(HINGE1 * S) * CFrame.Angles(0, a1, 0)
			local hinge2 = hinge1 * CFrame.new(HINGE2 * S) * CFrame.Angles(0, a2, 0)
			for _, piece in one.pieces do
				n += 1
				local base = if piece.group == 0 then body elseif piece.group == 1 then hinge1 else hinge2
				self.frames[n] = base * piece.at
			end
		end
	end
	workspace:BulkMoveTo(self.parts, self.frames, Enum.BulkMoveMode.FireCFrameChanged)
end

function SharkView.destroy(self: SharkView)
	self.folder:Destroy()
end

return SharkView
