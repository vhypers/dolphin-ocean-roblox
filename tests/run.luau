-- Logic tests for the rules (no Roblox needed). Run: tools/luau tests/run.luau
local Rules = require("../src/shared/Rules")
local Rng = require("../src/shared/Rng")
local SeaFloor = require("../src/shared/SeaFloor")
local Swimmer = require("../src/shared/Swimmer")
local Schools = require("../src/shared/Schools")
local Session = require("../src/shared/Session")
local Lang = require("../src/shared/Lang")
local Data = require("../src/shared/Data")

local passed, failed = 0, 0
local function check(ok: boolean, what: string)
	if ok then
		passed += 1
	else
		failed += 1
		print("FAIL: " .. what)
	end
end
local function near(a: number, b: number, eps: number?): boolean
	return math.abs(a - b) <= (eps or 1e-6)
end

local SEA = Rules.SEA_LEVEL

-- ---------- the numbers match the Godot game ----------
local expected = {
	SEA_LEVEL = 18.0, WORLD_RADIUS = 300.0, DAY_LENGTH = 120.0, DAYS = 30, AIR_MAX = 60.0,
	AIR_REFILL_TIME = 1.2, AIR_LOW = 20.0, AIR_AFTER_HURT = 15.0, BREATH_DEPTH = 1.5,
	FOOD_MAX = 100.0, FOOD_EMPTY_AFTER = 80.0, FOOD_LOW = 25.0, FOOD_PER_FISH = 12.0, LIVES = 3,
	CRUISE_SPEED = 11.0, BOOST_SPEED = 23.0, BOOST_DRAIN = 0.33, BOOST_REFILL = 0.13,
	TURN_RATE = 1.8, PITCH_RATE = 1.05, GRAVITY = 18.0, JUMP_SLOW_MOTION = 0.33,
	TAIL_START = 0.6, TAIL_PER_DAY = 0.08, GENTLE_FOOD_EMPTY_AFTER = 150.0, RESCUE_TIME = 3.5,
	SPIN_RATE = 9.0, INVULNERABLE = 2.2, GENTLE_INVULNERABLE = 4.0,
}
for name, value in expected do
	check((Rules :: any)[name] == value, "Rules." .. name .. " is " .. tostring(value))
end

-- ---------- Godot-style helpers ----------
check(near(Rules.angleDifference(0, math.pi * 1.5), -math.pi * 0.5), "angle difference takes the short way")
check(near(Rules.lerpAngle(0.1, -0.1, 0.5), 0), "lerpAngle halfway")
check(near(Rules.rotateToward(0, 1, 0.25), 0.25), "rotateToward steps")
check(near(Rules.rotateToward(0, 0.1, 0.25), 0.1), "rotateToward stops at the target")
check(near(Rules.wrap(4, -math.pi, math.pi), 4 - 2 * math.pi), "wrap into -pi..pi")
check(near(Rules.fposmod(-0.25, 1), 0.75), "fposmod is never negative")
check(Rules.smoothstep(0, 1, -1) == 0 and Rules.smoothstep(0, 1, 2) == 1, "smoothstep clamps")
check(not Rules.isNight(0) and Rules.isNight(Rules.DAY_LENGTH * 0.75), "night comes late in the day")

-- ---------- random numbers ----------
do
	local a, b = Rng.new(5), Rng.new(5)
	local same, inRange = true, true
	for _ = 1, 1000 do
		local x, y = a:randf(), b:randf()
		same = same and x == y
		inRange = inRange and x >= 0 and x < 1
	end
	check(same, "same seed, same numbers")
	check(inRange, "randf stays in 0..1")
	check(Rng.new(5):randf() ~= Rng.new(6):randf(), "different seeds differ")
end

-- ---------- the Red Sea floor ----------
local bed = SeaFloor.new(0)
check(#bed.islands == 10, "the Red Sea has 10 islands")
for i, island in bed.islands do
	local place = Data.redSeaIslands[i]
	check(island.cx == place[1] and island.cz == place[2] and island.radius == place[3], "island " .. i .. " from the data")
	check(bed:height(island.cx, island.cz) > SEA + 2, "island " .. i .. " rises above the sea")
end
do
	local open = bed:height(0, 0)
	check(open < SEA - 30 and open > -35, "open sea near the start is deep: " .. open)
	local far = bed:height(450, 0)
	check(far < bed:base(450, 0) - 15, "the bed drops off past the edge of the world")
	-- push a point that is inside island 1 out to deep enough water
	local island = bed.islands[1]
	local x, y, z = bed:pushOut(island.cx + 5, 10, island.cz, 1.6, SEA - 1.1)
	check(bed:height(x, z) + 1.6 <= SEA - 1.1 + 1e-3, "pushOut leaves her in water deep enough")
	check(y == 10, "pushOut keeps the height")
	local dist = math.sqrt((x - island.cx) ^ 2 + (z - island.cz) ^ 2)
	check(dist > island.radius * 0.3, "pushOut moves outward from the island")
	local ox, oy, oz = bed:pushOut(0, 0, 0, 1.6, SEA - 1.1)
	check(ox == 0 and oy == 0 and oz == 0, "pushOut leaves open water alone")
	local rng = Rng.new(3)
	local fx, fz = bed:freePoint(rng, 20, 285)
	check(bed:height(fx, fz) < -14 and math.sqrt(fx * fx + fz * fz) <= 294 + 1e-6, "freePoint finds deep open water")
end

-- ---------- swimming ----------
do
	local s = Swimmer.new(bed)
	check(s.x == 0 and s.y == -4 and s.z == 0, "she starts where the Godot game starts")
	s.strength = Rules.TAIL_START
	check(near(s:cruiseSpeed(), 11 * (0.78 + 0.22 * 0.6)), "a hurt tail swims slower")
	for _ = 1, 120 do
		s:step(1 / 60, 0, 0, false)
	end
	check(s.z > 15 and near(s.x, 0, 1e-6), "with no steering she swims straight ahead (+z)")
	check(near(s.air, 58, 0.05), "air runs down a second per second under water")
	local before = s.yaw
	s:step(0.1, 1, 0, false)
	check(s.yaw < before, "steering right turns her right (yaw goes down)")
	-- boosting uses energy and is faster
	local b = Swimmer.new(bed)
	for _ = 1, 60 do
		b:step(1 / 60, 0, 0, true)
	end
	check(b.energy < 0.7 and b.speed > 15, "boost drains energy and speeds her up")
	for _ = 1, 600 do
		b:step(1 / 60, 0, 0, false)
	end
	check(b.energy == 1, "energy refills when she stops boosting")
	-- breathing at the surface
	local u = Swimmer.new(bed)
	u.air = 30
	local breathed = 0
	u.listeners.breathed = function()
		breathed += 1
	end
	u:reset(0, SEA - 1.0, 0, 0)
	u.air = 30
	u:step(0.6, 0, 0, false)
	check(breathed == 1, "coming up to breathe says so once")
	check(u.air > 50, "air refills fast at the surface")
	-- running out of air
	local d = Swimmer.new(bed)
	local hurt = 0
	d.listeners.suffocated = function()
		hurt += 1
	end
	d.air = 0.01
	d:step(0.05, 0, 0, false)
	check(hurt == 1 and d.air == Rules.AIR_AFTER_HURT, "out of air: hurt, and 15 s of air to get up")
	-- leaping out of the water when she rises steeply and fast
	local j = Swimmer.new(bed)
	local jumped = 0
	j.listeners.jumped = function()
		jumped += 1
	end
	j:reset(0, SEA - 1.0, 0, 0)
	j.pitch = 0.6
	j.speed = 14
	for _ = 1, 6 do
		j:step(1 / 60, 0, 1, false)
	end
	check(j.jumping and jumped == 1, "rising steeply at speed makes her leap")
	local spins = -1
	j.listeners.landed = function(n: number)
		spins = n
	end
	for _ = 1, 600 do
		j:step(1 / 60, 0, 0, true)
		if not j.jumping then
			break
		end
	end
	check(not j.jumping and spins >= 1, "holding Boost in the air spins her: " .. spins)
	-- the jump button from deep water swims up first
	local k = Swimmer.new(bed)
	check(not k:requestJump() and k.autoJump, "jump from deep water swims up first")
	for _ = 1, 600 do
		k:step(1 / 60, 0, 0, false)
		if k.jumping then
			break
		end
	end
	check(k.jumping, "and then leaps")
	-- the edge of the world
	local e = Swimmer.new(bed)
	local edges = 0
	e.listeners.edge_reached = function()
		edges += 1
	end
	e:reset(0, -4, 299, 0)
	for _ = 1, 30 do
		e:step(1 / 30, 0, 0, false)
	end
	check(math.sqrt(e.x ^ 2 + e.z ^ 2) <= Rules.WORLD_RADIUS + 1e-6, "she stays inside the world")
	check(edges == 1, "the edge says so once")
	-- islands are walls
	local w = Swimmer.new(bed)
	local island = bed.islands[1]
	w:reset(island.cx, -4, island.cz - island.radius * 1.6, 0)
	for _ = 1, 600 do
		w:step(1 / 60, 0, 0, false)
	end
	check(bed:height(w.x, w.z) + 1.6 <= SEA - 1.1 + 0.01, "she can't swim into an island")
end

-- ---------- fish ----------
do
	local schools = Schools.new(bed, 0, 7)
	check(#schools.list == 16, "16 schools in the Red Sea")
	-- as in the Godot game, a school settles into the water on its first move
	schools:advance(0.01, 1000, -4, 1000)
	local fishCount, reefSchools = 0, 0
	for _, school in schools.list do
		fishCount += #school.fish
		if school.island then
			reefSchools += 1
		end
		check(school.cy < SEA - 2.9 and school.cy > bed:height(school.cx, school.cz) + 2.9, "a school is in the water")
	end
	check(fishCount == 256, "16 fish in each school")
	check(reefSchools == 11, "11 schools live by the reefs, 5 in open water")
	local s = schools.list[1]
	s.alive = 0
	s.timer = 0.5
	schools:advance(0.6, 0, -4, 0)
	check(s.alive == 16, "an eaten school comes back elsewhere")
end

-- ---------- one game ----------
do
	local game = Session.new(true, 11)
	check(game.lives == 3 and game.food == 100 and game.day == 1, "a new game")
	check(game.tail == Rules.TAIL_START and game.swimmer.strength == Rules.TAIL_START, "her tail starts hurt")
	-- food runs out in 150 s in Gentle
	game:step(1.5, 0, 0, false)
	check(near(game.food, 99, 0.01), "food drops 1 every 1.5 s in Gentle")
	-- eating a fish right in front of her
	local school = game.schools.list[1]
	local s = game.swimmer
	school.cx, school.cy, school.cz = s.x, s.y, s.z + 2.2
	local one = school.fish[1]
	game.food = 50
	local before = game.fish
	one.x, one.y, one.z = s.x + s.dx * 2.2, s.y + s.dy * 2.2, s.z + s.dz * 2.2
	game:_fishAndEating()
	check(game.fish == before + 1 and near(game.food, 62), "a fish gives 12 food")
	check(not one.alive, "the fish is gone")
	-- a day passes
	game.dayTime = Rules.DAY_LENGTH - 0.01
	game:step(0.05, 0, 0, false)
	check(game.day == 2, "after 2 minutes day 2 begins")
	check(near(game.tail, Rules.TAIL_START + Rules.TAIL_PER_DAY), "her tail heals 8% a day")
	-- hurt three times in Gentle: Sam and the rescuers
	game.swimmer.invulnerable = 0
	game:hurt("test")
	check(game.lives == 2, "a hurt costs a heart")
	game:hurt("test")
	check(game.lives == 2, "no second hurt while she is safe for a moment")
	game.swimmer.invulnerable = 0
	game:hurt("test")
	game.swimmer.invulnerable = 0
	game:hurt("test")
	check(game.rescueLeft > 0 and not game.over, "out of hearts in Gentle: the rescuers come")
	game:step(Rules.RESCUE_TIME + 0.1, 0, 0, false)
	check(game.lives == 3 and game.food > 99.9 and game.rescueLeft <= 0, "after the rescue: full hearts and food")
	check(game.calmLeft > 9.5, "after the rescue the sharks leave her alone for a while")
	-- hunger in Hard ends the game
	local hard = Session.new(false, 12)
	hard.food = 0.5
	hard:step(0.5, 0, 0, false)
	check(hard.over and not hard.won, "in Hard, hunger ends the game")
	-- the last day
	local last = Session.new(true, 13)
	last.day = Rules.DAYS
	last.dayTime = Rules.DAY_LENGTH - 0.01
	last:step(0.05, 0, 0, false)
	check(last.over and last.won, "living through day 30 wins")
	-- messages
	local talk = Session.new(true, 14)
	check(#talk.messages == 2 and talk.messages[1].text == "Day 1. Good luck!", "the game greets her")
	check(string.find(talk.messages[2].text, "sonar", 1, true) ~= nil, "and points her to the sonar")
end

-- ---------- sharks and her Hit ----------
do
	local function flatDistance(a: any, b: any): number
		return math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
	end
	-- put a shark at a spot relative to her, facing her
	local function put(game: any, shark: any, ahead: number, up: number)
		local s = game.swimmer
		shark.x, shark.y, shark.z = s.x + s.dx * ahead, s.y + up, s.z + s.dz * ahead
		shark.dx, shark.dy, shark.dz = -s.dx, -s.dy, -s.dz
	end

	local gentle = Session.new(true, 21)
	local hard = Session.new(false, 22)
	check(#gentle.sharks == Rules.GENTLE_SHARKS and #hard.sharks == Rules.SHARKS, "4 sharks in Gentle, 8 in Hard")
	local closest = math.huge
	for _, shark in hard.sharks do
		closest = math.min(closest, flatDistance(shark, hard.swimmer))
	end
	check(closest > 30, "no shark starts close enough to chase her")
	check(gentle.calmLeft == Rules.GENTLE_CALM_START and hard.calmLeft == 0, "Gentle starts with 20 calm seconds")

	-- calm at the start of a Gentle game
	put(gentle, gentle.sharks[1], 12, 0)
	gentle:step(0.1, 0, 0, false)
	check(gentle.sharks[1].mood == "patrol", "no chase while it is calm")

	-- a shark that sees her circles first, and does not bite while it circles
	local shark = hard.sharks[1]
	put(hard, shark, 20, 0)
	hard:step(1 / 60, 0, 0, false)
	check(shark.mood == "chase" and shark.circleLeft > 0, "a shark within 30 m comes for her, circling first")
	local tip = false
	for _, m in hard.messages do
		tip = tip or string.find(m.text, "Press Hit (X)", 1, true) ~= nil
	end
	check(tip, "the first shark brings the tip about Hit and the pod")
	put(hard, shark, 2.6, 0)
	hard:step(1 / 60, 0, 0, false)
	check(hard.lives == 3, "no bite while it circles")
	-- then it bites
	shark.circleLeft = 0
	put(hard, shark, 2.6, 0)
	hard:step(1 / 60, 0, 0, false)
	check(hard.lives == 2 and shark.mood == "flee", "a bite costs a heart and the shark swims off")

	-- chase speed: faster with each level in Hard, never faster than her in Gentle
	local fast = Session.new(true, 23)
	fast.level = 20
	fast.calmLeft = 0
	local chaser = fast.sharks[1]
	put(fast, chaser, 20, 0)
	chaser.circleLeft = 0
	chaser.mood = "chase"
	local x0, z0 = chaser.x, chaser.z
	fast.swimmer.speed = 0
	fast:_moveSharks(0.1, true)
	local pace = math.sqrt((chaser.x - x0) ^ 2 + (chaser.z - z0) ^ 2) / 0.1
	check(pace <= fast.swimmer:cruiseSpeed() - Rules.SHARK_BELOW_HER + 0.05, "in Gentle a chasing shark is slower than her")

	-- Hit: nobody near, then a charge, then a hit
	local hit = Session.new(false, 24)
	for _, other in hit.sharks do
		other.x, other.z = 250, 250
	end
	hit:step(1 / 60, 0, 0, false)
	table.clear(hit.messages)
	hit:pressAttack()
	check(hit.attack == nil and hit.messages[1].text == "No sharks nearby", "Hit with no shark near says so")
	local mark = hit.sharks[1]
	put(hit, mark, 20, 0)
	mark.mood = "patrol"
	hit.calmLeft = 99
	hit:step(1 / 60, 0, 0, false)
	hit:pressAttack()
	check(hit.attack == mark and hit.attackCooldown == Rules.ATTACK_COOLDOWN, "Hit charges the nearest shark")
	local struck = false
	for _ = 1, 120 do
		hit:step(1 / 60, 0, 0, false)
		if mark.mood == "flee" then
			struck = true
			break
		end
	end
	check(struck and hit.driven == 1, "her charge reaches the shark and drives it off")
	check(hit.attack == nil and hit.safeLeft > 0, "after the hit she is safe for a moment")
	table.clear(hit.messages)
	hit:pressAttack()
	check(hit.messages[1].text == "Spring is gathering strength for another hit", "Hit needs 5 seconds to come back")
end

-- ---------- her family and her pod ----------
do
	local game = Session.new(true, 31)
	check(#game.pod == 0 and game.lost == nil, "she starts alone")
	table.clear(game.messages)
	game:pressPod()
	check(game.messages[1].text == "Your family isn't with you yet. Find them first!", "Pod before she has a family")
	-- day 2: someone is waiting
	game.dayTime = Rules.DAY_LENGTH - 0.01
	game:step(0.02, 0, 0, false)
	local lost = game.lost
	check(game.day == 2 and lost ~= nil and game:familyDue() == 0, "on day 2 someone from her family waits nearby")
	local s = game.swimmer
	assert(lost)
	local away = math.sqrt((lost.x - s.x) ^ 2 + (lost.z - s.z) ^ 2)
	check(away > 50 and away < 150, "about 60 to 140 m away")
	-- she swims to them
	s.x, s.y, s.z = lost.x + 3, lost.y, lost.z
	game:step(1 / 60, 0, 0, false)
	check(#game.pod == 1 and game.familyFound == 1 and game.lost == nil, "they join her pod")
	local joined = false
	for _, m in game.messages do
		joined = joined or m.text == "Your cousin found you!"
	end
	check(joined, "her cousin is first")
	-- the pod follows her
	for _ = 1, 180 do
		game:step(1 / 60, 0, 0, false)
	end
	local mate = game.pod[1]
	local ox, oy, oz = Rules.turn(mate.ox, mate.oy, mate.oz, s.yaw)
	-- it trails its place by speed / 2.4, about 4 m at her cruising speed
	check(math.sqrt((mate.x - s.x - ox) ^ 2 + (mate.z - s.z - oz) ^ 2) < 6, "the pod swims beside her")
	-- the pod chases a shark: under it, up into its belly, and away it goes
	game.calmLeft = 99
	for _, other in game.sharks do
		other.x, other.z = s.x + 200, s.z + 200
	end
	local shark = game.sharks[1]
	shark.x, shark.y, shark.z = s.x + s.dx * 25, math.max(s.y, game.bed:height(s.x + s.dx * 25, s.z + s.dz * 25) + 6), s.z + s.dz * 25
	shark.mood = "patrol"
	table.clear(game.effects)
	game:pressPod()
	check(shark.mood == "flee" and mate.rush == shark and game.podCooldown == Rules.POD_COOLDOWN, "Pod sends the family at the shark")
	local hitAt = nil
	local rolled = 0
	for i = 1, math.floor(Rules.POD_RUSH * 60) do
		game:step(1 / 60, 0, 0, false)
		if mate.struck >= 0 and hitAt == nil then
			hitAt = i / 60
		end
		rolled = math.max(rolled, math.abs(shark.roll))
	end
	local slow = false
	for _, e in game.effects do
		slow = slow or e.kind == "pod_hit"
	end
	check(hitAt ~= nil and slow, "a mate rams the shark within the rush (" .. tostring(hitAt) .. " s)")
	check(rolled > 2, "the hit rolls the shark over (" .. string.format("%.1f", rolled) .. " rad)")
	check(math.abs(shark.roll) < 0.01, "and it rights itself afterwards")
	table.clear(game.messages)
	game:pressPod()
	check(game.messages[1].text == "Your pod is resting, wait a little", "the pod rests 15 seconds")

	-- three found: a calf is born the next morning, grows on fish and joins the pod
	game.familyFound = 2
	game.lost = nil
	game.day = 7
	game.lostIndex = -1
	game:_checkFamily(false)
	check(game.lost == nil, "nobody waits between family days")
	game.day = 8
	game:_checkFamily(false)
	local next = game.lost
	assert(next)
	s.x, s.y, s.z = next.x, next.y, next.z
	game:_moveLost(1 / 60)
	check(game.familyFound == 3 and game.calfNext == 9, "after three family members a calf is due")
	game.dayTime = Rules.DAY_LENGTH - 0.01
	game:step(0.02, 0, 0, false)
	local calf = game.calf
	check(game.day == 9 and calf ~= nil, "a calf is born the next morning")
	assert(calf)
	check(calf.size < 0.5, "and it is small")
	for _ = 1, 45 do
		game:_feedCalf(15, 1)
	end
	check(game.calf == nil and #game.pod == 3 and game.raised == 1, "a grown calf joins the pod")

	-- her mother waits on the last day, and finding her wins
	local last = Session.new(true, 32)
	last.day = Rules.DAYS
	last:_checkFamily(true)
	local mother = last.lost
	check(last:familyDue() == #Session.FAMILY and mother ~= nil and mother.size == 1.0, "her mother waits on day 30")
	assert(mother)
	last.swimmer.x, last.swimmer.y, last.swimmer.z = mother.x, mother.y, mother.z
	last:_moveLost(1 / 60)
	check(last.over and last.won and last.reunited, "finding her mother wins")

	-- the level goes up every 25 fish
	local eater = Session.new(true, 33)
	table.clear(eater.messages)
	eater:eat(25, 0)
	check(eater.level == 2 and eater.messages[1].text == "Level 2! Sharks are faster", "Level 2 after 25 fish")
end

-- ---------- language ----------
do
	Lang.language = "ru"
	check(Lang.t("Food") == "Еда", "Russian")
	check(Lang.f("Day %d of %d", 3, 30) == "День 3 из 30", "Russian with numbers")
	local dash = false
	for _, key in Lang.keys() do
		local ru = Lang.t(key)
		if string.find(ru, "—", 1, true) or string.find(key, "—", 1, true) then
			dash = true
		end
	end
	check(not dash, "no em dash in game text")
	Lang.language = "en"
	check(Lang.t("Food") == "Food", "English by default")
end

print(string.format("%d checks passed, %d failed", passed, failed))
if failed > 0 then
	error("tests failed")
end
