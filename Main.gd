extends Node3D

const MATCH_SECONDS := 300.0
const FIELD_LENGTH := 42.0
const FIELD_WIDTH := 26.0
const PLAYER_SPEED := 7.0
const BOT_SPEED := 4.4
const BALL_RADIUS := 0.34

var player: CharacterBody3D
var ball: RigidBody3D
var teammates: Array[CharacterBody3D] = []
var opponents: Array[CharacterBody3D] = []
var all_bots: Array[CharacterBody3D] = []
var score_home := 0
var score_away := 0
var time_left := MATCH_SECONDS
var match_active := false
var is_paused := false
var joystick_vector := Vector2.ZERO
var touch_origin := Vector2.ZERO
var joystick_touch_id := -1
var burst_time := 0.0
var burst_cooldown := 0.0
var ui_score: Label
var ui_timer: Label
var ui_hint: Label
var joystick_base: Control
var joystick_knob: Control
var shoot_button: Button
var pass_button: Button
var call_pass_button: Button
var pass_request_active := false
var pass_request_cooldown := 0.0
var burst_button: Button
var jockey_button: Button
var jockey_mode := false
var camera_rig: Node3D
var camera: Camera3D
var rng := RandomNumberGenerator.new()
var player_visual: MeshInstance3D
var ball_visual: MeshInstance3D
var kick_anim_time := 0.0
var kick_anim_leg: Node3D
var player_left_leg: Node3D
var player_right_leg: Node3D
var player_left_arm: Node3D
var player_right_arm: Node3D
var ball_bounce_phase := 0.0
var goal_flash: ColorRect
var goal_flash_time := 0.0
var burst_fx_timer := 0.0
var run_phase := 0.0
var lobby_layer: CanvasLayer
var lobby_status: Label
var character_picker: OptionButton
var ability_picker: OptionButton
var color_picker: OptionButton
var selected_ability := "Speed Burst"
var selected_character := "Striker"
var selected_team_color := "Electric Blue"
var wins_total := 0
var goals_total := 0
var passes_total := 0
var burst_uses_total := 0
var tasks_claimed: Dictionary = {}
var player_level := 1
var aim_line: MeshInstance3D
var goal_banner: Label
var sfx_player: AudioStreamPlayer
var goal_animation_busy := false
var goal_banner_tween: Tween
var sound_enabled := true
var ultimate_cooldown := 0.0
var ultimate_button: Button
var pause_button: Button
var sound_button: Button
var ultimate_fx_timer := 0.0
var ball_spin := 0.0
var dribble_knock_cooldown := 0.0
var pitch_wetness := 0.0
var pitch_wear := 0.0
var player_technique := 0.72
var first_touch_cooldown := 0.0
var hub_content: VBoxContainer
var match_coins := 0
var premium_points := 0
var daily_bonus_claimed := false
var goal_reward_claimed := false
var selected_tactic := "Balanced • keep passing lanes"
# Direct-IP ENet prototype. Public matchmaking still requires a reachable host or relay.
var network_peer: ENetMultiplayerPeer
var network_status := "Offline"
var network_send_accumulator := 0.0
var network_player_states: Dictionary = {}
var remote_players: Dictionary = {}
var online_address_input: LineEdit
var online_port_input: SpinBox
var network_status_label: Label
var network_match_enabled := false
var friend_target_input: LineEdit
var friend_request_status_label: Label
var pending_friend_request_from := -1
var player_uid := ""
var player_display_name := "Guest Player"
var account_mode := "Guest"
var player_profiles: Dictionary = {}
var profile_uid_label: Label
var profile_status_label: Label
var owned_characters: Array = ["Striker"]
var owned_outfits: Array = ["Academy Blue"]
var equipped_outfit := "Academy Blue"
var tutorial_completed := false
var tutorial_layer: CanvasLayer
var tutorial_step_label: Label
var tutorial_body_label: Label
var tutorial_index := 0
var settings_sensitivity := 1.0
var settings_music_enabled := true


func _ready() -> void:
	rng.randomize()
	var loading := _create_loading_screen()
	await get_tree().process_frame
	_set_loading_stage(loading, 8, "PREPARING THE ARENA")
	await get_tree().process_frame
	_build_world()
	_set_loading_stage(loading, 22, "BUILDING THE PITCH")
	await get_tree().process_frame
	_build_pitch()
	_build_goals()
	_set_loading_stage(loading, 40, "ASSEMBLING THE TEAMS")
	await get_tree().process_frame
	_build_players()
	_build_ball()
	_set_loading_stage(loading, 60, "SETTING UP CAMERA")
	await get_tree().process_frame
	_build_camera()
	_build_ui()
	_set_loading_stage(loading, 78, "LOADING YOUR CAREER")
	await get_tree().process_frame
	_load_progress()
	_build_lobby()
	_update_hud()
	_set_loading_stage(loading, 100, "READY TO PLAY")
	await get_tree().create_timer(0.25).timeout
	if is_instance_valid(loading):
		var fade := create_tween()
		fade.tween_property(loading, "modulate:a", 0.0, 0.35)
		fade.tween_callback(func() -> void:
			if is_instance_valid(loading):
				loading.queue_free()
			if is_instance_valid(lobby_layer):
				lobby_layer.visible = true
				lobby_layer.modulate.a = 1.0
				_show_hub_tab("HOME")
		)

func _create_loading_screen() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = "StartupLoadingScreen"
	layer.layer = 50
	add_child(layer)
	var backdrop := ColorRect.new()
	backdrop.anchor_right = 1.0
	backdrop.anchor_bottom = 1.0
	backdrop.color = Color(0.012, 0.018, 0.045, 1.0)
	layer.add_child(backdrop)
	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.offset_left = 24
	center.offset_right = -24
	layer.add_child(center)
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 12)
	stack.custom_minimum_size = Vector2(280, 0)
	center.add_child(stack)
	var emblem := Label.new()
	emblem.text = "◉"
	emblem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emblem.add_theme_font_size_override("font_size", 76)
	emblem.add_theme_color_override("font_color", Color(0.18, 0.68, 1.0))
	stack.add_child(emblem)
	var title := Label.new()
	title.text = "ECLIPSE STRIKERS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", Color(0.38, 0.84, 1.0))
	stack.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "3D ANIME FOOTBALL"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.75, 0.8, 0.92))
	stack.add_child(subtitle)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	stack.add_child(spacer)
	var progress := ProgressBar.new()
	progress.name = "LoadingProgress"
	progress.min_value = 0
	progress.max_value = 100
	progress.value = 0
	progress.show_percentage = false
	progress.custom_minimum_size = Vector2(0, 12)
	stack.add_child(progress)
	var status := Label.new()
	status.name = "LoadingStatus"
	status.text = "INITIALIZING..."
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 14)
	status.add_theme_color_override("font_color", Color(0.9, 0.92, 1.0))
	stack.add_child(status)
	var footer := Label.new()
	footer.text = "PLAY OFFLINE ANYTIME  •  RANKED NEEDS INTERNET"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 11)
	footer.add_theme_color_override("font_color", Color(0.5, 0.58, 0.72))
	stack.add_child(footer)
	var pulse := create_tween().set_loops()
	pulse.tween_property(emblem, "scale", Vector2(1.12, 1.12), 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(emblem, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return layer

func _set_loading_stage(layer: CanvasLayer, progress_value: float, message: String) -> void:
	if not is_instance_valid(layer):
		return
	var progress := layer.find_child("LoadingProgress", true, false) as ProgressBar
	var status := layer.find_child("LoadingStatus", true, false) as Label
	if progress:
		progress.value = progress_value
	if status:
		status.text = message


func _build_founder_intro() -> void:
	# Founder-only cinematic intro: no roster or extra characters appear here.
	lobby_layer.visible = false
	var intro := CanvasLayer.new()
	intro.layer = 30
	add_child(intro)
	var backdrop := ColorRect.new()
	backdrop.anchor_right = 1.0
	backdrop.anchor_bottom = 1.0
	backdrop.color = Color(0.008, 0.012, 0.035, 1.0)
	intro.add_child(backdrop)
	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.offset_left = 16
	center.offset_right = -16
	intro.add_child(center)
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 14)
	center.add_child(stack)
	var aura := Label.new()
	aura.text = "◉"
	aura.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aura.add_theme_font_size_override("font_size", 94)
	aura.add_theme_color_override("font_color", Color(0.2, 0.68, 1.0, 0.95))
	stack.add_child(aura)
	var title := Label.new()
	title.text = "ECLIPSE STRIKERS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 29)
	title.add_theme_color_override("font_color", Color(0.35, 0.82, 1.0))
	stack.add_child(title)
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(180, 3)
	line.color = Color(0.85, 0.12, 0.28, 0.95)
	stack.add_child(line)
	var founder := Label.new()
	founder.text = "FOUNDER\nSTALIN VISMAY"
	founder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	founder.add_theme_font_size_override("font_size", 23)
	founder.add_theme_color_override("font_color", Color(1.0, 0.94, 0.9))
	stack.add_child(founder)
	var identity := Label.new()
	identity.text = "KING OF KINGS  •  INNOCENT ZERO"
	identity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	identity.add_theme_font_size_override("font_size", 13)
	identity.add_theme_color_override("font_color", Color(0.72, 0.78, 0.92))
	stack.add_child(identity)
	var skip := Button.new()
	skip.text = "ENTER THE ARENA  ▶"
	skip.custom_minimum_size = Vector2(210, 44)
	skip.add_theme_color_override("font_color", Color.WHITE)
	skip.add_theme_stylebox_override("normal", _panel_style(Color(0.04, 0.22, 0.42), Color(0.2, 0.68, 1.0)))
	stack.add_child(skip)
	var finish_intro := func() -> void:
		if is_instance_valid(intro):
			var fade := create_tween()
			fade.tween_property(intro, "modulate:a", 0.0, 0.35)
			fade.tween_callback(func() -> void:
				if is_instance_valid(intro):
					intro.queue_free()
				if is_instance_valid(lobby_layer):
					lobby_layer.visible = true
					if not tutorial_completed:
						_start_tutorial()
			)
	skip.pressed.connect(finish_intro)
	var pulse := create_tween().set_loops()
	pulse.tween_property(aura, "scale", Vector2(1.13, 1.13), 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(aura, "scale", Vector2.ONE, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var reveal := create_tween()
	reveal.tween_interval(4.5)
	reveal.tween_callback(finish_intro)

func _process(delta: float) -> void:
	_update_aim_guide()
	_update_network_session(delta)
	if match_active and not is_paused:
		time_left = maxf(0.0, time_left - delta)
		if time_left <= 0.0:
			match_active = false
			if score_home > score_away:
				wins_total += 1
				match_coins += 50
			else:
				match_coins += 20
			player_level = 1 + int(wins_total / 3) + int(goals_total / 10)
			_save_progress()
			var stats := lobby_layer.find_child("ProgressStats", true, false) as Label
			if stats:
				stats.text = "LEVEL %d   •   WINS %d   •   GOALS %d" % [player_level, wins_total, goals_total]
			ui_hint.text = "FULL TIME  •  Tap RESTART to play again"
		_update_hud()
	if burst_time > 0.0:
		burst_time = maxf(0.0, burst_time - delta)
	if burst_cooldown > 0.0:
		burst_cooldown = maxf(0.0, burst_cooldown - delta)
	if dribble_knock_cooldown > 0.0:
		dribble_knock_cooldown = maxf(0.0, dribble_knock_cooldown - delta)
	if first_touch_cooldown > 0.0:
		first_touch_cooldown = maxf(0.0, first_touch_cooldown - delta)
	if ultimate_cooldown > 0.0:
		ultimate_cooldown = maxf(0.0, ultimate_cooldown - delta)
	if pass_request_cooldown > 0.0:
		pass_request_cooldown = maxf(0.0, pass_request_cooldown - delta)
	if call_pass_button:
		call_pass_button.text = "CALL PASS" if pass_request_cooldown <= 0.0 else "CALL %ds" % int(ceil(pass_request_cooldown))
	if ultimate_button:
		ultimate_button.text = "ULTIMATE" if ultimate_cooldown <= 0.0 else "ULT " + str(int(ceil(ultimate_cooldown))) + "s"
	if player_visual and player:
		var moving := Vector2(player.velocity.x, player.velocity.z).length() > 0.5
		run_phase += delta * (12.0 if moving else 3.0)
		player_visual.position.y = 0.95 + (absf(sin(run_phase)) * 0.10 if moving else 0.0)
		player_visual.rotation.z = sin(run_phase * 0.5) * 0.06 if moving else lerpf(player_visual.rotation.z, 0.0, delta * 5.0)
		if player_left_leg and player_right_leg and kick_anim_time <= 0.0:
			var stride := sin(run_phase) * (0.55 if moving else 0.035)
			player_left_leg.rotation.x = stride
			player_right_leg.rotation.x = -stride
			if player_left_arm and player_right_arm:
				player_left_arm.rotation.x = -stride * 0.65
				player_right_arm.rotation.x = stride * 0.65
	if kick_anim_time > 0.0:
		kick_anim_time = maxf(0.0, kick_anim_time - delta)
		if kick_anim_leg:
			var progress := 1.0 - kick_anim_time / 0.34
			kick_anim_leg.rotation.x = -1.15 * sin(progress * PI) if progress < 1.0 else 0.0
		if player_visual:
			player_visual.rotation.z = sin((1.0 - kick_anim_time / 0.34) * PI) * -0.16
	if is_instance_valid(ball_visual) and is_instance_valid(ball):
		var speed_spin := ball.linear_velocity.length()
		ball_visual.rotate_x(delta * speed_spin * 0.65)
		ball_visual.rotate_z(delta * speed_spin * 0.45)
		var ground_dist := maxf(0.0, ball.global_position.y - BALL_RADIUS)
		ball_visual.position.y = 0.0
		ball_visual.scale = Vector3.ONE * (1.0 + minf(0.08, ground_dist * 0.06))
	if burst_time > 0.0 and player:
		burst_fx_timer -= delta
		if burst_fx_timer <= 0.0:
			burst_fx_timer = 0.12
			_spawn_skill_burst(player.global_position + Vector3(0, 0.12, 0), Color(0.15, 0.75, 1.0))
	if goal_flash_time > 0.0 and goal_flash:
		goal_flash_time = maxf(0.0, goal_flash_time - delta)
		var flash_color := goal_flash.color
		flash_color.a = clampf(goal_flash_time * 1.8, 0.0, 0.28)
		goal_flash.color = flash_color
	if camera_rig and player:
		var target := player.global_position
		camera_rig.global_position = camera_rig.global_position.lerp(target, minf(1.0, delta * 5.0))
		camera_rig.rotation.y = lerp_angle(camera_rig.rotation.y, player.rotation.y, minf(1.0, delta * 3.0))
		if joystick_knob and joystick_base:
			var offset := joystick_vector * 35.0 * settings_sensitivity
			joystick_knob.position = Vector2(42, 42) + offset

func _physics_process(delta: float) -> void:
	if is_paused:
		return
	if not match_active:
		_move_ball(delta)
		return
	_move_user(delta)
	if multiplayer.multiplayer_peer == null or multiplayer.is_server():
		_move_bots(delta)
		_move_ball(delta)
		_update_pitch_conditions(delta)
		_update_adaptive_ai(delta)
		_check_goals()

func _build_world() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = ProceduralSkyMaterial.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.7, 0.78, 0.9)
	environment.ambient_light_energy = 0.8
	env.environment = environment
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -30, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)

func _material(color: Color, roughness := 0.8) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat

func _mesh_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi

func _build_pitch() -> void:
	var grass := _material(Color(0.08, 0.37, 0.18))
	_mesh_box(self, Vector3(FIELD_LENGTH, 0.3, FIELD_WIDTH), Vector3(0, -0.2, 0), grass)
	for i in range(7):
		var stripe_mat := _material(Color(0.10 if i % 2 == 0 else 0.12, 0.42 if i % 2 == 0 else 0.46, 0.20))
		_mesh_box(self, Vector3(FIELD_LENGTH / 7.0, 0.015, FIELD_WIDTH), Vector3(-FIELD_LENGTH / 2.0 + FIELD_LENGTH / 14.0 + i * FIELD_LENGTH / 7.0, -0.04, 0), stripe_mat)
	var white := _material(Color(0.92, 0.95, 0.91))
	_mesh_box(self, Vector3(0.08, 0.03, FIELD_WIDTH - 0.3), Vector3(0, -0.025, 0), white)
	_mesh_box(self, Vector3(0.08, 0.03, FIELD_WIDTH - 0.3), Vector3(-FIELD_LENGTH / 2.0 + 0.2, -0.025, 0), white)
	_mesh_box(self, Vector3(0.08, 0.03, FIELD_WIDTH - 0.3), Vector3(FIELD_LENGTH / 2.0 - 0.2, -0.025, 0), white)
	_mesh_box(self, Vector3(FIELD_LENGTH - 0.3, 0.03, 0.08), Vector3(0, -0.025, -FIELD_WIDTH / 2.0 + 0.2), white)
	_mesh_box(self, Vector3(FIELD_LENGTH - 0.3, 0.03, 0.08), Vector3(0, -0.025, FIELD_WIDTH / 2.0 - 0.2), white)
	var center := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 3.7
	ring.outer_radius = 3.82
	center.mesh = ring
	center.position = Vector3(0, -0.015, 0)
	center.material_override = white
	add_child(center)
	# Low perimeter barriers and stadium seating blocks create a sense of scale.
	var dark := _material(Color(0.035, 0.07, 0.11))
	_mesh_box(self, Vector3(FIELD_LENGTH + 2, 0.6, 0.45), Vector3(0, 0.1, -FIELD_WIDTH / 2.0 - 0.45), dark)
	_mesh_box(self, Vector3(FIELD_LENGTH + 2, 0.6, 0.45), Vector3(0, 0.1, FIELD_WIDTH / 2.0 + 0.45), dark)
	for side in [-1.0, 1.0]:
		for tier in range(5):
			var seat_mat := _material([Color(0.045,0.075,0.13), Color(0.065,0.11,0.19), Color(0.09,0.15,0.25), Color(0.12,0.19,0.3), Color(0.15,0.23,0.35)][tier])
			_mesh_box(self, Vector3(FIELD_LENGTH + 10, 0.48, 1.25), Vector3(0, 0.25 + tier * 0.48, side * (FIELD_WIDTH / 2.0 + 1.8 + tier * 0.92)), seat_mat)
	# Proper penalty areas, six-yard boxes and penalty spots.
	for end in [-1.0, 1.0]:
		var box_x: float = float(end) * (FIELD_LENGTH / 2.0 - 4.0)
		_mesh_box(self, Vector3(0.07, 0.025, 15.0), Vector3(box_x, -0.018, 0), white)
		_mesh_box(self, Vector3(6.0, 0.025, 0.07), Vector3(end * (FIELD_LENGTH / 2.0 - 7.0), -0.018, -7.5), white)
		_mesh_box(self, Vector3(6.0, 0.025, 0.07), Vector3(end * (FIELD_LENGTH / 2.0 - 7.0), -0.018, 7.5), white)
		_mesh_box(self, Vector3(0.07, 0.025, 7.0), Vector3(end * (FIELD_LENGTH / 2.0 - 1.0), -0.018, 0), white)
		_mesh_box(self, Vector3(0.07, 0.025, 0.07), Vector3(end * (FIELD_LENGTH / 2.0 - 7.0), -0.005, 0), white)
	# Stadium fascia and subtle anime-arena cyan lighting.
	var fascia := _material(Color(0.025, 0.045, 0.085))
	_mesh_box(self, Vector3(FIELD_LENGTH + 14, 0.45, 0.7), Vector3(0, 2.65, -FIELD_WIDTH / 2.0 - 5.1), fascia)
	_mesh_box(self, Vector3(FIELD_LENGTH + 14, 0.45, 0.7), Vector3(0, 2.65, FIELD_WIDTH / 2.0 + 5.1), fascia)
	var glow := _material(Color(0.05, 0.55, 0.95))
	glow.emission_enabled = true
	glow.emission = Color(0.04, 0.38, 1.0)
	glow.emission_energy_multiplier = 1.3
	_mesh_box(self, Vector3(FIELD_LENGTH + 12, 0.07, 0.08), Vector3(0, 2.4, -FIELD_WIDTH / 2.0 - 5.0), glow)
	_mesh_box(self, Vector3(FIELD_LENGTH + 12, 0.07, 0.08), Vector3(0, 2.4, FIELD_WIDTH / 2.0 + 5.0), glow)
	# Floodlight towers around the pitch.
	for x in [-FIELD_LENGTH / 2.0 - 5.0, FIELD_LENGTH / 2.0 + 5.0]:
		for z in [-FIELD_WIDTH / 2.0 - 6.0, FIELD_WIDTH / 2.0 + 6.0]:
			_mesh_box(self, Vector3(0.22, 8.0, 0.22), Vector3(x, 4.0, z), _material(Color(0.12, 0.16, 0.23), 0.35))
			var lamp := _mesh_box(self, Vector3(1.6, 0.22, 0.65), Vector3(x, 8.0, z), glow)
			lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_goals() -> void:
	var goal_mat := _material(Color(0.93, 0.96, 1.0), 0.4)
	for x in [-FIELD_LENGTH / 2.0 - 0.65, FIELD_LENGTH / 2.0 + 0.65]:
		_mesh_box(self, Vector3(1.4, 0.15, 7.0), Vector3(x, 0.05, 0), _material(Color(0.1, 0.1, 0.12)))
		_mesh_box(self, Vector3(0.18, 2.3, 0.18), Vector3(x, 1.1, -3.1), goal_mat)
		_mesh_box(self, Vector3(0.18, 2.3, 0.18), Vector3(x, 1.1, 3.1), goal_mat)
		_mesh_box(self, Vector3(0.18, 0.18, 6.4), Vector3(x, 2.2, 0), goal_mat)
		var net_mat := _material(Color(0.55, 0.76, 0.9, 0.28), 0.95)
		# Fine net grid, rather than a solid translucent panel.
		for zline in range(13):
			_mesh_box(self, Vector3(1.55, 0.025, 0.025), Vector3(x + (0.78 if x < 0 else -0.78), 0.2 + zline * 0.16, -3.0 + zline * 0.5), net_mat)
		for hline in range(8):
			_mesh_box(self, Vector3(1.55, 0.025, 0.025), Vector3(x + (0.78 if x < 0 else -0.78), 0.18 + hline * 0.28, 0), net_mat)
		_mesh_box(self, Vector3(1.8, 0.08, 6.3), Vector3(x + (0.9 if x < 0 else -0.9), 0.12, 0), _material(Color(0.75, 0.85, 0.9, 0.25)))

func _make_player(team_home: bool, pos: Vector3, is_user := false) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.name = "HomePlayer" if team_home else "AwayPlayer"
	body.position = pos
	body.floor_snap_length = 0.4
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.42
	capsule.height = 1.65
	var mesh := MeshInstance3D.new()
	mesh.mesh = capsule
	mesh.position.y = 0.95
	mesh.material_override = _material(Color(0.08, 0.36, 0.95) if team_home else Color(0.92, 0.15, 0.12), 0.45)
	body.add_child(mesh)
	if is_user:
		player_visual = mesh
	# Anime-inspired athletic silhouette: defined torso, hair silhouette and bright eye band.
	var trim_mat := _material(Color(0.12, 0.86, 1.0) if team_home else Color(1.0, 0.36, 0.18), 0.35)
	_mesh_box(body, Vector3(0.56, 0.09, 0.46), Vector3(0, 1.12, 0), trim_mat)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.27
	sphere.height = 0.54
	head.mesh = sphere
	head.position = Vector3(0, 1.9, 0)
	head.material_override = _material(Color(0.72, 0.48, 0.32))
	body.add_child(head)
	var hair := MeshInstance3D.new()
	var hair_mesh := SphereMesh.new()
	hair_mesh.radius = 0.29
	hair_mesh.height = 0.28
	hair.mesh = hair_mesh
	hair.position = Vector3(0, 2.13, -0.015)
	hair.material_override = _material(Color(0.035, 0.045, 0.075) if team_home else Color(0.16, 0.035, 0.045), 0.4)
	body.add_child(hair)
	var eye_band := _mesh_box(body, Vector3(0.29, 0.045, 0.035), Vector3(0, 1.96, 0.245), trim_mat)
	eye_band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var limb_mat := _material(Color(0.055, 0.075, 0.12) if team_home else Color(0.16, 0.035, 0.045), 0.55)
	var leg_nodes: Array[MeshInstance3D] = []
	for leg_name in ["LeftLeg", "RightLeg"]:
		var leg := MeshInstance3D.new()
		var leg_mesh := BoxMesh.new()
		leg_mesh.size = Vector3(0.19, 0.52, 0.22)
		leg.mesh = leg_mesh
		leg.name = leg_name
		leg.position = Vector3(-0.17 if leg_name == "LeftLeg" else 0.17, 0.48, 0.0)
		leg.material_override = limb_mat
		body.add_child(leg)
		leg_nodes.append(leg)
	var arm_nodes: Array[MeshInstance3D] = []
	for arm_name in ["LeftArm", "RightArm"]:
		var arm := MeshInstance3D.new()
		var arm_mesh := BoxMesh.new()
		arm_mesh.size = Vector3(0.16, 0.5, 0.18)
		arm.mesh = arm_mesh
		arm.name = arm_name
		arm.position = Vector3(-0.34 if arm_name == "LeftArm" else 0.34, 1.08, 0.0)
		arm.material_override = limb_mat
		body.add_child(arm)
		arm_nodes.append(arm)
	if is_user:
		player_left_leg = leg_nodes[0]
		player_right_leg = leg_nodes[1]
		kick_anim_leg = player_right_leg
		player_left_arm = arm_nodes[0]
		player_right_arm = arm_nodes[1]
	var boot_mat := _material(Color(0.05, 0.06, 0.08))
	for z in [-0.22, 0.22]:
		var boot := MeshInstance3D.new()
		var bootmesh := BoxMesh.new()
		bootmesh.size = Vector3(0.22, 0.16, 0.32)
		boot.mesh = bootmesh
		boot.position = Vector3(0, 0.18, z)
		boot.material_override = boot_mat
		body.add_child(boot)
	var shape := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.42
	capsule_shape.height = 1.65
	shape.shape = capsule_shape
	shape.position.y = 0.92
	body.add_child(shape)
	add_child(body)
	if is_user:
		player = body
	return body

func _build_players() -> void:
	player = _make_player(true, Vector3(-12, 0, 0), true)
	teammates.append(_make_player(true, Vector3(-7, 0, -7)))
	teammates.append(_make_player(true, Vector3(-1, 0, 7)))
	teammates.append(_make_player(true, Vector3(-9, 0, 1)))
	opponents.append(_make_player(false, Vector3(11, 0, 0)))
	opponents.append(_make_player(false, Vector3(7, 0, -7)))
	opponents.append(_make_player(false, Vector3(1, 0, 7)))
	opponents.append(_make_player(false, Vector3(9, 0, 1)))
	all_bots.append_array(teammates)
	all_bots.append_array(opponents)

func _build_ball() -> void:
	ball = RigidBody3D.new()
	ball.name = "Football"
	ball.position = Vector3.ZERO
	ball.mass = 0.43
	ball.linear_damp = 0.8
	ball.angular_damp = 0.8
	ball.continuous_cd = true
	var sphere := SphereMesh.new()
	sphere.radius = BALL_RADIUS
	sphere.height = BALL_RADIUS * 2.0
	var mesh := MeshInstance3D.new()
	mesh.mesh = sphere
	mesh.name = "AnimatedBallVisual"
	mesh.material_override = _material(Color(0.95, 0.95, 0.9), 0.3)
	ball.add_child(mesh)
	ball_visual = mesh
	var shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = BALL_RADIUS
	shape.shape = sphere_shape
	ball.add_child(shape)
	add_child(ball)

func _build_camera() -> void:
	camera_rig = Node3D.new()
	camera_rig.position = player.position
	add_child(camera_rig)
	camera = Camera3D.new()
	camera.position = Vector3(0, 5.2, 8.8)
	camera.rotation_degrees = Vector3(-24, 0, 0)
	camera.current = true
	camera.fov = 75
	camera_rig.add_child(camera)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var top := HBoxContainer.new()
	top.anchor_left = 0.25
	top.anchor_right = 0.75
	top.anchor_top = 0.025
	top.anchor_bottom = 0.12
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	layer.add_child(top)
	ui_score = Label.new()
	ui_score.add_theme_font_size_override("font_size", 30)
	ui_score.add_theme_color_override("font_color", Color.WHITE)
	top.add_child(ui_score)
	ui_timer = Label.new()
	ui_timer.add_theme_font_size_override("font_size", 27)
	ui_timer.add_theme_color_override("font_color", Color(1, 0.9, 0.35))
	top.add_child(ui_timer)
	ui_hint = Label.new()
	ui_hint.text = "BLUE TEAM  •  Score more goals!"
	ui_hint.anchor_left = 0.28
	ui_hint.anchor_right = 0.72
	ui_hint.anchor_top = 0.13
	ui_hint.anchor_bottom = 0.2
	ui_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_hint.add_theme_font_size_override("font_size", 17)
	ui_hint.add_theme_color_override("font_color", Color.WHITE)
	layer.add_child(ui_hint)
	joystick_base = Control.new()
	joystick_base.anchor_left = 0.035
	joystick_base.anchor_right = 0.035
	joystick_base.anchor_top = 0.69
	joystick_base.anchor_bottom = 0.69
	joystick_base.position = Vector2.ZERO
	joystick_base.size = Vector2(100, 100)
	joystick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(joystick_base)
	var base_panel := Panel.new()
	base_panel.size = Vector2(100, 100)
	base_panel.position = Vector2.ZERO
	base_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.1,0.2,0.3,0.55), Color(0.8,0.9,1,0.5)))
	joystick_base.add_child(base_panel)
	joystick_knob = Panel.new()
	joystick_knob.position = Vector2(28, 28)
	joystick_knob.size = Vector2(44, 44)
	joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick_knob.add_theme_stylebox_override("panel", _panel_style(Color(0.65,0.82,1,0.9), Color(1,1,1,0.9)))
	joystick_base.add_child(joystick_knob)
	shoot_button = _make_button(layer, "SHOOT", Vector2(-128, -142), Color(0.85,0.12,0.13))
	shoot_button.pressed.connect(_shoot)
	pass_button = _make_button(layer, "PASS", Vector2(-235, -80), Color(0.05,0.4,0.85))
	pass_button.pressed.connect(_pass_ball)
	var lob_button := _make_button(layer, "LOB / THROUGH", Vector2(-350, -145), Color(0.05, 0.52, 0.58))
	lob_button.size = Vector2(112, 58)
	lob_button.add_theme_font_size_override("font_size", 11)
	lob_button.pressed.connect(_lob_through_pass)
	var finesse_button := _make_button(layer, "FINESSE", Vector2(-235, -215), Color(0.62, 0.26, 0.72))
	finesse_button.pressed.connect(_finesse_shot)
	var tackle_button := _make_button(layer, "TACKLE", Vector2(-128, -215), Color(0.75, 0.34, 0.08))
	tackle_button.pressed.connect(_tackle)
	call_pass_button = _make_button(layer, "CALL PASS", Vector2(-350, -80), Color(0.08,0.58,0.42))
	call_pass_button.size = Vector2(108, 58)
	call_pass_button.add_theme_font_size_override("font_size", 13)
	call_pass_button.pressed.connect(_request_teammate_pass)
	burst_button = _make_button(layer, "BURST", Vector2(-128, -62), Color(0.45,0.2,0.8))
	burst_button.pressed.connect(_burst)
	jockey_button = _make_button(layer, "JOCKEY", Vector2(-350, -215), Color(0.1, 0.56, 0.42))
	jockey_button.size = Vector2(108, 58)
	jockey_button.add_theme_font_size_override("font_size", 12)
	jockey_button.pressed.connect(_toggle_jockey)
	ultimate_button = _make_button(layer, "ULTIMATE", Vector2(-238, -155), Color(0.06, 0.72, 0.92))
	ultimate_button.size = Vector2(112, 58)
	ultimate_button.pressed.connect(_use_ultimate)
	var restart := _make_button(layer, "RESTART", Vector2(18, -55), Color(0.08,0.45,0.24))
	restart.anchor_left = 0.5
	restart.anchor_right = 0.5
	restart.anchor_top = 0.15
	restart.anchor_bottom = 0.15
	restart.position = Vector2(-138, 0)
	restart.size = Vector2(130, 44)
	restart.pressed.connect(_restart)
	var lobby_button := _make_button(layer, "LOBBY", Vector2.ZERO, Color(0.22,0.25,0.34))
	lobby_button.anchor_left = 0.5
	lobby_button.anchor_right = 0.5
	lobby_button.anchor_top = 0.15
	lobby_button.anchor_bottom = 0.15
	lobby_button.position = Vector2(8, 0)
	lobby_button.size = Vector2(112, 44)
	lobby_button.pressed.connect(_return_to_lobby)
	goal_banner = Label.new()
	goal_banner.anchor_left = 0.15
	goal_banner.anchor_right = 0.85
	goal_banner.anchor_top = 0.31
	goal_banner.anchor_bottom = 0.49
	goal_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	goal_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	goal_banner.add_theme_font_size_override("font_size", 36)
	goal_banner.add_theme_color_override("font_color", Color(1.0, 0.88, 0.28))
	goal_banner.add_theme_color_override("font_shadow_color", Color(0.02, 0.04, 0.1, 1.0))
	goal_banner.add_theme_constant_override("shadow_offset_x", 3)
	goal_banner.add_theme_constant_override("shadow_offset_y", 4)
	goal_banner.text = ""
	goal_banner.modulate.a = 0.0
	goal_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(goal_banner)
	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "ProceduralSFX"
	sfx_player.volume_db = -7.0
	add_child(sfx_player)
	var aim_material := StandardMaterial3D.new()
	aim_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aim_material.albedo_color = Color(0.15, 0.95, 1.0, 0.9)
	aim_material.emission_enabled = true
	aim_material.emission = Color(0.05, 0.7, 1.0)
	aim_material.emission_energy_multiplier = 1.8
	var aim_mesh := ImmediateMesh.new()
	aim_line = MeshInstance3D.new()
	aim_line.name = "ShotTrajectoryGuide"
	aim_line.mesh = aim_mesh
	aim_line.material_override = aim_material
	add_child(aim_line)
	goal_flash = ColorRect.new()
	goal_flash.anchor_right = 1.0
	goal_flash.anchor_bottom = 1.0
	goal_flash.color = Color(0.1, 0.9, 1.0, 0.0)
	goal_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(goal_flash)
	# Compact top-corner controls keep pause and sound accessible on phones.
	pause_button = Button.new()
	pause_button.text = "PAUSE"
	pause_button.anchor_left = 1.0
	pause_button.anchor_right = 1.0
	pause_button.anchor_top = 0.025
	pause_button.anchor_bottom = 0.025
	pause_button.position = Vector2(-108, 0)
	pause_button.size = Vector2(92, 38)
	pause_button.add_theme_font_size_override("font_size", 14)
	pause_button.pressed.connect(_toggle_pause)
	layer.add_child(pause_button)
	sound_button = Button.new()
	sound_button.text = "SFX ON"
	sound_button.anchor_left = 1.0
	sound_button.anchor_right = 1.0
	sound_button.anchor_top = 0.025
	sound_button.anchor_bottom = 0.025
	sound_button.position = Vector2(-208, 0)
	sound_button.size = Vector2(88, 38)
	sound_button.add_theme_font_size_override("font_size", 14)
	sound_button.pressed.connect(_toggle_sound)
	layer.add_child(sound_button)
	goal_banner.move_to_front()

func _toggle_pause() -> void:
	if not match_active:
		ui_hint.text = "Start a match before pausing"
		return
	is_paused = not is_paused
	joystick_vector = Vector2.ZERO
	if pause_button:
		pause_button.text = "RESUME" if is_paused else "PAUSE"
	ui_hint.text = "MATCH PAUSED" if is_paused else "MATCH RESUMED"

func _toggle_sound() -> void:
	sound_enabled = not sound_enabled
	if sound_button:
		sound_button.text = "SFX ON" if sound_enabled else "SFX OFF"
	ui_hint.text = "Sound effects enabled" if sound_enabled else "Sound effects muted"

func _panel_style(bg: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(50)
	return style

func _make_button(layer: CanvasLayer, caption: String, offset: Vector2, color: Color) -> Button:
	var b := Button.new()
	b.text = caption
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.anchor_top = 1.0
	b.anchor_bottom = 1.0
	b.position = offset
	b.size = Vector2(100, 72) if caption != "BURST" else Vector2(100, 54)
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", Color.WHITE)
	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.set_corner_radius_all(18)
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	b.add_theme_stylebox_override("normal", normal)
	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = color.lightened(0.2)
	pressed_style.set_corner_radius_all(18)
	b.add_theme_stylebox_override("pressed", pressed_style)
	layer.add_child(b)
	return b

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and event.position.x < get_viewport().get_visible_rect().size.x * 0.45 and event.position.y > get_viewport().get_visible_rect().size.y * 0.55:
			joystick_touch_id = event.index
			touch_origin = event.position
			joystick_vector = Vector2.ZERO
		elif not event.pressed and event.index == joystick_touch_id:
			joystick_touch_id = -1
			joystick_vector = Vector2.ZERO
	elif event is InputEventScreenDrag and event.index == joystick_touch_id:
		var d: Vector2 = event.position - touch_origin
		joystick_vector = Vector2(clampf(d.x / 52.0, -1.0, 1.0), clampf(d.y / 52.0, -1.0, 1.0))
	elif event is InputEventMouseButton:
		if event.pressed and event.position.x < get_viewport().get_visible_rect().size.x * 0.45 and event.position.y > get_viewport().get_visible_rect().size.y * 0.55:
			joystick_touch_id = 999
			touch_origin = event.position
		elif not event.pressed and joystick_touch_id == 999:
			joystick_touch_id = -1
			joystick_vector = Vector2.ZERO
	elif event is InputEventMouseMotion and joystick_touch_id == 999:
		var d: Vector2 = event.position - touch_origin
		joystick_vector = Vector2(clampf(d.x / 52.0, -1.0, 1.0), clampf(d.y / 52.0, -1.0, 1.0))

func _move_user(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var input_dir := joystick_vector
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): input_dir.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): input_dir.x += 1.0
	input_dir = input_dir.limit_length(1.0)
	var forward := -camera_rig.global_basis.z
	forward.y = 0
	forward = forward.normalized()
	var right := camera_rig.global_basis.x
	right.y = 0
	right = right.normalized()
	var direction := (right * input_dir.x + forward * -input_dir.y).normalized()
	var speed := PLAYER_SPEED * (1.8 if burst_time > 0.0 else (0.62 if jockey_mode else 1.0))
	var target_velocity := direction * speed
	var response := 13.0 if direction.length() > 0.1 else 8.0
	player.velocity.x = move_toward(player.velocity.x, target_velocity.x, response * delta)
	player.velocity.z = move_toward(player.velocity.z, target_velocity.z, response * delta)
	player.velocity.y = -0.5
	player.move_and_slide()
	if direction.length() > 0.1:
		player.rotation.y = lerp_angle(player.rotation.y, atan2(-direction.x, -direction.z), minf(1.0, delta * 8.0))
		# Gentle touches preserve free ball movement while rewarding close control.
		if ball and player.global_position.distance_to(ball.global_position) < 1.35 and dribble_knock_cooldown <= 0.0 and ball.global_position.y < 0.9:
			var touch_strength := 1.0 if input_dir.length() < 0.65 else 2.4
			ball.apply_central_impulse((direction * touch_strength) + Vector3(0, 0.04, 0))
			dribble_knock_cooldown = 0.16
	player.position.x = clampf(player.position.x, -FIELD_LENGTH / 2.0 + 1.0, FIELD_LENGTH / 2.0 - 1.0)
	player.position.z = clampf(player.position.z, -FIELD_WIDTH / 2.0 + 1.0, FIELD_WIDTH / 2.0 - 1.0)

func _move_bots(delta: float) -> void:
	for bot in all_bots:
		if not is_instance_valid(bot):
			continue
		var target := ball.global_position
		if pass_request_active and teammates.has(bot):
			target = ball.global_position
		if teammates.has(bot) and bot.global_position.distance_to(ball.global_position) > 8.0:
			target = Vector3(-5, 0, 0) if bot == teammates[0] else Vector3(ball.global_position.x - 3.0, 0, ball.global_position.z + (2.0 if bot == teammates[1] else -2.0))
		if opponents.has(bot) and bot.global_position.distance_to(ball.global_position) > 11.0:
			target = Vector3(5, 0, ball.global_position.z * 0.6)
		if opponents.has(bot) and bot.has_meta("pressing") and bool(bot.get_meta("pressing")):
			target = ball.global_position + Vector3(-1.5, 0, signf(bot.global_position.z - ball.global_position.z) * 1.4)
		var to_target := target - bot.global_position
		to_target.y = 0
		var dir := to_target.normalized()
		var speed := BOT_SPEED * (0.82 if opponents.has(bot) else 1.0)
		bot.velocity.x = dir.x * speed
		bot.velocity.z = dir.z * speed
		bot.velocity.y = -0.5
		bot.move_and_slide()
		bot.position.x = clampf(bot.position.x, -FIELD_LENGTH / 2.0 + 0.8, FIELD_LENGTH / 2.0 - 0.8)
		bot.position.z = clampf(bot.position.z, -FIELD_WIDTH / 2.0 + 0.8, FIELD_WIDTH / 2.0 - 0.8)
		if dir.length() > 0.1:
			bot.rotation.y = atan2(-dir.x, -dir.z)
		if pass_request_active and teammates.has(bot) and bot.global_position.distance_to(ball.global_position) < 1.65:
			var receive_point := player.global_position + Vector3(0.0, 0.25, 0.0)
			var pass_dir := (receive_point - ball.global_position).normalized()
			pass_dir.y = 0.045
			ball.linear_velocity = Vector3.ZERO
			ball.apply_central_impulse(pass_dir.normalized() * 8.5)
			pass_request_active = false
			pass_request_cooldown = 3.0
			ui_hint.text = "TEAMMATE PASS!  •  CONTROL THE BALL"
			_play_sfx("pass")
			_spawn_skill_burst(ball.global_position, Color(0.15, 0.9, 0.55))
		elif bot.global_position.distance_to(ball.global_position) < 1.25 and rng.randf() < delta * 1.4:
			var goal_x := -FIELD_LENGTH / 2.0 if opponents.has(bot) else FIELD_LENGTH / 2.0
			var aim := Vector3(goal_x, 0.15, rng.randf_range(-2.5, 2.5)) - ball.global_position
			ball.apply_central_impulse(aim.normalized() * rng.randf_range(4.0, 7.0))

func _update_pitch_conditions(delta: float) -> void:
	if not match_active:
		return
	pitch_wear = clampf(pitch_wear + delta / maxf(MATCH_SECONDS, 1.0) * 0.22, 0.0, 1.0)

func _update_adaptive_ai(_delta: float) -> void:
	if not match_active:
		return
	var trailing_late := score_away < score_home and time_left < 35.0
	for rival in opponents:
		if is_instance_valid(rival):
			rival.set_meta("pressing", trailing_late)

func _move_ball(_delta: float) -> void:
	if ball.global_position.y < BALL_RADIUS:
		var p := ball.global_position
		p.y = BALL_RADIUS
		ball.global_position = p
		# Small, damped rebound so the ball visibly bounces instead of sticking to the turf.
		if ball.linear_velocity.y < -0.9:
			ball.linear_velocity.y = -ball.linear_velocity.y * 0.38
			ball.linear_velocity.x *= 0.94
			ball.linear_velocity.z *= 0.94
		else:
			ball.linear_velocity.y = 0.0
			var ground_damping := lerpf(0.94, 0.985, pitch_wetness)
			ball.linear_velocity.x *= ground_damping
			ball.linear_velocity.z *= ground_damping
		if ball.global_position.distance_to(player.global_position) < 1.15 and ball.linear_velocity.length() > 1.5 and first_touch_cooldown <= 0.0:
			var relative_speed := ball.linear_velocity.length()
			var control_factor := clampf(player_technique - relative_speed * 0.025 - pitch_wetness * 0.12, 0.22, 0.9)
			ball.linear_velocity *= 1.0 - control_factor * 0.48
			first_touch_cooldown = 0.55
	if absf(ball.global_position.z) > FIELD_WIDTH / 2.0 - 0.4:
		ball.linear_velocity.z *= -0.65
		ball.global_position.z = clampf(ball.global_position.z, -FIELD_WIDTH / 2.0 + 0.5, FIELD_WIDTH / 2.0 - 0.5)
	# Subtle spin adds a lateral curve to moving shots and passes.
	if absf(ball_spin) > 0.02 and ball.global_position.y < 2.2:
		var v := ball.linear_velocity
		ball.apply_central_force(Vector3(-v.z, 0.0, v.x) * ball_spin * 0.22)
		ball_spin = move_toward(ball_spin, 0.0, _delta * 0.42)
	ball.linear_velocity.x = clampf(ball.linear_velocity.x, -18.0, 18.0)
	ball.linear_velocity.z = clampf(ball.linear_velocity.z, -14.0, 14.0)

func _near_ball() -> bool:
	return player.global_position.distance_to(ball.global_position) < 2.0

func _shoot() -> void:
	if not match_active or not _near_ball():
		ui_hint.text = "Get closer to the ball to shoot"
		return
	var goal_target := Vector3(FIELD_LENGTH / 2.0 + 2.0, 1.0, clampf(-player.global_position.z * 0.45, -2.35, 2.35))
	var dir := (goal_target - ball.global_position).normalized()
	var shot_power := 13.0
	if selected_ability == "Power Shot":
		shot_power = 18.0
	if _send_online_ball_action("shoot", dir):
		ui_hint.text = "SHOT SENT TO HOST"
		return
	ball.apply_central_impulse(dir * shot_power)
	ball_spin = clampf(-player.global_position.z * 0.12, -1.8, 1.8)
	kick_anim_time = 0.34
	_play_sfx("kick")
	_spawn_skill_burst(ball.global_position, Color(1.0, 0.25, 0.12))
	ui_hint.text = "⚡ DIRECT SHOT! ⚡"

func _lob_through_pass() -> void:
	if not match_active or not _near_ball():
		ui_hint.text = "Get close to the ball for a lob pass"
		return
	var target := player.global_position + (-player.global_basis.z * 10.0)
	if not teammates.is_empty():
		var best := teammates[0]
		for mate in teammates:
			if mate.global_position.distance_to(player.global_position) > best.global_position.distance_to(player.global_position):
				best = mate
		target = best.global_position + (-best.global_basis.z * 2.5)
	var dir := (target - ball.global_position).normalized()
	dir.y = 0.34
	if _send_online_ball_action("lob", dir):
		ui_hint.text = "LOFTED PASS SENT TO HOST"
		return
	ball.apply_central_impulse(dir.normalized() * 9.2)
	ball_spin = clampf(player.global_position.z * 0.05, -0.7, 0.7)
	kick_anim_time = 0.3
	_play_sfx("pass")
	ui_hint.text = "LOFTED THROUGH BALL!"

func _finesse_shot() -> void:
	if not match_active or not _near_ball():
		ui_hint.text = "Get closer to the ball to finesse"
		return
	var target := Vector3(FIELD_LENGTH / 2.0 + 2.0, 1.0, clampf(-player.global_position.z * 0.7 + 1.0, -2.4, 2.4))
	var dir := (target - ball.global_position).normalized()
	if _send_online_ball_action("finesse", dir):
		ui_hint.text = "FINESSE SHOT SENT TO HOST"
		return
	ball.apply_central_impulse(dir * 10.5)
	ball_spin = -1.8 if player.global_position.z >= 0.0 else 1.8
	kick_anim_time = 0.4
	_play_sfx("kick")
	_spawn_skill_burst(ball.global_position, Color(0.8, 0.25, 1.0))
	ui_hint.text = "CURVE SHOT! AIM FOR THE CORNER"

func _toggle_jockey() -> void:
	if not match_active:
		ui_hint.text = "Start a match to use JOCKEY control"
		return
	jockey_mode = not jockey_mode
	if is_instance_valid(jockey_button):
		jockey_button.text = "JOCKEY ON" if jockey_mode else "JOCKEY"
		jockey_button.modulate = Color(0.45, 1.0, 0.72) if jockey_mode else Color.WHITE
	ui_hint.text = "JOCKEY ON • tighter movement" if jockey_mode else "JOCKEY OFF • full movement"


func _tackle() -> void:
	if not match_active:
		return
	if _near_ball() and _send_online_ball_action("tackle", ball.global_position - player.global_position):
		ui_hint.text = "TACKLE SENT TO HOST"
		return
	var closest: CharacterBody3D = null
	var closest_distance := 2.25
	for rival in opponents:
		var distance := player.global_position.distance_to(rival.global_position)
		if distance < closest_distance:
			closest = rival
			closest_distance = distance
	if closest != null:
		var push := (closest.global_position - player.global_position).normalized()
		closest.velocity.x += push.x * 5.0
		closest.velocity.z += push.z * 5.0
		if closest.global_position.distance_to(ball.global_position) < 1.8:
			ball.apply_central_impulse((push * 5.5) + Vector3(0, 0.3, 0))
		ui_hint.text = "STANDING TACKLE!"
	else:
		ui_hint.text = "NO OPPONENT IN TACKLING RANGE"

func _request_teammate_pass() -> void:
	if not match_active:
		ui_hint.text = "Start a match before calling for a pass"
		return
	if pass_request_cooldown > 0.0 or pass_request_active:
		ui_hint.text = "Your teammate is already responding!"
		return
	if teammates.is_empty():
		ui_hint.text = "No teammate available"
		return
	var nearest := teammates[0]
	var nearest_distance := nearest.global_position.distance_to(ball.global_position)
	for mate in teammates:
		var distance := mate.global_position.distance_to(ball.global_position)
		if distance < nearest_distance:
			nearest = mate
			nearest_distance = distance
	pass_request_active = true
	pass_request_cooldown = 1.0
	ui_hint.text = "PASS!  •  TEAMMATE MOVING TO THE BALL"

func _pass_ball() -> void:
	if not match_active or not _near_ball():
		ui_hint.text = "Get closer to the ball to pass"
		return
	var target := teammates[0].global_position if not teammates.is_empty() else player.global_position + Vector3(5,0,0)
	var dir := (target - ball.global_position).normalized()
	dir.y = 0.05
	var pass_power := 7.5
	if selected_ability == "Precision Pass":
		pass_power = 11.0
	if _send_online_ball_action("pass", dir):
		ui_hint.text = "PASS SENT TO HOST"
		return
	ball.apply_central_impulse(dir.normalized() * pass_power)
	passes_total += 1
	ball_spin = clampf(player.global_position.z * 0.04, -0.5, 0.5)
	kick_anim_time = 0.28
	_play_sfx("pass")
	_spawn_skill_burst(ball.global_position, Color(0.15, 0.65, 1.0))
	ui_hint.text = "◆ PERFECT PASS ◆"


func _use_ultimate() -> void:
	if not match_active:
		ui_hint.text = "Start a match before using your ultimate"
		return
	if selected_character != "Eclipse Ace":
		ui_hint.text = "Select ECLIPSE ACE in the lobby to unlock the ultimate"
		return
	if ultimate_cooldown > 0.0:
		ui_hint.text = "ECLIPSE BREAKER recharging..."
		return
	if not _near_ball():
		ui_hint.text = "Get close to the ball to unleash ECLIPSE BREAKER"
		return
	ultimate_cooldown = 32.0
	kick_anim_time = 0.46
	_play_sfx("ultimate")
	_spawn_skill_burst(player.global_position + Vector3(0, 0.5, 0), Color(0.25, 0.05, 0.95))
	_spawn_skill_burst(ball.global_position, Color(0.05, 0.9, 1.0))
	# Original anime-style finisher: high precision toward the goal with a small
	# controlled miss chance so the move is powerful but not an automatic score.
	var goal_x := FIELD_LENGTH / 2.0 + 2.0
	var in_range := player.global_position.x > 2.0
	var target_z := clampf(-player.global_position.z * 0.32, -2.15, 2.15)
	if in_range and rng.randf() > 0.80:
		target_z = 3.5 if rng.randf() > 0.5 else -3.5
	var target := Vector3(goal_x, 0.7, target_z)
	var dir := (target - ball.global_position).normalized()
	dir.y = 0.035
	ball.linear_velocity = Vector3.ZERO
	ball.apply_central_impulse(dir.normalized() * 22.0)
	ui_hint.text = "ECLIPSE BREAKER!! • 80% TARGET ACCURACY IN RANGE"
	if goal_banner:
		if goal_banner_tween and goal_banner_tween.is_running():
			goal_banner_tween.kill()
		goal_banner.text = "ECLIPSE BREAKER"
		goal_banner.scale = Vector2(0.45, 0.45)
		goal_banner.modulate.a = 1.0
		goal_banner.add_theme_color_override("font_color", Color(0.25, 0.9, 1.0))
		goal_banner_tween = create_tween()
		goal_banner_tween.set_parallel(true)
		goal_banner_tween.tween_property(goal_banner, "scale", Vector2(1.15, 1.15), 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		goal_banner_tween.tween_property(goal_banner, "modulate:a", 0.0, 1.25).set_delay(0.65)

func _burst() -> void:
	if selected_ability != "Speed Burst":
		ui_hint.text = "POWER SHOT selected — use SHOOT" if selected_ability == "Power Shot" else "PRECISION PASS selected — use PASS"
		return
	if burst_cooldown > 0.0:
		ui_hint.text = "BURST recharging..."
		return
	burst_time = 1.6
	burst_uses_total += 1
	burst_cooldown = 5.0
	_play_sfx("burst")
	burst_fx_timer = 0.0
	_spawn_skill_burst(player.global_position, Color(0.15, 0.75, 1.0))
	ui_hint.text = "⚡ ANIME BURST! ⚡"

func _check_goals() -> void:
	if ball.global_position.x > FIELD_LENGTH / 2.0 + 0.5 and absf(ball.global_position.z) < 3.1:
		score_home += 1
		goals_total += 1
		_reset_kickoff("GOAL! BLUE TEAM SCORES")
	elif ball.global_position.x < -FIELD_LENGTH / 2.0 - 0.5 and absf(ball.global_position.z) < 3.1:
		score_away += 1
		_reset_kickoff("RED TEAM SCORES")
	if absf(ball.global_position.x) > FIELD_LENGTH / 2.0 + 2.0:
		_reset_ball()

func _reset_ball() -> void:
	ball.global_position = Vector3.ZERO
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO

func _reset_kickoff(message: String) -> void:
	ui_hint.text = message
	if message.contains("SCORES") or message.contains("GOAL"):
		_show_goal_celebration(message)
		_play_sfx("goal")
	if goal_flash:
		goal_flash.color = Color(0.12, 0.95, 1.0, 0.28) if message.contains("GOAL") or message.contains("SCORES") else Color(0.1, 0.9, 1.0, 0.0)
		goal_flash_time = 0.35 if message.contains("GOAL") or message.contains("SCORES") else 0.0
	if message.contains("GOAL") or message.contains("SCORES"):
		_spawn_skill_burst(Vector3(FIELD_LENGTH / 2.0 if message.contains("BLUE") else -FIELD_LENGTH / 2.0, 0.2, 0), Color(1.0, 0.85, 0.2))
	_reset_ball()
	player.global_position = Vector3(-12,0,0)
	var starts_home := [Vector3(-7,0,-7), Vector3(-1,0,7), Vector3(-9,0,1)]
	var starts_away := [Vector3(11,0,0), Vector3(7,0,-7), Vector3(1,0,7), Vector3(9,0,1)]
	for i in range(teammates.size()):
		teammates[i].global_position = starts_home[i]
	for i in range(opponents.size()):
		opponents[i].global_position = starts_away[i]
	_update_hud()

func _restart() -> void:
	is_paused = false
	if pause_button:
		pause_button.text = "PAUSE"
	score_home = 0
	score_away = 0
	time_left = MATCH_SECONDS
	match_active = true
	burst_time = 0
	burst_cooldown = 0
	_reset_kickoff("KICK OFF!  •  Score more goals!")

func _update_hud() -> void:
	if not ui_score:
		return
	ui_score.text = "  BLUE  %d  -  %d  RED     " % [score_home, score_away]
	var total := int(ceil(time_left))
	ui_timer.text = "   %02d:%02d" % [total / 60, total % 60]
	if burst_button:
		if selected_ability == "Speed Burst":
			burst_button.text = "BURST" if burst_cooldown <= 0.0 else str(int(ceil(burst_cooldown))) + "s"
		else:
			burst_button.text = "SKILL"


func _build_lobby() -> void:
	lobby_layer = CanvasLayer.new()
	lobby_layer.layer = 10
	add_child(lobby_layer)
	var backdrop := ColorRect.new()
	backdrop.anchor_right = 1.0
	backdrop.anchor_bottom = 1.0
	backdrop.color = Color(0.012, 0.02, 0.055, 0.97)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	lobby_layer.add_child(backdrop)
	var root := VBoxContainer.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.offset_left = 14
	root.offset_right = -14
	root.offset_top = 10
	root.offset_bottom = -10
	root.add_theme_constant_override("separation", 8)
	lobby_layer.add_child(root)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	root.add_child(header)
	var brand := Label.new()
	brand.text = "ECLIPSE\nSTRIKERS"
	brand.add_theme_font_size_override("font_size", 22)
	brand.add_theme_color_override("font_color", Color(0.24, 0.82, 1.0))
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(brand)
	var wallet := Label.new()
	wallet.text = "◈ %d GP   ◆ %d EP" % [match_coins, premium_points]
	wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wallet.add_theme_font_size_override("font_size", 14)
	wallet.add_theme_color_override("font_color", Color(1.0, 0.82, 0.28))
	header.add_child(wallet)
	var nav := GridContainer.new()
	nav.columns = 3
	nav.add_theme_constant_override("h_separation", 4)
	nav.add_theme_constant_override("v_separation", 4)
	root.add_child(nav)
	for tab in ["HOME", "SQUAD", "VAULT", "STORE", "TASKS", "ONLINE", "PROFILE", "TACTICS", "SETTINGS"]:
		var nav_button := Button.new()
		nav_button.text = tab
		nav_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nav_button.custom_minimum_size.y = 38
		nav_button.add_theme_font_size_override("font_size", 11)
		nav_button.pressed.connect(_show_hub_tab.bind(tab))
		nav.add_child(nav_button)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	hub_content = VBoxContainer.new()
	hub_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hub_content.add_theme_constant_override("separation", 10)
	scroll.add_child(hub_content)
	lobby_status = Label.new()
	lobby_status.text = "OFFLINE READY • Quick Match and Career need no internet • Ranked requires internet."
	lobby_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lobby_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lobby_status.add_theme_font_size_override("font_size", 11)
	lobby_status.add_theme_color_override("font_color", Color(0.65, 0.78, 0.9))
	root.add_child(lobby_status)
	_show_hub_tab("HOME")


func _hub_heading(value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.25, 0.82, 1.0))
	return label


func _hub_text(value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.86, 0.9, 1.0))
	return label


func _hub_button(value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 44
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.42))
	button.add_theme_color_override("font_pressed_color", Color(0.25, 0.9, 1.0))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.045, 0.09, 0.18, 0.98)
	normal.border_color = Color(0.12, 0.48, 0.72, 0.9)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.08, 0.18, 0.31, 1.0)
	hover.border_color = Color(0.2, 0.82, 1.0, 1.0)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.12, 0.3, 0.42, 1.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.pressed.connect(callback)
	return button


func _show_hub_tab(tab: String) -> void:
	if not is_instance_valid(hub_content):
		return
	for child in hub_content.get_children():
		child.queue_free()
	match tab:
		"ONLINE":
			_build_online_panel()
		"PROFILE":
			_build_profile_panel()
		"VAULT":
			_build_vault_panel()
		"TASKS":
			_build_tasks_panel()
		"SQUAD":
			hub_content.add_child(_hub_heading("SQUAD • STARTING FOUR"))
			hub_content.add_child(_hub_text("Your controlled player is locked to third-person. Use quick swaps to change your role and team setup before kick-off."))
			var lineup := GridContainer.new()
			lineup.columns = 2
			lineup.add_theme_constant_override("h_separation", 8)
			lineup.add_theme_constant_override("v_separation", 8)
			hub_content.add_child(lineup)
			for entry in [
				["01 • YOU", selected_character, "PACE 88  SHOOT 84  STAMINA 82"],
				["02 • TEAMMATE", "Playmaker", "PACE 78  PASS 92  STAMINA 86"],
				["03 • TEAMMATE", "Winger", "PACE 94  DRIBBLE 88  STAMINA 80"],
				["04 • TEAMMATE", "Defender", "PACE 75  TACKLE 91  STAMINA 90"]
			]:
				var card := PanelContainer.new()
				card.custom_minimum_size = Vector2(125, 98)
				var body := VBoxContainer.new()
				card.add_child(body)
				var title := _hub_text(entry[0])
				title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.28))
				body.add_child(title)
				body.add_child(_hub_text(entry[1]))
				body.add_child(_hub_text(entry[2]))
				lineup.add_child(card)
			var swap_row := HBoxContainer.new()
			hub_content.add_child(swap_row)
			swap_row.add_child(_hub_button("QUICK SWAP ROLE", func():
				var choices := ["Striker", "Playmaker", "Defender", "Eclipse Ace"]
				var next_index := (choices.find(selected_character) + 1) % choices.size()
				selected_character = choices[next_index]
				if character_picker:
					character_picker.select(next_index)
				_show_hub_tab("SQUAD")
			))
			swap_row.add_child(_hub_button("KIT COLOUR", func():
				if color_picker:
					color_picker.select((color_picker.selected + 1) % color_picker.item_count)
					selected_team_color = color_picker.get_item_text(color_picker.selected)
				lobby_status.text = "Kit preset changed to " + selected_team_color + "."
			))
			hub_content.add_child(_hub_heading("PLAYER CARD • FORM & FITNESS"))
			hub_content.add_child(_hub_text("FORM  ▲ GOOD     FITNESS  ████████░░  82%     MORALE  HIGH"))
			hub_content.add_child(_hub_text("Contract: Academy prospect • Season 1 (career contract system is a visual prototype)"))
			hub_content.add_child(_hub_heading("CUSTOMIZATION"))
			hub_content.add_child(_hub_text("Kit, ability and character presets are available. Club badge, goalkeeper kit, stadium editor and celebration editor are planned, not connected yet."))
			_add_existing_loadout_controls()
		"STORE":
			_build_store_panel()
			hub_content.add_child(_hub_heading("CAREER REWARDS • EARN MORE GP"))
			hub_content.add_child(_hub_text("GP: %d   •   EP: %d" % [match_coins, premium_points]))
			hub_content.add_child(_hub_text("Match coins are earned from offline matches. Premium points are a non-purchasable prototype balance; no real-money purchases are enabled."))
			hub_content.add_child(_hub_button("CLAIM DAILY BONUS  +100 GP", func():
				if not daily_bonus_claimed:
					match_coins += 100
					daily_bonus_claimed = true
					_save_progress()
					lobby_status.text = "Daily bonus claimed: +100 GP."
				else:
					lobby_status.text = "Daily bonus already claimed on this save."
				_show_hub_tab("STORE")
			))
			hub_content.add_child(_hub_heading("SEASON TRACK"))
			hub_content.add_child(_hub_text("TIER %d / 10   •   NEXT: KIT COLOUR   •   WEEKLY CHALLENGE: SCORE 3 GOALS" % mini(10, 1 + int(goals_total / 3))))
			var track := ProgressBar.new()
			track.max_value = 10
			track.value = mini(10, goals_total)
			track.show_percentage = false
			track.custom_minimum_size.y = 18
			hub_content.add_child(track)
			hub_content.add_child(_hub_heading("INBOX / REWARDS"))
			hub_content.add_child(_hub_text("Match rewards: %d goals • %d wins. Rewards are saved locally on this device." % [goals_total, wins_total]))
			hub_content.add_child(_hub_button("CLAIM CAREER GOAL REWARD", func():
				if goals_total >= 3 and not goal_reward_claimed:
					match_coins += 150
					goal_reward_claimed = true
					_save_progress()
					lobby_status.text = "Career reward claimed: +150 GP."
				else:
					lobby_status.text = "Score 3 total goals; reward can be claimed once."
				_show_hub_tab("STORE")
			))
		"TACTICS":
			hub_content.add_child(_hub_heading("TACTICS • QUICK SETUP"))
			hub_content.add_child(_hub_text("Formation: 1-1-1-1 • small-sided 4v4. No offside, no fouls, continuous play."))
			for tactic in ["Balanced • keep passing lanes", "High Press • win it back quickly", "Counter Attack • sprint into space", "Compact • protect the middle"]:
				hub_content.add_child(_hub_button(tactic, func():
					selected_tactic = tactic
					lobby_status.text = "Tactic selected: " + selected_tactic
				))
			hub_content.add_child(_hub_text("Teamwork tip: tap CALL PASS to request the ball, move into space, then use PASS to combine."))
		"SETTINGS":
			hub_content.add_child(_hub_heading("SETTINGS • CONTROL YOUR ARENA"))
			hub_content.add_child(_hub_button("SOUND EFFECTS: " + ("ON" if sound_enabled else "OFF"), func():
				sound_enabled = not sound_enabled
				_save_progress()
				_show_hub_tab("SETTINGS")
			))
			hub_content.add_child(_hub_button("MUSIC: " + ("ON" if settings_music_enabled else "OFF"), func():
				settings_music_enabled = not settings_music_enabled
				_save_progress()
				_show_hub_tab("SETTINGS")
			))
			hub_content.add_child(_hub_heading("JOYSTICK SENSITIVITY"))
			var sensitivity := HSlider.new()
			sensitivity.min_value = 0.6
			sensitivity.max_value = 1.6
			sensitivity.step = 0.1
			sensitivity.value = settings_sensitivity
			sensitivity.custom_minimum_size.y = 32
			sensitivity.value_changed.connect(func(value: float):
				settings_sensitivity = value
				_save_progress()
			)
			hub_content.add_child(sensitivity)
			hub_content.add_child(_hub_text("Sensitivity: %.1fx • Adjust joystick response." % settings_sensitivity))
			hub_content.add_child(_hub_button("REPLAY 2-MINUTE TUTORIAL", func(): _start_tutorial(true)))
			hub_content.add_child(_hub_text("Left joystick: move • SHOOT: kick • PASS: teammate • LOB: aerial ball • BURST: sprint."))
			hub_content.add_child(_hub_text("Offline Quick Match/Career work without internet. Ranked needs internet and a live server, not yet deployed."))
		_:
			hub_content.add_child(_hub_heading("MATCHDAY • YOUR ARENA"))
			hub_content.add_child(_hub_text("FOUR PLAYERS. ONE BALL. NO STOPPAGES."))
			hub_content.add_child(_hub_text("OFFLINE PLAY: Quick Match and Career run without Wi-Fi or mobile data. Only Ranked will require internet."))
			hub_content.add_child(_hub_text("Control one player from a third-person camera. Win with spacing, quick passing and signature abilities."))
			var modes := GridContainer.new()
			modes.columns = 2
			modes.add_theme_constant_override("h_separation", 8)
			modes.add_theme_constant_override("v_separation", 8)
			hub_content.add_child(modes)
			modes.add_child(_hub_button("⚡ QUICK MATCH\nOffline vs AI", _start_match))
			modes.add_child(_hub_button("🏆 CAREER / CUP\nLocal progression", _start_match))
			modes.add_child(_hub_button("RANKED DIVISIONS\nInternet required", _request_ranked_match))
			modes.add_child(_hub_button("ONLINE CO-OP / PRO CLUBS\nOnline • locked", func():
				lobby_status.text = "Online 4v4 and friend parties are not connected yet; this build runs offline AI matches."
			))
			hub_content.add_child(_hub_heading("YOUR STARTING SQUAD"))
			hub_content.add_child(_hub_text("YOU • %s   |   PLAYMAKER   |   WINGER   |   DEFENDER" % selected_character.to_upper()))
			hub_content.add_child(_hub_text("WINS %d   •   GOALS %d   •   LEVEL %d" % [wins_total, goals_total, player_level]))
			hub_content.add_child(_hub_button("MANAGE SQUAD", func(): _show_hub_tab("SQUAD")))
			hub_content.add_child(_hub_button("STORE • SEASON TRACK • INBOX", func(): _show_hub_tab("STORE")))
			hub_content.add_child(_hub_heading("COMMUNITY"))
			hub_content.add_child(_hub_text("Friends: local placeholder • Clan leaderboard: planned • Quick chat/emotes: planned."))
			_add_existing_loadout_controls()


func _build_store_panel() -> void:
	hub_content.add_child(_hub_heading("STRIKER STORE • BUY WITH GP"))
	hub_content.add_child(_hub_text("◈ %d GP available. Earn coins by playing matches and completing tasks." % match_coins))
	hub_content.add_child(_hub_heading("CHARACTERS"))
	for item in [["Playmaker", 250, "Passing specialist"], ["Defender", 250, "Defensive powerhouse"], ["Eclipse Ace", 500, "Elite anime striker"]]:
		var item_name: String = item[0]
		var price: int = item[1]
		var description: String = item[2]
		var row := VBoxContainer.new()
		row.add_child(_hub_text(item_name + " • " + description))
		if owned_characters.has(item_name):
			row.add_child(_hub_text("OWNED ✓"))
		else:
			row.add_child(_hub_button("BUY " + item_name.to_upper() + " • %d GP" % price, func():
				if match_coins < price:
					lobby_status.text = "Not enough GP. Play matches or complete tasks."
					return
				match_coins -= price
				owned_characters.append(item_name)
				_save_progress()
				lobby_status.text = item_name + " unlocked! Equip it in the Vault."
				_show_hub_tab("STORE")
			))
		hub_content.add_child(row)
	hub_content.add_child(_hub_heading("OUTFITS / KITS"))
	for item in [["Academy Blue", 0, "Electric Blue"], ["Neon Surge", 120, "Neon Green"], ["Royal Eclipse", 180, "Royal Purple"], ["Crimson Phantom", 180, "Crimson Red"]]:
		var outfit_name: String = item[0]
		var price: int = item[1]
		var team_color: String = item[2]
		var row := HBoxContainer.new()
		row.add_child(_hub_text("%s • %s" % [outfit_name, team_color]))
		if owned_outfits.has(outfit_name):
			row.add_child(_hub_text("OWNED" if equipped_outfit != outfit_name else "EQUIPPED ✓"))
		else:
			row.add_child(_hub_button("BUY %d GP" % price, func():
				if match_coins < price:
					lobby_status.text = "Not enough GP. Complete tasks to earn more."
					return
				match_coins -= price
				owned_outfits.append(outfit_name)
				_save_progress()
				_show_hub_tab("STORE")
			))
		hub_content.add_child(row)


func _build_vault_panel() -> void:
	hub_content.add_child(_hub_heading("VAULT • YOUR COLLECTION"))
	hub_content.add_child(_hub_text("Your free Striker and Academy Blue kit are unlocked from the start."))
	hub_content.add_child(_hub_heading("CHARACTERS"))
	for character_name in owned_characters:
		hub_content.add_child(_hub_button(("✓ " if selected_character == character_name else "EQUIP ") + character_name, func():
			selected_character = character_name
			_save_progress()
			_show_hub_tab("VAULT")
		))
	hub_content.add_child(_hub_heading("OUTFITS"))
	for outfit_name in owned_outfits:
		hub_content.add_child(_hub_button(("✓ EQUIPPED • " if equipped_outfit == outfit_name else "EQUIP • ") + outfit_name, func():
			equipped_outfit = outfit_name
			match outfit_name:
				"Neon Surge": selected_team_color = "Neon Green"
				"Royal Eclipse": selected_team_color = "Royal Purple"
				"Crimson Phantom": selected_team_color = "Crimson Red"
				_: selected_team_color = "Electric Blue"
			_save_progress()
			_show_hub_tab("VAULT")
		))
	hub_content.add_child(_hub_button("VISIT STORE", func(): _show_hub_tab("STORE")))


func _start_tutorial(force_replay: bool = false) -> void:
	if tutorial_completed and not force_replay:
		return
	if is_instance_valid(tutorial_layer):
		tutorial_layer.queue_free()
	tutorial_index = 0
	tutorial_layer = CanvasLayer.new()
	tutorial_layer.layer = 40
	add_child(tutorial_layer)
	var shade := ColorRect.new()
	shade.anchor_right = 1.0
	shade.anchor_bottom = 1.0
	shade.color = Color(0.008, 0.012, 0.035, 0.94)
	tutorial_layer.add_child(shade)
	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.offset_left = 20
	center.offset_right = -20
	tutorial_layer.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(300, 330)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(card)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	card.add_child(stack)
	var heading := _hub_heading("2-MINUTE TRAINING")
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(heading)
	tutorial_step_label = _hub_text("")
	tutorial_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(tutorial_step_label)
	tutorial_body_label = _hub_text("")
	tutorial_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_body_label.custom_minimum_size.y = 100
	stack.add_child(tutorial_body_label)
	stack.add_child(_hub_text("Spend about 20 seconds per lesson. Replay any time in Settings."))
	stack.add_child(_hub_button("NEXT LESSON  ▶", func():
		tutorial_index += 1
		if tutorial_index >= 6:
			tutorial_completed = true
			_save_progress()
			if is_instance_valid(tutorial_layer):
				tutorial_layer.queue_free()
			tutorial_layer = null
			if is_instance_valid(lobby_layer):
				lobby_layer.visible = true
				lobby_status.text = "Training complete. You're ready to play!"
			return
		_update_tutorial_page()
	))
	stack.add_child(_hub_button("SKIP TUTORIAL", func():
		if is_instance_valid(tutorial_layer):
			tutorial_layer.queue_free()
		tutorial_layer = null
		if is_instance_valid(lobby_layer):
			lobby_layer.visible = true
	))
	lobby_layer.visible = false
	_update_tutorial_page()


func _update_tutorial_page() -> void:
	var lessons := [
		["1 / 6 • MOVEMENT", "Use the LEFT joystick to run in any direction."],
		["2 / 6 • POSITIONING", "Move close to the ball and face the goal before shooting."],
		["3 / 6 • SHOOT", "Tap SHOOT on the right to kick toward goal."],
		["4 / 6 • PASS", "Tap PASS to send the ball to a teammate. Use CALL PASS to ask for a passing option."],
		["5 / 6 • SPECIAL MOVES", "LOB sends an aerial ball, FINESSE is a controlled shot, TACKLE challenges for possession, and BURST speeds you up."],
		["6 / 6 • WIN THE MATCH", "Watch the score and timer at the top. Pass, move into space and outscore the AI to earn GP."]
	]
	if is_instance_valid(tutorial_step_label) and is_instance_valid(tutorial_body_label):
		tutorial_step_label.text = lessons[tutorial_index][0]
		tutorial_body_label.text = lessons[tutorial_index][1]


func _build_tasks_panel() -> void:
	hub_content.add_child(_hub_heading("FIELD ORDERS • CHALLENGES"))
	hub_content.add_child(_hub_text("Complete objectives in your matches and claim GP rewards. Progress saves on this device; tasks do not reset daily yet."))
	_add_task_card("FIRST STRIKE", "Score 3 goals", goals_total, 3, 100, "goals")
	_add_task_card("TEAM ENGINE", "Attempt 5 passes", passes_total, 5, 80, "passes")
	_add_task_card("PHANTOM FOOTWORK", "Use burst 3 times", burst_uses_total, 3, 80, "bursts")
	_add_task_card("WINNER'S MINDSET", "Win 1 match", wins_total, 1, 150, "wins")
	hub_content.add_child(_hub_text("Rewards are local prototype coins. Server-verified online rewards are not connected yet."))


func _add_task_card(task_name: String, description: String, progress_value: int, target: int, reward: int, task_id: String) -> void:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.055, 0.12, 0.98)
	style.border_color = Color(0.12, 0.42, 0.68, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", style)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	card.add_child(body)
	var top := HBoxContainer.new()
	body.add_child(top)
	var title := _hub_heading(task_name)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var reward_label := _hub_text("+%d GP" % reward)
	reward_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.28))
	top.add_child(reward_label)
	body.add_child(_hub_text(description))
	var bar := ProgressBar.new()
	bar.max_value = target
	bar.value = mini(progress_value, target)
	bar.show_percentage = false
	bar.custom_minimum_size.y = 12
	body.add_child(bar)
	var footer := HBoxContainer.new()
	body.add_child(footer)
	var status := _hub_text("%d / %d" % [mini(progress_value, target), target])
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(status)
	if bool(tasks_claimed.get(task_id, false)):
		footer.add_child(_hub_text("CLAIMED ✓"))
	elif progress_value >= target:
		footer.add_child(_hub_button("CLAIM REWARD", func():
			if bool(tasks_claimed.get(task_id, false)):
				return
			tasks_claimed[task_id] = true
			match_coins += reward
			_save_progress()
			_show_hub_tab("TASKS")
			lobby_status.text = "Task complete: %s • +%d GP" % [task_name, reward]
		))
	else:
		footer.add_child(_hub_text("IN PROGRESS"))
	hub_content.add_child(card)


func _add_existing_loadout_controls() -> void:
	hub_content.add_child(_lobby_label("PLAYER CLASS"))
	character_picker = OptionButton.new()
	for item in ["Striker", "Playmaker", "Defender", "Eclipse Ace"]:
		if owned_characters.has(item):
			character_picker.add_item(item)
	var selected_index := 0
	for option_index in range(character_picker.item_count):
		if character_picker.get_item_text(option_index) == selected_character:
			selected_index = option_index
			break
	character_picker.select(selected_index)
	hub_content.add_child(character_picker)
	hub_content.add_child(_lobby_label("SPECIAL ABILITY"))
	ability_picker = OptionButton.new()
	for item in ["Speed Burst", "Power Shot", "Precision Pass"]:
		ability_picker.add_item(item)
	hub_content.add_child(ability_picker)
	hub_content.add_child(_lobby_label("TEAM KIT"))
	color_picker = OptionButton.new()
	for item in ["Electric Blue", "Neon Green", "Royal Purple", "Crimson Red"]:
		color_picker.add_item(item)
	color_picker.select(maxi(0, ["Electric Blue", "Neon Green", "Royal Purple", "Crimson Red"].find(selected_team_color)))
	hub_content.add_child(color_picker)
	hub_content.add_child(_hub_button("▶ PLAY OFFLINE 4v4", _start_match))


func _lobby_label(value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.45, 0.75, 0.95))
	return label


func _request_ranked_match() -> void:
	# Ranked requires an online authoritative service; do not fake matchmaking locally.
	lobby_status.text = "RANKED NEEDS INTERNET AND A LIVE RANKED SERVER. The server is not deployed yet. Quick Match and Career work fully offline."


func _start_match() -> void:
	is_paused = false
	if pause_button:
		pause_button.text = "PAUSE"
	if is_instance_valid(character_picker):
		var chosen_character := character_picker.get_item_text(character_picker.selected)
		if owned_characters.has(chosen_character):
			selected_character = chosen_character
	if is_instance_valid(ability_picker):
		selected_ability = ability_picker.get_item_text(ability_picker.selected)
	if is_instance_valid(color_picker):
		selected_team_color = color_picker.get_item_text(color_picker.selected)
	var tint := Color(0.08, 0.36, 0.95)
	match selected_team_color:
		"Neon Green": tint = Color(0.12, 0.92, 0.42)
		"Royal Purple": tint = Color(0.52, 0.2, 0.92)
		"Crimson Red": tint = Color(0.92, 0.08, 0.2)
		_: tint = Color(0.08, 0.36, 0.95)
	if player_visual:
		player_visual.material_override = _material(tint, 0.45)
		player_visual.scale = Vector3(1.0, 1.0, 1.0)
		if selected_character == "Playmaker":
			player_visual.scale = Vector3(0.92, 1.06, 0.92)
		elif selected_character == "Defender":
			player_visual.scale = Vector3(1.10, 1.0, 1.10)
	match selected_character:
		"Playmaker": ui_hint.text = "PLAYMAKER • PRECISION AND TEAMWORK"
		"Defender": ui_hint.text = "DEFENDER • HOLD YOUR LINE"
		"Eclipse Ace": ui_hint.text = "ECLIPSE ACE • ULTIMATE: ECLIPSE BREAKER"
		_: ui_hint.text = "STRIKER • GO FOR GOALS"
	match_active = true
	jockey_mode = false
	if is_instance_valid(jockey_button):
		jockey_button.text = "JOCKEY"
		jockey_button.modulate = Color.WHITE
	time_left = MATCH_SECONDS
	score_home = 0
	score_away = 0
	burst_time = 0.0
	burst_cooldown = 0.0
	ultimate_cooldown = 0.0
	_reset_kickoff("KICK OFF! • " + selected_ability.to_upper())
	lobby_layer.visible = false
	_update_hud()


func _return_to_lobby() -> void:
	is_paused = false
	match_active = false
	joystick_vector = Vector2.ZERO
	lobby_layer.visible = true
	lobby_status.text = "Choose your loadout and kick off."
	var stats := lobby_layer.find_child("ProgressStats", true, false) as Label
	if stats:
		stats.text = "LEVEL %d   •   WINS %d   •   GOALS %d" % [player_level, wins_total, goals_total]


func _show_online_room_status() -> void:
	_show_hub_tab("ONLINE")


func _build_online_panel() -> void:
	hub_content.add_child(_hub_heading("ONLINE ROOM • DIRECT IP"))
	hub_content.add_child(_hub_text("Offline Quick Match and Career work without internet. Ranked is online-only but needs a live ranked server, which is not deployed yet. Create or join a friend's room for direct-IP multiplayer."))
	hub_content.add_child(_hub_text("Room capacity: host + up to 3 peers. Player requests are available only between players already connected to the same room. Public matchmaking and global friends are not live yet."))
	hub_content.add_child(_hub_heading("HOST ADDRESS"))
	online_address_input = LineEdit.new()
	online_address_input.placeholder_text = "Host IP address (e.g. 192.168.1.20)"
	online_address_input.text = "127.0.0.1"
	online_address_input.custom_minimum_size.y = 42
	hub_content.add_child(online_address_input)
	hub_content.add_child(_hub_heading("PORT"))
	online_port_input = SpinBox.new()
	online_port_input.min_value = 1024
	online_port_input.max_value = 65535
	online_port_input.step = 1
	online_port_input.value = 2456
	online_port_input.custom_minimum_size.y = 42
	hub_content.add_child(online_port_input)
	hub_content.add_child(_hub_button("CREATE ROOM", _host_online_room))
	hub_content.add_child(_hub_button("JOIN ROOM", _join_online_room))
	hub_content.add_child(_hub_button("DISCONNECT", _disconnect_online_room))
	network_status_label = _hub_text("Connection: " + network_status)
	hub_content.add_child(network_status_label)
	hub_content.add_child(_hub_heading("PLAYER REQUESTS"))
	hub_content.add_child(_hub_text("Send a request by the player's UID or room peer ID. They can accept or reject it. Both players must be in the same connected room."))
	friend_target_input = LineEdit.new()
	friend_target_input.placeholder_text = "Player UID or peer ID"
	friend_target_input.custom_minimum_size.y = 42
	hub_content.add_child(friend_target_input)
	hub_content.add_child(_hub_button("SEND PLAYER REQUEST", _send_friend_request))
	friend_request_status_label = _hub_text("No pending player request.")
	hub_content.add_child(friend_request_status_label)
	var response_row := HBoxContainer.new()
	response_row.add_child(_hub_button("ACCEPT", func(): _respond_to_friend_request(true)))
	response_row.add_child(_hub_button("REJECT", func(): _respond_to_friend_request(false)))
	hub_content.add_child(response_row)
	hub_content.add_child(_hub_text("The host must be reachable over the network; mobile networks may need a relay or port forwarding. 127.0.0.1 means this device only."))


func _send_friend_request() -> void:
	if multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		_set_friend_request_status("Join or create a room before sending a request.")
		return
	var target_text := friend_target_input.text.strip_edges() if is_instance_valid(friend_target_input) else ""
	var target_id := -1
	if target_text.is_valid_int():
		target_id = int(target_text)
	else:
		for peer_key in player_profiles.keys():
			var profile: Dictionary = player_profiles[peer_key]
			if str(profile.get("uid", "")).to_upper() == target_text.to_upper():
				target_id = int(peer_key)
				break
	if target_id < 0:
		_set_friend_request_status("Enter a connected player's UID or peer ID.")
		return
	if target_id <= 0 or target_id == multiplayer.get_unique_id():
		_set_friend_request_status("Choose another connected player's peer ID.")
		return
	if multiplayer.is_server():
		if not multiplayer.get_peers().has(target_id):
			_set_friend_request_status("That peer is not connected to this room.")
			return
		rpc_id(target_id, "_rpc_receive_friend_request", 1, "Room host")
	else:
		rpc_id(1, "_rpc_route_friend_request", target_id)
	_set_friend_request_status("Request sent to player %d." % target_id)


func _respond_to_friend_request(accepted: bool) -> void:
	if pending_friend_request_from < 0:
		_set_friend_request_status("There is no request to answer.")
		return
	var requester_id := pending_friend_request_from
	pending_friend_request_from = -1
	if multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		if multiplayer.is_server():
			if requester_id > 1:
				rpc_id(requester_id, "_rpc_friend_request_result", 1, accepted)
		else:
			rpc_id(1, "_rpc_route_friend_request_response", requester_id, accepted)
	_set_friend_request_status("Request accepted." if accepted else "Request rejected.")


func _set_friend_request_status(message: String) -> void:
	if is_instance_valid(friend_request_status_label):
		friend_request_status_label.text = message
	if is_instance_valid(lobby_status):
		lobby_status.text = message


@rpc("any_peer", "call_remote", "reliable")
func _rpc_route_friend_request(target_id: int) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id <= 1 or target_id <= 1 or sender_id == target_id or not multiplayer.get_peers().has(target_id):
		if sender_id > 1:
			rpc_id(sender_id, "_rpc_friend_request_result", target_id, false)
		return
	rpc_id(target_id, "_rpc_receive_friend_request", sender_id, "Player %d" % sender_id)


@rpc("authority", "call_remote", "reliable")
func _rpc_receive_friend_request(sender_id: int, sender_name: String) -> void:
	pending_friend_request_from = sender_id
	_set_friend_request_status("REQUEST FROM %s • tap ACCEPT or REJECT" % sender_name)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_route_friend_request_response(requester_id: int, accepted: bool) -> void:
	if not multiplayer.is_server():
		return
	var responder_id := multiplayer.get_remote_sender_id()
	if responder_id <= 1 or requester_id <= 0:
		return
	if requester_id == 1:
		_set_friend_request_status("Player %d %s your request." % [responder_id, "accepted" if accepted else "rejected"])
	elif multiplayer.get_peers().has(requester_id):
		rpc_id(requester_id, "_rpc_friend_request_result", responder_id, accepted)


@rpc("authority", "call_remote", "reliable")
func _rpc_friend_request_result(responder_id: int, accepted: bool) -> void:
	_set_friend_request_status("Player %d accepted your request!" % responder_id if accepted else "Player %d rejected your request." % responder_id)


func _host_online_room() -> void:
	var port := int(online_port_input.value) if is_instance_valid(online_port_input) else 2456
	_disconnect_online_room()
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_server(port, 3)
	if result != OK:
		network_status = "Host failed: " + error_string(result)
		_set_network_status(network_status)
		return
	network_peer = peer
	multiplayer.multiplayer_peer = network_peer
	if not multiplayer.peer_connected.is_connected(_on_network_peer_connected):
		multiplayer.peer_connected.connect(_on_network_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_network_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_network_peer_disconnected)
	network_status = "Hosting on UDP port %d • waiting for peers" % port
	network_match_enabled = true
	player_profiles.clear()
	player_profiles[1] = {"uid": player_uid, "name": player_display_name}
	_set_network_status(network_status)


func _join_online_room() -> void:
	var address := online_address_input.text.strip_edges() if is_instance_valid(online_address_input) else ""
	var port := int(online_port_input.value) if is_instance_valid(online_port_input) else 2456
	if address.is_empty():
		_set_network_status("Enter the host IP address first.")
		return
	_disconnect_online_room()
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_client(address, port)
	if result != OK:
		network_status = "Join failed: " + error_string(result)
		_set_network_status(network_status)
		return
	network_peer = peer
	multiplayer.multiplayer_peer = network_peer
	if not multiplayer.connected_to_server.is_connected(_on_network_connected):
		multiplayer.connected_to_server.connect(_on_network_connected)
	if not multiplayer.connection_failed.is_connected(_on_network_connection_failed):
		multiplayer.connection_failed.connect(_on_network_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_network_server_disconnected):
		multiplayer.server_disconnected.connect(_on_network_server_disconnected)
	network_status = "Connecting to %s:%d…" % [address, port]
	network_match_enabled = true
	_set_network_status(network_status)


func _disconnect_online_room() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	network_peer = null
	network_match_enabled = false
	network_send_accumulator = 0.0
	for peer_id in remote_players.keys():
		var avatar = remote_players[peer_id]
		if is_instance_valid(avatar):
			avatar.queue_free()
	remote_players.clear()
	network_player_states.clear()
	player_profiles.clear()
	network_status = "Offline"
	_set_network_status(network_status)


func _on_network_connected() -> void:
	network_status = "Connected to host • starting match"
	_set_network_status(network_status)
	rpc_id(1, "_rpc_register_profile", player_uid, player_display_name)
	if not match_active:
		_start_match()


func _on_network_connection_failed() -> void:
	network_status = "Connection failed • check IP, port and firewall"
	_set_network_status(network_status)


func _on_network_server_disconnected() -> void:
	_disconnect_online_room()
	_set_network_status("Host disconnected.")


func _on_network_peer_connected(peer_id: int) -> void:
	network_status = "Peer %d connected • %d peer(s) online" % [peer_id, remote_players.size() + 1]
	_set_network_status(network_status)
	if not match_active:
		_start_match()


func _on_network_peer_disconnected(peer_id: int) -> void:
	if remote_players.has(peer_id):
		var avatar = remote_players[peer_id]
		if is_instance_valid(avatar):
			avatar.queue_free()
		remote_players.erase(peer_id)
	network_player_states.erase(peer_id)
	network_status = "Peer %d left • %d peer(s) online" % [peer_id, remote_players.size()]
	_set_network_status(network_status)


func _set_network_status(message: String) -> void:
	network_status = message
	if is_instance_valid(network_status_label):
		network_status_label.text = "Connection: " + message
	if is_instance_valid(lobby_status):
		lobby_status.text = message


func _update_network_session(delta: float) -> void:
	if not network_match_enabled or multiplayer.multiplayer_peer == null:
		return
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	network_send_accumulator += delta
	if network_send_accumulator < 0.05:
		return
	network_send_accumulator = 0.0
	var my_id := multiplayer.get_unique_id()
	var player_pos := player.global_position if is_instance_valid(player) else Vector3.ZERO
	var player_rot := player.rotation.y if is_instance_valid(player) else 0.0
	var ball_pos := ball.global_position if is_instance_valid(ball) else Vector3.ZERO
	var ball_vel := ball.linear_velocity if is_instance_valid(ball) else Vector3.ZERO
	if multiplayer.is_server():
		network_player_states[my_id] = {"position": player_pos, "rotation": player_rot}
		for peer_id in network_player_states.keys():
			var state: Dictionary = network_player_states[peer_id]
			rpc("_rpc_receive_state", int(peer_id), state["position"], float(state["rotation"]), ball_pos, ball_vel, score_home, score_away, time_left)
	else:
		rpc_id(1, "_rpc_submit_state", player_pos, player_rot)


@rpc("any_peer", "call_remote", "unreliable")
func _rpc_submit_state(position: Vector3, rotation_y: float) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id <= 1 or not is_instance_valid(player):
		return
	if absf(position.x) > FIELD_LENGTH / 2.0 + 2.0 or absf(position.z) > FIELD_WIDTH / 2.0 + 2.0:
		return
	network_player_states[sender_id] = {"position": position, "rotation": rotation_y}
	if not remote_players.has(sender_id) or not is_instance_valid(remote_players[sender_id]):
		var avatar := _make_player(sender_id % 2 == 0, position)
		avatar.name = "RemotePeer_%d" % sender_id
		remote_players[sender_id] = avatar
	var remote_avatar: CharacterBody3D = remote_players[sender_id]
	remote_avatar.global_position = remote_avatar.global_position.lerp(position, 0.65)
	remote_avatar.rotation.y = rotation_y


@rpc("authority", "call_remote", "unreliable")
func _rpc_receive_state(peer_id: int, position: Vector3, rotation_y: float, ball_position: Vector3, ball_velocity: Vector3, home_score: int, away_score: int, match_clock: float) -> void:
	if peer_id != multiplayer.get_unique_id():
		if not remote_players.has(peer_id) or not is_instance_valid(remote_players[peer_id]):
			var avatar := _make_player(peer_id % 2 == 0, position)
			avatar.name = "RemotePeer_%d" % peer_id
			remote_players[peer_id] = avatar
		var remote_avatar: CharacterBody3D = remote_players[peer_id]
		remote_avatar.global_position = remote_avatar.global_position.lerp(position, 0.55)
		remote_avatar.rotation.y = rotation_y
	if not multiplayer.is_server():
		ball.global_position = ball_position
		ball.linear_velocity = ball_velocity.limit_length(35.0)
		score_home = home_score
		score_away = away_score
		time_left = clampf(match_clock, 0.0, MATCH_SECONDS)
		_update_hud()



func _send_online_ball_action(action: String, direction: Vector3) -> bool:
	if not network_match_enabled or multiplayer.multiplayer_peer == null:
		return false
	if multiplayer.is_server():
		return false
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return false
	rpc_id(1, "_rpc_request_ball_action", action, direction.normalized())
	return true


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_ball_action(action: String, direction: Vector3) -> void:
	if not multiplayer.is_server() or not is_instance_valid(ball):
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if not remote_players.has(sender_id) or not is_instance_valid(remote_players[sender_id]):
		return
	var remote_avatar: CharacterBody3D = remote_players[sender_id]
	if remote_avatar.global_position.distance_to(ball.global_position) > 2.8:
		return
	var dir := direction.normalized()
	if dir.length_squared() < 0.5:
		return
	match action:
		"shoot":
			ball.apply_central_impulse(dir * 13.0)
		"finesse":
			ball.apply_central_impulse(dir * 10.5)
			ball_spin = clampf(-remote_avatar.global_position.z * 0.12, -1.8, 1.8)
		"pass":
			ball.apply_central_impulse(dir * 7.5)
		"lob":
			dir.y = maxf(dir.y, 0.34)
			ball.apply_central_impulse(dir.normalized() * 9.2)
		"tackle":
			ball.apply_central_impulse((remote_avatar.global_position.direction_to(ball.global_position) * 5.5) + Vector3(0, 0.3, 0))
		_:
			return


func _save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("account", "uid", player_uid)
	cfg.set_value("account", "display_name", player_display_name)
	cfg.set_value("account", "mode", account_mode)
	cfg.set_value("career", "wins", wins_total)
	cfg.set_value("career", "goals", goals_total)
	cfg.set_value("career", "level", player_level)
	cfg.set_value("wallet", "match_coins", match_coins)
	cfg.set_value("wallet", "premium_points", premium_points)
	cfg.set_value("rewards", "daily_bonus_claimed", daily_bonus_claimed)
	cfg.set_value("rewards", "goal_reward_claimed", goal_reward_claimed)
	cfg.set_value("cosmetics", "owned_characters", owned_characters)
	cfg.set_value("cosmetics", "owned_outfits", owned_outfits)
	cfg.set_value("cosmetics", "equipped_outfit", equipped_outfit)
	cfg.set_value("tutorial", "completed", tutorial_completed)
	cfg.set_value("settings", "sensitivity", settings_sensitivity)
	cfg.set_value("settings", "music_enabled", settings_music_enabled)
	cfg.save("user://football_progress.cfg")


func _load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://football_progress.cfg") == OK:
		player_uid = str(cfg.get_value("account", "uid", ""))
		player_display_name = str(cfg.get_value("account", "display_name", "Guest Player"))
		account_mode = str(cfg.get_value("account", "mode", "Guest"))
		wins_total = int(cfg.get_value("career", "wins", 0))
		goals_total = int(cfg.get_value("career", "goals", 0))
		player_level = int(cfg.get_value("career", "level", 1))
		match_coins = int(cfg.get_value("wallet", "match_coins", 0))
		premium_points = int(cfg.get_value("wallet", "premium_points", 0))
		daily_bonus_claimed = bool(cfg.get_value("rewards", "daily_bonus_claimed", false))
		goal_reward_claimed = bool(cfg.get_value("rewards", "goal_reward_claimed", false))
		owned_characters = cfg.get_value("cosmetics", "owned_characters", ["Striker"])
		owned_outfits = cfg.get_value("cosmetics", "owned_outfits", ["Academy Blue"])
		equipped_outfit = str(cfg.get_value("cosmetics", "equipped_outfit", "Academy Blue"))
		tutorial_completed = bool(cfg.get_value("tutorial", "completed", false))
		settings_sensitivity = float(cfg.get_value("settings", "sensitivity", 1.0))
		settings_music_enabled = bool(cfg.get_value("settings", "music_enabled", true))
	if not owned_characters.has("Striker"):
		owned_characters.append("Striker")
	if not owned_outfits.has("Academy Blue"):
		owned_outfits.append("Academy Blue")
	if player_uid.is_empty():
		_generate_player_uid()
		player_display_name = "Guest-" + player_uid.substr(maxi(0, player_uid.length() - 4))
		account_mode = "Guest"
		_save_progress()
	if player_display_name.is_empty():
		player_display_name = "Guest-" + player_uid.substr(maxi(0, player_uid.length() - 4))


func _generate_player_uid() -> void:
	# Locally generated, persistent ID. Global uniqueness requires a backend account service.
	var crypto := Crypto.new()
	var bytes := crypto.generate_random_bytes(12)
	player_uid = "ES-" + bytes.hex_encode().to_upper()


func _build_profile_panel() -> void:
	hub_content.add_child(_hub_heading("PLAYER PROFILE"))
	hub_content.add_child(_hub_text("Your profile is saved on this device. Guest play works offline; online accounts and global UID registration need a configured backend."))
	hub_content.add_child(_hub_heading("DISPLAY NAME"))
	var name_input := LineEdit.new()
	name_input.text = player_display_name
	name_input.placeholder_text = "Your player name"
	name_input.custom_minimum_size.y = 42
	hub_content.add_child(name_input)
	hub_content.add_child(_hub_heading("YOUR PLAYER UID"))
	profile_uid_label = _hub_text(player_uid)
	profile_uid_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hub_content.add_child(profile_uid_label)
	hub_content.add_child(_hub_button("COPY MY UID", func():
		DisplayServer.clipboard_set(player_uid)
		_set_profile_status("Your UID was copied.")
	))
	hub_content.add_child(_hub_button("SAVE GUEST PROFILE", func():
		var clean_name := name_input.text.strip_edges()
		if clean_name.is_empty():
			_set_profile_status("Enter a display name first.")
			return
		player_display_name = clean_name.left(20)
		account_mode = "Guest"
		_save_progress()
		_set_profile_status("Guest profile saved on this device.")
		if multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			if multiplayer.is_server():
				player_profiles[1] = {"uid": player_uid, "name": player_display_name}
				_broadcast_player_profiles()
			else:
				rpc_id(1, "_rpc_register_profile", player_uid, player_display_name)
		_show_hub_tab("PROFILE")
	))
	hub_content.add_child(_hub_button("SIGN IN WITH GOOGLE", _google_sign_in_unavailable))
	profile_status_label = _hub_text("Account mode: " + account_mode)
	hub_content.add_child(profile_status_label)
	hub_content.add_child(_hub_heading("PLAYERS IN THIS ROOM"))
	if multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		var found_any := false
		for peer_key in player_profiles.keys():
			var entry: Dictionary = player_profiles[peer_key]
			var remote_uid := str(entry.get("uid", ""))
			if int(peer_key) == multiplayer.get_unique_id() or remote_uid.is_empty():
				continue
			found_any = true
			var peer_row := HBoxContainer.new()
			peer_row.add_child(_hub_text("%s • %s" % [str(entry.get("name", "Player")), remote_uid]))
			var copy_peer_uid := _hub_button("COPY UID", _copy_remote_uid.bind(remote_uid))
			peer_row.add_child(copy_peer_uid)
			hub_content.add_child(peer_row)
		if not found_any:
			hub_content.add_child(_hub_text("No other player profiles received yet. Players must join this room and register their guest profile."))
	else:
		hub_content.add_child(_hub_text("Join the same online room as another player to see their UID here."))
	hub_content.add_child(_hub_text("UIDs are currently local-profile IDs, not server-verified accounts. Use the ONLINE tab for requests to players in the same room."))


func _copy_remote_uid(uid_to_copy: String) -> void:
	DisplayServer.clipboard_set(uid_to_copy)
	_set_profile_status("Player UID copied.")


func _set_profile_status(message: String) -> void:
	if is_instance_valid(profile_status_label):
		profile_status_label.text = message
	if is_instance_valid(lobby_status):
		lobby_status.text = message


func _google_sign_in_unavailable() -> void:
	_set_profile_status("Google sign-in is not active yet: configure Google OAuth and a verified auth backend before enabling it.")


func _broadcast_player_profiles() -> void:
	if not multiplayer.is_server():
		return
	rpc("_rpc_player_profiles_updated", player_profiles)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_register_profile(uid: String, display_name: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id <= 1 or uid.length() < 8 or uid.length() > 40:
		return
	player_profiles[sender_id] = {"uid": uid, "name": display_name.left(20)}
	_broadcast_player_profiles()


@rpc("authority", "call_remote", "reliable")
func _rpc_player_profiles_updated(profiles: Dictionary) -> void:
	player_profiles = profiles.duplicate(true)


func _spawn_skill_burst(at: Vector3, tint: Color) -> void:
	# Lightweight procedural anime impact ring: no external art assets required.
	var fx := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.42
	ring.outer_radius = 0.58
	fx.mesh = ring
	fx.global_position = at
	fx.scale = Vector3.ONE * 0.22
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(tint.r, tint.g, tint.b, 0.82)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = tint
	mat.emission_energy_multiplier = 1.8
	fx.material_override = mat
	add_child(fx)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(fx, "scale", Vector3.ONE * 2.8, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color", Color(tint.r, tint.g, tint.b, 0.0), 0.42)
	tween.tween_property(fx, "position:y", at.y + 0.65, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(fx.queue_free)


func _update_aim_guide() -> void:
	if not is_instance_valid(aim_line) or not is_instance_valid(ball) or not is_instance_valid(player):
		return
	var show_guide := match_active and _near_ball()
	aim_line.visible = show_guide
	if not show_guide:
		return
	var mesh := aim_line.mesh as ImmediateMesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var origin := ball.global_position + Vector3(0, 0.12, 0)
	var target_z := clampf(-player.global_position.z * 0.45, -2.35, 2.35)
	var target := Vector3(FIELD_LENGTH / 2.0 + 2.0, 1.0, target_z)
	var dir := (target - origin).normalized()
	var power := 13.0 if selected_ability != "Power Shot" else 18.0
	var velocity := dir * power * 0.72
	var point := origin
	mesh.surface_add_vertex(to_local(point))
	for i in range(1, 22):
		var t := float(i) * 0.11
		point = origin + velocity * t + Vector3(0, -4.9 * t * t, 0)
		mesh.surface_add_vertex(to_local(point))
	mesh.surface_end()

func _show_goal_celebration(message: String) -> void:
	if not is_instance_valid(goal_banner):
		return
	if goal_banner_tween and goal_banner_tween.is_running():
		goal_banner_tween.kill()
	var home_goal := message.contains("BLUE")
	goal_banner.text = "GOAL!!" if home_goal else "THEY SCORED!"
	if home_goal:
		goal_banner.text += "\nTHAT'S THE STRIKER'S INSTINCT!"
	else:
		goal_banner.text += "\nRESET. WE'RE NOT DONE YET."
	goal_banner.scale = Vector2(0.55, 0.55)
	goal_banner.modulate.a = 1.0
	goal_animation_busy = true
	goal_banner_tween = create_tween()
	goal_banner_tween.set_parallel(true)
	goal_banner_tween.tween_property(goal_banner, "scale", Vector2(1.0, 1.0), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	goal_banner_tween.tween_property(goal_banner, "modulate:a", 0.0, 2.4).set_delay(1.5)
	goal_banner_tween.chain().tween_callback(func(): goal_animation_busy = false)

func _play_sfx(kind: String) -> void:
	if not sound_enabled or not is_instance_valid(sfx_player):
		return
	var rate := 22050
	var duration := 0.24
	var base_freq := 180.0
	match kind:
		"goal":
			duration = 0.9
			base_freq = 440.0
		"kick":
			duration = 0.13
			base_freq = 115.0
		"pass":
			duration = 0.16
			base_freq = 260.0
		"burst":
			duration = 0.28
			base_freq = 620.0
		"ultimate":
			duration = 1.05
			base_freq = 330.0
	var count := int(rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in range(count):
		var t := float(i) / rate
		var envelope := 1.0 - float(i) / count
		var freq := base_freq
		if kind == "goal" or kind == "ultimate":
			freq = base_freq * (1.0 + 0.35 * sin(t * 9.0))
		elif kind == "kick":
			freq = base_freq * (1.0 - 0.55 * t / duration)
		elif kind == "burst":
			freq = base_freq * (0.7 + 1.1 * t / duration)
		elif kind == "ultimate":
			freq = base_freq * (0.8 + 1.4 * t / duration)
		var wave := sin(TAU * freq * t) * envelope
		if kind == "kick":
			wave = (wave * 0.65 + sin(TAU * 55.0 * t) * envelope * 0.35)
		elif kind == "goal" or kind == "ultimate":
			wave = (wave * 0.7 + sin(TAU * base_freq * 1.5 * t) * envelope * 0.3)
		var sample := int(clampf(wave * 12500.0, -32767.0, 32767.0))
		bytes.encode_s16(i * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = bytes
	sfx_player.stream = stream
	sfx_player.play()
