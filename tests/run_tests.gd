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
	_check(int(large.children) == 2 and int(large.fragments) == 3 and int(large.child_tier) == GermData.GermTier.MEDIUM, "large germ split recipe")
	_check(int(medium.children) == 2 and int(medium.fragments) == 2 and int(medium.child_tier) == GermData.GermTier.SMALL, "medium germ split recipe")
	_check(int(small.children) == 0 and int(small.fragments) == 1, "small germ split recipe")


func _test_spawn_ramp() -> void:
	_check(GameMath.active_germ_cap(0.0) == 5, "run starts with germ cap five")
	_check(GameMath.active_germ_cap(60.0) == 8, "germ cap grows every twenty seconds")
	_check(GameMath.active_germ_cap(9999.0) == 35, "germ cap never exceeds thirty-five")
	_check(is_equal_approx(GameMath.spawn_interval(0.0), 1.3), "spawn interval starts at 1.3 seconds")
	_check(is_equal_approx(GameMath.spawn_interval(180.0), 0.45), "spawn interval reaches 0.45 seconds")
	_check(is_equal_approx(GameMath.threat_speed_multiplier(300.0), 1.5), "threat speed caps at plus fifty percent")


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
	_check(large.hp == 3 and large.score == 100, "large germ data resource")
	_check(medium.hp == 2 and medium.score == 50, "medium germ data resource")
	_check(small.hp == 1 and small.score == 25, "small germ data resource")
	_check(load("res://assets/figma/petri-logo.png") != null, "Figma PETRI logo loads")
	_check(load("res://scenes/main.tscn") != null, "main scene loads")


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
	game.call("_update_run", 0.5)
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
	_check(germ_pool.size() == 35 and active_germs <= 35, "ten-minute run respects germ pool cap")
	_check(debris_pool.size() == 80 and active_debris <= 80, "ten-minute run respects fragment pool cap")
	_check(pellet_pool.size() == 120, "pellet pool remains fixed")
	_check(_count_nodes(game) == initial_node_count, "ten-minute simulation leaks no nodes")
	audio_manager.call("stop_all")
	game.free()


func _count_nodes(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _count_nodes(child)
	return count
