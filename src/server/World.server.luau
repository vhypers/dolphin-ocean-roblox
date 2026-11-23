--!strict
-- Sets up light, sky and water, and builds the ocean if the place does not have it yet.
-- The game itself runs on the player's computer (StarterPlayerScripts/Main): one player, no
-- chat, nothing sent anywhere.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Spring = ReplicatedStorage:WaitForChild("Spring")
local TerrainBuilder = require(Spring:WaitForChild("TerrainBuilder"))

local function ensure(className: string, name: string, parent: Instance): any
	local found = parent:FindFirstChild(name)
	if found and found.ClassName == className then
		return found
	end
	local made = Instance.new(className)
	made.Name = name
	made.Parent = parent
	return made
end

-- warm Red Sea light; the client moves the sun through the day
Lighting.Brightness = 2.4
Lighting.Ambient = Color3.fromRGB(70, 82, 96)
Lighting.OutdoorAmbient = Color3.fromRGB(120, 138, 156)
Lighting.EnvironmentDiffuseScale = 1
Lighting.EnvironmentSpecularScale = 1
Lighting.GlobalShadows = true
Lighting.GeographicLatitude = 22
Lighting.ClockTime = 9
Lighting.ExposureCompensation = 0.1

local atmosphere = ensure("Atmosphere", "Atmosphere", Lighting)
atmosphere.Density = 0.32
atmosphere.Offset = 0.2
atmosphere.Color = Color3.fromRGB(200, 222, 238)
atmosphere.Decay = Color3.fromRGB(110, 146, 178)
atmosphere.Glare = 0.35
atmosphere.Haze = 1.2

ensure("Sky", "Sky", Lighting)

local bloom = ensure("BloomEffect", "Bloom", Lighting)
bloom.Intensity = 0.5
bloom.Size = 28
bloom.Threshold = 1.7

local grade = ensure("ColorCorrectionEffect", "Grade", Lighting)
grade.Saturation = 0.08
grade.Contrast = 0.06

local rays = ensure("SunRaysEffect", "SunRays", Lighting)
rays.Intensity = 0.05
rays.Spread = 0.7

local clouds = ensure("Clouds", "Clouds", workspace.Terrain)
clouds.Cover = 0.5
clouds.Density = 0.55
clouds.Color = Color3.fromRGB(255, 255, 255)

TerrainBuilder.style(0)

ReplicatedStorage:SetAttribute("OceanReady", false)
ReplicatedStorage:SetAttribute("OceanProgress", 0)
if not TerrainBuilder.isBuilt() then
	local started = os.clock()
	TerrainBuilder.build(0, function(fraction: number)
		ReplicatedStorage:SetAttribute("OceanProgress", fraction)
	end)
	print(string.format("Spring: built the ocean in %.1f s", os.clock() - started))
end
ReplicatedStorage:SetAttribute("OceanReady", true)
