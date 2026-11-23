--!strict
-- The shape of one ocean's bed and islands, ported from the Godot game's scripts/sea_floor.gd.
-- Drawing (the terrain) and collisions both use height(). Godot's FastNoiseLite is replaced by
-- Luau's math.noise, so the small bumps differ; the big shapes are the kit's formulas.

local Rules = if script then require(script.Parent.Rules) else require("./Rules")
local Data = if script then require(script.Parent.Data) else require("./Data")
local Rng = if script then require(script.Parent.Rng) else require("./Rng")

local SEA = Rules.SEA_LEVEL
local WORLD = Rules.WORLD_RADIUS
local WALL_FOOT = 1.40 -- in island radii
local smoothstep = Rules.smoothstep
local TAU = Rules.TAU

export type Island = {
	cx: number,
	cz: number,
	radius: number,
	top: number,
	p1: number,
	p2: number,
	reachSquared: number,
}

local SeaFloor = {}
SeaFloor.__index = SeaFloor

export type SeaFloor = typeof(setmetatable(
	{} :: {
		ocean: number,
		icy: boolean,
		islands: { Island },
		shift: number,
	},
	SeaFloor
))

-- fractal noise like FastNoiseLite's default (FBM, gain 0.5, lacunarity 2), roughly -1 to 1
local function fbm(x: number, z: number, seed: number, frequency: number, octaves: number): number
	local sum, amp, total, f = 0.0, 1.0, 0.0, frequency
	for _ = 1, octaves do
		sum += math.noise(x * f + 0.37, z * f + 0.71, seed + 0.5) * amp
		total += amp
		amp *= 0.5
		f *= 2.0
	end
	return Rules.clamp(sum / total * 1.8, -1, 1)
end

function SeaFloor.radiusAt(island: Island, angle: number): number
	return island.radius * (1.0 + 0.14 * math.sin(3.0 * angle + island.p1) + 0.08 * math.sin(5.0 * angle + island.p2))
end

-- a point on an island's outline scaled by u (1 = the outline)
function SeaFloor.point(island: Island, angle: number, u: number): (number, number)
	local r = SeaFloor.radiusAt(island, angle) * u
	return island.cx + math.cos(angle) * r, island.cz + math.sin(angle) * r
end

function SeaFloor.new(oceanIndex: number?): SeaFloor
	local ocean = oceanIndex or 0
	local self = setmetatable({
		ocean = ocean,
		icy = Data.oceans[ocean + 1].icy,
		islands = {},
		shift = ocean * 41.0,
	}, SeaFloor)
	self:_makeIslands()
	return self
end

function SeaFloor._makeIslands(self: SeaFloor)
	local rng = Rng.new(4242 + self.ocean * 7919) -- so each ocean always looks the same
	local found = {}
	if self.ocean == 0 then
		for _, place in Data.redSeaIslands do
			table.insert(found, place)
		end
	else
		local wanted = if self.icy then 13 else 10
		for _ = 1, 3000 do
			if #found >= wanted then
				break
			end
			local distance = if #found == 0 then rng:range(78, 98) else rng:range(70, WORLD - 42.0)
			local angle = rng:randf() * TAU
			local radius = if self.icy then rng:range(17, 32) else rng:range(32, 52)
			local x, z = math.cos(angle) * distance, math.sin(angle) * distance
			local clear = true
			for _, other in found do
				local dx, dz = x - other[1], z - other[2]
				if math.sqrt(dx * dx + dz * dz) <= other[3] + radius + 36.0 then
					clear = false
					break
				end
			end
			if clear then
				table.insert(found, { x, z, radius, if self.icy then rng:range(7, 13) else rng:range(3, 6) })
			end
		end
	end
	for _, place in found do
		local radius = place[3]
		table.insert(self.islands, {
			cx = place[1],
			cz = place[2],
			radius = radius,
			top = place[4],
			p1 = rng:randf() * TAU,
			p2 = rng:randf() * TAU,
			reachSquared = (radius * 1.92) ^ 2,
		})
	end
end

function SeaFloor.base(self: SeaFloor, x: number, z: number): number
	x += self.shift
	z -= self.shift * 0.7
	return -24.0 + 3.5 * math.sin(x * 0.025) * math.cos(z * 0.03) + 1.6 * math.sin(x * 0.09 + z * 0.06) + 0.8 * math.cos(
		z * 0.15 - x * 0.05
	)
end

function SeaFloor.islandU(self: SeaFloor, island: Island, x: number, z: number): number
	local dx, dz = x - island.cx, z - island.cz
	local angle = math.atan2(dz, dx)
	local u = math.sqrt(dx * dx + dz * dz) / SeaFloor.radiusAt(island, angle)
	if u > 0.42 then
		-- spurs of reef reaching out, with grooves of sand between them
		local spurs = 0.6 * math.sin(angle * 7.0 + island.p1 + u * 1.5) + 0.4 * math.sin(angle * 13.0 + island.p2 - u * 2.0)
		u += spurs * 0.10 * smoothstep(0.42, 0.85, u)
	end
	-- bays and buttresses, so a reef is not a smooth tower
	return u + fbm(x, z, 12 + self.ocean, 0.022, 1) * 0.17 * smoothstep(0.34, 0.62, u)
end

function SeaFloor.height(self: SeaFloor, x: number, z: number): number
	local h = self:survey(x, z)
	return h
end

-- the height, and how far out on the nearest island (in island radii; 1.5 in open sea)
function SeaFloor.survey(self: SeaFloor, x: number, z: number): (number, number)
	local bed = self:base(x, z)
	local fromMiddle = x * x + z * z
	if fromMiddle > WORLD * WORLD then
		bed -= 26.0 * smoothstep(WORLD + 15.0, WORLD + 160.0, math.sqrt(fromMiddle)) -- drop-off into the blue
	end
	local h = bed
	local nearest = 1.5
	for _, island in self.islands do
		local dx, dz = x - island.cx, z - island.cz
		if dx * dx + dz * dz <= island.reachSquared then
			local u = self:islandU(island, x, z)
			nearest = math.min(nearest, u)
			if u < WALL_FOOT then
				h = math.max(h, self:_profile(island, u, bed, math.atan2(dz, dx)))
			end
		end
	end
	local rough = 0.6
	if nearest < WALL_FOOT then
		local wall = smoothstep(0.58, 0.70, nearest) * (1.0 - smoothstep(0.95, WALL_FOOT, nearest))
		if wall > 0.0 then
			h += 0.5 * math.sin(h * 0.9) * wall -- ledges
		end
		rough = Rules.lerp(0.35 + 1.5 * wall, 0.6, smoothstep(1.0, WALL_FOOT, nearest))
		if self.icy and nearest < 0.36 then
			rough = 2.6 * (1.0 - smoothstep(0.24, 0.36, nearest)) + 0.3 -- jagged ice
		end
	end
	return h + fbm(x, z, 7 + self.ocean, 0.075, 3) * rough, nearest
end

-- how much of a rocky cliff this side of an island has, 0 to 1; other sides keep their beach
function SeaFloor.cliffAt(self: SeaFloor, island: Island, angle: number): number
	if self.icy then
		return 0.0
	end
	local shape = 0.55 * math.sin(angle * 2.0 + island.p1 * 3.0) + 0.45 * math.sin(angle * 3.0 + island.p2 * 2.0)
	return smoothstep(0.35, 0.75, shape)
end

function SeaFloor._profile(self: SeaFloor, island: Island, u: number, bed: number, angle: number): number
	if u < 0.36 and not self.icy then
		local beach = if u < 0.28
			then SEA + 0.6 + island.top * (1.0 - u * u / 0.0784)
			else SEA + 0.6 - 4.1 * (u - 0.28) / 0.08
		local cliff = self:cliffAt(island, angle)
		if cliff <= 0.0 then
			return beach
		end
		-- a rocky headland: high ground runs out to the water and drops steeply; the reef below is unchanged
		local top = SEA + 1.8 + island.top * 0.75
		local ragged = u
			+ 0.022 * math.sin(angle * 17.0 + island.p1 * 5.0)
			+ 0.014 * math.sin(angle * 31.0 + island.p2 * 3.0)
			+ 0.008 * math.sin(angle * 57.0)
		local face = SEA - 3.5 + (top - SEA + 3.5) * (1.0 - smoothstep(0.282, 0.335, ragged))
		local high = math.max(
			beach,
			face - u * 3.0 - 0.6 * (0.5 + 0.5 * math.sin(angle * 9.0 + island.p2)) * smoothstep(0.2, 0.3, u)
		)
		return Rules.lerp(beach, high, cliff)
	end
	if u < 0.28 then
		if self.icy then
			return SEA + 0.6 + island.top * (1.0 - (u / 0.28) ^ 5) -- flat tops and cliffs
		end
		return SEA + 0.6 + island.top * (1.0 - u * u / 0.0784)
	end
	if u < 0.36 then
		return SEA + 0.6 - 4.1 * (u - 0.28) / 0.08
	end
	if u < 0.6 then
		return SEA - 3.5 - 3.0 * (u - 0.36) / 0.24
	end
	-- steep at the top, a terrace part of the way down, then a long slope of rubble
	local out = (u - 0.6) / (WALL_FOOT - 0.6)
	local down = 1.0 - (1.0 - out) ^ 2.3
	down -= 0.11 * smoothstep(0.08, 0.22, out) * (1.0 - smoothstep(0.22, 0.5, out))
	return SEA - 6.5 + (bed - SEA + 6.5) * down
end

-- the nearest island to a point, and the angle from its centre (for choosing terrain materials)
function SeaFloor.nearestIsland(self: SeaFloor, x: number, z: number): (Island?, number)
	local best: Island? = nil
	local closest = math.huge
	for _, island in self.islands do
		local d = ((island.cx - x) ^ 2 + (island.cz - z) ^ 2) / (island.radius * island.radius)
		if d < closest then
			closest = d
			best = island
		end
	end
	if best then
		return best, math.atan2(z - best.cz, x - best.cx)
	end
	return nil, 0
end

-- islands are walls: slide a point outward until the water is deep enough for it
function SeaFloor.pushOut(
	self: SeaFloor,
	px: number,
	py: number,
	pz: number,
	clearance: number,
	limit: number
): (number, number, number)
	if self:height(px, pz) + clearance <= limit then
		return px, py, pz
	end
	local island: Island? = nil
	local closest = math.huge
	for _, other in self.islands do
		local d = ((other.cx - px) ^ 2 + (other.cz - pz) ^ 2) / (other.radius * other.radius)
		if d < closest then
			closest = d
			island = other
		end
	end
	if island == nil or (island.cx - px) ^ 2 + (island.cz - pz) ^ 2 > island.reachSquared then
		return px, py, pz -- shallow open sea
	end
	local ax, az = px - island.cx, pz - island.cz
	local inner = math.sqrt(ax * ax + az * az)
	if inner > 0.001 then
		ax, az = ax / inner, az / inner
	else
		ax, az = 0, -1
	end
	local outer = inner
	for _ = 1, 220 do
		outer += 0.5
		if self:height(island.cx + ax * outer, island.cz + az * outer) + clearance <= limit then
			break
		end
		inner = outer
	end
	for _ = 1, 5 do
		local mid = (inner + outer) * 0.5
		if self:height(island.cx + ax * mid, island.cz + az * mid) + clearance <= limit then
			outer = mid
		else
			inner = mid
		end
	end
	return island.cx + ax * outer, py, island.cz + az * outer
end

-- a point in open water between nearest and farthest metres from `around`, deeper than deeperThan
function SeaFloor.freePoint(
	self: SeaFloor,
	rng: Rng.Rng,
	nearest: number,
	farthest: number,
	aroundX: number?,
	aroundZ: number?,
	deeperThan: number?
): (number, number)
	local ox, oz = aroundX or 0, aroundZ or 0
	local deeper = deeperThan or -14.0
	local x, z = 0, 0
	local fx, fz: number? = nil, nil
	for _ = 1, 80 do
		local angle = rng:randf() * TAU
		local r = rng:range(nearest, farthest)
		x, z = ox + math.cos(angle) * r, oz + math.sin(angle) * r
		local len = math.sqrt(x * x + z * z)
		if len > WORLD - 6.0 then
			x, z = x / len * (WORLD - 6.0), z / len * (WORLD - 6.0)
		end
		local h = self:height(x, z)
		if h < deeper then
			return x, z
		end
		if h < SEA - 12.0 then
			fx, fz = x, z
		end
	end
	if fx and fz then
		return fx, fz
	end
	return x, z
end

return SeaFloor
