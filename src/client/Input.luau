--!strict
-- Every action and its keys and mouse buttons, as in the Godot game's scripts/controls.gd.
-- Swim with WASD or the arrows, or hold the left mouse button and drag (a stick from where you
-- pressed); a left click without a drag is Hit. The right mouse button held is Boost, the wheel
-- button is Jump.
-- Esc belongs to Roblox (its menu), so Pause is P and the game pauses when the menu opens.

local UserInputService = game:GetService("UserInputService")

local Input = {}

local K = Enum.KeyCode

Input.KEYS = {
	up = { K.W, K.Up },
	down = { K.S, K.Down },
	left = { K.A, K.Left },
	right = { K.D, K.Right },
	boost = { K.Space, K.LeftShift, K.RightShift },
	attack = { K.X, K.Q },
	jump = { K.J, K.Return, K.KeypadEnter },
	pod = { K.F, K.E },
	magic = { K.R },
	back = { K.B },
	view = { K.V },
	diary = { K.Tab },
	pause = { K.P },
	sound = { K.M },
	controls = { K.C },
	fullscreen = { K.G },
	-- menus
	language = { K.L },
	difficulty = { K.H },
	menu = { K.Backspace },
}

local HELD = { up = true, down = true, left = true, right = true, boost = true }

local JOY_RADIUS = 50.0
local DEAD_ZONE = 0.1
local CLICK_MOVE = 10.0

local byKey: { [Enum.KeyCode]: { string } } = {}
for action, keys in Input.KEYS do
	for _, key in keys do
		byKey[key] = byKey[key] or {}
		table.insert(byKey[key], action)
	end
end

local keysDown: { [Enum.KeyCode]: boolean } = {}
local rightDown = false
local joyActive = false
local joyStart = Vector2.zero
local joyMoved = false
local stick = Vector2.zero
local listeners: { (string) -> () } = {}

local function withoutDeadZone(value: number): number
	return math.sign(value) * math.max(math.abs(value) - DEAD_ZONE, 0.0) / (1.0 - DEAD_ZONE)
end

local function fire(action: string)
	for _, listener in listeners do
		listener(action)
	end
end

function Input.onPressed(listener: (string) -> ())
	table.insert(listeners, listener)
end

function Input.held(action: string): boolean
	if action == "boost" and rightDown then
		return true
	end
	for _, key in Input.KEYS[action] do
		if keysDown[key] then
			return true
		end
	end
	return false
end

-- steer x is right, y is up, each -1 to 1
function Input.steer(): (number, number)
	local x = stick.X + (if Input.held("right") then 1 else 0) - (if Input.held("left") then 1 else 0)
	local y = stick.Y + (if Input.held("up") then 1 else 0) - (if Input.held("down") then 1 else 0)
	return math.clamp(x, -1, 1), math.clamp(y, -1, 1)
end

function Input.releaseAll()
	table.clear(keysDown)
	rightDown = false
	joyActive = false
	stick = Vector2.zero
end

-- the first key of an action, for showing on buttons
function Input.badge(action: string): string
	local key = Input.KEYS[action][1]
	local names = { Return = "Enter", Space = "Space", LeftShift = "Shift", Backspace = "Backspace" }
	return names[key.Name] or key.Name
end

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		if processed then
			return
		end
		keysDown[input.KeyCode] = true
		for _, action in byKey[input.KeyCode] or {} do
			if not HELD[action] then
				fire(action)
			end
		end
	elseif processed then
		return
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
		joyActive = true
		joyMoved = false
		joyStart = UserInputService:GetMouseLocation()
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		rightDown = true
	elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
		fire("jump")
	end
end)

UserInputService.InputChanged:Connect(function(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseMovement and joyActive then
		local at = UserInputService:GetMouseLocation()
		local moved = (at - joyStart) / JOY_RADIUS
		if (at - joyStart).Magnitude > CLICK_MOVE then
			joyMoved = true
		end
		if joyMoved then
			-- screen y grows downward; up on the stick swims up
			stick = Vector2.new(withoutDeadZone(math.clamp(moved.X, -1, 1)), -withoutDeadZone(math.clamp(moved.Y, -1, 1)))
		end
	end
end)

UserInputService.InputEnded:Connect(function(input: InputObject)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		keysDown[input.KeyCode] = nil
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
		-- a click without a drag is Hit, as in the Godot game; a drag only steers
		local clicked = joyActive and not joyMoved
		joyActive = false
		stick = Vector2.zero
		if clicked then
			fire("attack")
		end
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		rightDown = false
	end
end)

UserInputService.WindowFocusReleased:Connect(function()
	Input.releaseAll()
	fire("focus_lost")
end)

return Input
