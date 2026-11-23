--!strict
-- A small seeded random number generator (xorshift32) that works both in Roblox and in the
-- Luau command-line tool, so tests and the game make the same choices for the same seed.

local Rng = {}
Rng.__index = Rng

export type Rng = typeof(setmetatable({} :: { state: number }, Rng))

function Rng.new(seed: number?): Rng
	local s = seed or 1
	if s < 0 then
		s = -s
	end
	local state = bit32.band(math.floor(s * 2654435761 + 12345), 0xFFFFFFFF)
	if state == 0 then
		state = 0x9E3779B9
	end
	local self = setmetatable({ state = state }, Rng)
	for _ = 1, 4 do
		self:nextInt()
	end
	return self
end

function Rng.nextInt(self: Rng): number
	local x = self.state
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	self.state = x
	return x
end

-- 0 <= randf() < 1
function Rng.randf(self: Rng): number
	return self:nextInt() / 4294967296
end

function Rng.range(self: Rng, a: number, b: number): number
	return a + (b - a) * self:randf()
end

-- a whole number from 0 to n - 1
function Rng.below(self: Rng, n: number): number
	return math.floor(self:randf() * n)
end

return Rng
