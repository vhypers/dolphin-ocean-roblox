--!strict
-- The rules of one game, without graphics: days, hearts, food, air, fish, her hurt tail, sharks,
-- her Hit, her family who find her one by one and become her pod, the calf, and the rescue in
-- Gentle. Ported from the Godot game's scripts/game_session.gd and the shark parts of
-- scripts/life.gd; Sam, tasks, magic and the other oceans arrive in later steps.

local Rules = if script then require(script.Parent.Rules) else require("./Rules")
local Lang = if script then require(script.Parent.Lang) else require("./Lang")
local Rng = if script then require(script.Parent.Rng) else require("./Rng")
local SeaFloor = if script then require(script.Parent.SeaFloor) else require("./SeaFloor")
local Swimmer = if script then require(script.Parent.Swimmer) else require("./Swimmer")
local Schools = if script then require(script.Parent.Schools) else require("./Schools")

local SEA = Rules.SEA_LEVEL
local MAX_STEP = 1.0 / 60.0
local INF = math.huge
local clamp = Rules.clamp

-- who finds her, in order; her mother is last, on day 30
local FAMILY = {
	"Your cousin found you!",
	"Your aunt found you!",
	"Your best friend found you!",
	"Your big sister found you!",
	"Your grandmother found you!",
	"Your little brother found you!",
	"Your uncle found you!",
}

local Session = {}
Session.__index = Session
Session.FAMILY = FAMILY

export type Message = { kind: string, text: string, big: boolean, seconds: number }
export type Effect = { kind: string, x: number, y: number, z: number, count: number }

-- mood is "patrol", "chase" or "flee"
export type Shark = {
	x: number,
	y: number,
	z: number,
	dx: number, -- the way it swims (unit)
	dy: number,
	dz: number,
	gx: number, -- where it patrols to
	gy: number,
	gz: number,
	mood: string,
	timer: number,
	stun: number,
	kx: number, -- knocked aside by a hit
	ky: number,
	kz: number,
	phase: number,
	circleLeft: number, -- circling her before it comes in, as real sharks do
	circleWay: number,
	roll: number, -- rolled over by a dolphin's hit
	rollSpeed: number,
	burst: number, -- racing away after a hit
}

-- a dolphin of her family: in the pod, the calf, or waiting to be found
export type Mate = {
	x: number,
	y: number,
	z: number,
	ox: number, -- place in the pod, in her own turn
	oy: number,
	oz: number,
	fx: number, -- facing
	fy: number,
	fz: number,
	size: number,
	tint: number,
	phase: number,
	rush: Shark?,
	rushTime: number,
	struck: number, -- seconds since it hit the shark it rushes; -1 before the hit
	ramming: boolean, -- under the shark and shooting up at it
	trail: number,
	food: number,
	growth: number,
}

export type Session = typeof(setmetatable(
	{} :: {
		gentle: boolean,
		ocean: number,
		bed: SeaFloor.SeaFloor,
		rng: Rng.Rng,
		swimmer: Swimmer.Swimmer,
		schools: Schools.Schools,
		sharks: { Shark },
		pod: { Mate },
		calf: Mate?,
		calfNext: number,
		raised: number,
		lost: Mate?,
		lostIndex: number,
		lostX: number,
		lostY: number,
		lostZ: number,
		familyFound: number,
		reunited: boolean,
		attack: Shark?,
		attackLeft: number,
		attackCooldown: number,
		podCooldown: number,
		target: Shark?,
		targetDistance: number,
		chased: boolean,
		safeLeft: number,
		calmLeft: number,
		driven: number,
		badges: { [string]: string },
		time: number,
		day: number,
		dayTime: number,
		lives: number,
		food: number,
		fish: number,
		tricks: number,
		jumps: number,
		level: number,
		tail: number,
		seen: { [number]: boolean },
		rescueLeft: number,
		rescueReason: string,
		rescues: number,
		over: boolean,
		won: boolean,
		messages: { Message },
		effects: { Effect },
		_hungryWarned: boolean,
		_calfWarned: boolean,
		_calfTip: boolean,
		_sharkTip: boolean,
		_reefTip: boolean,
		_wasNight: boolean,
	},
	Session
))

-- ---------- small vector helpers (Godot's Vector3 maths on plain numbers) ----------

local function length(x: number, y: number, z: number): number
	return math.sqrt(x * x + y * y + z * z)
end

local function distance(ax: number, ay: number, az: number, bx: number, by: number, bz: number): number
	return length(ax - bx, ay - by, az - bz)
end

local function normalized(x: number, y: number, z: number): (number, number, number)
	local l = length(x, y, z)
	if l < 1e-9 then
		return 0, 0, 0
	end
	return x / l, y / l, z / l
end

-- like Vector3.move_toward: step toward the goal, never past it
local function moveToward(
	x: number,
	y: number,
	z: number,
	gx: number,
	gy: number,
	gz: number,
	delta: number
): (number, number, number)
	local d = distance(x, y, z, gx, gy, gz)
	if d <= delta or d < 1e-9 then
		return gx, gy, gz
	end
	local k = delta / d
	return x + (gx - x) * k, y + (gy - y) * k, z + (gz - z) * k
end

-- ---------- starting ----------

function Session.new(gentle: boolean, seed: number?): Session
	local bed = SeaFloor.new(0)
	local self = setmetatable({
		gentle = gentle,
		ocean = 0,
		bed = bed,
		rng = Rng.new(if seed then seed + 101 else os.time()),
		swimmer = Swimmer.new(bed),
		schools = Schools.new(bed, 0, seed),
		sharks = {},
		pod = {},
		calf = nil,
		calfNext = 0,
		raised = 0,
		lost = nil,
		lostIndex = -1,
		lostX = 0,
		lostY = 0,
		lostZ = 0,
		familyFound = 0,
		reunited = false,
		attack = nil,
		attackLeft = 0,
		attackCooldown = 0,
		podCooldown = 0,
		target = nil,
		targetDistance = INF,
		chased = false,
		safeLeft = 0,
		calmLeft = if gentle then Rules.GENTLE_CALM_START else 0,
		driven = 0,
		badges = { attack = "X", pod = "F" },
		time = 0,
		day = 1,
		dayTime = 0,
		lives = Rules.LIVES,
		food = Rules.FOOD_MAX,
		fish = 0,
		tricks = 0,
		jumps = 0,
		level = 1,
		tail = Rules.TAIL_START,
		seen = {},
		rescueLeft = 0,
		rescueReason = "",
		rescues = 0,
		over = false,
		won = false,
		messages = {},
		effects = {},
		_hungryWarned = false,
		_calfWarned = false,
		_calfTip = false,
		_sharkTip = false,
		_reefTip = false,
		_wasNight = false,
	}, Session)
	self:_connect()
	self.swimmer.strength = self.tail
	local s = self.swimmer
	for _ = 1, if gentle then Rules.GENTLE_SHARKS else Rules.SHARKS do
		local shark: Shark = {
			x = 0,
			y = -99,
			z = 0,
			dx = 1,
			dy = 0,
			dz = 0,
			gx = 0,
			gy = 0,
			gz = 0,
			mood = "patrol",
			timer = 0,
			stun = 0,
			kx = 0,
			ky = 0,
			kz = 0,
			phase = self.rng:randf() * Rules.TAU,
			circleLeft = 0,
			circleWay = 1,
			roll = 0,
			rollSpeed = 0,
			burst = 0,
		}
		table.insert(self.sharks, shark)
		self:placeShark(shark, s.x, s.z)
	end
	for _ = 1, Rules.POD_START do
		self:_addMate()
	end
	self:_checkFamily(false)
	self:banner(Lang.f("Day %d. Good luck!", self.day), true)
	self:say(Lang.t("Swim with the arrows, WASD or the mouse. Yellow dots on the sonar are fish"), 5.0)
	return self
end

function Session._connect(self: Session)
	local swimmer = self.swimmer
	swimmer.listeners.jumped = function()
		self.jumps += 1
		self:banner(Lang.t("Leap!"), false)
		self:say(Lang.t("Slow motion! Look around with the arrows or the mouse"), 3.0)
	end
	swimmer.listeners.splashed = function(x: number, y: number, z: number)
		self:effect("splash", x, y, z, 1)
	end
	swimmer.listeners.breathed = function()
		self:banner(Lang.t("A breath! Your air is full again"), false)
	end
	swimmer.listeners.air_low = function()
		self:say(Lang.t("Air is running out! Swim up to breathe"), 4.0)
	end
	swimmer.listeners.suffocated = function()
		swimmer.invulnerable = 0.0
		self:hurt(Lang.t("You ran out of air!"))
		if not self.over then
			self:say(Lang.t("Spring ran out of air! Up, quickly!"), 4.0)
		end
	end
	swimmer.listeners.edge_reached = function()
		self:say(Lang.t("This is the edge of the ocean. Turn back!"), 4.0)
	end
	swimmer.listeners.landed = function(spins: number)
		if spins <= 0 then
			return
		end
		self.tricks += spins
		local words = { "Spin!", "Double spin!", "Triple spin!" }
		self:banner(Lang.t(words[math.min(spins, 3)]), spins > 1)
	end
end

function Session.say(self: Session, text: string, seconds: number)
	table.insert(self.messages, { kind = "say", text = text, big = false, seconds = seconds })
end

function Session.banner(self: Session, text: string, big: boolean)
	table.insert(self.messages, { kind = "banner", text = text, big = big, seconds = if big then 3.0 else 2.2 })
end

function Session.effect(self: Session, kind: string, x: number, y: number, z: number, count: number)
	table.insert(self.effects, { kind = kind, x = x, y = y, z = z, count = count })
end

function Session.isNight(self: Session): boolean
	return Rules.isNight(self.dayTime)
end

-- pod members, Spring and the calf
function Session.familySize(self: Session): number
	return #self.pod + 1 + (if self.calf then 1 else 0)
end

-- ---------- sharks: where they are and where they patrol (Godot's life.gd) ----------

function Session.placeShark(self: Session, shark: Shark, px: number, pz: number)
	local bed = self.bed
	local x, z = bed:freePoint(self.rng, 55, 90, px, pz)
	if distance(x, 0, z, px, 0, pz) < 45.0 then
		-- at the rim of the world: try toward the middle
		local toward = math.sqrt(px * px + pz * pz)
		local cx, cz = 0, 0
		if toward > 75.0 then
			cx, cz = px - px / toward * 75.0, pz - pz / toward * 75.0
		end
		x, z = bed:freePoint(self.rng, 0, 25, cx, cz)
	end
	shark.x, shark.z = x, z
	shark.y = self.rng:range(bed:height(x, z) + 4.0, SEA - 4.0)
	shark.mood = "patrol"
	shark.stun = 0
	shark.kx, shark.ky, shark.kz = 0, 0, 0
	self:newGoal(shark, px, pz)
end

function Session.newGoal(self: Session, shark: Shark, px: number, pz: number)
	local x, z = self.bed:freePoint(self.rng, 15, 60, px, pz)
	shark.gx, shark.gz = x, z
	shark.gy = self.rng:range(self.bed:height(x, z) + 5.0, SEA - 5.0)
end

-- ---------- each frame ----------

-- steerX is right, steerY is up; dt is already slowed during a jump
function Session.step(self: Session, dt: number, steerX: number, steerY: number, boost: boolean)
	local left = dt
	while left > 0.000001 and not self.over do
		local piece = math.min(left, MAX_STEP)
		self:_tick(piece, steerX, steerY, boost)
		left -= piece
	end
end

function Session._tick(self: Session, dt: number, steerX: number, steerY: number, boost: boolean)
	self.time += dt
	if self.rescueLeft > 0.0 then
		self.rescueLeft -= dt
		if self.rescueLeft <= 0.0 then
			self:_finishRescue()
		end
		return
	end
	self.calmLeft = math.max(self.calmLeft - dt, 0.0)
	self.swimmer.strength = self.tail
	local lunged = self.attack ~= nil
	self.safeLeft = math.max(self.safeLeft - dt, 0.0)
	self.attackCooldown = math.max(self.attackCooldown - dt, 0.0)
	self.podCooldown = math.max(self.podCooldown - dt, 0.0)
	local attack = self.attack
	if attack then
		self.attackLeft -= dt
		if self.attackLeft <= 0.0 or attack.mood == "flee" or self.swimmer.jumping then
			self.attack = nil
		end
	end
	local s = self.swimmer
	s.lunging = self.attack ~= nil
	if self.attack then
		s.lungeX, s.lungeY, s.lungeZ = self.attack.x, self.attack.y, self.attack.z
	end
	s:step(dt, steerX, steerY, boost)
	if self.over or self.rescueLeft > 0.0 then
		return
	end
	self:_passTime(dt)
	if self.over then
		return
	end
	local emptyAfter = if self.gentle then Rules.GENTLE_FOOD_EMPTY_AFTER else Rules.FOOD_EMPTY_AFTER
	self.food -= dt * Rules.FOOD_MAX / emptyAfter
	if self.food < Rules.FOOD_LOW and not self._hungryWarned then
		self._hungryWarned = true
		self:say(Lang.t("Spring is hungry! Catch a fish quickly"), 4.0)
	elseif self.food > 40.0 then
		self._hungryWarned = false
	end
	if self.food <= 0.0 then
		self.food = 0.0
		if self.gentle then
			self:_rescue(Lang.t("Spring got too hungry!"))
			return
		end
		self.lives = 0
		self:_end(false, Lang.t("Spring got too hungry!"))
		return
	end
	self.schools:advance(dt, s.x, s.y, s.z)
	self:_fishAndEating()
	self:_movePod(dt)
	self:_moveCalf(dt)
	self:_moveLost(dt)
	if self.over then
		return
	end
	local safe = lunged or self.safeLeft > 0.0 or self.calmLeft > 0.0
	self:_moveSharks(dt, safe)
	if self.over then
		return
	end
	if lunged and self.attack == nil then
		self.safeLeft = Rules.ATTACK_SAFE_AFTER
		s.lunging = false
	end
end

function Session._passTime(self: Session, dt: number)
	self.dayTime += dt
	if self.dayTime >= Rules.DAY_LENGTH then
		self.dayTime -= Rules.DAY_LENGTH
		self.day += 1
		if self.day > Rules.DAYS then
			self:_end(true, "")
			return
		end
		self:banner(
			if self.day == Rules.DAYS then Lang.t("The last day! Hold on!") else Lang.f("Day %d has begun!", self.day),
			true
		)
		self:_healTail(Rules.TAIL_PER_DAY)
		self:_checkFamily(true)
		if self.calf == nil and self.calfNext > 0 and self.day >= self.calfNext then
			self:_newCalf()
			self:say(Lang.t("A calf was born in your pod! Protect it and feed it"), 5.0)
		end
	end
	local night = self:isNight()
	if night and not self._wasNight then
		self:banner(Lang.t("Night has fallen. Be careful!"), false)
	end
	self._wasNight = night
end

function Session._healTail(self: Session, amount: number)
	if self.tail >= 1.0 then
		return
	end
	self.tail = math.min(1.0, self.tail + amount)
	self.swimmer.strength = self.tail
	if self.tail >= 1.0 then
		self:banner(Lang.t("Your tail has healed! Full speed again!"), true)
	end
end

-- ---------- fish, pod and calf ----------

function Session._fishAndEating(self: Session)
	local s = self.swimmer
	local hx, hy, hz = s.x + s.dx * 2.2, s.y + s.dy * 2.2, s.z + s.dz * 2.2
	local calf = self.calf
	for _, school in self.schools.list do
		if school.alive > 0 then
			local away = distance(school.cx, school.cy, school.cz, s.x, s.y, s.z)
			if away < 20.0 then
				for _, one in school.fish do
					if one.alive then
						local caught = (one.x - hx) ^ 2 + (one.y - hy) ^ 2 + (one.z - hz) ^ 2 < 5.8
						if not caught then
							for _, mate in self.pod do
								if (one.x - mate.x) ^ 2 + (one.y - mate.y) ^ 2 + (one.z - mate.z) ^ 2 < 4.0 then
									caught = true
									break
								end
							end
						end
						local byCalf = not caught
							and calf ~= nil
							and (one.x - calf.x) ^ 2 + (one.y - calf.y) ^ 2 + (one.z - calf.z) ^ 2 < 3.4
						if caught or byCalf then
							one.alive = false
							school.alive -= 1
							if school.alive <= 0 then
								school.timer = 4.0
							end
							self:effect("bubbles", one.x, one.y, one.z, 4)
							if caught then
								self:eat(1, school.species)
							else
								self:_feedCalf(15.0, 1.0)
							end
						end
					end
				end
			end
		end
	end
end

function Session.eat(self: Session, count: number, species: number)
	self.fish += count
	self.food = math.min(Rules.FOOD_MAX, self.food + Rules.FOOD_PER_FISH * count)
	self.seen[species] = true
	self:_feedCalf(4.0 * count, 0.34 * count)
	if math.floor(self.fish / Rules.FISH_PER_LEVEL) + 1 > self.level then
		self.level += 1
		self:banner(Lang.f("Level %d! Sharks are faster", self.level), false)
	end
end

local function newMate(self: Session): Mate
	return {
		x = 0,
		y = 0,
		z = 0,
		ox = 0,
		oy = 0,
		oz = 0,
		fx = 0,
		fy = 0,
		fz = -1,
		size = 0.85,
		tint = 1.0,
		phase = 0,
		rush = nil,
		rushTime = 0,
		struck = -1,
		ramming = false,
		trail = 0,
		food = 85.0,
		growth = 0,
	}
end

function Session._slot(self: Session, mate: Mate, index: number)
	local slot = Rules.POD_SLOTS[index]
	mate.ox, mate.oy, mate.oz = slot[1], slot[2], slot[3]
end

function Session._addMate(self: Session)
	local s = self.swimmer
	local mate = newMate(self)
	self:_slot(mate, #self.pod + 1)
	mate.size = self.rng:range(0.78, 0.92)
	mate.tint = self.rng:range(0.86, 1.06)
	mate.phase = self.rng:randf() * Rules.TAU
	local ox, oy, oz = Rules.turn(mate.ox, mate.oy - 2, mate.oz - 5, s.yaw)
	mate.x, mate.y, mate.z = s.x + ox, s.y + oy, s.z + oz
	table.insert(self.pod, mate)
end

function Session._newCalf(self: Session)
	local s = self.swimmer
	local calf = newMate(self)
	calf.tint = 1.16
	local c = Rules.CALF_OFFSET
	local ox, oy, oz = Rules.turn(c[1], c[2], c[3], s.yaw)
	calf.x, calf.y, calf.z = s.x + ox, s.y + oy, s.z + oz
	self.calf = calf
	self._calfWarned = false
	self:_sizeCalf()
end

function Session._sizeCalf(self: Session)
	local calf = self.calf
	if calf then
		calf.size = 0.46 + 0.36 * math.min(1.0, calf.growth / Rules.CALF_GROWTH)
	end
end

function Session._feedCalf(self: Session, amount: number, growth: number)
	local calf = self.calf
	if calf == nil then
		return
	end
	calf.food = math.min(100.0, calf.food + amount)
	calf.growth += growth
	self:_sizeCalf()
	if calf.growth < Rules.CALF_GROWTH then
		return
	end
	self.calf = nil
	self.raised += 1
	self.calfNext = self.day + 2
	if #self.pod < #Rules.POD_SLOTS then
		self:_slot(calf, #self.pod + 1)
		calf.size = 0.86
		table.insert(self.pod, calf)
		self:banner(Lang.t("The calf has grown up and joined the pod!"), true)
	else
		self:banner(Lang.t("The calf has grown up and swum off on its own!"), true)
	end
end

function Session._movePod(self: Session, dt: number)
	local s = self.swimmer
	local bed = self.bed
	for i, mate in self.pod do
		local gx, gy, gz
		local pace = 0.0
		local rush = mate.rush
		if mate.rushTime > 0.0 and rush then
			mate.rushTime -= dt
			if mate.struck >= 0.0 then
				mate.struck += dt
			end
			gx, gy, gz = self:_rushGoal(mate, rush, i - 1)
			pace = Rules.POD_RUSH_SPEED
			if mate.struck < 0.0 then
				mate.trail -= dt
				if mate.trail <= 0.0 then
					mate.trail = Rules.POD_TRAIL_EVERY
					self:effect("bubbles", mate.x - mate.fx * 1.6, mate.y - mate.fy * 1.6, mate.z - mate.fz * 1.6, 2)
				end
			end
		else
			mate.rush = nil
			mate.struck = -1.0
			mate.ramming = false
			local ox, oy, oz = Rules.turn(mate.ox, mate.oy, mate.oz, s.yaw)
			gx, gy, gz = s.x + ox, s.y + oy, s.z + oz
			gy += math.sin(self.time * 1.3 + (i - 1)) * 0.6
		end
		local wx, wy, wz = mate.x, mate.y, mate.z
		if pace == 0.0 then
			pace = math.min(36.0, distance(wx, wy, wz, gx, gy, gz) * 2.4)
		end
		local px, py, pz = moveToward(wx, wy, wz, gx, gy, gz, pace * dt)
		local ground = bed:height(px, pz) + 1.2
		if ground > SEA - 1.4 then
			px, py, pz = bed:pushOut(px, py, pz, 1.2, SEA - 1.4)
		elseif py < ground then
			py = ground
		end
		mate.x, mate.y, mate.z = px, py, pz
		if (px - wx) ^ 2 + (py - wy) ^ 2 + (pz - wz) ^ 2 > 0.000001 then
			local nx, ny, nz = normalized(px - wx, py - wy, pz - wz)
			local k = math.min(1.0, 8.0 * dt)
			mate.fx += (nx - mate.fx) * k
			mate.fy += (ny - mate.fy) * k
			mate.fz += (nz - mate.fz) * k
		end
		mate.phase += dt * (5.0 + (if mate.rushTime > 0.0 then 14.0 else s.speed * 0.35))
	end
end

-- Where a rushing mate heads: first under the shark, a little to one side, then up into its belly
-- by the gills, as real dolphins ram sharks. After the hit it follows the fleeing shark for the
-- rest of the rush. i counts from 0, as in Godot.
function Session._rushGoal(self: Session, mate: Mate, shark: Shark, i: number): (number, number, number)
	local bed = self.bed
	local fx, fz = shark.dx, shark.dz
	local flat = math.sqrt(fx * fx + fz * fz)
	if flat * flat > 0.001 then
		fx, fz = fx / flat, fz / flat
	else
		fx, fz = 0, -1
	end
	local side = if i % 2 == 0 then 1 else -1
	local bx, bz = -fz * side, fx * side -- flat x UP, to one side
	if mate.struck >= 0.0 then
		-- peel away and escort it off: behind, below and to one side, clear of its body
		local ex = shark.x - shark.dx * 5.5 + bx * 3.0
		local ey = shark.y - shark.dy * 5.5 - 1.5
		local ez = shark.z - shark.dz * 5.5 + bz * 3.0
		ey += math.sin(self.time * 5.0 + i * 2.0) * 0.8
		ey = math.max(ey, bed:height(ex, ez) + 1.5)
		return ex, ey, ez
	end
	if mate.ramming then
		if distance(mate.x, mate.y, mate.z, shark.x, shark.y, shark.z) < Rules.POD_RAM_REACH then
			self:_podStrike(mate, shark)
		end
		return shark.x + fx * 0.6, shark.y - 0.3, shark.z + fz * 0.6
	end
	local ux = shark.x + bx * 2.0 - fx * 0.5
	local uy = shark.y - Rules.POD_BELOW
	local uz = shark.z + bz * 2.0 - fz * 0.5
	uy = math.max(uy, bed:height(ux, uz) + 1.5)
	-- under it now (or running out of time): go up and hit
	if distance(mate.x, mate.y, mate.z, ux, uy, uz) < 2.0 or mate.rushTime < 1.2 then
		mate.ramming = true
	end
	return ux, uy, uz
end

-- A mate rams the shark it chases: the shark is knocked up and away, rolls over and reels, then
-- races off, in a burst of bubbles.
function Session._podStrike(self: Session, mate: Mate, shark: Shark)
	mate.struck = 0.0
	local ax, ay, az = shark.x - mate.x, shark.y - mate.y, shark.z - mate.z
	if ax * ax + ay * ay + az * az > 0.01 then
		ax, ay, az = normalized(ax, ay, az)
	else
		ax, ay, az = 0, 1, 0
	end
	shark.kx += ax * Rules.POD_KNOCK
	shark.ky += ay * Rules.POD_KNOCK
	shark.kz += az * Rules.POD_KNOCK
	shark.stun = math.max(shark.stun, Rules.POD_STUN)
	shark.rollSpeed = Rules.POD_TUMBLE * (if self.rng:randf() < 0.5 then 1 else -1)
	shark.burst = Rules.POD_BURST
	self:effect("bubbles", (mate.x + shark.x) / 2, (mate.y + shark.y) / 2, (mate.z + shark.z) / 2, 22)
	self:effect("pod_hit", shark.x, shark.y, shark.z, 0)
end

function Session._moveCalf(self: Session, dt: number)
	local calf = self.calf
	if calf == nil then
		return
	end
	local s = self.swimmer
	local c = Rules.CALF_OFFSET
	local ox, oy, oz = Rules.turn(c[1], c[2], c[3], s.yaw)
	local gx, gy, gz = s.x + ox, s.y + oy + math.sin(self.time * 2.1) * 0.25, s.z + oz
	local wx, wy, wz = calf.x, calf.y, calf.z
	local fastest = if calf.food < 20.0 then 8.5 else 40.0
	local px, py, pz =
		moveToward(wx, wy, wz, gx, gy, gz, math.min(fastest, distance(wx, wy, wz, gx, gy, gz) * 6.0) * dt)
	local ground = self.bed:height(px, pz) + 1.0
	if ground > SEA - 1.2 then
		px, py, pz = self.bed:pushOut(px, py, pz, 1.0, SEA - 1.2)
	elseif py < ground then
		py = ground
	end
	calf.x, calf.y, calf.z = px, py, pz
	if (px - wx) ^ 2 + (py - wy) ^ 2 + (pz - wz) ^ 2 > 0.000001 then
		local nx, ny, nz = normalized(px - wx, py - wy, pz - wz)
		local k = math.min(1.0, 8.0 * dt)
		calf.fx += (nx - calf.fx) * k
		calf.fy += (ny - calf.fy) * k
		calf.fz += (nz - calf.fz) * k
	end
	calf.phase += dt * (7.0 + s.speed * 0.45)
	calf.food = math.max(0.0, calf.food - dt * 100.0 / Rules.CALF_EMPTY_AFTER)
	if calf.food < 25.0 and not self._calfWarned then
		self._calfWarned = true
		self:say(Lang.t("The calf is hungry! Lead it through a school of fish"), 4.0)
	elseif calf.food > 45.0 then
		self._calfWarned = false
	end
end

-- ---------- sharks ----------

function Session._moveSharks(self: Session, dt: number, safe: boolean)
	local s = self.swimmer
	local bed = self.bed
	local wasChased = self.chased
	self.chased = false
	self.target = nil
	self.targetDistance = INF
	local chaseSpeed = 8.6 + self.level * 0.45
	if self.gentle then
		chaseSpeed = math.min(chaseSpeed, s:cruiseSpeed() - Rules.SHARK_BELOW_HER)
	end
	local ramming = s:isRamming()
	local px, py, pz = s.x, s.y, s.z
	local nx, ny, nz = px + s.dx * 2.3, py + s.dy * 2.3, pz + s.dz * 2.3
	for _, shark in self.sharks do
		shark.timer -= dt
		shark.stun = math.max(shark.stun - dt, 0.0)
		local away = distance(shark.x, shark.y, shark.z, px, py, pz)
		local wx, wy, wz
		local pace
		shark.burst = math.max(shark.burst - dt, 0.0)
		shark.roll += shark.rollSpeed * dt
		shark.rollSpeed *= math.exp(-2.0 * dt)
		if math.abs(shark.rollSpeed) < 1.5 then
			-- settle back upright the short way round
			shark.roll = Rules.wrap(shark.roll, -math.pi, math.pi)
			local step = 3.0 * dt
			shark.roll = if math.abs(shark.roll) <= step then 0 else shark.roll - Rules.sign(shark.roll) * step
		end
		if shark.mood == "flee" then
			wx, wy, wz = normalized(shark.x - px, shark.y - py, shark.z - pz)
			pace = if shark.stun > 0.0
				then 2.0
				else (if shark.burst > 0.0 then Rules.POD_BURST_SPEED else 11.0)
			if shark.timer <= 0.0 then
				shark.mood = "patrol"
				self:newGoal(shark, px, pz)
			end
		elseif away < 30.0 and s.invulnerable <= 0.0 and self.calmLeft <= 0.0 then
			if shark.mood ~= "chase" then
				if not self._sharkTip then
					self._sharkTip = true
					self:say(
						Lang.f(
							"Shark! Press Hit (%s) and Spring rams it with her snout. Or call your pod (%s)",
							self.badges.attack,
							self.badges.pod
						),
						5.0
					)
				end
				shark.circleLeft = if self.gentle then Rules.CIRCLE_GENTLE else Rules.CIRCLE_HARD
				shark.circleWay = if self.rng:randf() < 0.5 then 1 else -1
			end
			shark.mood = "chase"
			wx, wy, wz = normalized(px - shark.x, py - shark.y, pz - shark.z)
			pace = chaseSpeed
			if shark.circleLeft > 0.0 then
				-- round her at a distance first, drifting in to the circle
				shark.circleLeft -= dt
				local ox, oy, oz = shark.x - px, (shark.y - py) * 0.3, shark.z - pz
				local fx, fy, fz = 1, 0, 0
				if ox * ox + oy * oy + oz * oz > 0.01 then
					fx, fy, fz = normalized(ox, oy, oz)
				end
				local ax, az = -fz * shark.circleWay, fx * shark.circleWay -- flat x UP
				local drift = (Rules.CIRCLE_RADIUS - length(ox, oy, oz)) * 0.15
				wx, wy, wz = normalized(ax + fx * drift, fy * drift, az + fz * drift)
				pace = chaseSpeed * 0.8
			end
			self.chased = true
		else
			if away > 125.0 then
				self:placeShark(shark, px, pz)
			end
			shark.mood = "patrol"
			wx, wy, wz = shark.gx - shark.x, shark.gy - shark.y, shark.gz - shark.z
			if length(wx, wy, wz) < 6.0 then
				self:newGoal(shark, px, pz)
				wx, wy, wz = shark.gx - shark.x, shark.gy - shark.y, shark.gz - shark.z
			end
			wx, wy, wz = normalized(wx, wy, wz)
			pace = 5.0
		end
		local k = math.min(1.0, 1.6 * dt)
		local tx, ty, tz = shark.dx + (wx - shark.dx) * k, shark.dy + (wy - shark.dy) * k, shark.dz + (wz - shark.dz) * k
		if tx * tx + ty * ty + tz * tz > 0.0001 then
			shark.dx, shark.dy, shark.dz = normalized(tx, ty, tz)
		end
		local x = shark.x + (shark.dx * pace + shark.kx) * dt
		local y = shark.y + (shark.dy * pace + shark.ky) * dt
		local z = shark.z + (shark.dz * pace + shark.kz) * dt
		local fade = math.max(0.0, 1.0 - 3.0 * dt)
		shark.kx, shark.ky, shark.kz = shark.kx * fade, shark.ky * fade, shark.kz * fade
		x, y, z = bed:pushOut(x, y, z, 2.5, SEA - 3.5)
		y = clamp(y, bed:height(x, z) + 2.5, SEA - 2.0)
		shark.x, shark.y, shark.z = x, y, z
		shark.phase += dt * (4.0 + pace * 0.5)
		if shark.mood ~= "flee" then
			if away < self.targetDistance then
				self.targetDistance = away
				self.target = shark
			end
			local mine = shark == self.attack
			local along = clamp((nx - x) * shark.dx + (ny - y) * shark.dy + (nz - z) * shark.dz, -3.6, 3.3)
			local reach = if mine then 3.4 else 2.5
			if ramming and distance(x + shark.dx * along, y + shark.dy * along, z + shark.dz * along, nx, ny, nz) < reach then
				self:_hit(shark, mine)
			elseif s.invulnerable <= 0.0 and not safe and shark.circleLeft <= 0.0 then
				local mx, my, mz = x + shark.dx * 2.6, y + shark.dy * 2.6, z + shark.dz * 2.6
				local calf = self.calf
				if distance(mx, my, mz, px, py, pz) < 3.2 then
					self:_bite(shark, "")
				elseif calf and distance(mx, my, mz, calf.x, calf.y, calf.z) < 2.5 and self.gentle then
					-- in gentle a scared calf goes hungry instead of costing a heart
					calf.food = math.max(0.0, calf.food - 25.0)
					shark.mood = "flee"
					shark.timer = 5.0
					self:say(Lang.t("A shark scared the calf! Keep sharks away"), 3.0)
				elseif calf and distance(mx, my, mz, calf.x, calf.y, calf.z) < 2.5 then
					self:_bite(shark, Lang.t("A shark attacked the calf!"))
					if not self._calfTip and not self.over then
						self._calfTip = true
						self:say(Lang.t("A shark attacked the calf! You shielded it. Keep sharks away"), 5.0)
					end
				end
			end
			if self.over or self.rescueLeft > 0.0 then
				break
			end
		end
	end
	if self.chased and not wasChased then
		self:effect("alarm", px, py, pz, 0)
	end
	if self.chased and not self._reefTip and bed:height(px, pz) > SEA - 5.6 then
		self._reefTip = true
		self:say(Lang.t("The shallows by an island are safe: too shallow for sharks"), 4.5)
	end
end

function Session._hit(self: Session, shark: Shark, mine: boolean)
	local s = self.swimmer
	shark.mood = "flee"
	shark.timer = 12.0
	shark.stun = 1.3
	local fx, fz = s.dx, s.dz
	local flat = math.sqrt(fx * fx + fz * fz)
	if flat > 1e-3 then
		fx, fz = fx / flat, fz / flat
	else
		fx, fz = math.sin(s.yaw), math.cos(s.yaw)
	end
	local sx, sz = shark.x - s.x, shark.z - s.z
	local along = sx * fx + sz * fz
	sx, sz = sx - fx * along, sz - fz * along
	if sx * sx + sz * sz < 0.04 then
		sx, sz = fz, -fx
	end
	local sl = math.sqrt(sx * sx + sz * sz)
	sx, sz = sx / sl, sz / sl
	shark.x += fx * 1.5 + sx
	shark.z += fz * 1.5 + sz
	shark.kx, shark.ky, shark.kz = fx * 5.0 + sx * 8.0, 0, fz * 5.0 + sz * 8.0
	s.speed = 8.0
	if mine then
		self.attack = nil
		s.lunging = false
		self.safeLeft = Rules.ATTACK_SAFE_AFTER
	else
		s.energy = math.max(0.0, s.energy - 0.25)
	end
	self.driven += 1
	self:effect("bubbles", s.x + s.dx * 2.3, s.y + s.dy * 2.3, s.z + s.dz * 2.3, 34)
	self:banner(Lang.t("Snout hit! The shark swims away"), false)
end

function Session._bite(self: Session, shark: Shark, reason: string)
	self:hurt(reason)
	shark.mood = "flee"
	shark.timer = 5.0
end

-- ---------- her own buttons ----------

function Session.pressAttack(self: Session)
	if self.over or self.swimmer.jumping or self.rescueLeft > 0 then
		return
	end
	if self.attackCooldown > 0.0 then
		self:say(Lang.t("Spring is gathering strength for another hit"), 1.5)
		return
	end
	local target = self.target
	if target == nil or self.targetDistance > Rules.ATTACK_RANGE then
		self:say(Lang.t("No sharks nearby"), 1.8)
		return
	end
	self.attack = target
	self.attackLeft = Rules.ATTACK_TIME
	self.attackCooldown = Rules.ATTACK_COOLDOWN
	self.swimmer.autoJump = false
	self:banner(Lang.t("Charge!"), false)
end

function Session.pressJump(self: Session)
	if self.over or self.swimmer.jumping or self.rescueLeft > 0 then
		return
	end
	if not self.swimmer:requestJump() then
		self:say(Lang.t("Swimming up to jump!"), 2.0)
	end
end

function Session.pressPod(self: Session)
	if self.over or self.rescueLeft > 0 then
		return
	end
	if #self.pod == 0 then
		self:say(Lang.t("Your family isn't with you yet. Find them first!"), 2.5)
		return
	end
	if self.podCooldown > 0.0 then
		self:say(Lang.t("Your pod is resting, wait a little"), 1.5)
		return
	end
	local s = self.swimmer
	local near: { Shark } = {}
	for _, shark in self.sharks do
		if shark.mood ~= "flee" and distance(shark.x, shark.y, shark.z, s.x, s.y, s.z) < Rules.POD_RANGE then
			table.insert(near, shark)
		end
	end
	if #near == 0 then
		self:say(Lang.t("No sharks nearby. Your pod will help when they come"), 2.5)
		return
	end
	table.sort(near, function(a: Shark, b: Shark): boolean
		return (a.x - s.x) ^ 2 + (a.y - s.y) ^ 2 + (a.z - s.z) ^ 2 < (b.x - s.x) ^ 2 + (b.y - s.y) ^ 2 + (b.z - s.z) ^ 2
	end)
	local count = math.min(#near, 1 + math.floor(#self.pod / 3))
	for i = 1, count do
		near[i].mood = "flee"
		near[i].timer = 14.0
		self.driven += 1
	end
	for i, mate in self.pod do
		mate.rush = near[(i - 1) % count + 1]
		mate.rushTime = Rules.POD_RUSH
		mate.struck = -1.0
		mate.ramming = false
		mate.trail = 0.0
	end
	self.podCooldown = Rules.POD_COOLDOWN
	self:banner(
		if count > 1 then Lang.t("Your pod chases the sharks away!") else Lang.t("Your pod chases the shark away!"),
		false
	)
end

-- ---------- her family, one by one ----------

-- who from her family is waiting today (0 for the first; #FAMILY for her mother), or -1
function Session.familyDue(self: Session): number
	if self.day >= Rules.DAYS then
		return #FAMILY
	end
	local found = self.familyFound
	if found < #Rules.FAMILY_DAYS and self.day >= Rules.FAMILY_DAYS[found + 1] then
		return found
	end
	return -1
end

function Session._checkFamily(self: Session, announce: boolean)
	local who = self:familyDue()
	if who < 0 or self.over then
		self.lost = nil
		self.lostIndex = -1
		return
	end
	local lost = self.lost
	if lost == nil or self.lostIndex ~= who then
		lost = newMate(self)
		self.lost = lost
		self.lostIndex = who
		lost.size = if who == #FAMILY then 1.0 else self.rng:range(0.82, 0.92)
		lost.tint = self.rng:range(0.86, 1.06)
		lost.phase = self.rng:randf() * Rules.TAU
		announce = true
	end
	assert(lost)
	local s = self.swimmer
	local x, z = self.bed:freePoint(self.rng, 60, 140, s.x, s.z)
	local bottom = self.bed:height(x, z)
	self.lostX, self.lostY, self.lostZ = x, clamp(SEA - 8.0, bottom + 4.0, SEA - 3.0), z
	lost.x, lost.y, lost.z = self.lostX, self.lostY, self.lostZ
	if announce then
		local line = if who == #FAMILY
			then "Sam heard your mother's whistle! She is nearby. Look for the pink heart on the sonar"
			else "Sam heard whistles! Someone from your family is nearby. Look for the pink heart on the sonar"
		self:say(Lang.t(line), 6.0)
	end
end

function Session._moveLost(self: Session, dt: number)
	local lost = self.lost
	if lost == nil then
		return
	end
	local wx, wy, wz = lost.x, lost.y, lost.z
	local a = self.time * 0.3 + lost.phase
	local gx = self.lostX + math.cos(a) * 6.0
	local gy = self.lostY + 0.3 * math.sin(a * 2.0) * 6.0
	local gz = self.lostZ + math.sin(a) * 6.0
	lost.x, lost.y, lost.z = moveToward(wx, wy, wz, gx, gy, gz, 3.5 * dt)
	if (lost.x - wx) ^ 2 + (lost.y - wy) ^ 2 + (lost.z - wz) ^ 2 > 0.000001 then
		local nx, ny, nz = normalized(lost.x - wx, lost.y - wy, lost.z - wz)
		local k = math.min(1.0, 4.0 * dt)
		lost.fx += (nx - lost.fx) * k
		lost.fy += (ny - lost.fy) * k
		lost.fz += (nz - lost.fz) * k
	end
	lost.phase += dt * 5.0
	local s = self.swimmer
	if distance(lost.x, lost.y, lost.z, s.x, s.y, s.z) < Rules.FAMILY_MEET then
		self:_familyJoins()
	end
end

function Session._familyJoins(self: Session)
	local mate = self.lost
	local who = self.lostIndex
	self.lost = nil
	self.lostIndex = -1
	if mate == nil then
		return
	end
	self:effect("bubbles", mate.x, mate.y, mate.z, 30)
	if who == #FAMILY then
		self.reunited = true
		self:banner(Lang.t("You found your mother!"), true)
		self:_end(true, "")
		return
	end
	self.familyFound += 1
	if #self.pod < #Rules.POD_SLOTS then
		self:_slot(mate, #self.pod + 1)
		table.insert(self.pod, mate)
	end
	self:banner(Lang.t(FAMILY[who + 1]), true)
	if self.familyFound >= Rules.CALF_AFTER_FAMILY and self.calf == nil and self.raised == 0 and self.calfNext == 0 then
		self.calfNext = self.day + 1
	end
end

-- ---------- hurt, rescue and the end ----------

function Session.hurt(self: Session, reason: string?)
	if self.over or self.swimmer.invulnerable > 0.0 then
		return
	end
	self.lives -= 1
	self.swimmer.invulnerable = if self.gentle then Rules.GENTLE_INVULNERABLE else Rules.INVULNERABLE
	self:effect("hurt", self.swimmer.x, self.swimmer.y, self.swimmer.z, 0)
	local why = reason or ""
	if self.lives <= 0 and self.gentle then
		self.lives = 0
		self:_rescue(if why ~= "" then why else Lang.t("Ouch, a shark got you!"))
	elseif self.lives <= 0 then
		self:_end(false, if why ~= "" then why else Lang.t("Ouch, a shark got you!"))
	elseif why ~= "" then
		self:banner(why, false)
	end
end

-- Gentle: losing every heart or going hungry brings Sam and the rescuers instead of a game over
function Session._rescue(self: Session, reason: string)
	self.rescues += 1
	self.rescueLeft = Rules.RESCUE_TIME
	self.rescueReason = reason
	self.attack = nil
	self.chased = false
	self.swimmer.jumping = false
	self.swimmer.lunging = false
	self.swimmer.autoJump = false
end

function Session._finishRescue(self: Session)
	self.lives = Rules.LIVES
	self.food = Rules.FOOD_MAX
	local s = self.swimmer
	local x, _, z = self.bed:pushOut(s.x + 7, s.y, s.z, 1.6, SEA - 1.1)
	s:reset(x, SEA - 2.0, z, s.yaw)
	for _, mate in self.pod do
		local ox, oy, oz = Rules.turn(mate.ox, mate.oy, mate.oz, s.yaw)
		mate.x, mate.y, mate.z = s.x + ox, s.y + oy, s.z + oz
		mate.rush = nil
	end
	local calf = self.calf
	if calf then
		local c = Rules.CALF_OFFSET
		local ox, oy, oz = Rules.turn(c[1], c[2], c[3], s.yaw)
		calf.x, calf.y, calf.z = s.x + ox, s.y + oy, s.z + oz
		calf.food = math.max(calf.food, 60.0)
	end
	for _, shark in self.sharks do
		self:placeShark(shark, s.x, s.z)
	end
	self.calmLeft = Rules.CALM_AFTER_RESCUE
	self:banner(Lang.t("Sam and the rescuers helped you. Swim on!"), true)
end

function Session._end(self: Session, victory: boolean, reason: string)
	self.over = true
	self.won = victory
	self.rescueReason = reason
	self.attack = nil
	self.swimmer.lunging = false
end

return Session
