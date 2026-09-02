class_name BoonData
extends RefCounted

enum BoonType {
	DASH_EVADE,
	SPEED_BOOSTS,
	POINT_MULTIPLIER,
	INVINCIBILITY,
	GOO_TRAIL_BOOST,
	FREEZE_AOE_SHOCK,
	MOVEMENT_SPEED,
	CHARGED_BEAM,
	MAX_HEALTH,
}

const NO_BOON := -1
const MAX_LEVEL := 2
const CHOICE_COUNT := 3
const CHOICE_LOCK_SECONDS := 2.0
const CHOICE_PICKUP_RADIUS := 28.0
const GOO_POOL_SIZE := 64
const GOO_HIT_COOLDOWN := 0.45
const BEAM_CHARGE_SECONDS := 1.5
const BEAM_DURATION_SECONDS := 3.0
const BEAM_TICK_SECONDS := 0.2


static func display_name(boon_type: int) -> String:
	match boon_type:
		BoonType.DASH_EVADE:
			return "DASH EVADE"
		BoonType.SPEED_BOOSTS:
			return "SPEED BOOSTS"
		BoonType.POINT_MULTIPLIER:
			return "POINT MULTIPLIER"
		BoonType.INVINCIBILITY:
			return "INVINCIBILITY"
		BoonType.GOO_TRAIL_BOOST:
			return "GOO TRAIL BOOST"
		BoonType.FREEZE_AOE_SHOCK:
			return "FREEZE SHOCK"
		BoonType.MOVEMENT_SPEED:
			return "MOVEMENT SPEED"
		BoonType.CHARGED_BEAM:
			return "CHARGED BEAM"
		BoonType.MAX_HEALTH:
			return "MAX HEALTH"
	return "BOON"


static func short_label(boon_type: int) -> String:
	match boon_type:
		BoonType.DASH_EVADE:
			return "DASH"
		BoonType.INVINCIBILITY:
			return "INVINCIBLE"
		BoonType.GOO_TRAIL_BOOST:
			return "GOO BOOST"
		BoonType.FREEZE_AOE_SHOCK:
			return "FREEZE"
	return display_name(boon_type)


static func control_label(boon_type: int) -> String:
	if is_space_boon(boon_type):
		return "SPACE"
	if boon_type == BoonType.CHARGED_BEAM:
		return "HOLD FIRE"
	return "PASSIVE"


static func color(boon_type: int) -> Color:
	match boon_type:
		BoonType.DASH_EVADE:
			return Color("55DDE0")
		BoonType.SPEED_BOOSTS:
			return Color("DCFF84")
		BoonType.POINT_MULTIPLIER:
			return Color("FFD9A6")
		BoonType.INVINCIBILITY:
			return Color("EFCEFD")
		BoonType.GOO_TRAIL_BOOST:
			return Color("8BCF68")
		BoonType.FREEZE_AOE_SHOCK:
			return Color("A8F4FF")
		BoonType.MOVEMENT_SPEED:
			return Color("FF9E73")
		BoonType.CHARGED_BEAM:
			return Color("FF6B6B")
		BoonType.MAX_HEALTH:
			return Color("FF7F8A")
	return Color.WHITE


static func level_cap(boon_type: int) -> int:
	return 1 if boon_type == BoonType.MAX_HEALTH else MAX_LEVEL


static func player_max_health(level: int) -> int:
	return 5 if level > 0 else 3


static func is_space_boon(boon_type: int) -> bool:
	return boon_type == BoonType.DASH_EVADE or boon_type == BoonType.INVINCIBILITY or boon_type == BoonType.GOO_TRAIL_BOOST or boon_type == BoonType.FREEZE_AOE_SHOCK


static func movement_multiplier(level: int) -> float:
	return 1.0 + 0.15 * clampi(level, 0, MAX_LEVEL)


static func mobility_speed_multiplier(level: int) -> float:
	return 1.0 + 0.15 * clampi(level, 0, MAX_LEVEL)


static func mobility_duration_multiplier(level: int) -> float:
	return 1.0 + 0.10 * clampi(level, 0, MAX_LEVEL)


static func mobility_recharge_multiplier(level: int) -> float:
	return 1.0 + 0.15 * clampi(level, 0, MAX_LEVEL)


static func point_multiplier(level: int) -> float:
	match clampi(level, 0, MAX_LEVEL):
		1:
			return 1.5
		2:
			return 2.0
	return 1.0


static func dash_speed(level: int) -> float:
	return 700.0 if level >= 2 else 600.0


static func dash_duration(level: int) -> float:
	return 0.22 if level >= 2 else 0.18


static func dash_cooldown(level: int) -> float:
	return 2.0 if level >= 2 else 2.5


static func invincibility_duration(level: int) -> float:
	return 3.0 if level >= 2 else 2.0


static func invincibility_cooldown(level: int) -> float:
	return 10.0 if level >= 2 else 12.0


static func goo_accel_multiplier(level: int) -> float:
	return 2.0 if level >= 2 else 1.8


static func goo_speed_multiplier(level: int) -> float:
	return 1.7 if level >= 2 else 1.5


static func goo_radius(level: int) -> float:
	return 28.0 if level >= 2 else 24.0


static func goo_lifetime(level: int) -> float:
	return 5.0 if level >= 2 else 4.0


static func goo_interval(level: int) -> float:
	return 0.12 if level >= 2 else 0.15


static func freeze_radius(level: int) -> float:
	return 220.0 if level >= 2 else 180.0


static func freeze_duration(level: int) -> float:
	return 4.0 if level >= 2 else 3.0


static func freeze_cooldown(level: int) -> float:
	return 8.0 if level >= 2 else 10.0


static func beam_width(level: int) -> float:
	return 24.0 if level >= 2 else 18.0


static func beam_damage(level: int) -> int:
	return 6 if level >= 2 else 4
