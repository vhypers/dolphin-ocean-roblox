--!strict
-- English by default, Russian in Settings. Russian texts come from the Godot game's
-- data/lang_ru.json, which addresses the player in the feminine (Спринг is a she).
-- No em dash in game text.

local Lang = {}

Lang.language = "en"

local RU: { [string]: string } = {
	-- from the Godot game
	["A breath! Your air is full again"] = "Вдох! Воздуха снова полно",
	["Air"] = "Воздух",
	["Air is running out! Swim up to breathe"] = "Воздух кончается! Плыви наверх, чтобы вдохнуть",
	["Back"] = "Назад",
	["Boost"] = "Рывок",
	["Come up to breathe every minute"] = "Всплывай подышать каждую минуту",
	["Continue!"] = "Дальше!",
	["Day %d has begun!"] = "Настал день %d!",
	["Day %d of %d"] = "День %d из %d",
	["Day %d. Good luck!"] = "День %d. Удачи!",
	["Fewer and slower sharks, more time before hunger. When your hearts run out, Sam and the rescuers help."] = "Акул меньше, и они медленнее, голод наступает позже. Когда кончаются сердечки, помогают Сэм и спасатели.",
	["Find your family across the oceans in 30 days!"] = "Найди свою семью в океанах Земли за 30 дней!",
	["Food"] = "Еда",
	["Gentle"] = "Лёгкая",
	["Hard"] = "Сложная",
	["Jump"] = "Прыжок",
	["Language: %s"] = "Язык: %s",
	["Night has fallen. Be careful!"] = "Наступила ночь. Будь осторожна!",
	["Now you see through Spring's eyes"] = "Теперь ты смотришь глазами Спринг",
	["Pause"] = "Пауза",
	["Paused"] = "Пауза",
	["Sam and the rescuers are on their way..."] = "Сэм и спасатели уже спешат на помощь...",
	["Sam and the rescuers helped you. Swim on!"] = "Сэм и спасатели помогли тебе. Плыви дальше!",
	["Spring"] = "Спринг",
	["Spring got too hungry!"] = "Спринг слишком проголодалась!",
	["Spring is hungry! Catch a fish quickly"] = "Спринг проголодалась! Скорее поймай рыбу",
	["Spring ran out of air! Up, quickly!"] = "Спринг не хватило воздуха! Скорее наверх!",
	["Spring's tail heals day by day and at healing corals"] = "Хвост Спринг заживает день за днём и у лечебных кораллов",
	["Swim!"] = "Плыть!",
	["Swimming up to jump!"] = "Плыву наверх, чтобы прыгнуть!",
	["The last day! Hold on!"] = "Последний день! Держись!",
	["View"] = "Вид",
	["You ran out of air!"] = "Не хватило воздуха!",
	["Your tail has healed! Full speed again!"] = "Хвост зажил! Снова полная скорость!",
	["%d m"] = "%d м",
	["Leap!"] = "Прыжок!",
	["Slow motion! Look around with the arrows or the mouse"] = "Замедление! Осмотрись стрелками или мышью",
	["Spin!"] = "Вращение!",
	["Double spin!"] = "Двойное вращение!",
	["Triple spin!"] = "Тройное вращение!",
	-- new in the Roblox version
	["Building the ocean... %d%%"] = "Строим океан... %d%%",
	["Difficulty: %s"] = "Сложность: %s",
	["English"] = "English",
	["Russian"] = "Русский",
	["Fish %d"] = "Рыба %d",
	["Catch fish so Spring isn't hungry"] = "Лови рыбу, чтобы Спринг не голодала",
	["This is the edge of the ocean. Turn back!"] = "Здесь край океана. Поворачивай назад!",
	["Swim: WASD or arrows, or hold the left mouse button and drag"] = "Плыть: WASD или стрелки, или зажми левую кнопку мыши и веди",
	["Boost: Space, Shift or hold the right mouse button"] = "Рывок: пробел, Shift или зажми правую кнопку мыши",
	["Jump: J, Enter or the mouse wheel. Rise steeply to leap"] = "Прыжок: J, Enter или колёсико мыши. Резко всплыви, чтобы выпрыгнуть",
	["Hold Boost in the air to spin"] = "Держи «Рывок» в воздухе, чтобы вращаться",
	["Look back: B   Spring's eyes: V   Pause: P"] = "Назад: B   Глаза Спринг: V   Пауза: P",
	["Roblox step R1 \"First swim\""] = "Roblox, шаг R1 «Первый заплыв»",
	["Play again"] = "Играть снова",
	["fish caught"] = "поймано рыб",
	["days lived"] = "прожито дней",
	["spins in the air"] = "вращений в воздухе",
	["You swam through all 30 days!"] = "Ты проплавала все 30 дней!",
	["The game is over"] = "Игра окончена",
	["Back to the menu"] = "В меню",
}

function Lang.t(text: string): string
	if Lang.language == "ru" then
		return RU[text] or text
	end
	return text
end

function Lang.f(text: string, ...: any): string
	return string.format(Lang.t(text), ...)
end

-- every English text that has a Russian one (for the tests)
function Lang.keys(): { string }
	local all = {}
	for key in RU do
		table.insert(all, key)
	end
	return all
end

return Lang
