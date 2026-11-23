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
local SharkView = require(script.Parent:WaitForChild("SharkView"))
local PodView = require(script.Parent:WaitForChild("PodView"))
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
local sharkView = SharkView.new(session.sharks, worldFolder)
local podView = PodView.new(worldFolder)
local chase = ChaseCamera.new()
chase:snapBehind(session.swimmer)

-- the pod's fight with a shark, watched from above, with a moment of slow motion at the first hit
local podShow = 0.0
local podLinger = 0.0
local podSpot: { number }? = nil
local podSpan = 10.0
local podSlow = 0.0 -- real seconds of slow motion left
local podSlowed = false -- once per call

local hud: Hud.Hud

local function keyNames()
	session.badges = { attack = Input.badge("attack"), pod = Input.badge("pod") }
end
keyNames()

local function toggleLanguage()
	Lang.language = if Lang.language == "en" then "ru" else "en"
	hud:refresh(gentle)
end

local function newGame()
	session = Session.new(gentle, os.time())
	keyNames()
	fishView.folder:Destroy()
	fishView = FishView.new(session.schools, worldFolder)
	sharkView:destroy()
	sharkView = SharkView.new(session.sharks, worldFolder)
	podView:clear()
	podShow, podLinger, podSpot, podSlow, podSlowed = 0, 0, nil, 0, false
	chase.overhead = 0
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
		elseif action == "attack" then
			session:pressAttack()
		elseif action == "pod" then
			session:pressPod()
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

-- From the moment the pod sets off until a little after it is done, the camera rises above the
-- fight (the Godot game's main.gd _follow_pod).
local function followPod(dt: number, playing: boolean)
	local s = session.swimmer
	local spots: { { number } } = {}
	for _, mate in session.pod do
		local rush = mate.rush
		if mate.rushTime > 0 and rush then
			table.insert(spots, { mate.x, mate.y, mate.z })
			table.insert(spots, { rush.x, rush.y, rush.z })
		end
	end
	local rushing = #spots > 0 and playing
	if not rushing and podShow <= 0 then
		podSlowed = false
	end
	podLinger = if rushing then 0.5 else math.max(podLinger - dt, 0.0)
	local wanted = if (rushing or podLinger > 0) and playing then 1.0 else 0.0
	local step = dt * (if wanted > podShow then 2.0 else 1.3)
	podShow = if math.abs(wanted - podShow) <= step then wanted else podShow + step * Rules.sign(wanted - podShow)
	chase.overhead = podShow
	if rushing then
		-- the fight in the middle of the picture; Spring too, when she is close enough to be part of it
		local cx, cy, cz = 0, 0, 0
		for _, p in spots do
			cx, cy, cz = cx + p[1], cy + p[2], cz + p[3]
		end
		cx, cy, cz = cx / #spots, cy / #spots, cz / #spots
		if math.sqrt((s.x - cx) ^ 2 + (s.y - cy) ^ 2 + (s.z - cz) ^ 2) < 18.0 then
			table.insert(spots, { s.x, s.y, s.z })
			local w = 1.0 / #spots
			cx, cy, cz = cx + (s.x - cx) * w, cy + (s.y - cy) * w, cz + (s.z - cz) * w
		end
		local span = 0.0
		for _, p in spots do
			span = math.max(span, math.sqrt((p[1] - cx) ^ 2 + (p[2] - cy) ^ 2 + (p[3] - cz) ^ 2))
		end
		local k = 1.0 - math.exp(-7.0 * dt)
		local spot = podSpot
		if spot == nil then
			podSpot = { cx, cy, cz }
		else
			podSpot = { spot[1] + (cx - spot[1]) * k, spot[2] + (cy - spot[2]) * k, spot[3] + (cz - spot[3]) * k }
		end
		podSpan += (span - podSpan) * k
	elseif podShow <= 0 then
		podSpot = nil
	end
	local spot = podSpot
	if spot then
		chase.focusX, chase.focusY, chase.focusZ = spot[1], spot[2], spot[3]
		chase.span = podSpan
	end
end

-- how fast the game runs this frame: half speed for a moment at the pod's first hit, easing in and out
local function podTime(real: number): number
	if podSlow <= 0.0 then
		return 1.0
	end
	podSlow = math.max(podSlow - real, 0.0)
	local t = 1.0 - podSlow / Rules.POD_SLOW_SECONDS
	local depth = Rules.smoothstep(0.0, 0.15, t) * (1.0 - Rules.smoothstep(0.6, 1.0, t))
	return Rules.lerp(1.0, Rules.POD_SLOW_MOTION, depth)
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
		moved = (if swimmer.jumping then real * Rules.JUMP_SLOW_MOTION else real) * podTime(real)
		session:step(moved, steerX, steerY, Input.held("boost"))
		for _, m in session.messages do
			hud:message(m.kind, m.text, m.big, m.seconds)
		end
		table.clear(session.messages)
		for _, e in session.effects do
			if e.kind == "pod_hit" then
				if not podSlowed and chase.overhead > 0.3 then
					podSlowed = true
					podSlow = Rules.POD_SLOW_SECONDS
				end
			elseif e.kind == "hurt" then
				chase:bump()
			elseif e.kind ~= "alarm" then
				Effects.play(e.kind, e.x, e.y, e.z, e.count, worldFolder)
			end
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

	followPod(real, state == "playing")
	camera.CameraType = Enum.CameraType.Scriptable
	local frame, fov = chase:follow(real, swimmer, steerX, steerY, clock, 0.5, state == "playing" or state == "paused")
	camera.CFrame = frame
	camera.FieldOfView = fov
	dolphin:update(moved, swimmer, session.tail, clock, frame.Position.Y < 0)
	fishView:update(session.schools, session.schools.time)
	sharkView:update(session.sharks, chase.x, chase.y, chase.z, state ~= "title" and state ~= "loading")
	podView:update(moved, session, clock)
	light(session.dayTime)
	hud:update(real, session, camera.ViewportSize.Y)
	hud:mark(session, camera, state == "playing", clock)
end)

-- Studio only: test commands for playtests, set as the player's "SpringCheat" attribute, and a
-- short state line in "SpringState". Nothing of this runs in a published game.
if RunService:IsStudio() then
	local function cheat(command: string)
		local word, number = string.match(command, "^(%a+)%s*(%-?%d*)")
		local n = tonumber(number)
		local s = session.swimmer
		if word == "day" and n then
			session.day = n - 1
			session.dayTime = Rules.DAY_LENGTH - 0.05
		elseif word == "shark" then
			local shark = session.sharks[n or 1]
			if shark then
				local ahead = 18
				shark.x, shark.y, shark.z = s.x + s.dx * ahead, s.y, s.z + s.dz * ahead
				shark.mood = "patrol"
				session.calmLeft = 0
			end
		elseif word == "meet" then
			local lost = session.lost
			if lost then
				lost.x, lost.y, lost.z = s.x + s.dx * 5, s.y, s.z + s.dz * 5
			end
		elseif word == "pod" then
			for _ = 1, n or 1 do
				if #session.pod < #Rules.POD_SLOTS then
					session:_addMate()
				end
			end
		elseif word == "calf" then
			session:_newCalf()
		elseif word == "calm" then
			session.calmLeft = n or 999
		elseif word == "air" then
			s.air = Rules.AIR_MAX
		end
	end
	player:GetAttributeChangedSignal("SpringCheat"):Connect(function()
		local command = player:GetAttribute("SpringCheat")
		if type(command) == "string" and command ~= "" then
			player:SetAttribute("SpringCheat", "")
			cheat(command)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			local s = session.swimmer
			local moods = {}
			for _, shark in session.sharks do
				local d = math.sqrt((shark.x - s.x) ^ 2 + (shark.y - s.y) ^ 2 + (shark.z - s.z) ^ 2)
				table.insert(moods, string.format("%s%.0f", string.sub(shark.mood, 1, 1), d))
			end
			player:SetAttribute(
				"SpringState",
				string.format(
					"%s day %d lives %d food %.0f pod %d calf %s lost %s found %d attack %s cool %.1f/%.1f overhead %.2f sharks %s",
					state,
					session.day,
					session.lives,
					session.food,
					#session.pod,
					tostring(session.calf ~= nil),
					tostring(session.lost ~= nil),
					session.familyFound,
					tostring(session.attack ~= nil),
					session.attackCooldown,
					session.podCooldown,
					chase.overhead,
					table.concat(moods, " ")
				)
			)
		end
	end)
end
