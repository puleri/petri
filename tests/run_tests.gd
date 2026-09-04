extends SceneTree

var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("_run_suite")


func _run_suite() -> void:
	print("PETRI deterministic test suite")
	_test_boost()
	_test_scoring_and_combo()
	_test_splitting()
	_test_spawn_ramp()
	_test_persistence()
	_test_collisions()
	_test_resources_and_scene()
	_test_item_specs()
	_test_elite_and_pickup_flow()
	_test_item_selection_and_overcharge()
	_test_item_combat_effects()
	_test_additional_item_combat_effects()
	_test_long_run_pool_stability()
	await process_frame
	await process_frame
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS  ", label)
	else:
		failures += 1
		push_error("FAIL  " + label)


func _test_boost() -> void:
	var charge := 1.0
	var delay := 0.0
	for i in 20:
		var next := GameMath.update_boost(charge, delay, true, 0.1)
		charge = float(next.charge)
		delay = float(next.delay)
	_check(is_zero_approx(charge), "boost drains in about two seconds")
	var waiting := GameMath.update_boost(charge, delay, false, 0.49)
	_check(is_zero_approx(float(waiting.charge)), "boost waits before recharge")
	charge = float(waiting.charge)
	delay = float(waiting.delay)
	var after_delay := GameMath.update_boost(charge, delay, false, 0.02)
	charge = float(after_delay.charge)
	delay = float(after_delay.delay)
	for i in 30:
		var next := GameMath.update_boost(charge, delay, false, 0.1)
		charge = float(next.charge)
		delay = float(next.delay)
	_check(is_equal_approx(charge, 1.0), "boost recharges in about three seconds")


func _test_scoring_and_combo() -> void:
	_check(GameMath.combo_after_kill(1, 1.0) == 2, "second quick kill starts x2 combo")
	_check(GameMath.combo_after_kill(5, 0.25) == 5, "combo caps at x5")
	_check(GameMath.combo_after_kill(4, 2.01) == 1, "combo resets after two seconds")
	_check(GameMath.awarded_score(100, 4) == 400, "score applies combo multiplier")


func _test_splitting() -> void:
	var large := GameMath.split_result(GermData.GermTier.LARGE)
	var medium := GameMath.split_result(GermData.GermTier.MEDIUM)
	var small := GameMath.split_result(GermData.GermTier.SMALL)
	var elite := GameMath.split_result(GermData.GermTier.ELITE)
	_check(int(large.children) == 2 and int(large.fragments) == 3 and int(large.child_tier) == GermData.GermTier.MEDIUM, "large germ split recipe")
	_check(int(medium.children) == 2 and int(medium.fragments) == 2 and int(medium.child_tier) == GermData.GermTier.SMALL, "medium germ split recipe")
	_check(int(small.children) == 0 and int(small.fragments) == 1, "small germ split recipe")
	_check(int(elite.children) == 0 and int(elite.fragments) == 4, "elite destruction recipe")


func _test_spawn_ramp() -> void:
	_check(GameMath.active_germ_cap(0.0) == 5, "run starts with germ cap five")
	_check(GameMath.active_germ_cap(60.0) == 8, "germ cap grows every twenty seconds")
	_check(GameMath.active_germ_cap(9999.0) == 35, "germ cap never exceeds thirty-five")
	_check(is_equal_approx(GameMath.spawn_interval(0.0), 1.3), "spawn interval starts at 1.3 seconds")
	_check(is_equal_approx(GameMath.spawn_interval(180.0), 0.45), "spawn interval reaches 0.45 seconds")
	_check(is_equal_approx(GameMath.threat_speed_multiplier(300.0), 1.5), "threat speed caps at plus fifty percent")
	_check(is_equal_approx(GameMath.ELITE_FIRST_SPAWN, 20.0) and is_equal_approx(GameMath.ELITE_SPAWN_INTERVAL, 30.0), "elite cadence constants")


func _test_persistence() -> void:
	var path := "user://petri-test.cfg"
	var store := SaveStore.new(path)
	var data := store.defaults()
	data.best_score = 4321
	data.best_time = 87.5
	data.reduced_motion = true
	_check(store.save_data(data) == OK, "persistence writes config")
	var loaded := store.load_data()
	_check(int(loaded.best_score) == 4321 and is_equal_approx(float(loaded.best_time), 87.5), "persistence restores bests")
	_check(bool(loaded.reduced_motion), "persistence restores preferences")
	var changed := store.update_bests(4200, 91.0, loaded)
	_check(changed and int(loaded.best_score) == 4321 and is_equal_approx(float(loaded.best_time), 91.0), "persistence updates best fields independently")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_collisions() -> void:
	_check(not GameMath.membrane_is_lethal(239.9), "normal membrane impact rebounds")
	_check(GameMath.membrane_is_lethal(240.1), "boost-speed membrane impact is lethal")
	_check(not GameMath.hostile_collision_is_lethal(0.01), "spawn protection blocks hostile death")
	_check(GameMath.hostile_collision_is_lethal(0.0), "hostile contact is lethal after protection")


func _test_resources_and_scene() -> void:
	var large: GermData = load("res://data/germ_large.tres")
	var medium: GermData = load("res://data/germ_medium.tres")
	var small: GermData = load("res://data/germ_small.tres")
	var elite: GermData = load("res://data/germ_elite.tres")
	_check(large.hp == 3 and large.score == 100, "large germ data resource")
	_check(medium.hp == 2 and medium.score == 50, "medium germ data resource")
	_check(small.hp == 1 and small.score == 25, "small germ data resource")
	_check(elite.hp == 18 and elite.radius == 66.0 and elite.score == 600 and elite.fragment_count == 4, "tank elite data resource")
	_check(load("res://assets/figma/petri-logo.png") != null, "Figma PETRI logo loads")
	_check(load("res://scenes/main.tscn") != null, "main scene loads")


func _test_item_specs() -> void:
	_check(ItemData.ItemType.size() == 12 and ItemData.MAX_LEVEL == 3, "twelve item types with level-three cap")
	_check(ItemData.hitter_count(1) == 1 and ItemData.hitter_count(4) == 4, "spinning hitter count curve")
	_check(is_equal_approx(ItemData.aoe_radius(3), 170.0) and is_equal_approx(ItemData.aoe_interval(4), 2.75), "AOE radius and interval curve")
	_check(is_equal_approx(ItemData.turret_interval(3), 0.8) and is_equal_approx(ItemData.turret_interval(4), 0.4), "turret overcharge fire rate")
	_check(ItemData.ricochet_bounces(3) == 3 and is_equal_approx(ItemData.ricochet_lifetime(3), 2.3), "ricochet bounce and lifetime curve")
	_check(ItemData.spread_angles(3).size() == 7 and is_equal_approx(absf(ItemData.spread_angles(3)[6]), deg_to_rad(36.0)), "spread count and outer angle")
	_check(is_equal_approx(ItemData.mine_interval(1), 1.4) and is_equal_approx(ItemData.mine_blast_radius(4), 70.0), "leave-behind mine curve")
	_check(is_equal_approx(ItemData.catalyst_shots_per_second(3), 8.5) and is_equal_approx(ItemData.catalyst_shots_per_second(4), 10.0), "catalyst fire-rate curve")
	_check(ItemData.piercing_targets(1) == 1 and ItemData.piercing_targets(4) == 5, "piercing dose target curve")
	_check(is_equal_approx(ItemData.inhibitor_radius(3), 160.0) and is_equal_approx(ItemData.inhibitor_speed_multiplier(4), 0.45), "inhibitor field curve")
	_check(is_equal_approx(ItemData.antibody_recharge(3), 16.0) and is_equal_approx(ItemData.antibody_pulse_radius(4), 150.0), "antibody shell curve")
	_check(is_equal_approx(ItemData.cleanup_radius(3), 75.0) and ItemData.cleanup_damage(4) == 2, "catalytic cleanup curve")
	_check(is_equal_approx(ItemData.seeking_range(3), 320.0) and is_equal_approx(ItemData.seeking_turn_speed(4), 5.0), "seeking enzyme curve")


func _test_elite_and_pickup_flow() -> void:
	var game := _new_game()
	game.call("_start_run")
	game.get("spawn_warnings").clear()
	game.set("elite_timer", 0.0)
	game.set("spawn_protection_left", 9999.0)
	game.call("_update_run", 0.01)
	var elite_warnings := 0
	for warning in Array(game.get("spawn_warnings")):
		if int(warning.tier) == GermData.GermTier.ELITE: elite_warnings += 1
	_check(elite_warnings == 1 and is_equal_approx(float(game.get("elite_timer")), 30.0), "elite queues at scheduled cadence")
	_check(is_equal_approx(float(Array(game.get("spawn_warnings"))[0].duration), 1.02), "germ entry aura lasts twenty percent longer")
	game.call("_update_spawn_warnings", 1.03)
	var germ_pool: Array = game.get("germs")
	_check(bool(germ_pool[GameMath.MAX_REGULAR_GERMS].active) and int(germ_pool[GameMath.MAX_REGULAR_GERMS].hp) == 18, "elite uses reserved germ slot")
	game.set("score", 0)
	game.set("combo", 1)
	game.set("last_kill_time", -999.0)
	game.call("_damage_germ", GameMath.MAX_REGULAR_GERMS, 18)
	var active_debris := 0
	for fragment in Array(game.get("debris")):
		if bool(fragment.active): active_debris += 1
	var active_item_warnings := 0
	for warning in Array(game.get("item_warnings")):
		if bool(warning.active): active_item_warnings += 1
	_check(int(game.get("score")) == 600 and active_debris == 4, "elite awards score and creates four debris")
	_check(active_item_warnings == 1, "elite death creates one item aura")
	game.call("_update_item_warnings", 0.86)
	var pickup_index := -1
	var pickup_type := -1
	for i in Array(game.get("pickups")).size():
		if bool(Array(game.get("pickups"))[i].active):
			pickup_index = i
			pickup_type = int(Array(game.get("pickups"))[i].item_type)
			break
	_check(pickup_index >= 0 and is_equal_approx(float(Array(game.get("pickups"))[pickup_index].life), 15.0), "item appears after aura with fifteen-second lifetime")
	game.set("player_pos", Vector2(Array(game.get("pickups"))[pickup_index].pos))
	game.call("_update_pickups", 0.01)
	_check(Array(game.get("item_levels"))[pickup_type] == 1 and not bool(Array(game.get("pickups"))[pickup_index].active), "touching pickup grants item level")
	var clamped: Vector2 = game.call("_clamp_pickup_position", Vector2(-99999.0, -99999.0))
	_check(clamped.distance_to(Vector2(game.get("arena_center"))) <= float(game.get("arena_radius")) - 29.99, "item drops clamp inside membrane")
	game.call("_spawn_germ", GermData.GermTier.ELITE, Vector2(game.get("player_pos")))
	game.set("spawn_protection_left", 0.0)
	game.call("_resolve_hostile_hits")
	_check(int(game.get("state")) == 5 and String(game.get("death_reason")) == "Germ contact", "elite contact is lethal")
	_free_game(game)


func _test_item_selection_and_overcharge() -> void:
	var game := _new_game()
	game.call("_start_run")
	var levels: Array = game.get("item_levels")
	for i in levels.size(): levels[i] = ItemData.MAX_LEVEL
	levels[ItemData.ItemType.SPREAD] = 2
	var forced_drop: Dictionary = game.call("_select_item_drop")
	_check(int(forced_drop.item_type) == ItemData.ItemType.SPREAD and not bool(forced_drop.overcharge), "drop rerolls maxed items")
	levels[ItemData.ItemType.SPREAD] = ItemData.MAX_LEVEL
	var overcharge_drop: Dictionary = game.call("_select_item_drop")
	_check(bool(overcharge_drop.overcharge) and int(overcharge_drop.item_type) >= 0 and int(overcharge_drop.item_type) < ItemData.ItemType.size(), "all-max drop becomes overcharge")
	game.call("_start_overcharge", ItemData.ItemType.AOE)
	_check(int(game.call("_effective_item_level", ItemData.ItemType.AOE)) == 4, "overcharge applies virtual level four")
	game.call("_start_overcharge", ItemData.ItemType.TURRET)
	_check(int(game.get("overcharge_item")) == ItemData.ItemType.TURRET and is_equal_approx(float(game.get("overcharge_left")), 15.0), "new overcharge replaces previous effect")
	game.call("_update_overcharge", 15.1)
	_check(int(game.get("overcharge_item")) == -1 and int(game.call("_effective_item_level", ItemData.ItemType.TURRET)) == 3, "overcharge expires to permanent level three")
	game.call("_activate_pickup", ItemData.ItemType.AOE, Vector2(game.get("arena_center")) + Vector2(100.0, 0.0), false)
	game.call("_update_pickups", 15.1)
	var any_pickup := false
	for pickup in Array(game.get("pickups")):
		if bool(pickup.active): any_pickup = true
	_check(not any_pickup, "uncollected item expires")
	game.call("_start_overcharge", ItemData.ItemType.AOE)
	game.set("elite_timer", 12.0)
	game.call("_set_pause", true)
	game.call("_process", 1.0)
	_check(is_equal_approx(float(game.get("overcharge_left")), 15.0) and is_equal_approx(float(game.get("elite_timer")), 12.0), "pause freezes item and elite timers")
	_free_game(game)


func _test_item_combat_effects() -> void:
	var game := _new_game()
	game.call("_start_run")
	_clear_combat(game)
	var levels: Array = game.get("item_levels")
	levels[ItemData.ItemType.SPREAD] = 3
	levels[ItemData.ItemType.RICOCHET] = 3
	game.call("_fire_pellet")
	var player_projectiles := 0
	var projectile_curve_ok := true
	for projectile in Array(game.get("pellets")):
		if bool(projectile.active):
			player_projectiles += 1
			projectile_curve_ok = projectile_curve_ok and int(projectile.bounces) == 3 and is_equal_approx(float(projectile.life), 2.3)
	_check(player_projectiles == 7 and projectile_curve_ok, "spread and ricochet modify player volley")
	_clear_projectiles(game)
	var center := Vector2(game.get("arena_center"))
	var radius := float(game.get("arena_radius"))
	game.call("_spawn_projectile", center + Vector2.RIGHT * (radius - 3.0), Vector2.RIGHT, 520.0, 2.0, 1, 0)
	game.call("_update_pellets", 0.02)
	var bounced: Dictionary = Array(game.get("pellets"))[0]
	_check(bool(bounced.active) and int(bounced.bounces) == 0 and Vector2(bounced.vel).dot(Vector2.RIGHT) < 0.0, "ricochet reflects from membrane")
	_clear_projectiles(game)
	_clear_hostiles(game)
	levels[ItemData.ItemType.TURRET] = 1
	game.call("_deploy_turret", center)
	game.call("_spawn_germ", GermData.GermTier.SMALL, center + Vector2(100.0, 0.0))
	game.call("_update_turrets", 0.01)
	var turret_shot := false
	for projectile in Array(game.get("pellets")):
		if bool(projectile.active) and int(projectile.owner) == 1: turret_shot = true
	_check(turret_shot, "turret auto-aims and fires at nearest hostile")
	for i in Array(game.get("turrets")).size(): Array(game.get("turrets"))[i].active = false
	_check(bool(game.call("_deploy_turret", center)) and bool(game.call("_deploy_turret", center)) and bool(game.call("_deploy_turret", center)) and not bool(game.call("_deploy_turret", center)), "turret pool caps at three")
	_clear_projectiles(game)
	_clear_hostiles(game)
	levels[ItemData.ItemType.SPINNING_HITTER] = 1
	game.set("hitter_angle", 0.0)
	game.call("_spawn_germ", GermData.GermTier.SMALL, center + Vector2.RIGHT * 58.0)
	game.call("_update_spinning_hitters", 0.0)
	_check(not bool(Array(game.get("germs"))[0].active), "spinning hitter damages intersecting germ")
	_clear_hostiles(game)
	levels[ItemData.ItemType.AOE] = 1
	game.set("score", 0)
	game.set("combo", 1)
	game.set("last_kill_time", -999.0)
	game.call("_spawn_germ", GermData.GermTier.SMALL, center + Vector2.RIGHT * 50.0)
	Array(game.get("debris"))[0] = {"active": true, "pos": center + Vector2.UP * 50.0, "vel": Vector2.ZERO, "life": 10.0, "angle": 0.0, "spin": 0.0, "hitter_cooldown": 0.0}
	game.set("aoe_timer", 0.0)
	game.call("_update_aoe", 0.0)
	_check(not bool(Array(game.get("germs"))[0].active) and not bool(Array(game.get("debris"))[0].active), "AOE damages germs and debris")
	_check(int(game.get("score")) == 45 and int(game.get("combo")) == 2, "item multi-kills award score and combo exactly once")
	_clear_hostiles(game)
	levels[ItemData.ItemType.LEAVE_BEHIND] = 1
	game.set("player_velocity", Vector2(100.0, 0.0))
	game.set("mine_timer", 0.0)
	game.call("_update_mines", 0.01)
	var mine_pos := Vector2(Array(game.get("mines"))[0].pos)
	game.call("_spawn_germ", GermData.GermTier.SMALL, mine_pos)
	Array(game.get("mines"))[0].arm = 0.0
	game.call("_update_mines", 0.0)
	_check(not bool(Array(game.get("mines"))[0].active) and not bool(Array(game.get("germs"))[0].active), "leave-behind mine arms, triggers, and deals area damage")
	_free_game(game)


func _test_additional_item_combat_effects() -> void:
	var game := _new_game()
	game.call("_start_run")
	_clear_combat(game)
	var levels: Array = game.get("item_levels")
	var center := Vector2(game.get("arena_center"))

	levels[ItemData.ItemType.CATALYST] = 3
	game.call("_fire_pellet")
	_check(is_equal_approx(float(game.get("fire_cooldown")), ItemData.catalyst_fire_interval(3)), "catalyst reduces the player firing interval")

	_clear_combat(game)
	levels[ItemData.ItemType.PIERCING_DOSE] = 1
	var stacked_target := center + Vector2.RIGHT * 80.0
	game.call("_spawn_germ", GermData.GermTier.ELITE, stacked_target)
	game.call("_spawn_projectile", stacked_target, Vector2.RIGHT, 0.0, 2.0, 0, 0)
	game.call("_resolve_projectile_hits")
	game.call("_resolve_projectile_hits")
	_check(int(Array(game.get("germs"))[GameMath.MAX_REGULAR_GERMS].hp) == 17, "piercing projectile cannot repeatedly damage the same target")
	_clear_combat(game)
	game.call("_spawn_germ", GermData.GermTier.SMALL, stacked_target)
	game.call("_spawn_germ", GermData.GermTier.SMALL, stacked_target)
	game.call("_spawn_projectile", stacked_target, Vector2.RIGHT, 0.0, 2.0, 0, 0)
	game.call("_resolve_projectile_hits")
	_check(not bool(Array(game.get("germs"))[0].active) and not bool(Array(game.get("germs"))[1].active), "piercing dose damages distinct overlapping targets once")
	_check(not bool(Array(game.get("pellets"))[0].active), "level-one piercing projectile expires after two targets")

	_clear_combat(game)
	levels[ItemData.ItemType.INHIBITOR_FIELD] = 1
	game.call("_spawn_germ", GermData.GermTier.SMALL, center + Vector2.RIGHT * 50.0)
	Array(game.get("germs"))[0].vel = Vector2.LEFT * 100.0
	var inhibitor_start := Vector2(Array(game.get("germs"))[0].pos)
	game.call("_update_germs", 0.1)
	var inhibitor_distance := inhibitor_start.distance_to(Vector2(Array(game.get("germs"))[0].pos))
	_check(is_equal_approx(inhibitor_distance, 8.0), "inhibitor field slows nearby germ movement")

	_clear_combat(game)
	levels[ItemData.ItemType.ANTIBODY_SHELL] = 1
	game.set("spawn_protection_left", 0.0)
	game.call("_spawn_germ", GermData.GermTier.SMALL, center)
	game.call("_resolve_hostile_hits")
	_check(int(game.get("state")) == 2 and is_equal_approx(float(game.get("antibody_cooldown")), 32.0), "ready antibody shell prevents one hostile collision")
	Array(game.get("germs"))[0].pos = center
	game.set("spawn_protection_left", 0.0)
	game.call("_resolve_hostile_hits")
	_check(int(game.get("state")) == 5, "recharging antibody shell does not prevent another collision")

	game.call("_start_run")
	_clear_combat(game)
	levels = game.get("item_levels")
	levels[ItemData.ItemType.CATALYTIC_CLEANUP] = 1
	game.call("_spawn_germ", GermData.GermTier.SMALL, center + Vector2.RIGHT * 30.0)
	Array(game.get("debris"))[0] = {"active": true, "pos": center, "vel": Vector2.ZERO, "life": 10.0, "angle": 0.0, "spin": 0.0, "hitter_cooldown": 0.0}
	game.call("_spawn_projectile", center, Vector2.RIGHT, 0.0, 2.0, 0, 0)
	game.call("_resolve_projectile_hits")
	_check(not bool(Array(game.get("germs"))[0].active) and int(game.get("score")) == 60, "catalytic cleanup turns shot debris into germ damage")

	game.call("_start_run")
	_clear_combat(game)
	levels = game.get("item_levels")
	levels[ItemData.ItemType.SEEKING_ENZYME] = 1
	game.call("_spawn_germ", GermData.GermTier.SMALL, center + Vector2(120.0, 60.0))
	game.call("_spawn_projectile", center, Vector2.RIGHT, 100.0, 2.0, 0, 0)
	var acquired_target := int(Array(game.get("pellets"))[0].seek_target)
	game.call("_update_pellets", 0.1)
	_check(acquired_target == 0 and Vector2(Array(game.get("pellets"))[0].vel).y > 0.0, "seeking enzyme acquires a germ and bends its projectile")
	_free_game(game)


func _test_long_run_pool_stability() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game := packed.instantiate()
	root.add_child(game)
	var initial_node_count := _count_nodes(game)
	var audio_manager := game.get_node("AudioManager")
	audio_manager.call("apply_levels", 0.0, 0.0)
	audio_manager.set("_unlocked", true)
	game.call("_start_run")
	var opening_warnings: Array = game.get("spawn_warnings")
	_check(opening_warnings.size() == 5, "opening germs receive spawn auras")
	game.set("spawn_protection_left", 9999.0)
	game.call("_update_run", 0.4)
	var early_germs: Array = game.get("germs")
	var early_active := 0
	for germ in early_germs:
		if bool(germ.active): early_active += 1
	_check(early_active == 0 and Array(game.get("spawn_warnings")).size() == 5, "spawn aura appears before germ activation")
	game.call("_update_run", 0.7)
	var entered_active := 0
	for germ in early_germs:
		if bool(germ.active): entered_active += 1
	_check(entered_active == 5 and Array(game.get("spawn_warnings")).is_empty(), "germs enter after the aura telegraph")
	for i in 6000:
		game.set("spawn_protection_left", 9999.0)
		game.call("_update_run", 0.1)
	var germ_pool: Array = game.get("germs")
	var debris_pool: Array = game.get("debris")
	var pellet_pool: Array = game.get("pellets")
	var active_germs := 0
	var active_debris := 0
	for germ in germ_pool:
		if bool(germ.active): active_germs += 1
	for fragment in debris_pool:
		if bool(fragment.active): active_debris += 1
	_check(germ_pool.size() == 36 and active_germs <= 36, "ten-minute run respects regular plus elite germ cap")
	_check(debris_pool.size() == 80 and active_debris <= 80, "ten-minute run respects fragment pool cap")
	_check(pellet_pool.size() == 240, "projectile pool remains fixed")
	_check(Array(game.get("turrets")).size() == 3 and Array(game.get("mines")).size() == 48 and Array(game.get("effect_flashes")).size() == 24, "item combat and effect pools remain fixed")
	_check(Array(game.get("pickups")).size() == 4 and Array(game.get("item_warnings")).size() == 4, "pickup and item warning pools remain fixed")
	_check(_count_nodes(game) == initial_node_count, "ten-minute simulation leaks no nodes")
	audio_manager.call("stop_all")
	game.free()


func _count_nodes(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _count_nodes(child)
	return count


func _new_game() -> Node:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game := packed.instantiate()
	root.add_child(game)
	var audio_manager := game.get_node("AudioManager")
	audio_manager.call("apply_levels", 0.0, 0.0)
	audio_manager.set("_unlocked", true)
	return game


func _free_game(game: Node) -> void:
	game.get_node("AudioManager").call("stop_all")
	game.free()


func _clear_projectiles(game: Node) -> void:
	for i in Array(game.get("pellets")).size(): Array(game.get("pellets"))[i].active = false


func _clear_hostiles(game: Node) -> void:
	for i in Array(game.get("germs")).size(): Array(game.get("germs"))[i].active = false
	for i in Array(game.get("debris")).size(): Array(game.get("debris"))[i].active = false


func _clear_combat(game: Node) -> void:
	_clear_projectiles(game)
	_clear_hostiles(game)
	for i in Array(game.get("turrets")).size(): Array(game.get("turrets"))[i].active = false
	for i in Array(game.get("mines")).size(): Array(game.get("mines"))[i].active = false
	for i in Array(game.get("pickups")).size(): Array(game.get("pickups"))[i].active = false
	for i in Array(game.get("item_warnings")).size(): Array(game.get("item_warnings"))[i].active = false
	Array(game.get("spawn_warnings")).clear()
