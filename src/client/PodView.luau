--!strict
-- Draws her family: the pod, the calf and whoever is waiting to be found. Each family member keeps
-- its own dolphin from the moment it is waiting until it swims in the pod (as in the Godot
-- game's life_view.gd, a shade lighter or darker and a little smaller than Spring).

local DolphinView = require(script.Parent:WaitForChild("DolphinView"))

local PodView = {}
PodView.__index = PodView

export type PodView = typeof(setmetatable(
	{} :: {
		folder: Folder,
		views: { [any]: DolphinView.DolphinView },
		spare: { DolphinView.DolphinView },
		count: number,
	},
	PodView
))

function PodView.new(parent: Instance): PodView
	local folder = Instance.new("Folder")
	folder.Name = "Family"
	folder.Parent = parent
	return setmetatable({ folder = folder, views = {}, spare = {}, count = 0 }, PodView)
end

-- a swimmer-shaped pose for DolphinView from a family member of the session
local function pose(mate: any, rushing: boolean): any
	local fx, fy, fz = mate.fx, mate.fy, mate.fz
	local l = math.sqrt(fx * fx + fy * fy + fz * fz)
	if l < 1e-4 then
		fx, fy, fz, l = 0, 0, 1, 1
	end
	return {
		x = mate.x,
		y = mate.y,
		z = mate.z,
		yaw = math.atan2(fx, fz),
		pitch = math.asin(math.clamp(fy / l, -1, 1)),
		roll = 0,
		jumping = false,
		speed = if rushing then 26 else 11,
		boosting = rushing,
		invulnerable = 0,
	}
end

function PodView.update(self: PodView, dt: number, session: any, time: number)
	local members = {}
	for _, mate in session.pod do
		table.insert(members, mate)
	end
	if session.calf then
		table.insert(members, session.calf)
	end
	if session.lost then
		table.insert(members, session.lost)
	end
	local present = {}
	for _, mate in members do
		present[mate] = true
	end
	for mate, view in self.views do
		if not present[mate] then
			view.model.Parent = nil
			table.insert(self.spare, view)
			self.views[mate] = nil
		end
	end
	for _, mate in members do
		local view = self.views[mate]
		if view == nil then
			view = table.remove(self.spare)
			if view == nil then
				self.count += 1
				view = DolphinView.new(self.folder, "Family" .. self.count, mate.size, mate.tint)
			end
			assert(view)
			view.model.Parent = self.folder
			self.views[mate] = view
		end
		view:setScale(mate.size)
		view:setTint(mate.tint)
		local rushing = mate.rushTime > 0 and mate.rush ~= nil
		view:update(dt, pose(mate, rushing), 1.0, time, mate.y < 18)
	end
end

function PodView.clear(self: PodView)
	for mate, view in self.views do
		view.model.Parent = nil
		table.insert(self.spare, view)
		self.views[mate] = nil
	end
end

return PodView
