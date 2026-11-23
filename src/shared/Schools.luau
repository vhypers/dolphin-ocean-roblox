--!strict
-- Schools of fish: where they live and how they swim. Ported from the fish part of the Godot
-- game's scripts/life.gd (other creatures arrive in later steps).

local Rules = if script then require(script.Parent.Rules) else require("./Rules")
local Data = if script then require(script.Parent.Data) else require("./Data")
local Rng = if script then require(script.Parent.Rng) else require("./Rng")
local SeaFloor = if script then require(script.Parent.SeaFloor) else require("./SeaFloor")

local SEA = Rules.SEA_LEVEL
local WORLD = Rules.WORLD_RADIUS

local Schools = {}
Schools.__index = Schools

Schools.FISH_PER_SCHOOL = 16
Schools.SEE = 125.0
Schools.SWIMMABLE = 45.0 -- fish this near her are kept out of the rock
Schools.FISH_OFF_ROCK = 1.8 -- as low as her snout can reach

export type Fish = {
	ox: number, -- place in the school
	oy: number,
	oz: number,
	phase: number,
	alive: boolean,
	x: number,
	y: number,
	z: number,
	heading: number,
}

export type School = {
	species: number,
	island: SeaFloor.Island?, -- nil for schools that roam
	cx: number,
	cy: number,
	cz: number,
	heading: number,
	targetY: number,
	alive: number,
	timer: number,
	spread: number,
	side: number,
	orbit: number,
	seed: number,
	shown: boolean,
	fish: { Fish },
}

export type Schools = typeof(setmetatable(
	{} :: {
		bed: SeaFloor.SeaFloor,
		rng: Rng.Rng,
		time: number,
		list: { School },
	},
	Schools
))

function Schools.new(bed: SeaFloor.SeaFloor, ocean: number, seed: number?): Schools
	local self = setmetatable({
		bed = bed,
		rng = Rng.new(seed or 99),
		time = 0,
		list = {},
	}, Schools)
	self:_make(ocean)
	return self
end

function Schools._make(self: Schools, ocean: number)
	local info = Data.oceans[ocean + 1]
	local reef, open = info.reef, info.open
	local reefNext, openNext = 0, 0
	local rng = self.rng
	for _, home in Data.schoolHomes do
		local island: SeaFloor.Island? = nil
		local species
		if home >= 0 and #self.bed.islands > 0 then
			island = self.bed.islands[(home % #self.bed.islands) + 1]
			species = reef[(reefNext % #reef) + 1]
			reefNext += 1
		else
			species = open[(openNext % #open) + 1]
			openNext += 1
		end
		local school: School = {
			species = species,
			island = island,
			cx = 0,
			cy = 0,
			cz = 0,
			heading = 0,
			targetY = 0,
			alive = 0,
			timer = 0,
			spread = 1,
			side = if rng:randf() < 0.5 then 1 else -1,
			orbit = rng:range(0.67, 0.8),
			seed = rng:randf() * 9.0,
			shown = true,
			fish = {},
		}
		for _ = 1, Schools.FISH_PER_SCHOOL do
			table.insert(school.fish, {
				ox = rng:range(-3, 3),
				oy = rng:range(-1.4, 1.4),
				oz = rng:range(-3.5, 3.5),
				phase = rng:randf() * Rules.TAU,
				alive = true,
				x = 0,
				y = 0,
				z = 0,
				heading = 0,
			})
		end
		table.insert(self.list, school)
		self:place(school, nil, nil)
	end
end

-- awayX/awayZ: keep the new place at least 45 m from there (where she is), if given
function Schools.place(self: Schools, school: School, awayX: number?, awayZ: number?)
	local rng = self.rng
	local ax, az = 0, 0
	for _ = 1, 30 do
		if school.island then
			ax, az = SeaFloor.point(school.island, rng:randf() * Rules.TAU, school.orbit)
		else
			ax, az = self.bed:freePoint(rng, 20, WORLD - 15.0)
		end
		if awayX == nil or awayZ == nil or math.sqrt((ax - awayX) ^ 2 + (az - awayZ) ^ 2) > 45.0 then
			break
		end
	end
	local ground = self.bed:height(ax, az)
	if school.island then
		school.targetY = rng:range(math.max(ground + 3.5, SEA - 13.0), SEA - 5.0)
	else
		school.targetY = rng:range(ground + 4.0, SEA - 4.0)
	end
	school.cx, school.cy, school.cz = ax, school.targetY, az
	school.heading = rng:randf() * Rules.TAU
	school.alive = #school.fish
	school.spread = 1.0
	school.timer = 0.0
	for _, fish in school.fish do
		fish.alive = true
	end
	self:_pose(school, true)
end

function Schools.advance(self: Schools, dt: number, px: number, py: number, pz: number)
	self.time += dt
	for _, school in self.list do
		self:_move(school, dt, px, py, pz)
	end
end

function Schools._move(self: Schools, school: School, dt: number, px: number, py: number, pz: number)
	if school.alive <= 0 then
		school.timer -= dt
		school.shown = false
		if school.timer <= 0.0 then
			self:place(school, px, pz)
		end
		return
	end
	local away = math.sqrt((school.cx - px) ^ 2 + (school.cy - py) ^ 2 + (school.cz - pz) ^ 2)
	local speed = 2.6
	local cx, cy, cz = school.cx, school.cy, school.cz
	if away < 12.0 then
		speed = 7.5
		school.heading += Rules.angleDifference(school.heading, math.atan2(cx - px, cz - pz)) * math.min(1.0, 2.2 * dt)
	elseif school.island then
		local island = school.island
		local dx, dz = cx - island.cx, cz - island.cz
		local off = Rules.clamp((math.sqrt(dx * dx + dz * dz) - island.radius * school.orbit) / 8.0, -1.0, 1.0)
		local wanted = math.atan2(dx, dz) + school.side * (math.pi / 2.0 + off * 0.9)
		school.heading += Rules.angleDifference(school.heading, wanted) * math.min(1.0, 1.2 * dt)
	else
		school.heading += math.sin(self.time * 0.3 + school.seed) * 0.5 * dt
	end
	cx += math.sin(school.heading) * speed * dt
	cz += math.cos(school.heading) * speed * dt
	cy += (school.targetY - cy) * 0.4 * dt + math.sin(self.time * 0.4 + school.seed) * 0.4 * dt
	cx, cy, cz = self.bed:pushOut(cx, cy, cz, 3.5, SEA - 3.0)
	cy = Rules.clamp(cy, self.bed:height(cx, cz) + 3.0, SEA - 3.0)
	if math.sqrt(cx * cx + cz * cz) > WORLD - 8.0 then
		school.heading = math.atan2(-cx, -cz)
	end
	school.cx, school.cy, school.cz = cx, cy, cz
	school.spread += ((if away < 14.0 then 1.9 else 1.0) - school.spread) * math.min(1.0, 2.0 * dt)
	school.shown = away < Schools.SEE
	if school.shown then
		self:_pose(school, away < Schools.SWIMMABLE)
	end
end

function Schools._pose(self: Schools, school: School, careful: boolean)
	local c, s = math.cos(school.heading), math.sin(school.heading)
	for _, fish in school.fish do
		local a = self.time * 1.3 + fish.phase
		local ox = (fish.ox + math.sin(a * 0.7) * 0.4) * school.spread
		local oz = (fish.oz + math.cos(a * 0.5) * 0.5) * school.spread
		local x = school.cx + ox * c + oz * s
		local y = school.cy + fish.oy * school.spread + math.sin(a) * 0.25
		local z = school.cz - ox * s + oz * c
		if careful then
			local lowest = self.bed:height(x, z) + Schools.FISH_OFF_ROCK
			if lowest > SEA - 1.2 then
				-- too shallow there: tuck in with the others
				x = x + (school.cx - x) * 0.9
				y = y + (school.cy - y) * 0.9
				z = z + (school.cz - z) * 0.9
				lowest = self.bed:height(x, z) + Schools.FISH_OFF_ROCK
			end
			y = math.min(math.max(y, lowest), SEA - 1.0)
		end
		fish.x, fish.y, fish.z = x, y, z
		fish.heading = school.heading + math.sin(a * 0.9) * 0.22
	end
end

return Schools
