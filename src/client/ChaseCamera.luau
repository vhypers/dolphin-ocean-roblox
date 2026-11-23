--!strict
-- Behind the dolphin, through her eyes (View) or looking back (Back). Comes up for a look when
-- she breathes or leaps. A port of the Godot game's scripts/chase_camera.gd, in metres.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rules = require(ReplicatedStorage:WaitForChild("Spring"):WaitForChild("Rules"))
local World = require(script.Parent:WaitForChild("World"))

local SEA = Rules.SEA_LEVEL
local DISTANCE = 6.3
local LIFT = 1.7

local ChaseCamera = {}
ChaseCamera.__index = ChaseCamera

export type ChaseCamera = typeof(setmetatable(
	{} :: {
		x: number,
		y: number,
		z: number,
		fov: number,
		above: boolean,
		firstPerson: boolean,
		backwards: boolean,
		lookYaw: number,
		lookPitch: number,
		basePitch: number,
		atSurface: number,
		shake: number,
		-- 0 to 1: how far up above the pod's fight the camera has risen, and what it watches
		overhead: number,
		focusX: number,
		focusY: number,
		focusZ: number,
		span: number,
	},
	ChaseCamera
))

function ChaseCamera.new(): ChaseCamera
	return setmetatable({
		x = 0,
		y = 0,
		z = 0,
		fov = 65,
		above = false,
		firstPerson = false,
		backwards = false,
		lookYaw = 0,
		lookPitch = 0,
		basePitch = 0,
		atSurface = 0,
		shake = 0,
		overhead = 0,
		focusX = 0,
		focusY = 0,
		focusZ = 0,
		span = 10,
	}, ChaseCamera)
end

-- Up above the fight, behind her heading so forward stays up the screen, far enough to hold
-- everyone. Steep like a helicopter where the water is deep enough; flatter near the surface.
function ChaseCamera._helicopter(self: ChaseCamera, s: any, ceiling: number): (number, number, number)
	local hx, hz = math.sin(s.yaw), math.cos(s.yaw)
	local reach = Rules.clamp(self.span * 1.3 + 7.0, 13.0, 34.0)
	local pitch = math.rad(66.0)
	local rise = reach * math.sin(pitch)
	local room = ceiling - self.focusY
	if rise > room then
		rise = math.max(room, 2.5)
		pitch = math.asin(Rules.clamp(rise / reach, 0.2, 1.0))
	end
	local back = reach * math.cos(pitch)
	return self.focusX - hx * back, self.focusY + rise, self.focusZ - hz * back
end

function ChaseCamera.snapBehind(self: ChaseCamera, s: any)
	self.above = false
	self.atSurface = 0
	self.lookYaw = 0
	self.lookPitch = 0
	self.basePitch = 0
	local k = if self.backwards then -1 else 1
	self.x = s.x - s.dx * k * DISTANCE
	self.y = s.y - s.dy * k * DISTANCE + LIFT
	self.z = s.z - s.dz * k * DISTANCE
end

function ChaseCamera.bump(self: ChaseCamera)
	self.shake = 0.45
end

-- never sit in the waterline: go to whichever side we are heading for
function ChaseCamera._outOfWaterline(self: ChaseCamera, bed: any, time: number, wave: number, clearance: number)
	local surface = SEA + Rules.waveHeight(self.x, self.z, time, wave)
	local ground = bed:height(self.x, self.z)
	if self.above then
		self.y = math.max(self.y, math.max(surface + 0.5, ground + 1.0))
	else
		self.y = math.min(math.max(self.y, ground + clearance), surface - 0.5)
	end
end

-- returns the camera frame (studs) and field of view
function ChaseCamera.follow(
	self: ChaseCamera,
	dt: number,
	s: any,
	steerX: number,
	steerY: number,
	time: number,
	wave: number,
	playing: boolean
): (CFrame, number)
	local bed = s.bed
	local k = 1.0 - math.exp(-6.0 * dt)
	local back = self.backwards and playing
	-- during a slow-motion jump steering looks around
	local lookX = if s.jumping then steerX else 0
	local lookY = if s.jumping then steerY else 0
	self.lookYaw += (-lookX * 2.7 - self.lookYaw) * k
	self.lookPitch += (lookY * 1.25 - self.lookPitch) * k
	local tiltTo = if s.jumping then 0.0 else s.pitch * (if back then -0.85 else 0.85)
	self.basePitch += (tiltTo - self.basePitch) * k
	local yaw = s.yaw - self.lookYaw + (if back then math.pi else 0.0)
	local tilt = Rules.clamp(self.basePitch + self.lookPitch, -1.35, 1.35)
	local ax, ay, az = math.sin(yaw) * math.cos(tilt), math.sin(tilt), math.cos(yaw) * math.cos(tilt)

	self.atSurface = if s.y > SEA - 1.2 and s.pitch > -0.2 then self.atSurface + dt else 0.0
	local high = Rules.smoothstep(0.0, 1.0, self.overhead)
	if high > 0.5 then
		self.above = false -- the helicopter view stays under the water, looking down
		self.atSurface = 0.0
	elseif not self.above then
		self.above = (s.jumping and s.y > SEA) or self.atSurface > 0.35
	elseif not s.jumping then
		self.above = s.y > SEA - 1.7 and s.pitch > -0.3
	end

	local fx, fy, fz
	if self.firstPerson and playing and high <= 0.0 then
		local forward = if back then 0.3 else 2.4
		self.x = s.x + s.dx * forward
		self.y = s.y + s.dy * forward + (if back then 0.75 else 0.35)
		self.z = s.z + s.dz * forward
		if self.above and not s.jumping then
			self.y = math.max(self.y, SEA + 0.6)
		end
		self:_outOfWaterline(bed, time, wave, 0.4)
		fx, fy, fz = self.x + ax, self.y + ay, self.z + az
	else
		local tx, ty, tz = s.x - ax * DISTANCE, s.y - ay * DISTANCE + LIFT, s.z - az * DISTANCE
		local margin = 1.2 + math.max(wave - 1.0, 0.0) * 0.5
		if high > 0.0 then
			local hx, hy, hz = self:_helicopter(s, SEA - margin - 0.4)
			tx, ty, tz = tx + (hx - tx) * high, ty + (hy - ty) * high, tz + (hz - tz) * high
		end
		ty = if self.above then math.max(ty, SEA + 2.7) else math.min(ty, SEA - margin)
		local m = 1.0 - math.exp(-Rules.lerp(5.0, 4.0, high) * dt)
		self.x += (tx - self.x) * m
		self.y += (ty - self.y) * m
		self.z += (tz - self.z) * m
		if not self.above then
			self.x, self.y, self.z = bed:pushOut(self.x, self.y, self.z, 0.8, SEA - margin)
		end
		self:_outOfWaterline(bed, time, wave, 0.8)
		fx, fy, fz = s.x + ax * 6.0, s.y + ay * 6.0 + 0.8, s.z + az * 6.0
		if self.above and not s.jumping then
			fy = math.max(fy, SEA - 0.2)
		end
		fx += (self.focusX - fx) * high
		fy += (self.focusY - fy) * high
		fz += (self.focusZ - fz) * high
	end

	local wanted = Rules.clamp(65.0 + (s.speed - Rules.CRUISE_SPEED) * 0.55, 63.0, 74.0)
	self.fov += (wanted - self.fov) * math.min(1.0, 3.0 * dt)
	local eye = World.point(self.x, self.y, self.z)
	if self.shake > 0 then
		self.shake -= dt
		eye += Vector3.new(math.random() * 0.4 - 0.2, math.random() * 0.4 - 0.2, 0) * World.S
	end
	local focus = World.point(fx, fy, fz)
	if (focus - eye).Magnitude < 0.01 then
		focus = eye + Vector3.new(0, 0, 1)
	end
	return CFrame.lookAt(eye, focus), self.fov
end

return ChaseCamera
