--!strict
-- Draws every school: each fish is a two-tone body and a wagging tail, in its species' colours
-- from the kit. Fish far away or eaten are hidden.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Data = require(ReplicatedStorage:WaitForChild("Spring"):WaitForChild("Data"))
local World = require(script.Parent.World)

local FishView = {}
FishView.__index = FishView

local S = World.S
local HIDDEN = CFrame.new(0, -400, 0) -- under the sea floor, above where Roblox removes fallen parts

-- body depth as a share of length, from the Godot game's AnimalShapes.FISH
local DEPTH = { 0.26, 0.2, 0.36, 0.46, 0.42, 0.32, 0.38, 0.32, 0.22, 0.3, 0.22, 0.24 }

type Look = { top: BasePart, bottom: BasePart, tail: BasePart, length: number, shown: boolean }

export type FishView = typeof(setmetatable(
	{} :: {
		folder: Folder,
		looks: { { Look } },
		parts: { BasePart },
		frames: { CFrame },
	},
	FishView
))

local function hex(text: string?): Color3
	if text == nil then
		return Color3.new(1, 1, 1)
	end
	return Color3.fromHex(text)
end

local function ellipsoid(size: Vector3, color: Color3, parent: Instance): BasePart
	local part = Instance.new("Part")
	part.Size = size * S
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.CFrame = HIDDEN
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	part.Parent = parent
	return part
end

function FishView.new(schools: any, parent: Instance): FishView
	local folder = Instance.new("Folder")
	folder.Name = "Fish"
	local looks = {}
	for _, school in schools.list do
		local species = Data.species[school.species + 1]
		local length = species.length
		local depth = length * DEPTH[school.species + 1]
		local width = math.max(length * 0.13, depth * 0.36)
		local top, bottom, fin = hex(species.top), hex(species.bottom), hex(species.fin)
		local mid = if species.mid then hex(species.mid) else top:Lerp(bottom, 0.5)
		local list = {}
		for _ in school.fish do
			table.insert(list, {
				top = ellipsoid(Vector3.new(width, depth * 0.7, length * 0.78), top:Lerp(mid, 0.25), folder),
				bottom = ellipsoid(Vector3.new(width * 0.92, depth * 0.62, length * 0.72), bottom, folder),
				tail = ellipsoid(Vector3.new(width * 0.25, depth * 0.85, length * 0.26), fin, folder),
				length = length,
				shown = false,
			})
		end
		table.insert(looks, list)
	end
	folder.Parent = parent
	return setmetatable({ folder = folder, looks = looks, parts = {}, frames = {} }, FishView)
end

function FishView.update(self: FishView, schools: any, time: number)
	local parts, frames = self.parts, self.frames
	table.clear(parts)
	table.clear(frames)
	for i, school in schools.list do
		local list = self.looks[i]
		local visible = school.shown and school.alive > 0
		for j, one in school.fish do
			local look = list[j]
			if visible and one.alive then
				local L = look.length * S
				local root = CFrame.new(one.x * S, (one.y - 18) * S, one.z * S) * CFrame.Angles(0, one.heading + math.pi, 0)
				local wag = math.sin(time * 9 + one.phase * 3) * 0.45
				table.insert(parts, look.top)
				table.insert(frames, root * CFrame.new(0, L * 0.035, 0))
				table.insert(parts, look.bottom)
				table.insert(frames, root * CFrame.new(0, -L * 0.05, -L * 0.02))
				table.insert(parts, look.tail)
				table.insert(frames, root * CFrame.new(0, 0, L * 0.34) * CFrame.Angles(0, wag, 0) * CFrame.new(0, 0, L * 0.1))
				look.shown = true
			elseif look.shown then
				look.shown = false
				table.insert(parts, look.top)
				table.insert(frames, HIDDEN)
				table.insert(parts, look.bottom)
				table.insert(frames, HIDDEN)
				table.insert(parts, look.tail)
				table.insert(frames, HIDDEN)
			end
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

return FishView
