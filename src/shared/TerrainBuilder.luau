--!native
--!strict
-- Builds the Red Sea as Roblox terrain from SeaFloor.height(): sand, reef rubble, reef walls,
-- beaches, grass and cliffs, filled with water up to sea level (y = 0 studs).
-- Run once in Edit mode and save the place; the server builds it at start if it is missing.

local Rules = require(script.Parent.Rules)
local SeaFloor = require(script.Parent.SeaFloor)
local Data = require(script.Parent.Data)

local TerrainBuilder = {}

-- bump this when the shape or materials change, so old saved terrain is rebuilt
TerrainBuilder.VERSION = 2

local S = Rules.STUDS
local SEA = Rules.SEA_LEVEL
local VOXEL = 4
local HALF_WIDTH_M = 480 -- metres from the centre to the edge of the shaped sea floor (the world is 300)
local Y_LOW = -240 -- studs; sea level is 0
local Y_HIGH = 32
local CHUNK = 64 -- voxels per side in one write
-- Roblox has almost no fog under water, so the end of the water would show as a blue wall.
-- Around the shaped floor lies plain open sea out to OPEN_SEA studs, on a flat floor that the
-- shaped floor's rim blends into (the drop-off into the blue is about this deep).
local OPEN_SEA = 4096
local FAR_FLOOR = -204 -- studs
local OPEN_TILE = 1024 -- studs per side in one fill

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

function TerrainBuilder.isBuilt(): boolean
	return workspace.Terrain:GetAttribute("SpringOcean") == TerrainBuilder.VERSION
end

-- water and terrain colours for one ocean
function TerrainBuilder.style(ocean: number)
	local info = Data.oceans[ocean + 1]
	local terrain = workspace.Terrain
	local shallow = rgb(info.shallow)
	local deep = rgb(info.deep)
	terrain.WaterColor = deep:Lerp(shallow, 0.55)
	terrain.WaterTransparency = 0.82
	terrain.WaterReflectance = 0.55
	terrain.WaterWaveSize = 0.22
	terrain.WaterWaveSpeed = 11
	-- swaying grass on the islands; only Studio may set it, so it is saved with the baked ocean
	pcall(function()
		terrain.Decoration = true
	end)
	terrain:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(232, 222, 196))
	terrain:SetMaterialColor(Enum.Material.Limestone, Color3.fromRGB(205, 178, 160)) -- coral rubble
	terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(156, 142, 124)) -- reef walls and cliffs
	terrain:SetMaterialColor(Enum.Material.Sandstone, Color3.fromRGB(186, 150, 112))
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(132, 140, 84))
end

-- what a column of ground is made of
local function materialAt(bed: SeaFloor.SeaFloor, x: number, z: number, h: number, u: number): Enum.Material
	local wobble = math.noise(x * 0.09 + 0.3, z * 0.09 + 0.7, 3.5) * 0.08
	local island, angle = bed:nearestIsland(x, z)
	if h > SEA + 0.25 then
		if island and u + wobble > 0.2 and bed:cliffAt(island, angle) > 0.45 then
			return Enum.Material.Rock
		end
		if u + wobble < 0.26 then
			return Enum.Material.Grass
		end
		return Enum.Material.Sand
	end
	local v = u + wobble
	if v < 0.42 then
		return Enum.Material.Sand
	elseif v < 0.6 then
		return Enum.Material.Limestone
	elseif v < 1.12 then
		return if island and bed:cliffAt(island, angle) > 0.5 and v < 0.8 then Enum.Material.Sandstone else Enum.Material.Rock
	elseif v < 1.25 then
		return Enum.Material.Limestone
	end
	return Enum.Material.Sand
end

function TerrainBuilder.build(ocean: number?, progress: ((number) -> ())?)
	local index = ocean or 0
	local terrain = workspace.Terrain
	terrain:Clear()
	TerrainBuilder.style(index)
	local bed = SeaFloor.new(index)
	local half = math.floor(HALF_WIDTH_M * S / VOXEL)
	local ny = (Y_HIGH - Y_LOW) // VOXEL
	local chunks = math.ceil(half * 2 / CHUNK)
	local total, done = chunks * chunks, 0
	local air = Enum.Material.Air
	local useChannels = true
	for ci = 0, chunks - 1 do
		for cj = 0, chunks - 1 do
			local x0 = -half + ci * CHUNK
			local x1 = math.min(x0 + CHUNK, half)
			local z0 = -half + cj * CHUNK
			local z1 = math.min(z0 + CHUNK, half)
			local w, d = x1 - x0, z1 - z0
			local heights = table.create(w * d, 0)
			local kinds = table.create(w * d, air)
			for ix = 1, w do
				local xm = (x0 + ix - 0.5) * VOXEL / S
				for iz = 1, d do
					local zm = (z0 + iz - 0.5) * VOXEL / S
					local h, u = bed:survey(xm, zm)
					local rim = Rules.smoothstep(HALF_WIDTH_M - 40, HALF_WIDTH_M, math.max(math.abs(xm), math.abs(zm)))
					if rim > 0 then
						h = Rules.lerp(h, SEA + FAR_FLOOR / S, rim)
					end
					heights[(ix - 1) * d + iz] = (h - SEA) * S
					kinds[(ix - 1) * d + iz] = materialAt(bed, xm, zm, h, u)
				end
			end
			local solidMaterial, solidOccupancy, liquidOccupancy = table.create(w), table.create(w), table.create(w)
			for ix = 1, w do
				local mx, ox, lx = table.create(ny), table.create(ny), table.create(ny)
				for iy = 1, ny do
					local y0 = Y_LOW + (iy - 1) * VOXEL
					local wet = if y0 + VOXEL <= 0 then 1 else 0
					local my, oy, ly = table.create(d), table.create(d), table.create(d)
					for iz = 1, d do
						local top = heights[(ix - 1) * d + iz]
						local occupancy
						if top >= y0 + VOXEL then
							occupancy = 1
						elseif top <= y0 then
							occupancy = 0
						else
							occupancy = (top - y0) / VOXEL
						end
						my[iz] = if occupancy > 0 then kinds[(ix - 1) * d + iz] else air
						oy[iz] = occupancy
						ly[iz] = wet
					end
					mx[iy], ox[iy], lx[iy] = my, oy, ly
				end
				solidMaterial[ix], solidOccupancy[ix], liquidOccupancy[ix] = mx, ox, lx
			end
			local region = Region3.new(Vector3.new(x0 * VOXEL, Y_LOW, z0 * VOXEL), Vector3.new(x1 * VOXEL, Y_HIGH, z1 * VOXEL))
			if useChannels then
				local ok, err = pcall(function()
					terrain:WriteVoxelChannels(region, VOXEL, {
						SolidMaterial = solidMaterial,
						SolidOccupancy = solidOccupancy,
						LiquidOccupancy = liquidOccupancy,
					})
				end)
				if not ok then
					warn("Spring: WriteVoxelChannels failed, using WriteVoxels: " .. tostring(err))
					useChannels = false
				end
			end
			if not useChannels then
				-- older terrain: a voxel is either solid or water
				for ix = 1, w do
					for iy = 1, ny do
						local my, oy, ly = solidMaterial[ix][iy], solidOccupancy[ix][iy], liquidOccupancy[ix][iy]
						for iz = 1, d do
							if oy[iz] < 0.3 and ly[iz] > 0 then
								my[iz] = Enum.Material.Water
								oy[iz] = 1
							end
						end
					end
				end
				terrain:WriteVoxels(region, VOXEL, solidMaterial, solidOccupancy)
			end
			done += 1
			if progress then
				progress(0.9 * done / total)
			end
			task.wait()
		end
	end
	TerrainBuilder.openSea(half * VOXEL)
	if progress then
		progress(1)
	end
	terrain:SetAttribute("SpringOcean", TerrainBuilder.VERSION)
end

-- plain water on a flat sand floor around the shaped square (inner: its half width in studs)
function TerrainBuilder.openSea(inner: number)
	local terrain = workspace.Terrain
	local rects = {
		{ -OPEN_SEA, -OPEN_SEA, OPEN_SEA, -inner }, -- x0, z0, x1, z1
		{ -OPEN_SEA, inner, OPEN_SEA, OPEN_SEA },
		{ -OPEN_SEA, -inner, -inner, inner },
		{ inner, -inner, OPEN_SEA, inner },
	}
	for _, r in rects do
		local x = r[1]
		while x < r[3] do
			local x1 = math.min(x + OPEN_TILE, r[3])
			local z = r[2]
			while z < r[4] do
				local z1 = math.min(z + OPEN_TILE, r[4])
				local cx, cz, sx, sz = (x + x1) / 2, (z + z1) / 2, x1 - x, z1 - z
				terrain:FillBlock(CFrame.new(cx, FAR_FLOOR / 2, cz), Vector3.new(sx, -FAR_FLOOR, sz), Enum.Material.Water)
				terrain:FillBlock(
					CFrame.new(cx, (Y_LOW + FAR_FLOOR) / 2, cz),
					Vector3.new(sx, FAR_FLOOR - Y_LOW, sz),
					Enum.Material.Sand
				)
				z = z1
				task.wait()
			end
			x = x1
		end
	end
end

return TerrainBuilder
