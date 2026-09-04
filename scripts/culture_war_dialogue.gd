class_name CultureWarDialogue
extends RefCounted

enum Topic {
	PRONOUNS,
	BOOKS,
	FREE_SPEECH,
	TRAD_LIFE,
	MERITOCRACY,
	CLIMATE_LIFESTYLE,
	AI_ART,
	WELLNESS_MASCULINITY,
}

const STANCE_A := 0
const STANCE_B := 1
const INTENSITY_OPENER := 0
const INTENSITY_MEDIUM := 1
const INTENSITY_SMALL := 2

const TOPICS := [
	{
		"opener": [
			"What do I do if I see an antibiotic?... Oh god!",
			"Fewf. You do not want to go in there.",
		],
		"medium": [
			[
				"I am gonna 3.14159 you!",
				"Come here and give me a kiss!"
			],
			[
				"hey!",
				"uh oh."
			],
		],
		"small": [
			[
				"Don't make me get the thermometer.",
				"I know what a spleen is!"
			],
			[
				"That's probably fine.",
				"Wait. Do you smell pennies?"
			],
		],
	},
	{
		"opener": [
			"Who put a little receipt in this book?",
			"Whoa. This one has a map at the beginning.",
		],
		"medium": [
			[
				"I've already read eleven pages!",
				"Don't tell me what happens to Mr. Pickles."
			],
			[
				"That's not a bookmark. That's trash.",
				"I read the back. Basically finished it."
			],
		],
		"small": [
			[
				"Chapter seven. Bad neighborhood.",
				"This font is way too confident."
			],
			[
				"Hang on, I'm sounding this one out.",
				"Ooh. An appendix."
			],
		],
	},
	{
		"opener": [
			"Somebody on the internet knows my name.",
			"I clicked one thing and now everybody's mad.",
		],
		"medium": [
			[
				"I have seventeen tabs and they're all important.",
				"Don't worry. I replied 'interesting.'"
			],
			[
				"Turn the Wi-Fi off!",
				"I accidentally liked something from 2018."
			],
		],
		"small": [
			[
				"Refresh it again.",
				"They can tell I'm online."
			],
			[
				"Delete the evidence.",
				"Put the phone face down."
			],
		],
	},
	{
		"opener": [
			"I made soup but something has happened.",
			"Nobody touch that container. It's thinking.",
		],
		"medium": [
			[
				"The recipe said one clove. I used the bulb.",
				"I don't measure vanilla because I'm not a coward."
			],
			[
				"Why is the oven making that noise?",
				"That's not burnt. That's the flavor arriving."
			],
		],
		"small": [
			[
				"Taste this and be brave.",
				"More butter will fix it."
			],
			[
				"It's supposed to look wet.",
				"Put cheese on top. Quickly."
			],
		],
	},
	{
		"opener": [
			"Good news. There's another meeting.",
			"Someone said 'quick sync' and locked the door.",
		],
		"medium": [
			[
				"I made a spreadsheet about the spreadsheet.",
				"Can everybody see my screen? Don't answer."
			],
			[
				"I've been nodding for forty minutes.",
				"I don't know who Kevin is but I agree with him."
			],
		],
		"small": [
			[
				"Circle it back.",
				"Put it in the parking lot."
			],
			[
				"Great point, whoever said that.",
				"I'm double muted."
			],
		],
	},
	{
		"opener": [
			"The weather app has betrayed me.",
			"They said partly cloudy. This is extremely cloudy.",
		],
		"medium": [
			[
				"I dressed for seventy-two!",
				"The little sun icon lied to my face."
			],
			[
				"I brought an umbrella so now it won't rain.",
				"This wind has somewhere to be."
			],
		],
		"small": [
			[
				"I'm gonna fight the forecast.",
				"Too many degrees."
			],
			[
				"Here it comes!",
				"Nope. Just a leaf."
			],
		],
	},
	{
		"opener": [
			"The computer made a picture of my uncle.",
			"Okay. Why does the robot know about lighting?",
		],
		"medium": [
			[
				"I typed 'cool wizard' and brother, look at him.",
				"It gave the dog human teeth again."
			],
			[
				"Why are there seven fingers?",
				"Tell it fewer horses."
			],
		],
		"small": [
			[
				"Make him shinier.",
				"More fog!"
			],
			[
				"That's not a hand.",
				"Undo the baby."
			],
		],
	},
	{
		"opener": [
			"I've started waking up at five and it's horrible.",
			"A man on a podcast told me to buy magnesium.",
		],
		"medium": [
			[
				"I took a cold shower and saw the face of God.",
				"My morning routine is now four hours long."
			],
			[
				"I bought a special cup for water.",
				"Apparently I've been breathing wrong."
			],
		],
		"small": [
			[
				"Optimize me.",
				"I'm full of electrolytes."
			],
			[
				"Stretch your little legs.",
				"Go stand near a window."
			],
		],
	},
]

const ELITE_LINES := [
	"Excellent. They're arguing about soup.",
	"Put another chair in there.",
	"Somebody make the room slightly warmer.",
	"They don't know about the second meeting.",
	"Give them both a clipboard.",
	"Perfect. Nobody knows why they're here.",
]

const PLAYER_LINES := [
	"I think that guy just wants to go home.",
	"Nobody here seems qualified for this.",
	"I was told there would be snacks.",
	"This feels like somebody else's problem.",
	"I don't think we're supposed to be in this room.",
	"Okay. I'm gonna go look for a bathroom.",
]


static func topic_count() -> int:
	return TOPICS.size()


static func regular_line(topic_id: int, stance: int, intensity: int, variant_index: int = 0) -> String:
	var topic: Dictionary = TOPICS[posmod(topic_id, TOPICS.size())]
	if intensity <= INTENSITY_OPENER:
		return _variant(topic.opener, variant_index)
	var normalized_stance := clampi(stance, STANCE_A, STANCE_B)
	var lines_by_stance: Array = topic.medium if intensity == INTENSITY_MEDIUM else topic.small
	return _variant(lines_by_stance[normalized_stance], variant_index)


static func elite_line(variant_index: int = 0) -> String:
	return _variant(ELITE_LINES, variant_index)


static func player_line(variant_index: int = 0) -> String:
	return _variant(PLAYER_LINES, variant_index)


static func all_lines() -> Array[String]:
	var lines: Array[String] = []
	for topic in TOPICS:
		for line in topic.opener:
			lines.append(str(line))
		for intensity_key in ["medium", "small"]:
			for stance_lines in topic[intensity_key]:
				for line in stance_lines:
					lines.append(str(line))
	for line in ELITE_LINES:
		lines.append(str(line))
	for line in PLAYER_LINES:
		lines.append(str(line))
	return lines


static func _variant(lines: Array, variant_index: int) -> String:
	return str(lines[posmod(variant_index, lines.size())])
