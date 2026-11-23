--!strict
-- Numbers from the Godot game's scripts/ocean_rules.gd (which come from docs/GAME_DESIGN.md).
-- Game logic works in metres, in the same coordinates as the Godot game: sea level is y = 18.
-- Only the views turn metres into Roblox studs (STUDS per metre, sea level at y = 0).

local Rules = {}

Rules.STUDS = 3 -- studs per metre in the Roblox world

Rules.SEA_LEVEL = 18.0
Rules.WORLD_RADIUS = 300.0

Rules.DAY_LENGTH = 120.0
Rules.DAYS = 30
Rules.DAY_OFFSET = 0.1
Rules.NIGHT_FROM = 0.78

Rules.AIR_MAX = 60.0
Rules.AIR_REFILL_TIME = 1.2
Rules.AIR_LOW = 20.0
Rules.AIR_AFTER_HURT = 15.0
Rules.BREATH_DEPTH = 1.5
Rules.FOOD_MAX = 100.0
Rules.FOOD_EMPTY_AFTER = 80.0
Rules.FOOD_LOW = 25.0
Rules.FOOD_PER_FISH = 12.0
Rules.LIVES = 3
Rules.INVULNERABLE = 2.2

Rules.CRUISE_SPEED = 11.0
Rules.BOOST_SPEED = 23.0
Rules.ATTACK_SPEED = 26.0
Rules.RIDE_SPEED = 18.0
Rules.BOOST_DRAIN = 0.33
Rules.BOOST_REFILL = 0.13
Rules.TURN_RATE = 1.8
Rules.PITCH_RATE = 1.05
Rules.GRAVITY = 18.0
Rules.JUMP_SLOW_MOTION = 0.33
Rules.UNDER_ICE = 2.4

-- sharks, her Hit and her pod
Rules.SHARKS = 8
Rules.ATTACK_COOLDOWN = 5.0
Rules.ATTACK_TIME = 2.6
Rules.ATTACK_RANGE = 42.0
Rules.ATTACK_SAFE_AFTER = 0.7
Rules.POD_COOLDOWN = 15.0
Rules.POD_RANGE = 55.0
Rules.POD_RUSH = 3.2
Rules.POD_RUSH_SPEED = 32.0 -- fast enough to reach a fleeing shark at the edge of POD_RANGE in time
Rules.POD_KNOCK = 9.0 -- the hit throws the shark aside
Rules.POD_STUN = 0.6 -- and it reels for a moment
Rules.POD_BELOW = 3.2 -- mates dive this far under the shark, then ram its belly from below
Rules.POD_RAM_REACH = 2.2 -- a ramming mate this close hits
Rules.POD_TUMBLE = 9.0 -- radians a second the hit rolls the shark over
Rules.POD_BURST = 2.0 -- seconds the shark then races away
Rules.POD_BURST_SPEED = 17.0
Rules.POD_TRAIL_EVERY = 0.05 -- a charging mate leaves bubbles this often
Rules.POD_SLOW_MOTION = 0.5 -- time runs at half speed for the moment of the first hit
Rules.POD_SLOW_SECONDS = 0.9
Rules.POD_START = 0 -- Spring lost her pod; she finds her family one by one
-- where each pod member swims, relative to her (metres, in her own turn: y up, z ahead)
Rules.POD_SLOTS = {
	{ -3.6, 0.6, -5 },
	{ 3.6, -0.4, -6 },
	{ -2.2, 1.8, -10 },
	{ 2.6, -1.6, -11 },
	{ 0, 2.4, -14 },
	{ -5, -1.2, -13 },
	{ 5, 1, -15 },
	{ -7.5, 0.5, -9 },
	{ 7.5, -0.6, -10 },
}
Rules.CIRCLE_GENTLE = 1.5 -- seconds a shark circles her before it comes in
Rules.CIRCLE_HARD = 1.4
Rules.CIRCLE_RADIUS = 10.0

-- the story: her hurt tail and her family
Rules.TAIL_START = 0.6
Rules.TAIL_PER_DAY = 0.08
Rules.TAIL_PER_CORAL = 0.12
-- days on which someone from her family is waiting nearby; her mother waits on the last day
Rules.FAMILY_DAYS = { 2, 5, 8, 11, 14, 17, 21 }
Rules.FAMILY_MEET = 8.0
Rules.CALF_AFTER_FAMILY = 3 -- a calf is born once this many have found her
Rules.CALF_GROWTH = 45.0
Rules.CALF_EMPTY_AFTER = 170.0
Rules.CALF_OFFSET = { 1.7, -0.25, -1.3 }

-- gentle difficulty (the kit's rules are "hard")
Rules.GENTLE_FOOD_EMPTY_AFTER = 150.0
Rules.GENTLE_INVULNERABLE = 4.0
Rules.GENTLE_SHARKS = 4
Rules.GENTLE_CALM_START = 20.0 -- no shark chases at the start of a game
Rules.SHARK_BELOW_HER = 1.5 -- in gentle, chasing sharks stay this much slower than she cruises
Rules.RESCUE_TIME = 3.5
Rules.CALM_AFTER_RESCUE = 10.0

Rules.SPIN_RATE = 9.0 -- radians a second while she holds Boost in the air
Rules.FISH_PER_LEVEL = 25

-- ---------- helpers that behave like Godot's ----------

local PI = math.pi
local TAU = 2 * math.pi
Rules.TAU = TAU

function Rules.clamp(v: number, lo: number, hi: number): number
	if v < lo then
		return lo
	elseif v > hi then
		return hi
	end
	return v
end

function Rules.lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

function Rules.smoothstep(a: number, b: number, x: number): number
	if a == b then
		return if x < a then 0 else 1
	end
	local y = Rules.clamp((x - a) / (b - a), 0, 1)
	return y * y * (3 - 2 * y)
end

function Rules.fposmod(x: number, y: number): number
	local v = math.fmod(x, y)
	if (v < 0 and y > 0) or (v > 0 and y < 0) then
		v += y
	end
	return v
end

function Rules.wrap(value: number, lo: number, hi: number): number
	local range = hi - lo
	if range == 0 then
		return lo
	end
	return value - range * math.floor((value - lo) / range)
end

function Rules.angleDifference(from: number, to: number): number
	local difference = math.fmod(to - from, TAU)
	return math.fmod(2 * difference, TAU) - difference
end

function Rules.lerpAngle(from: number, to: number, weight: number): number
	return from + Rules.angleDifference(from, to) * weight
end

function Rules.rotateToward(from: number, to: number, delta: number): number
	local difference = Rules.angleDifference(from, to)
	local absDifference = math.abs(difference)
	local step = Rules.clamp(delta, absDifference - PI, absDifference)
	return from + step * (if difference >= 0 then 1 else -1)
end

function Rules.sign(v: number): number
	return if v > 0 then 1 elseif v < 0 then -1 else 0
end

-- Must match the Godot game's wave_height(); here it only keeps the camera out of the waterline.
function Rules.waveHeight(x: number, z: number, t: number, amp: number?): number
	local a = amp or 1.0
	return (
		0.26 * math.sin(x * 0.16 + t * 1.3)
		+ 0.19 * math.sin(z * 0.23 + t * 1.05 + x * 0.05)
		+ 0.09 * math.sin((x + z) * 0.55 + t * 2.3)
		+ 0.05 * math.sin((x * 0.8 - z) * 0.9 + t * 2.9)
	) * a
end

-- an offset in her own turn (y up, z ahead) turned with her heading, like Godot's rotated(UP, yaw)
function Rules.turn(x: number, y: number, z: number, yaw: number): (number, number, number)
	local c, s = math.cos(yaw), math.sin(yaw)
	return x * c + z * s, y, -x * s + z * c
end

function Rules.isNight(dayTime: number): boolean
	return Rules.fposmod(dayTime / Rules.DAY_LENGTH + Rules.DAY_OFFSET, 1.0) > Rules.NIGHT_FROM
end

return Rules
