--!strict
-- The player's body: swimming, jumping and breathing. A line-by-line port of the Godot game's
-- scripts/swimmer.gd (lunging and currents arrive with the sharks and oceans in later steps).
-- Positions are metres in the Godot game's coordinates; yaw 0 faces +z.

local Rules = if script then require(script.Parent.Rules) else require("./Rules")
local SeaFloor = if script then require(script.Parent.SeaFloor) else require("./SeaFloor")

local SEA = Rules.SEA_LEVEL
local clamp = Rules.clamp

local Swimmer = {}
Swimmer.__index = Swimmer

Swimmer.START = { 0, -4, 0 }

export type Swimmer = typeof(setmetatable(
	{} :: {
		bed: SeaFloor.SeaFloor,
		x: number,
		y: number,
		z: number,
		dx: number, -- direction (unit)
		dy: number,
		dz: number,
		yaw: number,
		pitch: number,
		roll: number,
		speed: number,
		energy: number,
		air: number,
		invulnerable: number,
		strength: number,
		speedScale: number,
		jumping: boolean,
		autoJump: boolean,
		boosting: boolean,
		vx: number, -- jump velocity
		vy: number,
		vz: number,
		listeners: { [string]: (...any) -> () },
		_spinHeld: boolean,
		_spun: number,
		_wasBreathing: boolean,
		_lowWarned: boolean,
		_edgeQuiet: number,
	},
	Swimmer
))

function Swimmer.new(bed: SeaFloor.SeaFloor): Swimmer
	local self = setmetatable({
		bed = bed,
		x = 0,
		y = 0,
		z = 0,
		dx = 0,
		dy = 0,
		dz = 1,
		yaw = 0,
		pitch = 0,
		roll = 0,
		speed = Rules.CRUISE_SPEED,
		energy = 1,
		air = Rules.AIR_MAX,
		invulnerable = 0,
		strength = 1,
		speedScale = 1,
		jumping = false,
		autoJump = false,
		boosting = false,
		vx = 0,
		vy = 0,
		vz = 0,
		listeners = {},
		_spinHeld = false,
		_spun = 0,
		_wasBreathing = false,
		_lowWarned = false,
		_edgeQuiet = 0,
	}, Swimmer)
	self:reset()
	return self
end

-- signals: jumped, splashed(x, y, z), breathed, air_low, suffocated, edge_reached, landed(spins)
function Swimmer.emit(self: Swimmer, name: string, ...: any)
	local listener = self.listeners[name]
	if listener then
		listener(...)
	end
end

function Swimmer.reset(self: Swimmer, x: number?, y: number?, z: number?, heading: number?)
	self.x = x or Swimmer.START[1]
	self.y = y or Swimmer.START[2]
	self.z = z or Swimmer.START[3]
	self.yaw = heading or 0
	self.pitch = 0
	self.roll = 0
	self.speed = Rules.CRUISE_SPEED
	self.energy = 1
	self.air = Rules.AIR_MAX
	self.invulnerable = 0
	self.jumping = false
	self.autoJump = false
	self.boosting = false
	self._wasBreathing = false
	self._lowWarned = false
	self._edgeQuiet = 0
	self:_updateDirection()
end

-- a jump counts as breathing
function Swimmer.isBreathing(self: Swimmer): boolean
	return self.jumping or self.y > SEA - Rules.BREATH_DEPTH
end

-- returns false when the dolphin first has to swim up
function Swimmer.requestJump(self: Swimmer): boolean
	if self.jumping then
		return true
	end
	if self.y > SEA - 7.0 then
		self:_jump()
		return true
	end
	self.autoJump = true
	return false
end

function Swimmer.cruiseSpeed(self: Swimmer): number
	return Rules.CRUISE_SPEED * (0.78 + 0.22 * self.strength)
end

-- steerX is right, steerY is up, both from -1 to 1
function Swimmer.step(self: Swimmer, dt: number, steerX: number, steerY: number, wantBoost: boolean)
	steerX = clamp(steerX, -1, 1)
	steerY = clamp(steerY, -1, 1)
	if not self.jumping then
		self.yaw -= steerX * Rules.TURN_RATE * dt
		if math.abs(steerY) > 0.05 then
			self.pitch += steerY * Rules.PITCH_RATE * dt
		else
			self.pitch *= 1.0 - math.min(1.0, 1.5 * dt)
		end
		self.pitch = clamp(self.pitch, -1.0, 1.0)
		self.roll += (steerX * 0.65 - self.roll) * math.min(1.0, 5.0 * dt)
		if self.autoJump then
			self.pitch += (0.9 - self.pitch) * math.min(1.0, 3.0 * dt)
		end
	end
	local manual = self.autoJump or (wantBoost and self.energy > 0.0)
	self.boosting = manual
	self.energy = clamp(self.energy + (if manual then -Rules.BOOST_DRAIN else Rules.BOOST_REFILL) * dt, 0.0, 1.0)
	local topSpeed = self:cruiseSpeed() * self.speedScale
	if manual then
		topSpeed = Rules.BOOST_SPEED * (0.7 + 0.3 * self.strength)
	end
	self.speed += (topSpeed - self.speed) * math.min(1.0, 3.0 * dt)
	self._spinHeld = wantBoost
	if self.jumping then
		self:_fly(dt)
	else
		self:_swim(dt)
	end
	self:_stayInWorld(dt)
	self:_breathe(dt)
	self.invulnerable = math.max(self.invulnerable - dt, 0.0)
end

function Swimmer._swim(self: Swimmer, dt: number)
	self:_updateDirection()
	self.x += self.dx * self.speed * dt
	self.y += self.dy * self.speed * dt
	self.z += self.dz * self.speed * dt
	self.x, self.y, self.z = self.bed:pushOut(self.x, self.y, self.z, 1.6, SEA - 1.1)
	if self.autoJump and self.y > SEA - 7.0 then
		self:_jump()
		return
	end
	local bed = self.bed:height(self.x, self.z)
	local aheadX = self.x + math.sin(self.yaw) * 1.8
	local aheadZ = self.z + math.cos(self.yaw) * 1.8
	local lowest = math.min(math.max(bed, self.bed:height(aheadX, aheadZ) - 0.3) + 1.6, SEA - 0.9)
	if self.y < lowest then
		self.y = lowest
		if self.pitch < 0.0 then
			self.pitch *= 0.8
		end
	end
	if self.y > SEA - 0.9 then
		if self.pitch > 0.25 and self.speed > 9.5 then
			self.jumping = true
			self._spun = 0.0
			self.autoJump = false
			self.vx = self.dx * self.speed * 1.05
			self.vy = math.max(self.dy * self.speed * 1.05, 14.0)
			self.vz = self.dz * self.speed * 1.05
			self:emit("splashed", self.x, self.y, self.z)
			self:emit("jumped")
		else
			self.y = SEA - 0.9
			if self.pitch > 0.0 then
				self.pitch *= 0.8
			end
		end
	end
end

function Swimmer._jump(self: Swimmer)
	self._spun = 0.0
	self.jumping = true
	self.autoJump = false
	local forward = math.max(self.speed, 15.0)
	local lift = 16.0 + math.max(0.0, SEA - 0.9 - self.y) * 1.7
	self.vx = math.sin(self.yaw) * forward
	self.vy = lift
	self.vz = math.cos(self.yaw) * forward
	if self.y > SEA - 2.0 then
		self:emit("splashed", self.x, self.y, self.z)
	end
	self:emit("jumped")
end

function Swimmer._fly(self: Swimmer, dt: number)
	self.vy -= Rules.GRAVITY * dt
	local flat = math.sqrt(self.vx * self.vx + self.vz * self.vz)
	if flat > 0.5 then
		self.yaw = math.atan2(self.vx, self.vz)
	end
	self.pitch = math.atan2(self.vy, math.max(flat, 0.01))
	if self._spinHeld then
		-- holding Boost in the air: a spin round her own length
		self.roll += Rules.SPIN_RATE * dt
		self._spun += Rules.SPIN_RATE * dt
	else
		self.roll = Rules.wrap(self.roll, -math.pi, math.pi) * (1.0 - math.min(1.0, 3.0 * dt))
	end
	self.x += self.vx * dt
	self.y += self.vy * dt
	self.z += self.vz * dt
	local px, py, pz = self.bed:pushOut(self.x, self.y, self.z, 1.6, SEA - 1.1)
	if px ~= self.x or pz ~= self.z then
		self.x, self.y, self.z = px, py, pz
		self.vx *= 0.4
		self.vz *= 0.4
	end
	self:_updateDirection()
	if self.y < SEA - 0.4 and self.vy < 0.0 then
		self.jumping = false
		self.roll = Rules.wrap(self.roll, -math.pi, math.pi)
		local spins = math.floor((self._spun + 0.6) / Rules.TAU)
		self._spun = 0.0
		self:emit("landed", spins)
		self.speed = math.max(10.0, math.sqrt(self.vx ^ 2 + self.vy ^ 2 + self.vz ^ 2) * 0.85)
		self.pitch = math.max(-0.9, self.pitch)
		self:emit("splashed", self.x, self.y, self.z)
	end
end

function Swimmer._stayInWorld(self: Swimmer, dt: number)
	self._edgeQuiet = math.max(self._edgeQuiet - dt, 0.0)
	local distance = math.sqrt(self.x * self.x + self.z * self.z)
	if distance > Rules.WORLD_RADIUS then
		local k = Rules.WORLD_RADIUS / distance
		self.x *= k
		self.z *= k
		self.yaw = Rules.rotateToward(self.yaw, math.atan2(-self.x, -self.z), 1.5 * dt)
		if self._edgeQuiet <= 0.0 then
			self._edgeQuiet = 5.0
			self:emit("edge_reached")
		end
	end
end

function Swimmer._breathe(self: Swimmer, dt: number)
	local breathing = self:isBreathing()
	if breathing then
		if not self._wasBreathing and self.air < Rules.AIR_MAX - 3.0 then
			self:emit("breathed")
		end
		self.air = math.min(Rules.AIR_MAX, self.air + Rules.AIR_MAX * dt / Rules.AIR_REFILL_TIME)
		self._lowWarned = false
	else
		self.air -= dt
		if self.air < Rules.AIR_LOW and not self._lowWarned then
			self._lowWarned = true
			self:emit("air_low")
		end
		if self.air <= 0.0 then
			self.air = Rules.AIR_AFTER_HURT
			self:emit("suffocated")
		end
	end
	self._wasBreathing = breathing
end

function Swimmer._updateDirection(self: Swimmer)
	local cp = math.cos(self.pitch)
	self.dx = math.sin(self.yaw) * cp
	self.dy = math.sin(self.pitch)
	self.dz = math.cos(self.yaw) * cp
end

return Swimmer
