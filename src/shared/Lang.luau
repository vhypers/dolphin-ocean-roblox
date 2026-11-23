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
	-- R2: sharks, her Hit, her family and pod, the calf, the sonar
	["Swim with the arrows, WASD or the mouse. Yellow dots on the sonar are fish"] = "Плыви стрелками, WASD или мышью. Жёлтые точки на сонаре: рыба",
	["Shark! Press Hit (%s) and Spring rams it with her snout. Or call your pod (%s)"] = "Акула! Нажми «Удар» (%s), и Спринг сама ударит её носом. Или зови стаю (%s)",
	["The shallows by an island are safe: too shallow for sharks"] = "На мелководье у острова безопасно: акулам тут слишком мелко",
	["Snout hit! The shark swims away"] = "Удар носом! Акула удирает",
	["Ouch, a shark got you!"] = "Ой, поймали!",
	["Spring is gathering strength for another hit"] = "Спринг набирается сил для удара",
	["No sharks nearby"] = "Акул рядом нет",
	["Charge!"] = "В атаку!",
	["Your family isn't with you yet. Find them first!"] = "Твоей семьи пока нет рядом. Сначала найди родных!",
	["Your pod is resting, wait a little"] = "Стая отдыхает, подожди немного",
	["No sharks nearby. Your pod will help when they come"] = "Акул рядом нет. Стая поможет, когда они появятся",
	["Your pod chases the shark away!"] = "Стая прогоняет акулу!",
	["Your pod chases the sharks away!"] = "Стая прогоняет акул!",
	["Your cousin found you!"] = "Тебя нашёл двоюродный брат!",
	["Your aunt found you!"] = "Тебя нашла тётя!",
	["Your best friend found you!"] = "Тебя нашла лучшая подруга!",
	["Your big sister found you!"] = "Тебя нашла старшая сестра!",
	["Your grandmother found you!"] = "Тебя нашла бабушка!",
	["Your little brother found you!"] = "Тебя нашёл младший брат!",
	["Your uncle found you!"] = "Тебя нашёл дядя!",
	["You found your mother!"] = "Ты нашла маму!",
	["Spring found her mother. The whole family is together again!"] = "Спринг нашла маму. Вся семья снова вместе!",
	["Sam heard whistles! Someone from your family is nearby. Look for the pink heart on the sonar"] = "Сэм услышал свист! Кто-то из твоей семьи рядом. Ищи розовое сердечко на сонаре",
	["Sam heard your mother's whistle! She is nearby. Look for the pink heart on the sonar"] = "Сэм услышал свист твоей мамы! Она рядом. Ищи розовое сердечко на сонаре",
	["A calf was born in your pod! Protect it and feed it"] = "В стае родился малыш! Береги и корми его",
	["The calf is hungry! Lead it through a school of fish"] = "Малыш голоден! Проведи его через стаю рыб",
	["The calf has grown up and joined the pod!"] = "Малыш вырос и стал взрослым дельфином стаи!",
	["The calf has grown up and swum off on its own!"] = "Малыш вырос и уплыл в самостоятельное плавание!",
	["A shark scared the calf! Keep sharks away"] = "Акула напугала малыша! Не подпускай акул",
	["A shark attacked the calf!"] = "Акула напала на малыша!",
	["A shark attacked the calf! You shielded it. Keep sharks away"] = "Акула напала на малыша! Ты закрыла его собой. Не подпускай акул",
	["Level %d! Sharks are faster"] = "Уровень %d! Акулы быстрее",
	["Fish %d   Pod %d"] = "Рыба %d   Стая %d",
	["Calf"] = "Малыш",
	["well fed"] = "сыт",
	["hungry"] = "хочет есть",
	["very hungry!"] = "голоден!",
	["Hit"] = "Удар",
	["Pod"] = "Стая",
	["Sonar"] = "Сонар",
	["Hit rams a shark, your Pod chases it off"] = "«Удар» бьёт акулу, «Стая» прогоняет",
	["The bigger your pod, the more sharks it chases away"] = "Чем больше стая, тем больше акул она прогонит",
	["family found"] = "родных нашлось",
	["%d of %d"] = "%d из %d",
	-- R3: the story and Sam
	["This is Spring. She lived with her family in a warm, quiet bay."] = "Это Спринг. Она жила со своей семьёй в тёплой тихой бухте.",
	["Every day was the same: eat, sleep, hunt, and eat again."] = "Каждый день был похож на другой: поесть, поспать, поохотиться и снова поесть.",
	["But Spring was the most curious dolphin of them all."] = "Но Спринг была самой любопытной из всех.",
	["One day she swam too close to a fishing net and got caught."] = "Однажды она подплыла слишком близко к рыболовной сети и запуталась.",
	["The fishermen set her free, but her tail was badly hurt."] = "Рыбаки отпустили её, но хвост был сильно поранен.",
	["Too weak to swim, she was carried by the waves to a beach."] = "У неё не было сил плыть, и волны вынесли её на берег.",
	["There a boy named Sam found her and called the rescuers."] = "Там её нашёл мальчик по имени Сэм и позвал спасателей.",
	["Weeks later, Sam set her free. Now she must find her family. Sam's boat will follow her."] = "Через несколько недель Сэм выпустил её в море. Теперь ей нужно найти свою семью. Лодка Сэма поплывёт за ней.",
	["Watch the story"] = "Смотреть историю",
	["Sam asks: %s"] = "Сэм просит: %s",
	["%d  Sam's task"] = "%d  Задание Сэма",
	["Done!"] = "Готово!",
	["Task done! A star and a heart"] = "Задание выполнено! Звезда и сердечко",
	["Task done! The star is yours"] = "Задание выполнено! Звезда твоя",
	["Sam cheers for you!"] = "Сэм радуется за тебя!",
	["catch 5 %s"] = "поймай 5 %s",
	["stars earned"] = "получено звёзд",
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
	["Roblox step R3 \"The story and Sam\""] = "Roblox, шаг R3 «История и Сэм»",
	["Space, Enter or click: skip"] = "Пробел, Enter или щелчок: пропустить",
	["Do Sam's task each day for a star"] = "Каждый день выполняй задание Сэма и получай звезду",
	["Hit: X, Q or click. Pod: F or E"] = "Удар: X, Q или щелчок. Стая: F или E",
	["sharks driven off"] = "акул прогнано",
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
