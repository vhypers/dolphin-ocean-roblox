--!strict
-- Generated from the Godot game's data/game_data.json and data/text.json (R1 uses the Red Sea only).
-- Regenerate rather than edit by hand.

local Data = {}

export type Species = { index: number, name: string, nameRu: string, length: number, top: string, mid: string?, bottom: string, fin: string, tail: string }

Data.species = {
	{ index = 0, name = "anthias", nameRu = "антиас", length = 1.5, top = "#ff7a1a", mid = "#ff962e", bottom = "#ffc56e", fin = "#ff6a3a", tail = "lyre" },
	{ index = 1, name = "fusilier", nameRu = "фузилёр", length = 1.9, top = "#3e8fd8", mid = "#9fd0f0", bottom = "#f4f9fb", fin = "#6faedb", tail = "fork" },
	{ index = 2, name = "sergeant major", nameRu = "рыба-сержант", length = 1.6, top = "#e6dc5a", mid = "#f2f4ee", bottom = "#ffffff", fin = "#bfc9cf", tail = "fork" },
	{ index = 3, name = "masked butterflyfish", nameRu = "масковая рыба-бабочка", length = 1.7, top = "#ffdc00", mid = nil, bottom = "#ffc800", fin = "#ffcf00", tail = "trunc" },
	{ index = 4, name = "bannerfish", nameRu = "рыба-вымпел", length = 1.9, top = "#f6f6f0", mid = nil, bottom = "#fff3a8", fin = "#ffd92e", tail = "trunc" },
	{ index = 5, name = "sohal surgeonfish", nameRu = "хирург сохал", length = 2.2, top = "#8a9fbe", mid = "#b9c8da", bottom = "#eef2f5", fin = "#10151f", tail = "fork" },
	{ index = 6, name = "yellowtail tang", nameRu = "желтохвостая зебрасома", length = 1.8, top = "#2c2f9c", mid = nil, bottom = "#3b3fb4", fin = "#2a2c92", tail = "trunc" },
	{ index = 7, name = "parrotfish", nameRu = "рыба-попугай", length = 2.6, top = "#1fa594", mid = "#38c4a6", bottom = "#86e2bb", fin = "#2a9fc6", tail = "trunc" },
	{ index = 8, name = "herring", nameRu = "сельдь", length = 1.6, top = "#35587e", mid = "#a7c0d4", bottom = "#eef3f6", fin = "#8aa3b8", tail = "fork" },
	{ index = 9, name = "cod", nameRu = "треска", length = 2.6, top = "#6b693c", mid = "#a19f70", bottom = "#ece7d2", fin = "#7d7a50", tail = "trunc" },
	{ index = 10, name = "mackerel", nameRu = "скумбрия", length = 1.9, top = "#1f6a6a", mid = "#8fc7c0", bottom = "#f2f6f4", fin = "#4d8c8a", tail = "fork" },
	{ index = 11, name = "icefish", nameRu = "ледяная рыба", length = 2, top = "#a9bcc3", mid = "#dbe7ea", bottom = "#f6fbfc", fin = "#c5d6db", tail = "trunc" },
} :: { Species }

Data.oceans = {
	{ name = "Red Sea", nameRu = "Красное море", deep = { 5, 48, 79 }, shallow = { 43, 159, 208 }, wave = { 20, 85, 125 }, sand = { 255, 255, 255 }, reef = { 0, 3, 4, 5, 6, 7, 2, 0 }, open = { 1, 2, 1, 1, 0 }, icy = false },
	{ name = "Pacific Ocean", nameRu = "Тихий океан", deep = { 2, 31, 74 }, shallow = { 22, 112, 194 }, wave = { 15, 74, 120 }, sand = { 236, 230, 216 }, reef = { 0, 3, 4, 5, 6, 7, 2 }, open = { 10, 1, 10, 1, 0 }, icy = false },
	{ name = "Atlantic Ocean", nameRu = "Атлантический океан", deep = { 11, 48, 54 }, shallow = { 47, 143, 140 }, wave = { 23, 79, 99 }, sand = { 214, 207, 189 }, reef = { 4, 7, 9, 8, 10 }, open = { 8, 9, 10, 8, 9 }, icy = false },
	{ name = "Indian Ocean", nameRu = "Индийский океан", deep = { 5, 58, 94 }, shallow = { 56, 184, 220 }, wave = { 19, 90, 133 }, sand = { 255, 246, 230 }, reef = { 0, 3, 4, 5, 6, 7, 2 }, open = { 1, 10, 1, 1, 0 }, icy = false },
	{ name = "Southern Ocean", nameRu = "Южный океан", deep = { 10, 42, 54 }, shallow = { 79, 143, 156 }, wave = { 18, 70, 92 }, sand = { 154, 152, 147 }, reef = { 11, 8 }, open = { 11, 8 }, icy = true },
	{ name = "Arctic Ocean", nameRu = "Северный Ледовитый океан", deep = { 12, 42, 46 }, shallow = { 90, 138, 134 }, wave = { 23, 63, 82 }, sand = { 140, 138, 132 }, reef = { 9, 8 }, open = { 8, 9 }, icy = true },
}

-- x, z, radius, hill height (metres)
Data.redSeaIslands = {
	{ 58, 82, 44, 4.5 },
	{ -96, 34, 50, 6 },
	{ -38, -112, 44, 4 },
	{ 112, -58, 52, 5.5 },
	{ 4, 168, 36, 3.5 },
	{ -150, -70, 34, 3 },
	{ 190, 120, 46, 5 },
	{ -205, 140, 42, 4 },
	{ 150, -205, 40, 4.5 },
	{ -60, 250, 34, 3.5 },
}

-- for each fish school: the island it lives by (0-based), or -1 for open water
Data.schoolHomes = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0, -1, -1, -1, -1, -1 }

return Data
