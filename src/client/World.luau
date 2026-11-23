--!strict
-- Turns the game's metres (Godot coordinates, sea level y = 18) into Roblox studs (sea level y = 0).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rules = require(ReplicatedStorage:WaitForChild("Spring"):WaitForChild("Rules"))

local World = {}

local S = Rules.STUDS
local SEA = Rules.SEA_LEVEL

World.S = S

function World.point(x: number, y: number, z: number): Vector3
	return Vector3.new(x * S, (y - SEA) * S, z * S)
end

-- yaw 0 faces +z; Roblox models face -z, hence the half turn
function World.frame(x: number, y: number, z: number, yaw: number, pitch: number, roll: number): CFrame
	return CFrame.new(World.point(x, y, z))
		* CFrame.Angles(0, yaw + math.pi, 0)
		* CFrame.Angles(pitch, 0, 0)
		* CFrame.Angles(0, 0, -roll)
end

return World
