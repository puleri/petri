extends Node2D

signal run_time_changed(seconds: float)
signal score_changed(score: int)
signal combo_changed(multiplier: int)
signal boost_charge_changed(charge: float)
signal pause_state_changed(paused: bool)
signal game_over(score: int, survival_time: float, reason: String)

enum AppState { MENU, HOW_TO, PLAYING, PAUSED, SETTINGS, GAME_OVER }

const BG := Color("#D7FFF8")
const MINT := Color("#B2DBD5")
const DARK_MINT := Color("#70A097")
const ACCENT_MINT := Color("#6FB2AD")
const GAME_BG := Color("#B5DAD4")
const RAIL_MINT := Color("#D4EBE7")
const DISH_EDGE := Color("#C9E6E1")
const WHITE := Color("#FFFFFF")
const ORANGE := Color("#FFD9A6")
const ORANGE_HOT := Color("#FF9E73")
const LIME := Color("#DCFF84")
const LIME_DARK := Color("#A9C375")
const CYAN := Color("#55DDE0")
const PURPLE_SOFT := Color("#EFCEFD")
const PURPLE := Color("#77408E")

const PLAYER_RADIUS := 18.0
const BASE_ACCEL := 360.0
const BASE_MAX_SPEED := 190.0
const DRAG := 105.0
const BOOST_ACCEL_MULT := 1.8
const BOOST_SPEED_MULT := 1.5
const FIRE_INTERVAL := 1.0 / 6.0
const PELLET_SPEED := 520.0
const PELLET_LIFETIME := 1.25
const SPAWN_PROTECTION := 1.5
const DEBRIS_LIFETIME := 12.0
const PELLET_POOL_SIZE := 120
const ARENA_SCALE := 1.15
const SPAWN_TELEGRAPH_SECONDS := 0.85

var font: Font = preload("res://Excelorate-Font.otf")
var logo_texture: Texture2D = preload("res://assets/figma/petri-logo.png")
var germ_specs: Array[GermData] = [
	preload("res://data/germ_large.tres"),
	preload("res://data/germ_medium.tres"),
	preload("res://data/germ_small.tres"),
]

@onready var audio: PetriAudio = $AudioManager

var state := AppState.MENU
var settings_return_state := AppState.MENU
var save_store := SaveStore.new()
var saved := {}
var rng := RandomNumberGenerator.new()

var viewport_size := Vector2(1280.0, 720.0)
var css_viewport_width := 1280.0
var arena_center := Vector2(640.0, 345.0)
var arena_radius := 252.0
var wide_layout := false

var player_pos := Vector2.ZERO
var player_velocity := Vector2.ZERO
var player_facing := 0.0
var boost_charge := 1.0
var boost_delay := 0.0
var boost_active := false
var spawn_protection_left := 0.0
var fire_cooldown := 0.0

var run_time := 0.0
var score := 0
var combo := 1
var last_kill_time := -999.0
var spawn_timer := 0.0
var death_reason := ""
var screen_shake := 0.0

var pellets: Array[Dictionary] = []
var germs: Array[Dictionary] = []
var debris: Array[Dictionary] = []
var spawn_warnings: Array[Dictionary] = []
var popups: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	_create_pools()
	saved = save_store.load_data()
	audio.apply_levels(float(saved.sfx_volume), float(saved.music_volume))
	_apply_fullscreen_preference()
	_update_layout()
	player_pos = arena_center
	queue_redraw()


func _create_pools() -> void:
	for i in PELLET_POOL_SIZE:
		pellets.append({"active": false, "pos": Vector2.ZERO, "vel": Vector2.ZERO, "life": 0.0})
	for i in GameMath.MAX_GERMS:
		germs.append({"active": false, "tier": GermData.GermTier.LARGE, "pos": Vector2.ZERO, "vel": Vector2.ZERO, "hp": 0, "phase": 0.0})
	for i in GameMath.MAX_FRAGMENTS:
		debris.append({"active": false, "pos": Vector2.ZERO, "vel": Vector2.ZERO, "life": 0.0, "angle": 0.0, "spin": 0.0})


func _process(delta: float) -> void:
	_update_layout()
	if state == AppState.PLAYING:
		_update_run(delta)
	_update_popups(delta)
	screen_shake = maxf(0.0, screen_shake - delta * 2.6)
	queue_redraw()


func _update_layout() -> void:
	viewport_size = get_viewport_rect().size
	css_viewport_width = viewport_size.x
	if OS.has_feature("web"):
		var browser_width: Variant = JavaScriptBridge.eval("window.innerWidth", true)
		if browser_width != null:
			css_viewport_width = float(browser_width)
	wide_layout = viewport_size.x / maxf(viewport_size.y, 1.0) >= 2.0
	arena_center = Vector2(viewport_size.x * 0.5, viewport_size.y * (0.48 if wide_layout else 0.46))
	if wide_layout:
		arena_radius = minf(viewport_size.y * 0.39, viewport_size.x * 0.23)
	else:
		arena_radius = minf(viewport_size.y * 0.35, viewport_size.x * 0.34)
	arena_radius = maxf(190.0, arena_radius) * ARENA_SCALE


func _update_run(delta: float) -> void:
	run_time += delta
	spawn_protection_left = maxf(0.0, spawn_protection_left - delta)
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	emit_signal("run_time_changed", run_time)

	var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var wants_boost := Input.is_action_pressed("boost") and movement.length_squared() > 0.0
	var boost_state := GameMath.update_boost(boost_charge, boost_delay, wants_boost, delta)
	var was_boosting := boost_active
	boost_charge = float(boost_state.charge)
	boost_delay = float(boost_state.delay)
	boost_active = bool(boost_state.active)
	if boost_active and not was_boosting:
		audio.play_sfx("boost")
	emit_signal("boost_charge_changed", boost_charge)

	var accel := BASE_ACCEL * (BOOST_ACCEL_MULT if boost_active else 1.0)
	var max_speed := BASE_MAX_SPEED * (BOOST_SPEED_MULT if boost_active else 1.0)
	if movement.length_squared() > 0.0:
		player_velocity += movement.normalized() * accel * delta
	else:
		player_velocity = player_velocity.move_toward(Vector2.ZERO, DRAG * delta)
	if player_velocity.length() > max_speed:
		player_velocity = player_velocity.normalized() * max_speed
	player_pos += player_velocity * delta
	_resolve_player_membrane()

	var aim := get_global_mouse_position() - player_pos
	if aim.length_squared() > 1.0:
		player_facing = aim.angle()
	if Input.is_action_pressed("fire") and fire_cooldown <= 0.0:
		_fire_pellet()

	_update_pellets(delta)
	_update_spawn_warnings(delta)
	_update_germs(delta)
	_update_debris(delta)
	_resolve_projectile_hits()
	_resolve_hostile_hits()

	if combo > 1 and run_time - last_kill_time > 2.0:
		combo = 1
		emit_signal("combo_changed", combo)

	spawn_timer -= delta
	if spawn_timer <= 0.0 and _active_germ_count() + spawn_warnings.size() < GameMath.active_germ_cap(run_time):
		_queue_spawn_warning(_weighted_spawn_tier())
		spawn_timer = GameMath.spawn_interval(run_time)


func _resolve_player_membrane() -> void:
	var from_center := player_pos - arena_center
	var limit := arena_radius - PLAYER_RADIUS
	if from_center.length() <= limit:
		return
	var normal := from_center.normalized()
	var outward_speed := maxf(0.0, player_velocity.dot(normal))
	player_pos = arena_center + normal * limit
	if GameMath.membrane_is_lethal(outward_speed):
		_finish_run("Membrane impact")
		return
	player_velocity = player_velocity.bounce(normal) * 0.66
	audio.play_sfx("impact")
	if not bool(saved.reduced_motion):
		screen_shake = maxf(screen_shake, 0.22)


func _fire_pellet() -> void:
	for i in pellets.size():
		if not bool(pellets[i].active):
			var direction := Vector2.RIGHT.rotated(player_facing)
			pellets[i] = {
				"active": true,
				"pos": player_pos + direction * (PLAYER_RADIUS + 11.0),
				"vel": direction * PELLET_SPEED + player_velocity * 0.22,
				"life": PELLET_LIFETIME,
			}
			fire_cooldown = FIRE_INTERVAL
			audio.play_sfx("fire")
			return


func _update_pellets(delta: float) -> void:
	for i in pellets.size():
		if not bool(pellets[i].active):
			continue
		var p := pellets[i]
		p.pos += p.vel * delta
		p.life = float(p.life) - delta
		if float(p.life) <= 0.0 or (Vector2(p.pos) - arena_center).length() > arena_radius:
			p.active = false
		pellets[i] = p


func _update_germs(delta: float) -> void:
	var speed_mult := GameMath.threat_speed_multiplier(run_time)
	for i in germs.size():
		if not bool(germs[i].active):
			continue
		var g := germs[i]
		var target_dir := (player_pos - Vector2(g.pos)).normalized()
		var current_speed := Vector2(g.vel).length()
		var wanted := target_dir * current_speed
		g.vel = Vector2(g.vel).lerp(wanted, minf(1.0, delta * 0.18))
		g.pos += Vector2(g.vel) * speed_mult * delta
		g.phase = float(g.phase) + delta
		var spec := germ_specs[int(g.tier)]
		var edge := Vector2(g.pos) - arena_center
		if edge.length() + spec.radius > arena_radius:
			var normal := edge.normalized()
			g.pos = arena_center + normal * (arena_radius - spec.radius)
			g.vel = Vector2(g.vel).bounce(normal)
		germs[i] = g


func _update_debris(delta: float) -> void:
	for i in debris.size():
		if not bool(debris[i].active):
			continue
		var d := debris[i]
		d.pos += Vector2(d.vel) * delta
		d.angle = float(d.angle) + float(d.spin) * delta
		d.life = float(d.life) - delta
		var edge := Vector2(d.pos) - arena_center
		if edge.length() + 10.0 > arena_radius:
			var normal := edge.normalized()
			d.pos = arena_center + normal * (arena_radius - 10.0)
			d.vel = Vector2(d.vel).bounce(normal) * 0.82
		if float(d.life) <= 0.0:
			d.active = false
		debris[i] = d


func _resolve_projectile_hits() -> void:
	for pi in pellets.size():
		if not bool(pellets[pi].active):
			continue
		var pellet_pos := Vector2(pellets[pi].pos)
		var hit := false
		for gi in germs.size():
			if not bool(germs[gi].active):
				continue
			var spec := germ_specs[int(germs[gi].tier)]
			if pellet_pos.distance_squared_to(Vector2(germs[gi].pos)) <= pow(spec.radius + 5.0, 2.0):
				pellets[pi].active = false
				germs[gi].hp = int(germs[gi].hp) - 1
				if int(germs[gi].hp) <= 0:
					_destroy_germ(gi)
				else:
					audio.play_sfx("impact")
				hit = true
				break
		if hit:
			continue
		for di in debris.size():
			if not bool(debris[di].active):
				continue
			if pellet_pos.distance_squared_to(Vector2(debris[di].pos)) <= 225.0:
				pellets[pi].active = false
				debris[di].active = false
				_award_kill(10, Vector2(debris[di].pos))
				break


func _resolve_hostile_hits() -> void:
	if not GameMath.hostile_collision_is_lethal(spawn_protection_left):
		return
	for g in germs:
		if not bool(g.active):
			continue
		var spec := germ_specs[int(g.tier)]
		if player_pos.distance_squared_to(Vector2(g.pos)) <= pow(PLAYER_RADIUS + spec.radius * 0.82, 2.0):
			_finish_run("Germ contact")
			return
	for d in debris:
		if bool(d.active) and player_pos.distance_squared_to(Vector2(d.pos)) <= pow(PLAYER_RADIUS + 8.0, 2.0):
			_finish_run("Debris contact")
			return


func _spawn_germ(tier: int, position_override: Variant = null) -> bool:
	for i in germs.size():
		if bool(germs[i].active):
			continue
		var spec := germ_specs[tier]
		var angle := rng.randf_range(0.0, TAU)
		var at := _spawn_position(tier, angle)
		if position_override != null:
			at = Vector2(position_override)
		var speed := rng.randf_range(spec.speed_min, spec.speed_max)
		var direction := (player_pos - at).normalized().rotated(rng.randf_range(-0.5, 0.5))
		germs[i] = {"active": true, "tier": tier, "pos": at, "vel": direction * speed, "hp": spec.hp, "phase": rng.randf_range(0.0, TAU)}
		return true
	return false


func _spawn_position(tier: int, angle: float) -> Vector2:
	var spec := germ_specs[tier]
	return arena_center + Vector2.RIGHT.rotated(angle) * (arena_radius - spec.radius - 8.0)


func _queue_spawn_warning(tier: int, angle_override: Variant = null) -> void:
	var angle := rng.randf_range(0.0, TAU)
	if angle_override != null:
		angle = float(angle_override)
	spawn_warnings.append({
		"tier": tier,
		"angle": angle,
		"life": SPAWN_TELEGRAPH_SECONDS,
		"duration": SPAWN_TELEGRAPH_SECONDS,
	})


func _update_spawn_warnings(delta: float) -> void:
	for i in range(spawn_warnings.size() - 1, -1, -1):
		var warning := spawn_warnings[i]
		warning.life = float(warning.life) - delta
		if float(warning.life) <= 0.0:
			var tier := int(warning.tier)
			_spawn_germ(tier, _spawn_position(tier, float(warning.angle)))
			spawn_warnings.remove_at(i)
		else:
			spawn_warnings[i] = warning


func _spawn_debris(at: Vector2, count: int) -> void:
	var made := 0
	for i in debris.size():
		if bool(debris[i].active):
			continue
		var angle := rng.randf_range(0.0, TAU)
		debris[i] = {
			"active": true,
			"pos": at + Vector2.RIGHT.rotated(angle) * rng.randf_range(5.0, 18.0),
			"vel": Vector2.RIGHT.rotated(angle) * rng.randf_range(70.0, 145.0),
			"life": DEBRIS_LIFETIME,
			"angle": angle,
			"spin": rng.randf_range(-4.5, 4.5),
		}
		made += 1
		if made >= count:
			return


func _destroy_germ(index: int) -> void:
	var tier := int(germs[index].tier)
	var at := Vector2(germs[index].pos)
	germs[index].active = false
	var spec := germ_specs[tier]
	_award_kill(spec.score, at)
	var split := GameMath.split_result(tier)
	for child in int(split.children):
		var offset := Vector2.RIGHT.rotated(TAU * float(child) / maxf(1.0, float(split.children)) + rng.randf_range(-0.25, 0.25)) * 16.0
		_spawn_germ(int(split.child_tier), at + offset)
	_spawn_debris(at, int(split.fragments))
	audio.play_sfx("split")
	if not bool(saved.reduced_motion):
		screen_shake = maxf(screen_shake, 0.34)


func _award_kill(base: int, at: Vector2) -> void:
	combo = GameMath.combo_after_kill(combo, run_time - last_kill_time)
	last_kill_time = run_time
	var points := GameMath.awarded_score(base, combo)
	score += points
	popups.append({"pos": at, "text": "+%d%s" % [points, "   %dx" % combo if combo > 1 else ""], "life": 0.8})
	emit_signal("score_changed", score)
	emit_signal("combo_changed", combo)


func _weighted_spawn_tier() -> int:
	var roll := rng.randf()
	if roll < 0.26:
		return GermData.GermTier.LARGE
	if roll < 0.67:
		return GermData.GermTier.MEDIUM
	return GermData.GermTier.SMALL


func _active_germ_count() -> int:
	var count := 0
	for g in germs:
		if bool(g.active):
			count += 1
	return count


func _update_popups(delta: float) -> void:
	for i in range(popups.size() - 1, -1, -1):
		popups[i].life = float(popups[i].life) - delta
		popups[i].pos = Vector2(popups[i].pos) + Vector2.UP * 32.0 * delta
		if float(popups[i].life) <= 0.0:
			popups.remove_at(i)


func _start_run() -> void:
	for i in pellets.size(): pellets[i].active = false
	for i in germs.size(): germs[i].active = false
	for i in debris.size(): debris[i].active = false
	spawn_warnings.clear()
	popups.clear()
	run_time = 0.0
	score = 0
	combo = 1
	last_kill_time = -999.0
	boost_charge = 1.0
	boost_delay = 0.0
	boost_active = false
	spawn_protection_left = SPAWN_PROTECTION
	fire_cooldown = 0.0
	player_pos = arena_center
	player_velocity = Vector2.ZERO
	player_facing = 0.0
	spawn_timer = GameMath.spawn_interval(0.0)
	death_reason = ""
	state = AppState.PLAYING
	audio.unlock()
	audio.play_sfx("ui")
	var opening_tiers := [GermData.GermTier.LARGE, GermData.GermTier.MEDIUM, GermData.GermTier.MEDIUM, GermData.GermTier.SMALL, GermData.GermTier.SMALL]
	var opening_rotation := rng.randf_range(0.0, TAU)
	for i in opening_tiers.size():
		_queue_spawn_warning(opening_tiers[i], opening_rotation + TAU * float(i) / float(opening_tiers.size()))
	emit_signal("score_changed", score)
	emit_signal("combo_changed", combo)
	emit_signal("pause_state_changed", false)


func _finish_run(reason: String) -> void:
	if state != AppState.PLAYING:
		return
	death_reason = reason
	state = AppState.GAME_OVER
	boost_active = false
	save_store.update_bests(score, run_time, saved)
	audio.play_sfx("game_over")
	emit_signal("game_over", score, run_time, reason)


func _set_pause(paused: bool) -> void:
	if paused and state == AppState.PLAYING:
		state = AppState.PAUSED
		emit_signal("pause_state_changed", true)
	elif not paused and state == AppState.PAUSED:
		state = AppState.PLAYING
		emit_signal("pause_state_changed", false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == AppState.PLAYING:
		_set_pause(true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if state == AppState.PLAYING:
			_set_pause(true)
		elif state == AppState.PAUSED:
			_set_pause(false)
		elif state == AppState.HOW_TO:
			state = AppState.MENU
		elif state == AppState.SETTINGS:
			state = settings_return_state
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("restart") and state == AppState.GAME_OVER:
		_start_run()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER and state == AppState.MENU:
		_start_run()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_click(event.position)


func _handle_click(pos: Vector2) -> void:
	if state == AppState.MENU:
		for i in 3:
			if _menu_button_rect(i).has_point(pos):
				audio.unlock()
				audio.play_sfx("ui")
				if i == 0: _start_run()
				elif i == 1: state = AppState.HOW_TO
				else:
					settings_return_state = AppState.MENU
					state = AppState.SETTINGS
				return
	elif state == AppState.HOW_TO:
		if _single_button_rect().has_point(pos):
			state = AppState.MENU
			audio.play_sfx("ui")
	elif state == AppState.PAUSED:
		for i in 3:
			if _overlay_button_rect(i, 3).has_point(pos):
				audio.play_sfx("ui")
				if i == 0: _set_pause(false)
				elif i == 1:
					settings_return_state = AppState.PAUSED
					state = AppState.SETTINGS
				else: state = AppState.MENU
				return
	elif state == AppState.GAME_OVER:
		for i in 2:
			if _overlay_button_rect(i, 2).has_point(pos):
				audio.play_sfx("ui")
				if i == 0: _start_run()
				else: state = AppState.MENU
				return
	elif state == AppState.SETTINGS:
		for i in 4:
			if _settings_row_rect(i).has_point(pos):
				_change_setting(i)
				return
		if _single_button_rect().has_point(pos):
			state = settings_return_state
			audio.play_sfx("ui")


func _change_setting(index: int) -> void:
	match index:
		0: saved.sfx_volume = _cycle_level(float(saved.sfx_volume), [0.0, 0.4, 0.8, 1.0])
		1: saved.music_volume = _cycle_level(float(saved.music_volume), [0.0, 0.25, 0.5, 0.75])
		2:
			saved.fullscreen = not bool(saved.fullscreen)
			_apply_fullscreen_preference()
		3: saved.reduced_motion = not bool(saved.reduced_motion)
	save_store.save_data(saved)
	audio.apply_levels(float(saved.sfx_volume), float(saved.music_volume))
	audio.play_sfx("ui")


func _cycle_level(value: float, values: Array) -> float:
	for i in values.size():
		if is_equal_approx(value, float(values[i])):
			return float(values[(i + 1) % values.size()])
	return float(values[0])


func _apply_fullscreen_preference() -> void:
	if bool(saved.get("fullscreen", false)):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, viewport_size), BG)
	if state == AppState.MENU:
		_draw_menu()
	elif state == AppState.HOW_TO:
		_draw_how_to()
	elif state == AppState.SETTINGS:
		_draw_settings()
	else:
		_draw_game_world()
		if state == AppState.PAUSED:
			_draw_pause()
		elif state == AppState.GAME_OVER:
			_draw_game_over()
	if css_viewport_width < 1024.0:
		_draw_desktop_recommendation()


func _visual_offset() -> Vector2:
	if bool(saved.get("reduced_motion", false)) or screen_shake <= 0.0:
		return Vector2.ZERO
	return Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * 12.0 * screen_shake


func _draw_game_world() -> void:
	var offset := _visual_offset()
	var center := arena_center + offset
	draw_rect(Rect2(Vector2.ZERO, viewport_size), GAME_BG)
	var visual_unit := _hud_unit()
	var rail_top := maxf(viewport_size.x * 0.08, arena_center.x - arena_radius - visual_unit * 0.11)
	var rail_slope := minf(visual_unit * 0.36, viewport_size.x * 0.24)
	draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2(rail_top, 0), Vector2(maxf(0.0, rail_top - rail_slope), viewport_size.y), Vector2(0, viewport_size.y)]), RAIL_MINT)
	draw_colored_polygon(PackedVector2Array([Vector2(viewport_size.x - rail_top, 0), Vector2(viewport_size.x, 0), viewport_size, Vector2(minf(viewport_size.x, viewport_size.x - rail_top + rail_slope), viewport_size.y)]), RAIL_MINT)
	draw_circle(center, arena_radius + minf(viewport_size.x, viewport_size.y) * 0.37, Color(RAIL_MINT.r, RAIL_MINT.g, RAIL_MINT.b, 0.72))
	draw_circle(center, arena_radius + 34.0, Color(WHITE.r, WHITE.g, WHITE.b, 0.16))
	for layer in 16:
		var blend := float(layer + 1) / 16.0
		var edge_radius := arena_radius + 22.0 * (1.0 - blend)
		draw_circle(center, edge_radius, DISH_EDGE.lerp(WHITE, blend))
	draw_circle(center, arena_radius, WHITE)
	draw_arc(center, arena_radius, 0.0, TAU, 160, Color(ACCENT_MINT.r, ACCENT_MINT.g, ACCENT_MINT.b, 0.26), 2.0, true)

	for warning in spawn_warnings:
		_draw_spawn_warning(warning, offset)
	for d in debris:
		if bool(d.active): _draw_debris(Vector2(d.pos) + offset, float(d.angle))
	for g in germs:
		if bool(g.active): _draw_germ(g, offset)
	for p in pellets:
		if bool(p.active):
			draw_circle(Vector2(p.pos) + offset, 5.0, LIME)
			draw_arc(Vector2(p.pos) + offset, 6.5, 0.0, TAU, 18, LIME_DARK, 1.5, true)
	_draw_player(offset)
	_draw_reticle(get_global_mouse_position())
	for popup in popups:
		var alpha := clampf(float(popup.life) / 0.8, 0.0, 1.0)
		_draw_text_centered(str(popup.text), Vector2(popup.pos) + offset, 24, Color(0.466, 0.251, 0.557, alpha))
	_draw_hud()


func _draw_spawn_warning(warning: Dictionary, offset: Vector2) -> void:
	var tier := int(warning.tier)
	var spec := germ_specs[tier]
	var pos := _spawn_position(tier, float(warning.angle)) + offset
	var progress := 1.0 - clampf(float(warning.life) / float(warning.duration), 0.0, 1.0)
	var motion := 0.0 if bool(saved.get("reduced_motion", false)) else sin(progress * TAU * 3.0)
	var aura_radius := spec.radius + 18.0 + motion * 5.0
	var color := CYAN if tier != GermData.GermTier.MEDIUM else PURPLE_SOFT
	draw_circle(pos, aura_radius, Color(color.r, color.g, color.b, 0.09 + progress * 0.1))
	for ring in 3:
		var ring_radius := aura_radius + float(ring) * 9.0 - progress * 7.0
		var ring_alpha := clampf(0.5 - float(ring) * 0.11 + progress * 0.25, 0.12, 0.75)
		draw_arc(pos, ring_radius, 0.0, TAU, 42, Color(PURPLE.r, PURPLE.g, PURPLE.b, ring_alpha), 2.0, true)
	var inward := (arena_center - pos).normalized()
	var side := inward.orthogonal()
	var tip := pos + inward * (aura_radius + 10.0)
	var arrow := PackedVector2Array([tip, tip - inward * 13.0 + side * 7.0, tip - inward * 13.0 - side * 7.0])
	draw_colored_polygon(arrow, Color(LIME.r, LIME.g, LIME.b, 0.72))


func _draw_germ(g: Dictionary, offset: Vector2) -> void:
	var pos := Vector2(g.pos) + offset
	var spec := germ_specs[int(g.tier)]
	var radius := spec.radius
	var fill := CYAN if int(g.tier) != GermData.GermTier.MEDIUM else PURPLE_SOFT
	for i in 10:
		var a := TAU * float(i) / 10.0 + float(g.phase) * 0.18
		var inner := pos + Vector2.RIGHT.rotated(a) * (radius * 0.78)
		var outer := pos + Vector2.RIGHT.rotated(a) * (radius + 5.0 + sin(a * 3.0) * 3.0)
		draw_line(inner, outer, PURPLE, maxf(1.5, radius * 0.07), true)
	draw_circle(pos, radius, Color(fill.r, fill.g, fill.b, 0.78))
	draw_arc(pos, radius, 0.0, TAU, 48, PURPLE, maxf(2.0, radius * 0.08), true)
	draw_circle(pos + Vector2(-radius * 0.24, -radius * 0.12), radius * 0.12, PURPLE)
	draw_circle(pos + Vector2(radius * 0.18, radius * 0.22), radius * 0.08, DARK_MINT)
	if int(g.hp) < spec.hp:
		draw_arc(pos, radius + 4.0, -PI * 0.5, -PI * 0.5 + TAU * float(g.hp) / float(spec.hp), 24, ORANGE_HOT, 3.0, true)


func _draw_debris(pos: Vector2, angle: float) -> void:
	var pts := PackedVector2Array([
		pos + Vector2(-10.0, -6.0).rotated(angle),
		pos + Vector2(9.0, -9.0).rotated(angle),
		pos + Vector2(6.0, 8.0).rotated(angle),
		pos + Vector2(-7.0, 11.0).rotated(angle),
	])
	draw_colored_polygon(pts, PURPLE_SOFT)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), PURPLE, 2.0, true)


func _draw_player(offset: Vector2) -> void:
	var pos := player_pos + offset
	if boost_active:
		var tail_dir := Vector2.LEFT.rotated(player_facing)
		draw_line(pos + tail_dir * 12.0, pos + tail_dir * 44.0, Color(LIME.r, LIME.g, LIME.b, 0.7), 8.0, true)
	if spawn_protection_left > 0.0:
		draw_arc(pos, PLAYER_RADIUS + 10.0, 0.0, TAU, 40, Color(0.333, 0.867, 0.878, 0.55), 3.0, true)
	var forward := Vector2.RIGHT.rotated(player_facing)
	var side := forward.orthogonal()
	var shape := PackedVector2Array([pos + forward * 24.0, pos - forward * 15.0 + side * 13.0, pos - forward * 11.0, pos - forward * 15.0 - side * 13.0])
	draw_colored_polygon(shape, ORANGE)
	draw_polyline(PackedVector2Array([shape[0], shape[1], shape[2], shape[3], shape[0]]), ORANGE_HOT, 2.5, true)
	draw_circle(pos, 5.0, WHITE)


func _draw_reticle(pos: Vector2) -> void:
	var color := Color(0.439, 0.627, 0.592, 0.9)
	draw_arc(pos, 12.0, 0.0, TAU, 24, color, 2.0, true)
	draw_line(pos + Vector2(-20, 0), pos + Vector2(-8, 0), color, 2.0)
	draw_line(pos + Vector2(8, 0), pos + Vector2(20, 0), color, 2.0)
	draw_line(pos + Vector2(0, -20), pos + Vector2(0, -8), color, 2.0)
	draw_line(pos + Vector2(0, 8), pos + Vector2(0, 20), color, 2.0)


func _draw_hud() -> void:
	_draw_gameplay_logo()
	_draw_responsive_hud()


func _hud_unit() -> float:
	return minf(viewport_size.y, viewport_size.x * 0.62)


func _hud_top_safe_area() -> float:
	return 76.0 if css_viewport_width < 1024.0 else 0.0


func _gameplay_logo_rect() -> Rect2:
	var visual_unit := _hud_unit()
	var logo_width := clampf(minf(viewport_size.x * 0.22, visual_unit * 0.46), 110.0, 500.0)
	var logo_height := logo_width * float(logo_texture.get_height()) / float(logo_texture.get_width())
	var inset := maxf(18.0, visual_unit * 0.075)
	return Rect2(Vector2(inset, inset + _hud_top_safe_area()), Vector2(logo_width, logo_height))


func _draw_gameplay_logo() -> void:
	draw_texture_rect(logo_texture, _gameplay_logo_rect(), false)


func _draw_responsive_hud() -> void:
	var visual_unit := _hud_unit()
	var top_safe := _hud_top_safe_area()
	var label_size := roundi(clampf(visual_unit * 0.063, 20.0, 76.0))
	var value_size := roundi(clampf(visual_unit * 0.125, 42.0, 178.0))
	var time_value_size := roundi(clampf(visual_unit * 0.14, 40.0, 132.0))
	var outline_size := maxi(2, roundi(visual_unit * 0.011))
	var shadow_offset := Vector2.ONE * maxf(3.0, visual_unit * 0.013)

	_draw_mock_stat(
		"SCORE",
		str(score),
		Vector2(viewport_size.x - visual_unit * 0.09, top_safe + visual_unit * 0.145),
		-0.18,
		label_size,
		value_size,
		true,
		outline_size,
		shadow_offset
	)
	_draw_mock_stat(
		"TIME",
		_format_time_precise(run_time),
		Vector2(visual_unit * 0.075, viewport_size.y - visual_unit * 0.28),
		-0.10,
		label_size,
		time_value_size,
		false,
		outline_size,
		shadow_offset
	)
	if combo > 1:
		_draw_text_with_outline(
			"%dx COMBO" % combo,
			Vector2(viewport_size.x - visual_unit * 0.37, top_safe + visual_unit * 0.34),
			maxi(20, label_size / 2),
			PURPLE,
			WHITE,
			maxi(2, outline_size / 2),
			Vector2(4.0, 4.0),
			DARK_MINT
		)
	_draw_responsive_boost(visual_unit, label_size, outline_size, shadow_offset)


func _draw_mock_stat(label: String, value: String, origin: Vector2, rotation: float, label_size: int, value_size: int, align_right: bool, outline_size: int, shadow_offset: Vector2) -> void:
	draw_set_transform(origin, rotation, Vector2.ONE)
	var label_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, label_size).x
	var value_width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, value_size).x
	_draw_text_with_outline(label, Vector2(-label_width if align_right else 0.0, 0.0), label_size, DARK_MINT, WHITE, outline_size, shadow_offset, DARK_MINT)
	_draw_text_with_outline(value, Vector2(-value_width if align_right else 0.0, value_size * 0.91), value_size, DARK_MINT, WHITE, outline_size, shadow_offset, DARK_MINT)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_responsive_boost(visual_unit: float, label_size: int, outline_size: int, shadow_offset: Vector2) -> void:
	var rotation := 0.20
	var origin := Vector2(viewport_size.x - visual_unit * 0.07, viewport_size.y - visual_unit * 0.32)
	var meter_width := clampf(visual_unit * 0.48, 160.0, 500.0)
	var meter_height := clampf(visual_unit * 0.105, 36.0, 106.0)
	draw_set_transform(origin, rotation, Vector2.ONE)
	var label_width := font.get_string_size("BOOST", HORIZONTAL_ALIGNMENT_LEFT, -1.0, label_size).x
	_draw_text_with_outline("BOOST", Vector2(-label_width, 0.0), label_size, DARK_MINT, WHITE, outline_size, shadow_offset, DARK_MINT)
	var meter := Rect2(Vector2(-meter_width, meter_height * 0.34), Vector2(meter_width, meter_height))
	_draw_pill(meter.grow(8.0), Color(WHITE.r, WHITE.g, WHITE.b, 0.28), Color.TRANSPARENT, 0.0)
	_draw_pill(meter, Color(WHITE.r, WHITE.g, WHITE.b, 0.48), Color.TRANSPARENT, 0.0)
	var charge_rect := meter.grow(-6.0)
	charge_rect.size.x *= boost_charge
	if charge_rect.size.x > charge_rect.size.y:
		_draw_pill(charge_rect, Color(LIME.r, LIME.g, LIME.b, 0.52), Color.TRANSPARENT, 0.0)
	var space_size := roundi(meter_height * 0.58)
	var space_text := "SPACE"
	var space_width := font.get_string_size(space_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, space_size).x
	_draw_text_with_outline(space_text, Vector2(meter.get_center().x - space_width * 0.5, meter.get_center().y + space_size * 0.34), space_size, WHITE, Color(WHITE.r, WHITE.g, WHITE.b, 0.01), 1, Vector2(5.0, 5.0), Color(DARK_MINT.r, DARK_MINT.g, DARK_MINT.b, 0.62))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_menu() -> void:
	_draw_text_centered("PETRI", Vector2(viewport_size.x * 0.5, viewport_size.y * 0.25), int(clampf(viewport_size.y * 0.18, 92.0, 168.0)), DARK_MINT)
	_draw_text_centered("ANTIBIOTIC SURVIVAL", Vector2(viewport_size.x * 0.5, viewport_size.y * 0.31), 18, ACCENT_MINT)
	var labels := ["START RUN", "HOW TO PLAY", "SETTINGS"]
	for i in labels.size(): _draw_action_button(_menu_button_rect(i), labels[i], i == 0)
	_draw_text_centered("WASD  MOVE     MOUSE  AIM     LEFT CLICK  FIRE     SPACE  BOOST", Vector2(viewport_size.x * 0.5, viewport_size.y - 42.0), 15, DARK_MINT)


func _draw_how_to() -> void:
	_draw_text_centered("HOW TO PLAY", Vector2(viewport_size.x * 0.5, 92.0), 58, DARK_MINT)
	var panel := Rect2(Vector2(viewport_size.x * 0.5 - minf(470.0, viewport_size.x * 0.42), 142.0), Vector2(minf(940.0, viewport_size.x * 0.84), viewport_size.y - 262.0))
	_draw_pill(panel, Color(1,1,1,0.88), MINT, 3.0)
	var rows := [
		["W A S D", "Apply force. Momentum carries you through the dish."],
		["MOUSE", "Aim the antibiotic particle."],
		["LEFT CLICK", "Fire pellets — up to six per second."],
		["SPACE", "Hold to boost. The charge drains, pauses, then recharges."],
		["ESC", "Pause. Losing browser focus pauses automatically."],
	]
	for i in rows.size():
		var y := panel.position.y + 66.0 + i * 66.0
		_draw_text(str(rows[i][0]), Vector2(panel.position.x + 42.0, y), 22, PURPLE)
		_draw_text(str(rows[i][1]), Vector2(panel.position.x + 230.0, y), 17, DARK_MINT)
	_draw_text_centered("Any germ or debris contact ends the run after 1.5 seconds of spawn protection.", Vector2(viewport_size.x * 0.5, panel.end.y - 36.0), 16, ORANGE_HOT)
	_draw_action_button(_single_button_rect(), "BACK", false)


func _draw_pause() -> void:
	_draw_overlay_scrim()
	_draw_text_centered("PAUSED", Vector2(viewport_size.x * 0.5, viewport_size.y * 0.28), 68, WHITE)
	var labels := ["RESUME", "SETTINGS", "MAIN MENU"]
	for i in labels.size(): _draw_action_button(_overlay_button_rect(i, labels.size()), labels[i], i == 0)


func _draw_game_over() -> void:
	_draw_overlay_scrim()
	_draw_text_centered("CULTURE LOST", Vector2(viewport_size.x * 0.5, viewport_size.y * 0.2), 56, WHITE)
	_draw_text_centered(death_reason.to_upper(), Vector2(viewport_size.x * 0.5, viewport_size.y * 0.26), 17, LIME)
	var y := viewport_size.y * 0.36
	_draw_text_centered("SCORE  %07d" % score, Vector2(viewport_size.x * 0.5, y), 35, WHITE)
	_draw_text_centered("TIME  %s" % _format_time(run_time), Vector2(viewport_size.x * 0.5, y + 48.0), 28, WHITE)
	_draw_text_centered("BEST  %07d   /   %s" % [int(saved.best_score), _format_time(float(saved.best_time))], Vector2(viewport_size.x * 0.5, y + 88.0), 18, MINT)
	var labels := ["RETRY  R", "MAIN MENU"]
	for i in labels.size(): _draw_action_button(_overlay_button_rect(i, labels.size()), labels[i], i == 0)


func _draw_settings() -> void:
	_draw_text_centered("SETTINGS", Vector2(viewport_size.x * 0.5, 92.0), 58, DARK_MINT)
	var labels := ["SFX VOLUME", "AMBIENT HUM", "FULLSCREEN", "REDUCED MOTION"]
	var values := ["%d%%" % roundi(float(saved.sfx_volume) * 100.0), "%d%%" % roundi(float(saved.music_volume) * 100.0), "ON" if bool(saved.fullscreen) else "OFF", "ON" if bool(saved.reduced_motion) else "OFF"]
	for i in labels.size():
		var rect := _settings_row_rect(i)
		_draw_pill(rect, WHITE, MINT, 2.0)
		_draw_text(labels[i], rect.position + Vector2(28.0, 42.0), 20, DARK_MINT)
		_draw_text_right(values[i], Vector2(rect.end.x - 28.0, rect.position.y + 42.0), 22, PURPLE)
	_draw_action_button(_single_button_rect(), "BACK", false)


func _draw_overlay_scrim() -> void:
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.274, 0.5, 0.46, 0.88))


func _draw_desktop_recommendation() -> void:
	var rect := Rect2(Vector2(16.0, 12.0), Vector2(viewport_size.x - 32.0, 58.0))
	_draw_pill(rect, PURPLE, Color.TRANSPARENT, 0.0)
	_draw_text_centered("KEYBOARD + MOUSE RECOMMENDED  •  USE A 1024PX+ DESKTOP WINDOW", rect.get_center() + Vector2(0, 6), 14, WHITE)


func _menu_button_rect(index: int) -> Rect2:
	var width := minf(520.0, viewport_size.x * 0.72)
	return Rect2(Vector2(viewport_size.x * 0.5 - width * 0.5, viewport_size.y * 0.43 + index * 78.0), Vector2(width, 58.0))


func _overlay_button_rect(index: int, count: int) -> Rect2:
	var width := minf(420.0, viewport_size.x * 0.68)
	var start_y := viewport_size.y * (0.55 if count == 3 else 0.64)
	return Rect2(Vector2(viewport_size.x * 0.5 - width * 0.5, start_y + index * 70.0), Vector2(width, 52.0))


func _settings_row_rect(index: int) -> Rect2:
	var width := minf(720.0, viewport_size.x * 0.84)
	return Rect2(Vector2(viewport_size.x * 0.5 - width * 0.5, 150.0 + index * 82.0), Vector2(width, 62.0))


func _single_button_rect() -> Rect2:
	var width := minf(360.0, viewport_size.x * 0.6)
	return Rect2(Vector2(viewport_size.x * 0.5 - width * 0.5, viewport_size.y - 86.0), Vector2(width, 50.0))


func _draw_action_button(rect: Rect2, label: String, primary: bool) -> void:
	var fill := DARK_MINT if primary else WHITE
	var text_color := WHITE if primary else DARK_MINT
	var cut := 18.0
	var pts := PackedVector2Array([rect.position + Vector2(cut, 0), rect.position + Vector2(rect.size.x, 0), rect.end - Vector2(cut, 0), rect.position + Vector2(0, rect.size.y)])
	draw_colored_polygon(pts, fill)
	draw_polyline(PackedVector2Array([pts[0],pts[1],pts[2],pts[3],pts[0]]), MINT if not primary else ACCENT_MINT, 2.0, true)
	_draw_text_centered(label, rect.get_center() + Vector2(0, 9), 25, text_color)


func _draw_pill(rect: Rect2, fill: Color, stroke: Color, stroke_width: float) -> void:
	var radius := rect.size.y * 0.5
	draw_rect(Rect2(rect.position + Vector2(radius, 0), Vector2(maxf(0.0, rect.size.x - radius * 2.0), rect.size.y)), fill)
	draw_circle(rect.position + Vector2(radius, radius), radius, fill)
	draw_circle(rect.position + Vector2(rect.size.x - radius, radius), radius, fill)
	if stroke_width > 0.0 and stroke.a > 0.0:
		draw_line(rect.position + Vector2(radius, 0), rect.position + Vector2(rect.size.x - radius, 0), stroke, stroke_width, true)
		draw_line(rect.position + Vector2(radius, rect.size.y), rect.position + Vector2(rect.size.x - radius, rect.size.y), stroke, stroke_width, true)
		draw_arc(rect.position + Vector2(radius, radius), radius, PI * 0.5, PI * 1.5, 20, stroke, stroke_width, true)
		draw_arc(rect.position + Vector2(rect.size.x - radius, radius), radius, -PI * 0.5, PI * 0.5, 20, stroke, stroke_width, true)


func _draw_text(text: String, at: Vector2, size: int, color: Color) -> void:
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


func _draw_text_right(text: String, at: Vector2, size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	draw_string(font, at - Vector2(width, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


func _draw_text_centered(text: String, at: Vector2, size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	draw_string(font, at - Vector2(width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


func _draw_text_with_outline(text: String, at: Vector2, size: int, fill: Color, outline: Color, outline_size: int, shadow_offset: Vector2, shadow: Color) -> void:
	draw_string_outline(font, at + shadow_offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, outline_size + 2, shadow)
	draw_string(font, at + shadow_offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, shadow)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, outline_size, outline)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, fill)


func _format_time(seconds: float) -> String:
	var total := maxi(0, int(floor(seconds)))
	return "%02d:%02d" % [total / 60, total % 60]


func _format_time_precise(seconds: float) -> String:
	var safe_seconds := maxf(0.0, seconds)
	var total := int(floor(safe_seconds))
	var centiseconds := mini(99, int(floor(fmod(safe_seconds, 1.0) * 100.0)))
	return "%d:%02d.%02d" % [total / 60, total % 60, centiseconds]
