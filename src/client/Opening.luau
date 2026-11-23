--!strict
-- The story before the game, told in the Red Sea with the game's own models: about 53 seconds,
-- shot for shot as in the Godot game's scripts/opening.gd. Her pod, her curiosity, the net, the
-- fishermen, the storm, the beach, Sam, and her release. Space, Enter or a click skips it.
-- Works in metres (Godot's coordinates, sea level 18); World turns them into studs.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Spring = ReplicatedStorage:WaitForChild("Spring")
local Rules = require(Spring:WaitForChild("Rules"))
local World = require(script.Parent:WaitForChild("World"))
local DolphinView = require(script.Parent:WaitForChild("DolphinView"))
local Shapes = require(script.Parent:WaitForChild("Shapes"))
local Effects = require(script.Parent:WaitForChild("Effects"))

local Opening = {}
Opening.__index = Opening

local SEA = Rules.SEA_LEVEL
local POD = 5
local FISH = 30
local TAU = Rules.TAU
local HIDDEN = CFrame.new(0, -400, 0)

-- start time, length, caption, time of day (seconds into a 120 s day), weather (0 calm, 1 cloudy, 2 storm)
local SHOTS: { { any } } = {
	{ 0.0, 7.0, "This is Spring. She lived with her family in a warm, quiet bay.", 22.0, 0 },
	{ 7.0, 6.0, "Every day was the same: eat, sleep, hunt, and eat again.", 30.0, 0 },
	{ 13.0, 6.0, "But Spring was the most curious dolphin of them all.", 38.0, 0 },
	{ 19.0, 6.0, "One day she swam too close to a fishing net and got caught.", 40.0, 0 },
	{ 25.0, 6.5, "The fishermen set her free, but her tail was badly hurt.", 44.0, 1 },
	{ 31.5, 6.5, "Too weak to swim, she was carried by the waves to a beach.", 72.0, 2 },
	{ 38.0, 7.0, "There a boy named Sam found her and called the rescuers.", 20.0, 0 },
	{ 45.0, 8.0, "Weeks later, Sam set her free. Now she must find her family. Sam's boat will follow her.", 26.0, 0 },
}
Opening.LENGTH = 53.0

type FishPiece = { body: BasePart, tail: BasePart }

export type Opening = typeof(setmetatable(
	{} :: {
		time: number,
		shot: number,
		caption: string,
		fade: number,
		dayTime: number,
		eye: CFrame,
		fov: number,
		folder: Folder,
		bed: any,
		spring: DolphinView.DolphinView,
		pod: { DolphinView.DolphinView },
		fish: { FishPiece },
		boat: Shapes.Thing,
		net: Shapes.Thing,
		samBoat: Shapes.Thing,
		samStanding: Shapes.Thing,
		samKneeling: Shapes.Thing,
		rescuers: { Shapes.Thing },
		splashed: boolean,
		bubbleAt: number,
		weather: number,
		kept: { [string]: any },
		-- places in the Red Sea, worked out from its first island (metres)
		out: Vector3,
		along: Vector3,
		bay: Vector3,
		ball: Vector3,
		netAt: Vector3,
		shallow: Vector3,
		shore: Vector3,
		dry: Vector3,
	},
	Opening
))

local function smoothstep(a: number, b: number, x: number): number
	return Rules.smoothstep(a, b, x)
end

-- a vector turned about the vertical (like Godot's rotated(UP, angle))
local function turned(v: Vector3, angle: number): Vector3
	local x, y, z = Rules.turn(v.X, v.Y, v.Z, angle)
	return Vector3.new(x, y, z)
end

-- an offset (x right, y up, z ahead) in the frame of a flat heading, as Godot's _basis(f) * v
local function basis(forward: Vector3, v: Vector3): Vector3
	local f = Vector3.new(forward.X, 0, forward.Z).Unit
	return Vector3.new(f.Z, 0, -f.X) * v.X + Vector3.yAxis * v.Y + f * v.Z
end

local function ellipsoid(size: Vector3, color: Color3, parent: Instance): BasePart
	local part = Instance.new("Part")
	part.Size = size * World.S
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CFrame = HIDDEN
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	part.Parent = parent
	return part
end

function Opening.new(parent: Instance, bed: any): Opening
	local folder = Instance.new("Folder")
	folder.Name = "Opening"
	folder.Parent = parent
	local pod = {}
	for i = 0, POD - 1 do
		table.insert(pod, DolphinView.new(folder, "OpeningPod" .. i, 0.9, 0.85 + 0.05 * i))
	end
	local fish = {}
	for _ = 1, FISH do
		table.insert(fish, {
			body = ellipsoid(Vector3.new(0.22, 0.42, 1.2), Color3.fromHex("ff8a2a"), folder),
			tail = ellipsoid(Vector3.new(0.06, 0.34, 0.4), Color3.fromHex("ff6a3a"), folder),
		})
	end
	local samStanding = Shapes.new("Sam", folder)
	Shapes.person(samStanding, CFrame.identity, 1.32, Shapes.SAM, false, true)
	local samKneeling = Shapes.new("SamKneeling", folder)
	Shapes.person(samKneeling, CFrame.identity, 1.32, Shapes.SAM, true, true)
	local rescuers = {}
	for i = 0, 1 do
		local person = Shapes.new("Rescuer" .. i, folder)
		Shapes.person(person, CFrame.identity, 1.72 + 0.06 * i, Shapes.rescuerLook(i))
		table.insert(rescuers, person)
	end
	local self = setmetatable({
		time = 0,
		shot = -1,
		caption = "",
		fade = 0,
		dayTime = 22,
		eye = CFrame.identity,
		fov = 52,
		folder = folder,
		bed = bed,
		spring = DolphinView.new(folder, "OpeningSpring"),
		pod = pod,
		fish = fish,
		boat = Shapes.boat(folder, "fishing"),
		net = Shapes.net(folder),
		samBoat = Shapes.boat(folder, "rescue"),
		samStanding = samStanding,
		samKneeling = samKneeling,
		rescuers = rescuers,
		splashed = false,
		bubbleAt = 0,
		weather = 0,
		kept = {},
		out = Vector3.zero,
		along = Vector3.zero,
		bay = Vector3.zero,
		ball = Vector3.zero,
		netAt = Vector3.zero,
		shallow = Vector3.zero,
		shore = Vector3.zero,
		dry = Vector3.zero,
	}, Opening)
	self:_findPlaces()
	self:_keepWeather()
	self:_hideAll()
	return self
end

function Opening.skip(self: Opening)
	self.time = Opening.LENGTH
end

-- moves everything on; returns false once the story is over
function Opening.advance(self: Opening, dt: number): boolean
	self.time += dt
	if self.time >= Opening.LENGTH then
		return false
	end
	local now = 1
	for i, shot in SHOTS do
		if self.time >= shot[1] then
			now = i
		end
	end
	local shot = SHOTS[now]
	local t = self.time - shot[1]
	if now ~= self.shot then
		self.shot = now
		self.splashed = false
		self.bubbleAt = 0
		self.caption = shot[3]
		self:_hideAll()
		self:_setWeather(shot[5])
	end
	if now == 1 then
		self:_swimTogether(t)
	elseif now == 2 then
		self:_hunt(t)
	elseif now == 3 then
		self:_curious(t)
	elseif now == 4 then
		self:_caught(t)
	elseif now == 5 then
		self:_freed(t)
	elseif now == 6 then
		self:_storm(t)
	elseif now == 7 then
		self:_beach(t)
	else
		self:_release(t)
	end
	self.fade = math.clamp(math.min(t * 2.0, (shot[2] - t) * 2.0), 0.0, 1.0)
	self.dayTime = shot[4] + t * 0.4
	return true
end

function Opening.destroy(self: Opening)
	self:_setWeather(0)
	self.folder:Destroy()
end

-- ---------- the shots ----------

function Opening._swimTogether(self: Opening, t: number)
	local lead = self.bay + self.along * (t - 3.5) * 5.0
	self:_pose(self.spring, lead, self.along, t * 9.0, 0.19, 0, false)
	for i = 0, POD - 1 do
		local slot = Rules.POD_SLOTS[i + 1]
		local at = lead + basis(self.along, Vector3.new(slot[1], slot[2], slot[3]) * 1.2) + Vector3.new(0, math.sin(t * 1.3 + i) * 0.4, 0)
		self:_pose(self.pod[i + 1], at, self.along, t * 9.0 + i * 1.7, 0.19, 0, false)
	end
	self:_look(lead - self.out * 11.0 + Vector3.new(0, 1.6, 0) - self.along * 3.0, lead + self.along * 2.5)
end

function Opening._hunt(self: Opening, t: number)
	local parts, frames = {}, {}
	for i = 0, FISH - 1 do
		local a = t * 2.2 + i * TAU / FISH
		local r = 2.0 + 0.8 * math.sin(i * 1.7)
		local at = self.ball + Vector3.new(math.cos(a) * r, math.sin(i * 2.3 + t) * 1.2, math.sin(a) * r)
		local root = CFrame.new(World.point(at.X, at.Y, at.Z)) * CFrame.Angles(0, -a + math.pi, 0)
		local one = self.fish[i + 1]
		table.insert(parts, one.body)
		table.insert(frames, root)
		table.insert(parts, one.tail)
		table.insert(frames, root * CFrame.Angles(0, math.sin(t * 14 + i) * 0.5, 0) * CFrame.new(0, 0, 0.6 * World.S))
	end
	workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	local dolphins = { self.spring }
	for _, mate in self.pod do
		table.insert(dolphins, mate)
	end
	for i, node in dolphins do
		local k = i - 1
		local speed = 0.55 + 0.08 * k
		local a = t * speed + k * TAU / #dolphins
		local r = 7.0 + 1.5 * math.sin(t * 1.4 + k)
		local at = self.ball + Vector3.new(math.cos(a) * r, math.sin(t * 0.9 + k) * 2.0, math.sin(a) * r)
		self:_pose(node, at, Vector3.new(-math.sin(a), 0, math.cos(a)), t * 11.0 + k, 0.24, 0.35, false)
	end
	self:_look(self.ball - self.out * 15.0 + Vector3.new(0, 3.5, 0), self.ball)
end

function Opening._curious(self: Opening, t: number)
	self:_showBoat(self.netAt.Y, t)
	local share = smoothstep(0.0, 6.0, t)
	local from = self.ball + self.out * 3.0
	local to = self.netAt - self:_netSide() * 4.0
	local at = from:Lerp(to, share) + Vector3.new(0, math.sin(t * 2.0) * 0.3, 0)
	local heading = (to - from).Unit
	self:_pose(self.spring, at, heading, t * 7.0, 0.17, math.sin(t * 1.5) * 0.15, false)
	-- her family swims on without her
	for i = 0, POD - 1 do
		local slot = Rules.POD_SLOTS[i + 1]
		local away = self.ball
			+ self.along * (8.0 + t * 6.0)
			+ basis(self.along, Vector3.new(slot[1], slot[2], slot[3]) * 1.2)
			- self.out * 6.0
		self:_pose(self.pod[i + 1], away, self.along, t * 9.0 + i, 0.19, 0, false)
	end
	self:_look(at - heading * 7.0 + Vector3.new(0, 2.0, 0) + self.along * 1.5, at:Lerp(self.netAt, 0.5))
end

function Opening._caught(self: Opening, t: number)
	self:_showBoat(self.netAt.Y, t)
	local side = self:_netSide()
	local struggle = math.sin(t * 9.0)
	local at = self.netAt - side * 1.1 + Vector3.new(math.sin(t * 4.3) * 0.4, -0.5 + math.sin(t * 3.1) * 0.2, 0)
	self:_pose(self.spring, at, turned(side, 0.4 * struggle), t * 16.0, 0.4, 0.6 * struggle, false)
	if t >= self.bubbleAt then
		self.bubbleAt = t + 0.7
		Effects.play("bubbles", at.X, at.Y + 0.5, at.Z, 10, self.folder)
	end
	self:_look(at - side * 6.0 + basis(side, Vector3.new(3, 0, 0)) + Vector3.new(0, 1.0, 0), at)
end

function Opening._freed(self: Opening, t: number)
	local lift = smoothstep(0.5, 3.0, t)
	local netY = Rules.lerp(self.netAt.Y, SEA - 4.6, lift) -- the top of the net comes just out of the water
	local boat = self:_showBoat(netY, t, -2.6 + math.sin(t * 6.0) * 0.5)
	local side = self:_netSide()
	if t < 3.6 then
		local at = Vector3.new(self.netAt.X, math.min(netY + 4.6, SEA + 0.1), self.netAt.Z) - side * 1.2
		self:_pose(self.spring, at, side, t * 12.0, 0.3, math.sin(t * 7.0) * 0.4, true)
	else
		local sink = t - 3.6
		local at = self.netAt - side * (2.5 + sink * 1.2)
		at = Vector3.new(at.X, SEA - 0.3 - math.min(sink * 1.5, 1.4), at.Z)
		self:_pose(self.spring, at, -side, t * 4.0, 0.08, 0.4, true)
		if not self.splashed then
			self.splashed = true
			Effects.play("splash", at.X, SEA, at.Z, 1, self.folder)
		end
	end
	self:_look(boat - side * 16.0 + basis(side, Vector3.new(9, 0, 0)) + Vector3.new(0, 3.0, 0), Vector3.new(boat.X, SEA, boat.Z) - side * 2.0)
end

function Opening._storm(self: Opening, t: number)
	local start = self.shallow - self.out * 70.0
	local finish = self.shallow - self.out * 40.0
	local at = start:Lerp(finish, t / 6.5)
	at = Vector3.new(at.X, SEA - 0.35 + Rules.waveHeight(at.X, at.Z, self.time, 2.0) * 0.8, at.Z)
	self:_pose(self.spring, at, turned(self.out, math.sin(t * 0.7) * 0.5), t * 2.0, 0.05, 0.5 + math.sin(t * 1.3) * 0.2, true)
	local eye = at - self.out * 9.0 + basis(self.out, Vector3.new(4, 0, 0))
	self:_look(Vector3.new(eye.X, SEA + 1.4, eye.Z), at + self.out * 6.0)
end

function Opening._beach(self: Opening, t: number)
	local bed = self.bed
	self:_pose(self.spring, self.shallow, self.along, t * 1.5, 0.03, 0.55, true)
	local knees = self.shore
	local facing = math.atan2(self.out.X, self.out.Z)
	local run = smoothstep(0.0, 3.0, t)
	if t < 3.0 then
		local p = self.dry:Lerp(knees, run)
		p = Vector3.new(p.X, bed:height(p.X, p.Z) + math.abs(math.sin(t * 9.0)) * 0.08, p.Z)
		Shapes.place(self.samStanding, World.frame(p.X, p.Y, p.Z, facing, 0, 0))
		Shapes.hide(self.samKneeling)
	else
		Shapes.hide(self.samStanding)
		local y = math.max(bed:height(knees.X, knees.Z), SEA - 0.2)
		Shapes.place(self.samKneeling, World.frame(knees.X, y, knees.Z, facing, 0, 0))
	end
	for i = 0, 1 do
		local person = self.rescuers[i + 1]
		local walk = smoothstep(2.5 + i * 0.6, 6.5, t)
		if walk > 0.0 then
			local from = self.dry - self.along * (4.0 + i * 3.0) - self.out * 2.0
			local to = self.shore + self.along * (2.2 + i * 1.6) - self.out * 0.3
			local p = from:Lerp(to, walk)
			local y = math.max(bed:height(p.X, p.Z), SEA - 0.3) + (if walk < 1.0 then math.abs(math.sin(t * 7.0 + i)) * 0.06 else 0.0)
			local way = to - from
			local yaw = if walk < 1.0 then math.atan2(way.X, way.Z) else facing + math.pi
			Shapes.place(person, World.frame(p.X, y, p.Z, yaw, 0, 0))
		end
	end
	local eye = self.shallow - self.out * 9.0 + self.along * 3.0
	self:_look(Vector3.new(eye.X, SEA + 1.7, eye.Z), (self.shallow + self.shore) * 0.5 + Vector3.new(0, 0.6, 0))
end

function Opening._release(self: Opening, t: number)
	local boat = Vector3.new(self.bay.X, SEA + Rules.waveHeight(self.bay.X, self.bay.Z, self.time, 1.0) * 0.85, self.bay.Z)
	self.samBoat.angles[1] = -2.6 + math.sin(t * 9.0) * 0.6
	self.samBoat.angles[2] = -2.6 + math.sin(t * 9.0 + 1) * 0.6
	Shapes.place(self.samBoat, World.frame(boat.X, boat.Y, boat.Z, math.atan2(self.along.X, self.along.Z), 0, 0))
	-- she swims off past the camera, with one leap of joy
	local heading = turned(-self.out, 0.9)
	local at = boat + basis(self.along, Vector3.new(3, 0, 0)) + heading * (2.0 + t * 3.4)
	local leap = math.clamp((t - 2.2) / 1.6, 0.0, 1.0)
	local flying = leap > 0.0 and leap < 1.0
	local rise = if flying then 3.0 * math.sin(math.pi * leap) else 0.0
	at = Vector3.new(at.X, SEA - 0.9 + rise - smoothstep(5.0, 8.0, t) * 2.5, at.Z)
	local climb = if flying then 3.0 * math.pi / 1.6 * math.cos(math.pi * leap) / 3.4 else 0.0
	if leap > 0.0 and not self.splashed then
		self.splashed = true
		Effects.play("splash", at.X, SEA, at.Z, 1, self.folder)
	end
	self:_pose(self.spring, at, (heading + Vector3.new(0, climb, 0)).Unit, t * 7.0, if rise > 0.0 then 0.07 else 0.2, 0, true)
	local eye = boat - self.out * 14.0 + self.along * 8.0
	self:_look(Vector3.new(eye.X, SEA + 3.0, eye.Z), boat:Lerp(at, 0.5) + Vector3.new(0, 0.5, 0))
end

-- ---------- helpers ----------

function Opening._findPlaces(self: Opening)
	local bed = self.bed
	local island = bed.islands[1]
	local centre = Vector3.new(island.cx, 0, island.cz)
	self.out = centre.Unit
	self.along = Vector3.new(self.out.Z, 0, -self.out.X)
	self.bay = self.out * 40.0 + Vector3.new(0, 4, 0)
	self.ball = self.bay + self.along * 22.0 + Vector3.new(0, 2, 0)
	local netAt = self.ball + self.along * 26.0 + self.out * 4.0
	self.netAt = Vector3.new(netAt.X, SEA - 7.0, netAt.Z)
	-- walk in from the open sea toward the island's centre to find the shallows and the beach
	local fromX, fromZ = island.cx - self.out.X * island.radius * 1.4, island.cz - self.out.Z * island.radius * 1.4
	local stepX, stepZ = self.out.X * 0.25, self.out.Z * 0.25
	local px, pz = fromX, fromZ
	local wetX, wetZ, edgeX, edgeZ = nil, nil, nil, nil
	for _ = 1, 400 do
		local h = bed:height(px, pz)
		if wetX == nil and h > SEA - 0.65 then
			wetX, wetZ = px, pz
		end
		if h > SEA + 0.15 then
			edgeX, edgeZ = px, pz
			break
		end
		px += stepX
		pz += stepZ
	end
	local wx, wz = wetX or fromX, wetZ or fromZ
	local ex, ez = edgeX or (wx + stepX * 8), edgeZ or (wz + stepZ * 8)
	self.shallow = Vector3.new(wx, bed:height(wx, wz) + 0.45, wz)
	self.shore = Vector3.new(ex, bed:height(ex, ez), ez)
	local dx, dz = ex + stepX * 18, ez + stepZ * 18
	self.dry = Vector3.new(dx, bed:height(dx, dz), dz)
end

function Opening._pose(
	self: Opening,
	node: DolphinView.DolphinView,
	at: Vector3,
	heading: Vector3,
	phase: number,
	stroke: number,
	roll: number,
	hurt: boolean
)
	local d = heading.Unit
	local root = World.frame(at.X, at.Y, at.Z, math.atan2(d.X, d.Z), math.asin(math.clamp(d.Y, -1, 1)), roll)
	node:pose(root, phase, stroke, if hurt then 0.6 else 1.0)
end

function Opening._look(self: Opening, from: Vector3, at: Vector3)
	local eye = World.point(from.X, from.Y, from.Z)
	local target = World.point(at.X, at.Y, at.Z)
	if (target - eye).Magnitude > 0.01 then
		self.eye = CFrame.lookAt(eye, target)
	end
end

function Opening._netSide(self: Opening): Vector3
	return turned(self.out, 0.25)
end

-- the fishing boat beside its net; arms: how the crew's arms are turned. Returns where the boat is.
function Opening._showBoat(self: Opening, netY: number, t: number, arms: number?): Vector3
	local side = self:_netSide()
	local at = Vector3.new(self.netAt.X, SEA, self.netAt.Z) + basis(side, Vector3.new(3, 0, 0))
	at = Vector3.new(at.X, SEA + Rules.waveHeight(at.X, at.Z, self.time, 1.0) * 0.85, at.Z)
	local yaw = math.atan2(side.X, side.Z) + math.pi * 0.5
	for j in self.boat.angles do
		self.boat.angles[j] = arms or -0.2
	end
	Shapes.place(self.boat, World.frame(at.X, at.Y, at.Z, yaw, 0, 0))
	Shapes.place(self.net, World.frame(self.netAt.X, netY, self.netAt.Z, yaw, 0, 0))
	return at
end

function Opening._hideAll(self: Opening)
	for _, thing in { self.boat, self.net, self.samBoat, self.samStanding, self.samKneeling, self.rescuers[1], self.rescuers[2] } do
		Shapes.hide(thing)
	end
	for _, mate in self.pod do
		mate:pose(HIDDEN, 0, 0, 1)
	end
	local parts, frames = {}, {}
	for _, one in self.fish do
		table.insert(parts, one.body)
		table.insert(frames, HIDDEN)
		table.insert(parts, one.tail)
		table.insert(frames, HIDDEN)
	end
	workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
end

-- ---------- weather for the story: clouds before the storm, then the storm ----------

function Opening._keepWeather(self: Opening)
	local terrain = workspace.Terrain
	local clouds = terrain:FindFirstChildOfClass("Clouds")
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	self.kept = {
		waveSize = terrain.WaterWaveSize,
		waveSpeed = terrain.WaterWaveSpeed,
		brightness = Lighting.Brightness,
		exposure = Lighting.ExposureCompensation,
		cover = if clouds then clouds.Cover else nil,
		density = if clouds then clouds.Density else nil,
		cloudColor = if clouds then clouds.Color else nil,
		haze = if atmosphere then atmosphere.Haze else nil,
		airColor = if atmosphere then atmosphere.Color else nil,
	}
end

function Opening._setWeather(self: Opening, weather: number)
	local kept = self.kept
	local terrain = workspace.Terrain
	local clouds = terrain:FindFirstChildOfClass("Clouds")
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local storm, cloudy = weather == 2, weather >= 1
	terrain.WaterWaveSize = if storm then 0.6 else kept.waveSize
	terrain.WaterWaveSpeed = if storm then 22 else kept.waveSpeed
	Lighting.Brightness = if storm then 0.6 elseif cloudy then 1.7 else kept.brightness
	Lighting.ExposureCompensation = if storm then -0.7 elseif cloudy then -0.2 else kept.exposure
	if clouds and kept.cover then
		clouds.Cover = if storm then 1.0 elseif cloudy then 0.8 else kept.cover
		clouds.Density = if storm then 1.0 elseif cloudy then 0.7 else kept.density
		clouds.Color = if storm then Color3.fromRGB(70, 74, 84) elseif cloudy then Color3.fromRGB(200, 205, 212) else kept.cloudColor
	end
	if atmosphere and kept.haze then
		atmosphere.Haze = if storm then 4.0 elseif cloudy then 2.0 else kept.haze
		atmosphere.Color = if storm then Color3.fromRGB(120, 128, 138) else kept.airColor
	end
	self.weather = weather
end

return Opening
