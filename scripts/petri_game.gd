extends Node2D

signal run_time_changed(seconds: float)
signal score_changed(score: int)
signal combo_changed(multiplier: int)
signal boost_charge_changed(charge: float)
signal pause_state_changed(paused: bool)
signal game_over(score: int, survival_time: float, reason: String)
signal item_warning_started(item_type: int, position: Vector2)
signal item_collected(item_type: int, level: int)
signal item_overcharge_changed(item_type: int, seconds_left: float)

enum AppState { MENU, HOW_TO, PLAYING, PAUSED, SETTINGS, GAME_OVER }
enum ProjectileOwner { PLAYER, TURRET }

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
const PELLET_SPEED := 520.0
const PELLET_LIFETIME := 1.25
const SPAWN_PROTECTION := 1.5
const DEBRIS_LIFETIME := 12.0
const PELLET_POOL_SIZE := 240
const TURRET_POOL_SIZE := 3
const MINE_POOL_SIZE := 48
const PICKUP_POOL_SIZE := 4
const EFFECT_FLASH_POOL_SIZE := 24
const ARENA_SCALE := 1.3225
const GERM_SPAWN_TELEGRAPH_SECONDS := 1.02
const ITEM_SPAWN_TELEGRAPH_SECONDS := 0.85
const ITEM_PICKUP_LIFETIME := 15.0
const ITEM_PICKUP_RADIUS := 18.0
const HITTER_ORBIT_RADIUS := 58.0
const HITTER_ANGULAR_SPEED := 2.8
const HITTER_HIT_COOLDOWN := 0.35
const AOE_WARNING_SECONDS := 0.6
const TURRET_BULLET_SPEED := 480.0
const TURRET_BULLET_LIFETIME := 1.5
const MINE_ARM_SECONDS := 0.25
const MINE_LIFETIME := 8.0
const MINE_TRIGGER_RADIUS := 30.0
const ANTIBODY_PROTECTION_SECONDS := 0.75
const ANTIBODY_REPEL_SPEED := 220.0

var font: Font = preload("res://Excelorate-Font.otf")
var logo_texture: Texture2D = preload("res://assets/figma/petri-logo.png")
var germ_specs: Array[GermData] = [
	preload("res://data/germ_large.tres"),
	preload("res://data/germ_medium.tres"),
	preload("res://data/germ_small.tres"),
	preload("res://data/germ_elite.tres"),
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
var elite_timer := GameMath.ELITE_FIRST_SPAWN
var death_reason := ""
var screen_shake := 0.0
var hitter_angle := 0.0
var aoe_timer := INF
var aoe_warning_active := false
var aoe_flash_left := 0.0
var mine_timer := INF
var overcharge_item := -1
var overcharge_left := 0.0
var antibody_cooldown := 0.0

var pellets: Array[Dictionary] = []
var germs: Array[Dictionary] = []
var debris: Array[Dictionary] = []
var spawn_warnings: Array[Dictionary] = []
var item_warnings: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var turrets: Array[Dictionary] = []
var mines: Array[Dictionary] = []
var effect_flashes: Array[Dictionary] = []
var item_levels: Array[int] = []
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
		pellets.append({
			"active": false,
			"pos": Vector2.ZERO,
			"vel": Vector2.ZERO,
			"life": 0.0,
			"bounces": 0,
			"owner": ProjectileOwner.PLAYER,
			"pierces": 0,
			"hit_germs": 0,
			"hit_debris_low": 0,
			"hit_debris_high": 0,
			"seek_target": -1,
		})
	for i in GameMath.MAX_GERMS:
		germs.append({"active": false, "tier": GermData.GermTier.LARGE, "pos": Vector2.ZERO, "vel": Vector2.ZERO, "hp": 0, "phase": 0.0, "hitter_cooldown": 0.0})
	for i in GameMath.MAX_FRAGMENTS:
		debris.append({"active": false, "pos": Vector2.ZERO, "vel": Vector2.ZERO, "life": 0.0, "angle": 0.0, "spin": 0.0, "hitter_cooldown": 0.0})
	for i in TURRET_POOL_SIZE:
		turrets.append({"active": false, "pos": Vector2.ZERO, "cooldown": 0.0, "angle": 0.0})
	for i in MINE_POOL_SIZE:
		mines.append({"active": false, "pos": Vector2.ZERO, "life": 0.0, "arm": 0.0, "phase": 0.0, "blast_radius": 55.0})
	for i in PICKUP_POOL_SIZE:
		item_warnings.append({"active": false, "item_type": 0, "pos": Vector2.ZERO, "life": 0.0, "duration": ITEM_SPAWN_TELEGRAPH_SECONDS, "overcharge": false})
		pickups.append({"active": false, "item_type": 0, "pos": Vector2.ZERO, "life": 0.0, "phase": 0.0, "overcharge": false})
	for i in EFFECT_FLASH_POOL_SIZE:
		effect_flashes.append({"active": false, "pos": Vector2.ZERO, "radius": 0.0, "life": 0.0, "duration": 0.0, "color": Color.WHITE})
	for i in ItemData.ItemType.size():
		item_levels.append(0)


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
	_update_overcharge(delta)
	_update_antibody_shell(delta)
	_update_effect_flashes(delta)
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
	_update_item_warnings(delta)
	_update_pickups(delta)
	_update_germs(delta)
	_update_debris(delta)
	_update_turrets(delta)
	_update_mines(delta)
	_update_spinning_hitters(delta)
	_update_aoe(delta)
	_resolve_projectile_hits()
	_resolve_hostile_hits()

	if combo > 1 and run_time - last_kill_time > 2.0:
		combo = 1
		emit_signal("combo_changed", combo)

	spawn_timer -= delta
	if spawn_timer <= 0.0 and _active_regular_germ_count() + _pending_regular_germ_count() < GameMath.active_germ_cap(run_time):
		_queue_spawn_warning(_weighted_spawn_tier())
		spawn_timer = GameMath.spawn_interval(run_time)

	elite_timer -= delta
	if elite_timer <= 0.0 and not _elite_exists():
		_queue_spawn_warning(GermData.GermTier.ELITE)
		elite_timer = GameMath.ELITE_SPAWN_INTERVAL
		audio.play_sfx("elite_spawn")


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
	var spread_level := _effective_item_level(ItemData.ItemType.SPREAD)
	var ricochet_level := _effective_item_level(ItemData.ItemType.RICOCHET)
	var catalyst_level := _effective_item_level(ItemData.ItemType.CATALYST)
	var angles := ItemData.spread_angles(spread_level)
	var center_direction := Vector2.RIGHT.rotated(player_facing)
	var center_spawned := _spawn_projectile(
		player_pos + center_direction * (PLAYER_RADIUS + 11.0),
		center_direction,
		PELLET_SPEED,
		ItemData.ricochet_lifetime(ricochet_level),
		ItemData.ricochet_bounces(ricochet_level),
		ProjectileOwner.PLAYER,
		player_velocity * 0.22
	)
	if not center_spawned:
		return
	for i in range(1, angles.size()):
		var direction := Vector2.RIGHT.rotated(player_facing + float(angles[i]))
		_spawn_projectile(
			player_pos + direction * (PLAYER_RADIUS + 11.0),
			direction,
			PELLET_SPEED,
			ItemData.ricochet_lifetime(ricochet_level),
			ItemData.ricochet_bounces(ricochet_level),
			ProjectileOwner.PLAYER,
			player_velocity * 0.22
		)
	fire_cooldown = ItemData.catalyst_fire_interval(catalyst_level)
	audio.play_sfx("fire")


func _spawn_projectile(at: Vector2, direction: Vector2, speed: float, life: float, bounces: int, owner: int, inherited_velocity: Vector2 = Vector2.ZERO) -> bool:
	for i in pellets.size():
		if bool(pellets[i].active):
			continue
		var piercing_level := _effective_item_level(ItemData.ItemType.PIERCING_DOSE) if owner == ProjectileOwner.PLAYER else 0
		var seeking_level := _effective_item_level(ItemData.ItemType.SEEKING_ENZYME) if owner == ProjectileOwner.PLAYER else 0
		pellets[i] = {
			"active": true,
			"pos": at,
			"vel": direction.normalized() * speed + inherited_velocity,
			"life": life,
			"bounces": bounces,
			"owner": owner,
			"pierces": ItemData.piercing_targets(piercing_level),
			"hit_germs": 0,
			"hit_debris_low": 0,
			"hit_debris_high": 0,
			"seek_target": _nearest_germ_index(at, ItemData.seeking_range(seeking_level)) if seeking_level > 0 else -1,
		}
		return true
	return false


func _update_pellets(delta: float) -> void:
	var seeking_level := _effective_item_level(ItemData.ItemType.SEEKING_ENZYME)
	for i in pellets.size():
		if not bool(pellets[i].active):
			continue
		var p := pellets[i]
		if int(p.owner) == ProjectileOwner.PLAYER and seeking_level > 0:
			_update_seeking_projectile(p, seeking_level, delta)
		p.pos += p.vel * delta
		p.life = float(p.life) - delta
		var edge := Vector2(p.pos) - arena_center
		if edge.length() + 5.0 > arena_radius:
			if int(p.bounces) > 0:
				var normal := edge.normalized()
				p.pos = arena_center + normal * (arena_radius - 5.0)
				p.vel = Vector2(p.vel).bounce(normal)
				p.bounces = int(p.bounces) - 1
			else:
				p.active = false
		if float(p.life) <= 0.0:
			p.active = false
		pellets[i] = p


func _update_seeking_projectile(projectile: Dictionary, level: int, delta: float) -> void:
	var target_index := int(projectile.seek_target)
	if target_index < 0 or target_index >= germs.size() or not bool(germs[target_index].active):
		target_index = _nearest_germ_index(Vector2(projectile.pos), ItemData.seeking_range(level))
		projectile.seek_target = target_index
	if target_index < 0:
		return
	var velocity := Vector2(projectile.vel)
	var toward_target := Vector2(germs[target_index].pos) - Vector2(projectile.pos)
	if velocity.length_squared() <= 0.001 or toward_target.length_squared() <= 0.001:
		return
	var angle_delta := wrapf(toward_target.angle() - velocity.angle(), -PI, PI)
	var maximum_turn := ItemData.seeking_turn_speed(level) * delta
	projectile.vel = velocity.rotated(clampf(angle_delta, -maximum_turn, maximum_turn))


func _update_germs(delta: float) -> void:
	var speed_mult := GameMath.threat_speed_multiplier(run_time)
	var inhibitor_level := _effective_item_level(ItemData.ItemType.INHIBITOR_FIELD)
	var inhibitor_radius_squared := pow(ItemData.inhibitor_radius(inhibitor_level), 2.0)
	var inhibitor_speed_mult := ItemData.inhibitor_speed_multiplier(inhibitor_level)
	for i in germs.size():
		if not bool(germs[i].active):
			continue
		var g := germs[i]
		g.hitter_cooldown = maxf(0.0, float(g.hitter_cooldown) - delta)
		var target_dir := (player_pos - Vector2(g.pos)).normalized()
		var current_speed := Vector2(g.vel).length()
		var wanted := target_dir * current_speed
		g.vel = Vector2(g.vel).lerp(wanted, minf(1.0, delta * 0.18))
		var local_speed_mult := inhibitor_speed_mult if inhibitor_level > 0 and player_pos.distance_squared_to(Vector2(g.pos)) <= inhibitor_radius_squared else 1.0
		g.pos += Vector2(g.vel) * speed_mult * local_speed_mult * delta
		g.phase = float(g.phase) + delta
		var spec := germ_specs[int(g.tier)]
		var edge := Vector2(g.pos) - arena_center
		if edge.length() + spec.radius > arena_radius:
			var normal := edge.normalized()
			g.pos = arena_center + normal * (arena_radius - spec.radius)
			g.vel = Vector2(g.vel).bounce(normal)
		germs[i] = g


func _update_debris(delta: float) -> void:
	var inhibitor_level := _effective_item_level(ItemData.ItemType.INHIBITOR_FIELD)
	var inhibitor_radius_squared := pow(ItemData.inhibitor_radius(inhibitor_level), 2.0)
	var inhibitor_speed_mult := ItemData.inhibitor_speed_multiplier(inhibitor_level)
	for i in debris.size():
		if not bool(debris[i].active):
			continue
		var d := debris[i]
		d.hitter_cooldown = maxf(0.0, float(d.hitter_cooldown) - delta)
		var local_speed_mult := inhibitor_speed_mult if inhibitor_level > 0 and player_pos.distance_squared_to(Vector2(d.pos)) <= inhibitor_radius_squared else 1.0
		d.pos += Vector2(d.vel) * local_speed_mult * delta
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
		var projectile := pellets[pi]
		var pellet_pos := Vector2(projectile.pos)
		for gi in germs.size():
			if not bool(germs[gi].active):
				continue
			var germ_bit := 1 << gi
			if (int(projectile.hit_germs) & germ_bit) != 0:
				continue
			var spec := germ_specs[int(germs[gi].tier)]
			if pellet_pos.distance_squared_to(Vector2(germs[gi].pos)) <= pow(spec.radius + 5.0, 2.0):
				projectile.hit_germs = int(projectile.hit_germs) | germ_bit
				_damage_germ(gi, 1)
				if int(projectile.pierces) > 0:
					projectile.pierces = int(projectile.pierces) - 1
				else:
					projectile.active = false
					break
		if not bool(projectile.active):
			pellets[pi] = projectile
			continue
		for di in debris.size():
			if not bool(debris[di].active):
				continue
			var debris_bit_index := di if di < 40 else di - 40
			var debris_bit := 1 << debris_bit_index
			var debris_mask := int(projectile.hit_debris_low) if di < 40 else int(projectile.hit_debris_high)
			if (debris_mask & debris_bit) != 0:
				continue
			if pellet_pos.distance_squared_to(Vector2(debris[di].pos)) <= 225.0:
				if di < 40:
					projectile.hit_debris_low = debris_mask | debris_bit
				else:
					projectile.hit_debris_high = debris_mask | debris_bit
				_destroy_debris(di, int(projectile.owner) == ProjectileOwner.PLAYER)
				if int(projectile.pierces) > 0:
					projectile.pierces = int(projectile.pierces) - 1
				else:
					projectile.active = false
					break
		pellets[pi] = projectile


func _damage_germ(index: int, amount: int) -> bool:
	if index < 0 or index >= germs.size() or not bool(germs[index].active):
		return false
	germs[index].hp = int(germs[index].hp) - amount
	if int(germs[index].hp) <= 0:
		_destroy_germ(index)
	else:
		audio.play_sfx("impact")
	return true


func _destroy_debris(index: int, trigger_cleanup: bool = false) -> bool:
	if index < 0 or index >= debris.size() or not bool(debris[index].active):
		return false
	var at := Vector2(debris[index].pos)
	debris[index].active = false
	_award_kill(10, at)
	var cleanup_level := _effective_item_level(ItemData.ItemType.CATALYTIC_CLEANUP)
	if trigger_cleanup and cleanup_level > 0:
		_damage_germs_only(at, ItemData.cleanup_radius(cleanup_level), ItemData.cleanup_damage(cleanup_level))
		_spawn_effect_flash(at, ItemData.cleanup_radius(cleanup_level), ItemData.color(ItemData.ItemType.CATALYTIC_CLEANUP))
	return true


func _damage_germs_only(at: Vector2, radius: float, amount: int) -> void:
	var targets: Array[int] = []
	for i in germs.size():
		if not bool(germs[i].active):
			continue
		var spec := germ_specs[int(germs[i].tier)]
		if at.distance_squared_to(Vector2(germs[i].pos)) <= pow(radius + spec.radius * 0.5, 2.0):
			targets.append(i)
	for index in targets:
		_damage_germ(index, amount)


func _damage_area(at: Vector2, radius: float, amount: int) -> void:
	var germ_targets: Array[int] = []
	var debris_targets: Array[int] = []
	for i in germs.size():
		if not bool(germs[i].active):
			continue
		var spec := germ_specs[int(germs[i].tier)]
		if at.distance_squared_to(Vector2(germs[i].pos)) <= pow(radius + spec.radius * 0.5, 2.0):
			germ_targets.append(i)
	for i in debris.size():
		if bool(debris[i].active) and at.distance_squared_to(Vector2(debris[i].pos)) <= pow(radius + 8.0, 2.0):
			debris_targets.append(i)
	for index in germ_targets:
		_damage_germ(index, amount)
	for index in debris_targets:
		_destroy_debris(index)


func _update_spinning_hitters(delta: float) -> void:
	var level := _effective_item_level(ItemData.ItemType.SPINNING_HITTER)
	var count := ItemData.hitter_count(level)
	if count <= 0:
		return
	hitter_angle = fmod(hitter_angle + HITTER_ANGULAR_SPEED * delta, TAU)
	for hitter in count:
		var angle := hitter_angle + TAU * float(hitter) / float(count)
		var hitter_pos := player_pos + Vector2.RIGHT.rotated(angle) * HITTER_ORBIT_RADIUS
		for gi in germs.size():
			if not bool(germs[gi].active) or float(germs[gi].hitter_cooldown) > 0.0:
				continue
			var spec := germ_specs[int(germs[gi].tier)]
			if hitter_pos.distance_squared_to(Vector2(germs[gi].pos)) <= pow(spec.radius + 10.0, 2.0):
				germs[gi].hitter_cooldown = HITTER_HIT_COOLDOWN
				_damage_germ(gi, 1)
		for di in debris.size():
			if not bool(debris[di].active) or float(debris[di].hitter_cooldown) > 0.0:
				continue
			if hitter_pos.distance_squared_to(Vector2(debris[di].pos)) <= 324.0:
				debris[di].hitter_cooldown = HITTER_HIT_COOLDOWN
				_destroy_debris(di)


func _deploy_turret(at: Vector2) -> bool:
	for i in turrets.size():
		if bool(turrets[i].active):
			continue
		turrets[i] = {"active": true, "pos": _clamp_pickup_position(at), "cooldown": 0.0, "angle": player_facing}
		return true
	return false


func _update_turrets(delta: float) -> void:
	var level := _effective_item_level(ItemData.ItemType.TURRET)
	if level <= 0:
		return
	var fire_interval := ItemData.turret_interval(level)
	var target_range := ItemData.turret_range(level)
	for i in turrets.size():
		if not bool(turrets[i].active):
			continue
		var turret := turrets[i]
		turret.cooldown = maxf(0.0, float(turret.cooldown) - delta)
		var target: Variant = _nearest_hostile_position(Vector2(turret.pos), target_range)
		if target != null:
			var direction := (Vector2(target) - Vector2(turret.pos)).normalized()
			turret.angle = direction.angle()
			if float(turret.cooldown) <= 0.0:
				if _spawn_projectile(Vector2(turret.pos) + direction * 16.0, direction, TURRET_BULLET_SPEED, TURRET_BULLET_LIFETIME, 0, ProjectileOwner.TURRET):
					turret.cooldown = fire_interval
					audio.play_sfx("turret")
				else:
					turret.cooldown = 0.1
		turrets[i] = turret


func _nearest_hostile_position(from: Vector2, maximum_range: float) -> Variant:
	var best_distance := maximum_range * maximum_range
	var best_position: Variant = null
	for g in germs:
		if not bool(g.active):
			continue
		var distance := from.distance_squared_to(Vector2(g.pos))
		if distance < best_distance:
			best_distance = distance
			best_position = Vector2(g.pos)
	for d in debris:
		if not bool(d.active):
			continue
		var distance := from.distance_squared_to(Vector2(d.pos))
		if distance < best_distance:
			best_distance = distance
			best_position = Vector2(d.pos)
	return best_position


func _nearest_germ_index(from: Vector2, maximum_range: float) -> int:
	var best_distance := maximum_range * maximum_range
	var best_index := -1
	for i in germs.size():
		if not bool(germs[i].active):
			continue
		var distance := from.distance_squared_to(Vector2(germs[i].pos))
		if distance < best_distance:
			best_distance = distance
			best_index = i
	return best_index


func _update_mines(delta: float) -> void:
	var level := _effective_item_level(ItemData.ItemType.LEAVE_BEHIND)
	if level > 0 and player_velocity.length() > 30.0:
		mine_timer -= delta
		if mine_timer <= 0.0:
			_spawn_mine(level)
			mine_timer += ItemData.mine_interval(level)
	for i in mines.size():
		if not bool(mines[i].active):
			continue
		var mine := mines[i]
		mine.life = float(mine.life) - delta
		mine.arm = maxf(0.0, float(mine.arm) - delta)
		mine.phase = float(mine.phase) + delta
		if float(mine.life) <= 0.0:
			mine.active = false
		elif float(mine.arm) <= 0.0 and _hostile_within(Vector2(mine.pos), MINE_TRIGGER_RADIUS):
			mine.active = false
			_damage_area(Vector2(mine.pos), float(mine.blast_radius), 1)
			audio.play_sfx("mine")
		mines[i] = mine


func _spawn_mine(level: int) -> bool:
	var behind := Vector2.ZERO
	if player_velocity.length_squared() > 1.0:
		behind = -player_velocity.normalized() * (PLAYER_RADIUS + 8.0)
	for i in mines.size():
		if bool(mines[i].active):
			continue
		mines[i] = {
			"active": true,
			"pos": _clamp_pickup_position(player_pos + behind),
			"life": MINE_LIFETIME,
			"arm": MINE_ARM_SECONDS,
			"phase": 0.0,
			"blast_radius": ItemData.mine_blast_radius(level),
		}
		return true
	return false


func _hostile_within(at: Vector2, radius: float) -> bool:
	var radius_squared := radius * radius
	for g in germs:
		if bool(g.active) and at.distance_squared_to(Vector2(g.pos)) <= radius_squared:
			return true
	for d in debris:
		if bool(d.active) and at.distance_squared_to(Vector2(d.pos)) <= radius_squared:
			return true
	return false


func _update_aoe(delta: float) -> void:
	aoe_flash_left = maxf(0.0, aoe_flash_left - delta)
	var level := _effective_item_level(ItemData.ItemType.AOE)
	if level <= 0:
		aoe_warning_active = false
		return
	aoe_timer -= delta
	aoe_warning_active = aoe_timer <= AOE_WARNING_SECONDS
	if aoe_timer <= 0.0:
		_damage_area(player_pos, ItemData.aoe_radius(level), 1)
		aoe_timer = ItemData.aoe_interval(level)
		aoe_warning_active = false
		aoe_flash_left = 0.22
		audio.play_sfx("aoe")


func _resolve_hostile_hits() -> void:
	if not GameMath.hostile_collision_is_lethal(spawn_protection_left):
		return
	for g in germs:
		if not bool(g.active):
			continue
		var spec := germ_specs[int(g.tier)]
		if player_pos.distance_squared_to(Vector2(g.pos)) <= pow(PLAYER_RADIUS + spec.radius * 0.82, 2.0):
			if _trigger_antibody_shell():
				return
			_finish_run("Germ contact")
			return
	for d in debris:
		if bool(d.active) and player_pos.distance_squared_to(Vector2(d.pos)) <= pow(PLAYER_RADIUS + 8.0, 2.0):
			if _trigger_antibody_shell():
				return
			_finish_run("Debris contact")
			return


func _update_antibody_shell(delta: float) -> void:
	if _effective_item_level(ItemData.ItemType.ANTIBODY_SHELL) <= 0:
		antibody_cooldown = 0.0
		return
	antibody_cooldown = maxf(0.0, antibody_cooldown - delta)


func _trigger_antibody_shell() -> bool:
	var level := _effective_item_level(ItemData.ItemType.ANTIBODY_SHELL)
	if level <= 0 or antibody_cooldown > 0.0:
		return false
	antibody_cooldown = ItemData.antibody_recharge(level)
	spawn_protection_left = maxf(spawn_protection_left, ANTIBODY_PROTECTION_SECONDS)
	_repel_hostiles(ItemData.antibody_pulse_radius(level))
	_spawn_effect_flash(player_pos, ItemData.antibody_pulse_radius(level), ItemData.color(ItemData.ItemType.ANTIBODY_SHELL))
	popups.append({"pos": player_pos, "text": "SHELL BURST", "life": 1.0, "duration": 1.0, "item_type": ItemData.ItemType.ANTIBODY_SHELL})
	audio.play_sfx("impact")
	if not bool(saved.reduced_motion):
		screen_shake = maxf(screen_shake, 0.24)
	return true


func _repel_hostiles(radius: float) -> void:
	var radius_squared := radius * radius
	for i in germs.size():
		if not bool(germs[i].active) or player_pos.distance_squared_to(Vector2(germs[i].pos)) > radius_squared:
			continue
		var g := germs[i]
		var away := Vector2(g.pos) - player_pos
		if away.length_squared() <= 0.001:
			away = Vector2.RIGHT.rotated(player_facing + PI)
		away = away.normalized()
		g.pos = Vector2(g.pos) + away * 8.0
		g.vel = away * ANTIBODY_REPEL_SPEED
		var spec := germ_specs[int(g.tier)]
		var edge := Vector2(g.pos) - arena_center
		if edge.length() + spec.radius > arena_radius:
			g.pos = arena_center + edge.normalized() * (arena_radius - spec.radius)
		germs[i] = g
	for i in debris.size():
		if not bool(debris[i].active) or player_pos.distance_squared_to(Vector2(debris[i].pos)) > radius_squared:
			continue
		var d := debris[i]
		var away := Vector2(d.pos) - player_pos
		if away.length_squared() <= 0.001:
			away = Vector2.RIGHT.rotated(player_facing + PI)
		away = away.normalized()
		d.pos = Vector2(d.pos) + away * 8.0
		d.vel = away * ANTIBODY_REPEL_SPEED
		var edge := Vector2(d.pos) - arena_center
		if edge.length() + 10.0 > arena_radius:
			d.pos = arena_center + edge.normalized() * (arena_radius - 10.0)
		debris[i] = d


func _spawn_germ(tier: int, position_override: Variant = null) -> bool:
	var first_index := GameMath.MAX_REGULAR_GERMS if tier == GermData.GermTier.ELITE else 0
	var end_index := GameMath.MAX_GERMS if tier == GermData.GermTier.ELITE else GameMath.MAX_REGULAR_GERMS
	for i in range(first_index, end_index):
		if bool(germs[i].active):
			continue
		var spec := germ_specs[tier]
		var angle := rng.randf_range(0.0, TAU)
		var at := _spawn_position(tier, angle)
		if position_override != null:
			at = Vector2(position_override)
		var speed := rng.randf_range(spec.speed_min, spec.speed_max)
		var direction := (player_pos - at).normalized().rotated(rng.randf_range(-0.5, 0.5))
		germs[i] = {"active": true, "tier": tier, "pos": at, "vel": direction * speed, "hp": spec.hp, "phase": rng.randf_range(0.0, TAU), "hitter_cooldown": 0.0}
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
		"life": GERM_SPAWN_TELEGRAPH_SECONDS,
		"duration": GERM_SPAWN_TELEGRAPH_SECONDS,
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


func _queue_item_warning(at: Vector2) -> bool:
	var drop := _select_item_drop()
	var clamped_position := _clamp_pickup_position(at)
	for i in item_warnings.size():
		if bool(item_warnings[i].active):
			continue
		item_warnings[i] = {
			"active": true,
			"item_type": int(drop.item_type),
			"pos": clamped_position,
			"life": ITEM_SPAWN_TELEGRAPH_SECONDS,
			"duration": ITEM_SPAWN_TELEGRAPH_SECONDS,
			"overcharge": bool(drop.overcharge),
		}
		emit_signal("item_warning_started", int(drop.item_type), clamped_position)
		return true
	return false


func _select_item_drop() -> Dictionary:
	var candidates: Array[int] = []
	for item_type in ItemData.ItemType.size():
		if item_levels[item_type] < ItemData.MAX_LEVEL:
			candidates.append(item_type)
	if not candidates.is_empty():
		return {"item_type": candidates[rng.randi_range(0, candidates.size() - 1)], "overcharge": false}
	return {"item_type": rng.randi_range(0, ItemData.ItemType.size() - 1), "overcharge": true}


func _clamp_pickup_position(at: Vector2) -> Vector2:
	var from_center := at - arena_center
	var limit := arena_radius - ITEM_PICKUP_RADIUS - 12.0
	if from_center.length() <= limit:
		return at
	return arena_center + from_center.normalized() * limit


func _update_item_warnings(delta: float) -> void:
	for i in item_warnings.size():
		if not bool(item_warnings[i].active):
			continue
		var warning := item_warnings[i]
		warning.life = float(warning.life) - delta
		if float(warning.life) <= 0.0:
			_activate_pickup(int(warning.item_type), Vector2(warning.pos), bool(warning.overcharge))
			warning.active = false
		item_warnings[i] = warning


func _activate_pickup(item_type: int, at: Vector2, is_overcharge: bool) -> bool:
	for i in pickups.size():
		if bool(pickups[i].active):
			continue
		pickups[i] = {
			"active": true,
			"item_type": item_type,
			"pos": at,
			"life": ITEM_PICKUP_LIFETIME,
			"phase": 0.0,
			"overcharge": is_overcharge,
		}
		audio.play_sfx("item_appear")
		return true
	return false


func _update_pickups(delta: float) -> void:
	for i in pickups.size():
		if not bool(pickups[i].active):
			continue
		var pickup := pickups[i]
		pickup.life = float(pickup.life) - delta
		pickup.phase = float(pickup.phase) + delta
		if float(pickup.life) <= 0.0:
			pickup.active = false
		elif player_pos.distance_squared_to(Vector2(pickup.pos)) <= pow(PLAYER_RADIUS + ITEM_PICKUP_RADIUS, 2.0):
			_collect_pickup(pickup)
			pickup.active = false
		pickups[i] = pickup


func _collect_pickup(pickup: Dictionary) -> void:
	var item_type := int(pickup.item_type)
	var collected_level := ItemData.OVERCHARGE_LEVEL
	var popup_text := "%s  OVERCHARGE" % ItemData.display_name(item_type)
	if bool(pickup.overcharge):
		_start_overcharge(item_type)
	else:
		item_levels[item_type] = mini(ItemData.MAX_LEVEL, item_levels[item_type] + 1)
		collected_level = item_levels[item_type]
		popup_text = "%s  LVL %d" % [ItemData.display_name(item_type), collected_level]
		if item_type == ItemData.ItemType.TURRET:
			_deploy_turret(player_pos)
		elif item_type == ItemData.ItemType.AOE:
			aoe_timer = minf(aoe_timer, ItemData.aoe_interval(_effective_item_level(item_type)))
		elif item_type == ItemData.ItemType.LEAVE_BEHIND:
			mine_timer = minf(mine_timer, ItemData.mine_interval(_effective_item_level(item_type)))
		elif item_type == ItemData.ItemType.ANTIBODY_SHELL and antibody_cooldown > 0.0:
			antibody_cooldown = minf(antibody_cooldown, ItemData.antibody_recharge(_effective_item_level(item_type)))
	popups.append({"pos": player_pos, "text": popup_text, "life": 1.2, "duration": 1.2, "item_type": item_type})
	audio.play_sfx("item_pickup")
	emit_signal("item_collected", item_type, collected_level)


func _start_overcharge(item_type: int) -> void:
	overcharge_item = item_type
	overcharge_left = ItemData.OVERCHARGE_SECONDS
	if item_type == ItemData.ItemType.AOE:
		aoe_timer = minf(aoe_timer, ItemData.aoe_interval(ItemData.OVERCHARGE_LEVEL))
	elif item_type == ItemData.ItemType.LEAVE_BEHIND:
		mine_timer = minf(mine_timer, ItemData.mine_interval(ItemData.OVERCHARGE_LEVEL))
	elif item_type == ItemData.ItemType.ANTIBODY_SHELL and antibody_cooldown > 0.0:
		antibody_cooldown = minf(antibody_cooldown, ItemData.antibody_recharge(ItemData.OVERCHARGE_LEVEL))
	emit_signal("item_overcharge_changed", item_type, overcharge_left)


func _update_overcharge(delta: float) -> void:
	if overcharge_item < 0:
		return
	overcharge_left = maxf(0.0, overcharge_left - delta)
	if overcharge_left <= 0.0:
		var expired_item := overcharge_item
		overcharge_item = -1
		emit_signal("item_overcharge_changed", expired_item, 0.0)


func _effective_item_level(item_type: int) -> int:
	if overcharge_item == item_type and overcharge_left > 0.0:
		return ItemData.OVERCHARGE_LEVEL
	return item_levels[item_type]


func _spawn_effect_flash(at: Vector2, radius: float, color: Color) -> bool:
	for i in effect_flashes.size():
		if bool(effect_flashes[i].active):
			continue
		effect_flashes[i] = {
			"active": true,
			"pos": at,
			"radius": radius,
			"life": 0.3,
			"duration": 0.3,
			"color": color,
		}
		return true
	return false


func _update_effect_flashes(delta: float) -> void:
	for i in effect_flashes.size():
		if not bool(effect_flashes[i].active):
			continue
		var effect := effect_flashes[i]
		effect.life = float(effect.life) - delta
		if float(effect.life) <= 0.0:
			effect.active = false
		effect_flashes[i] = effect


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
			"hitter_cooldown": 0.0,
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
	if tier == GermData.GermTier.ELITE:
		_queue_item_warning(at)
	audio.play_sfx("split")
	if not bool(saved.reduced_motion):
		screen_shake = maxf(screen_shake, 0.34)


func _award_kill(base: int, at: Vector2) -> void:
	combo = GameMath.combo_after_kill(combo, run_time - last_kill_time)
	last_kill_time = run_time
	var points := GameMath.awarded_score(base, combo)
	score += points
	popups.append({"pos": at, "text": "+%d%s" % [points, "   %dx" % combo if combo > 1 else ""], "life": 0.8, "duration": 0.8, "item_type": -1})
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


func _active_regular_germ_count() -> int:
	var count := 0
	for g in germs:
		if bool(g.active) and int(g.tier) != GermData.GermTier.ELITE:
			count += 1
	return count


func _pending_regular_germ_count() -> int:
	var count := 0
	for warning in spawn_warnings:
		if int(warning.tier) != GermData.GermTier.ELITE:
			count += 1
	return count


func _elite_exists() -> bool:
	for g in germs:
		if bool(g.active) and int(g.tier) == GermData.GermTier.ELITE:
			return true
	for warning in spawn_warnings:
		if int(warning.tier) == GermData.GermTier.ELITE:
			return true
	return false


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
	for i in turrets.size(): turrets[i].active = false
	for i in mines.size(): mines[i].active = false
	for i in effect_flashes.size(): effect_flashes[i].active = false
	for i in pickups.size(): pickups[i].active = false
	for i in item_warnings.size(): item_warnings[i].active = false
	for i in item_levels.size(): item_levels[i] = 0
	spawn_warnings.clear()
	popups.clear()
	run_time = 0.0
	score = 0
	combo = 1
	last_kill_time = -999.0
	elite_timer = GameMath.ELITE_FIRST_SPAWN
	hitter_angle = 0.0
	aoe_timer = INF
	aoe_warning_active = false
	aoe_flash_left = 0.0
	mine_timer = INF
	overcharge_item = -1
	overcharge_left = 0.0
	antibody_cooldown = 0.0
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
	emit_signal("item_overcharge_changed", -1, 0.0)
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

	_draw_inhibitor_field(offset)
	for warning in spawn_warnings:
		_draw_spawn_warning(warning, offset)
	for warning in item_warnings:
		if bool(warning.active): _draw_item_warning(warning, offset)
	for mine in mines:
		if bool(mine.active): _draw_mine(mine, offset)
	for turret in turrets:
		if bool(turret.active): _draw_turret(turret, offset)
	for pickup in pickups:
		if bool(pickup.active): _draw_pickup(pickup, offset)
	for effect in effect_flashes:
		if bool(effect.active): _draw_effect_flash(effect, offset)
	for d in debris:
		if bool(d.active): _draw_debris(Vector2(d.pos) + offset, float(d.angle))
	for g in germs:
		if bool(g.active): _draw_germ(g, offset)
	for p in pellets:
		if bool(p.active):
			var pellet_color := LIME if int(p.owner) == ProjectileOwner.PLAYER else PURPLE_SOFT
			draw_circle(Vector2(p.pos) + offset, 5.0, pellet_color)
			draw_arc(Vector2(p.pos) + offset, 6.5, 0.0, TAU, 18, LIME_DARK if int(p.owner) == ProjectileOwner.PLAYER else PURPLE, 1.5, true)
			if int(p.owner) == ProjectileOwner.PLAYER and int(p.pierces) > 0:
				draw_arc(Vector2(p.pos) + offset, 9.0, 0.0, TAU, 18, ItemData.color(ItemData.ItemType.PIERCING_DOSE), 1.5, true)
	_draw_aoe_effect(offset)
	_draw_spinning_hitters(offset)
	_draw_antibody_shell(offset)
	_draw_player(offset)
	_draw_reticle(get_global_mouse_position())
	for popup in popups:
		var duration := float(popup.get("duration", 0.8))
		var alpha := clampf(float(popup.life) / duration, 0.0, 1.0)
		var popup_color := PURPLE
		if int(popup.get("item_type", -1)) >= 0:
			popup_color = ItemData.color(int(popup.item_type))
		_draw_text_centered(str(popup.text), Vector2(popup.pos) + offset, 24, Color(popup_color.r, popup_color.g, popup_color.b, alpha))
	_draw_hud()


func _draw_inhibitor_field(offset: Vector2) -> void:
	var level := _effective_item_level(ItemData.ItemType.INHIBITOR_FIELD)
	if level <= 0:
		return
	var color := ItemData.color(ItemData.ItemType.INHIBITOR_FIELD)
	var radius := ItemData.inhibitor_radius(level)
	var motion := 0.0 if bool(saved.get("reduced_motion", false)) else sin(run_time * 3.0) * 3.0
	var pos := player_pos + offset
	draw_circle(pos, radius, Color(color.r, color.g, color.b, 0.055))
	draw_arc(pos, radius + motion, 0.0, TAU, 72, Color(color.r, color.g, color.b, 0.42), 2.0, true)
	draw_arc(pos, radius * 0.72 - motion, 0.0, TAU, 64, Color(color.r, color.g, color.b, 0.16), 1.5, true)


func _draw_effect_flash(effect: Dictionary, offset: Vector2) -> void:
	var progress := 1.0 - clampf(float(effect.life) / float(effect.duration), 0.0, 1.0)
	var radius := float(effect.radius) * progress
	var color := Color(effect.color)
	var pos := Vector2(effect.pos) + offset
	draw_circle(pos, radius, Color(color.r, color.g, color.b, (1.0 - progress) * 0.1))
	draw_arc(pos, radius, 0.0, TAU, 64, Color(color.r, color.g, color.b, (1.0 - progress) * 0.9), 3.0, true)


func _draw_spawn_warning(warning: Dictionary, offset: Vector2) -> void:
	var tier := int(warning.tier)
	var spec := germ_specs[tier]
	var pos := _spawn_position(tier, float(warning.angle)) + offset
	var progress := 1.0 - clampf(float(warning.life) / float(warning.duration), 0.0, 1.0)
	var motion := 0.0 if bool(saved.get("reduced_motion", false)) else sin(progress * TAU * 3.0)
	var aura_radius := spec.radius + 18.0 + motion * 5.0
	var color := ORANGE_HOT if tier == GermData.GermTier.ELITE else (CYAN if tier != GermData.GermTier.MEDIUM else PURPLE_SOFT)
	var ring_color := ORANGE_HOT if tier == GermData.GermTier.ELITE else PURPLE
	draw_circle(pos, aura_radius, Color(color.r, color.g, color.b, 0.09 + progress * 0.1))
	for ring in 3:
		var ring_radius := aura_radius + float(ring) * 9.0 - progress * 7.0
		var ring_alpha := clampf(0.5 - float(ring) * 0.11 + progress * 0.25, 0.12, 0.75)
		draw_arc(pos, ring_radius, 0.0, TAU, 42, Color(ring_color.r, ring_color.g, ring_color.b, ring_alpha), 2.0, true)
	var inward := (arena_center - pos).normalized()
	var side := inward.orthogonal()
	var tip := pos + inward * (aura_radius + 10.0)
	var arrow := PackedVector2Array([tip, tip - inward * 13.0 + side * 7.0, tip - inward * 13.0 - side * 7.0])
	draw_colored_polygon(arrow, Color(LIME.r, LIME.g, LIME.b, 0.72))


func _draw_item_warning(warning: Dictionary, offset: Vector2) -> void:
	var item_type := int(warning.item_type)
	var color := ItemData.color(item_type)
	var pos := Vector2(warning.pos) + offset
	var progress := 1.0 - clampf(float(warning.life) / float(warning.duration), 0.0, 1.0)
	var motion := 0.0 if bool(saved.get("reduced_motion", false)) else sin(progress * TAU * 3.0) * 4.0
	var aura_radius := 28.0 + motion
	draw_circle(pos, aura_radius + 8.0, Color(color.r, color.g, color.b, 0.13 + progress * 0.12))
	for ring in 3:
		var radius := aura_radius + float(ring) * 9.0 - progress * 6.0
		draw_arc(pos, radius, 0.0, TAU, 40, Color(color.r, color.g, color.b, 0.72 - float(ring) * 0.16), 2.5, true)
	_draw_item_icon(item_type, pos, 16.0, color)


func _draw_pickup(pickup: Dictionary, offset: Vector2) -> void:
	var item_type := int(pickup.item_type)
	var color := ItemData.color(item_type)
	var pos := Vector2(pickup.pos) + offset
	var motion := 0.0 if bool(saved.get("reduced_motion", false)) else sin(float(pickup.phase) * 4.0) * 3.0
	draw_circle(pos, 28.0 + motion, Color(color.r, color.g, color.b, 0.16))
	draw_arc(pos, 24.0 + motion, 0.0, TAU, 32, color, 2.5, true)
	draw_circle(pos, ITEM_PICKUP_RADIUS, Color(WHITE.r, WHITE.g, WHITE.b, 0.94))
	_draw_item_icon(item_type, pos, 14.0, color)
	var label := "%s%s" % [ItemData.display_name(item_type), "  +" if bool(pickup.overcharge) else ""]
	_draw_text_centered(label, pos + Vector2(0.0, -32.0), 13, DARK_MINT)


func _draw_item_icon(item_type: int, pos: Vector2, size: float, color: Color) -> void:
	match item_type:
		ItemData.ItemType.SPINNING_HITTER:
			var direction := Vector2.RIGHT.rotated(-0.55)
			draw_line(pos - direction * size, pos + direction * size, color, 5.0, true)
			draw_circle(pos - direction * size, 3.5, color)
			draw_circle(pos + direction * size, 3.5, color)
		ItemData.ItemType.AOE:
			draw_arc(pos, size * 0.45, 0.0, TAU, 20, color, 2.5, true)
			draw_arc(pos, size * 0.85, 0.0, TAU, 24, color, 2.0, true)
		ItemData.ItemType.TURRET:
			draw_circle(pos, size * 0.52, color)
			draw_line(pos, pos + Vector2.RIGHT.rotated(-0.35) * size, WHITE, 4.0, true)
		ItemData.ItemType.RICOCHET:
			var points := PackedVector2Array([pos + Vector2(-size, size * 0.6), pos + Vector2(-size * 0.25, -size * 0.6), pos + Vector2(size * 0.2, size * 0.3), pos + Vector2(size, -size * 0.65)])
			draw_polyline(points, color, 3.5, true)
		ItemData.ItemType.SPREAD:
			for angle in [-0.5, 0.0, 0.5]:
				draw_line(pos - Vector2.RIGHT.rotated(float(angle)) * 3.0, pos + Vector2.RIGHT.rotated(float(angle)) * size, color, 3.0, true)
		ItemData.ItemType.LEAVE_BEHIND:
			var diamond := PackedVector2Array([pos + Vector2(0, -size), pos + Vector2(size, 0), pos + Vector2(0, size), pos + Vector2(-size, 0), pos + Vector2(0, -size)])
			draw_polyline(diamond, color, 3.0, true)
			draw_circle(pos, 4.0, color)
		ItemData.ItemType.CATALYST:
			var bolt := PackedVector2Array([pos + Vector2(-size * 0.2, -size), pos + Vector2(size * 0.45, -size * 0.2), pos + Vector2(0.05 * size, -size * 0.2), pos + Vector2(size * 0.2, size), pos + Vector2(-size * 0.5, size * 0.1), pos + Vector2(-size * 0.05, size * 0.1)])
			draw_colored_polygon(bolt, color)
		ItemData.ItemType.PIERCING_DOSE:
			draw_arc(pos, size * 0.52, 0.0, TAU, 22, color, 2.5, true)
			draw_line(pos + Vector2(-size, 0.0), pos + Vector2(size, 0.0), color, 3.0, true)
			var arrow := PackedVector2Array([pos + Vector2(size, 0.0), pos + Vector2(size * 0.52, -size * 0.34), pos + Vector2(size * 0.52, size * 0.34)])
			draw_colored_polygon(arrow, color)
		ItemData.ItemType.INHIBITOR_FIELD:
			draw_arc(pos, size * 0.48, 0.0, TAU, 22, color, 2.5, true)
			draw_arc(pos, size * 0.9, 0.0, TAU, 28, color, 2.0, true)
			draw_line(pos + Vector2(-size * 0.28, 0.0), pos + Vector2(size * 0.28, 0.0), color, 3.0, true)
		ItemData.ItemType.ANTIBODY_SHELL:
			var shield := PackedVector2Array([pos + Vector2(0.0, -size), pos + Vector2(size * 0.78, -size * 0.55), pos + Vector2(size * 0.62, size * 0.42), pos + Vector2(0.0, size), pos + Vector2(-size * 0.62, size * 0.42), pos + Vector2(-size * 0.78, -size * 0.55), pos + Vector2(0.0, -size)])
			draw_polyline(shield, color, 3.0, true)
		ItemData.ItemType.CATALYTIC_CLEANUP:
			for ray in 6:
				var direction := Vector2.RIGHT.rotated(TAU * float(ray) / 6.0)
				draw_line(pos + direction * size * 0.25, pos + direction * size, color, 3.0, true)
			draw_circle(pos, size * 0.28, color)
		ItemData.ItemType.SEEKING_ENZYME:
			draw_arc(pos, size * 0.72, 0.0, TAU, 28, color, 2.5, true)
			draw_circle(pos, size * 0.22, color)
			draw_line(pos + Vector2(-size, 0.0), pos + Vector2(-size * 0.45, 0.0), color, 2.5, true)
			draw_line(pos + Vector2(size * 0.45, 0.0), pos + Vector2(size, 0.0), color, 2.5, true)


func _draw_germ(g: Dictionary, offset: Vector2) -> void:
	var pos := Vector2(g.pos) + offset
	var tier := int(g.tier)
	var spec := germ_specs[tier]
	var radius := spec.radius
	var is_elite := tier == GermData.GermTier.ELITE
	var fill := ORANGE if is_elite else (CYAN if tier != GermData.GermTier.MEDIUM else PURPLE_SOFT)
	var outline := ORANGE_HOT if is_elite else PURPLE
	var spike_count := 14 if is_elite else 10
	for i in spike_count:
		var a := TAU * float(i) / float(spike_count) + float(g.phase) * 0.18
		var inner := pos + Vector2.RIGHT.rotated(a) * (radius * 0.78)
		var outer := pos + Vector2.RIGHT.rotated(a) * (radius + (9.0 if is_elite else 5.0) + sin(a * 3.0) * 3.0)
		draw_line(inner, outer, outline, maxf(1.5, radius * 0.07), true)
	draw_circle(pos, radius, Color(fill.r, fill.g, fill.b, 0.78))
	draw_arc(pos, radius, 0.0, TAU, 48, outline, maxf(2.0, radius * 0.08), true)
	if is_elite:
		draw_arc(pos, radius * 0.68, 0.0, TAU, 40, WHITE, 3.0, true)
	draw_circle(pos + Vector2(-radius * 0.24, -radius * 0.12), radius * 0.12, outline)
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


func _draw_mine(mine: Dictionary, offset: Vector2) -> void:
	var pos := Vector2(mine.pos) + offset
	var armed := float(mine.arm) <= 0.0
	var color := ORANGE_HOT if armed else ORANGE
	var pulse := 0.0 if bool(saved.get("reduced_motion", false)) else sin(float(mine.phase) * 6.0) * 2.0
	var size := 9.0 + pulse
	var diamond := PackedVector2Array([pos + Vector2(0, -size), pos + Vector2(size, 0), pos + Vector2(0, size), pos + Vector2(-size, 0), pos + Vector2(0, -size)])
	draw_colored_polygon(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3]]), Color(color.r, color.g, color.b, 0.55))
	draw_polyline(diamond, PURPLE, 2.0, true)
	if armed:
		draw_circle(pos, 3.0, LIME)


func _draw_turret(turret: Dictionary, offset: Vector2) -> void:
	var pos := Vector2(turret.pos) + offset
	var direction := Vector2.RIGHT.rotated(float(turret.angle))
	var overcharged := overcharge_item == ItemData.ItemType.TURRET and overcharge_left > 0.0
	var color := ORANGE_HOT if overcharged else PURPLE
	draw_circle(pos, 13.0, Color(PURPLE_SOFT.r, PURPLE_SOFT.g, PURPLE_SOFT.b, 0.88))
	draw_arc(pos, 13.0, 0.0, TAU, 24, color, 2.5, true)
	draw_line(pos, pos + direction * 20.0, color, 6.0, true)
	draw_circle(pos, 4.0, WHITE)


func _draw_aoe_effect(offset: Vector2) -> void:
	var level := _effective_item_level(ItemData.ItemType.AOE)
	if level <= 0:
		return
	var pos := player_pos + offset
	var radius := ItemData.aoe_radius(level)
	if aoe_warning_active:
		var progress := clampf(1.0 - aoe_timer / AOE_WARNING_SECONDS, 0.0, 1.0)
		var warning_radius := radius if bool(saved.get("reduced_motion", false)) else lerpf(radius * 0.35, radius, progress)
		draw_arc(pos, warning_radius, 0.0, TAU, 72, Color(CYAN.r, CYAN.g, CYAN.b, 0.36 + progress * 0.34), 3.0, true)
	if aoe_flash_left > 0.0:
		var alpha := clampf(aoe_flash_left / 0.22, 0.0, 1.0)
		draw_circle(pos, radius, Color(CYAN.r, CYAN.g, CYAN.b, alpha * 0.12))
		draw_arc(pos, radius, 0.0, TAU, 72, Color(CYAN.r, CYAN.g, CYAN.b, alpha * 0.8), 4.0, true)


func _draw_antibody_shell(offset: Vector2) -> void:
	var level := _effective_item_level(ItemData.ItemType.ANTIBODY_SHELL)
	if level <= 0:
		return
	var color := ItemData.color(ItemData.ItemType.ANTIBODY_SHELL)
	var pos := player_pos + offset
	var radius := PLAYER_RADIUS + 10.0
	if antibody_cooldown <= 0.0:
		var pulse := 0.0 if bool(saved.get("reduced_motion", false)) else sin(run_time * 5.0) * 2.0
		draw_circle(pos, radius + pulse, Color(color.r, color.g, color.b, 0.08))
		draw_arc(pos, radius + pulse, 0.0, TAU, 36, Color(color.r, color.g, color.b, 0.9), 3.0, true)
	else:
		var recharge := ItemData.antibody_recharge(level)
		var progress := 1.0 - clampf(antibody_cooldown / recharge, 0.0, 1.0)
		draw_arc(pos, radius, -PI * 0.5, -PI * 0.5 + TAU * progress, 36, Color(color.r, color.g, color.b, 0.55), 2.0, true)


func _draw_spinning_hitters(offset: Vector2) -> void:
	var level := _effective_item_level(ItemData.ItemType.SPINNING_HITTER)
	var count := ItemData.hitter_count(level)
	if count <= 0:
		return
	var color := ORANGE_HOT if level >= ItemData.OVERCHARGE_LEVEL else ORANGE
	for hitter in count:
		var angle := hitter_angle + TAU * float(hitter) / float(count)
		var pos := player_pos + offset + Vector2.RIGHT.rotated(angle) * HITTER_ORBIT_RADIUS
		var direction := Vector2.RIGHT.rotated(angle + PI * 0.5)
		draw_line(pos - direction * 11.0, pos + direction * 11.0, PURPLE, 9.0, true)
		draw_line(pos - direction * 10.0, pos + direction * 10.0, color, 5.0, true)
		draw_circle(pos - direction * 10.0, 3.0, LIME)
		draw_circle(pos + direction * 10.0, 3.0, LIME)


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
		["LEFT CLICK", "Fire antibiotic pellets. Catalyst increases their cadence."],
		["SPACE", "Hold to boost. The charge drains, pauses, then recharges."],
		["ESC", "Pause. Losing browser focus pauses automatically."],
		["GOLD ELITE", "Destroy the tank germ to reveal a permanent item."],
		["ITEM AURA", "Touch the item before it fades. Duplicates level it up."],
	]
	for i in rows.size():
		var y := panel.position.y + 56.0 + i * 47.0
		_draw_text(str(rows[i][0]), Vector2(panel.position.x + 42.0, y), 19, PURPLE)
		_draw_text(str(rows[i][1]), Vector2(panel.position.x + 230.0, y), 15, DARK_MINT)
	_draw_text_centered("Items add attacks, control, or protection. Unshielded hostile contact ends the run.", Vector2(viewport_size.x * 0.5, panel.end.y - 30.0), 15, ORANGE_HOT)
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
