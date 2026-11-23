--!strict
-- Splashes when she leaps and lands, bubbles when she catches a fish.
-- Uses Roblox's built-in particle pictures, so nothing has to be uploaded.

local Debris = game:GetService("Debris")
local World = require(script.Parent.World)

local Effects = {}

local S = World.S

local function burst(at: Vector3, setup: (ParticleEmitter) -> (), count: number, parent: Instance)
	local holder = Instance.new("Part")
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.Transparency = 1
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.CFrame = CFrame.new(at)
	holder.Parent = parent
	local emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	setup(emitter)
	emitter.Parent = holder
	emitter:Emit(count)
	Debris:AddItem(holder, 4)
end

function Effects.play(kind: string, x: number, y: number, z: number, count: number, parent: Instance)
	if kind == "splash" then
		burst(World.point(x, 18, z), function(e: ParticleEmitter)
			e.Texture = "rbxasset://textures/particles/smoke_main.dds"
			e.Color = ColorSequence.new(Color3.fromRGB(245, 252, 255))
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6 * S), NumberSequenceKeypoint.new(1, 1.6 * S) })
			e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
			e.Lifetime = NumberRange.new(0.6, 1.1)
			e.Speed = NumberRange.new(4 * S, 8 * S)
			e.SpreadAngle = Vector2.new(35, 35)
			e.EmissionDirection = Enum.NormalId.Top
			e.Acceleration = Vector3.new(0, -14 * S, 0)
			e.Drag = 1
		end, 30 * count, parent)
	elseif kind == "bubbles" then
		burst(World.point(x, y, z), function(e: ParticleEmitter)
			e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			e.Color = ColorSequence.new(Color3.fromRGB(225, 248, 255))
			e.LightEmission = 0.5
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18 * S), NumberSequenceKeypoint.new(1, 0.05 * S) })
			e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
			e.Lifetime = NumberRange.new(0.8, 1.6)
			e.Speed = NumberRange.new(0.5 * S, 2 * S)
			e.SpreadAngle = Vector2.new(180, 180)
			e.Acceleration = Vector3.new(0, 3 * S, 0)
		end, 6 * count, parent)
	end
end

return Effects
