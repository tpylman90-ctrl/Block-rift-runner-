extends Node3D

enum ScreenState { HANGAR, SHOP, RUN, GAME_OVER }

const PROFILE_PATH := "user://pilot_profile.cfg"
const PARTS := {
	"wing_pack": {"title": "WING BLOCKS", "cost": 55, "hint": "HANDLING"},
	"twin_cannon": {"title": "TWIN CANNONS", "cost": 85, "hint": "FASTER FIRE"},
	"armor": {"title": "ARMOR PLATE", "cost": 100, "hint": "ONE HIT BUFFER"},
	"boost_core": {"title": "BOOST CORE", "cost": 125, "hint": "LONGER BOOST"},
}

var state: ScreenState = ScreenState.HANGAR
var rng := RandomNumberGenerator.new()
var player: CharacterBody3D
var camera: Camera3D
var course_root: Node3D
var ui_root: Control
var menu_panel: CenterContainer
var shop_panel: CenterContainer
var game_over_panel: CenterContainer
var hud: Control
var title_label: Label
var subtitle_label: Label
var lives_label: Label
var score_label: Label
var scrap_label: Label
var difficulty_label: Label
var steering_hint: Label
var fire_button: Button
var boost_button: Button
var shop_status: Label
var shop_buttons: Dictionary = {}

var total_scrap := 0
var run_scrap := 0
var run_score := 0
var high_score := 0
var runs_started := 0
var owned_parts: Array[String] = ["core"]
var equipped_parts: Array[String] = ["core"]
var lives := 3
var distance := 0.0
var run_speed := 27.0
var segment_number := 0
var next_segment_distance := 45.0
var steering_target := Vector2.ZERO
var steering_rate := 9.0
var invulnerability := 0.0
var armor_charge := 0
var firing := false
var fire_cooldown := 0.0
var boost_time := 0.0
var boost_cooldown := 0.0
var boost_duration := 1.15
var boost_speed := 0.0
var secret_life_segment := -1
var secret_life_claimed := false
var course_objects: Array[Node3D] = []
var projectiles: Array[Area3D] = []
var stars: MultiMeshInstance3D
var starfield_offset := 0.0


func _ready() -> void:
	rng.randomize()
	_load_profile()
	_build_world()
	_build_ship()
	_build_ui()
	_show_hangar()
	get_viewport().size_changed.connect(_layout_ui)


func _build_world() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.006, 0.012, 0.035)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.23, 0.31, 0.56)
	environment.ambient_light_energy = 0.65
	world_environment.environment = environment
	add_child(world_environment)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-28.0, -25.0, 0.0)
	key_light.light_color = Color(0.69, 0.82, 1.0)
	key_light.light_energy = 1.3
	add_child(key_light)

	camera = Camera3D.new()
	camera.current = true
	camera.fov = 73.0
	add_child(camera)

	course_root = Node3D.new()
	course_root.name = "GeneratedCourse"
	add_child(course_root)
	_build_starfield()


func _build_starfield() -> void:
	var cube := BoxMesh.new()
	cube.size = Vector3(0.11, 0.11, 0.11)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	cube.material = material
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = cube
	multi.instance_count = 260
	for i in range(multi.instance_count):
		var x := rng.randf_range(-100.0, 100.0)
		var y := rng.randf_range(-65.0, 65.0)
		var z := rng.randf_range(-190.0, 40.0)
		var scale_value := rng.randf_range(0.35, 1.25)
		multi.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * scale_value), Vector3(x, y, z)))
		var tint := Color(0.40, 0.61, 1.0).lerp(Color(1.0, 0.58, 0.35), rng.randf())
		multi.set_instance_color(i, tint)
	stars = MultiMeshInstance3D.new()
	stars.multimesh = multi
	add_child(stars)


func _build_ship() -> void:
	player = CharacterBody3D.new()
	player.name = "PlayerShip"
	player.position = Vector3(0.0, 0.0, 0.0)
	player.collision_layer = 1
	player.collision_mask = 0
	var body_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(2.3, 1.35, 3.3)
	body_shape.shape = box_shape
	player.add_child(body_shape)
	add_child(player)
	_rebuild_ship_mesh()


func _rebuild_ship_mesh() -> void:
	for child in player.get_children():
		if child is MeshInstance3D:
			child.queue_free()
	var hull := _make_block(Vector3(0.0, 0.0, 0.25), Vector3(1.55, 0.8, 3.0), Color(0.78, 0.85, 0.93))
	player.add_child(hull)
	var nose := _make_block(Vector3(0.0, 0.04, -1.55), Vector3(1.08, 0.53, 1.0), Color(0.32, 0.83, 1.0))
	player.add_child(nose)
	var cockpit := _make_block(Vector3(0.0, 0.55, -0.25), Vector3(0.72, 0.42, 1.0), Color(0.11, 0.25, 0.48))
	player.add_child(cockpit)
	for side in [-1.0, 1.0]:
		var engine := _make_block(Vector3(side * 0.92, -0.08, 1.05), Vector3(0.48, 0.58, 1.45), Color(0.27, 0.38, 0.58))
		player.add_child(engine)
		var glow := _make_block(Vector3(side * 0.92, -0.08, 1.83), Vector3(0.28, 0.3, 0.15), Color(0.13, 0.78, 1.0), true)
		player.add_child(glow)
	if equipped_parts.has("wing_pack"):
		for side in [-1.0, 1.0]:
			player.add_child(_make_block(Vector3(side * 1.45, -0.04, 0.2), Vector3(1.35, 0.25, 1.25), Color(0.93, 0.39, 0.24)))
	if equipped_parts.has("twin_cannon"):
		for side in [-1.0, 1.0]:
			player.add_child(_make_block(Vector3(side * 0.56, -0.02, -1.8), Vector3(0.22, 0.24, 0.72), Color(1.0, 0.63, 0.25)))
	if equipped_parts.has("armor"):
		player.add_child(_make_block(Vector3(0.0, -0.4, -0.25), Vector3(1.2, 0.22, 1.5), Color(0.92, 0.38, 0.22)))
	if equipped_parts.has("boost_core"):
		player.add_child(_make_block(Vector3(0.0, -0.15, 1.65), Vector3(0.62, 0.45, 0.8), Color(0.42, 0.3, 0.96)))


func _make_block(at: Vector3, dimensions: Vector3, tint: Color, emissive := false) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	mesh_instance.mesh = mesh
	mesh_instance.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.72
	if emissive:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.emission_enabled = true
		material.emission = tint
		material.emission_energy_multiplier = 1.6
	mesh_instance.material_override = material
	return mesh_instance


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(ui_root)

	menu_panel = CenterContainer.new()
	menu_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(menu_panel)
	var menu_column := VBoxContainer.new()
	menu_column.custom_minimum_size = Vector2(560.0, 390.0)
	menu_column.add_theme_constant_override("separation", 18)
	menu_column.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_panel.add_child(menu_column)
	title_label = _label("BLOCK RIFT RUNNER", 52, Color(0.53, 0.88, 1.0))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_column.add_child(title_label)
	subtitle_label = _label("BUILD A SCRAP SHIP. SURVIVE THE RIFT.", 20, Color(0.77, 0.84, 0.96))
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_column.add_child(subtitle_label)
	var menu_spacer := Control.new()
	menu_spacer.custom_minimum_size.y = 14
	menu_column.add_child(menu_spacer)
	var launch := _button("LAUNCH RUN", 30)
	launch.pressed.connect(_start_run)
	menu_column.add_child(launch)
	var parts := _button("HANGAR / PARTS", 24)
	parts.pressed.connect(_show_shop)
	menu_column.add_child(parts)
	var help := _label("DRAG TO FLY  •  FIRE TO CLEAR DRONES  •  BOOST TO SURGE", 17, Color(0.57, 0.66, 0.82))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_column.add_child(help)

	shop_panel = CenterContainer.new()
	shop_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(shop_panel)
	var shop_column := VBoxContainer.new()
	shop_column.custom_minimum_size = Vector2(620.0, 650.0)
	shop_column.add_theme_constant_override("separation", 12)
	shop_column.alignment = BoxContainer.ALIGNMENT_CENTER
	shop_panel.add_child(shop_column)
	var shop_title := _label("SCRAP HANGAR", 42, Color(0.53, 0.88, 1.0))
	shop_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_column.add_child(shop_title)
	shop_status = _label("", 20, Color(1.0, 0.77, 0.35))
	shop_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_column.add_child(shop_status)
	for part_id in PARTS.keys():
		var part_button := _button("", 17)
		part_button.pressed.connect(_on_shop_part_pressed.bind(part_id))
		shop_column.add_child(part_button)
		shop_buttons[part_id] = part_button
	var shop_note := _label("UNLOCKS STAY YOURS. EQUIPPED BLOCKS ARE LOST WHEN A RUN ENDS.", 16, Color(0.62, 0.69, 0.83))
	shop_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_column.add_child(shop_note)
	var back := _button("BACK TO FLIGHT DECK", 22)
	back.pressed.connect(_show_hangar)
	shop_column.add_child(back)

	game_over_panel = CenterContainer.new()
	game_over_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(game_over_panel)
	var result_column := VBoxContainer.new()
	result_column.custom_minimum_size = Vector2(540.0, 360.0)
	result_column.alignment = BoxContainer.ALIGNMENT_CENTER
	result_column.add_theme_constant_override("separation", 15)
	game_over_panel.add_child(result_column)
	var end_title := _label("SHIP LOST IN THE RIFT", 42, Color(1.0, 0.54, 0.35))
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_column.add_child(end_title)
	var summary := _label("", 22, Color(0.82, 0.88, 0.98))
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.name = "RunSummary"
	game_over_panel.set_meta("summary", summary)
	result_column.add_child(summary)
	var return_button := _button("RETURN TO HANGAR", 24)
	return_button.pressed.connect(_show_hangar)
	result_column.add_child(return_button)

	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_PASS
	ui_root.add_child(hud)
	lives_label = _label("LIVES  3", 25, Color(1.0, 0.72, 0.42))
	hud.add_child(lives_label)
	score_label = _label("SCORE  0", 22, Color(0.72, 0.88, 1.0))
	hud.add_child(score_label)
	scrap_label = _label("SCRAP  0", 22, Color(0.5, 1.0, 0.75))
	hud.add_child(scrap_label)
	difficulty_label = _label("RIFT  1", 20, Color(0.82, 0.72, 1.0))
	hud.add_child(difficulty_label)
	steering_hint = _label("DRAG ANYWHERE ON LEFT SIDE TO STEER", 17, Color(0.75, 0.85, 1.0))
	steering_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(steering_hint)
	fire_button = _button("FIRE", 24)
	fire_button.button_down.connect(func(): firing = true)
	fire_button.button_up.connect(func(): firing = false)
	hud.add_child(fire_button)
	boost_button = _button("BOOST", 21)
	boost_button.button_down.connect(_activate_boost)
	hud.add_child(boost_button)
	_layout_ui()
	_show_hangar()


func _label(text_value: String, font_size: int, tint: Color) -> Label:
	var result := Label.new()
	result.text = text_value
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", tint)
	result.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.75))
	result.add_theme_constant_override("shadow_offset_x", 2)
	result.add_theme_constant_override("shadow_offset_y", 2)
	return result


func _button(text_value: String, font_size: int) -> Button:
	var result := Button.new()
	result.text = text_value
	result.custom_minimum_size = Vector2(420.0, 66.0)
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", Color(0.93, 0.97, 1.0))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.035, 0.09, 0.18, 0.94)
	normal.border_color = Color(0.16, 0.67, 0.9, 0.9)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.06, 0.19, 0.31, 0.98)
	result.add_theme_stylebox_override("normal", normal)
	result.add_theme_stylebox_override("hover", hover)
	result.add_theme_stylebox_override("pressed", hover)
	return result


func _layout_ui() -> void:
	if not is_instance_valid(ui_root):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var w := viewport_size.x
	var h := viewport_size.y
	var button_width := clampf(w * 0.23, 300.0, 480.0)
	for control in ui_root.find_children("*", "Button", true, false):
		control.custom_minimum_size.x = button_width
		control.custom_minimum_size.y = clampf(h * 0.085, 58.0, 92.0)
	if title_label:
		title_label.add_theme_font_size_override("font_size", int(clampf(h * 0.075, 38.0, 76.0)))
	if lives_label:
		lives_label.position = Vector2(w * 0.025, h * 0.03)
		lives_label.size = Vector2(w * 0.28, h * 0.06)
		score_label.position = Vector2(w * 0.025, h * 0.09)
		score_label.size = Vector2(w * 0.3, h * 0.055)
		scrap_label.position = Vector2(w * 0.025, h * 0.15)
		scrap_label.size = Vector2(w * 0.3, h * 0.055)
		difficulty_label.position = Vector2(w * 0.82, h * 0.03)
		difficulty_label.size = Vector2(w * 0.16, h * 0.055)
		var action_button_width := clampf(w * 0.14, 150.0, 230.0)
		fire_button.custom_minimum_size = Vector2.ZERO
		boost_button.custom_minimum_size = Vector2.ZERO
		fire_button.position = Vector2(w - action_button_width - 28.0, h * 0.7)
		fire_button.size = Vector2(action_button_width, h * 0.13)
		boost_button.position = Vector2(w - action_button_width - 28.0, h * 0.85)
		boost_button.size = Vector2(action_button_width, h * 0.11)
		steering_hint.position = Vector2(w * 0.18, h * 0.91)
		steering_hint.size = Vector2(w * 0.56, h * 0.05)


func _show_hangar() -> void:
	state = ScreenState.HANGAR
	menu_panel.visible = true
	shop_panel.visible = false
	game_over_panel.visible = false
	hud.visible = false
	firing = false
	if is_instance_valid(player):
		player.visible = true
		player.position = Vector3(0.0, -0.4, 0.0)
		player.rotation = Vector3.ZERO
		camera.position = Vector3(0.0, 3.7, 10.5)
		camera.look_at(Vector3(0.0, 0.0, -8.0), Vector3.UP)
	subtitle_label.text = "BANKED SCRAP %d   •   BEST FLIGHT %d" % [total_scrap, high_score]


func _show_shop() -> void:
	state = ScreenState.SHOP
	menu_panel.visible = false
	shop_panel.visible = true
	game_over_panel.visible = false
	hud.visible = false
	shop_status.text = "BANKED SCRAP: %d  |  BLOCKS: %d/4" % [total_scrap, equipped_parts.size()]
	_update_shop_buttons()


func _update_shop_buttons() -> void:
	for part_id in PARTS.keys():
		var item: Dictionary = PARTS[part_id]
		var owned := owned_parts.has(part_id)
		var equipped := equipped_parts.has(part_id)
		var button: Button = shop_buttons[part_id]
		if not owned:
			button.text = "%s  •  %d SCRAP  •  %s" % [item.title, item.cost, item.hint]
		elif equipped:
			button.text = "✓  %s  •  EQUIPPED" % item.title
		else:
			button.text = "+  %s  •  EQUIP  •  %s" % [item.title, item.hint]
		button.disabled = owned and not equipped and equipped_parts.size() >= 4
	shop_status.text = "BANKED SCRAP: %d  |  BLOCKS: %d/4" % [total_scrap, equipped_parts.size()]


func _on_shop_part_pressed(part_id: String) -> void:
	var item: Dictionary = PARTS[part_id]
	if not owned_parts.has(part_id):
		if total_scrap < int(item.cost):
			shop_status.text = "NEED %d MORE SCRAP" % (int(item.cost) - total_scrap)
			return
		total_scrap -= int(item.cost)
		owned_parts.append(part_id)
		equipped_parts.append(part_id)
		_save_profile()
	else:
		if equipped_parts.has(part_id):
			equipped_parts.erase(part_id)
		else:
			if equipped_parts.size() >= 4:
				shop_status.text = "MAX 4 BLOCKS PER SHIP"
				return
			equipped_parts.append(part_id)
		_save_profile()
	_rebuild_ship_mesh()
	_update_shop_buttons()


func _start_run() -> void:
	runs_started += 1
	rng.randomize()
	var rare_life_chance := 0.20
	secret_life_segment = rng.randi_range(3, 10) if rng.randf() < rare_life_chance else -1
	secret_life_claimed = false
	lives = 3
	distance = 0.0
	run_speed = 27.0
	segment_number = 0
	next_segment_distance = 45.0
	run_score = 0
	run_scrap = 0
	steering_target = Vector2.ZERO
	invulnerability = 0.0
	armor_charge = 1 if equipped_parts.has("armor") else 0
	firing = false
	fire_cooldown = 0.0
	boost_time = 0.0
	boost_cooldown = 0.0
	boost_duration = 1.8 if equipped_parts.has("boost_core") else 1.15
	boost_speed = 0.0
	for item in course_objects:
		if is_instance_valid(item):
			item.queue_free()
	course_objects.clear()
	for shot in projectiles:
		if is_instance_valid(shot):
			shot.queue_free()
	projectiles.clear()
	course_root.position = Vector3.ZERO
	player.position = Vector3.ZERO
	player.rotation = Vector3.ZERO
	player.visible = true
	_rebuild_ship_mesh()
	while next_segment_distance < 190.0:
		_spawn_segment(-next_segment_distance)
		next_segment_distance += rng.randf_range(48.0, 74.0)
	state = ScreenState.RUN
	menu_panel.visible = false
	shop_panel.visible = false
	game_over_panel.visible = false
	hud.visible = true
	_update_hud()


func _process(delta: float) -> void:
	if state != ScreenState.RUN:
		if is_instance_valid(player):
			camera.position = camera.position.lerp(player.position + Vector3(0.0, 3.7, 10.5), minf(delta * 3.0, 1.0))
			camera.look_at(player.position + Vector3(0.0, 0.0, -8.0), Vector3.UP)
		return
	_update_flight(delta)


func _update_flight(delta: float) -> void:
	if invulnerability > 0.0:
		invulnerability = maxf(invulnerability - delta, 0.0)
		player.visible = int(Time.get_ticks_msec() / 100) % 2 == 0
	else:
		player.visible = true
	if boost_time > 0.0:
		boost_time = maxf(boost_time - delta, 0.0)
	else:
		boost_speed = move_toward(boost_speed, 0.0, delta * 30.0)
	boost_cooldown = maxf(boost_cooldown - delta, 0.0)
	var current_speed := run_speed + boost_speed
	distance += current_speed * delta
	run_score += int(current_speed * delta * 4.0)
	course_root.position.z += current_speed * delta
	starfield_offset = fmod(starfield_offset + current_speed * delta * 0.12, 210.0)
	stars.position.z = starfield_offset - 100.0
	var target := Vector3(steering_target.x, steering_target.y, 0.0)
	var response := steering_rate if equipped_parts.has("wing_pack") else 7.0
	player.position.x = move_toward(player.position.x, target.x, delta * response)
	player.position.y = move_toward(player.position.y, target.y, delta * response)
	player.position.x = clampf(player.position.x, -10.0, 10.0)
	player.position.y = clampf(player.position.y, -5.5, 5.5)
	player.rotation.z = lerpf(player.rotation.z, clampf((target.x - player.position.x) * -0.08, -0.55, 0.55), delta * 4.0)
	player.rotation.x = lerpf(player.rotation.x, clampf((target.y - player.position.y) * 0.06, -0.28, 0.28), delta * 4.0)
	camera.position = camera.position.lerp(player.position + Vector3(0.0, 3.9, 11.5), minf(delta * 4.0, 1.0))
	camera.look_at(player.position + Vector3(0.0, 0.0, -16.0), Vector3.UP)

	while next_segment_distance < distance + 190.0:
		_spawn_segment(-next_segment_distance)
		next_segment_distance += rng.randf_range(48.0, 76.0)
	for item in course_objects:
		if is_instance_valid(item) and item.global_position.z > 18.0:
			item.queue_free()
	for shot in projectiles:
		if is_instance_valid(shot):
			shot.position.z -= 95.0 * delta
			if shot.global_position.z < -210.0:
				shot.queue_free()
	projectiles = projectiles.filter(func(node): return is_instance_valid(node))
	course_objects = course_objects.filter(func(node): return is_instance_valid(node))
	fire_cooldown = maxf(fire_cooldown - delta, 0.0)
	var auto_fire := firing or Input.is_key_pressed(KEY_SPACE)
	if auto_fire and fire_cooldown <= 0.0:
		_fire_weapon()
		fire_cooldown = 0.16 if equipped_parts.has("twin_cannon") else 0.3
	var new_rift := int(distance / 180.0) + 1
	if new_rift > int((distance - current_speed * delta) / 180.0) + 1:
		run_speed = minf(run_speed + 1.6, 43.0)
	_update_hud()


func _spawn_segment(z_position: float) -> void:
	segment_number += 1
	var rift_level := int(float(segment_number) / 4.0) + 1
	var pattern := rng.randi_range(0, 5)
	match pattern:
		0:
			_spawn_gate(z_position, rng.randi_range(0, 3))
		1:
			_spawn_debris(z_position, 3 + mini(rift_level, 3))
		2:
			_spawn_salvage_line(z_position)
		3:
			_spawn_enemy(z_position)
		4:
			_spawn_alternating_wall(z_position, rift_level)
		_:
			_spawn_debris(z_position, 2)
			if rng.randf() < 0.7:
				_spawn_pickup(Vector3(rng.randf_range(-7.0, 7.0), rng.randf_range(-3.8, 3.8), z_position - 12.0), "scrap")
	if segment_number == secret_life_segment and not secret_life_claimed:
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		_spawn_gate(z_position - 2.0, 1 if side < 0.0 else 2)
		_spawn_pickup(Vector3(side * rng.randf_range(7.0, 8.7), rng.randf_range(-4.2, 4.2), z_position - 2.0), "life")
		secret_life_claimed = true


func _spawn_gate(z_position: float, open_index: int) -> void:
	var slots := [
		Vector3(-6.0, 0.0, z_position),
		Vector3(-2.0, 0.0, z_position),
		Vector3(2.0, 0.0, z_position),
		Vector3(6.0, 0.0, z_position),
	]
	for i in range(slots.size()):
		if i == open_index:
			continue
		_spawn_hazard(slots[i], Vector3(3.1, 4.0, 2.7), Color(0.76, 0.19, 0.23))
	_spawn_hazard(Vector3(0.0, 6.8, z_position), Vector3(23.0, 1.2, 2.7), Color(0.32, 0.39, 0.56))
	_spawn_hazard(Vector3(0.0, -6.8, z_position), Vector3(23.0, 1.2, 2.7), Color(0.32, 0.39, 0.56))
	if rng.randf() < 0.45:
		_spawn_pickup(Vector3(slots[open_index].x, rng.randf_range(-1.0, 1.0), z_position - 1.0), "scrap")


func _spawn_debris(z_position: float, count: int) -> void:
	for i in range(count):
		var x := rng.randf_range(-9.0, 9.0)
		var y := rng.randf_range(-5.0, 5.0)
		if absf(x) < 2.0 and absf(y) < 1.5:
			x = 4.2 if x >= 0.0 else -4.2
		var dims := Vector3(rng.randf_range(1.4, 3.4), rng.randf_range(1.2, 3.2), rng.randf_range(1.8, 4.0))
		var hue_color: Color = [Color(0.75, 0.27, 0.2), Color(0.31, 0.42, 0.62), Color(0.48, 0.33, 0.72)][rng.randi_range(0, 2)]
		_spawn_hazard(Vector3(x, y, z_position - rng.randf_range(0.0, 18.0)), dims, hue_color, Vector3(rng.randf_range(-0.45, 0.45), rng.randf_range(-0.45, 0.45), rng.randf_range(-0.45, 0.45)))


func _spawn_salvage_line(z_position: float) -> void:
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	for i in range(5):
		var x := side * (2.0 + float(i) * 1.15)
		var y := sin(float(i) * 0.85) * 1.25
		_spawn_pickup(Vector3(x, y, z_position - float(i) * 7.0), "scrap")
	_spawn_debris(z_position - 21.0, 2)


func _spawn_alternating_wall(z_position: float, level: int) -> void:
	var safe_x := rng.randf_range(-6.5, 6.5)
	var count := 3 + mini(level, 2)
	for i in range(count):
		var x := rng.randf_range(-9.5, 9.5)
		while absf(x - safe_x) < 4.0:
			x = rng.randf_range(-9.5, 9.5)
		var y := rng.randf_range(-4.5, 4.5)
		_spawn_hazard(Vector3(x, y, z_position - float(i) * 5.5), Vector3(rng.randf_range(2.2, 4.0), rng.randf_range(2.0, 3.4), 2.6), Color(0.69, 0.24, 0.3))
		safe_x = -safe_x * 0.65
	if rng.randf() < 0.55:
		_spawn_pickup(Vector3(safe_x, 0.0, z_position - 4.0), "scrap")


func _spawn_hazard(at: Vector3, dimensions: Vector3, tint: Color, spin := Vector3.ZERO) -> void:
	var area := Area3D.new()
	area.position = at
	area.collision_layer = 8
	area.collision_mask = 1
	area.add_to_group("hazards")
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	shape_node.shape = shape
	area.add_child(shape_node)
	var mesh := _make_block(Vector3.ZERO, dimensions, tint)
	area.add_child(mesh)
	area.body_entered.connect(_on_hazard_body_entered.bind(area))
	area.set_meta("spin", spin)
	course_root.add_child(area)
	course_objects.append(area)


func _spawn_pickup(at: Vector3, kind: String) -> void:
	var pickup := Area3D.new()
	pickup.position = at
	pickup.collision_layer = 2
	pickup.collision_mask = 1
	pickup.add_to_group("pickups")
	pickup.set_meta("kind", kind)
	var shape_node := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.1 if kind == "life" else 0.9
	shape_node.shape = sphere
	pickup.add_child(shape_node)
	var tint := Color(0.36, 1.0, 0.69) if kind == "scrap" else Color(1.0, 0.83, 0.28)
	var crystal := _make_block(Vector3.ZERO, Vector3.ONE * (1.05 if kind == "life" else 0.72), tint, true)
	crystal.rotation_degrees = Vector3(25.0, 45.0, 0.0)
	pickup.add_child(crystal)
	pickup.body_entered.connect(_on_pickup_body_entered.bind(pickup))
	course_root.add_child(pickup)
	course_objects.append(pickup)


func _spawn_enemy(z_position: float) -> void:
	var enemy := Area3D.new()
	enemy.position = Vector3(rng.randf_range(-7.0, 7.0), rng.randf_range(-3.5, 3.5), z_position)
	enemy.collision_layer = 4
	enemy.collision_mask = 1
	enemy.add_to_group("enemies")
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.6, 2.2, 2.4)
	shape_node.shape = shape
	enemy.add_child(shape_node)
	enemy.add_child(_make_block(Vector3.ZERO, Vector3(2.3, 1.5, 2.4), Color(0.83, 0.21, 0.24)))
	enemy.add_child(_make_block(Vector3(0.0, 0.05, -1.25), Vector3(0.85, 0.55, 0.35), Color(1.0, 0.71, 0.27), true))
	enemy.body_entered.connect(_on_hazard_body_entered.bind(enemy))
	course_root.add_child(enemy)
	course_objects.append(enemy)
	_spawn_pickup(Vector3(enemy.position.x, enemy.position.y + 2.5, z_position - 3.0), "scrap")


func _fire_weapon() -> void:
	var barrels := [-0.53, 0.53] if equipped_parts.has("twin_cannon") else [0.0]
	for barrel_x in barrels:
		var shot := Area3D.new()
		shot.position = player.position + Vector3(barrel_x, 0.0, -2.0)
		shot.collision_layer = 2
		shot.collision_mask = 4
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.38, 0.38, 1.25)
		shape_node.shape = shape
		shot.add_child(shape_node)
		shot.add_child(_make_block(Vector3.ZERO, Vector3(0.25, 0.25, 1.1), Color(0.35, 0.89, 1.0), true))
		shot.area_entered.connect(_on_shot_hit.bind(shot))
		add_child(shot)
		projectiles.append(shot)


func _on_shot_hit(area: Area3D, shot: Area3D) -> void:
	if not is_instance_valid(shot) or not area.is_in_group("enemies"):
		return
	run_score += 150
	run_scrap += 12
	total_scrap += 12
	_save_profile()
	area.queue_free()
	shot.queue_free()


func _on_hazard_body_entered(body: Node3D, hazard: Area3D) -> void:
	if body != player or state != ScreenState.RUN:
		return
	if invulnerability > 0.0:
		return
	if armor_charge > 0:
		armor_charge -= 1
		invulnerability = 1.0
		run_score += 25
		return
	lives -= 1
	invulnerability = 1.8
	steering_target = Vector2.ZERO
	_update_hud()
	if lives <= 0:
		_end_run()


func _on_pickup_body_entered(body: Node3D, pickup: Area3D) -> void:
	if body != player or state != ScreenState.RUN or not is_instance_valid(pickup):
		return
	var kind := str(pickup.get_meta("kind", "scrap"))
	if kind == "life":
		lives = mini(lives + 1, 4)
		secret_life_claimed = true
	else:
		run_scrap += 10
		total_scrap += 10
		run_score += 50
		_save_profile()
	pickup.queue_free()
	_update_hud()


func _activate_boost() -> void:
	if state != ScreenState.RUN or boost_cooldown > 0.0:
		return
	boost_time = boost_duration
	boost_speed = 17.0 if equipped_parts.has("boost_core") else 11.0
	boost_cooldown = 5.2
	invulnerability = maxf(invulnerability, 0.5)


func _end_run() -> void:
	state = ScreenState.GAME_OVER
	hud.visible = false
	menu_panel.visible = false
	shop_panel.visible = false
	game_over_panel.visible = true
	player.visible = true
	high_score = maxi(high_score, run_score)
	equipped_parts = ["core"]
	_save_profile()
	var summary: Label = game_over_panel.get_meta("summary")
	summary.text = "SCORE  %d\nSALVAGE BANKED  +%d\nBEST FLIGHT  %d\nTOTAL SCRAP  %d" % [run_score, run_scrap, high_score, total_scrap]
	_rebuild_ship_mesh()


func _update_hud() -> void:
	if not is_instance_valid(hud):
		return
	lives_label.text = "LIVES  %d" % lives
	score_label.text = "SCORE  %07d" % run_score
	scrap_label.text = "SCRAP  %d  (+%d)" % [total_scrap, run_scrap]
	difficulty_label.text = "RIFT  %d" % (int(distance / 180.0) + 1)
	boost_button.disabled = boost_cooldown > 0.0
	boost_button.text = "BOOST" if boost_cooldown <= 0.0 else "CHARGING"


func _input(event: InputEvent) -> void:
	if state != ScreenState.RUN:
		return
	if event is InputEventScreenDrag:
		_update_steering_from_screen(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		_update_steering_from_screen(event.position)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_update_steering_from_screen(event.position)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			firing = true
		elif event.keycode == KEY_SHIFT:
			_activate_boost()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.pressed:
		if event.keycode == KEY_SPACE:
			firing = false


func _update_steering_from_screen(pointer: Vector2) -> void:
	var bounds := get_viewport().get_visible_rect().size
	if pointer.x > bounds.x * 0.76:
		return
	var x_fraction := (pointer.x / bounds.x - 0.5) * 2.0
	var y_fraction := (0.5 - pointer.y / bounds.y) * 2.0
	steering_target.x = clampf(x_fraction * 9.2, -9.2, 9.2)
	steering_target.y = clampf(y_fraction * 5.2, -5.2, 5.2)


func _load_profile() -> void:
	var config := ConfigFile.new()
	if config.load(PROFILE_PATH) != OK:
		return
	total_scrap = int(config.get_value("pilot", "scrap", 0))
	high_score = int(config.get_value("pilot", "high_score", 0))
	runs_started = int(config.get_value("pilot", "runs_started", 0))
	var saved_owned = config.get_value("pilot", "owned_parts", ["core"])
	owned_parts.clear()
	for part_id in saved_owned:
		if part_id == "core" or PARTS.has(str(part_id)):
			owned_parts.append(str(part_id))
	if not owned_parts.has("core"):
		owned_parts.push_front("core")
	var saved_equipped = config.get_value("pilot", "equipped_parts", ["core"])
	equipped_parts.clear()
	for part_id in saved_equipped:
		if owned_parts.has(str(part_id)) and equipped_parts.size() < 4:
			equipped_parts.append(str(part_id))
	if not equipped_parts.has("core"):
		equipped_parts.push_front("core")


func _save_profile() -> void:
	var config := ConfigFile.new()
	config.set_value("pilot", "scrap", total_scrap)
	config.set_value("pilot", "high_score", high_score)
	config.set_value("pilot", "runs_started", runs_started)
	config.set_value("pilot", "owned_parts", owned_parts)
	config.set_value("pilot", "equipped_parts", equipped_parts)
	config.save(PROFILE_PATH)

