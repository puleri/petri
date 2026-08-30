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
			"THE PRONOUN BOX HAS GONE TOO FAR!",
			"LANGUAGE IS THE FINAL BATTLEGROUND!",
		],
		"medium": [
			["WORDS HAVE ALWAYS MEANT WHAT I SAY!", "GRAMMAR IS NOT A FEELING!"],
			["ONE WRONG WORD REVEALS EVERYTHING!", "YOUR BIO NEEDS MORE CONTEXT!"],
		],
		"small": [
			["COMMON SENSE! ALL CAPS!", "THE DICTIONARY IS ON MY SIDE!"],
			["UPDATE YOUR VOCABULARY OR ELSE!", "EVERY TYPO IS A RED FLAG!"],
		],
	},
	{
		"opener": [
			"THIS BOOK WILL DECIDE THE CHILDREN!",
			"THE LIBRARY HAS ENTERED THE WAR!",
		],
		"medium": [
			["BAN IT FOR THE CHILDREN!", "A LIBRARY SHOULD NEVER CHALLENGE ME!"],
			["READING IT IS RESISTANCE!", "MAKE EVERY BANNED BOOK REQUIRED!"],
		],
		"small": [
			["PAPERBACK PANIC!", "CLOSE THE LIBRARY!"],
			["ANNOTATE THE REVOLUTION!", "PUT IT ON EVERY SYLLABUS!"],
		],
	},
	{
		"opener": [
			"SOMEONE IS WRONG ON THE INTERNET!",
			"THE REPLY GUY DEMANDS A HEARING!",
		],
		"medium": [
			["FREE SPEECH MEANS YOU OWE ME A PLATFORM!", "CENSORSHIP IS WHEN YOU BLOCK ME!"],
			["DISAGREEMENT IS BASICALLY VIOLENCE!", "ACCOUNTABILITY NEEDS NO APPEAL!"],
		],
		"small": [
			["DEBATE ME OR YOU LOSE!", "UNBAN MY 47TH ACCOUNT!"],
			["BLOCK FIRST! CONTEXT LATER!", "DELETE THE WHOLE THREAD!"],
		],
	},
	{
		"opener": [
			"THE ALGORITHM DISCOVERED TRADITION!",
			"DOMESTIC LIFE IS NOW A BATTLEGROUND!",
		],
		"medium": [
			["MY TRADITIONAL LIFE NEEDS A RING LIGHT!", "HISTORY AGREES WITH MY PODCAST!"],
			["DOMESTICITY IS A STRUCTURAL EMERGENCY!", "TRADITION IS PEER PRESSURE FROM GHOSTS!"],
		],
		"small": [
			["SUBMIT AND SUBSCRIBE!", "THE PAST HAD BETTER LIGHTING!"],
			["DECONSTRUCT THE SOURDOUGH!", "YOUR APRON IS POLITICAL!"],
		],
	},
	{
		"opener": [
			"HR HAS ENTERED THE DISCOURSE!",
			"THE ORG CHART CLAIMS TO BE NEUTRAL!",
		],
		"medium": [
			["MERITOCRACY BEGAN RIGHT AFTER I WON!", "MY ADVANTAGE IS JUST GOOD CULTURE!"],
			["PUT JUSTICE IN THE QUARTERLY DECK!", "REPRESENTATION NEEDS A KPI!"],
		],
		"small": [
			["SKILL ISSUE! SYSTEM SOLVED!", "IGNORE THE ORG CHART!"],
			["MANDATORY BELONGING MODULE!", "DIVERSITY, NOW WITH DASHBOARDS!"],
		],
	},
	{
		"opener": [
			"BREAKFAST IS NOW A POLICY POSITION!",
			"THE WEATHER HAS BECOME PERSONAL!",
		],
		"medium": [
			["THEY'RE COMING FOR YOUR GAS STOVE!", "MY TRUCK IS A CONSTITUTIONAL RIGHT!"],
			["YOUR BREAKFAST IS A POLICY FAILURE!", "CARBON-SCORE THE BRUNCH!"],
		],
		"small": [
			["GRILL LIKE LIBERTY DEPENDS ON IT!", "OWN THE WEATHER!"],
			["BAN THE BRUNCH!", "COMPOST YOUR PERSONALITY!"],
		],
	},
	{
		"opener": [
			"THE MACHINE MADE A PICTURE!",
			"ART HAS ACCEPTED THE TERMS OF SERVICE!",
		],
		"medium": [
			["I TYPED THE PROMPT. I'M THE ARTIST!", "AUTOMATION DEMOCRATIZED MY TALENT!"],
			["EVERY PIXEL IS STOLEN!", "YOUR MASTERPIECE HAS TERMS OF SERVICE!"],
		],
		"small": [
			["ONE CLICK! THIRTY YEARS OF CRAFT!", "SHIP THE SLOP!"],
			["UNPLUG THE MUSE!", "CITE EVERY PIXEL!"],
		],
	},
	{
		"opener": [
			"SELF-CARE HAS A SALES FUNNEL!",
			"THE PODCAST CAN FIX YOUR PERSONALITY!",
		],
		"medium": [
			["REAL MEN SUBSCRIBE TO MY COURSE!", "ALPHA STATUS BILLS MONTHLY!"],
			["I HEALED MY TRAUMA WITH A BRAND DEAL!", "VULNERABILITY, LINK IN BIO!"],
		],
		"small": [
			["MONETIZE THE JAWLINE!", "COLD-PLUNGE THE FEELINGS!"],
			["THERAPY-SPEAK SPEEDRUN!", "BOUNDARIES, BUT SPONSORED!"],
		],
	},
]

const ELITE_LINES := [
	"WE A/B TESTED BOTH SIDES.",
	"ANGER RETAINS USERS.",
	"YOUR ENEMY SAW THE SAME AD.",
	"ENGAGEMENT UP. SOLIDARITY DOWN.",
	"OUTRAGE CONVERTS.",
	"DIVISION IS A GROWTH MARKET.",
]

const PLAYER_LINES := [
	"Funny how wages never trend.",
	"They sell both sides the megaphones.",
	"Keep fighting sideways. The penthouse loves it.",
	"Every outrage has a sponsor.",
	"Culture war has one winner: the ruling class.",
	"The feed gets rich. We get furious.",
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
