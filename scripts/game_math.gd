class_name GameMath
extends RefCounted

const BOOST_DRAIN_SECONDS := 2.0
const BOOST_RECHARGE_DELAY := 0.5
const BOOST_RECHARGE_SECONDS := 3.0
const MAX_REGULAR_GERMS := 35
const MAX_GERMS := 36
const MAX_FRAGMENTS := 80
const ELITE_FIRST_SPAWN := 20.0
const ELITE_SPAWN_INTERVAL := 30.0

static func update_boost(charge: float, delay_left: float, boosting: bool, delta: float) -> Dictionary:
	var next_charge := charge
	var next_delay := maxf(0.0, delay_left - delta)
	var active := boosting and next_charge > 0.0
	if active:
		next_charge = maxf(0.0, next_charge - delta / BOOST_DRAIN_SECONDS)
		next_delay = BOOST_RECHARGE_DELAY
		if next_charge <= 0.0:
			active = false
	elif next_delay <= 0.0:
		next_charge = minf(1.0, next_charge + delta / BOOST_RECHARGE_SECONDS)
	return {"charge": next_charge, "delay": next_delay, "active": active}


static func combo_after_kill(previous_combo: int, since_last_kill: float) -> int:
	if since_last_kill <= 2.0:
		return clampi(previous_combo + 1, 2, 5)
	return 1


static func awarded_score(base_score: int, combo: int) -> int:
	return base_score * maxi(1, combo)


static func active_germ_cap(run_seconds: float) -> int:
	return mini(MAX_REGULAR_GERMS, 5 + int(floor(run_seconds / 20.0)))


static func spawn_interval(run_seconds: float) -> float:
	return lerpf(1.3, 0.45, clampf(run_seconds / 180.0, 0.0, 1.0))


static func threat_speed_multiplier(run_seconds: float) -> float:
	return 1.0 + minf(0.5, floor(run_seconds / 60.0) * 0.1)


static func split_result(tier: int) -> Dictionary:
	match tier:
		GermData.GermTier.LARGE:
			return {"child_tier": GermData.GermTier.MEDIUM, "children": 2, "fragments": 3}
		GermData.GermTier.MEDIUM:
			return {"child_tier": GermData.GermTier.SMALL, "children": 2, "fragments": 2}
		GermData.GermTier.SMALL:
			return {"child_tier": -1, "children": 0, "fragments": 1}
		GermData.GermTier.ELITE:
			return {"child_tier": -1, "children": 0, "fragments": 4}
	return {"child_tier": -1, "children": 0, "fragments": 0}


static func membrane_is_lethal(outward_speed: float, threshold: float = 240.0) -> bool:
	return outward_speed > threshold


static func hostile_collision_is_lethal(spawn_protection_left: float) -> bool:
	return spawn_protection_left <= 0.0
