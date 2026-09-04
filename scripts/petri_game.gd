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
signal boon_collected(boon_type: int, level: int)
signal health_changed(current_health: int, maximum_health: int)

enum AppState { MENU, HOW_TO, PLAYING, PAUSED, SETTINGS, GAME_OVER }
enum ProjectileOwner { PLAYER, TURRET }
enum DialogueSpeaker { NONE, GERM, PLAYER }
enum DialogueCutscenePhase { NONE, ZOOM_IN, TALKING, ZOOM_OUT }
enum BossEncounterPhase { INACTIVE, CLEANUP, WARNING, ACTIVE, BOON_SELECTION, COMPLETED }
enum BossDashPhase { CHASE, WARNING, DASH, VOLLEY_WARNING, RING_WARNING, RING_ACTIVE }
enum DebrisSource { REGULAR, BOSS_VOLLEY }

const BG := Color("#D7FFF8")
const MINT := Color("#B2DBD5")
const DARK_MINT := Color("#70A097")
const ACCENT_MINT := Color("#6FB2AD")
const GAME_BG := Color("#B2DBD5")
const PLAYSPACE_RING := Color("#D1EDE7")
const WHITE := Color("#FFFFFF")
const ORANGE := Color("#FFD9A6")
const ORANGE_HOT := Color("#FF9E73")
const LIME := Color("#DCFF84")
const LIME_DARK := Color("#A9C375")
const CYAN := Color("#55DDE0")
const PURPLE_SOFT := Color("#EFCEFD")
const PURPLE := Color("#77408E")
const BOSS_FILL := Color("#5D2E6E")
const BOSS_CORE := Color("#3C2049")
const BOSS_2_FILL := Color("#321A3C")
const BOSS_2_CORE := Color("#FF6B6B")
const BOSS_3_FILL := Color("#1B0D26")
const BOSS_3_CORE := Color("#FF5C8A")

const PLAYER_RADIUS := 18.0
const PLAYER_ASSET_WIDTH := 39.1
const PLAYER_ASSET_ROTATION_OFFSET := PI * 0.5
const PLAYER_BASE_HEALTH := 3
const PLAYER_DAMAGE_GRACE_SECONDS := 1.0
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
const ARENA_SCALE := 1.3225
const PLAYSPACE_RING_RADIUS_MULTIPLIER := 1.44
const DISH_INNER_SHADOW_WIDTH_MULTIPLIER := 0.2
const DISH_INNER_SHADOW_FALLOFF := 1.7
const DISH_INNER_SHADOW_LAYERS := 64
const GERM_SPAWN_TELEGRAPH_SECONDS := 2.5
const SPLIT_CHILD_SPEED_MULTIPLIER := 0.75
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
const DIALOGUE_BASE_WORD_COUNT := 4
const DIALOGUE_BASE_DURATION_SECONDS := 2.2
const DIALOGUE_EXTRA_WORD_SECONDS := 0.25
const DIALOGUE_START_INTERVAL_SECONDS := 24.0
const PLAYER_DIALOGUE_MIN_INTERVAL := 24.0
const PLAYER_DIALOGUE_MAX_INTERVAL := 34.0
const DIALOGUE_MAX_TEXT_WIDTH := 280.0
const DIALOGUE_ZOOM_IN_SECONDS := 0.3
const DIALOGUE_ZOOM_OUT_SECONDS := 0.35
const DIALOGUE_CAMERA_SCALE := 1.58
const DIALOGUE_TYPE_HOLD_SECONDS := 0.2
const DIALOGUE_SPEAKER_PULSE_AMOUNT := 0.055
const DIALOGUE_SPEAKER_PULSE_SPEED := 7.5
const DIALOGUE_CINEMATIC_HUD_OPACITY := 0.08
const HUD_SCALE := 0.72
const HUD_OCCLUDED_OPACITY := 0.15
const WORLD_TEXT_OCCLUDED_OPACITY := 0.28
const OPACITY_TRANSITION_SPEED := 4.5
const GERM_ASSET_RADIUS := 119.0
const GERM_HIT_REACTION_SECONDS := 0.3
const GERM_HIT_FLASH_PEAK_SECONDS := 0.05
const GERM_HIT_FLASH_END_SECONDS := 0.25
const GERM_HIT_LAYER_STARTS := [0.0, 0.033333335, 0.06666667, 0.09427313]
const GERM_HIT_LAYER_PEAKS := [0.10000001, 0.13333334, 0.16550392, 0.19917288]
const GERM_VISUAL_DRAW_ORDER := [
	GermData.GermTier.BOSS_3,
	GermData.GermTier.BOSS_2,
	GermData.GermTier.BOSS,
	GermData.GermTier.ELITE,
	GermData.GermTier.LARGE,
	GermData.GermTier.MEDIUM,
	GermData.GermTier.SMALL,
]
const BEAM_MAX_LENGTH := 1600.0
const BOON_SELECTION_MOVE_DRAG := 105.0

const CULTURE_WAR_DIALOGUE := preload("res://scripts/culture_war_dialogue.gd")

var font: Font = preload("res://Excelorate-Font.otf")
var logo_texture: Texture2D = preload("res://assets/figma/petri-logo.png")
var player_texture: Texture2D = preload("res://assets/Specimen/P1/P1.png")
var germ_layer_sources: Array[Texture2D] = [
	preload("res://assets/Specimen/Meeboid/Meeboid-4.png"),
	preload("res://assets/Specimen/Meeboid/Meeboid-3.png"),
	preload("res://assets/Specimen/Meeboid/Meeboid-2.png"),
	preload("res://assets/Specimen/Meeboid/Meeboid-1.png"),
]
var germ_specs: Array[GermData] = [
	preload("res://data/germ_large.tres"),
	preload("res://data/germ_medium.tres"),
	preload("res://data/germ_small.tres"),
	preload("res://data/germ_elite.tres"),
	preload("res://data/germ_boss.tres"),
	preload("res://data/germ_boss_2.tres"),
	preload("res://data/germ_boss_3.tres"),
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
var damage_protection_left := 0.0
var fire_cooldown := 0.0
var player_health := PLAYER_BASE_HEALTH
var player_max_health := PLAYER_BASE_HEALTH
var boss_health_bonus := 0

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
var boss_encounter_phase := BossEncounterPhase.INACTIVE
var bosses_defeated := 0
var active_boss_stage := -1
var base_weapon_damage := 1
var base_weapon_fire_rate := GameMath.BASE_PLAYER_FIRE_RATE
var boon_selection_lock_left := 0.0
var boon_reward_stage := -1
var active_space_boon := BoonData.NO_BOON
var dash_left := 0.0
var dash_cooldown := 0.0
var dash_direction := Vector2.ZERO
var invincibility_left := 0.0
var invincibility_cooldown := 0.0
var freeze_cooldown := 0.0
var freeze_flash_left := 0.0
var goo_emit_timer := 0.0
var beam_charge := 0.0
var beam_active_left := 0.0
var beam_tick_left := 0.0
var beam_direction := Vector2.RIGHT

var pellets: Array[Dictionary] = []
var germs: Array[Dictionary] = []
var debris: Array[Dictionary] = []
var spawn_warnings: Array[Dictionary] = []
var item_warnings: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var turrets: Array[Dictionary] = []
var mines: Array[Dictionary] = []
var item_levels: Array[int] = []
var boon_levels: Array[int] = []
var boon_choices: Array[Dictionary] = []
var goo_patches: Array[Dictionary] = []
var popups: Array[Dictionary] = []
var germ_visual_textures: Array = []
var germ_flash_masks: Array[Texture2D] = []
var dialogue_speaker := DialogueSpeaker.NONE
var dialogue_germ_index := -1
var dialogue_text := ""
var dialogue_life := 0.0
var dialogue_cooldown := 0.0
var dialogue_cutscene_phase := DialogueCutscenePhase.NONE
var dialogue_phase_time := 0.0
var dialogue_talk_duration := 0.0
var dialogue_type_characters_per_second := 40.0
var dialogue_visible_characters := 0
var dialogue_focus_position := Vector2.ZERO
var next_player_dialogue_time := INF
var pending_dialogue_germ_indices: Array[int] = [-1, -1]
var logo_hud_opacity := 1.0
var score_hud_opacity := 1.0
var timer_hud_opacity := 1.0
var combo_hud_opacity := 1.0
var boost_hud_opacity := 1.0
var health_hud_opacity := 1.0
var dialogue_occlusion_opacity := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rng.randomize()
	_create_pools()
	_build_germ_visual_cache()
	saved = save_store.load_data()
	audio.apply_levels(float(saved.sfx_volume), float(saved.music_volume))
	_apply_fullscreen_preference()
	_update_layout()
	player_pos = arena_center
	queue_redraw()


func _create_pools() -> void:
	for i in PELLET_POOL_SIZE:
		pellets.append({"active": false, "pos": Vector2.ZERO, "vel": Vector2.ZERO, "life": 0.0, "bounces": 0, "owner": ProjectileOwner.PLAYER, "damage": 1})
	for i in GameMath.MAX_GERMS:
		germs.append({"active": false, "tier": GermData.GermTier.LARGE, "pos": Vector2.ZERO, "vel": Vector2.ZERO, "move_speed": 0.0, "hp": 0, "phase": 0.0, "hitter_cooldown": 0.0, "goo_hit_cooldown": 0.0, "freeze_left": 0.0, "hit_reaction_left": 0.0, "topic_id": -1, "stance": -1, "dash_phase": BossDashPhase.CHASE, "dash_timer": INF, "dash_direction": Vector2.ZERO, "volley_timer": INF, "volley_rotation": 0.0, "ring_timer": INF, "ring_angle": 0.0, "ring_hit_player": false})
	for i in GameMath.MAX_FRAGMENTS:
		debris.append({"active": false, "pos": Vector2.ZERO, "vel": Vector2.ZERO, "life": 0.0, "angle": 0.0, "spin": 0.0, "hitter_cooldown": 0.0, "goo_hit_cooldown": 0.0, "freeze_left": 0.0, "source": DebrisSource.REGULAR, "bounces": -1})
	for i in TURRET_POOL_SIZE:
		turrets.append({"active": false, "pos": Vector2.ZERO, "cooldown": 0.0, "angle": 0.0})
	for i in MINE_POOL_SIZE:
		mines.append({"active": false, "pos": Vector2.ZERO, "life": 0.0, "arm": 0.0, "phase": 0.0, "blast_radius": 55.0})
	for i in PICKUP_POOL_SIZE:
		item_warnings.append({"active": false, "item_type": 0, "pos": Vector2.ZERO, "life": 0.0, "duration": ITEM_SPAWN_TELEGRAPH_SECONDS, "overcharge": false})
		pickups.append({"active": false, "item_type": 0, "pos": Vector2.ZERO, "life": 0.0, "phase": 0.0, "overcharge": false})
	for i in ItemData.ItemType.size():
		item_levels.append(0)
	for i in BoonData.BoonType.size():
		boon_levels.append(0)
	for i in BoonData.CHOICE_COUNT:
		boon_choices.append({"active": false, "boon_type": BoonData.NO_BOON, "pos": Vector2.ZERO, "phase": 0.0})
	for i in BoonData.GOO_POOL_SIZE:
		goo_patches.append({"active": false, "pos": Vector2.ZERO, "life": 0.0, "duration": 0.0, "radius": 0.0, "phase": 0.0})


func _build_germ_visual_cache() -> void:
	germ_visual_textures.clear()
	germ_flash_masks.clear()
	for source in germ_layer_sources:
		germ_flash_masks.append(_make_germ_layer_texture(source, WHITE, true))
	for tier in GermData.GermTier.size():
		var tier_layers: Array[Texture2D] = []
		var target := _germ_palette_color(tier)
		for source in germ_layer_sources:
			tier_layers.append(_make_germ_layer_texture(source, target, false))
		germ_visual_textures.append(tier_layers)


func _make_germ_layer_texture(source: Texture2D, target: Color, alpha_mask: bool) -> Texture2D:
	var image := source.get_image()
	image.convert(Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.a <= 0.0:
				continue
			if alpha_mask:
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, pixel.a))
			else:
				var saturation := clampf(pixel.s * target.s, 0.0, 1.0)
				var value := clampf(pixel.v * target.v, 0.0, 1.0)
				image.set_pixel(x, y, Color.from_hsv(target.h, saturation, value, pixel.a))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func _germ_palette_color(tier: int) -> Color:
	match tier:
		GermData.GermTier.MEDIUM:
			return PURPLE_SOFT
		GermData.GermTier.ELITE:
			return ORANGE_HOT
		GermData.GermTier.BOSS:
			return BOSS_FILL
		GermData.GermTier.BOSS_2:
			return BOSS_2_FILL
		GermData.GermTier.BOSS_3:
			return BOSS_3_FILL
	return CYAN


func _germ_hit_layer_scale(germ: Dictionary, layer: int) -> float:
	if bool(saved.get("reduced_motion", false)) or layer < 0 or layer >= GERM_HIT_LAYER_STARTS.size():
		return 1.0
	var left := float(germ.get("hit_reaction_left", 0.0))
	if left <= 0.0:
		return 1.0
	var elapsed := GERM_HIT_REACTION_SECONDS - left
	var start := float(GERM_HIT_LAYER_STARTS[layer])
	var peak := float(GERM_HIT_LAYER_PEAKS[layer])
	if elapsed <= start:
		return 1.0
	if elapsed <= peak:
		return lerpf(1.0, 1.1, clampf((elapsed - start) / maxf(peak - start, 0.0001), 0.0, 1.0))
	return lerpf(1.1, 1.0, clampf((elapsed - peak) / maxf(GERM_HIT_REACTION_SECONDS - peak, 0.0001), 0.0, 1.0))


func _germ_hit_flash_amount(germ: Dictionary) -> float:
	if bool(saved.get("reduced_motion", false)):
		return 0.0
	var left := float(germ.get("hit_reaction_left", 0.0))
	if left <= 0.0:
		return 0.0
	var elapsed := GERM_HIT_REACTION_SECONDS - left
	if elapsed <= GERM_HIT_FLASH_PEAK_SECONDS:
		return clampf(elapsed / GERM_HIT_FLASH_PEAK_SECONDS, 0.0, 1.0)
	if elapsed <= GERM_HIT_FLASH_END_SECONDS:
		return 1.0 - clampf((elapsed - GERM_HIT_FLASH_PEAK_SECONDS) / (GERM_HIT_FLASH_END_SECONDS - GERM_HIT_FLASH_PEAK_SECONDS), 0.0, 1.0)
	return 0.0


func _clear_germ_hit_reactions() -> void:
	for i in germs.size():
		germs[i].hit_reaction_left = 0.0


func _set_reduced_motion(enabled: bool) -> void:
	saved.reduced_motion = enabled
	if enabled:
		_clear_germ_hit_reactions()


func _process(delta: float) -> void:
	_update_layout()
	if state == AppState.PLAYING:
		_update_run(delta)
	if not _dialogue_cutscene_active():
		_update_popups(delta)
	_update_overlay_opacities(delta)
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
	if boss_encounter_phase == BossEncounterPhase.BOON_SELECTION:
		_update_boon_selection(delta)
		return
	if _dialogue_cutscene_active():
		_update_dialogue(delta)
		return
	run_time += delta
	_update_dialogue(delta)
	if _dialogue_cutscene_active():
		return
	spawn_protection_left = maxf(0.0, spawn_protection_left - delta)
	damage_protection_left = maxf(0.0, damage_protection_left - delta)
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	_update_overcharge(delta)
	emit_signal("run_time_changed", run_time)

	var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_update_boon_cooldowns(delta)
	_update_space_ability(delta, movement)
	_update_player_movement(delta, movement)
	_resolve_player_membrane()

	var aim := get_global_mouse_position() - player_pos
	if aim.length_squared() > 1.0:
		player_facing = aim.angle()
	if Input.is_action_pressed("fire") and fire_cooldown <= 0.0:
		_fire_pellet()
	_update_beam(delta)

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
	_update_goo_patches(delta)
	_resolve_projectile_hits()
	_resolve_hostile_hits()
	_update_boss_encounter()

	if combo > 1 and run_time - last_kill_time > 2.0:
		combo = 1
		emit_signal("combo_changed", combo)

	if _normal_spawning_enabled():
		spawn_timer -= delta
		if spawn_timer <= 0.0 and _active_regular_germ_count() + _pending_regular_germ_count() < GameMath.active_germ_cap(run_time):
			_queue_spawn_warning(_weighted_spawn_tier())
			spawn_timer = GameMath.spawn_interval(run_time)

		elite_timer -= delta
		if elite_timer <= 0.0 and not _elite_exists():
			_queue_spawn_warning(GermData.GermTier.ELITE)
			elite_timer = GameMath.ELITE_SPAWN_INTERVAL
			audio.play_sfx("elite_spawn")


func _update_boon_selection(delta: float) -> void:
	var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var movement_multiplier := BoonData.movement_multiplier(_boon_level(BoonData.BoonType.MOVEMENT_SPEED))
	if movement.length_squared() > 0.0:
		player_velocity += movement.normalized() * BASE_ACCEL * movement_multiplier * delta
	else:
		player_velocity = player_velocity.move_toward(Vector2.ZERO, BOON_SELECTION_MOVE_DRAG * delta)
	var max_speed := BASE_MAX_SPEED * movement_multiplier
	if player_velocity.length() > max_speed:
		player_velocity = player_velocity.normalized() * max_speed
	player_pos += player_velocity * delta
	_resolve_player_membrane(true)
	var aim := get_global_mouse_position() - player_pos
	if aim.length_squared() > 1.0:
		player_facing = aim.angle()
	boon_selection_lock_left = maxf(0.0, boon_selection_lock_left - delta)
	if boon_selection_lock_left <= 0.000001:
		boon_selection_lock_left = 0.0
	for i in boon_choices.size():
		if not bool(boon_choices[i].active):
			continue
		boon_choices[i].phase = float(boon_choices[i].phase) + delta
		if boon_selection_lock_left <= 0.0 and player_pos.distance_squared_to(Vector2(boon_choices[i].pos)) <= pow(PLAYER_RADIUS + BoonData.CHOICE_PICKUP_RADIUS, 2.0):
			_collect_boon_choice(i)
			return


func _update_boon_cooldowns(delta: float) -> void:
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	invincibility_cooldown = maxf(0.0, invincibility_cooldown - delta)
	invincibility_left = maxf(0.0, invincibility_left - delta)
	freeze_cooldown = maxf(0.0, freeze_cooldown - delta)
	freeze_flash_left = maxf(0.0, freeze_flash_left - delta)


func _update_space_ability(delta: float, movement: Vector2) -> void:
	var mobility_level := _boon_level(BoonData.BoonType.SPEED_BOOSTS)
	var mobility_speed := BoonData.mobility_speed_multiplier(mobility_level)
	var mobility_duration := BoonData.mobility_duration_multiplier(mobility_level)
	var mobility_recharge := BoonData.mobility_recharge_multiplier(mobility_level)
	if dash_left > 0.0:
		dash_left = maxf(0.0, dash_left - delta)
		player_velocity = dash_direction * BoonData.dash_speed(_boon_level(BoonData.BoonType.DASH_EVADE)) * mobility_speed
		boost_active = false
		return
	match active_space_boon:
		BoonData.BoonType.DASH_EVADE:
			boost_active = false
			if Input.is_action_just_pressed("boost") and dash_cooldown <= 0.0:
				dash_direction = movement.normalized() if movement.length_squared() > 0.0 else Vector2.RIGHT.rotated(player_facing)
				var level := _boon_level(BoonData.BoonType.DASH_EVADE)
				dash_left = BoonData.dash_duration(level) * mobility_duration
				dash_cooldown = BoonData.dash_cooldown(level) / mobility_recharge
				player_velocity = dash_direction * BoonData.dash_speed(level) * mobility_speed
				audio.play_sfx("boost")
		BoonData.BoonType.INVINCIBILITY:
			boost_active = false
			if Input.is_action_just_pressed("boost") and invincibility_cooldown <= 0.0:
				var level := _boon_level(BoonData.BoonType.INVINCIBILITY)
				invincibility_left = BoonData.invincibility_duration(level)
				invincibility_cooldown = BoonData.invincibility_cooldown(level)
				audio.play_sfx("boost")
		BoonData.BoonType.FREEZE_AOE_SHOCK:
			boost_active = false
			if Input.is_action_just_pressed("boost") and freeze_cooldown <= 0.0:
				_activate_freeze_shock()
		_:
			var wants_boost := Input.is_action_pressed("boost") and movement.length_squared() > 0.0
			var boost_state := GameMath.update_boost(boost_charge, boost_delay, wants_boost, delta, mobility_duration, mobility_recharge)
			var was_boosting := boost_active
			boost_charge = float(boost_state.charge)
			boost_delay = float(boost_state.delay)
			boost_active = bool(boost_state.active)
			if boost_active and not was_boosting:
				audio.play_sfx("boost")
			if active_space_boon == BoonData.BoonType.GOO_TRAIL_BOOST and boost_active:
				goo_emit_timer -= delta
				if goo_emit_timer <= 0.0:
					_spawn_goo_patch(player_pos)
					goo_emit_timer += BoonData.goo_interval(_boon_level(BoonData.BoonType.GOO_TRAIL_BOOST))
			else:
				goo_emit_timer = 0.0
	emit_signal("boost_charge_changed", _space_meter_value())


func _update_player_movement(delta: float, movement: Vector2) -> void:
	if dash_left > 0.0:
		player_pos += player_velocity * delta
		return
	var movement_multiplier := BoonData.movement_multiplier(_boon_level(BoonData.BoonType.MOVEMENT_SPEED))
	var mobility_speed := BoonData.mobility_speed_multiplier(_boon_level(BoonData.BoonType.SPEED_BOOSTS))
	var accel_boost := 1.0
	var speed_boost := 1.0
	if boost_active:
		if active_space_boon == BoonData.BoonType.GOO_TRAIL_BOOST:
			var goo_level := _boon_level(BoonData.BoonType.GOO_TRAIL_BOOST)
			accel_boost = BoonData.goo_accel_multiplier(goo_level) * mobility_speed
			speed_boost = BoonData.goo_speed_multiplier(goo_level) * mobility_speed
		else:
			accel_boost = BOOST_ACCEL_MULT * mobility_speed
			speed_boost = BOOST_SPEED_MULT * mobility_speed
	var accel := BASE_ACCEL * movement_multiplier * accel_boost
	var max_speed := BASE_MAX_SPEED * movement_multiplier * speed_boost
	if movement.length_squared() > 0.0:
		player_velocity += movement.normalized() * accel * delta
	else:
		player_velocity = player_velocity.move_toward(Vector2.ZERO, DRAG * delta)
	if player_velocity.length() > max_speed:
		player_velocity = player_velocity.normalized() * max_speed
	player_pos += player_velocity * delta


func _resolve_player_membrane(force_safe: bool = false) -> void:
	var from_center := player_pos - arena_center
	var limit := arena_radius - PLAYER_RADIUS
	if from_center.length() <= limit:
		return
	if invincibility_left > 0.0 and not force_safe:
		return
	var normal := from_center.normalized()
	var outward_speed := maxf(0.0, player_velocity.dot(normal))
	player_pos = arena_center + normal * limit
	if dash_left > 0.0:
		dash_left = 0.0
		player_velocity = Vector2.ZERO
		return
	var took_damage := false
	if not force_safe and GameMath.membrane_is_lethal(outward_speed):
		took_damage = _damage_player("Membrane impact", true)
		if state == AppState.GAME_OVER:
			return
	player_velocity = player_velocity.bounce(normal) * 0.66
	if not took_damage:
		audio.play_sfx("impact")
	if not bool(saved.reduced_motion):
		screen_shake = maxf(screen_shake, 0.22)


func _player_damage_blocked(ignore_spawn_protection: bool = false) -> bool:
	return state != AppState.PLAYING or boss_encounter_phase == BossEncounterPhase.BOON_SELECTION or (spawn_protection_left > 0.0 and not ignore_spawn_protection) or damage_protection_left > 0.0 or dash_left > 0.0 or invincibility_left > 0.0


func _damage_player(reason: String, ignore_spawn_protection: bool = false) -> bool:
	if _player_damage_blocked(ignore_spawn_protection):
		return false
	player_health = maxi(0, player_health - 1)
	emit_signal("health_changed", player_health, player_max_health)
	if player_health <= 0:
		_finish_run(reason)
		return true
	damage_protection_left = PLAYER_DAMAGE_GRACE_SECONDS
	popups.append({"pos": player_pos, "text": "-1 HP", "life": 0.8, "duration": 0.8, "item_type": -1, "occlusion_opacity": 1.0, "color": BOSS_2_CORE})
	audio.play_sfx("impact")
	if not bool(saved.get("reduced_motion", false)):
		screen_shake = maxf(screen_shake, 0.38)
	return true


func _restore_player_health() -> void:
	player_max_health = BoonData.player_max_health(_boon_level(BoonData.BoonType.MAX_HEALTH)) + boss_health_bonus
	player_health = player_max_health
	damage_protection_left = 0.0
	emit_signal("health_changed", player_health, player_max_health)


func _fire_pellet() -> void:
	var spread_level := _effective_item_level(ItemData.ItemType.SPREAD)
	var ricochet_level := _effective_item_level(ItemData.ItemType.RICOCHET)
	var angles := ItemData.spread_angles(spread_level)
	var center_direction := Vector2.RIGHT.rotated(player_facing)
	var center_spawned := _spawn_projectile(
		player_pos + center_direction * (PLAYER_RADIUS + 11.0),
		center_direction,
		PELLET_SPEED,
		ItemData.ricochet_lifetime(ricochet_level),
		ItemData.ricochet_bounces(ricochet_level),
		ProjectileOwner.PLAYER,
		player_velocity * 0.22,
		_player_projectile_damage()
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
			player_velocity * 0.22,
			_player_projectile_damage()
		)
	fire_cooldown = _player_fire_interval()
	audio.play_sfx("fire")


func _player_projectile_damage() -> int:
	return base_weapon_damage


func _player_fire_interval() -> float:
	return 1.0 / maxf(base_weapon_fire_rate, 0.001)


func _boon_level(boon_type: int) -> int:
	if boon_type < 0 or boon_type >= boon_levels.size():
		return 0
	return boon_levels[boon_type]


func _space_hud_label() -> String:
	if active_space_boon == BoonData.NO_BOON:
		return "BOOST"
	return BoonData.short_label(active_space_boon)


func _space_meter_value() -> float:
	match active_space_boon:
		BoonData.BoonType.DASH_EVADE:
			if dash_left > 0.0:
				var duration := BoonData.dash_duration(_boon_level(active_space_boon)) * BoonData.mobility_duration_multiplier(_boon_level(BoonData.BoonType.SPEED_BOOSTS))
				return clampf(dash_left / maxf(duration, 0.001), 0.0, 1.0)
			var cooldown := BoonData.dash_cooldown(_boon_level(active_space_boon)) / BoonData.mobility_recharge_multiplier(_boon_level(BoonData.BoonType.SPEED_BOOSTS))
			return 1.0 - clampf(dash_cooldown / maxf(cooldown, 0.001), 0.0, 1.0)
		BoonData.BoonType.INVINCIBILITY:
			if invincibility_left > 0.0:
				return clampf(invincibility_left / BoonData.invincibility_duration(_boon_level(active_space_boon)), 0.0, 1.0)
			return 1.0 - clampf(invincibility_cooldown / BoonData.invincibility_cooldown(_boon_level(active_space_boon)), 0.0, 1.0)
		BoonData.BoonType.FREEZE_AOE_SHOCK:
			return 1.0 - clampf(freeze_cooldown / BoonData.freeze_cooldown(_boon_level(active_space_boon)), 0.0, 1.0)
	return boost_charge


func _update_beam(delta: float) -> void:
	var beam_level := _boon_level(BoonData.BoonType.CHARGED_BEAM)
	if beam_level <= 0:
		beam_charge = 0.0
		beam_active_left = 0.0
		return
	var aim := get_global_mouse_position() - player_pos
	if aim.length_squared() > 1.0:
		beam_direction = aim.normalized()
	if beam_active_left > 0.0:
		beam_active_left = maxf(0.0, beam_active_left - delta)
		beam_tick_left -= delta
		while beam_tick_left <= 0.0 and beam_active_left > 0.0:
			_damage_beam(beam_level)
			beam_tick_left += BoonData.BEAM_TICK_SECONDS
		return
	if Input.is_action_pressed("fire"):
		beam_charge = minf(BoonData.BEAM_CHARGE_SECONDS, beam_charge + delta)
	elif Input.is_action_just_released("fire"):
		if beam_charge >= BoonData.BEAM_CHARGE_SECONDS:
			_begin_charged_beam()
		beam_charge = 0.0
	elif beam_charge > 0.0:
		beam_charge = 0.0


func _begin_charged_beam() -> void:
	if _boon_level(BoonData.BoonType.CHARGED_BEAM) <= 0 or beam_active_left > 0.0:
		return
	beam_active_left = BoonData.BEAM_DURATION_SECONDS
	beam_tick_left = 0.0
	audio.play_sfx("aoe")


func _beam_end() -> Vector2:
	var direction := beam_direction.normalized()
	if direction.length_squared() <= 0.0:
		direction = Vector2.RIGHT.rotated(player_facing)
	var offset := player_pos - arena_center
	var projection := offset.dot(direction)
	var discriminant := projection * projection - offset.length_squared() + arena_radius * arena_radius
	var distance := BEAM_MAX_LENGTH
	if discriminant >= 0.0:
		distance = minf(BEAM_MAX_LENGTH, maxf(0.0, -projection + sqrt(discriminant)))
	return player_pos + direction * distance


func _damage_beam(level: int) -> void:
	var start := player_pos
	var finish := _beam_end()
	var width := BoonData.beam_width(level)
	var damage := BoonData.beam_damage(level)
	var germ_targets: Array[int] = []
	var debris_targets: Array[int] = []
	for i in germs.size():
		if not bool(germs[i].active):
			continue
		var radius := germ_specs[int(germs[i].tier)].radius + width * 0.5
		if _distance_squared_to_segment(Vector2(germs[i].pos), start, finish) <= radius * radius:
			germ_targets.append(i)
	for i in debris.size():
		if bool(debris[i].active) and _distance_squared_to_segment(Vector2(debris[i].pos), start, finish) <= pow(8.0 + width * 0.5, 2.0):
			debris_targets.append(i)
	for index in germ_targets:
		_damage_germ(index, damage)
	for index in debris_targets:
		_destroy_debris(index)


func _distance_squared_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment := finish - start
	if segment.length_squared() <= 0.0001:
		return point.distance_squared_to(start)
	var t := clampf((point - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return point.distance_squared_to(start + segment * t)


func _activate_freeze_shock() -> void:
	var level := _boon_level(BoonData.BoonType.FREEZE_AOE_SHOCK)
	if level <= 0:
		return
	var radius := BoonData.freeze_radius(level)
	var duration := BoonData.freeze_duration(level)
	for i in germs.size():
		if bool(germs[i].active) and player_pos.distance_squared_to(Vector2(germs[i].pos)) <= pow(radius + germ_specs[int(germs[i].tier)].radius, 2.0):
			germs[i].freeze_left = maxf(float(germs[i].get("freeze_left", 0.0)), duration)
	for i in debris.size():
		if bool(debris[i].active) and player_pos.distance_squared_to(Vector2(debris[i].pos)) <= pow(radius + 8.0, 2.0):
			debris[i].freeze_left = maxf(float(debris[i].get("freeze_left", 0.0)), duration)
	freeze_cooldown = BoonData.freeze_cooldown(level)
	freeze_flash_left = 0.35
	audio.play_sfx("aoe")


func _spawn_goo_patch(at: Vector2) -> bool:
	var level := _boon_level(BoonData.BoonType.GOO_TRAIL_BOOST)
	if level <= 0:
		return false
	for i in goo_patches.size():
		if bool(goo_patches[i].active):
			continue
		var duration := BoonData.goo_lifetime(level)
		goo_patches[i] = {"active": true, "pos": at, "life": duration, "duration": duration, "radius": BoonData.goo_radius(level), "phase": rng.randf_range(0.0, TAU)}
		return true
	return false


func _update_goo_patches(delta: float) -> void:
	for i in goo_patches.size():
		if not bool(goo_patches[i].active):
			continue
		goo_patches[i].life = float(goo_patches[i].life) - delta
		goo_patches[i].phase = float(goo_patches[i].phase) + delta
		if float(goo_patches[i].life) <= 0.0:
			goo_patches[i].active = false
	var germ_targets: Array[int] = []
	var debris_targets: Array[int] = []
	for i in germs.size():
		if not bool(germs[i].active) or float(germs[i].get("goo_hit_cooldown", 0.0)) > 0.0:
			continue
		if _hostile_overlaps_goo(Vector2(germs[i].pos), germ_specs[int(germs[i].tier)].radius * 0.6):
			germs[i].goo_hit_cooldown = BoonData.GOO_HIT_COOLDOWN
			germ_targets.append(i)
	for i in debris.size():
		if not bool(debris[i].active) or float(debris[i].get("goo_hit_cooldown", 0.0)) > 0.0:
			continue
		if _hostile_overlaps_goo(Vector2(debris[i].pos), 8.0):
			debris[i].goo_hit_cooldown = BoonData.GOO_HIT_COOLDOWN
			debris_targets.append(i)
	for index in germ_targets:
		_damage_germ(index, 1)
	for index in debris_targets:
		_destroy_debris(index)


func _hostile_overlaps_goo(at: Vector2, hostile_radius: float) -> bool:
	for patch in goo_patches:
		if bool(patch.active) and at.distance_squared_to(Vector2(patch.pos)) <= pow(float(patch.radius) + hostile_radius, 2.0):
			return true
	return false


func _spawn_projectile(at: Vector2, direction: Vector2, speed: float, life: float, bounces: int, owner: int, inherited_velocity: Vector2 = Vector2.ZERO, damage: int = 1) -> bool:
	for i in pellets.size():
		if bool(pellets[i].active):
			continue
		pellets[i] = {
			"active": true,
			"pos": at,
			"vel": direction.normalized() * speed + inherited_velocity,
			"life": life,
			"bounces": bounces,
			"owner": owner,
			"damage": damage,
		}
		return true
	return false


func _update_pellets(delta: float) -> void:
	for i in pellets.size():
		if not bool(pellets[i].active):
			continue
		var p := pellets[i]
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


func _update_germs(delta: float) -> void:
	var speed_mult := GameMath.threat_speed_multiplier(run_time)
	for i in germs.size():
		if not bool(germs[i].active):
			continue
		var g := germs[i]
		g.hitter_cooldown = maxf(0.0, float(g.hitter_cooldown) - delta)
		g.goo_hit_cooldown = maxf(0.0, float(g.get("goo_hit_cooldown", 0.0)) - delta)
		g.hit_reaction_left = maxf(0.0, float(g.get("hit_reaction_left", 0.0)) - delta)
		var frozen := float(g.get("freeze_left", 0.0)) > 0.0
		g.freeze_left = maxf(0.0, float(g.get("freeze_left", 0.0)) - delta)
		var simulation_delta := delta
		if frozen:
			simulation_delta *= 0.5 if _is_boss_tier(int(g.tier)) else 0.0
		if _is_boss_tier(int(g.tier)):
			g = _update_boss_movement(g, simulation_delta)
		else:
			var target_dir := (player_pos - Vector2(g.pos)).normalized()
			var current_speed := Vector2(g.vel).length()
			var wanted := target_dir * current_speed
			g.vel = Vector2(g.vel).lerp(wanted, minf(1.0, simulation_delta * 0.18))
			g.pos += Vector2(g.vel) * speed_mult * simulation_delta
		g.phase = float(g.phase) + simulation_delta
		var spec := germ_specs[int(g.tier)]
		var edge := Vector2(g.pos) - arena_center
		if edge.length() + spec.radius > arena_radius:
			var normal := edge.normalized()
			g.pos = arena_center + normal * (arena_radius - spec.radius)
			if _is_boss_tier(int(g.tier)) and int(g.dash_phase) == BossDashPhase.DASH:
				g.dash_phase = BossDashPhase.CHASE
				g.dash_timer = GameMath.BOSS_DASH_COOLDOWN
				g.vel = -normal * float(g.move_speed)
			else:
				g.vel = Vector2(g.vel).bounce(normal)
		germs[i] = g


func _is_boss_tier(tier: int) -> bool:
	return tier == GermData.GermTier.BOSS or tier == GermData.GermTier.BOSS_2 or tier == GermData.GermTier.BOSS_3


func _boss_has_volley(tier: int) -> bool:
	return tier == GermData.GermTier.BOSS_2 or tier == GermData.GermTier.BOSS_3


func _boss_has_ring(tier: int) -> bool:
	return tier == GermData.GermTier.BOSS_3


func _update_boss_movement(germ: Dictionary, delta: float) -> Dictionary:
	var g := germ
	var tier := int(g.tier)
	match int(g.dash_phase):
		BossDashPhase.WARNING:
			g.vel = Vector2.ZERO
			g.dash_timer = float(g.dash_timer) - delta
			if float(g.dash_timer) <= 0.0:
				g.dash_phase = BossDashPhase.DASH
				g.dash_timer = GameMath.BOSS_DASH_SECONDS
				g.vel = Vector2(g.dash_direction) * GameMath.BOSS_DASH_SPEED
		BossDashPhase.DASH:
			g.pos += Vector2(g.dash_direction) * GameMath.BOSS_DASH_SPEED * delta
			g.dash_timer = float(g.dash_timer) - delta
			if float(g.dash_timer) <= 0.0:
				g.dash_phase = BossDashPhase.CHASE
				g.dash_timer = GameMath.BOSS_DASH_COOLDOWN
				g.vel = Vector2(g.dash_direction) * float(g.move_speed)
		BossDashPhase.VOLLEY_WARNING:
			g.vel = Vector2.ZERO
			g.volley_timer = float(g.volley_timer) - delta
			if float(g.volley_timer) <= 0.0:
				_spawn_boss_volley(Vector2(g.pos), float(g.volley_rotation), tier)
				g.dash_phase = BossDashPhase.CHASE
				g.volley_timer = GameMath.BOSS_VOLLEY_COOLDOWN
		BossDashPhase.RING_WARNING:
			g.vel = Vector2.ZERO
			g.ring_timer = float(g.ring_timer) - delta
			if float(g.ring_timer) <= 0.0:
				g.dash_phase = BossDashPhase.RING_ACTIVE
				g.ring_timer = GameMath.BOSS_RING_ACTIVE_SECONDS
				g.ring_hit_player = false
				audio.play_sfx("aoe")
		BossDashPhase.RING_ACTIVE:
			g.vel = Vector2.ZERO
			var previous_radius := _boss_ring_radius(float(g.ring_timer))
			g.ring_timer = maxf(0.0, float(g.ring_timer) - delta)
			var next_radius := _boss_ring_radius(float(g.ring_timer))
			if not bool(g.ring_hit_player) and _boss_ring_swept_hits_player(g, previous_radius, next_radius):
				if _damage_player("Contracting ring"):
					g.ring_hit_player = true
			if float(g.ring_timer) <= 0.0:
				g.dash_phase = BossDashPhase.CHASE
				g.ring_timer = GameMath.BOSS_RING_COOLDOWN
				g.ring_hit_player = false
		_:
			g.dash_timer = float(g.dash_timer) - delta
			if _boss_has_volley(tier):
				g.volley_timer = float(g.volley_timer) - delta
			if _boss_has_ring(tier):
				g.ring_timer = float(g.ring_timer) - delta
			var target_dir := (player_pos - Vector2(g.pos)).normalized()
			var wanted := target_dir * float(g.move_speed)
			g.vel = Vector2(g.vel).lerp(wanted, minf(1.0, delta * 0.7))
			g.pos += Vector2(g.vel) * delta
			if float(g.dash_timer) <= 0.0:
				g.dash_phase = BossDashPhase.WARNING
				g.dash_timer = GameMath.BOSS_DASH_WARNING_SECONDS
				g.dash_direction = target_dir
				g.vel = Vector2.ZERO
			elif _boss_has_volley(tier) and float(g.volley_timer) <= 0.0:
				g.dash_phase = BossDashPhase.VOLLEY_WARNING
				g.volley_timer = GameMath.BOSS_VOLLEY_WARNING_SECONDS
				g.volley_rotation = rng.randf_range(0.0, TAU)
				g.vel = Vector2.ZERO
			elif _boss_has_ring(tier) and float(g.ring_timer) <= 0.0:
				g.dash_phase = BossDashPhase.RING_WARNING
				g.ring_timer = GameMath.BOSS_RING_WARNING_SECONDS
				g.ring_angle = (player_pos - arena_center).angle()
				g.ring_hit_player = false
				g.vel = Vector2.ZERO
	return g


func _boss_ring_radius(seconds_left: float) -> float:
	return arena_radius * clampf(seconds_left / GameMath.BOSS_RING_ACTIVE_SECONDS, 0.0, 1.0)


func _boss_ring_swept_hits_player(germ: Dictionary, previous_radius: float, next_radius: float) -> bool:
	var player_from_center := player_pos - arena_center
	var collision_band := PLAYER_RADIUS + GameMath.BOSS_RING_THICKNESS * 0.5
	if player_from_center.length() > previous_radius + collision_band or player_from_center.length() < next_radius - collision_band:
		return false
	var angle_from_wedge := absf(wrapf(player_from_center.angle() - float(germ.ring_angle), -PI, PI))
	return angle_from_wedge > GameMath.BOSS_RING_SAFE_WEDGE_RADIANS * 0.5


func _spawn_boss_volley(at: Vector2, rotation: float, boss_tier: int = GermData.GermTier.BOSS_2) -> void:
	var spawn_radius := germ_specs[boss_tier].radius + 12.0
	for shot in GameMath.BOSS_VOLLEY_COUNT:
		var angle := rotation + TAU * float(shot) / float(GameMath.BOSS_VOLLEY_COUNT)
		var direction := Vector2.RIGHT.rotated(angle)
		var spawn_position := at + direction * spawn_radius
		var from_center := spawn_position - arena_center
		if from_center.length() + 10.0 > arena_radius:
			spawn_position = arena_center + from_center.normalized() * (arena_radius - 10.0)
		for i in debris.size():
			if bool(debris[i].active):
				continue
			debris[i] = {
				"active": true,
				"pos": spawn_position,
				"vel": direction * GameMath.BOSS_VOLLEY_SPEED,
				"life": GameMath.BOSS_VOLLEY_LIFETIME,
				"angle": angle,
				"spin": rng.randf_range(-6.0, 6.0),
				"hitter_cooldown": 0.0,
				"goo_hit_cooldown": 0.0,
				"freeze_left": 0.0,
				"source": DebrisSource.BOSS_VOLLEY,
				"bounces": GameMath.BOSS_VOLLEY_BOUNCES,
			}
			break
	audio.play_sfx("mine")


func _update_debris(delta: float) -> void:
	for i in debris.size():
		if not bool(debris[i].active):
			continue
		var d := debris[i]
		d.hitter_cooldown = maxf(0.0, float(d.hitter_cooldown) - delta)
		d.goo_hit_cooldown = maxf(0.0, float(d.get("goo_hit_cooldown", 0.0)) - delta)
		var frozen := float(d.get("freeze_left", 0.0)) > 0.0
		d.freeze_left = maxf(0.0, float(d.get("freeze_left", 0.0)) - delta)
		var simulation_delta := 0.0 if frozen else delta
		d.pos += Vector2(d.vel) * simulation_delta
		d.angle = float(d.angle) + float(d.spin) * simulation_delta
		d.life = float(d.life) - simulation_delta
		var edge := Vector2(d.pos) - arena_center
		if edge.length() + 10.0 > arena_radius:
			var remaining_bounces := int(d.get("bounces", -1))
			if remaining_bounces == 0:
				d.active = false
			else:
				var normal := edge.normalized()
				d.pos = arena_center + normal * (arena_radius - 10.0)
				d.vel = Vector2(d.vel).bounce(normal) * 0.82
				if remaining_bounces > 0:
					d.bounces = remaining_bounces - 1
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
				_damage_germ(gi, int(pellets[pi].get("damage", 1)))
				hit = true
				break
		if hit:
			continue
		for di in debris.size():
			if not bool(debris[di].active):
				continue
			if pellet_pos.distance_squared_to(Vector2(debris[di].pos)) <= 225.0:
				pellets[pi].active = false
				_destroy_debris(di)
				break


func _damage_germ(index: int, amount: int) -> bool:
	if index < 0 or index >= germs.size() or not bool(germs[index].active):
		return false
	germs[index].hp = int(germs[index].hp) - amount
	if int(germs[index].hp) <= 0:
		_destroy_germ(index)
	else:
		if not bool(saved.get("reduced_motion", false)):
			germs[index].hit_reaction_left = GERM_HIT_REACTION_SECONDS
		audio.play_sfx("impact")
	return true


func _destroy_debris(index: int) -> bool:
	if index < 0 or index >= debris.size() or not bool(debris[index].active):
		return false
	var at := Vector2(debris[index].pos)
	debris[index].active = false
	_award_kill(10, at)
	return true


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
		var remaining_level := _effective_item_level(ItemData.ItemType.AOE)
		aoe_timer = ItemData.aoe_interval(remaining_level)
		aoe_warning_active = false
		aoe_flash_left = 0.22 if remaining_level > 0 else 0.0
		audio.play_sfx("aoe")


func _resolve_hostile_hits() -> void:
	if _player_damage_blocked():
		return
	for g in germs:
		if not bool(g.active):
			continue
		var spec := germ_specs[int(g.tier)]
		if player_pos.distance_squared_to(Vector2(g.pos)) <= pow(PLAYER_RADIUS + spec.radius * 0.82, 2.0):
			_damage_player("Germ contact")
			return
	for d in debris:
		if bool(d.active) and player_pos.distance_squared_to(Vector2(d.pos)) <= pow(PLAYER_RADIUS + 8.0, 2.0):
			_damage_player("Debris contact")
			return


func _spawn_germ(tier: int, position_override: Variant = null, topic_override: int = -1, stance_override: int = -1, dialogue_priority: bool = false, speed_multiplier: float = 1.0) -> bool:
	var first_index := 0
	var end_index := GameMath.MAX_REGULAR_GERMS
	if tier == GermData.GermTier.ELITE:
		first_index = GameMath.ELITE_GERM_INDEX
		end_index = GameMath.ELITE_GERM_INDEX + 1
	elif _is_boss_tier(tier):
		first_index = GameMath.BOSS_GERM_INDEX
		end_index = GameMath.BOSS_GERM_INDEX + 1
	for i in range(first_index, end_index):
		if bool(germs[i].active):
			continue
		var spec := germ_specs[tier]
		var angle := rng.randf_range(0.0, TAU)
		var at := _spawn_position(tier, angle)
		if position_override != null:
			at = Vector2(position_override)
		var speed := rng.randf_range(spec.speed_min, spec.speed_max) * speed_multiplier
		var direction := (player_pos - at).normalized().rotated(rng.randf_range(-0.5, 0.5))
		var topic_id := -1
		var stance := -1
		if tier <= GermData.GermTier.SMALL:
			topic_id = topic_override if topic_override >= 0 else rng.randi_range(0, CULTURE_WAR_DIALOGUE.topic_count() - 1)
			if tier != GermData.GermTier.LARGE:
				stance = stance_override if stance_override >= 0 else rng.randi_range(CULTURE_WAR_DIALOGUE.STANCE_A, CULTURE_WAR_DIALOGUE.STANCE_B)
		germs[i] = {"active": true, "tier": tier, "pos": at, "vel": direction * speed, "move_speed": speed, "hp": spec.hp, "phase": rng.randf_range(0.0, TAU), "hitter_cooldown": 0.0, "goo_hit_cooldown": 0.0, "freeze_left": 0.0, "hit_reaction_left": 0.0, "topic_id": topic_id, "stance": stance, "dash_phase": BossDashPhase.CHASE, "dash_timer": GameMath.BOSS_INITIAL_DASH_DELAY if _is_boss_tier(tier) else INF, "dash_direction": Vector2.ZERO, "volley_timer": GameMath.BOSS_VOLLEY_INITIAL_DELAY if _boss_has_volley(tier) else INF, "volley_rotation": 0.0, "ring_timer": GameMath.BOSS_RING_INITIAL_DELAY if _boss_has_ring(tier) else INF, "ring_angle": 0.0, "ring_hit_player": false}
		if _is_boss_tier(tier):
			boss_encounter_phase = BossEncounterPhase.ACTIVE
		_try_show_germ_dialogue(i, dialogue_priority or tier == GermData.GermTier.LARGE or tier == GermData.GermTier.ELITE or _is_boss_tier(tier))
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
	popups.append({"pos": player_pos, "text": popup_text, "life": 1.2, "duration": 1.2, "item_type": item_type, "occlusion_opacity": 1.0})
	audio.play_sfx("item_pickup")
	emit_signal("item_collected", item_type, collected_level)


func _start_overcharge(item_type: int) -> void:
	overcharge_item = item_type
	overcharge_left = ItemData.OVERCHARGE_SECONDS
	if item_type == ItemData.ItemType.AOE:
		aoe_timer = minf(aoe_timer, ItemData.aoe_interval(ItemData.OVERCHARGE_LEVEL))
	elif item_type == ItemData.ItemType.LEAVE_BEHIND:
		mine_timer = minf(mine_timer, ItemData.mine_interval(ItemData.OVERCHARGE_LEVEL))
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
			"goo_hit_cooldown": 0.0,
			"freeze_left": 0.0,
			"source": DebrisSource.REGULAR,
			"bounces": -1,
		}
		made += 1
		if made >= count:
			return


func _destroy_germ(index: int) -> void:
	var tier := int(germs[index].tier)
	var at := Vector2(germs[index].pos)
	var topic_id := int(germs[index].get("topic_id", -1))
	var stance := int(germs[index].get("stance", -1))
	germs[index].active = false
	germs[index].hit_reaction_left = 0.0
	germs[index].ring_timer = INF
	germs[index].ring_angle = 0.0
	germs[index].ring_hit_player = false
	_remove_pending_dialogue(index)
	if dialogue_speaker == DialogueSpeaker.GERM and dialogue_germ_index == index:
		_clear_dialogue_bubble()
	var spec := germ_specs[tier]
	_award_kill(spec.score, at)
	var split := GameMath.split_result(tier)
	for child in int(split.children):
		var offset := Vector2.RIGHT.rotated(TAU * float(child) / maxf(1.0, float(split.children)) + rng.randf_range(-0.25, 0.25)) * 16.0
		var child_stance := child if tier == GermData.GermTier.LARGE else stance
		_spawn_germ(int(split.child_tier), at + offset, topic_id, child_stance, true, SPLIT_CHILD_SPEED_MULTIPLIER)
	_spawn_debris(at, int(split.fragments))
	if tier == GermData.GermTier.ELITE:
		_queue_item_warning(at)
	elif _is_boss_tier(tier):
		_complete_boss_encounter()
	audio.play_sfx("split")
	if not bool(saved.reduced_motion):
		screen_shake = maxf(screen_shake, 0.34)


func _award_kill(base: int, at: Vector2) -> void:
	combo = GameMath.combo_after_kill(combo, run_time - last_kill_time)
	last_kill_time = run_time
	var points := GameMath.awarded_score(base, combo, BoonData.point_multiplier(_boon_level(BoonData.BoonType.POINT_MULTIPLIER)))
	score += points
	popups.append({"pos": at, "text": "+%d%s" % [points, "   %dx" % combo if combo > 1 else ""], "life": 0.8, "duration": 0.8, "item_type": -1, "occlusion_opacity": 1.0})
	emit_signal("score_changed", score)
	emit_signal("combo_changed", combo)
	_try_begin_next_boss_encounter()


func _begin_boss_cleanup() -> void:
	active_boss_stage = bosses_defeated
	boss_encounter_phase = BossEncounterPhase.CLEANUP
	spawn_warnings.clear()
	popups.append({"pos": player_pos, "text": "%s  //  CLEAR THE DISH" % _format_score_threshold(_boss_threshold_for_stage(active_boss_stage)), "life": 1.8, "duration": 1.8, "item_type": -1, "occlusion_opacity": 1.0, "color": ORANGE_HOT})
	audio.play_sfx("elite_spawn")


func _try_begin_next_boss_encounter() -> void:
	if boss_encounter_phase != BossEncounterPhase.INACTIVE or bosses_defeated >= GameMath.BOSS_STAGE_COUNT:
		return
	if score >= _boss_threshold_for_stage(bosses_defeated):
		_begin_boss_cleanup()


func _boss_threshold_for_stage(stage: int) -> int:
	match stage:
		1:
			return GameMath.BOSS_2_SCORE_THRESHOLD
		2:
			return GameMath.BOSS_3_SCORE_THRESHOLD
	return GameMath.BOSS_SCORE_THRESHOLD


func _boss_tier_for_stage(stage: int) -> int:
	match stage:
		1:
			return GermData.GermTier.BOSS_2
		2:
			return GermData.GermTier.BOSS_3
	return GermData.GermTier.BOSS


func _format_score_threshold(value: int) -> String:
	return "%d,%03d" % [value / 1000, value % 1000]


func _update_boss_encounter() -> void:
	if boss_encounter_phase != BossEncounterPhase.CLEANUP:
		return
	if _active_germ_count() > 0 or _active_debris_count() > 0:
		return
	boss_encounter_phase = BossEncounterPhase.WARNING
	_queue_spawn_warning(_boss_tier_for_stage(active_boss_stage))
	audio.play_sfx("elite_spawn")


func _complete_boss_encounter() -> void:
	var completed_stage := active_boss_stage
	_reset_abilities_for_boss_reward()
	_clear_transient_boon_effects()
	if completed_stage == 0:
		base_weapon_damage = 2
		base_weapon_fire_rate = GameMath.BASE_PLAYER_FIRE_RATE
	elif completed_stage >= 1:
		_clear_boss_volley_debris()
		base_weapon_damage = 2
		base_weapon_fire_rate = GameMath.OVERCLOCKED_PLAYER_FIRE_RATE
		if completed_stage == 2:
			boss_health_bonus = 1
	_restore_player_health()
	fire_cooldown = minf(fire_cooldown, _player_fire_interval())
	bosses_defeated = maxi(bosses_defeated, completed_stage + 1)
	boon_reward_stage = completed_stage
	active_boss_stage = -1
	boss_encounter_phase = BossEncounterPhase.BOON_SELECTION
	player_velocity = Vector2.ZERO
	_begin_boon_selection()
	var reward_text := "ABILITIES RESET  //  BASE WEAPON MK II"
	if completed_stage == 1:
		reward_text = "ABILITIES RESET  //  WEAPON OVERCLOCKED"
	elif completed_stage == 2:
		reward_text = "ABILITIES RESET  //  MAX HEALTH +1"
	popups.append({"pos": player_pos, "text": reward_text, "life": 2.4, "duration": 2.4, "item_type": -1, "occlusion_opacity": 1.0, "color": LIME_DARK})
	audio.play_sfx("item_pickup")


func _begin_boon_selection() -> void:
	boon_selection_lock_left = BoonData.CHOICE_LOCK_SECONDS
	_clear_dialogue_bubble()
	var offered := _generate_boon_offer()
	var choice_radius := maxf(0.0, minf(120.0, arena_radius - 48.0))
	for i in boon_choices.size():
		var angle := -PI * 0.5 + TAU * float(i) / float(BoonData.CHOICE_COUNT)
		boon_choices[i] = {
			"active": i < offered.size(),
			"boon_type": offered[i] if i < offered.size() else BoonData.NO_BOON,
			"pos": arena_center + Vector2.RIGHT.rotated(angle) * choice_radius,
			"phase": rng.randf_range(0.0, TAU),
		}
	popups.append({"pos": arena_center + Vector2(0.0, arena_radius * 0.68), "text": "CHOOSE ONE BOON", "life": 2.0, "duration": 2.0, "item_type": -1, "occlusion_opacity": 1.0, "color": PURPLE})


func _generate_boon_offer() -> Array[int]:
	var candidates: Array[int] = []
	for boon_type in BoonData.BoonType.size():
		if _boon_level(boon_type) >= BoonData.level_cap(boon_type):
			continue
		if boon_type == BoonData.BoonType.SPEED_BOOSTS and (active_space_boon == BoonData.BoonType.INVINCIBILITY or active_space_boon == BoonData.BoonType.FREEZE_AOE_SHOCK):
			continue
		candidates.append(boon_type)
	for i in range(candidates.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, i)
		var held := candidates[i]
		candidates[i] = candidates[swap_index]
		candidates[swap_index] = held
	var offered: Array[int] = []
	for i in mini(BoonData.CHOICE_COUNT, candidates.size()):
		offered.append(candidates[i])
	return offered


func _collect_boon_choice(index: int) -> bool:
	if boss_encounter_phase != BossEncounterPhase.BOON_SELECTION or boon_selection_lock_left > 0.0:
		return false
	if index < 0 or index >= boon_choices.size() or not bool(boon_choices[index].active):
		return false
	var boon_type := int(boon_choices[index].boon_type)
	boon_levels[boon_type] = mini(BoonData.level_cap(boon_type), boon_levels[boon_type] + 1)
	if BoonData.is_space_boon(boon_type):
		active_space_boon = boon_type
	elif boon_type == BoonData.BoonType.MAX_HEALTH:
		_restore_player_health()
	for i in boon_choices.size():
		boon_choices[i].active = false
	var level := boon_levels[boon_type]
	popups.append({"pos": player_pos, "text": "%s  //  LVL %d" % [BoonData.display_name(boon_type), level], "life": 2.0, "duration": 2.0, "item_type": -1, "occlusion_opacity": 1.0, "color": BoonData.color(boon_type)})
	audio.play_sfx("item_pickup")
	emit_signal("boon_collected", boon_type, level)
	_finish_boon_selection()
	return true


func _finish_boon_selection() -> void:
	boon_selection_lock_left = 0.0
	boon_reward_stage = -1
	boss_encounter_phase = BossEncounterPhase.COMPLETED if bosses_defeated >= GameMath.BOSS_STAGE_COUNT else BossEncounterPhase.INACTIVE
	spawn_timer = GameMath.spawn_interval(run_time)
	elite_timer = GameMath.ELITE_SPAWN_INTERVAL
	_try_begin_next_boss_encounter()


func _clear_transient_boon_effects() -> void:
	boost_active = false
	boost_charge = 1.0
	boost_delay = 0.0
	dash_left = 0.0
	dash_cooldown = 0.0
	dash_direction = Vector2.ZERO
	invincibility_left = 0.0
	invincibility_cooldown = 0.0
	freeze_cooldown = 0.0
	freeze_flash_left = 0.0
	goo_emit_timer = 0.0
	beam_charge = 0.0
	beam_active_left = 0.0
	beam_tick_left = 0.0
	for i in goo_patches.size():
		goo_patches[i].active = false
	for i in germs.size():
		germs[i].freeze_left = 0.0
		germs[i].goo_hit_cooldown = 0.0
	for i in debris.size():
		debris[i].freeze_left = 0.0
		debris[i].goo_hit_cooldown = 0.0


func _clear_boss_volley_debris() -> void:
	for i in debris.size():
		if bool(debris[i].active) and int(debris[i].get("source", DebrisSource.REGULAR)) == DebrisSource.BOSS_VOLLEY:
			debris[i].active = false


func _reset_abilities_for_boss_reward() -> void:
	for i in item_levels.size():
		item_levels[i] = 0
	overcharge_item = -1
	overcharge_left = 0.0
	hitter_angle = 0.0
	aoe_timer = INF
	aoe_warning_active = false
	aoe_flash_left = 0.0
	mine_timer = INF
	for i in turrets.size():
		turrets[i].active = false
	for i in mines.size():
		mines[i].active = false
	for i in pickups.size():
		pickups[i].active = false
	for i in item_warnings.size():
		item_warnings[i].active = false
	for i in pellets.size():
		if bool(pellets[i].active) and int(pellets[i].owner) == ProjectileOwner.TURRET:
			pellets[i].active = false
	emit_signal("item_overcharge_changed", -1, 0.0)


func _normal_spawning_enabled() -> bool:
	return boss_encounter_phase == BossEncounterPhase.INACTIVE or boss_encounter_phase == BossEncounterPhase.COMPLETED


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
		if bool(g.active) and int(g.tier) <= GermData.GermTier.SMALL:
			count += 1
	return count


func _pending_regular_germ_count() -> int:
	var count := 0
	for warning in spawn_warnings:
		if int(warning.tier) <= GermData.GermTier.SMALL:
			count += 1
	return count


func _active_debris_count() -> int:
	var count := 0
	for fragment in debris:
		if bool(fragment.active):
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
		var target_opacity := _overlay_target_opacity(_popup_bounds(popups[i]), -1, false, WORLD_TEXT_OCCLUDED_OPACITY)
		popups[i].occlusion_opacity = move_toward(float(popups[i].get("occlusion_opacity", 1.0)), target_opacity, delta * OPACITY_TRANSITION_SPEED)
		if float(popups[i].life) <= 0.0:
			popups.remove_at(i)


func _update_overlay_opacities(delta: float) -> void:
	if state == AppState.MENU or state == AppState.HOW_TO or state == AppState.SETTINGS:
		logo_hud_opacity = move_toward(logo_hud_opacity, 1.0, delta * OPACITY_TRANSITION_SPEED)
		score_hud_opacity = move_toward(score_hud_opacity, 1.0, delta * OPACITY_TRANSITION_SPEED)
		timer_hud_opacity = move_toward(timer_hud_opacity, 1.0, delta * OPACITY_TRANSITION_SPEED)
		combo_hud_opacity = move_toward(combo_hud_opacity, 1.0, delta * OPACITY_TRANSITION_SPEED)
		boost_hud_opacity = move_toward(boost_hud_opacity, 1.0, delta * OPACITY_TRANSITION_SPEED)
		health_hud_opacity = move_toward(health_hud_opacity, 1.0, delta * OPACITY_TRANSITION_SPEED)
		dialogue_occlusion_opacity = move_toward(dialogue_occlusion_opacity, 1.0, delta * OPACITY_TRANSITION_SPEED)
		return
	logo_hud_opacity = move_toward(logo_hud_opacity, _overlay_target_opacity(_gameplay_logo_bounds()), delta * OPACITY_TRANSITION_SPEED)
	score_hud_opacity = move_toward(score_hud_opacity, _overlay_target_opacity(_score_bounds()), delta * OPACITY_TRANSITION_SPEED)
	timer_hud_opacity = move_toward(timer_hud_opacity, _timer_opacity(), delta * OPACITY_TRANSITION_SPEED)
	combo_hud_opacity = move_toward(combo_hud_opacity, _overlay_target_opacity(_combo_bounds()), delta * OPACITY_TRANSITION_SPEED)
	boost_hud_opacity = move_toward(boost_hud_opacity, _overlay_target_opacity(_boost_bounds()), delta * OPACITY_TRANSITION_SPEED)
	health_hud_opacity = move_toward(health_hud_opacity, _overlay_target_opacity(_health_bounds()), delta * OPACITY_TRANSITION_SPEED)
	var dialogue_target := 1.0
	if dialogue_speaker != DialogueSpeaker.NONE and not dialogue_text.is_empty():
		var speaker_pos := _dialogue_world_to_screen(player_pos)
		var speaker_radius := PLAYER_RADIUS
		var ignored_germ := -1
		var ignore_player := dialogue_speaker == DialogueSpeaker.PLAYER
		if dialogue_speaker == DialogueSpeaker.GERM and dialogue_germ_index >= 0 and dialogue_germ_index < germs.size() and bool(germs[dialogue_germ_index].active):
			speaker_pos = _dialogue_world_to_screen(Vector2(germs[dialogue_germ_index].pos))
			speaker_radius = germ_specs[int(germs[dialogue_germ_index].tier)].radius
			ignored_germ = dialogue_germ_index
		speaker_radius *= _dialogue_camera_zoom() * _dialogue_speaker_scale(ignored_germ)
		var layout := _dialogue_layout(speaker_pos, dialogue_text, speaker_radius)
		dialogue_target = _overlay_target_opacity(Rect2(layout.rect), ignored_germ, ignore_player, WORLD_TEXT_OCCLUDED_OPACITY)
	dialogue_occlusion_opacity = move_toward(dialogue_occlusion_opacity, dialogue_target, delta * OPACITY_TRANSITION_SPEED)


func _overlay_target_opacity(rect: Rect2, ignored_germ_index: int = -1, ignore_player: bool = false, occluded_opacity: float = HUD_OCCLUDED_OPACITY) -> float:
	var zoom := _dialogue_camera_zoom()
	var player_screen_pos := _dialogue_world_to_screen(player_pos)
	if not ignore_player and _circle_intersects_rect(player_screen_pos, PLAYER_RADIUS * zoom * _dialogue_speaker_scale(), rect):
		return occluded_opacity
	for i in germs.size():
		if i == ignored_germ_index or not bool(germs[i].active):
			continue
		var radius := germ_specs[int(germs[i].tier)].radius * zoom * _dialogue_speaker_scale(i)
		var germ_screen_pos := _dialogue_world_to_screen(Vector2(germs[i].pos))
		if _circle_intersects_rect(germ_screen_pos, radius, rect):
			return occluded_opacity
	return 1.0


func _popup_bounds(popup: Dictionary) -> Rect2:
	var font_size := 18
	var text := str(popup.text)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var baseline := Vector2(popup.pos)
	return Rect2(
		Vector2(baseline.x - width * 0.5 - 3.0, baseline.y - font.get_ascent(font_size) - 3.0),
		Vector2(width + 6.0, font.get_height(font_size) + 6.0)
	)


func _update_dialogue(delta: float) -> void:
	dialogue_cooldown = maxf(0.0, dialogue_cooldown - delta)
	if dialogue_speaker == DialogueSpeaker.GERM:
		if dialogue_germ_index < 0 or dialogue_germ_index >= germs.size() or not bool(germs[dialogue_germ_index].active):
			_clear_dialogue_bubble()
	if _dialogue_cutscene_active():
		_update_dialogue_cutscene(delta)
		if _dialogue_cutscene_active():
			return
	if dialogue_cooldown > 0.0:
		return
	if run_time >= next_player_dialogue_time:
		_show_player_dialogue()
	elif dialogue_speaker == DialogueSpeaker.NONE:
		_show_next_pending_dialogue()


func _update_dialogue_cutscene(delta: float) -> void:
	dialogue_life = maxf(0.0, dialogue_life - delta)
	var remaining := maxf(0.0, delta)
	while remaining > 0.0 and _dialogue_cutscene_active():
		var phase_duration := _dialogue_phase_duration()
		var phase_remaining := maxf(0.0, phase_duration - dialogue_phase_time)
		var step := minf(remaining, phase_remaining)
		dialogue_phase_time += step
		remaining -= step
		if dialogue_cutscene_phase == DialogueCutscenePhase.TALKING and not bool(saved.get("reduced_motion", false)):
			dialogue_visible_characters = mini(
				dialogue_text.length(),
				floori(dialogue_phase_time * dialogue_type_characters_per_second)
			)
		if dialogue_phase_time + 0.0001 < phase_duration:
			break
		match dialogue_cutscene_phase:
			DialogueCutscenePhase.ZOOM_IN:
				dialogue_cutscene_phase = DialogueCutscenePhase.TALKING
				dialogue_phase_time = 0.0
			DialogueCutscenePhase.TALKING:
				dialogue_visible_characters = dialogue_text.length()
				dialogue_cutscene_phase = DialogueCutscenePhase.ZOOM_OUT
				dialogue_phase_time = 0.0
			DialogueCutscenePhase.ZOOM_OUT:
				_clear_dialogue_bubble()
			_:
				return
		if is_zero_approx(step) and phase_duration > 0.0:
			break


func _dialogue_phase_duration() -> float:
	match dialogue_cutscene_phase:
		DialogueCutscenePhase.ZOOM_IN:
			return DIALOGUE_ZOOM_IN_SECONDS
		DialogueCutscenePhase.TALKING:
			return dialogue_talk_duration
		DialogueCutscenePhase.ZOOM_OUT:
			return DIALOGUE_ZOOM_OUT_SECONDS
	return 0.0


func _dialogue_cutscene_active() -> bool:
	return dialogue_speaker != DialogueSpeaker.NONE and dialogue_cutscene_phase != DialogueCutscenePhase.NONE


func _dialogue_phase_progress() -> float:
	return clampf(dialogue_phase_time / maxf(_dialogue_phase_duration(), 0.0001), 0.0, 1.0)


func _dialogue_ease(value: float) -> float:
	var clamped := clampf(value, 0.0, 1.0)
	return clamped * clamped * (3.0 - 2.0 * clamped)


func _dialogue_cinematic_amount() -> float:
	if not _dialogue_cutscene_active():
		return 0.0
	match dialogue_cutscene_phase:
		DialogueCutscenePhase.ZOOM_IN:
			return _dialogue_ease(_dialogue_phase_progress())
		DialogueCutscenePhase.TALKING:
			return 1.0
		DialogueCutscenePhase.ZOOM_OUT:
			return 1.0 - _dialogue_ease(_dialogue_phase_progress())
	return 0.0


func _dialogue_camera_zoom() -> float:
	if bool(saved.get("reduced_motion", false)):
		return 1.0
	return lerpf(1.0, DIALOGUE_CAMERA_SCALE, _dialogue_cinematic_amount())


func _dialogue_camera_target() -> Vector2:
	return Vector2(viewport_size.x * 0.5, viewport_size.y * 0.56)


func _dialogue_camera_origin(offset: Vector2 = Vector2.ZERO) -> Vector2:
	if not _dialogue_cutscene_active():
		return Vector2.ZERO
	var zoom := _dialogue_camera_zoom()
	return _dialogue_camera_target() - (dialogue_focus_position + offset) * zoom


func _dialogue_world_to_screen(world_position: Vector2, offset: Vector2 = Vector2.ZERO) -> Vector2:
	if not _dialogue_cutscene_active():
		return world_position + offset
	return _dialogue_camera_origin(offset) + (world_position + offset) * _dialogue_camera_zoom()


func _dialogue_speaker_scale(germ_index: int = -1) -> float:
	if not _dialogue_cutscene_active() or bool(saved.get("reduced_motion", false)):
		return 1.0
	var is_speaker := dialogue_speaker == DialogueSpeaker.PLAYER and germ_index < 0
	if dialogue_speaker == DialogueSpeaker.GERM:
		is_speaker = germ_index == dialogue_germ_index
	if not is_speaker:
		return 1.0
	var elapsed := dialogue_phase_time
	if dialogue_cutscene_phase == DialogueCutscenePhase.TALKING:
		elapsed += DIALOGUE_ZOOM_IN_SECONDS
	elif dialogue_cutscene_phase == DialogueCutscenePhase.ZOOM_OUT:
		elapsed += DIALOGUE_ZOOM_IN_SECONDS + dialogue_talk_duration
	var pulse := 0.5 + 0.5 * sin(elapsed * DIALOGUE_SPEAKER_PULSE_SPEED)
	return 1.0 - DIALOGUE_SPEAKER_PULSE_AMOUNT * pulse * _dialogue_cinematic_amount()


func _dialogue_bubble_alpha() -> float:
	if not _dialogue_cutscene_active():
		return 0.0
	match dialogue_cutscene_phase:
		DialogueCutscenePhase.ZOOM_IN:
			return _dialogue_ease(clampf((_dialogue_phase_progress() - 0.35) / 0.65, 0.0, 1.0))
		DialogueCutscenePhase.ZOOM_OUT:
			return 1.0 - _dialogue_ease(_dialogue_phase_progress())
	return 1.0


func _try_show_germ_dialogue(index: int, queue_if_blocked: bool = false) -> bool:
	if index < 0 or index >= germs.size() or not bool(germs[index].active):
		return false
	var tier := int(germs[index].tier)
	var uses_elite_voice := tier == GermData.GermTier.ELITE or _is_boss_tier(tier)
	if dialogue_speaker != DialogueSpeaker.NONE or dialogue_cooldown > 0.0:
		if queue_if_blocked:
			_queue_pending_dialogue(index)
		return false
	var line := ""
	if uses_elite_voice:
		line = CULTURE_WAR_DIALOGUE.elite_line(rng.randi())
	else:
		line = CULTURE_WAR_DIALOGUE.regular_line(
			int(germs[index].topic_id),
			int(germs[index].stance),
			_dialogue_intensity(tier),
			rng.randi()
		)
	_show_dialogue(DialogueSpeaker.GERM, index, line)
	return true


func _queue_pending_dialogue(index: int) -> void:
	if index in pending_dialogue_germ_indices:
		return
	if index >= 0 and index < germs.size() and bool(germs[index].active) and (int(germs[index].tier) == GermData.GermTier.ELITE or _is_boss_tier(int(germs[index].tier))):
		var previous_first := pending_dialogue_germ_indices[0]
		pending_dialogue_germ_indices[0] = index
		if previous_first >= 0:
			pending_dialogue_germ_indices[1] = previous_first
		return
	for i in pending_dialogue_germ_indices.size():
		if pending_dialogue_germ_indices[i] < 0:
			pending_dialogue_germ_indices[i] = index
			return


func _show_next_pending_dialogue() -> void:
	for i in pending_dialogue_germ_indices.size():
		var index := pending_dialogue_germ_indices[i]
		pending_dialogue_germ_indices[i] = -1
		if index >= 0 and index < germs.size() and bool(germs[index].active) and _try_show_germ_dialogue(index):
			return


func _remove_pending_dialogue(index: int) -> void:
	for i in pending_dialogue_germ_indices.size():
		if pending_dialogue_germ_indices[i] == index:
			pending_dialogue_germ_indices[i] = -1


func _show_player_dialogue() -> void:
	_show_dialogue(
		DialogueSpeaker.PLAYER,
		-1,
		CULTURE_WAR_DIALOGUE.player_line(rng.randi())
	)
	next_player_dialogue_time = run_time + rng.randf_range(PLAYER_DIALOGUE_MIN_INTERVAL, PLAYER_DIALOGUE_MAX_INTERVAL)


func _dialogue_duration_for_text(text: String) -> float:
	var word_count := maxi(1, text.split(" ", false).size())
	var extra_words := maxi(0, word_count - DIALOGUE_BASE_WORD_COUNT)
	return DIALOGUE_BASE_DURATION_SECONDS + float(extra_words) * DIALOGUE_EXTRA_WORD_SECONDS


func _show_dialogue(speaker: int, germ_index: int, text: String) -> void:
	dialogue_speaker = speaker
	dialogue_germ_index = germ_index
	dialogue_text = text
	dialogue_cutscene_phase = DialogueCutscenePhase.ZOOM_IN
	dialogue_phase_time = 0.0
	var duration := _dialogue_duration_for_text(text)
	var available_talk_time := maxf(0.1, duration - DIALOGUE_ZOOM_IN_SECONDS - DIALOGUE_ZOOM_OUT_SECONDS)
	dialogue_talk_duration = available_talk_time
	var type_time := maxf(0.1, dialogue_talk_duration - DIALOGUE_TYPE_HOLD_SECONDS)
	dialogue_type_characters_per_second = float(text.length()) / type_time
	dialogue_life = DIALOGUE_ZOOM_IN_SECONDS + dialogue_talk_duration + DIALOGUE_ZOOM_OUT_SECONDS
	dialogue_cooldown = DIALOGUE_START_INTERVAL_SECONDS
	dialogue_visible_characters = text.length() if bool(saved.get("reduced_motion", false)) else 0
	dialogue_focus_position = player_pos
	if speaker == DialogueSpeaker.GERM and germ_index >= 0 and germ_index < germs.size() and bool(germs[germ_index].active):
		dialogue_focus_position = Vector2(germs[germ_index].pos)


func _clear_dialogue_bubble() -> void:
	dialogue_speaker = DialogueSpeaker.NONE
	dialogue_germ_index = -1
	dialogue_text = ""
	dialogue_life = 0.0
	dialogue_cutscene_phase = DialogueCutscenePhase.NONE
	dialogue_phase_time = 0.0
	dialogue_talk_duration = 0.0
	dialogue_type_characters_per_second = 40.0
	dialogue_visible_characters = 0
	dialogue_focus_position = Vector2.ZERO
	dialogue_occlusion_opacity = 1.0


func _reset_dialogue() -> void:
	_clear_dialogue_bubble()
	dialogue_cooldown = 0.0
	next_player_dialogue_time = INF
	for i in pending_dialogue_germ_indices.size():
		pending_dialogue_germ_indices[i] = -1


func _dialogue_intensity(tier: int) -> int:
	match tier:
		GermData.GermTier.LARGE:
			return CULTURE_WAR_DIALOGUE.INTENSITY_OPENER
		GermData.GermTier.MEDIUM:
			return CULTURE_WAR_DIALOGUE.INTENSITY_MEDIUM
		_:
			return CULTURE_WAR_DIALOGUE.INTENSITY_SMALL


func _start_run() -> void:
	for i in pellets.size(): pellets[i].active = false
	for i in germs.size():
		germs[i].active = false
		germs[i].hit_reaction_left = 0.0
		germs[i].ring_timer = INF
		germs[i].ring_angle = 0.0
		germs[i].ring_hit_player = false
	for i in debris.size(): debris[i].active = false
	for i in turrets.size(): turrets[i].active = false
	for i in mines.size(): mines[i].active = false
	for i in pickups.size(): pickups[i].active = false
	for i in item_warnings.size(): item_warnings[i].active = false
	for i in item_levels.size(): item_levels[i] = 0
	for i in boon_levels.size(): boon_levels[i] = 0
	for i in boon_choices.size(): boon_choices[i].active = false
	for i in goo_patches.size(): goo_patches[i].active = false
	spawn_warnings.clear()
	popups.clear()
	_reset_dialogue()
	logo_hud_opacity = 1.0
	score_hud_opacity = 1.0
	timer_hud_opacity = 1.0
	combo_hud_opacity = 1.0
	boost_hud_opacity = 1.0
	health_hud_opacity = 1.0
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
	boss_encounter_phase = BossEncounterPhase.INACTIVE
	bosses_defeated = 0
	active_boss_stage = -1
	boon_reward_stage = -1
	boon_selection_lock_left = 0.0
	active_space_boon = BoonData.NO_BOON
	base_weapon_damage = 1
	base_weapon_fire_rate = GameMath.BASE_PLAYER_FIRE_RATE
	boss_health_bonus = 0
	boost_charge = 1.0
	boost_delay = 0.0
	boost_active = false
	player_max_health = PLAYER_BASE_HEALTH
	player_health = player_max_health
	damage_protection_left = 0.0
	dash_left = 0.0
	dash_cooldown = 0.0
	dash_direction = Vector2.ZERO
	invincibility_left = 0.0
	invincibility_cooldown = 0.0
	freeze_cooldown = 0.0
	freeze_flash_left = 0.0
	goo_emit_timer = 0.0
	beam_charge = 0.0
	beam_active_left = 0.0
	beam_tick_left = 0.0
	beam_direction = Vector2.RIGHT
	spawn_protection_left = SPAWN_PROTECTION
	fire_cooldown = 0.0
	player_pos = arena_center
	player_velocity = Vector2.ZERO
	player_facing = 0.0
	spawn_timer = GameMath.spawn_interval(0.0)
	death_reason = ""
	state = AppState.PLAYING
	next_player_dialogue_time = rng.randf_range(PLAYER_DIALOGUE_MIN_INTERVAL, PLAYER_DIALOGUE_MAX_INTERVAL)
	audio.unlock()
	audio.play_sfx("ui")
	var opening_tiers := [GermData.GermTier.LARGE, GermData.GermTier.MEDIUM, GermData.GermTier.MEDIUM, GermData.GermTier.SMALL, GermData.GermTier.SMALL]
	var opening_rotation := rng.randf_range(0.0, TAU)
	for i in opening_tiers.size():
		_queue_spawn_warning(opening_tiers[i], opening_rotation + TAU * float(i) / float(opening_tiers.size()))
	emit_signal("score_changed", score)
	emit_signal("combo_changed", combo)
	emit_signal("health_changed", player_health, player_max_health)
	emit_signal("item_overcharge_changed", -1, 0.0)
	emit_signal("pause_state_changed", false)


func _finish_run(reason: String) -> void:
	if state != AppState.PLAYING:
		return
	death_reason = reason
	state = AppState.GAME_OVER
	_clear_dialogue_bubble()
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
		3: _set_reduced_motion(not bool(saved.reduced_motion))
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
	draw_rect(Rect2(Vector2.ZERO, viewport_size), GAME_BG)
	var offset := Vector2.ZERO if _dialogue_cutscene_active() else _visual_offset()
	var camera_zoom := _dialogue_camera_zoom()
	draw_set_transform(_dialogue_camera_origin(offset), 0.0, Vector2.ONE * camera_zoom)
	var center := arena_center + offset
	_draw_playspace_backdrop(center)

	for patch in goo_patches:
		if bool(patch.active): _draw_goo_patch(patch, offset)
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
	for choice in boon_choices:
		if bool(choice.active): _draw_boon_choice(choice, offset)
	# Custom-drawn actors use painter's order: larger bodies go down first so
	# small germs and debris remain legible when threats overlap.
	for tier in GERM_VISUAL_DRAW_ORDER:
		for i in germs.size():
			if bool(germs[i].active) and int(germs[i].tier) == tier:
				_draw_germ(germs[i], offset, _dialogue_speaker_scale(i))
	for d in debris:
		if bool(d.active):
			_draw_debris(Vector2(d.pos) + offset, float(d.angle), int(d.get("source", DebrisSource.REGULAR)))
			if float(d.get("freeze_left", 0.0)) > 0.0:
				draw_arc(Vector2(d.pos) + offset, 15.0, 0.0, TAU, 24, Color(CYAN.r, CYAN.g, CYAN.b, 0.78), 2.0, true)
	for p in pellets:
		if bool(p.active):
			var upgraded_player_shot := int(p.owner) == ProjectileOwner.PLAYER and int(p.get("damage", 1)) > 1
			var pellet_color := ORANGE_HOT if upgraded_player_shot else (LIME if int(p.owner) == ProjectileOwner.PLAYER else PURPLE_SOFT)
			var pellet_radius := 7.0 if upgraded_player_shot else 5.0
			draw_circle(Vector2(p.pos) + offset, pellet_radius, pellet_color)
			draw_arc(Vector2(p.pos) + offset, pellet_radius + 1.5, 0.0, TAU, 18, WHITE if upgraded_player_shot else (LIME_DARK if int(p.owner) == ProjectileOwner.PLAYER else PURPLE), 1.5, true)
	_draw_beam(offset)
	_draw_aoe_effect(offset)
	_draw_freeze_effect(offset)
	_draw_spinning_hitters(offset)
	_draw_player(offset, _dialogue_speaker_scale())
	if not _dialogue_cutscene_active():
		_draw_reticle(get_global_mouse_position())
	for popup in popups:
		var duration := float(popup.get("duration", 0.8))
		var alpha := clampf(float(popup.life) / duration, 0.0, 1.0) * float(popup.get("occlusion_opacity", 1.0))
		var popup_color := PURPLE
		if int(popup.get("item_type", -1)) >= 0:
			popup_color = ItemData.color(int(popup.item_type))
		elif popup.has("color"):
			popup_color = Color(popup.color)
		_draw_text_centered(str(popup.text), Vector2(popup.pos) + offset, 18, Color(popup_color.r, popup_color.g, popup_color.b, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var cinematic_hud_opacity := lerpf(1.0, DIALOGUE_CINEMATIC_HUD_OPACITY, _dialogue_cinematic_amount())
	_draw_hud(cinematic_hud_opacity)
	_draw_dialogue_cinematic_frame()
	_draw_dialogue_bubble(offset)


func _draw_playspace_backdrop(center: Vector2) -> void:
	draw_circle(center, arena_radius * PLAYSPACE_RING_RADIUS_MULTIPLIER, PLAYSPACE_RING)
	draw_circle(center, arena_radius, GAME_BG)
	var shadow_width := arena_radius * DISH_INNER_SHADOW_WIDTH_MULTIPLIER
	for layer in DISH_INNER_SHADOW_LAYERS:
		var progress := float(layer + 1) / float(DISH_INNER_SHADOW_LAYERS)
		var shadow_fade := 1.0 - pow(1.0 - progress, DISH_INNER_SHADOW_FALLOFF)
		draw_circle(center, arena_radius - shadow_width * progress, GAME_BG.lerp(WHITE, shadow_fade))


func _draw_dialogue_cinematic_frame() -> void:
	var amount := _dialogue_cinematic_amount()
	if amount <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(PURPLE.r, PURPLE.g, PURPLE.b, 0.055 * amount))
	var bar_height := clampf(viewport_size.y * 0.045, 22.0, 54.0) * amount
	var bar_color := Color(DARK_MINT.r, DARK_MINT.g, DARK_MINT.b, 0.82 * amount)
	draw_rect(Rect2(Vector2.ZERO, Vector2(viewport_size.x, bar_height)), bar_color)
	draw_rect(Rect2(Vector2(0.0, viewport_size.y - bar_height), Vector2(viewport_size.x, bar_height)), bar_color)


func _draw_spawn_warning(warning: Dictionary, offset: Vector2) -> void:
	var tier := int(warning.tier)
	var spec := germ_specs[tier]
	var pos := _spawn_position(tier, float(warning.angle)) + offset
	var progress := 1.0 - clampf(float(warning.life) / float(warning.duration), 0.0, 1.0)
	var motion := 0.0 if bool(saved.get("reduced_motion", false)) else sin(progress * TAU * 3.0)
	var aura_radius := spec.radius + 18.0 + motion * 5.0
	var color := _germ_palette_color(tier)
	var ring_color := BOSS_3_CORE if tier == GermData.GermTier.BOSS_3 else (BOSS_2_CORE if tier == GermData.GermTier.BOSS_2 else (LIME if tier == GermData.GermTier.BOSS else (ORANGE_HOT if tier == GermData.GermTier.ELITE else PURPLE)))
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


func _draw_boon_choice(choice: Dictionary, offset: Vector2) -> void:
	var boon_type := int(choice.boon_type)
	var pos := Vector2(choice.pos) + offset
	var unlocked := boon_selection_lock_left <= 0.0
	var color := BoonData.color(boon_type)
	var alpha := 1.0 if unlocked else 0.36
	var pulse := 0.0
	if unlocked and not bool(saved.get("reduced_motion", false)):
		pulse = sin(float(choice.phase) * 4.0) * 3.0
	draw_circle(pos, BoonData.CHOICE_PICKUP_RADIUS + 11.0 + pulse, Color(color.r, color.g, color.b, 0.14 * alpha))
	draw_arc(pos, BoonData.CHOICE_PICKUP_RADIUS + 5.0 + pulse, 0.0, TAU, 40, Color(color.r, color.g, color.b, 0.86 * alpha), 3.0, true)
	draw_circle(pos, BoonData.CHOICE_PICKUP_RADIUS, Color(WHITE.r, WHITE.g, WHITE.b, 0.92 * alpha))
	_draw_boon_icon(boon_type, pos, 14.0, Color(color.r, color.g, color.b, alpha))
	_draw_text_centered(BoonData.display_name(boon_type), pos + Vector2(0.0, -42.0), 13, Color(PURPLE.r, PURPLE.g, PURPLE.b, alpha))
	_draw_text_centered(BoonData.control_label(boon_type), pos + Vector2(0.0, 48.0), 11, Color(DARK_MINT.r, DARK_MINT.g, DARK_MINT.b, alpha))
	if not unlocked:
		var lock_progress := 1.0 - boon_selection_lock_left / BoonData.CHOICE_LOCK_SECONDS
		draw_arc(pos, BoonData.CHOICE_PICKUP_RADIUS + 9.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(lock_progress, 0.0, 1.0), 36, PURPLE, 3.0, true)


func _draw_boon_icon(boon_type: int, pos: Vector2, size: float, color: Color) -> void:
	match boon_type:
		BoonData.BoonType.DASH_EVADE:
			draw_colored_polygon(PackedVector2Array([pos + Vector2(size, 0.0), pos + Vector2(-size, -size * 0.72), pos + Vector2(-size * 0.35, 0.0), pos + Vector2(-size, size * 0.72)]), color)
		BoonData.BoonType.SPEED_BOOSTS:
			for offset in [-5.0, 5.0]:
				draw_line(pos + Vector2(-size, offset), pos + Vector2(size, offset), color, 3.0, true)
		BoonData.BoonType.POINT_MULTIPLIER:
			_draw_text_centered("x", pos + Vector2(0.0, 6.0), 25, color)
		BoonData.BoonType.INVINCIBILITY:
			draw_arc(pos, size, 0.0, TAU, 28, color, 4.0, true)
			draw_circle(pos, size * 0.42, color)
		BoonData.BoonType.GOO_TRAIL_BOOST:
			draw_circle(pos + Vector2(-5.0, 3.0), size * 0.7, color)
			draw_circle(pos + Vector2(7.0, -4.0), size * 0.45, color)
		BoonData.BoonType.FREEZE_AOE_SHOCK:
			for angle in [0.0, PI / 3.0, PI * 2.0 / 3.0]:
				draw_line(pos - Vector2.RIGHT.rotated(angle) * size, pos + Vector2.RIGHT.rotated(angle) * size, color, 3.0, true)
		BoonData.BoonType.MOVEMENT_SPEED:
			draw_line(pos + Vector2(-size, 7.0), pos + Vector2(size, -7.0), color, 5.0, true)
			draw_circle(pos + Vector2(-size, 7.0), 4.0, color)
		BoonData.BoonType.CHARGED_BEAM:
			draw_line(pos + Vector2(-size, 0.0), pos + Vector2(size, 0.0), color, 7.0, true)
			draw_circle(pos + Vector2(-size, 0.0), 5.0, WHITE)
		BoonData.BoonType.MAX_HEALTH:
			draw_circle(pos + Vector2(-size * 0.42, -size * 0.18), size * 0.54, color)
			draw_circle(pos + Vector2(size * 0.42, -size * 0.18), size * 0.54, color)
			draw_colored_polygon(PackedVector2Array([pos + Vector2(-size * 0.92, 0.0), pos + Vector2(size * 0.92, 0.0), pos + Vector2(0.0, size)]), color)


func _draw_goo_patch(patch: Dictionary, offset: Vector2) -> void:
	var pos := Vector2(patch.pos) + offset
	var alpha := clampf(float(patch.life) / maxf(float(patch.duration), 0.001), 0.0, 1.0)
	var motion := 0.0 if bool(saved.get("reduced_motion", false)) else sin(float(patch.phase) * 3.5) * 2.0
	var radius := float(patch.radius) + motion
	draw_circle(pos, radius, Color(LIME_DARK.r, LIME_DARK.g, LIME_DARK.b, 0.18 * alpha))
	draw_arc(pos, radius, 0.0, TAU, 30, Color(LIME_DARK.r, LIME_DARK.g, LIME_DARK.b, 0.52 * alpha), 2.0, true)


func _draw_boss_ring_attack(germ: Dictionary, offset: Vector2) -> void:
	var attack_phase := int(germ.dash_phase)
	if attack_phase != BossDashPhase.RING_WARNING and attack_phase != BossDashPhase.RING_ACTIVE:
		return
	var center := arena_center + offset
	var safe_angle := float(germ.ring_angle)
	var half_wedge := GameMath.BOSS_RING_SAFE_WEDGE_RADIANS * 0.5
	var radius := arena_radius - GameMath.BOSS_RING_THICKNESS * 0.5
	var pulse := 0.0
	var fill_alpha := 0.28
	if attack_phase == BossDashPhase.RING_WARNING:
		if not bool(saved.get("reduced_motion", false)):
			pulse = sin(float(germ.ring_timer) * 20.0) * 4.0
		radius += pulse
	else:
		radius = _boss_ring_radius(float(germ.ring_timer))
		fill_alpha = 0.52
	var arc_start := safe_angle + half_wedge
	var arc_end := safe_angle + TAU - half_wedge
	draw_arc(center, radius, arc_start, arc_end, 128, Color(BOSS_3_CORE.r, BOSS_3_CORE.g, BOSS_3_CORE.b, fill_alpha), GameMath.BOSS_RING_THICKNESS, true)
	draw_arc(center, radius, arc_start, arc_end, 128, Color(CYAN.r, CYAN.g, CYAN.b, 0.9), 2.5, true)
	for edge_angle in [safe_angle - half_wedge, safe_angle + half_wedge]:
		var edge_direction := Vector2.RIGHT.rotated(float(edge_angle))
		var inner := maxf(0.0, radius - 24.0)
		draw_line(center + edge_direction * inner, center + edge_direction * (radius + 12.0), LIME, 4.0, true)
	var safe_direction := Vector2.RIGHT.rotated(safe_angle)
	var marker_distance := maxf(24.0, radius)
	var marker_tip := center + safe_direction * marker_distance
	var marker_side := safe_direction.orthogonal()
	draw_colored_polygon(PackedVector2Array([marker_tip, marker_tip - safe_direction * 18.0 + marker_side * 9.0, marker_tip - safe_direction * 18.0 - marker_side * 9.0]), WHITE)


func _draw_germ(g: Dictionary, offset: Vector2, actor_scale: float = 1.0) -> void:
	var pos := Vector2(g.pos) + offset
	var tier := int(g.tier)
	var spec := germ_specs[tier]
	var radius := spec.radius * actor_scale
	var is_elite := tier == GermData.GermTier.ELITE
	var is_boss_2 := tier == GermData.GermTier.BOSS_2
	var is_boss_3 := tier == GermData.GermTier.BOSS_3
	var is_boss := _is_boss_tier(tier)
	if is_boss_3:
		_draw_boss_ring_attack(g, offset)
	if is_boss and int(g.dash_phase) == BossDashPhase.WARNING:
		var warning_motion := 0.0 if bool(saved.get("reduced_motion", false)) else 0.5 + sin(float(g.dash_timer) * 18.0) * 0.5
		var dash_direction := Vector2(g.dash_direction)
		var tell_start := pos + dash_direction * (radius + 8.0)
		var tell_end := pos + dash_direction * minf(arena_radius * 0.9, 360.0)
		draw_line(tell_start, tell_end, Color(ORANGE_HOT.r, ORANGE_HOT.g, ORANGE_HOT.b, 0.62 + warning_motion * 0.28), 4.0, true)
		var tell_side := dash_direction.orthogonal()
		draw_colored_polygon(PackedVector2Array([tell_end, tell_end - dash_direction * 18.0 + tell_side * 10.0, tell_end - dash_direction * 18.0 - tell_side * 10.0]), ORANGE_HOT)
	if (is_boss_2 or is_boss_3) and int(g.dash_phase) == BossDashPhase.VOLLEY_WARNING:
		var volley_motion := 0.0 if bool(saved.get("reduced_motion", false)) else 0.5 + 0.5 * sin(float(g.volley_timer) * 20.0)
		for ring in 3:
			draw_arc(pos, radius + 15.0 + float(ring) * 13.0, 0.0, TAU, 64, Color(BOSS_2_CORE.r, BOSS_2_CORE.g, BOSS_2_CORE.b, 0.5 + volley_motion * 0.3 - float(ring) * 0.1), 3.0, true)
		for shot in GameMath.BOSS_VOLLEY_COUNT:
			var volley_angle := float(g.volley_rotation) + TAU * float(shot) / float(GameMath.BOSS_VOLLEY_COUNT)
			var volley_direction := Vector2.RIGHT.rotated(volley_angle)
			draw_line(pos + volley_direction * (radius + 8.0), pos + volley_direction * (radius + 42.0), LIME, 3.0, true)
	_draw_germ_asset_body(g, pos, tier, radius, offset)
	if float(g.get("freeze_left", 0.0)) > 0.0:
		draw_circle(pos, radius * 0.88, Color(CYAN.r, CYAN.g, CYAN.b, 0.08))
		draw_arc(pos, radius * 0.9, 0.0, TAU, 48, Color(CYAN.r, CYAN.g, CYAN.b, 0.78), 3.0, true)
	if is_boss_3:
		draw_arc(pos, radius * 0.82, 0.0, TAU, 56, BOSS_3_CORE, 5.0, true)
		draw_arc(pos, radius * 0.68, 0.0, TAU, 52, CYAN, 4.0, true)
		draw_arc(pos, radius * 0.53, 0.0, TAU, 48, LIME, 3.5, true)
		draw_arc(pos, radius * 0.38, 0.0, TAU, 44, WHITE, 2.5, true)
	elif is_boss_2:
		draw_arc(pos, radius * 0.76, 0.0, TAU, 52, LIME, 4.5, true)
		draw_arc(pos, radius * 0.58, 0.0, TAU, 48, WHITE, 3.0, true)
		draw_arc(pos, radius * 0.4, 0.0, TAU, 40, ORANGE_HOT, 2.5, true)
	elif is_boss:
		draw_arc(pos, radius * 0.72, 0.0, TAU, 48, LIME, 4.0, true)
		draw_arc(pos, radius * 0.51, 0.0, TAU, 40, WHITE, 2.5, true)
	elif is_elite:
		draw_arc(pos, radius * 0.68, 0.0, TAU, 40, WHITE, 3.0, true)
	if int(g.hp) < spec.hp:
		draw_arc(pos, radius + 4.0, -PI * 0.5, -PI * 0.5 + TAU * float(g.hp) / float(spec.hp), 24, ORANGE_HOT, 3.0, true)


func _draw_germ_asset_body(germ: Dictionary, pos: Vector2, tier: int, radius: float, offset: Vector2) -> void:
	if tier < 0 or tier >= germ_visual_textures.size():
		return
	var tier_layers: Array = germ_visual_textures[tier]
	if tier_layers.size() != germ_layer_sources.size():
		return
	var camera_transform := Transform2D(0.0, Vector2.ONE * _dialogue_camera_zoom(), 0.0, _dialogue_camera_origin(offset))
	var germ_transform := Transform2D(float(germ.phase) * 0.1, Vector2.ONE, 0.0, pos)
	draw_set_transform_matrix(camera_transform * germ_transform)
	var base_scale := radius / GERM_ASSET_RADIUS
	var flash_amount := _germ_hit_flash_amount(germ)
	for layer in tier_layers.size():
		var texture: Texture2D = tier_layers[layer]
		var layer_scale := base_scale * _germ_hit_layer_scale(germ, layer)
		var layer_size := texture.get_size() * layer_scale
		var rect := Rect2(-layer_size * 0.5, layer_size)
		draw_texture_rect(texture, rect, false)
		if flash_amount > 0.0:
			draw_texture_rect(germ_flash_masks[layer], rect, false, Color(BOSS_2_CORE.r, BOSS_2_CORE.g, BOSS_2_CORE.b, flash_amount))
	draw_set_transform_matrix(camera_transform)


func _draw_debris(pos: Vector2, angle: float, source: int = DebrisSource.REGULAR) -> void:
	var pts := PackedVector2Array([
		pos + Vector2(-10.0, -6.0).rotated(angle),
		pos + Vector2(9.0, -9.0).rotated(angle),
		pos + Vector2(6.0, 8.0).rotated(angle),
		pos + Vector2(-7.0, 11.0).rotated(angle),
	])
	var fill := BOSS_2_CORE if source == DebrisSource.BOSS_VOLLEY else PURPLE_SOFT
	var outline := LIME if source == DebrisSource.BOSS_VOLLEY else PURPLE
	draw_colored_polygon(pts, fill)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), outline, 2.0, true)


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


func _draw_beam(offset: Vector2) -> void:
	var level := _boon_level(BoonData.BoonType.CHARGED_BEAM)
	if beam_active_left <= 0.0 or level <= 0:
		return
	var start := player_pos + offset
	var finish := _beam_end() + offset
	var width := BoonData.beam_width(level)
	var flicker := 1.0
	if not bool(saved.get("reduced_motion", false)):
		flicker = 0.88 + sin(beam_active_left * 48.0) * 0.12
	draw_line(start, finish, Color(BOSS_2_CORE.r, BOSS_2_CORE.g, BOSS_2_CORE.b, 0.2), width + 10.0, true)
	draw_line(start, finish, Color(ORANGE_HOT.r, ORANGE_HOT.g, ORANGE_HOT.b, 0.75 * flicker), width, true)
	draw_line(start, finish, Color(WHITE.r, WHITE.g, WHITE.b, 0.9 * flicker), maxf(3.0, width * 0.28), true)


func _draw_freeze_effect(offset: Vector2) -> void:
	if freeze_flash_left <= 0.0:
		return
	var level := _boon_level(BoonData.BoonType.FREEZE_AOE_SHOCK)
	if level <= 0:
		return
	var alpha := clampf(freeze_flash_left / 0.35, 0.0, 1.0)
	var radius := BoonData.freeze_radius(level)
	draw_circle(player_pos + offset, radius, Color(CYAN.r, CYAN.g, CYAN.b, alpha * 0.08))
	draw_arc(player_pos + offset, radius, 0.0, TAU, 72, Color(CYAN.r, CYAN.g, CYAN.b, alpha * 0.8), 4.0, true)


func _draw_player(offset: Vector2, actor_scale: float = 1.0) -> void:
	var pos := player_pos + offset
	if boost_active or dash_left > 0.0:
		var tail_dir := -dash_direction if dash_left > 0.0 else Vector2.LEFT.rotated(player_facing)
		var trail_color := CYAN if dash_left > 0.0 else (LIME_DARK if active_space_boon == BoonData.BoonType.GOO_TRAIL_BOOST else LIME)
		draw_line(pos + tail_dir * 12.0 * actor_scale, pos + tail_dir * (58.0 if dash_left > 0.0 else 44.0) * actor_scale, Color(trail_color.r, trail_color.g, trail_color.b, 0.7), 8.0 * actor_scale, true)
	if spawn_protection_left > 0.0:
		draw_arc(pos, (PLAYER_RADIUS + 10.0) * actor_scale, 0.0, TAU, 40, Color(0.333, 0.867, 0.878, 0.55), 3.0 * actor_scale, true)
	if damage_protection_left > 0.0:
		var damage_alpha := 0.7 if bool(saved.get("reduced_motion", false)) else (0.35 + 0.35 * absf(sin(damage_protection_left * 18.0)))
		draw_arc(pos, (PLAYER_RADIUS + 7.0) * actor_scale, 0.0, TAU, 40, Color(BOSS_2_CORE.r, BOSS_2_CORE.g, BOSS_2_CORE.b, damage_alpha), 3.0 * actor_scale, true)
	if invincibility_left > 0.0 or dash_left > 0.0:
		var shield_color := PURPLE_SOFT if invincibility_left > 0.0 else CYAN
		draw_circle(pos, (PLAYER_RADIUS + 10.0) * actor_scale, Color(shield_color.r, shield_color.g, shield_color.b, 0.14))
		draw_arc(pos, (PLAYER_RADIUS + 11.0) * actor_scale, 0.0, TAU, 40, shield_color, 3.5 * actor_scale, true)
	var camera_transform := Transform2D(0.0, Vector2.ONE * _dialogue_camera_zoom(), 0.0, _dialogue_camera_origin(offset))
	var player_transform := Transform2D(player_facing + PLAYER_ASSET_ROTATION_OFFSET, Vector2.ONE, 0.0, pos)
	draw_set_transform_matrix(camera_transform * player_transform)
	var texture_scale := PLAYER_ASSET_WIDTH * actor_scale / player_texture.get_width()
	var texture_size := player_texture.get_size() * texture_scale
	draw_texture_rect(player_texture, Rect2(-texture_size * 0.5, texture_size), false)
	draw_set_transform_matrix(camera_transform)
	if base_weapon_damage > 1:
		draw_arc(pos, 10.0 * actor_scale, -0.65, 0.65, 16, LIME, 2.5 * actor_scale, true)
	if base_weapon_fire_rate > GameMath.BASE_PLAYER_FIRE_RATE:
		draw_arc(pos, 14.0 * actor_scale, -0.8, 0.8, 18, CYAN, 2.0 * actor_scale, true)


func _draw_dialogue_bubble(offset: Vector2) -> void:
	if dialogue_speaker == DialogueSpeaker.NONE or dialogue_text.is_empty():
		return
	var camera_zoom := _dialogue_camera_zoom()
	var speaker_pos := _dialogue_world_to_screen(player_pos, offset)
	var speaker_radius := PLAYER_RADIUS * camera_zoom * _dialogue_speaker_scale()
	var stroke := ORANGE_HOT
	var text_color := DARK_MINT
	if dialogue_speaker == DialogueSpeaker.GERM:
		if dialogue_germ_index < 0 or dialogue_germ_index >= germs.size() or not bool(germs[dialogue_germ_index].active):
			return
		var germ := germs[dialogue_germ_index]
		speaker_pos = _dialogue_world_to_screen(Vector2(germ.pos), offset)
		speaker_radius = germ_specs[int(germ.tier)].radius * camera_zoom * _dialogue_speaker_scale(dialogue_germ_index)
		stroke = ORANGE_HOT if int(germ.tier) == GermData.GermTier.ELITE or _is_boss_tier(int(germ.tier)) else PURPLE
		text_color = PURPLE
	var layout := _dialogue_layout(speaker_pos, dialogue_text, speaker_radius)
	var rect: Rect2 = layout.rect
	var tail_tip: Vector2 = layout.tail_tip
	var tail_base: Vector2 = layout.tail_base
	var alpha := _dialogue_bubble_alpha() * dialogue_occlusion_opacity
	if alpha <= 0.0:
		return
	var fill := Color(WHITE.r, WHITE.g, WHITE.b, 0.96 * alpha)
	var line_color := Color(stroke.r, stroke.g, stroke.b, alpha)
	var tail_direction := -1.0 if bool(layout.above) else 1.0
	var tail := PackedVector2Array([
		tail_base + Vector2(-7.0, tail_direction),
		tail_base + Vector2(7.0, tail_direction),
		tail_tip,
	])
	draw_colored_polygon(tail, fill)
	draw_polyline(PackedVector2Array([tail[0], tail_tip, tail[1]]), line_color, 2.0, true)
	_draw_pill(rect, fill, line_color, 2.0)
	var lines: Array = _typewriter_dialogue_lines(Array(layout.lines), dialogue_visible_characters)
	var font_size := int(layout.font_size)
	var line_height := float(layout.line_height)
	var baseline := rect.position.y + 10.0 + font.get_ascent(font_size)
	for i in lines.size():
		_draw_text(str(lines[i]), Vector2(rect.position.x + 11.0, baseline + float(i) * line_height), font_size, Color(text_color.r, text_color.g, text_color.b, alpha))
	if dialogue_cutscene_phase == DialogueCutscenePhase.TALKING and dialogue_visible_characters < dialogue_text.length() and fmod(dialogue_phase_time, 0.48) < 0.36:
		var active_line := 0
		for i in lines.size():
			if not str(lines[i]).is_empty():
				active_line = i
		var typed_line := str(lines[active_line])
		var caret_x := rect.position.x + 12.0 + font.get_string_size(typed_line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		var caret_baseline := baseline + float(active_line) * line_height
		draw_line(Vector2(caret_x, caret_baseline - font.get_ascent(font_size)), Vector2(caret_x, caret_baseline + 2.0), Color(text_color.r, text_color.g, text_color.b, alpha), 1.5, true)


func _typewriter_dialogue_lines(full_lines: Array, visible_characters: int) -> Array[String]:
	var visible_lines: Array[String] = []
	var remaining := maxi(0, visible_characters)
	for i in full_lines.size():
		var full_line := str(full_lines[i])
		var visible_count := mini(remaining, full_line.length())
		visible_lines.append(full_line.left(visible_count))
		remaining -= visible_count
		if remaining > 0 and i < full_lines.size() - 1:
			remaining -= 1
	return visible_lines


func _dialogue_layout(speaker_pos: Vector2, text: String, speaker_radius: float) -> Dictionary:
	var font_size := clampi(roundi(_hud_unit() * 0.017), 10, 14)
	var max_text_width := clampf(float(font_size) * 18.5, 190.0, DIALOGUE_MAX_TEXT_WIDTH)
	var lines := _wrap_dialogue_text(text, max_text_width, font_size)
	var text_width := 0.0
	for line in lines:
		text_width = maxf(text_width, font.get_string_size(str(line), HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x)
	var line_height := float(font_size + 4)
	var bubble_size := Vector2(clampf(text_width + 22.0, 100.0, max_text_width + 22.0), float(lines.size()) * line_height + 14.0)
	var safe_left := maxf(12.0, arena_center.x - arena_radius + 8.0)
	var safe_right := minf(viewport_size.x - 12.0, arena_center.x + arena_radius - 8.0)
	if safe_right - safe_left < bubble_size.x:
		safe_left = 12.0
		safe_right = viewport_size.x - 12.0
	var safe_top := _hud_top_safe_area() + 12.0
	var safe_bottom := viewport_size.y - 16.0
	var gap := 16.0
	var above_y := speaker_pos.y - speaker_radius - gap - bubble_size.y
	var below_y := speaker_pos.y + speaker_radius + gap
	var centered_x := speaker_pos.x - bubble_size.x * 0.5
	var inward_x := speaker_pos.x + speaker_radius + gap if speaker_pos.x < arena_center.x else speaker_pos.x - speaker_radius - gap - bubble_size.x
	var center_x := arena_center.x - bubble_size.x * 0.5
	var candidates := [
		{"x": centered_x, "y": above_y, "above": true},
		{"x": centered_x, "y": below_y, "above": false},
		{"x": inward_x, "y": above_y, "above": true},
		{"x": inward_x, "y": below_y, "above": false},
		{"x": center_x, "y": above_y, "above": true},
		{"x": center_x, "y": below_y, "above": false},
	]
	# Speakers near the top edge can leave every natural placement competing with
	# the logo and health bar. Try the same horizontal anchors just below each HUD
	# block before accepting an overlap.
	var fallback_xs := [centered_x, inward_x, center_x, safe_left, safe_right - bubble_size.x]
	for reserved in _dialogue_hud_reserved_rects():
		var fallback_y := reserved.end.y + 8.0
		for fallback_x in fallback_xs:
			candidates.append({
				"x": fallback_x,
				"y": fallback_y,
				"above": fallback_y + bubble_size.y <= speaker_pos.y,
			})
	var rect := Rect2()
	var place_above := true
	var best_overlap := INF
	for candidate in candidates:
		var candidate_rect := Rect2(
			Vector2(
				clampf(float(candidate.x), safe_left, safe_right - bubble_size.x),
				clampf(float(candidate.y), safe_top, safe_bottom - bubble_size.y)
			),
			bubble_size
		)
		var overlap := _dialogue_hud_overlap(candidate_rect)
		if overlap < best_overlap:
			best_overlap = overlap
			rect = candidate_rect
			place_above = bool(candidate.above)
		if is_zero_approx(overlap):
			break
	var base_y := rect.end.y if place_above else rect.position.y
	var base_x := clampf(speaker_pos.x, rect.position.x + 18.0, rect.end.x - 18.0)
	var tip_y := speaker_pos.y - speaker_radius if place_above else speaker_pos.y + speaker_radius
	return {
		"rect": rect,
		"lines": lines,
		"font_size": font_size,
		"line_height": line_height,
		"tail_base": Vector2(base_x, base_y),
		"tail_tip": Vector2(speaker_pos.x, tip_y),
		"above": place_above,
	}


func _dialogue_hud_overlap(rect: Rect2) -> float:
	var overlap := 0.0
	for reserved in _dialogue_hud_reserved_rects():
		var intersection := rect.intersection(reserved)
		overlap += intersection.size.x * intersection.size.y
	return overlap


func _dialogue_hud_reserved_rects() -> Array[Rect2]:
	var reserved: Array[Rect2] = [
		_gameplay_logo_bounds().grow(5.0),
		_score_bounds().grow(5.0),
		_timer_bounds().grow(5.0),
		_boost_bounds().grow(5.0),
		_health_bounds().grow(5.0),
	]
	if combo > 1:
		reserved.append(_combo_bounds().grow(5.0))
	return reserved


func _wrap_dialogue_text(text: String, max_width: float, font_size: int) -> Array[String]:
	var lines: Array[String] = []
	var current := ""
	for word in text.split(" ", false):
		var candidate := str(word) if current.is_empty() else "%s %s" % [current, word]
		if current.is_empty() or font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x <= max_width:
			current = candidate
		elif lines.is_empty():
			lines.append(current)
			current = str(word)
		else:
			current = "%s %s" % [current, word]
	if not current.is_empty():
		lines.append(current)
	if lines.size() > 2:
		var overflow := " ".join(lines.slice(1))
		lines = [lines[0], overflow]
	while font.get_string_size(lines[lines.size() - 1], HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x > max_width:
		var shortened := lines[lines.size() - 1].trim_suffix("…")
		if shortened.length() <= 1:
			break
		lines[lines.size() - 1] = shortened.left(shortened.length() - 1).strip_edges() + "…"
	return lines


func _draw_reticle(pos: Vector2) -> void:
	var color := Color(0.439, 0.627, 0.592, 0.9)
	draw_arc(pos, 12.0, 0.0, TAU, 24, color, 2.0, true)
	draw_line(pos + Vector2(-20, 0), pos + Vector2(-8, 0), color, 2.0)
	draw_line(pos + Vector2(8, 0), pos + Vector2(20, 0), color, 2.0)
	draw_line(pos + Vector2(0, -20), pos + Vector2(0, -8), color, 2.0)
	draw_line(pos + Vector2(0, 8), pos + Vector2(0, 20), color, 2.0)


func _draw_hud(opacity_multiplier: float = 1.0) -> void:
	_draw_gameplay_logo(opacity_multiplier)
	_draw_health_hud(opacity_multiplier)
	_draw_responsive_hud(opacity_multiplier)


func _health_bounds() -> Rect2:
	var visual_unit := _hud_unit()
	var width := clampf(visual_unit * 0.28, 150.0, 260.0)
	var height := clampf(visual_unit * 0.034, 18.0, 30.0)
	return Rect2(Vector2(viewport_size.x * 0.5 - width * 0.5 - 6.0, _hud_top_safe_area() + 14.0), Vector2(width + 12.0, height + 32.0))


func _draw_health_hud(opacity_multiplier: float = 1.0) -> void:
	var bounds := _health_bounds()
	var opacity := health_hud_opacity * opacity_multiplier
	var font_size := clampi(roundi(_hud_unit() * 0.021), 12, 18)
	_draw_text_centered("HEALTH  %d / %d" % [player_health, player_max_health], Vector2(bounds.get_center().x, bounds.position.y + font_size), font_size, Color(PURPLE.r, PURPLE.g, PURPLE.b, opacity))
	var bar := Rect2(Vector2(bounds.position.x + 6.0, bounds.end.y - clampf(_hud_unit() * 0.034, 18.0, 30.0) - 4.0), Vector2(bounds.size.x - 12.0, clampf(_hud_unit() * 0.034, 18.0, 30.0)))
	var gap := 4.0
	var segment_width := (bar.size.x - gap * float(player_max_health - 1)) / float(maxi(1, player_max_health))
	for i in player_max_health:
		var segment := Rect2(Vector2(bar.position.x + float(i) * (segment_width + gap), bar.position.y), Vector2(segment_width, bar.size.y))
		var filled := i < player_health
		var fill := BOSS_2_CORE if filled else Color(WHITE.r, WHITE.g, WHITE.b, 0.5)
		_draw_pill(segment, Color(fill.r, fill.g, fill.b, (0.82 if filled else 0.42) * opacity), Color(PURPLE.r, PURPLE.g, PURPLE.b, 0.65 * opacity), 2.0)


func _hud_unit() -> float:
	return minf(viewport_size.y, viewport_size.x * 0.62)


func _hud_top_safe_area() -> float:
	return 76.0 if css_viewport_width < 1024.0 else 0.0


func _gameplay_logo_rect() -> Rect2:
	var visual_unit := _hud_unit()
	var logo_width := clampf(minf(viewport_size.x * 0.18, visual_unit * 0.36), 92.0, 380.0)
	var logo_height := logo_width * float(logo_texture.get_height()) / float(logo_texture.get_width())
	var inset := maxf(16.0, visual_unit * 0.06)
	return Rect2(Vector2(inset, inset + _hud_top_safe_area()), Vector2(logo_width, logo_height))


func _gameplay_logo_bounds() -> Rect2:
	var rect := _gameplay_logo_rect()
	return Rect2(rect.position - Vector2(5.0, 5.0), rect.size + Vector2(10.0, 31.0))


func _draw_gameplay_logo(opacity_multiplier: float = 1.0) -> void:
	var rect := _gameplay_logo_rect()
	var opacity := logo_hud_opacity * opacity_multiplier
	draw_texture_rect(logo_texture, rect, false, Color(1.0, 1.0, 1.0, opacity))
	_draw_text_centered("MODE // CULTURE WARS", Vector2(rect.get_center().x, rect.end.y + 16.0), clampi(roundi(_hud_unit() * 0.016), 10, 14), Color(PURPLE.r, PURPLE.g, PURPLE.b, opacity))


func _draw_responsive_hud(opacity_multiplier: float = 1.0) -> void:
	var visual_unit := _hud_unit()
	var top_safe := _hud_top_safe_area()
	var label_size := _hud_label_size(visual_unit)
	var value_size := _hud_score_size(visual_unit)
	var time_value_size := _hud_time_size(visual_unit)
	var outline_size := _hud_outline_size(visual_unit)
	var shadow_offset := _hud_shadow_offset(visual_unit)

	_draw_mock_stat(
		"SCORE",
		str(score),
		Vector2(viewport_size.x - visual_unit * 0.09, top_safe + visual_unit * 0.145),
		-0.18,
		label_size,
		value_size,
		true,
		outline_size,
		shadow_offset,
		score_hud_opacity * opacity_multiplier
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
		shadow_offset,
		timer_hud_opacity * opacity_multiplier
	)
	if combo > 1:
		var combo_opacity := combo_hud_opacity * opacity_multiplier
		var combo_fill := Color(PURPLE.r, PURPLE.g, PURPLE.b, combo_opacity)
		var combo_outline := Color(WHITE.r, WHITE.g, WHITE.b, combo_opacity)
		var combo_shadow := Color(DARK_MINT.r, DARK_MINT.g, DARK_MINT.b, combo_opacity)
		_draw_text_with_outline(
			"%dx COMBO" % combo,
			Vector2(viewport_size.x - visual_unit * 0.37, top_safe + visual_unit * 0.34),
			maxi(15, roundi(float(label_size) * 0.55)),
			combo_fill,
			combo_outline,
			maxi(2, outline_size / 2),
			Vector2(3.0, 3.0),
			combo_shadow
		)
	_draw_responsive_boost(visual_unit, label_size, outline_size, shadow_offset, boost_hud_opacity * opacity_multiplier)


func _hud_label_size(visual_unit: float) -> int:
	return roundi(clampf(visual_unit * 0.063 * HUD_SCALE, 16.0, 54.0))


func _hud_score_size(visual_unit: float) -> int:
	return roundi(clampf(visual_unit * 0.122 * HUD_SCALE, 30.0, 124.0))


func _hud_time_size(visual_unit: float) -> int:
	return roundi(clampf(visual_unit * 0.132 * HUD_SCALE, 30.0, 96.0))


func _hud_outline_size(visual_unit: float) -> int:
	return maxi(2, roundi(visual_unit * 0.0075))


func _hud_shadow_offset(visual_unit: float) -> Vector2:
	return Vector2.ONE * maxf(2.0, visual_unit * 0.009)


func _draw_mock_stat(label: String, value: String, origin: Vector2, rotation: float, label_size: int, value_size: int, align_right: bool, outline_size: int, shadow_offset: Vector2, opacity: float = 1.0) -> void:
	draw_set_transform(origin, rotation, Vector2.ONE)
	var label_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, label_size).x
	var value_width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, value_size).x
	var fill := Color(DARK_MINT.r, DARK_MINT.g, DARK_MINT.b, DARK_MINT.a * opacity)
	var outline := Color(WHITE.r, WHITE.g, WHITE.b, WHITE.a * opacity)
	var shadow := Color(DARK_MINT.r, DARK_MINT.g, DARK_MINT.b, DARK_MINT.a * opacity)
	_draw_text_with_outline(label, Vector2(-label_width if align_right else 0.0, 0.0), label_size, fill, outline, outline_size, shadow_offset, shadow)
	_draw_text_with_outline(value, Vector2(-value_width if align_right else 0.0, value_size * 0.91), value_size, fill, outline, outline_size, shadow_offset, shadow)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _timer_opacity() -> float:
	return _overlay_target_opacity(_timer_bounds())


func _timer_bounds() -> Rect2:
	var visual_unit := _hud_unit()
	var label_size := _hud_label_size(visual_unit)
	var value_size := _hud_time_size(visual_unit)
	var outline_size := _hud_outline_size(visual_unit)
	var shadow_offset := _hud_shadow_offset(visual_unit)
	return _mock_stat_bounds(
		"TIME",
		_format_time_precise(run_time),
		Vector2(visual_unit * 0.075, viewport_size.y - visual_unit * 0.28),
		-0.10,
		label_size,
		value_size,
		false,
		outline_size,
		shadow_offset
	)


func _score_bounds() -> Rect2:
	var visual_unit := _hud_unit()
	return _mock_stat_bounds(
		"SCORE",
		str(score),
		Vector2(viewport_size.x - visual_unit * 0.09, _hud_top_safe_area() + visual_unit * 0.145),
		-0.18,
		_hud_label_size(visual_unit),
		_hud_score_size(visual_unit),
		true,
		_hud_outline_size(visual_unit),
		_hud_shadow_offset(visual_unit)
	)


func _combo_bounds() -> Rect2:
	if combo <= 1:
		return Rect2(Vector2(-10000.0, -10000.0), Vector2.ZERO)
	var visual_unit := _hud_unit()
	var text := "%dx COMBO" % combo
	var font_size := maxi(15, roundi(float(_hud_label_size(visual_unit)) * 0.55))
	var baseline := Vector2(viewport_size.x - visual_unit * 0.37, _hud_top_safe_area() + visual_unit * 0.34)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	return Rect2(Vector2(baseline.x - 5.0, baseline.y - font.get_ascent(font_size) - 5.0), Vector2(width + 10.0, font.get_height(font_size) + 10.0))


func _mock_stat_bounds(label: String, value: String, origin: Vector2, rotation: float, label_size: int, value_size: int, align_right: bool, outline_size: int, shadow_offset: Vector2) -> Rect2:
	var label_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, label_size).x
	var value_width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, value_size).x
	var label_x := -label_width if align_right else 0.0
	var value_x := -value_width if align_right else 0.0
	var padding := float(outline_size) + maxf(shadow_offset.x, shadow_offset.y) + 3.0
	var local_left := minf(label_x, value_x) - padding
	var local_right := maxf(label_x + label_width, value_x + value_width) + padding
	var value_baseline := float(value_size) * 0.91
	var local_top := minf(-font.get_ascent(label_size), value_baseline - font.get_ascent(value_size)) - padding
	var local_bottom := maxf(font.get_descent(label_size), value_baseline + font.get_descent(value_size)) + padding
	return _transformed_rect_bounds(Rect2(Vector2(local_left, local_top), Vector2(local_right - local_left, local_bottom - local_top)), origin, rotation)


func _transformed_rect_bounds(local_rect: Rect2, origin: Vector2, rotation: float) -> Rect2:
	var transform := Transform2D(rotation, origin)
	var corners := [
		transform * local_rect.position,
		transform * Vector2(local_rect.end.x, local_rect.position.y),
		transform * local_rect.end,
		transform * Vector2(local_rect.position.x, local_rect.end.y),
	]
	var minimum: Vector2 = corners[0]
	var maximum: Vector2 = corners[0]
	for corner in corners:
		minimum = minimum.min(corner)
		maximum = maximum.max(corner)
	return Rect2(minimum, maximum - minimum)


func _circle_intersects_rect(center: Vector2, radius: float, rect: Rect2) -> bool:
	var closest := Vector2(
		clampf(center.x, rect.position.x, rect.end.x),
		clampf(center.y, rect.position.y, rect.end.y)
	)
	return center.distance_squared_to(closest) <= radius * radius


func _draw_responsive_boost(visual_unit: float, label_size: int, outline_size: int, shadow_offset: Vector2, opacity: float) -> void:
	var rotation := 0.20
	var origin := Vector2(viewport_size.x - visual_unit * 0.065, viewport_size.y - visual_unit * 0.27)
	var meter_width := clampf(visual_unit * 0.36, 135.0, 360.0)
	var meter_height := clampf(visual_unit * 0.078, 30.0, 76.0)
	draw_set_transform(origin, rotation, Vector2.ONE)
	var label := _space_hud_label()
	var label_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, label_size).x
	_draw_text_with_outline(label, Vector2(-label_width, 0.0), label_size, Color(DARK_MINT.r, DARK_MINT.g, DARK_MINT.b, opacity), Color(WHITE.r, WHITE.g, WHITE.b, opacity), outline_size, shadow_offset, Color(DARK_MINT.r, DARK_MINT.g, DARK_MINT.b, opacity))
	var meter := Rect2(Vector2(-meter_width, meter_height * 0.34), Vector2(meter_width, meter_height))
	_draw_pill(meter.grow(6.0), Color(WHITE.r, WHITE.g, WHITE.b, 0.28 * opacity), Color.TRANSPARENT, 0.0)
	_draw_pill(meter, Color(WHITE.r, WHITE.g, WHITE.b, 0.48 * opacity), Color.TRANSPARENT, 0.0)
	var charge_rect := meter.grow(-6.0)
	charge_rect.size.x *= _space_meter_value()
	if charge_rect.size.x > charge_rect.size.y:
		var meter_color := LIME if active_space_boon == BoonData.NO_BOON else BoonData.color(active_space_boon)
		_draw_pill(charge_rect, Color(meter_color.r, meter_color.g, meter_color.b, 0.58 * opacity), Color.TRANSPARENT, 0.0)
	var space_size := roundi(meter_height * 0.58)
	var space_text := "SPACE"
	var space_width := font.get_string_size(space_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, space_size).x
	_draw_text_with_outline(space_text, Vector2(meter.get_center().x - space_width * 0.5, meter.get_center().y + space_size * 0.34), space_size, Color(WHITE.r, WHITE.g, WHITE.b, opacity), Color(WHITE.r, WHITE.g, WHITE.b, 0.01 * opacity), 1, Vector2(4.0, 4.0), Color(DARK_MINT.r, DARK_MINT.g, DARK_MINT.b, 0.62 * opacity))
	if _boon_level(BoonData.BoonType.CHARGED_BEAM) > 0:
		var beam_label_size := maxi(12, roundi(float(label_size) * 0.55))
		var beam_label := "BEAM / HOLD FIRE"
		var beam_label_width := font.get_string_size(beam_label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, beam_label_size).x
		var beam_y := -meter_height * 1.05
		_draw_text_with_outline(beam_label, Vector2(-beam_label_width, beam_y), beam_label_size, Color(PURPLE.r, PURPLE.g, PURPLE.b, opacity), Color(WHITE.r, WHITE.g, WHITE.b, opacity), maxi(1, outline_size / 2), Vector2(2.0, 2.0), Color(DARK_MINT.r, DARK_MINT.g, DARK_MINT.b, opacity))
		var beam_meter := Rect2(Vector2(-meter_width, beam_y + 7.0), Vector2(meter_width, meter_height * 0.38))
		_draw_pill(beam_meter, Color(WHITE.r, WHITE.g, WHITE.b, 0.6 * opacity), Color.TRANSPARENT, 0.0)
		var beam_fill := beam_meter.grow(-4.0)
		var beam_value := beam_active_left / BoonData.BEAM_DURATION_SECONDS if beam_active_left > 0.0 else beam_charge / BoonData.BEAM_CHARGE_SECONDS
		beam_fill.size.x *= clampf(beam_value, 0.0, 1.0)
		if beam_fill.size.x > beam_fill.size.y:
			_draw_pill(beam_fill, Color(ORANGE_HOT.r, ORANGE_HOT.g, ORANGE_HOT.b, 0.72 * opacity), Color.TRANSPARENT, 0.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _boost_bounds() -> Rect2:
	var visual_unit := _hud_unit()
	var label_size := _hud_label_size(visual_unit)
	var origin := Vector2(viewport_size.x - visual_unit * 0.065, viewport_size.y - visual_unit * 0.27)
	var meter_width := clampf(visual_unit * 0.36, 135.0, 360.0)
	var meter_height := clampf(visual_unit * 0.078, 30.0, 76.0)
	var label_width := font.get_string_size(_space_hud_label(), HORIZONTAL_ALIGNMENT_LEFT, -1.0, label_size).x
	if _boon_level(BoonData.BoonType.CHARGED_BEAM) > 0:
		label_width = maxf(label_width, font.get_string_size("BEAM / HOLD FIRE", HORIZONTAL_ALIGNMENT_LEFT, -1.0, maxi(12, roundi(float(label_size) * 0.55))).x)
	var extra_top := meter_height * 1.25 if _boon_level(BoonData.BoonType.CHARGED_BEAM) > 0 else 0.0
	var local_rect := Rect2(
		Vector2(-maxf(meter_width + 7.0, label_width + 5.0), -font.get_ascent(label_size) - 5.0 - extra_top),
		Vector2(maxf(meter_width + 14.0, label_width + 12.0), font.get_ascent(label_size) + meter_height * 1.34 + 14.0 + extra_top)
	)
	return _transformed_rect_bounds(local_rect, origin, 0.20)


func _draw_menu() -> void:
	_draw_text_centered("PETRI", Vector2(viewport_size.x * 0.5, viewport_size.y * 0.25), int(clampf(viewport_size.y * 0.18, 92.0, 168.0)), DARK_MINT)
	_draw_text_centered("EVERYONE FIGHTS. SOMEONE PROFITS.", Vector2(viewport_size.x * 0.5, viewport_size.y * 0.31), 18, ACCENT_MINT)
	var labels := ["CULTURE WARS", "HOW TO PLAY", "SETTINGS"]
	for i in labels.size(): _draw_action_button(_menu_button_rect(i), labels[i], i == 0)
	_draw_text_centered("WASD  MOVE     MOUSE  AIM     LEFT CLICK  FIRE     SPACE  ACTIVE ABILITY", Vector2(viewport_size.x * 0.5, viewport_size.y - 42.0), 15, DARK_MINT)


func _draw_how_to() -> void:
	_draw_text_centered("HOW TO PLAY", Vector2(viewport_size.x * 0.5, 92.0), 58, DARK_MINT)
	var panel := Rect2(Vector2(viewport_size.x * 0.5 - minf(470.0, viewport_size.x * 0.42), 142.0), Vector2(minf(940.0, viewport_size.x * 0.84), viewport_size.y - 262.0))
	_draw_pill(panel, Color(1,1,1,0.88), MINT, 3.0)
	var rows := [
		["CULTURE WARS", "Germs are ragebait, not people. Arguments split and get louder."],
		["W A S D", "Apply force. Momentum carries you through the dish."],
		["MOUSE", "Aim the antibiotic particle."],
		["LEFT CLICK", "Fire pellets — up to six per second."],
		["SPACE", "Boost at first. Boss boons can replace it with a new ability."],
		["ESC", "Pause. Losing browser focus pauses automatically."],
		["GOLD ELITE", "Destroy the tank germ to reveal a permanent item."],
		["BOSS BOONS", "After each boss, choose one of three permanent run upgrades."],
	]
	for i in rows.size():
		var y := panel.position.y + 56.0 + i * 47.0
		_draw_text(str(rows[i][0]), Vector2(panel.position.x + 42.0, y), 19, PURPLE)
		_draw_text(str(rows[i][1]), Vector2(panel.position.x + 230.0, y), 15, DARK_MINT)
	_draw_text_centered("The discourse is the infection. Three unprotected hits end the run.", Vector2(viewport_size.x * 0.5, panel.end.y - 30.0), 15, ORANGE_HOT)
	_draw_action_button(_single_button_rect(), "BACK", false)


func _draw_pause() -> void:
	_draw_overlay_scrim()
	_draw_text_centered("PAUSED", Vector2(viewport_size.x * 0.5, viewport_size.y * 0.28), 68, WHITE)
	var labels := ["RESUME", "SETTINGS", "MAIN MENU"]
	for i in labels.size(): _draw_action_button(_overlay_button_rect(i, labels.size()), labels[i], i == 0)


func _draw_game_over() -> void:
	_draw_overlay_scrim()
	_draw_text_centered("CULTURE WAR LOST", Vector2(viewport_size.x * 0.5, viewport_size.y * 0.2), 56, WHITE)
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
