--!strict
-- Runs the game on the player's computer: the title, then the day-by-day swim.
-- Loading -> title -> playing <-> paused -> over.

local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Spring = ReplicatedStorage:WaitForChild("Spring")
local Rules = require(Spring:WaitForChild("Rules"))
local Lang = require(Spring:WaitForChild("Lang"))
local Session = require(Spring:WaitForChild("Session"))

local Input = require(script.Parent:WaitForChild("Input"))
local Hud = require(script.Parent:WaitForChild("Hud"))
local DolphinView = require(script.Parent:WaitForChild("DolphinView"))
local FishView = require(script.Parent:WaitForChild("FishView"))
local ChaseCamera = require(script.Parent:WaitForChild("ChaseCamera"))
local Effects = require(script.Parent:WaitForChild("Effects"))

-- Roblox's own panels (chat, player list, backpack) are hidden: this is a one-player game
task.spawn(function()
	for _ = 1, 20 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
		end)
		if ok then
			break
		end
		task.wait(0.5)
	end
end)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local worldFolder = Instance.new("Folder")
worldFolder.Name = "SpringWorld"
worldFolder.Parent = workspace

local state = "loading"
local gentle = true
local clock = 0
local session = Session.new(gentle, os.time())
local dolphin = DolphinView.new(worldFolder)
local fishView = FishView.new(session.schools, worldFolder)
local chase = ChaseCamera.new()
chase:snapBehind(session.swimmer)

local hud: Hud.Hud

local function toggleLanguage()
	Lang.language = if Lang.language == "en" then "ru" else "en"
	hud:refresh(gentle)
end

local function newGame()
	session = Session.new(gentle, os.time())
	fishView.folder:Destroy()
	fishView = FishView.new(session.schools, worldFolder)
	chase.backwards = false
	chase.firstPerson = false
	chase:snapBehind(session.swimmer)
	hud:clearMessages()
	Input.releaseAll()
	state = "playing"
	hud:show("play")
end

local function toTitle()
	state = "title"
	hud:clearMessages()
	hud:refresh(gentle)
	hud:show("title")
end

local function pause()
	if state == "playing" then
		state = "paused"
		Input.releaseAll()
		hud:show("pause")
	end
end

local function act(action: string)
	if action == "focus_lost" then
		pause()
		return
	end
	if state == "title" then
		if action == "play" or action == "jump" then
			newGame()
		elseif action == "language" then
			toggleLanguage()
		elseif action == "difficulty" then
			gentle = not gentle
			hud:refresh(gentle)
		end
	elseif state == "playing" then
		if action == "pause" then
			pause()
		elseif action == "jump" then
			session:pressJump()
		elseif action == "back" then
			chase.backwards = not chase.backwards
		elseif action == "view" then
			chase.firstPerson = not chase.firstPerson
			if chase.firstPerson then
				hud:message("banner", Lang.t("Now you see through Spring's eyes"), false, 2.2)
			end
		end
	elseif state == "paused" then
		if action == "pause" or action == "play" or action == "jump" then
			state = "playing"
			hud:show("play")
		elseif action == "language" then
			toggleLanguage()
		elseif action == "menu" then
			toTitle()
		end
	elseif state == "over" then
		if action == "play" or action == "jump" then
			newGame()
		elseif action == "menu" then
			toTitle()
		end
	end
end

hud = Hud.new(player:WaitForChild("PlayerGui"), act)
hud:refresh(gentle)
Input.onPressed(act)
GuiService.MenuOpened:Connect(pause)

-- the sun follows the Godot game's day: morning at the start, night for the last fifth
local function clockTime(dayTime: number): number
	local phase = Rules.fposmod(dayTime / Rules.DAY_LENGTH + Rules.DAY_OFFSET, 1.0)
	if phase < Rules.NIGHT_FROM then
		return 6 + 12 * phase / Rules.NIGHT_FROM
	end
	return (18 + 12 * (phase - Rules.NIGHT_FROM) / (1 - Rules.NIGHT_FROM)) % 24
end

local DAY_OUTDOOR = Color3.fromRGB(120, 138, 156)
local NIGHT_OUTDOOR = Color3.fromRGB(64, 84, 124)
local DAY_AMBIENT = Color3.fromRGB(70, 82, 96)
local NIGHT_AMBIENT = Color3.fromRGB(44, 58, 90)

local function light(dayTime: number)
	local hours = clockTime(dayTime)
	Lighting.ClockTime = hours
	-- 0 by day, 1 deep in the night, eased over dusk and dawn
	local night = 0
	if hours >= 18.5 or hours < 5.5 then
		night = 1
	elseif hours >= 17 then
		night = (hours - 17) / 1.5
	elseif hours < 7 then
		night = (7 - hours) / 1.5
	end
	night = math.clamp(night, 0, 1)
	Lighting.OutdoorAmbient = DAY_OUTDOOR:Lerp(NIGHT_OUTDOOR, night)
	Lighting.Ambient = DAY_AMBIENT:Lerp(NIGHT_AMBIENT, night)
end

RunService:BindToRenderStep("Spring", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
	local real = math.min(dt, 0.1)
	clock += real
	if state == "loading" then
		hud:setLoading((ReplicatedStorage:GetAttribute("OceanProgress") :: number?) or 0)
		if ReplicatedStorage:GetAttribute("OceanReady") then
			toTitle()
		end
	end

	local steerX, steerY = 0, 0
	local swimmer = session.swimmer
	local moved = 0
	if state == "playing" then
		steerX, steerY = Input.steer()
		moved = if swimmer.jumping then real * Rules.JUMP_SLOW_MOTION else real
		session:step(moved, steerX, steerY, Input.held("boost"))
		for _, m in session.messages do
			hud:message(m.kind, m.text, m.big, m.seconds)
		end
		table.clear(session.messages)
		for _, e in session.effects do
			Effects.play(e.kind, e.x, e.y, e.z, e.count, worldFolder)
		end
		table.clear(session.effects)
		if session.over then
			state = "over"
			hud:showOver(session)
			hud:show("over")
		end
	elseif state == "title" or state == "loading" then
		-- the sea lives on behind the title
		session.schools:advance(real, swimmer.x, swimmer.y, swimmer.z)
		table.clear(session.messages)
		table.clear(session.effects)
	end

	camera.CameraType = Enum.CameraType.Scriptable
	local frame, fov = chase:follow(real, swimmer, steerX, steerY, clock, 0.5, state == "playing" or state == "paused")
	camera.CFrame = frame
	camera.FieldOfView = fov
	dolphin:update(moved, swimmer, session.tail, clock, frame.Position.Y < 0)
	fishView:update(session.schools, session.schools.time)
	light(session.dayTime)
	hud:update(real, session, camera.ViewportSize.Y)
end)
