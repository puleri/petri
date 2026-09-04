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
	_test_player_health()
	_test_resources_and_scene()
	_test_germ_assets_and_hit_reactions()
	_test_culture_wars_dialogue()
	_test_timer_occlusion()
	_test_item_specs()
	_test_elite_and_pickup_flow()
	_test_item_selection_and_overcharge()
	_test_item_combat_effects()
	_test_additional_item_combat_effects()
	_test_boss_encounter_and_reward()
	_test_second_boss_encounter_and_reward()
	_test_third_boss_encounter_and_reward()
	_test_boon_system()
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
	_check(GameMath.awarded_score(100, 4, 1.5) == 600 and GameMath.awarded_score(100, 4, 2.0) == 800, "boon multiplier applies after combo scoring")


func _test_splitting() -> void:
	var large := GameMath.split_result(GermData.GermTier.LARGE)
	var medium := GameMath.split_result(GermData.GermTier.MEDIUM)
	var small := GameMath.split_result(GermData.GermTier.SMALL)
	var elite := GameMath.split_result(GermData.GermTier.ELITE)
	var boss := GameMath.split_result(GermData.GermTier.BOSS)
	var boss_2 := GameMath.split_result(GermData.GermTier.BOSS_2)
	var boss_3 := GameMath.split_result(GermData.GermTier.BOSS_3)
	_check(int(large.children) == 2 and int(large.fragments) == 3 and int(large.child_tier) == GermData.GermTier.MEDIUM, "large germ split recipe")
	_check(int(medium.children) == 2 and int(medium.fragments) == 2 and int(medium.child_tier) == GermData.GermTier.SMALL, "medium germ split recipe")
	_check(int(small.children) == 0 and int(small.fragments) == 1, "small germ split recipe")
	_check(int(elite.children) == 0 and int(elite.fragments) == 4, "elite destruction recipe")
	_check(int(boss.children) == 0 and int(boss.fragments) == 0, "boss destruction creates no lingering hazards")
	_check(int(boss_2.children) == 0 and int(boss_2.fragments) == 0, "second boss destruction creates no lingering hazards")
	_check(int(boss_3.children) == 0 and int(boss_3.fragments) == 0, "third boss destruction creates no lingering hazards")


func _test_spawn_ramp() -> void:
	_check(GameMath.active_germ_cap(0.0) == 5, "run starts with germ cap five")
	_check(GameMath.active_germ_cap(60.0) == 8, "germ cap grows every twenty seconds")
	_check(GameMath.active_germ_cap(9999.0) == 35, "germ cap never exceeds thirty-five")
	_check(is_equal_approx(GameMath.spawn_interval(0.0), 1.3), "spawn interval starts at 1.3 seconds")
	_check(is_equal_approx(GameMath.spawn_interval(180.0), 0.45), "spawn interval reaches 0.45 seconds")
	_check(is_equal_approx(GameMath.threat_speed_multiplier(300.0), 1.5), "threat speed caps at plus fifty percent")
	_check(is_equal_approx(GameMath.ELITE_FIRST_SPAWN, 5.0) and is_equal_approx(GameMath.ELITE_SPAWN_INTERVAL, 10.0), "elite cadence remains unchanged")
	_check(is_equal_approx(GameMath.BOSS_DASH_SPEED, 420.0), "boss dash speed remains unchanged")
	_check(GameMath.BOSS_SCORE_THRESHOLD == 50000 and GameMath.BOSS_2_SCORE_THRESHOLD == 100000 and GameMath.BOSS_3_SCORE_THRESHOLD == 150000 and GameMath.BOSS_STAGE_COUNT == 3 and GameMath.MAX_GERMS == 37, "three boss thresholds and shared reserved pool size")
	_check(is_equal_approx(GameMath.BASE_PLAYER_FIRE_RATE, 6.0) and is_equal_approx(GameMath.OVERCLOCKED_PLAYER_FIRE_RATE, 9.0), "base and overclocked fire rates")


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
	_check(not GameMath.hostile_collision_is_lethal(0.01), "spawn protection blocks hostile damage")
	_check(GameMath.hostile_collision_is_lethal(0.0), "hostile contact can damage after protection")


func _test_player_health() -> void:
	var game := _new_game()
	game.call("_start_run")
	_clear_combat(game)
	game.call("_reset_dialogue")
	var center := Vector2(game.get("arena_center"))
	game.set("player_pos", center)
	game.set("spawn_protection_left", 0.0)
	game.call("_spawn_germ", GermData.GermTier.SMALL, center)
	game.call("_resolve_hostile_hits")
	_check(int(game.get("player_health")) == 2 and int(game.get("player_max_health")) == 3 and int(game.get("state")) == 2, "first hostile hit removes one of three health")
	game.call("_resolve_hostile_hits")
	_check(int(game.get("player_health")) == 2 and is_equal_approx(float(game.get("damage_protection_left")), 1.0), "post-hit grace prevents an overlap from draining multiple health")
	game.set("damage_protection_left", 0.0)
	game.call("_resolve_hostile_hits")
	game.set("damage_protection_left", 0.0)
	game.call("_resolve_hostile_hits")
	_check(int(game.get("player_health")) == 0 and int(game.get("state")) == 5 and String(game.get("death_reason")) == "Germ contact", "third hostile hit ends the run")

	game.call("_start_run")
	_clear_combat(game)
	game.set("spawn_protection_left", 0.0)
	game.set("player_pos", center + Vector2.RIGHT * (float(game.get("arena_radius")) - 17.0))
	game.set("player_velocity", Vector2.RIGHT * 300.0)
	game.call("_resolve_player_membrane")
	_check(int(game.get("player_health")) == 2 and int(game.get("state")) == 2, "lethal-speed membrane impact removes one health instead of ending a healthy run")
	game.set("player_health", 1)
	game.set("damage_protection_left", 0.0)
	game.set("player_pos", center + Vector2.RIGHT * (float(game.get("arena_radius")) - 17.0))
	game.set("player_velocity", Vector2.RIGHT * 300.0)
	game.call("_resolve_player_membrane")
	_check(int(game.get("state")) == 5 and String(game.get("death_reason")) == "Membrane impact", "membrane damage still ends the run at zero health")

	game.call("_start_run")
	var boon_levels: Array = game.get("boon_levels")
	boon_levels[BoonData.BoonType.MAX_HEALTH] = 1
	game.set("player_health", 1)
	game.set("player_max_health", 5)
	game.set("active_boss_stage", 0)
	game.set("boss_encounter_phase", 3)
	game.call("_complete_boss_encounter")
	_check(int(game.get("player_health")) == 5 and int(game.get("player_max_health")) == 5 and int(boon_levels[BoonData.BoonType.MAX_HEALTH]) == 1 and int(game.get("boss_encounter_phase")) == 4, "boss victory restores boon-adjusted health without resetting boons")
	var health_bounds: Rect2 = game.call("_health_bounds")
	_check(health_bounds.size.x > 0.0 and health_bounds.size.y > 0.0, "health HUD reserves a responsive display area")
	game.call("_start_run")
	_check(int(game.get("player_health")) == 3 and int(game.get("player_max_health")) == 3 and is_zero_approx(float(game.get("damage_protection_left"))), "new run restores base health and clears damage grace")
	_free_game(game)


func _test_resources_and_scene() -> void:
	var large: GermData = load("res://data/germ_large.tres")
	var medium: GermData = load("res://data/germ_medium.tres")
	var small: GermData = load("res://data/germ_small.tres")
	var elite: GermData = load("res://data/germ_elite.tres")
	var boss: GermData = load("res://data/germ_boss.tres")
	var boss_2: GermData = load("res://data/germ_boss_2.tres")
	var boss_3: GermData = load("res://data/germ_boss_3.tres")
	_check(large.hp == 3 and large.score == 100, "large germ data resource")
	_check(medium.hp == 2 and medium.score == 50, "medium germ data resource")
	_check(small.hp == 1 and small.score == 25, "small germ data resource")
	_check(elite.hp == 18 and elite.radius == 66.0 and elite.score == 600 and elite.fragment_count == 4, "tank elite data resource")
	_check(is_equal_approx(large.speed_min, 38.4) and is_equal_approx(large.speed_max, 60.8), "large germ movement is twenty percent slower")
	_check(is_equal_approx(medium.speed_min, 52.8) and is_equal_approx(medium.speed_max, 78.4), "medium germ movement is twenty percent slower")
	_check(is_equal_approx(small.speed_min, 70.4) and is_equal_approx(small.speed_max, 105.6), "small germ movement is twenty percent slower")
	_check(is_equal_approx(elite.speed_min, 30.4) and is_equal_approx(elite.speed_max, 46.4), "elite germ movement is twenty percent slower")
	_check(boss.hp == 240 and boss.radius == 88.0 and boss.score == 5000 and boss.fragment_count == 0 and is_equal_approx(boss.speed_min, 32.0) and is_equal_approx(boss.speed_max, 44.0), "fifty-thousand-point boss data resource remains unchanged")
	_check(boss_2.hp == 600 and boss_2.radius == 100.0 and boss_2.score == 10000 and boss_2.fragment_count == 0 and is_equal_approx(boss_2.speed_min, 36.0) and is_equal_approx(boss_2.speed_max, 48.0), "hundred-thousand-point boss data resource remains unchanged")
	_check(boss_3.hp == 2200 and boss_3.radius == 120.0 and boss_3.score == 25000 and boss_3.fragment_count == 0 and is_equal_approx(boss_3.speed_min, 38.0) and is_equal_approx(boss_3.speed_max, 48.0), "hundred-fifty-thousand-point boss data resource")
	var game := _new_game()
	_clear_combat(game)
	var center := Vector2(game.get("arena_center"))
	var spawned_speeds_ok := true
	var spawn_specs: Array[GermData] = [large, medium, small, elite]
	for tier in [GermData.GermTier.LARGE, GermData.GermTier.MEDIUM, GermData.GermTier.SMALL, GermData.GermTier.ELITE]:
		game.call("_spawn_germ", tier, center + Vector2.RIGHT * 100.0)
		var index := GameMath.ELITE_GERM_INDEX if tier == GermData.GermTier.ELITE else _first_active_germ(game, tier)
		var spawned_speed := Vector2(Array(game.get("germs"))[index].vel).length()
		var spec: GermData = spawn_specs[tier]
		spawned_speeds_ok = spawned_speeds_ok and spawned_speed >= spec.speed_min and spawned_speed <= spec.speed_max and is_equal_approx(float(Array(game.get("germs"))[index].move_speed), spawned_speed)
	_check(spawned_speeds_ok, "fresh regular and elite spawns use the reduced resource ranges")
	_check(load("res://assets/figma/petri-logo.png") != null, "Figma PETRI logo loads")
	var player_texture := load("res://assets/Specimen/P1/P1.png") as Texture2D
	_check(player_texture != null and player_texture.get_size() == Vector2(226.0, 157.0), "soft-edged P1 player texture loads at its source size")
	_check(load("res://scenes/main.tscn") != null, "main scene loads")
	var script_constants: Dictionary = game.get_script().get_script_constant_map()
	_check(Color(script_constants.get("GAME_BG")).is_equal_approx(Color("B2DBD5")) and Color(script_constants.get("PLAYSPACE_RING")).is_equal_approx(Color("D1EDE7")), "playspace backdrop uses the mockup mint palette")
	_check(is_equal_approx(float(script_constants.get("PLAYSPACE_RING_RADIUS_MULTIPLIER")), 1.44) and is_equal_approx(float(script_constants.get("DISH_INNER_SHADOW_WIDTH_MULTIPLIER")), 0.2), "playspace backdrop keeps the mockup ring and inset-shadow proportions")
	var draw_order: Array = script_constants.get("GERM_VISUAL_DRAW_ORDER", [])
	var smallest_on_top := draw_order == [GermData.GermTier.BOSS_3, GermData.GermTier.BOSS_2, GermData.GermTier.BOSS, GermData.GermTier.ELITE, GermData.GermTier.LARGE, GermData.GermTier.MEDIUM, GermData.GermTier.SMALL]
	for i in range(1, draw_order.size()):
		smallest_on_top = smallest_on_top and game.get("germ_specs")[int(draw_order[i - 1])].radius >= game.get("germ_specs")[int(draw_order[i])].radius
	_check(smallest_on_top, "germs render from largest to smallest before debris")
	_free_game(game)


func _test_germ_assets_and_hit_reactions() -> void:
	var game := _new_game()
	var initial_node_count := _count_nodes(game)
	var visual_cache: Array = game.get("germ_visual_textures")
	var flash_masks: Array = game.get("germ_flash_masks")
	var cache_complete := visual_cache.size() == GermData.GermTier.size() and flash_masks.size() == 4
	var mipmaps_complete := cache_complete
	if cache_complete:
		for tier_layers in visual_cache:
			cache_complete = cache_complete and Array(tier_layers).size() == 4
			for texture in Array(tier_layers):
				var cached_texture := texture as Texture2D
				mipmaps_complete = mipmaps_complete and cached_texture != null and cached_texture.get_image().has_mipmaps()
	_check(cache_complete, "all seven germ tiers cache four layered Meeboid textures")
	_check(mipmaps_complete, "generated germ textures include mipmaps for small tiers")
	_check(Color(game.call("_germ_palette_color", GermData.GermTier.LARGE)).is_equal_approx(Color("55DDE0")) and Color(game.call("_germ_palette_color", GermData.GermTier.SMALL)).is_equal_approx(Color("55DDE0")), "large and small germs use the cyan body palette")
	_check(Color(game.call("_germ_palette_color", GermData.GermTier.MEDIUM)).is_equal_approx(Color("EFCEFD")) and Color(game.call("_germ_palette_color", GermData.GermTier.ELITE)).is_equal_approx(Color("FF9E73")), "medium and elite germs use lavender and orange palettes")
	_check(Color(game.call("_germ_palette_color", GermData.GermTier.BOSS_3)).is_equal_approx(Color("1B0D26")), "third boss uses the midnight-purple body palette")

	var center := Vector2(game.get("arena_center"))
	game.call("_spawn_germ", GermData.GermTier.ELITE, center)
	var elite_index := _first_active_germ(game, GermData.GermTier.ELITE)
	var germs: Array = game.get("germs")
	game.call("_damage_germ", elite_index, 1)
	_check(is_equal_approx(float(germs[elite_index].hit_reaction_left), 0.3), "surviving germ hits start the pooled reaction")
	germs[elite_index].hit_reaction_left = 0.2
	var outer_peak := float(game.call("_germ_hit_layer_scale", germs[elite_index], 0))
	var inner_rising := float(game.call("_germ_hit_layer_scale", germs[elite_index], 3))
	_check(is_equal_approx(outer_peak, 1.1) and inner_rising > 1.0 and inner_rising < outer_peak, "hit reaction ripples through the supplied layer timing")
	germs[elite_index].hit_reaction_left = 0.25
	_check(is_equal_approx(float(game.call("_germ_hit_flash_amount", germs[elite_index])), 1.0), "hit flash reaches full coral at fifty milliseconds")
	germs[elite_index].hit_reaction_left = 0.05
	game.call("_damage_germ", elite_index, 1)
	_check(is_equal_approx(float(germs[elite_index].hit_reaction_left), 0.3), "repeated hits restart instead of queueing the reaction")
	game.call("_update_germs", 0.31)
	_check(is_zero_approx(float(germs[elite_index].hit_reaction_left)), "hit reaction returns exactly to idle after three tenths")
	game.call("_damage_germ", elite_index, 999)
	_check(not bool(germs[elite_index].active) and is_zero_approx(float(germs[elite_index].hit_reaction_left)), "lethal hits remain immediate and clear reaction state")

	game.call("_spawn_germ", GermData.GermTier.SMALL, center)
	var small_index := _first_active_germ(game, GermData.GermTier.SMALL)
	_check(is_zero_approx(float(germs[small_index].hit_reaction_left)), "reused germ slots start without stale hit motion")
	game.call("_damage_germ", small_index, 1)
	_check(not bool(germs[small_index].active), "one-hit germs do not delay destruction for the visual reaction")

	game.call("_spawn_germ", GermData.GermTier.ELITE, center)
	elite_index = _first_active_germ(game, GermData.GermTier.ELITE)
	game.call("_damage_germ", elite_index, 1)
	game.call("_set_reduced_motion", true)
	_check(is_zero_approx(float(germs[elite_index].hit_reaction_left)) and is_equal_approx(float(game.call("_germ_hit_layer_scale", germs[elite_index], 0)), 1.0) and is_zero_approx(float(game.call("_germ_hit_flash_amount", germs[elite_index]))), "Reduced Motion clears active germ reactions")
	game.call("_damage_germ", elite_index, 1)
	_check(is_zero_approx(float(germs[elite_index].hit_reaction_left)), "damage under Reduced Motion starts no reaction")
	game.call("_set_reduced_motion", false)
	game.call("_damage_germ", elite_index, 1)
	_check(is_equal_approx(float(germs[elite_index].hit_reaction_left), 0.3), "future hits animate after Reduced Motion is disabled")
	_check(_count_nodes(game) == initial_node_count and germs.size() == 37, "layered hit reactions add no nodes or germ pool slots")
	_free_game(game)


func _test_culture_wars_dialogue() -> void:
	_check(CultureWarDialogue.topic_count() == 8, "Culture Wars covers eight recognizable discourse topics")
	var content_complete := true
	for topic_id in CultureWarDialogue.topic_count():
		for variant in 2:
			content_complete = content_complete and not CultureWarDialogue.regular_line(topic_id, -1, CultureWarDialogue.INTENSITY_OPENER, variant).is_empty()
			for stance in 2:
				content_complete = content_complete and not CultureWarDialogue.regular_line(topic_id, stance, CultureWarDialogue.INTENSITY_MEDIUM, variant).is_empty()
				content_complete = content_complete and not CultureWarDialogue.regular_line(topic_id, stance, CultureWarDialogue.INTENSITY_SMALL, variant).is_empty()
	_check(content_complete, "every topic has opener and opposing medium/small lines")
	var lines_fit := true
	for line in CultureWarDialogue.all_lines():
		lines_fit = lines_fit and line.length() <= 54
	_check(lines_fit, "dialogue copy stays within the compact two-line budget")
	_check(CultureWarDialogue.ELITE_LINES.size() >= 4 and CultureWarDialogue.PLAYER_LINES.size() >= 5, "elite and protagonist voice pools have variety")

	var game := _new_game()
	game.call("_start_run")
	_clear_combat(game)
	game.call("_reset_dialogue")
	_check(is_equal_approx(float(game.call("_dialogue_duration_for_text", "ONE TWO THREE FOUR")), 2.2) and is_equal_approx(float(game.call("_dialogue_duration_for_text", "ONE TWO")), 2.2), "one through four words receive the 2.2-second base duration")
	_check(is_equal_approx(float(game.call("_dialogue_duration_for_text", "ONE TWO THREE FOUR FIVE")), 2.45), "a fifth word adds a quarter second")
	_check(is_equal_approx(float(game.call("_dialogue_duration_for_text", "ONE TWO THREE FOUR FIVE SIX SEVEN EIGHT")), 3.2), "each word beyond four adds another quarter second")
	var center := Vector2(game.get("arena_center"))
	game.call("_spawn_germ", GermData.GermTier.LARGE, center + Vector2(120.0, 0.0))
	var parent_index := _first_active_germ(game, GermData.GermTier.LARGE)
	var parent_topic := int(Array(game.get("germs"))[parent_index].topic_id)
	game.call("_damage_germ", parent_index, 3)
	var medium_indices := _active_germ_indices(game, GermData.GermTier.MEDIUM)
	var medium_stances := {}
	var opposing_children_ok := medium_indices.size() == 2
	var medium_child_speed_ok := true
	var medium_spec: GermData = load("res://data/germ_medium.tres")
	for index in medium_indices:
		var germ: Dictionary = Array(game.get("germs"))[index]
		opposing_children_ok = opposing_children_ok and int(germ.topic_id) == parent_topic
		var child_speed := Vector2(germ.vel).length()
		medium_child_speed_ok = medium_child_speed_ok and child_speed >= medium_spec.speed_min * 0.75 and child_speed <= medium_spec.speed_max * 0.75
		medium_stances[int(germ.stance)] = true
	opposing_children_ok = opposing_children_ok and medium_stances.has(0) and medium_stances.has(1)
	_check(opposing_children_ok, "large germ splits into opposing stances on the same topic")
	_check(medium_child_speed_ok, "large-germ descendants spawn at seventy-five percent velocity")
	game.set("next_player_dialogue_time", INF)
	game.call("_update_dialogue", 24.1)
	var first_child_speaker := int(game.get("dialogue_germ_index"))
	var first_child_stance := int(Array(game.get("germs"))[first_child_speaker].stance)
	game.call("_update_dialogue", 24.1)
	var second_child_speaker := int(game.get("dialogue_germ_index"))
	var second_child_stance := int(Array(game.get("germs"))[second_child_speaker].stance)
	_check(first_child_speaker in medium_indices and second_child_speaker in medium_indices and first_child_speaker != second_child_speaker and first_child_stance != second_child_stance, "opposing split descendants surface sequentially after the global cooldown")
	game.call("_reset_dialogue")
	var inherited_stance := int(Array(game.get("germs"))[medium_indices[0]].stance)
	game.call("_damage_germ", medium_indices[0], 2)
	var small_indices := _active_germ_indices(game, GermData.GermTier.SMALL)
	var inherited_children_ok := small_indices.size() == 2
	var small_child_speed_ok := true
	var small_spec: GermData = load("res://data/germ_small.tres")
	for index in small_indices:
		var germ: Dictionary = Array(game.get("germs"))[index]
		inherited_children_ok = inherited_children_ok and int(germ.topic_id) == parent_topic and int(germ.stance) == inherited_stance
		var child_speed := Vector2(germ.vel).length()
		small_child_speed_ok = small_child_speed_ok and child_speed >= small_spec.speed_min * 0.75 and child_speed <= small_spec.speed_max * 0.75
	_check(inherited_children_ok, "small descendants inherit and intensify their parent's stance")
	_check(small_child_speed_ok, "medium-germ descendants spawn at seventy-five percent velocity")

	_clear_combat(game)
	game.call("_reset_dialogue")
	game.call("_spawn_germ", GermData.GermTier.SMALL, center + Vector2(80.0, 0.0), 0, 0)
	_check(is_equal_approx(float(game.get("dialogue_cooldown")), 24.0), "global dialogue interval targets two and a half cut scenes per minute")
	var first_speaker := int(game.get("dialogue_germ_index"))
	var first_text := String(game.get("dialogue_text"))
	game.call("_spawn_germ", GermData.GermTier.SMALL, center + Vector2(-80.0, 0.0), 1, 1)
	_check(int(game.get("dialogue_speaker")) == 1 and int(game.get("dialogue_germ_index")) == first_speaker and String(game.get("dialogue_text")) == first_text, "global dialogue channel prevents overlapping germ bubbles")
	game.set("next_player_dialogue_time", float(game.get("run_time")))
	game.call("_update_dialogue", 0.01)
	_check(int(game.get("dialogue_speaker")) == 1 and int(game.get("dialogue_germ_index")) == first_speaker, "global rate gate lets the current cut scene finish")
	game.call("_update_dialogue", 24.0)
	var player_line_duration := float(game.call("_dialogue_duration_for_text", String(game.get("dialogue_text"))))
	_check(int(game.get("dialogue_speaker")) == 2 and is_equal_approx(float(game.get("dialogue_life")), player_line_duration), "due protagonist dialogue receives the next available cut-scene slot")
	_check(int(game.get("dialogue_cutscene_phase")) == 1 and int(game.get("dialogue_visible_characters")) == 0, "dialogue opens with a cinematic zoom and an empty typewriter bubble")
	var frozen_run_time := float(game.get("run_time"))
	var frozen_player_pos := Vector2(game.get("player_pos"))
	game.call("_update_run", 0.18)
	_check(is_equal_approx(float(game.get("run_time")), frozen_run_time) and Vector2(game.get("player_pos")).is_equal_approx(frozen_player_pos), "dialogue cut scene freezes gameplay simulation")
	_check(float(game.call("_dialogue_camera_zoom")) > 1.0 and float(game.call("_dialogue_camera_zoom")) < 1.58, "dialogue camera eases toward the speaker")
	game.call("_update_run", 0.24)
	_check(int(game.get("dialogue_cutscene_phase")) == 2 and int(game.get("dialogue_visible_characters")) > 0 and int(game.get("dialogue_visible_characters")) < String(game.get("dialogue_text")).length(), "dialogue text types into the bubble during the speaking beat")
	_check(float(game.call("_dialogue_speaker_scale")) < 1.0, "dialogue speaker pulses slightly inward")
	var paused_life := float(game.get("dialogue_life"))
	var paused_phase_time := float(game.get("dialogue_phase_time"))
	game.call("_set_pause", true)
	game.call("_process", 1.0)
	_check(is_equal_approx(float(game.get("dialogue_life")), paused_life) and is_equal_approx(float(game.get("dialogue_phase_time")), paused_phase_time), "pause freezes dialogue timing")
	game.call("_set_pause", false)
	game.call("_update_run", float(game.get("dialogue_life")) + 0.01)
	_check(int(game.get("dialogue_speaker")) == 0 and int(game.get("dialogue_cutscene_phase")) == 0 and String(game.get("dialogue_text")).is_empty(), "cut scene zooms out and removes the completed bubble")
	var game_saved: Dictionary = game.get("saved")
	game_saved.reduced_motion = true
	game.call("_show_dialogue", 2, -1, "Every outrage has a sponsor.")
	_check(is_equal_approx(float(game.call("_dialogue_camera_zoom")), 1.0) and is_equal_approx(float(game.call("_dialogue_speaker_scale")), 1.0) and int(game.get("dialogue_visible_characters")) == String(game.get("dialogue_text")).length(), "reduced motion disables zoom, pulse, and typewriter motion")
	game_saved.reduced_motion = false
	game.call("_reset_dialogue")
	_clear_combat(game)
	game.call("_spawn_germ", GermData.GermTier.SMALL, center + Vector2(70.0, 0.0), 0, 0)
	var doomed_speaker := int(game.get("dialogue_germ_index"))
	game.call("_damage_germ", doomed_speaker, 1)
	_check(int(game.get("dialogue_speaker")) == 0 and String(game.get("dialogue_text")).is_empty(), "destroying a speaking germ clears its bubble")
	game.call("_spawn_germ", GermData.GermTier.SMALL, center + Vector2(-70.0, 0.0), 0, 1)
	_check(int(game.get("dialogue_speaker")) == 0, "germ dialogue observes the post-bubble cooldown")

	var layouts_fit := true
	for size in [Vector2(1280.0, 720.0), Vector2(1920.0, 1080.0), Vector2(2560.0, 1080.0), Vector2(900.0, 720.0)]:
		game.set("viewport_size", size)
		game.set("css_viewport_width", size.x)
		game.set("arena_center", Vector2(size.x * 0.5, size.y * 0.46))
		game.set("arena_radius", minf(size.y * 0.35, size.x * 0.34) * 1.3225)
		var layout: Dictionary = game.call("_dialogue_layout", Vector2(game.get("arena_center")) + Vector2(-float(game.get("arena_radius")) + 24.0, -float(game.get("arena_radius")) + 24.0), "Culture war has one winner: the ruling class.", 18.0)
		var rect: Rect2 = layout.rect
		layouts_fit = layouts_fit and rect.position.x >= 11.99 and rect.position.y >= (76.0 if size.x < 1024.0 else 0.0) and rect.end.x <= size.x - 11.99 and rect.end.y <= size.y - 15.99 and Array(layout.lines).size() <= 2 and is_zero_approx(float(game.call("_dialogue_hud_overlap", rect)))
		for rendered_line in Array(layout.lines):
			layouts_fit = layouts_fit and not str(rendered_line).contains("…")
	_check(layouts_fit, "speech bubble layout avoids the HUD across desktop and compact viewports")
	_free_game(game)


func _test_timer_occlusion() -> void:
	var game := _new_game()
	game.call("_start_run")
	_clear_combat(game)
	game.call("_update_layout")
	var visual_unit := float(game.call("_hud_unit"))
	var previous_label_size := roundi(clampf(visual_unit * 0.063, 20.0, 76.0))
	var previous_score_size := roundi(clampf(visual_unit * 0.125, 42.0, 178.0))
	var previous_time_size := roundi(clampf(visual_unit * 0.14, 40.0, 132.0))
	_check(int(game.call("_hud_label_size", visual_unit)) <= previous_label_size * 0.8 and int(game.call("_hud_score_size", visual_unit)) <= previous_score_size * 0.8 and int(game.call("_hud_time_size", visual_unit)) <= previous_time_size * 0.8, "gameplay HUD typography uses the reduced scale")
	var timer_bounds: Rect2 = game.call("_timer_bounds")
	game.set("player_pos", Vector2(game.get("arena_center")))
	_check(is_equal_approx(float(game.call("_timer_opacity")), 1.0), "timer remains opaque when actors do not overlap it")
	game.set("player_pos", timer_bounds.get_center())
	_check(is_equal_approx(float(game.call("_timer_opacity")), 0.15), "timer fades to fifteen percent over the player")
	game.set("timer_hud_opacity", 1.0)
	game.call("_update_overlay_opacities", 0.1)
	_check(float(game.get("timer_hud_opacity")) > 0.15 and float(game.get("timer_hud_opacity")) < 1.0, "HUD obstruction opacity transitions instead of snapping")
	game.call("_update_overlay_opacities", 0.2)
	_check(is_equal_approx(float(game.get("timer_hud_opacity")), 0.15), "HUD obstruction transition reaches its reduced opacity")
	game.set("player_pos", Vector2(game.get("arena_center")))
	game.call("_spawn_germ", GermData.GermTier.SMALL, timer_bounds.get_center(), 0, 0)
	game.call("_clear_dialogue_bubble")
	_check(is_equal_approx(float(game.call("_timer_opacity")), 0.15), "timer fades to fifteen percent over a germ")
	_clear_combat(game)
	game.set("player_pos", Rect2(game.call("_score_bounds")).get_center())
	game.set("score_hud_opacity", 1.0)
	game.call("_update_overlay_opacities", 0.3)
	_check(is_equal_approx(float(game.get("score_hud_opacity")), 0.15), "score HUD shares the actor-obstruction fade")
	game.set("player_pos", Vector2(game.get("arena_center")))
	Array(game.get("popups")).clear()
	Array(game.get("popups")).append({"pos": Vector2(game.get("player_pos")), "text": "+100   2x", "life": 5.0, "duration": 5.0, "item_type": -1, "occlusion_opacity": 1.0})
	game.call("_update_popups", 0.3)
	_check(is_equal_approx(float(Array(game.get("popups"))[0].occlusion_opacity), 0.28), "floating score multipliers fade over actors")
	Array(game.get("popups")).clear()
	game.call("_show_dialogue", 2, -1, "Every outrage has a sponsor.")
	var bubble_layout: Dictionary = game.call("_dialogue_layout", Vector2(game.get("player_pos")), "Every outrage has a sponsor.", 18.0)
	game.call("_spawn_germ", GermData.GermTier.SMALL, Rect2(bubble_layout.rect).get_center(), 0, 0)
	game.call("_show_dialogue", 2, -1, "Every outrage has a sponsor.")
	game.set("dialogue_occlusion_opacity", 1.0)
	game.call("_update_overlay_opacities", 0.3)
	_check(is_equal_approx(float(game.get("dialogue_occlusion_opacity")), 0.28), "speech bubbles fade when another actor is behind them")
	_free_game(game)


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
	_check(elite_warnings == 1 and is_equal_approx(float(game.get("elite_timer")), GameMath.ELITE_SPAWN_INTERVAL), "elite queues at scheduled cadence")
	_check(is_equal_approx(float(Array(game.get("spawn_warnings"))[0].duration), 2.5), "germ entry aura uses the configured duration")
	game.call("_update_spawn_warnings", 2.501)
	var germ_pool: Array = game.get("germs")
	_check(bool(germ_pool[GameMath.ELITE_GERM_INDEX].active) and int(germ_pool[GameMath.ELITE_GERM_INDEX].hp) == 18, "elite uses reserved germ slot")
	game.set("score", 0)
	game.set("combo", 1)
	game.set("last_kill_time", -999.0)
	game.call("_damage_germ", GameMath.ELITE_GERM_INDEX, 18)
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
	game.set("player_health", 1)
	game.call("_resolve_hostile_hits")
	_check(int(game.get("state")) == 5 and String(game.get("death_reason")) == "Germ contact", "elite contact removes the final health")
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
	_check(int(Array(game.get("germs"))[GameMath.ELITE_GERM_INDEX].hp) == 17, "piercing projectile cannot repeatedly damage the same target")
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
	_check(int(game.get("state")) == 2 and int(game.get("player_health")) == 2, "recharging antibody shell does not prevent another collision")

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


func _test_boss_encounter_and_reward() -> void:
	var game := _new_game()
	game.call("_start_run")
	_clear_combat(game)
	game.call("_reset_dialogue")
	game.set("spawn_protection_left", 9999.0)
	var center := Vector2(game.get("arena_center"))
	game.call("_queue_spawn_warning", GermData.GermTier.SMALL)
	game.call("_queue_spawn_warning", GermData.GermTier.ELITE)
	game.call("_spawn_germ", GermData.GermTier.SMALL, center + Vector2(120.0, 0.0))
	Array(game.get("debris"))[0] = {"active": true, "pos": center + Vector2.UP * 60.0, "vel": Vector2.ZERO, "life": 10.0, "angle": 0.0, "spin": 0.0, "hitter_cooldown": 0.0}
	game.set("score", GameMath.BOSS_SCORE_THRESHOLD - 25)
	game.set("combo", 1)
	game.set("last_kill_time", -999.0)
	game.call("_award_kill", 25, center)
	_check(int(game.get("boss_encounter_phase")) == 1 and Array(game.get("spawn_warnings")).is_empty(), "score threshold enters cleanup and cancels queued spawns")
	game.set("spawn_timer", 0.0)
	game.set("elite_timer", 0.0)
	game.call("_reset_dialogue")
	game.call("_update_run", 0.01)
	_check(Array(game.get("spawn_warnings")).is_empty() and is_zero_approx(float(game.get("spawn_timer"))) and is_zero_approx(float(game.get("elite_timer"))), "cleanup blocks regular and elite scheduling while hostiles remain")
	Array(game.get("germs"))[0].active = false
	game.call("_update_boss_encounter")
	_check(Array(game.get("spawn_warnings")).is_empty(), "debris alone continues to block boss entry")
	Array(game.get("debris"))[0].active = false
	game.call("_update_boss_encounter")
	var boss_warning_ok := Array(game.get("spawn_warnings")).size() == 1 and int(Array(game.get("spawn_warnings"))[0].tier) == GermData.GermTier.BOSS
	_check(boss_warning_ok and int(game.get("boss_encounter_phase")) == 2, "cleared dish queues the one-time boss telegraph")
	game.call("_update_spawn_warnings", 2.501)
	var boss_pool: Array = game.get("germs")
	var boss: Dictionary = boss_pool[GameMath.BOSS_GERM_INDEX]
	_check(bool(boss.active) and int(boss.tier) == GermData.GermTier.BOSS and int(boss.hp) == 240 and int(game.get("boss_encounter_phase")) == 3, "boss uses its dedicated reserved slot")
	game.call("_reset_dialogue")

	boss_pool[GameMath.BOSS_GERM_INDEX].dash_timer = 0.0
	game.call("_update_germs", 0.0)
	boss = boss_pool[GameMath.BOSS_GERM_INDEX]
	var locked_direction := Vector2(boss.dash_direction)
	_check(int(boss.dash_phase) == 1 and is_equal_approx(float(boss.dash_timer), GameMath.BOSS_DASH_WARNING_SECONDS), "boss begins with a timed direction-lock warning")
	game.set("player_pos", center + Vector2.UP * 100.0)
	var saved_data: Dictionary = game.get("saved")
	saved_data.reduced_motion = true
	game.call("_update_germs", GameMath.BOSS_DASH_WARNING_SECONDS + 0.01)
	boss = boss_pool[GameMath.BOSS_GERM_INDEX]
	_check(int(boss.dash_phase) == 2 and Vector2(boss.dash_direction).is_equal_approx(locked_direction), "boss dash keeps its locked direction under reduced motion")
	var before_dash := Vector2(boss.pos)
	game.call("_update_germs", 0.1)
	boss = boss_pool[GameMath.BOSS_GERM_INDEX]
	_check(Vector2(boss.pos).distance_to(before_dash) > 40.0, "boss dash uses the configured high-speed movement")
	var outward := Vector2.RIGHT
	boss_pool[GameMath.BOSS_GERM_INDEX].pos = center + outward * (float(game.get("arena_radius")) - 89.0)
	boss_pool[GameMath.BOSS_GERM_INDEX].dash_phase = 2
	boss_pool[GameMath.BOSS_GERM_INDEX].dash_timer = GameMath.BOSS_DASH_SECONDS
	boss_pool[GameMath.BOSS_GERM_INDEX].dash_direction = outward
	game.call("_update_germs", 0.1)
	boss = boss_pool[GameMath.BOSS_GERM_INDEX]
	_check(int(boss.dash_phase) == 0 and is_equal_approx(float(boss.dash_timer), GameMath.BOSS_DASH_COOLDOWN), "boss dash ends when it reaches the membrane")

	var levels: Array = game.get("item_levels")
	for i in levels.size(): levels[i] = ItemData.MAX_LEVEL
	game.call("_start_overcharge", ItemData.ItemType.AOE)
	game.call("_deploy_turret", center)
	Array(game.get("mines"))[0] = {"active": true, "pos": center, "life": 5.0, "arm": 0.0, "phase": 0.0, "blast_radius": 55.0}
	game.call("_activate_pickup", ItemData.ItemType.SPREAD, center + Vector2(80.0, 0.0), false)
	game.call("_queue_item_warning", center + Vector2.LEFT * 80.0)
	_clear_projectiles(game)
	game.call("_spawn_projectile", center, Vector2.RIGHT, 520.0, 1.0, 0, 0)
	game.call("_spawn_projectile", center, Vector2.RIGHT, 480.0, 1.0, 0, 1)
	game.set("player_pos", center)
	boss_pool[GameMath.BOSS_GERM_INDEX].pos = center + Vector2.RIGHT * 80.0
	boss_pool[GameMath.BOSS_GERM_INDEX].hp = 1
	game.set("aoe_timer", 0.0)
	game.call("_update_aoe", 0.0)
	var levels_cleared := true
	for level in levels: levels_cleared = levels_cleared and int(level) == 0
	var ability_fields_cleared := true
	for turret in Array(game.get("turrets")): ability_fields_cleared = ability_fields_cleared and not bool(turret.active)
	for mine in Array(game.get("mines")): ability_fields_cleared = ability_fields_cleared and not bool(mine.active)
	for pickup in Array(game.get("pickups")): ability_fields_cleared = ability_fields_cleared and not bool(pickup.active)
	for warning in Array(game.get("item_warnings")): ability_fields_cleared = ability_fields_cleared and not bool(warning.active)
	var old_player_shot_preserved := false
	var turret_shot_removed := true
	for projectile in Array(game.get("pellets")):
		if bool(projectile.active) and int(projectile.owner) == 0:
			old_player_shot_preserved = int(projectile.damage) == 1
		if bool(projectile.active) and int(projectile.owner) == 1:
			turret_shot_removed = false
	_check(levels_cleared and int(game.get("overcharge_item")) == -1 and ability_fields_cleared and is_inf(float(game.get("aoe_timer"))), "boss reward performs the full clean ability reset")
	_check(old_player_shot_preserved and turret_shot_removed, "reset removes turret shots without upgrading pellets already in flight")
	var choices: Array = game.get("boon_choices")
	var offered_types: Array[int] = []
	for choice in choices:
		if bool(choice.active): offered_types.append(int(choice.boon_type))
	_check(int(game.get("base_weapon_damage")) == 2 and is_equal_approx(float(game.get("base_weapon_fire_rate")), 6.0) and int(game.get("bosses_defeated")) == 1 and int(game.get("boss_encounter_phase")) == 4 and not bool(game.call("_normal_spawning_enabled")) and offered_types.size() == 3 and offered_types[0] != offered_types[1] and offered_types[0] != offered_types[2] and offered_types[1] != offered_types[2], "first boss grants two-damage shots and opens three distinct boon choices")
	var frozen_run_time := float(game.get("run_time"))
	var preserved_shot_life := -1.0
	for projectile in Array(game.get("pellets")):
		if bool(projectile.active) and int(projectile.owner) == 0:
			preserved_shot_life = float(projectile.life)
			break
	game.set("player_pos", Vector2(choices[0].pos))
	game.call("_update_run", 1.99)
	var still_locked := int(game.get("boss_encounter_phase")) == 4
	game.call("_update_run", 0.01)
	var shot_still_frozen := true
	for projectile in Array(game.get("pellets")):
		if bool(projectile.active) and int(projectile.owner) == 0 and preserved_shot_life >= 0.0:
			shot_still_frozen = is_equal_approx(float(projectile.life), preserved_shot_life)
			break
	_check(still_locked and is_equal_approx(float(game.get("run_time")), frozen_run_time) and shot_still_frozen, "boon lockout freezes run time and hazards for exactly two seconds")
	_check(int(game.get("boss_encounter_phase")) == 0 and bool(game.call("_normal_spawning_enabled")) and is_equal_approx(float(game.get("spawn_timer")), GameMath.spawn_interval(float(game.get("run_time")))) and is_equal_approx(float(game.get("elite_timer")), GameMath.ELITE_SPAWN_INTERVAL), "touching an unlocked boon resumes survival with a fresh elite timer")

	_clear_projectiles(game)
	levels[ItemData.ItemType.SPREAD] = 2
	levels[ItemData.ItemType.RICOCHET] = 2
	game.call("_fire_pellet")
	var upgraded_shots := 0
	var upgraded_curve_ok := true
	for projectile in Array(game.get("pellets")):
		if bool(projectile.active) and int(projectile.owner) == 0:
			upgraded_shots += 1
			upgraded_curve_ok = upgraded_curve_ok and int(projectile.damage) == 2 and int(projectile.bounces) == 2
	_check(upgraded_shots == 5 and upgraded_curve_ok, "spread and ricochet scale the double-damage base weapon")
	game.call("_spawn_projectile", center, Vector2.RIGHT, 480.0, 1.0, 0, 1)
	var turret_damage_ok := false
	for projectile in Array(game.get("pellets")):
		if bool(projectile.active) and int(projectile.owner) == 1:
			turret_damage_ok = int(projectile.damage) == 1
	_check(turret_damage_ok, "turret projectiles remain at one damage")
	game.call("_award_kill", 100, center)
	var second_boss_warning := false
	for warning in Array(game.get("spawn_warnings")):
		if int(warning.tier) == GermData.GermTier.BOSS_2: second_boss_warning = true
	_check(not second_boss_warning and int(game.get("boss_encounter_phase")) == 0 and int(game.get("bosses_defeated")) == 1, "second boss remains locked below one hundred thousand")
	game.call("_start_run")
	_check(int(game.get("base_weapon_damage")) == 1 and is_equal_approx(float(game.get("base_weapon_fire_rate")), 6.0) and int(game.get("bosses_defeated")) == 0 and int(game.get("boss_encounter_phase")) == 0 and int(game.call("_player_projectile_damage")) == 1, "new run restores the original weapon and boss progression")
	_clear_hostiles(game)
	game.call("_spawn_germ", GermData.GermTier.BOSS, Vector2(game.get("player_pos")))
	game.set("spawn_protection_left", 0.0)
	game.set("player_health", 1)
	game.call("_resolve_hostile_hits")
	_check(int(game.get("state")) == 5 and String(game.get("death_reason")) == "Germ contact", "boss contact removes the final health")
	_free_game(game)


func _test_second_boss_encounter_and_reward() -> void:
	var game := _new_game()
	game.call("_start_run")
	_clear_combat(game)
	game.call("_reset_dialogue")
	game.set("spawn_protection_left", 9999.0)
	var center := Vector2(game.get("arena_center"))
	game.set("bosses_defeated", 1)
	game.set("base_weapon_damage", 2)
	game.call("_queue_spawn_warning", GermData.GermTier.SMALL)
	game.call("_queue_spawn_warning", GermData.GermTier.ELITE)
	Array(game.get("debris"))[0] = {"active": true, "pos": center + Vector2.UP * 60.0, "vel": Vector2.ZERO, "life": 10.0, "angle": 0.0, "spin": 0.0, "hitter_cooldown": 0.0, "source": 0, "bounces": -1}
	game.set("score", GameMath.BOSS_2_SCORE_THRESHOLD - 25)
	game.set("combo", 1)
	game.set("last_kill_time", -999.0)
	game.call("_award_kill", 25, center)
	_check(int(game.get("boss_encounter_phase")) == 1 and int(game.get("active_boss_stage")) == 1 and Array(game.get("spawn_warnings")).is_empty(), "one hundred thousand enters the second cleanup stage")
	game.call("_update_boss_encounter")
	_check(Array(game.get("spawn_warnings")).is_empty(), "second boss waits for debris cleanup")
	Array(game.get("debris"))[0].active = false
	game.call("_update_boss_encounter")
	var second_warning_ok := Array(game.get("spawn_warnings")).size() == 1 and int(Array(game.get("spawn_warnings"))[0].tier) == GermData.GermTier.BOSS_2
	_check(second_warning_ok and int(game.get("boss_encounter_phase")) == 2, "cleared dish queues the second boss telegraph")
	game.call("_update_spawn_warnings", 2.501)
	var boss_pool: Array = game.get("germs")
	var boss: Dictionary = boss_pool[GameMath.BOSS_GERM_INDEX]
	_check(bool(boss.active) and int(boss.tier) == GermData.GermTier.BOSS_2 and int(boss.hp) == 600 and int(game.get("boss_encounter_phase")) == 3, "second boss reuses the dedicated boss slot")
	game.call("_reset_dialogue")

	boss_pool[GameMath.BOSS_GERM_INDEX].dash_timer = 0.0
	boss_pool[GameMath.BOSS_GERM_INDEX].volley_timer = 0.0
	game.call("_update_germs", 0.0)
	boss = boss_pool[GameMath.BOSS_GERM_INDEX]
	_check(int(boss.dash_phase) == 1 and is_equal_approx(float(boss.dash_timer), GameMath.BOSS_DASH_WARNING_SECONDS) and is_zero_approx(float(boss.volley_timer)), "second boss prioritizes the shared dash without advancing volley")
	game.call("_update_germs", 0.2)
	boss = boss_pool[GameMath.BOSS_GERM_INDEX]
	_check(int(boss.dash_phase) == 1 and is_zero_approx(float(boss.volley_timer)), "volley timer pauses during dash warning")
	boss_pool[GameMath.BOSS_GERM_INDEX].dash_phase = 0
	boss_pool[GameMath.BOSS_GERM_INDEX].dash_timer = 10.0
	boss_pool[GameMath.BOSS_GERM_INDEX].volley_timer = 0.0
	game.call("_update_germs", 0.0)
	boss = boss_pool[GameMath.BOSS_GERM_INDEX]
	var volley_rotation := float(boss.volley_rotation)
	_check(int(boss.dash_phase) == 3 and is_equal_approx(float(boss.volley_timer), GameMath.BOSS_VOLLEY_WARNING_SECONDS), "second boss enters a timed radial-volley warning")
	var saved_data: Dictionary = game.get("saved")
	saved_data.reduced_motion = true
	game.call("_update_germs", 0.5)
	boss = boss_pool[GameMath.BOSS_GERM_INDEX]
	_check(int(boss.dash_phase) == 3 and is_equal_approx(float(boss.dash_timer), 10.0) and _active_debris_indices(game, 1).is_empty(), "dash timer pauses during the reduced-motion volley warning")
	game.call("_update_germs", 0.41)
	boss = boss_pool[GameMath.BOSS_GERM_INDEX]
	var volley_indices := _active_debris_indices(game, 1)
	var volley_specs_ok := volley_indices.size() == GameMath.BOSS_VOLLEY_COUNT
	for index in volley_indices:
		var fragment: Dictionary = Array(game.get("debris"))[index]
		volley_specs_ok = volley_specs_ok and int(fragment.bounces) == 1 and is_equal_approx(float(fragment.life), GameMath.BOSS_VOLLEY_LIFETIME) and is_equal_approx(Vector2(fragment.vel).length(), GameMath.BOSS_VOLLEY_SPEED)
	_check(int(boss.dash_phase) == 0 and is_equal_approx(float(boss.volley_timer), GameMath.BOSS_VOLLEY_COOLDOWN) and volley_specs_ok and not is_nan(volley_rotation), "volley emits ten tagged one-bounce debris projectiles")

	var arena_radius := float(game.get("arena_radius"))
	var bouncing_index := volley_indices[0]
	Array(game.get("debris"))[bouncing_index].pos = center + Vector2.RIGHT * (arena_radius - 11.0)
	Array(game.get("debris"))[bouncing_index].vel = Vector2.RIGHT * GameMath.BOSS_VOLLEY_SPEED
	game.call("_update_debris", 0.1)
	_check(bool(Array(game.get("debris"))[bouncing_index].active) and int(Array(game.get("debris"))[bouncing_index].bounces) == 0, "volley debris consumes its single membrane bounce")
	Array(game.get("debris"))[bouncing_index].pos = center + Vector2.RIGHT * (arena_radius - 11.0)
	Array(game.get("debris"))[bouncing_index].vel = Vector2.RIGHT * GameMath.BOSS_VOLLEY_SPEED
	game.call("_update_debris", 0.1)
	_check(not bool(Array(game.get("debris"))[bouncing_index].active), "volley debris expires on its next membrane impact")
	var expiring_index := _active_debris_indices(game, 1)[0]
	Array(game.get("debris"))[expiring_index].life = 0.01
	game.call("_update_debris", 0.02)
	_check(not bool(Array(game.get("debris"))[expiring_index].active), "volley debris expires after six-second lifetime")
	var destructible_index := _active_debris_indices(game, 1)[0]
	var destructible_pos := Vector2(Array(game.get("debris"))[destructible_index].pos)
	boss_pool[GameMath.BOSS_GERM_INDEX].pos = center + Vector2.LEFT * 190.0
	game.set("score", 0)
	game.set("combo", 1)
	game.set("last_kill_time", -999.0)
	_clear_projectiles(game)
	game.call("_spawn_projectile", destructible_pos, Vector2.RIGHT, 0.0, 1.0, 0, 0)
	game.call("_resolve_projectile_hits")
	_check(not bool(Array(game.get("debris"))[destructible_index].active) and int(game.get("score")) == 10, "volley debris is destructible for the normal debris score")

	var levels: Array = game.get("item_levels")
	for i in levels.size(): levels[i] = ItemData.MAX_LEVEL
	game.call("_start_overcharge", ItemData.ItemType.SPREAD)
	boss_pool[GameMath.BOSS_GERM_INDEX].hp = 1
	game.call("_damage_germ", GameMath.BOSS_GERM_INDEX, 1)
	var volley_cleared := true
	for fragment in Array(game.get("debris")):
		if bool(fragment.active) and int(fragment.get("source", 0)) == 1: volley_cleared = false
	var levels_cleared := true
	for level in levels: levels_cleared = levels_cleared and int(level) == 0
	_check(volley_cleared and levels_cleared and int(game.get("overcharge_item")) == -1, "second boss reward clears volley debris and resets abilities")
	_check(int(game.get("base_weapon_damage")) == 2 and is_equal_approx(float(game.get("base_weapon_fire_rate")), 9.0) and is_equal_approx(float(game.call("_player_fire_interval")), 1.0 / 9.0) and int(game.get("bosses_defeated")) == 2 and int(game.get("boss_encounter_phase")) == 4 and not bool(game.call("_normal_spawning_enabled")), "second boss reward overclocks fire rate and waits for its boon choice")
	game.set("boon_selection_lock_left", 0.0)
	_check(bool(game.call("_collect_boon_choice", 0)) and int(game.get("boss_encounter_phase")) == 0 and bool(game.call("_normal_spawning_enabled")), "second boss resumes survival after its boon while the third milestone remains available")
	_clear_projectiles(game)
	levels[ItemData.ItemType.SPREAD] = 2
	levels[ItemData.ItemType.RICOCHET] = 2
	game.call("_fire_pellet")
	var overclocked_shots := 0
	var overclocked_curve_ok := true
	for projectile in Array(game.get("pellets")):
		if bool(projectile.active) and int(projectile.owner) == 0:
			overclocked_shots += 1
			overclocked_curve_ok = overclocked_curve_ok and int(projectile.damage) == 2 and int(projectile.bounces) == 2
	_check(overclocked_shots == 5 and overclocked_curve_ok and is_equal_approx(float(game.get("fire_cooldown")), 1.0 / 9.0), "overclocked spread and ricochet preserve two-damage scaling")
	game.set("score", GameMath.BOSS_3_SCORE_THRESHOLD - 100)
	game.call("_try_begin_next_boss_encounter")
	_check(int(game.get("bosses_defeated")) == 2 and int(game.get("boss_encounter_phase")) == 0, "third boss remains locked below one hundred fifty thousand")
	game.call("_start_run")
	_check(int(game.get("base_weapon_damage")) == 1 and is_equal_approx(float(game.get("base_weapon_fire_rate")), 6.0) and int(game.get("bosses_defeated")) == 0, "new run removes the fire-rate overclock")
	_free_game(game)

	var chain_game := _new_game()
	chain_game.call("_start_run")
	_clear_combat(chain_game)
	chain_game.call("_reset_dialogue")
	chain_game.set("spawn_protection_left", 9999.0)
	chain_game.set("score", GameMath.BOSS_2_SCORE_THRESHOLD)
	chain_game.call("_try_begin_next_boss_encounter")
	_check(int(chain_game.get("active_boss_stage")) == 0, "first boss remains mandatory when score jumps past both thresholds")
	chain_game.call("_update_boss_encounter")
	chain_game.call("_update_spawn_warnings", 2.501)
	chain_game.call("_reset_dialogue")
	chain_game.call("_damage_germ", GameMath.BOSS_GERM_INDEX, 240)
	_check(int(chain_game.get("bosses_defeated")) == 1 and int(chain_game.get("active_boss_stage")) == -1 and int(chain_game.get("boss_encounter_phase")) == 4, "crossed hundred-thousand threshold waits for the first boon choice")
	chain_game.set("boon_selection_lock_left", 0.0)
	chain_game.call("_collect_boon_choice", 0)
	_check(int(chain_game.get("active_boss_stage")) == 1 and int(chain_game.get("boss_encounter_phase")) == 1, "crossed hundred-thousand threshold chains after the first boon is chosen")
	_clear_hostiles(chain_game)
	chain_game.call("_spawn_germ", GermData.GermTier.BOSS_2, center)
	chain_game.call("_spawn_boss_volley", center, 0.0)
	var lethal_fragment := _active_debris_indices(chain_game, 1)[0]
	chain_game.set("player_pos", Vector2(Array(chain_game.get("debris"))[lethal_fragment].pos))
	chain_game.set("spawn_protection_left", 0.0)
	chain_game.set("player_health", 1)
	chain_game.call("_resolve_hostile_hits")
	_check(int(chain_game.get("state")) == 5 and String(chain_game.get("death_reason")) == "Debris contact", "second-boss volley debris removes the final health")
	_free_game(chain_game)


func _test_third_boss_encounter_and_reward() -> void:
	var game := _new_game()
	game.call("_start_run")
	_clear_combat(game)
	game.call("_reset_dialogue")
	game.set("spawn_protection_left", 9999.0)
	game.set("bosses_defeated", 2)
	game.set("base_weapon_damage", 2)
	game.set("base_weapon_fire_rate", GameMath.OVERCLOCKED_PLAYER_FIRE_RATE)
	var center := Vector2(game.get("arena_center"))
	Array(game.get("debris"))[0] = {"active": true, "pos": center + Vector2.UP * 70.0, "vel": Vector2.ZERO, "life": 10.0, "angle": 0.0, "spin": 0.0, "hitter_cooldown": 0.0, "goo_hit_cooldown": 0.0, "freeze_left": 0.0, "source": 0, "bounces": -1}
	game.set("score", GameMath.BOSS_3_SCORE_THRESHOLD - 25)
	game.set("combo", 1)
	game.set("last_kill_time", -999.0)
	game.call("_award_kill", 25, center)
	_check(int(game.get("boss_encounter_phase")) == 1 and int(game.get("active_boss_stage")) == 2, "one hundred fifty thousand enters the third cleanup stage")
	game.call("_update_boss_encounter")
	_check(Array(game.get("spawn_warnings")).is_empty(), "third boss waits for debris cleanup")
	Array(game.get("debris"))[0].active = false
	game.call("_update_boss_encounter")
	var third_warning_ok := Array(game.get("spawn_warnings")).size() == 1 and int(Array(game.get("spawn_warnings"))[0].tier) == GermData.GermTier.BOSS_3
	_check(third_warning_ok and int(game.get("boss_encounter_phase")) == 2, "cleared dish queues the third boss telegraph")
	game.call("_update_spawn_warnings", 2.501)
	var boss_pool: Array = game.get("germs")
	var boss: Dictionary = boss_pool[GameMath.BOSS_GERM_INDEX]
	_check(bool(boss.active) and int(boss.tier) == GermData.GermTier.BOSS_3 and int(boss.hp) == 2200 and int(game.get("boss_encounter_phase")) == 3, "third boss reuses the dedicated boss slot")
	_check(is_equal_approx(float(boss.dash_timer), GameMath.BOSS_INITIAL_DASH_DELAY) and is_equal_approx(float(boss.volley_timer), GameMath.BOSS_VOLLEY_INITIAL_DELAY) and is_equal_approx(float(boss.ring_timer), GameMath.BOSS_RING_INITIAL_DELAY), "third boss starts all three attack clocks with deterministic delays")
	game.call("_reset_dialogue")

	boss_pool[GameMath.BOSS_GERM_INDEX].dash_timer = 0.0
	boss_pool[GameMath.BOSS_GERM_INDEX].volley_timer = 0.0
	boss_pool[GameMath.BOSS_GERM_INDEX].ring_timer = 0.0
	game.call("_update_germs", 0.0)
	boss = boss_pool[GameMath.BOSS_GERM_INDEX]
	_check(int(boss.dash_phase) == 1 and is_zero_approx(float(boss.volley_timer)) and is_zero_approx(float(boss.ring_timer)), "third boss gives dash priority when all attacks are ready")
	game.call("_update_germs", 0.2)
	boss = boss_pool[GameMath.BOSS_GERM_INDEX]
	_check(is_zero_approx(float(boss.volley_timer)) and is_zero_approx(float(boss.ring_timer)), "volley and ring clocks pause during the dash warning")
	boss_pool[GameMath.BOSS_GERM_INDEX].dash_phase = 0
	boss_pool[GameMath.BOSS_GERM_INDEX].dash_timer = 10.0
	boss_pool[GameMath.BOSS_GERM_INDEX].volley_timer = 0.0
	boss_pool[GameMath.BOSS_GERM_INDEX].ring_timer = 0.0
	game.call("_update_germs", 0.0)
	boss = boss_pool[GameMath.BOSS_GERM_INDEX]
	_check(int(boss.dash_phase) == 3 and is_zero_approx(float(boss.ring_timer)), "third boss gives the radial volley priority over the ring")
	boss_pool[GameMath.BOSS_GERM_INDEX].volley_timer = 0.0
	game.call("_update_germs", 0.0)
	var third_volley := _active_debris_indices(game, 1)
	_check(third_volley.size() == GameMath.BOSS_VOLLEY_COUNT, "third boss retains the ten-projectile radial volley")

	boss_pool[GameMath.BOSS_GERM_INDEX].dash_phase = 0
	boss_pool[GameMath.BOSS_GERM_INDEX].dash_timer = 10.0
	boss_pool[GameMath.BOSS_GERM_INDEX].volley_timer = 10.0
	boss_pool[GameMath.BOSS_GERM_INDEX].ring_timer = 0.0
	game.set("player_pos", center + Vector2.RIGHT * 100.0)
	game.call("_update_germs", 0.0)
	boss = boss_pool[GameMath.BOSS_GERM_INDEX]
	_check(int(boss.dash_phase) == 4 and is_equal_approx(float(boss.ring_timer), GameMath.BOSS_RING_WARNING_SECONDS) and is_equal_approx(float(boss.ring_angle), 0.0), "ring warning locks a sixty-degree safe wedge toward the player")
	game.set("player_pos", center + Vector2.UP * 100.0)
	game.call("_update_germs", 0.5)
	boss = boss_pool[GameMath.BOSS_GERM_INDEX]
	_check(int(boss.dash_phase) == 4 and is_equal_approx(float(boss.ring_angle), 0.0) and is_equal_approx(float(boss.dash_timer), 10.0) and is_equal_approx(float(boss.volley_timer), 10.0), "ring direction stays locked and pauses the other attack clocks")
	var saved_data: Dictionary = game.get("saved")
	saved_data.reduced_motion = true
	boss_pool[GameMath.BOSS_GERM_INDEX].freeze_left = 1.0
	var warning_before_freeze := float(boss_pool[GameMath.BOSS_GERM_INDEX].ring_timer)
	game.call("_update_germs", 0.2)
	boss = boss_pool[GameMath.BOSS_GERM_INDEX]
	_check(is_equal_approx(float(boss.ring_timer), warning_before_freeze - 0.1), "freeze slows the reduced-motion ring warning to half speed")
	boss_pool[GameMath.BOSS_GERM_INDEX].freeze_left = 0.0
	game.call("_update_germs", float(boss.ring_timer) + 0.01)
	boss = boss_pool[GameMath.BOSS_GERM_INDEX]
	_check(int(boss.dash_phase) == 5 and is_equal_approx(float(boss.ring_timer), GameMath.BOSS_RING_ACTIVE_SECONDS), "ring warning transitions into the timed contraction")
	_check(is_equal_approx(float(game.call("_boss_ring_radius", GameMath.BOSS_RING_ACTIVE_SECONDS)), float(game.get("arena_radius"))) and is_zero_approx(float(game.call("_boss_ring_radius", 0.0))), "contracting ring travels from the membrane to the arena center")

	var arena_radius := float(game.get("arena_radius"))
	var crossing_start_seconds := GameMath.BOSS_RING_ACTIVE_SECONDS * 140.0 / arena_radius
	var crossing_delta := GameMath.BOSS_RING_ACTIVE_SECONDS * 80.0 / arena_radius
	game.set("spawn_protection_left", 0.0)
	game.set("damage_protection_left", 0.0)
	game.set("dash_left", 0.0)
	game.set("invincibility_left", 0.0)
	game.set("player_health", 3)
	game.set("player_pos", center + Vector2.UP * 100.0)
	boss_pool[GameMath.BOSS_GERM_INDEX].dash_phase = 5
	boss_pool[GameMath.BOSS_GERM_INDEX].ring_timer = crossing_start_seconds
	boss_pool[GameMath.BOSS_GERM_INDEX].ring_angle = 0.0
	boss_pool[GameMath.BOSS_GERM_INDEX].ring_hit_player = false
	game.call("_update_germs", crossing_delta)
	_check(int(game.get("player_health")) == 2 and bool(boss_pool[GameMath.BOSS_GERM_INDEX].ring_hit_player), "crossing the ring outside its wedge removes one health")
	game.set("damage_protection_left", 0.0)
	game.set("player_pos", center + Vector2.UP * 40.0)
	game.call("_update_germs", crossing_delta * 0.5)
	_check(int(game.get("player_health")) == 2, "one contracting ring cast cannot deal a second successful hit")

	game.set("player_health", 3)
	game.set("damage_protection_left", 0.0)
	game.set("player_pos", center + Vector2.RIGHT * 100.0)
	boss_pool[GameMath.BOSS_GERM_INDEX].dash_phase = 5
	boss_pool[GameMath.BOSS_GERM_INDEX].ring_timer = crossing_start_seconds
	boss_pool[GameMath.BOSS_GERM_INDEX].ring_angle = 0.0
	boss_pool[GameMath.BOSS_GERM_INDEX].ring_hit_player = false
	game.call("_update_germs", crossing_delta)
	_check(int(game.get("player_health")) == 3 and not bool(boss_pool[GameMath.BOSS_GERM_INDEX].ring_hit_player), "the locked sixty-degree wedge is safe")
	game.set("player_pos", center + Vector2.UP * 100.0)
	for guard in ["spawn", "dash", "invincibility", "grace"]:
		game.set("spawn_protection_left", 1.0 if guard == "spawn" else 0.0)
		game.set("dash_left", 0.1 if guard == "dash" else 0.0)
		game.set("invincibility_left", 0.1 if guard == "invincibility" else 0.0)
		game.set("damage_protection_left", 0.1 if guard == "grace" else 0.0)
		boss_pool[GameMath.BOSS_GERM_INDEX].dash_phase = 5
		boss_pool[GameMath.BOSS_GERM_INDEX].ring_timer = crossing_start_seconds
		boss_pool[GameMath.BOSS_GERM_INDEX].ring_hit_player = false
		game.call("_update_germs", crossing_delta)
	_check(int(game.get("player_health")) == 3, "spawn protection, Dash, Invincibility, and post-hit grace all guard against the ring")
	game.set("spawn_protection_left", 9999.0)
	game.set("dash_left", 0.0)
	game.set("invincibility_left", 0.0)
	game.set("damage_protection_left", 0.0)

	var levels: Array = game.get("item_levels")
	for i in levels.size(): levels[i] = ItemData.MAX_LEVEL
	game.call("_start_overcharge", ItemData.ItemType.TURRET)
	boss_pool[GameMath.BOSS_GERM_INDEX].hp = 1
	game.call("_damage_germ", GameMath.BOSS_GERM_INDEX, 1)
	var volley_cleared := _active_debris_indices(game, 1).is_empty()
	var levels_cleared := true
	for level in levels: levels_cleared = levels_cleared and int(level) == 0
	_check(volley_cleared and levels_cleared and int(game.get("overcharge_item")) == -1, "third boss reward clears volley debris and performs the full ability reset")
	_check(int(game.get("base_weapon_damage")) == 2 and is_equal_approx(float(game.get("base_weapon_fire_rate")), 9.0) and int(game.get("boss_health_bonus")) == 1 and int(game.get("player_health")) == 4 and int(game.get("player_max_health")) == 4, "third boss preserves the weapon and grants and fills one maximum health")
	_check(int(game.get("bosses_defeated")) == 3 and int(game.get("boss_encounter_phase")) == 4 and not bool(game.call("_normal_spawning_enabled")), "third boss waits for a third boon choice before completing")
	Array(game.get("boon_levels"))[BoonData.BoonType.MAX_HEALTH] = 1
	game.call("_restore_player_health")
	_check(int(game.get("player_health")) == 6 and int(game.get("player_max_health")) == 6, "third-boss health combines with the Max Health boon")
	game.set("boon_selection_lock_left", 0.0)
	_check(bool(game.call("_collect_boon_choice", 0)) and int(game.get("boss_encounter_phase")) == 5 and bool(game.call("_normal_spawning_enabled")) and is_equal_approx(float(game.get("elite_timer")), GameMath.ELITE_SPAWN_INTERVAL), "third boon resumes endless survival with every boss complete")
	game.call("_award_kill", 200000, center)
	_check(int(game.get("bosses_defeated")) == 3 and int(game.get("boss_encounter_phase")) == 5, "all three completed encounters cannot retrigger")
	game.call("_start_run")
	_check(int(game.get("boss_health_bonus")) == 0 and int(game.get("player_health")) == 3 and int(game.get("player_max_health")) == 3 and int(game.get("bosses_defeated")) == 0, "new run clears the third-boss health reward and progression")
	_free_game(game)

	var chain_game := _new_game()
	chain_game.call("_start_run")
	_clear_combat(chain_game)
	chain_game.call("_reset_dialogue")
	chain_game.set("score", GameMath.BOSS_3_SCORE_THRESHOLD)
	chain_game.call("_try_begin_next_boss_encounter")
	_check(int(chain_game.get("active_boss_stage")) == 0, "a score jump past all milestones still starts with boss one")
	chain_game.set("active_boss_stage", 0)
	chain_game.set("boss_encounter_phase", 3)
	chain_game.call("_complete_boss_encounter")
	chain_game.set("boon_selection_lock_left", 0.0)
	chain_game.call("_collect_boon_choice", 0)
	_check(int(chain_game.get("active_boss_stage")) == 1, "boss two chains only after the first boon choice")
	chain_game.set("active_boss_stage", 1)
	chain_game.set("boss_encounter_phase", 3)
	chain_game.call("_complete_boss_encounter")
	chain_game.set("boon_selection_lock_left", 0.0)
	chain_game.call("_collect_boon_choice", 0)
	_check(int(chain_game.get("active_boss_stage")) == 2 and int(chain_game.get("boss_encounter_phase")) == 1, "boss three chains only after the second boon choice")
	_free_game(chain_game)


func _test_boon_system() -> void:
	var game := _new_game()
	game.call("_start_run")
	_clear_combat(game)
	game.call("_reset_dialogue")
	game.set("spawn_protection_left", 0.0)
	var center := Vector2(game.get("arena_center"))
	var initial_node_count := _count_nodes(game)
	_check(BoonData.BoonType.size() == 9 and Array(game.get("boon_levels")).size() == 9, "boon data exposes nine run upgrades")
	_check(Array(game.get("boon_choices")).size() == 3 and Array(game.get("goo_patches")).size() == 64, "boon choices and goo use fixed three and sixty-four slot pools")

	var levels: Array = game.get("boon_levels")
	game.set("boss_encounter_phase", 4)
	game.set("boon_selection_lock_left", 0.0)
	Array(game.get("boon_choices"))[0] = {"active": true, "boon_type": BoonData.BoonType.DASH_EVADE, "pos": center, "phase": 0.0}
	game.call("_collect_boon_choice", 0)
	game.set("boss_encounter_phase", 4)
	game.set("boon_selection_lock_left", 0.0)
	Array(game.get("boon_choices"))[0] = {"active": true, "boon_type": BoonData.BoonType.INVINCIBILITY, "pos": center, "phase": 0.0}
	game.call("_collect_boon_choice", 0)
	_check(int(game.get("active_space_boon")) == BoonData.BoonType.INVINCIBILITY and int(levels[BoonData.BoonType.DASH_EVADE]) == 1 and int(levels[BoonData.BoonType.INVINCIBILITY]) == 1, "a new Space boon replaces the active slot while retaining stored levels")
	var incompatible_offer: Array = game.call("_generate_boon_offer")
	_check(not incompatible_offer.has(BoonData.BoonType.SPEED_BOOSTS), "Speed Boosts is filtered when the equipped Space ability cannot use it")
	game.set("boss_encounter_phase", 4)
	game.set("boon_selection_lock_left", 0.0)
	Array(game.get("boon_choices"))[0] = {"active": true, "boon_type": BoonData.BoonType.DASH_EVADE, "pos": center, "phase": 0.0}
	game.call("_collect_boon_choice", 0)
	_check(int(levels[BoonData.BoonType.DASH_EVADE]) == 2 and int(game.get("active_space_boon")) == BoonData.BoonType.DASH_EVADE, "repeated boons stack to level two and can be re-equipped")
	game.set("boss_encounter_phase", 4)
	game.set("boon_selection_lock_left", 0.0)
	game.set("player_health", 1)
	game.set("player_max_health", 3)
	Array(game.get("boon_choices"))[0] = {"active": true, "boon_type": BoonData.BoonType.MAX_HEALTH, "pos": center, "phase": 0.0}
	game.call("_collect_boon_choice", 0)
	_check(int(levels[BoonData.BoonType.MAX_HEALTH]) == 1 and int(game.get("player_health")) == 5 and int(game.get("player_max_health")) == 5, "Max Health raises the player from three to five health and fills the new capacity")
	var post_health_offer: Array = game.call("_generate_boon_offer")
	_check(not post_health_offer.has(BoonData.BoonType.MAX_HEALTH), "the one-level Max Health boon leaves the offer pool after collection")

	_check(is_equal_approx(BoonData.dash_speed(1), 600.0) and is_equal_approx(BoonData.dash_duration(1), 0.18) and is_equal_approx(BoonData.dash_cooldown(1), 2.5), "dash level one tuning")
	_check(is_equal_approx(BoonData.dash_speed(2), 700.0) and is_equal_approx(BoonData.dash_duration(2), 0.22) and is_equal_approx(BoonData.dash_cooldown(2), 2.0), "dash level two tuning")
	game.set("player_pos", center + Vector2.RIGHT * (float(game.get("arena_radius")) - 17.0))
	game.set("player_velocity", Vector2.RIGHT * 700.0)
	game.set("dash_direction", Vector2.RIGHT)
	game.set("dash_left", 0.1)
	game.call("_resolve_player_membrane")
	_check(int(game.get("state")) == 2 and is_zero_approx(float(game.get("dash_left"))) and Vector2(game.get("player_velocity")).is_zero_approx(), "dash is invulnerable and ends safely at the membrane")

	_clear_hostiles(game)
	game.set("player_pos", center)
	game.call("_spawn_germ", GermData.GermTier.SMALL, center)
	game.set("invincibility_left", 1.0)
	game.call("_resolve_hostile_hits")
	game.set("player_pos", center + Vector2.RIGHT * (float(game.get("arena_radius")) + 20.0))
	game.call("_resolve_player_membrane")
	_check(int(game.get("state")) == 2 and Vector2(game.get("player_pos")).distance_to(center) > float(game.get("arena_radius")), "invincibility ignores hostile and membrane contact with pass-through")
	_check(is_equal_approx(BoonData.invincibility_duration(1), 2.0) and is_equal_approx(BoonData.invincibility_cooldown(2), 10.0), "invincibility level timing")

	_clear_hostiles(game)
	game.set("player_pos", center)
	levels[BoonData.BoonType.POINT_MULTIPLIER] = 1
	game.set("score", 0)
	game.set("combo", 1)
	game.set("last_kill_time", -999.0)
	game.call("_award_kill", 100, center)
	_check(int(game.get("score")) == 150, "point multiplier increases future post-combo score")
	_check(is_equal_approx(BoonData.movement_multiplier(1), 1.15) and is_equal_approx(BoonData.movement_multiplier(2), 1.3), "movement speed boon scales acceleration and maximum speed")
	_check(is_equal_approx(BoonData.mobility_speed_multiplier(2), 1.3) and is_equal_approx(BoonData.mobility_duration_multiplier(2), 1.2) and is_equal_approx(BoonData.mobility_recharge_multiplier(2), 1.3), "Speed Boosts scales speed duration and recharge")

	levels[BoonData.BoonType.POINT_MULTIPLIER] = 0
	levels[BoonData.BoonType.GOO_TRAIL_BOOST] = 1
	game.call("_spawn_goo_patch", center)
	game.call("_spawn_germ", GermData.GermTier.SMALL, center)
	game.call("_update_goo_patches", 0.0)
	_check(not bool(Array(game.get("germs"))[0].active) and _active_goo_count(game) == 1, "goo patches damage a hostile and remain pooled")
	game.call("_spawn_germ", GermData.GermTier.LARGE, center)
	game.call("_update_goo_patches", 0.0)
	var large_index := _first_active_germ(game, GermData.GermTier.LARGE)
	var hp_after_first_goo := int(Array(game.get("germs"))[large_index].hp)
	game.call("_update_goo_patches", 0.0)
	_check(hp_after_first_goo == 2 and int(Array(game.get("germs"))[large_index].hp) == 2, "goo damage respects the per-hostile point-four-five-second cadence")
	_check(is_equal_approx(BoonData.goo_radius(1), 24.0) and is_equal_approx(BoonData.goo_lifetime(2), 5.0) and is_equal_approx(BoonData.goo_interval(2), 0.12), "goo trail levels use the configured size lifetime and deposit cadence")

	_clear_hostiles(game)
	levels[BoonData.BoonType.FREEZE_AOE_SHOCK] = 1
	game.set("player_pos", center)
	game.call("_spawn_germ", GermData.GermTier.SMALL, center + Vector2.RIGHT * 80.0)
	game.call("_spawn_germ", GermData.GermTier.BOSS, center + Vector2.LEFT * 80.0)
	var regular_index := _first_active_germ(game, GermData.GermTier.SMALL)
	var boss_index := GameMath.BOSS_GERM_INDEX
	var regular_before := Vector2(Array(game.get("germs"))[regular_index].pos)
	var boss_dash_before := float(Array(game.get("germs"))[boss_index].dash_timer)
	Array(game.get("debris"))[0] = {"active": true, "pos": center, "vel": Vector2.RIGHT * 100.0, "life": 5.0, "angle": 0.0, "spin": 1.0, "hitter_cooldown": 0.0, "goo_hit_cooldown": 0.0, "freeze_left": 0.0, "source": 0, "bounces": -1}
	game.call("_activate_freeze_shock")
	game.call("_update_germs", 1.0)
	game.call("_update_debris", 1.0)
	_check(Vector2(Array(game.get("germs"))[regular_index].pos).is_equal_approx(regular_before) and is_equal_approx(float(Array(game.get("debris"))[0].life), 5.0), "freeze fully stops regular germs and debris")
	_check(is_equal_approx(float(Array(game.get("germs"))[boss_index].dash_timer), boss_dash_before - 0.5), "freeze advances boss movement and attack timers at half speed")
	_check(is_equal_approx(BoonData.freeze_radius(2), 220.0) and is_equal_approx(BoonData.freeze_duration(2), 4.0) and is_equal_approx(BoonData.freeze_cooldown(2), 8.0), "freeze level two tuning")

	_clear_hostiles(game)
	levels[BoonData.BoonType.CHARGED_BEAM] = 1
	game.set("player_pos", center)
	game.set("beam_direction", Vector2.RIGHT)
	game.call("_spawn_germ", GermData.GermTier.BOSS, center + Vector2.RIGHT * 140.0)
	var beam_boss_hp := int(Array(game.get("germs"))[GameMath.BOSS_GERM_INDEX].hp)
	game.call("_damage_beam", 1)
	game.call("_begin_charged_beam")
	_check(int(Array(game.get("germs"))[GameMath.BOSS_GERM_INDEX].hp) == beam_boss_hp - 4 and is_equal_approx(float(game.get("beam_active_left")), 3.0), "charged beam deals level-one tick damage and lasts three seconds")
	levels[BoonData.BoonType.CHARGED_BEAM] = 2
	game.call("_damage_beam", 2)
	_check(int(Array(game.get("germs"))[GameMath.BOSS_GERM_INDEX].hp) == beam_boss_hp - 10 and is_equal_approx(BoonData.beam_width(2), 24.0), "charged beam level two widens and deals six damage per tick")

	game.call("_start_run")
	var reset_levels := true
	for level in Array(game.get("boon_levels")): reset_levels = reset_levels and int(level) == 0
	_check(reset_levels and int(game.get("active_space_boon")) == BoonData.NO_BOON and _active_goo_count(game) == 0 and is_zero_approx(float(game.get("beam_active_left"))) and is_zero_approx(float(game.get("freeze_cooldown"))) and int(game.get("player_health")) == 3 and int(game.get("player_max_health")) == 3, "new runs clear boons and transient effects and restore base health")
	_check(_count_nodes(game) == initial_node_count, "boon combat and selection add no runtime nodes")
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
	game.call("_update_run", 2.11)
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
	_check(germ_pool.size() == 37 and active_germs <= 37, "ten-minute run respects regular, elite, and boss germ cap")
	_check(debris_pool.size() == 80 and active_debris <= 80, "ten-minute run respects fragment pool cap")
	_check(pellet_pool.size() == 240, "projectile pool remains fixed")
	_check(Array(game.get("turrets")).size() == 3 and Array(game.get("mines")).size() == 48 and Array(game.get("effect_flashes")).size() == 24, "item combat and effect pools remain fixed")
	_check(Array(game.get("pickups")).size() == 4 and Array(game.get("item_warnings")).size() == 4, "pickup and item warning pools remain fixed")
	_check(Array(game.get("boon_choices")).size() == 3 and Array(game.get("goo_patches")).size() == 64, "boon selection and goo pools remain fixed")
	_check(_count_nodes(game) == initial_node_count, "ten-minute simulation leaks no nodes")
	audio_manager.call("stop_all")
	game.free()


func _count_nodes(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _count_nodes(child)
	return count


func _first_active_germ(game: Node, tier: int) -> int:
	for i in Array(game.get("germs")).size():
		var germ: Dictionary = Array(game.get("germs"))[i]
		if bool(germ.active) and int(germ.tier) == tier:
			return i
	return -1


func _active_germ_indices(game: Node, tier: int) -> Array[int]:
	var indices: Array[int] = []
	for i in Array(game.get("germs")).size():
		var germ: Dictionary = Array(game.get("germs"))[i]
		if bool(germ.active) and int(germ.tier) == tier:
			indices.append(i)
	return indices


func _active_debris_indices(game: Node, source: int) -> Array[int]:
	var indices: Array[int] = []
	for i in Array(game.get("debris")).size():
		var fragment: Dictionary = Array(game.get("debris"))[i]
		if bool(fragment.active) and int(fragment.get("source", 0)) == source:
			indices.append(i)
	return indices


func _active_goo_count(game: Node) -> int:
	var count := 0
	for patch in Array(game.get("goo_patches")):
		if bool(patch.active): count += 1
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
