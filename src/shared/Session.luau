--!strict
-- The rules of one game, without graphics: days, hearts, food, air, fish, her hurt tail and
-- the rescue in Gentle. Ported from the Godot game's scripts/game_session.gd; sharks, the pod,
-- Sam, tasks and the other oceans arrive in later steps.

local Rules = if script then require(script.Parent.Rules) else require("./Rules")
local Lang = if script then require(script.Parent.Lang) else require("./Lang")
local SeaFloor = if script then require(script.Parent.SeaFloor) else require("./SeaFloor")
local Swimmer = if script then require(script.Parent.Swimmer) else require("./Swimmer")
local Schools = if script then require(script.Parent.Schools) else require("./Schools")

local SEA = Rules.SEA_LEVEL

local Session = {}
Session.__index = Session

export type Message = { kind: string, text: string, big: boolean, seconds: number }
export type Effect = { kind: string, x: number, y: number, z: number, count: number }

export type Session = typeof(setmetatable(
	{} :: {
		gentle: boolean,
		ocean: number,
		bed: SeaFloor.SeaFloor,
		swimmer: Swimmer.Swimmer,
		schools: Schools.Schools,
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
		_wasNight: boolean,
	},
	Session
))

function Session.new(gentle: boolean, seed: number?): Session
	local bed = SeaFloor.new(0)
	local self = setmetatable({
		gentle = gentle,
		ocean = 0,
		bed = bed,
		swimmer = Swimmer.new(bed),
		schools = Schools.new(bed, 0, seed),
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
		_wasNight = false,
	}, Session)
	self:_connect()
	self.swimmer.strength = self.tail
	self:banner(Lang.f("Day %d. Good luck!", self.day), true)
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

-- steerX is right, steerY is up; dt is already slowed during a jump
function Session.step(self: Session, dt: number, steerX: number, steerY: number, boost: boolean)
	if self.over then
		return
	end
	self.time += dt
	if self.rescueLeft > 0.0 then
		self.rescueLeft -= dt
		if self.rescueLeft <= 0.0 then
			self:_finishRescue()
		end
		return
	end
	self.swimmer.strength = self.tail
	self.swimmer:step(dt, steerX, steerY, boost)
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
	local s = self.swimmer
	self.schools:advance(dt, s.x, s.y, s.z)
	self:_fishAndEating()
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

function Session._fishAndEating(self: Session)
	local s = self.swimmer
	local hx, hy, hz = s.x + s.dx * 2.2, s.y + s.dy * 2.2, s.z + s.dz * 2.2
	for _, school in self.schools.list do
		if school.alive > 0 then
			local away = math.sqrt((school.cx - s.x) ^ 2 + (school.cy - s.y) ^ 2 + (school.cz - s.z) ^ 2)
			if away < 20.0 then
				for _, one in school.fish do
					if one.alive and (one.x - hx) ^ 2 + (one.y - hy) ^ 2 + (one.z - hz) ^ 2 < 5.8 then
						one.alive = false
						school.alive -= 1
						if school.alive <= 0 then
							school.timer = 4.0
						end
						self:effect("bubbles", one.x, one.y, one.z, 4)
						self:eat(1, school.species)
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
	if math.floor(self.fish / Rules.FISH_PER_LEVEL) + 1 > self.level then
		self.level += 1 -- sharks get faster with each level once they arrive
	end
end

function Session.pressJump(self: Session)
	if self.over or self.swimmer.jumping or self.rescueLeft > 0 then
		return
	end
	if not self.swimmer:requestJump() then
		self:say(Lang.t("Swimming up to jump!"), 2.0)
	end
end

function Session.hurt(self: Session, reason: string?)
	if self.over or self.swimmer.invulnerable > 0.0 then
		return
	end
	self.lives -= 1
	self.swimmer.invulnerable = if self.gentle then Rules.GENTLE_INVULNERABLE else Rules.INVULNERABLE
	local why = reason or ""
	if self.lives <= 0 and self.gentle then
		self.lives = 0
		self:_rescue(why)
	elseif self.lives <= 0 then
		self:_end(false, why)
	elseif why ~= "" then
		self:banner(why, false)
	end
end

function Session._rescue(self: Session, reason: string)
	self.rescues += 1
	self.rescueLeft = Rules.RESCUE_TIME
	self.rescueReason = reason
	self.swimmer.jumping = false
	self.swimmer.autoJump = false
end

function Session._finishRescue(self: Session)
	self.lives = Rules.LIVES
	self.food = Rules.FOOD_MAX
	local s = self.swimmer
	local x, _, z = self.bed:pushOut(s.x + 7, s.y, s.z, 1.6, SEA - 1.1)
	s:reset(x, SEA - 2.0, z, s.yaw)
	self:banner(Lang.t("Sam and the rescuers helped you. Swim on!"), true)
end

function Session._end(self: Session, victory: boolean, reason: string)
	self.over = true
	self.won = victory
	self.rescueReason = reason
end

return Session
