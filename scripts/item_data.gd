class_name ItemData
extends RefCounted

enum ItemType {
	SPINNING_HITTER,
	AOE,
	TURRET,
	RICOCHET,
	SPREAD,
	LEAVE_BEHIND,
	CATALYST,
	PIERCING_DOSE,
	INHIBITOR_FIELD,
	ANTIBODY_SHELL,
	CATALYTIC_CLEANUP,
	SEEKING_ENZYME,
}

const MAX_LEVEL := 3
const OVERCHARGE_LEVEL := 4
const OVERCHARGE_SECONDS := 15.0


static func display_name(item_type: int) -> String:
	match item_type:
		ItemType.SPINNING_HITTER: return "SPINNING HITTER"
		ItemType.AOE: return "AOE"
		ItemType.TURRET: return "TURRET"
		ItemType.RICOCHET: return "RICOCHET"
		ItemType.SPREAD: return "SPREAD"
		ItemType.LEAVE_BEHIND: return "LEAVE-BEHIND"
		ItemType.CATALYST: return "CATALYST"
		ItemType.PIERCING_DOSE: return "PIERCING DOSE"
		ItemType.INHIBITOR_FIELD: return "INHIBITOR FIELD"
		ItemType.ANTIBODY_SHELL: return "ANTIBODY SHELL"
		ItemType.CATALYTIC_CLEANUP: return "CATALYTIC CLEANUP"
		ItemType.SEEKING_ENZYME: return "SEEKING ENZYME"
	return "ITEM"


static func color(item_type: int) -> Color:
	match item_type:
		ItemType.SPINNING_HITTER: return Color("#FF9E73")
		ItemType.AOE: return Color("#55DDE0")
		ItemType.TURRET: return Color("#77408E")
		ItemType.RICOCHET: return Color("#A9C375")
		ItemType.SPREAD: return Color("#C474E8")
		ItemType.LEAVE_BEHIND: return Color("#FFD9A6")
		ItemType.CATALYST: return Color("#E85D75")
		ItemType.PIERCING_DOSE: return Color("#4267AC")
		ItemType.INHIBITOR_FIELD: return Color("#4EAD8A")
		ItemType.ANTIBODY_SHELL: return Color("#E0A52B")
		ItemType.CATALYTIC_CLEANUP: return Color("#B35C9B")
		ItemType.SEEKING_ENZYME: return Color("#2E9CCA")
	return Color.WHITE


static func hitter_count(level: int) -> int:
	return clampi(level, 0, OVERCHARGE_LEVEL)


static func aoe_radius(level: int) -> float:
	match clampi(level, 0, OVERCHARGE_LEVEL):
		1: return 130.0
		2: return 150.0
		3: return 170.0
		4: return 190.0
	return 0.0


static func aoe_interval(level: int) -> float:
	match clampi(level, 0, OVERCHARGE_LEVEL):
		1: return 5.0
		2: return 4.25
		3: return 3.5
		4: return 2.75
	return INF


static func turret_interval(level: int) -> float:
	return 0.4 if level >= OVERCHARGE_LEVEL else 0.8


static func turret_range(level: int) -> float:
	return 360.0 if level >= OVERCHARGE_LEVEL else 300.0


static func ricochet_bounces(level: int) -> int:
	return clampi(level, 0, OVERCHARGE_LEVEL)


static func ricochet_lifetime(level: int) -> float:
	if level <= 0:
		return 1.25
	return 1.25 + 0.35 * float(clampi(level, 1, OVERCHARGE_LEVEL))


static func spread_angles(level: int) -> PackedFloat32Array:
	var angles := PackedFloat32Array([0.0])
	for step in clampi(level, 0, OVERCHARGE_LEVEL):
		var angle := deg_to_rad(12.0 * float(step + 1))
		angles.append(-angle)
		angles.append(angle)
	return angles


static func mine_interval(level: int) -> float:
	match clampi(level, 0, OVERCHARGE_LEVEL):
		1: return 1.4
		2: return 1.1
		3: return 0.85
		4: return 0.6
	return INF


static func mine_blast_radius(level: int) -> float:
	return 70.0 if level >= OVERCHARGE_LEVEL else 55.0


static func catalyst_shots_per_second(level: int) -> float:
	match clampi(level, 0, OVERCHARGE_LEVEL):
		1: return 6.75
		2: return 7.5
		3: return 8.5
		4: return 10.0
	return 6.0


static func catalyst_fire_interval(level: int) -> float:
	return 1.0 / catalyst_shots_per_second(level)


static func piercing_targets(level: int) -> int:
	match clampi(level, 0, OVERCHARGE_LEVEL):
		1: return 1
		2: return 2
		3: return 3
		4: return 5
	return 0


static func inhibitor_radius(level: int) -> float:
	match clampi(level, 0, OVERCHARGE_LEVEL):
		1: return 110.0
		2: return 135.0
		3: return 160.0
		4: return 190.0
	return 0.0


static func inhibitor_speed_multiplier(level: int) -> float:
	match clampi(level, 0, OVERCHARGE_LEVEL):
		1: return 0.8
		2: return 0.7
		3: return 0.6
		4: return 0.45
	return 1.0


static func antibody_recharge(level: int) -> float:
	match clampi(level, 0, OVERCHARGE_LEVEL):
		1: return 32.0
		2: return 24.0
		3: return 16.0
		4: return 8.0
	return INF


static func antibody_pulse_radius(level: int) -> float:
	match clampi(level, 0, OVERCHARGE_LEVEL):
		1: return 90.0
		2: return 105.0
		3: return 120.0
		4: return 150.0
	return 0.0


static func cleanup_radius(level: int) -> float:
	match clampi(level, 0, OVERCHARGE_LEVEL):
		1: return 45.0
		2: return 60.0
		3: return 75.0
		4: return 95.0
	return 0.0


static func cleanup_damage(level: int) -> int:
	return 2 if level >= OVERCHARGE_LEVEL else (1 if level > 0 else 0)


static func seeking_range(level: int) -> float:
	match clampi(level, 0, OVERCHARGE_LEVEL):
		1: return 170.0
		2: return 240.0
		3: return 320.0
		4: return 500.0
	return 0.0


static func seeking_turn_speed(level: int) -> float:
	match clampi(level, 0, OVERCHARGE_LEVEL):
		1: return 1.2
		2: return 2.0
		3: return 3.0
		4: return 5.0
	return 0.0
