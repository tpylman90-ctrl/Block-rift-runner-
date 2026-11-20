extends Node3D

class FlightRadar extends Control:
	var blips: Array[Dictionary] = []

	func _draw() -> void:
		var radius := minf(size.x, size.y) * 0.5 - 3.0
		var center := size * 0.5
		draw_circle(center, radius, Color(0.018, 0.09, 0.18, 0.88))
		draw_arc(center, radius, 0.0, TAU, 48, Color(0.25, 0.78, 1.0, 0.9), 3.0, true)
		draw_arc(center, radius * 0.66, 0.0, TAU, 48, Color(0.22, 0.63, 0.9, 0.34), 1.0, true)
		draw_arc(center, radius * 0.32, 0.0, TAU, 48, Color(0.22, 0.63, 0.9, 0.28), 1.0, true)
		draw_line(Vector2(center.x - radius, center.y), Vector2(center.x + radius, center.y), Color(0.22, 0.63, 0.9, 0.25), 1.0)
		draw_line(Vector2(center.x, center.y - radius), Vector2(center.x, center.y + radius), Color(0.22, 0.63, 0.9, 0.25), 1.0)
		for blip in blips:
			var offset: Vector2 = blip.offset
			draw_circle(center + offset * radius * 0.78, 4.0, blip.tint)
		draw_colored_polygon(PackedVector2Array([center + Vector2(0, -8), center + Vector2(-5, 6), center + Vector2(0, 3), center + Vector2(5, 6)]), Color(1.0, 0.91, 0.45))

enum ScreenState { HANGAR, BUILDER, RUN, STAGE_BREAK, GAME_OVER }

const PROFILE_PATH := "user://pilot_profile.cfg"
const STAGE_DISTANCE := 360.0
const STAGE_MULTIPLIER_STEP := 0.25
const MAX_PLACED_BLOCKS := 12
const BUILD_GRID := 0.5
const BACKGROUND_ANGLES := 5
const SPACE_BACKGROUNDS := [
	"res://art/backgrounds/rift_way.jpg",
	"res://art/backgrounds/ice.jpg",
	"res://art/backgrounds/emerald.jpg",
	"res://art/backgrounds/ember.jpg",
	"res://art/backgrounds/violet.jpg",
	"res://art/backgrounds/gold.jpg",
]
const PARTS := {
	"splitter_nose": {"title": "SPLITTER NOSE", "cost": 60, "hint": "SHARP FRONT BLOCK", "category": "HULL", "preview": "res://art/library/previews/splitter_nose.png"},
	"wing_pack": {"title": "AERO WING PAIR", "cost": 55, "hint": "QUICKER HANDLING", "category": "WINGS", "preview": "res://art/library/previews/wing_pack.png"},
	"fin_set": {"title": "TAIL FIN SET", "cost": 45, "hint": "TWIN STABILITY FINS", "category": "WINGS", "preview": "res://art/library/previews/fin_set.png"},
	"boost_core": {"title": "PULSE ENGINE", "cost": 125, "hint": "LONGER BOOST", "category": "ENGINES", "preview": "res://art/library/previews/boost_core.png"},
	"side_pods": {"title": "SIDE THRUSTER PODS", "cost": 80, "hint": "SIDE ENGINE PAIR", "category": "ENGINES", "preview": "res://art/library/previews/side_pods.png"},
	"twin_cannon": {"title": "TWIN CANNONS", "cost": 85, "hint": "FASTER FIRE", "category": "WEAPONS", "preview": "res://art/library/previews/twin_cannon.png"},
	"armor": {"title": "ARMOR PLATE", "cost": 100, "hint": "ONE HIT BUFFER", "category": "ARMOR", "preview": "res://art/library/previews/armor.png"},
}

const PART_CATEGORIES := ["ALL", "HULL", "WINGS", "ENGINES", "WEAPONS", "ARMOR"]
const ASTEROID_VARIANTS := [
	"res://art/library/models/asteroid_1.glb",
	"res://art/library/models/asteroid_2.glb",
	"res://art/library/models/asteroid_3.glb",
]
var asteroid_templates: Array[Node3D] = []

var state: ScreenState = ScreenState.HANGAR
var rng := RandomNumberGenerator.new()
var player: CharacterBody3D
var build_grid_root: Node3D
var camera: Camera3D
var course_root: Node3D
var ui_root: Control
var menu_panel: CenterContainer
var shop_panel: Control
var game_over_panel: CenterContainer
var stage_break_panel: CenterContainer
var stage_break_shade: ColorRect
var stage_break_summary: Label
var stage_break_view_label: Label
var backdrop_material: StandardMaterial3D
var hud: Control
var title_label: Label
var subtitle_label: Label
var lives_label: Label
var score_label: Label
var scrap_label: Label
var difficulty_label: Label
var steering_hint: Label
var aiming_reticle: Label
var radar_widget: FlightRadar
var fire_button: Button
var boost_button: Button
var boost_meter: ProgressBar
var shop_status: Label
var shop_buttons: Dictionary = {}
var builder_tabs: HBoxContainer
var builder_grid: GridContainer
var active_category := "ALL"
var builder_preview_label: Label
var builder_cards: Dictionary = {}
var builder_place_label: Label
var builder_rotate_button: Button
var builder_remove_button: Button
var builder_clear_button: Button
var builder_depth_back_button: Button
var builder_depth_forward_button: Button
var selected_part_id := ""
var selected_placement_index := -1
var placement_rotation := 0.0
var placement_depth := -0.1
var part_placements: Array[Dictionary] = []
var builder_pointer_start := Vector2.ZERO
var builder_pointer_active := false
var builder_drag_source := ""
var builder_dragging := false
var builder_drag_ghost: TextureRect
var space_background: TextureRect

var total_scrap := 0
var run_scrap := 0
var last_cashout_payout := 0
var run_score := 0
var high_score := 0
var runs_started := 0
var owned_parts: Array[String] = ["core"]
var equipped_parts: Array[String] = ["core"]
var lives := 3
var distance := 0.0
var stage_distance := 0.0
var stage_index := 1
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
var steering_touch_index := -1
var camera_shake := 0.0
var engine_flames: Array[MeshInstance3D] = []
var secret_life_segment := -1
var secret_life_claimed := false
var course_objects: Array[Node3D] = []
var projectiles: Array[Area3D] = []
var stars: MultiMeshInstance3D
var starfield_offset := 0.0
var selected_background_index := -1
var selected_background_angle := -1


func _ready() -> void:
	rng.randomize()
	_load_profile()
	_load_asteroid_models()
	_build_world()
	_build_ship()
	_build_ui()
	_show_hangar()
	get_viewport().size_changed.connect(_layout_ui)


func _build_world() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.012, 0.008, 0.045)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.34, 0.27, 0.72)
	environment.ambient_light_energy = 0.82
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.025, 0.095, 0.2)
	environment.fog_density = 0.004
	environment.fog_sun_scatter = 0.22
	world_environment.environment = environment
	add_child(world_environment)
	_build_space_background_layer()

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-28.0, -25.0, 0.0)
	key_light.light_color = Color(0.62, 0.8, 1.0)
	key_light.light_energy = 1.65
	add_child(key_light)

	camera = Camera3D.new()
	camera.current = true
	camera.fov = 78.0
	add_child(camera)
	_build_space_backdrop()

	course_root = Node3D.new()
	course_root.name = "GeneratedCourse"
	add_child(course_root)
	_build_starfield()


func _build_space_backdrop() -> void:
	_choose_background_view()


func _build_space_background_layer() -> void:
	var background_layer := CanvasLayer.new()
	background_layer.layer = -1
	add_child(background_layer)
	space_background = TextureRect.new()
	space_background.name = "PhotoSpaceBackground"
	space_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	space_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	space_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	space_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background_layer.add_child(space_background)


func _choose_background_view() -> void:
	var choices := SPACE_BACKGROUNDS.size() * BACKGROUND_ANGLES
	var choice := rng.randi_range(0, choices - 1)
	if choice == selected_background_index * BACKGROUND_ANGLES + selected_background_angle:
		choice = (choice + rng.randi_range(1, choices - 1)) % choices
	selected_background_index = int(choice / BACKGROUND_ANGLES)
	selected_background_angle = choice % BACKGROUND_ANGLES
	var source := load(SPACE_BACKGROUNDS[selected_background_index]) as Texture2D
	if is_instance_valid(space_background) and source:
		var atlas := AtlasTexture.new()
		atlas.atlas = source
		var texture_size := source.get_size()
		var x_scale := 0.72
		var y_scale := 0.82
		var x_offset := float(selected_background_angle) * (1.0 - x_scale) / float(BACKGROUND_ANGLES - 1)
		var y_offset := float((selected_background_index + selected_background_angle) % 3) * (1.0 - y_scale) / 2.0
		atlas.region = Rect2(texture_size.x * x_offset, texture_size.y * y_offset, texture_size.x * x_scale, texture_size.y * y_scale)
		space_background.texture = atlas


func _load_asteroid_models() -> void:
	for model_path in ASTEROID_VARIANTS:
		var gltf := GLTFDocument.new()
		var gltf_state := GLTFState.new()
		var load_error := gltf.append_from_file(model_path, gltf_state)
		if load_error != OK:
			push_warning("Could not load asteroid model: %s" % model_path)
			continue
		var model_scene := gltf.generate_scene(gltf_state)
		if model_scene:
			asteroid_templates.append(model_scene)
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
	multi.instance_count = 430
	for i in range(multi.instance_count):
		var x := rng.randf_range(-100.0, 100.0)
		var y := rng.randf_range(-65.0, 65.0)
		var z := rng.randf_range(-190.0, 40.0)
		var scale_value := rng.randf_range(0.35, 1.25)
		multi.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * scale_value), Vector3(x, y, z)))
		var tint := Color(0.34, 0.62, 1.0).lerp(Color(0.72, 0.83, 1.0), rng.randf())
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
	_build_ship_grid()
	add_child(player)
	_rebuild_ship_mesh()


func _build_ship_grid() -> void:
	build_grid_root = Node3D.new()
	build_grid_root.name = "MagneticBuildGrid"
	build_grid_root.visible = false
	var grid_mesh := ImmediateMesh.new()
	grid_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for x_step in range(-8, 9):
		var x := float(x_step) * BUILD_GRID
		grid_mesh.surface_add_vertex(Vector3(x, -3.0, -1.85))
		grid_mesh.surface_add_vertex(Vector3(x, 3.0, -1.85))
	for y_step in range(-6, 7):
		var y := float(y_step) * BUILD_GRID
		grid_mesh.surface_add_vertex(Vector3(-4.0, y, -1.85))
		grid_mesh.surface_add_vertex(Vector3(4.0, y, -1.85))
	grid_mesh.surface_end()
	var grid_material := StandardMaterial3D.new()
	grid_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	grid_material.albedo_color = Color(0.18, 0.68, 0.92, 0.26)
	grid_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	grid_material.no_depth_test = true
	var grid_instance := MeshInstance3D.new()
	grid_instance.mesh = grid_mesh
	grid_instance.material_override = grid_material
	grid_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	build_grid_root.add_child(grid_instance)
	player.add_child(build_grid_root)


func _rebuild_ship_mesh() -> void:
	engine_flames.clear()
	for child in player.get_children():
		if child is MeshInstance3D:
			child.queue_free()
	var hull := _make_block(Vector3(0.0, 0.0, 0.25), Vector3(1.55, 0.8, 3.0), Color(0.81, 0.23, 0.25))
	player.add_child(hull)
	var nose := _make_block(Vector3(0.0, 0.04, -1.55), Vector3(1.08, 0.53, 1.0), Color(1.0, 0.73, 0.23))
	player.add_child(nose)
	var cockpit := _make_block(Vector3(0.0, 0.55, -0.25), Vector3(0.72, 0.42, 1.0), Color(0.11, 0.25, 0.48))
	player.add_child(cockpit)
	for side in [-1.0, 1.0]:
		var wing := _make_block(Vector3(side * 1.12, 0.03, -0.35), Vector3(1.1, 0.2, 1.55), Color(0.86, 0.92, 1.0))
		player.add_child(wing)
		var engine := _make_block(Vector3(side * 0.92, -0.08, 1.05), Vector3(0.48, 0.58, 1.45), Color(0.27, 0.38, 0.58))
		player.add_child(engine)
		var glow := _make_block(Vector3(side * 0.92, -0.08, 1.83), Vector3(0.28, 0.3, 0.15), Color(0.13, 0.78, 1.0), true)
		player.add_child(glow)
		var flame := _make_block(Vector3(side * 0.92, -0.08, 2.18), Vector3(0.22, 0.24, 0.72), Color(0.24, 0.62, 1.0), true)
		player.add_child(flame)
		engine_flames.append(flame)
	var center_glow := _make_block(Vector3(0.0, 0.0, 1.62), Vector3(0.34, 0.28, 0.2), Color(0.96, 0.37, 1.0), true)
	player.add_child(center_glow)
	for placement in part_placements:
		var part_id := str(placement.get("id", ""))
		if not PARTS.has(part_id):
			continue
		var block := _make_placed_part(part_id)
		block.position = placement.get("position", Vector3.ZERO)
		block.rotation.z = float(placement.get("rotation", 0.0))
		if part_placements.find(placement) == selected_placement_index:
			var selected_material := block.material_override as StandardMaterial3D
			selected_material.emission_enabled = true
			selected_material.emission = Color(0.1, 0.62, 1.0)
			selected_material.emission_energy_multiplier = 0.55
		player.add_child(block)


func _make_placed_part(part_id: String) -> MeshInstance3D:
	var dimensions := Vector3(0.8, 0.48, 0.72)
	var tint := Color(0.9, 0.45, 0.28)
	match part_id:
		"splitter_nose":
			dimensions = Vector3(0.92, 0.34, 0.7)
			tint = Color(0.95, 0.88, 0.68)
		"wing_pack":
			dimensions = Vector3(1.0, 0.2, 0.62)
			tint = Color(0.94, 0.39, 0.24)
		"fin_set":
			dimensions = Vector3(0.28, 0.76, 0.5)
			tint = Color(0.98, 0.59, 0.27)
		"boost_core":
			dimensions = Vector3(0.52, 0.42, 0.62)
			tint = Color(0.42, 0.32, 0.96)
		"side_pods":
			dimensions = Vector3(0.48, 0.52, 0.78)
			tint = Color(0.18, 0.42, 0.72)
		"twin_cannon":
			dimensions = Vector3(0.24, 0.24, 0.82)
			tint = Color(1.0, 0.64, 0.23)
		"armor":
			dimensions = Vector3(0.92, 0.22, 0.68)
			tint = Color(0.88, 0.3, 0.23)
	return _make_block(Vector3.ZERO, dimensions, tint)


func _make_block(at: Vector3, dimensions: Vector3, tint: Color, emissive := false) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	mesh_instance.mesh = mesh
	mesh_instance.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.72
	material.metallic = 0.12
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
	parts.text = "SHIP BUILDER"
	parts.pressed.connect(_show_builder)
	menu_column.add_child(parts)
	var help := _label("DRAG TO FLY  •  FIRE TO CLEAR DRONES  •  BOOST TO SURGE", 17, Color(0.57, 0.66, 0.82))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_column.add_child(help)

	shop_panel = Control.new()
	shop_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(shop_panel)
	var builder_shade := ColorRect.new()
	builder_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	builder_shade.color = Color(0.008, 0.018, 0.045, 0.42)
	builder_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop_panel.add_child(builder_shade)
	var builder_window := PanelContainer.new()
	builder_window.anchor_right = 0.65
	builder_window.anchor_bottom = 1.0
	builder_window.offset_left = 28.0
	builder_window.offset_top = 28.0
	builder_window.offset_right = -18.0
	builder_window.offset_bottom = -28.0
	var window_style := StyleBoxFlat.new()
	window_style.bg_color = Color(0.012, 0.04, 0.09, 0.95)
	window_style.border_color = Color(0.12, 0.58, 0.82, 0.9)
	window_style.set_border_width_all(2)
	window_style.set_corner_radius_all(14)
	window_style.content_margin_left = 18
	window_style.content_margin_right = 18
	window_style.content_margin_top = 14
	window_style.content_margin_bottom = 14
	builder_window.add_theme_stylebox_override("panel", window_style)
	shop_panel.add_child(builder_window)
	var shop_column := VBoxContainer.new()
	shop_column.add_theme_constant_override("separation", 10)
	builder_window.add_child(shop_column)
	var builder_header := HBoxContainer.new()
	shop_column.add_child(builder_header)
	var shop_title := _label("SHIP BUILDER  /  BLOCK LIBRARY", 31, Color(0.53, 0.88, 1.0))
	shop_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	builder_header.add_child(shop_title)
	shop_status = _label("", 20, Color(1.0, 0.77, 0.35))
	shop_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	builder_header.add_child(shop_status)
	builder_tabs = HBoxContainer.new()
	builder_tabs.add_theme_constant_override("separation", 6)
	shop_column.add_child(builder_tabs)
	for category in PART_CATEGORIES:
		var tab := _button(category, 15)
		tab.custom_minimum_size = Vector2(0.0, 48.0)
		tab.set_meta("builder_component", true)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(_set_builder_category.bind(category))
		builder_tabs.add_child(tab)
	var library_scroll := ScrollContainer.new()
	library_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	library_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shop_column.add_child(library_scroll)
	builder_grid = GridContainer.new()
	builder_grid.columns = 2
	builder_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	builder_grid.add_theme_constant_override("h_separation", 12)
	builder_grid.add_theme_constant_override("v_separation", 10)
	library_scroll.add_child(builder_grid)
	for part_id in PARTS.keys():
		var item: Dictionary = PARTS[part_id]
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(280.0, 220.0)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.025, 0.08, 0.14, 0.97)
		card_style.border_color = Color(0.12, 0.3, 0.44, 0.9)
		card_style.set_border_width_all(1)
		card_style.set_corner_radius_all(10)
		card_style.content_margin_left = 10
		card_style.content_margin_right = 10
		card_style.content_margin_top = 8
		card_style.content_margin_bottom = 8
		card.add_theme_stylebox_override("panel", card_style)
		var card_column := VBoxContainer.new()
		card_column.add_theme_constant_override("separation", 4)
		card.add_child(card_column)
		var thumbnail := TextureRect.new()
		thumbnail.custom_minimum_size = Vector2(260.0, 118.0)
		thumbnail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var preview_path := str(item.preview)
		if ResourceLoader.exists(preview_path):
			thumbnail.texture = load(preview_path)
		card_column.add_child(thumbnail)
		var part_title := _label(str(item.title), 18, Color(0.88, 0.95, 1.0))
		card_column.add_child(part_title)
		var part_hint := _label("%s  •  %d SCRAP" % [str(item.hint), int(item.cost)], 14, Color(0.55, 0.76, 0.93))
		card_column.add_child(part_hint)
		var part_button := _button("", 15)
		part_button.custom_minimum_size = Vector2(0.0, 42.0)
		part_button.set_meta("builder_component", true)
		part_button.pressed.connect(_on_shop_part_pressed.bind(part_id))
		card_column.add_child(part_button)
		builder_grid.add_child(card)
		shop_buttons[part_id] = part_button
		builder_cards[part_id] = card
	var builder_footer := HBoxContainer.new()
	shop_column.add_child(builder_footer)
	var shop_note := _label("UNLOCKS PERSIST  •  BUILD WITH UP TO 12 BLOCKS  •  RUN BUILDS RESET AFTER GAME OVER", 14, Color(0.62, 0.69, 0.83))
	shop_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	builder_footer.add_child(shop_note)
	var back := _button("FLIGHT DECK", 17)
	back.custom_minimum_size = Vector2(180.0, 46.0)
	back.set_meta("builder_component", true)
	back.pressed.connect(_show_hangar)
	builder_footer.add_child(back)
	builder_preview_label = _label("3D SHIP PREVIEW\nDRAG TO ORBIT  •  %d / 4 BLOCKS" % equipped_parts.size(), 21, Color(0.78, 0.9, 1.0))
	builder_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	builder_preview_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	shop_panel.add_child(builder_preview_label)
	builder_place_label = _label("DRAG A BLOCK ONTO THE SHIP  •  IT SNAPS TO MAGNET POINTS", 17, Color(0.74, 0.88, 1.0))
	builder_place_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_panel.add_child(builder_place_label)
	builder_drag_ghost = TextureRect.new()
	builder_drag_ghost.custom_minimum_size = Vector2(118.0, 82.0)
	builder_drag_ghost.size = Vector2(118.0, 82.0)
	builder_drag_ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	builder_drag_ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	builder_drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	builder_drag_ghost.visible = false
	builder_drag_ghost.z_index = 20
	shop_panel.add_child(builder_drag_ghost)
	var placement_tools := HBoxContainer.new()
	placement_tools.add_theme_constant_override("separation", 8)
	shop_panel.add_child(placement_tools)
	builder_rotate_button = _button("ROTATE", 13)
	builder_rotate_button.custom_minimum_size = Vector2(0.0, 52.0)
	builder_rotate_button.set_meta("builder_component", true)
	builder_rotate_button.pressed.connect(_rotate_next_block)
	placement_tools.add_child(builder_rotate_button)
	builder_remove_button = _button("REMOVE SELECTED", 13)
	builder_remove_button.custom_minimum_size = Vector2(0.0, 52.0)
	builder_remove_button.set_meta("builder_component", true)
	builder_remove_button.pressed.connect(_remove_selected_block)
	placement_tools.add_child(builder_remove_button)
	builder_depth_back_button = _button("DEPTH −", 13)
	builder_depth_back_button.custom_minimum_size = Vector2(0.0, 52.0)
	builder_depth_back_button.set_meta("builder_component", true)
	builder_depth_back_button.pressed.connect(_adjust_block_depth.bind(-BUILD_GRID))
	placement_tools.add_child(builder_depth_back_button)
	builder_depth_forward_button = _button("DEPTH +", 13)
	builder_depth_forward_button.custom_minimum_size = Vector2(0.0, 52.0)
	builder_depth_forward_button.set_meta("builder_component", true)
	builder_depth_forward_button.pressed.connect(_adjust_block_depth.bind(BUILD_GRID))
	placement_tools.add_child(builder_depth_forward_button)
	builder_clear_button = _button("CLEAR", 13)
	builder_clear_button.custom_minimum_size = Vector2(0.0, 52.0)
	builder_clear_button.set_meta("builder_component", true)
	builder_clear_button.pressed.connect(_clear_placed_blocks)
	placement_tools.add_child(builder_clear_button)

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

	stage_break_panel = CenterContainer.new()
	stage_break_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage_break_shade = ColorRect.new()
	stage_break_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage_break_shade.color = Color(0.004, 0.01, 0.025, 0.83)
	stage_break_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(stage_break_shade)
	ui_root.add_child(stage_break_panel)
	var stage_card := PanelContainer.new()
	stage_card.custom_minimum_size = Vector2(620.0, 420.0)
	var stage_style := StyleBoxFlat.new()
	stage_style.bg_color = Color(0.012, 0.04, 0.09, 0.98)
	stage_style.border_color = Color(0.16, 0.7, 0.94, 0.96)
	stage_style.set_border_width_all(3)
	stage_style.set_corner_radius_all(18)
	stage_style.content_margin_left = 30
	stage_style.content_margin_right = 30
	stage_style.content_margin_top = 24
	stage_style.content_margin_bottom = 24
	stage_card.add_theme_stylebox_override("panel", stage_style)
	stage_break_panel.add_child(stage_card)
	var stage_column := VBoxContainer.new()
	stage_column.alignment = BoxContainer.ALIGNMENT_CENTER
	stage_column.add_theme_constant_override("separation", 16)
	stage_card.add_child(stage_column)
	var stage_title := _label("RIFT STAGE CLEARED", 38, Color(0.52, 0.89, 1.0))
	stage_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_column.add_child(stage_title)
	stage_break_summary = _label("", 22, Color(0.88, 0.94, 1.0))
	stage_break_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_column.add_child(stage_break_summary)
	stage_break_view_label = _label("VIEW 01 / 30", 17, Color(0.58, 0.78, 0.95))
	stage_break_view_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_column.add_child(stage_break_view_label)
	var risk_note := _label("KEEP GOING TO RAISE THE MULTIPLIER. YOUR UNBANKED HAUL IS AT RISK.", 15, Color(1.0, 0.7, 0.34))
	risk_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_column.add_child(risk_note)
	var cashout_button := _button("CASH OUT & RETURN TO HANGAR", 18)
	cashout_button.custom_minimum_size = Vector2(520.0, 64.0)
	cashout_button.pressed.connect(_cash_out_run)
	stage_column.add_child(cashout_button)
	var continue_button := _button("CONTINUE • NEXT MULTIPLIER", 18)
	continue_button.custom_minimum_size = Vector2(520.0, 64.0)
	continue_button.pressed.connect(_continue_run)
	stage_column.add_child(continue_button)

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
	aiming_reticle = _label("[  ×  ]", 25, Color(0.79, 0.91, 1.0, 0.72))
	aiming_reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(aiming_reticle)
	radar_widget = FlightRadar.new()
	radar_widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(radar_widget)
	fire_button = _button("FIRE", 24)
	fire_button.button_down.connect(func(): firing = true)
	fire_button.button_up.connect(func(): firing = false)
	hud.add_child(fire_button)
	boost_button = _button("BOOST", 21)
	boost_button.button_down.connect(_activate_boost)
	hud.add_child(boost_button)
	boost_meter = ProgressBar.new()
	boost_meter.show_percentage = false
	boost_meter.min_value = 0.0
	boost_meter.max_value = 1.0
	var meter_background := StyleBoxFlat.new()
	meter_background.bg_color = Color(0.025, 0.07, 0.14, 0.9)
	meter_background.border_color = Color(0.18, 0.52, 0.86, 0.9)
	meter_background.set_border_width_all(2)
	boost_meter.add_theme_stylebox_override("background", meter_background)
	var meter_fill := StyleBoxFlat.new()
	meter_fill.bg_color = Color(0.98, 0.76, 0.2)
	meter_fill.set_corner_radius_all(5)
	boost_meter.add_theme_stylebox_override("fill", meter_fill)
	hud.add_child(boost_meter)
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
		if control.get_meta("builder_component", false):
			control.custom_minimum_size.y = 48.0
			continue
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
		aiming_reticle.position = Vector2(w * 0.46, h * 0.39)
		aiming_reticle.size = Vector2(w * 0.08, h * 0.06)
		radar_widget.position = Vector2(w * 0.025, h * 0.69)
		radar_widget.size = Vector2(minf(h * 0.22, w * 0.12), minf(h * 0.22, w * 0.12))
		boost_meter.position = Vector2(w - action_button_width - 28.0, h * 0.63)
		boost_meter.size = Vector2(action_button_width, h * 0.035)
		builder_preview_label.position = Vector2(w * 0.665, h * 0.045)
		builder_preview_label.size = Vector2(w * 0.32, h * 0.09)
		builder_place_label.position = Vector2(w * 0.66, h * 0.14)
		builder_place_label.size = Vector2(w * 0.33, h * 0.08)
		var placement_tools := builder_rotate_button.get_parent() as HBoxContainer
		placement_tools.position = Vector2(w * 0.66, h * 0.87)
		placement_tools.size = Vector2(w * 0.33, h * 0.09)
		for tool_button in [builder_rotate_button, builder_remove_button, builder_depth_back_button, builder_depth_forward_button, builder_clear_button]:
			tool_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _show_hangar() -> void:
	state = ScreenState.HANGAR
	menu_panel.visible = true
	shop_panel.visible = false
	game_over_panel.visible = false
	stage_break_panel.visible = false
	stage_break_shade.visible = false
	hud.visible = false
	firing = false
	if is_instance_valid(player):
		player.visible = true
		build_grid_root.visible = false
		player.position = Vector3(0.0, -0.4, 0.0)
		player.rotation = Vector3.ZERO
		camera.position = Vector3(0.0, 3.7, 10.5)
		camera.look_at(Vector3(0.0, 0.0, -8.0), Vector3.UP)
		camera.fov = 78.0
	subtitle_label.text = "BANKED %d   •   LAST CASHOUT +%d   •   BEST FLIGHT %d" % [total_scrap, last_cashout_payout, high_score]


func _show_builder() -> void:
	state = ScreenState.BUILDER
	menu_panel.visible = false
	shop_panel.visible = true
	game_over_panel.visible = false
	hud.visible = false
	player.visible = true
	build_grid_root.visible = true
	player.rotation = Vector3.ZERO
	camera.fov = 62.0
	camera.position = player.position + Vector3(3.2, 2.6, 10.5)
	camera.look_at(player.position + Vector3(-7.0, 0.0, 0.0), Vector3.UP)
	active_category = "ALL"
	_update_shop_buttons()


func _set_builder_category(category: String) -> void:
	active_category = category
	_update_shop_buttons()


func _update_shop_buttons() -> void:
	for part_id in PARTS.keys():
		var item: Dictionary = PARTS[part_id]
		var owned := owned_parts.has(part_id)
		var equipped := _has_placed_part(part_id)
		var button: Button = shop_buttons[part_id]
		if not owned:
			button.text = "BUILD  •  %d SCRAP" % int(item.cost)
		elif equipped:
			button.text = "IN BUILD  •  DRAG ANOTHER COPY"
		else:
			button.text = "DRAG TO SHIP" if selected_part_id != part_id else "SELECTED  •  DRAG TO BUILD"
		button.disabled = false
		var card: Control = builder_cards[part_id]
		card.visible = active_category == "ALL" or str(item.category) == active_category
	shop_status.text = "SCRAP %d  •  PLACED %d / %d" % [total_scrap, part_placements.size(), MAX_PLACED_BLOCKS]
	builder_preview_label.text = "SHIP WORKSHOP\nDRAG TO ORBIT  •  %d / %d BLOCKS" % [part_placements.size(), MAX_PLACED_BLOCKS]
	if is_instance_valid(builder_place_label):
		var title := str(PARTS[selected_part_id].title) if PARTS.has(selected_part_id) else "NO BLOCK SELECTED"
		if selected_placement_index >= 0 and selected_placement_index < part_placements.size():
			var placed_id := str(part_placements[selected_placement_index].get("id", ""))
			title = str(PARTS.get(placed_id, {}).get("title", placed_id))
			builder_remove_button.text = "REMOVE SELECTED"
		else:
			builder_remove_button.text = "REMOVE LAST"
		builder_place_label.text = "DRAG A LIBRARY BLOCK TO BUILD  •  DRAG SHIP BLOCKS TO MOVE" if selected_placement_index < 0 else "EDITING %s  •  DRAG TO MOVE, ROTATE, OR CHANGE DEPTH" % title
		builder_remove_button.disabled = part_placements.is_empty()
		builder_clear_button.disabled = part_placements.is_empty()


func _on_shop_part_pressed(part_id: String) -> void:
	var item: Dictionary = PARTS[part_id]
	if not owned_parts.has(part_id):
		if total_scrap < int(item.cost):
			shop_status.text = "NEED %d MORE SCRAP" % (int(item.cost) - total_scrap)
			return
		total_scrap -= int(item.cost)
		owned_parts.append(part_id)
		shop_status.text = "%s UNLOCKED  •  SELECT IT, THEN PLACE IT" % item.title
		_save_profile()
	selected_part_id = part_id
	selected_placement_index = -1
	_update_shop_buttons()


func _has_placed_part(part_id: String) -> bool:
	for placement in part_placements:
		if str(placement.get("id", "")) == part_id:
			return true
	return false


func _place_selected_block(screen_position: Vector2) -> void:
	if selected_part_id.is_empty() or not owned_parts.has(selected_part_id):
		shop_status.text = "SELECT OR UNLOCK A BLOCK FIRST"
		return
	if part_placements.size() >= MAX_PLACED_BLOCKS:
		shop_status.text = "MAX %d BLOCKS  •  REMOVE ONE TO MAKE ROOM" % MAX_PLACED_BLOCKS
		return
	var target := _screen_to_ship_position(screen_position, placement_depth)
	var snapped := _snap_free_grid(target, selected_part_id, placement_rotation)
	if snapped.x < -100.0:
		shop_status.text = "BLOCK OVERLAPS ANOTHER PART  •  DROP IN AN OPEN GRID CELL"
		return
	part_placements.append({"id": selected_part_id, "position": Vector3(snapped.x, snapped.y, placement_depth), "rotation": placement_rotation})
	selected_placement_index = part_placements.size() - 1
	_sync_equipped_parts()
	_rebuild_ship_mesh()
	_save_profile()
	shop_status.text = "%s PLACED ON BUILD GRID" % str(PARTS[selected_part_id].title)
	_update_shop_buttons()


func _screen_to_ship_position(screen_position: Vector2, depth: float) -> Vector2:
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_direction := camera.project_ray_normal(screen_position)
	var inverse := player.global_transform.affine_inverse()
	var local_origin := inverse * ray_origin
	var local_direction := inverse.basis * ray_direction
	if absf(local_direction.z) < 0.0001:
		return Vector2(-999.0, -999.0)
	var distance := (depth - local_origin.z) / local_direction.z
	if distance < 0.0:
		return Vector2(-999.0, -999.0)
	var local_point := local_origin + local_direction * distance
	return Vector2(clampf(local_point.x, -4.0, 4.0), clampf(local_point.y, -3.0, 3.0))


func _snap_free_grid(target: Vector2, part_id: String, rotation: float, ignore_index := -1) -> Vector2:
	var grid_position := Vector2(round(target.x / BUILD_GRID), round(target.y / BUILD_GRID)) * BUILD_GRID
	if absf(target.x) > 4.0 or absf(target.y) > 3.0:
		return Vector2(-999.0, -999.0)
	var part_size := _part_dimensions(part_id)
	if int(round(absf(rotation) / (PI * 0.5))) % 2 == 1:
		part_size = Vector2(part_size.y, part_size.x)
	var candidate := Vector3(grid_position.x, grid_position.y, placement_depth)
	var candidate_depth := _part_depth(part_id)
	var body_size := Vector3(1.55, 0.8, 3.0)
	if _boxes_overlap(candidate, Vector3(part_size.x, part_size.y, candidate_depth), Vector3(0.0, 0.0, 0.25), body_size):
		return Vector2(-999.0, -999.0)
	for index in range(part_placements.size()):
		if index == ignore_index:
			continue
		var placement: Dictionary = part_placements[index]
		var position: Vector3 = placement.get("position", Vector3.ZERO)
		var other_id := str(placement.get("id", ""))
		var other_size := _part_dimensions(other_id)
		if int(round(absf(float(placement.get("rotation", 0.0))) / (PI * 0.5))) % 2 == 1:
			other_size = Vector2(other_size.y, other_size.x)
		if _boxes_overlap(candidate, Vector3(part_size.x, part_size.y, candidate_depth), position, Vector3(other_size.x, other_size.y, _part_depth(other_id))):
			return Vector2(-999.0, -999.0)
	return grid_position


func _boxes_overlap(a: Vector3, a_size: Vector3, b: Vector3, b_size: Vector3) -> bool:
	return absf(a.x - b.x) < (a_size.x + b_size.x) * 0.5 - 0.035 and absf(a.y - b.y) < (a_size.y + b_size.y) * 0.5 - 0.035 and absf(a.z - b.z) < (a_size.z + b_size.z) * 0.5 - 0.035


func _part_depth(part_id: String) -> float:
	match part_id:
		"splitter_nose", "wing_pack", "side_pods": return 0.72
		"fin_set", "boost_core", "armor": return 0.62
		"twin_cannon": return 0.82
	return 0.72


func _part_dimensions(part_id: String) -> Vector2:
	match part_id:
		"splitter_nose": return Vector2(0.92, 0.34)
		"wing_pack": return Vector2(1.0, 0.2)
		"fin_set": return Vector2(0.28, 0.76)
		"boost_core": return Vector2(0.52, 0.42)
		"side_pods": return Vector2(0.48, 0.52)
		"twin_cannon": return Vector2(0.24, 0.24)
		"armor": return Vector2(0.92, 0.22)
	return Vector2(0.8, 0.48)


func _part_under_pointer(screen_position: Vector2) -> String:
	for part_id in shop_buttons.keys():
		var button: Button = shop_buttons[part_id]
		if owned_parts.has(part_id) and button.visible and button.get_global_rect().has_point(screen_position):
			return "part:" + str(part_id)
	if screen_position.x > get_viewport().get_visible_rect().size.x * 0.65:
		var picked := _pick_placed_block(screen_position)
		if picked >= 0:
			selected_placement_index = picked
			selected_part_id = str(part_placements[picked].get("id", ""))
			var picked_position: Vector3 = part_placements[picked].get("position", Vector3.ZERO)
			placement_depth = picked_position.z
			return "move:%d" % picked
	return ""


func _pick_placed_block(screen_position: Vector2) -> int:
	var closest_index := -1
	var closest_distance := 48.0
	for index in range(part_placements.size()):
		var placement: Dictionary = part_placements[index]
		var local_position: Vector3 = placement.get("position", Vector3.ZERO)
		var screen_point := camera.unproject_position(player.to_global(local_position))
		var pointer_distance := screen_point.distance_to(screen_position)
		if pointer_distance < closest_distance:
			closest_distance = pointer_distance
			closest_index = index
	return closest_index


func _move_builder_drag(screen_position: Vector2) -> void:
	if builder_drag_source.is_empty() or not builder_pointer_active:
		return
	if not builder_dragging and screen_position.distance_to(builder_pointer_start) >= 12.0:
		builder_dragging = true
		if builder_drag_source.begins_with("part:"):
			selected_part_id = builder_drag_source.trim_prefix("part:")
			selected_placement_index = -1
		elif builder_drag_source.begins_with("move:"):
			var index := int(builder_drag_source.trim_prefix("move:"))
			if index >= 0 and index < part_placements.size():
				selected_placement_index = index
				selected_part_id = str(part_placements[index].get("id", ""))
		var item: Dictionary = PARTS.get(selected_part_id, {})
		var preview_path := str(item.get("preview", ""))
		builder_drag_ghost.texture = load(preview_path) if ResourceLoader.exists(preview_path) else null
		builder_drag_ghost.visible = true
		_update_shop_buttons()
	if builder_dragging:
		builder_drag_ghost.position = screen_position - builder_drag_ghost.size * 0.5


func _finish_builder_drag(screen_position: Vector2) -> bool:
	var did_drag := builder_dragging
	var source := builder_drag_source
	if not source.is_empty() and source.begins_with("move:") and not did_drag:
		_update_shop_buttons()
		return true
	if did_drag:
		builder_drag_ghost.visible = false
		var viewport_size := get_viewport().get_visible_rect().size
		if screen_position.x > viewport_size.x * 0.65 and screen_position.y > viewport_size.y * 0.22 and screen_position.y < viewport_size.y * 0.84:
			if source.begins_with("move:"):
				_move_placed_block(int(source.trim_prefix("move:")), screen_position)
			elif source.begins_with("part:"):
				selected_part_id = source.trim_prefix("part:")
				selected_placement_index = -1
				_place_selected_block(screen_position)
		else:
			_update_shop_buttons()
	return did_drag


func _move_placed_block(index: int, screen_position: Vector2) -> void:
	if index < 0 or index >= part_placements.size():
		return
	var placement: Dictionary = part_placements[index]
	var part_id := str(placement.get("id", ""))
	var current_position: Vector3 = placement.get("position", Vector3.ZERO)
	placement_depth = current_position.z
	var target := _screen_to_ship_position(screen_position, placement_depth)
	var snapped := _snap_free_grid(target, part_id, float(placement.get("rotation", 0.0)), index)
	if snapped.x < -100.0:
		shop_status.text = "BLOCK OVERLAPS ANOTHER PART  •  TRY AN OPEN GRID CELL"
		_update_shop_buttons()
		return
	part_placements[index].position = Vector3(snapped.x, snapped.y, placement_depth)
	selected_placement_index = index
	_rebuild_ship_mesh()
	_save_profile()
	shop_status.text = "%s MOVED ON BUILD GRID" % str(PARTS.get(part_id, {}).get("title", part_id))
	_update_shop_buttons()


func _sync_equipped_parts() -> void:
	equipped_parts = ["core"]
	for placement in part_placements:
		var part_id := str(placement.get("id", ""))
		if PARTS.has(part_id) and not equipped_parts.has(part_id):
			equipped_parts.append(part_id)


func _rotate_next_block() -> void:
	if selected_placement_index >= 0 and selected_placement_index < part_placements.size():
		var old_rotation := float(part_placements[selected_placement_index].get("rotation", 0.0))
		var next_rotation := fposmod(old_rotation + PI * 0.5, TAU)
		var position: Vector3 = part_placements[selected_placement_index].get("position", Vector3.ZERO)
		placement_depth = position.z
		if _snap_free_grid(Vector2(position.x, position.y), str(part_placements[selected_placement_index].get("id", "")), next_rotation, selected_placement_index).x < -100.0:
			shop_status.text = "ROTATION WOULD OVERLAP ANOTHER BLOCK"
			return
		part_placements[selected_placement_index].rotation = next_rotation
		_rebuild_ship_mesh()
		_save_profile()
		shop_status.text = "SELECTED BLOCK ROTATED 90°"
	else:
		placement_rotation = fposmod(placement_rotation + PI * 0.5, TAU)
		shop_status.text = "NEXT BLOCK ROTATION  •  %d°" % int(round(rad_to_deg(placement_rotation)))
	_update_shop_buttons()


func _remove_selected_block() -> void:
	if part_placements.is_empty():
		return
	var remove_index := selected_placement_index if selected_placement_index >= 0 and selected_placement_index < part_placements.size() else part_placements.size() - 1
	var removed: Dictionary = part_placements[remove_index]
	part_placements.remove_at(remove_index)
	selected_placement_index = -1
	selected_part_id = str(removed.get("id", ""))
	_sync_equipped_parts()
	_rebuild_ship_mesh()
	_save_profile()
	shop_status.text = "%s REMOVED" % str(PARTS.get(selected_part_id, {}).get("title", selected_part_id))
	_update_shop_buttons()


func _adjust_block_depth(change: float) -> void:
	if selected_placement_index >= 0 and selected_placement_index < part_placements.size():
		var current: Vector3 = part_placements[selected_placement_index].get("position", Vector3.ZERO)
		var target_depth := clampf(round((current.z + change) / BUILD_GRID) * BUILD_GRID, -2.0, 2.0)
		placement_depth = target_depth
		if _snap_free_grid(Vector2(current.x, current.y), str(part_placements[selected_placement_index].get("id", "")), float(part_placements[selected_placement_index].get("rotation", 0.0)), selected_placement_index).x < -100.0:
			shop_status.text = "DEPTH CHANGE WOULD OVERLAP ANOTHER PART"
			return
		current.z = target_depth
		part_placements[selected_placement_index].position = current
		placement_depth = current.z
		_rebuild_ship_mesh()
		_save_profile()
		shop_status.text = "BLOCK DEPTH  •  %.1f" % current.z
	else:
		placement_depth = clampf(round((placement_depth + change) / BUILD_GRID) * BUILD_GRID, -2.0, 2.0)
		shop_status.text = "PLACEMENT DEPTH  •  %.1f" % placement_depth
	_update_shop_buttons()


func _clear_placed_blocks() -> void:
	part_placements.clear()
	selected_placement_index = -1
	_sync_equipped_parts()
	_rebuild_ship_mesh()
	_save_profile()
	shop_status.text = "BUILD CLEARED  •  START WITH THE CORE SHIP"
	_update_shop_buttons()


func _start_run() -> void:
	runs_started += 1
	rng.randomize()
	var rare_life_chance := 0.20
	secret_life_segment = rng.randi_range(3, 10) if rng.randf() < rare_life_chance else -1
	secret_life_claimed = false
	lives = 3
	distance = 0.0
	stage_distance = 0.0
	stage_index = 1
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
	_choose_background_view()
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
	camera.fov = 78.0
	player.visible = true
	build_grid_root.visible = false
	_rebuild_ship_mesh()
	while next_segment_distance < 190.0:
		_spawn_segment(-next_segment_distance)
		next_segment_distance += rng.randf_range(48.0, 74.0)
	state = ScreenState.RUN
	menu_panel.visible = false
	shop_panel.visible = false
	game_over_panel.visible = false
	stage_break_panel.visible = false
	stage_break_shade.visible = false
	hud.visible = true
	_update_hud()


func _finish_stage() -> void:
	state = ScreenState.STAGE_BREAK
	firing = false
	hud.visible = false
	menu_panel.visible = false
	shop_panel.visible = false
	game_over_panel.visible = false
	stage_break_panel.visible = true
	stage_break_shade.visible = true
	var multiplier := 1.0 + float(stage_index - 1) * STAGE_MULTIPLIER_STEP
	var next_multiplier := multiplier + STAGE_MULTIPLIER_STEP
	var payout := int(round(float(run_scrap) * multiplier))
	stage_break_summary.text = "STAGE %d COMPLETE\nUNBANKED HAUL  %d SCRAP\nCASH OUT NOW  %d SCRAP  •  x%.2f\nCONTINUE TO RAISE IT TO  x%.2f" % [stage_index, run_scrap, payout, multiplier, next_multiplier]
	var view_number := selected_background_index * BACKGROUND_ANGLES + selected_background_angle + 1
	stage_break_view_label.text = "SPACE VIEW  %02d / 30" % view_number


func _cash_out_run() -> void:
	if state != ScreenState.STAGE_BREAK:
		return
	var multiplier := 1.0 + float(stage_index - 1) * STAGE_MULTIPLIER_STEP
	last_cashout_payout = int(round(float(run_scrap) * multiplier))
	total_scrap += last_cashout_payout
	high_score = maxi(high_score, run_score)
	run_scrap = 0
	_save_profile()
	_show_hangar()


func _continue_run() -> void:
	if state != ScreenState.STAGE_BREAK:
		return
	stage_index += 1
	run_speed = minf(run_speed + 1.2, 43.0)
	stage_distance = 0.0
	next_segment_distance = 45.0
	steering_target = Vector2.ZERO
	player.position = Vector3.ZERO
	player.rotation = Vector3.ZERO
	player.visible = true
	build_grid_root.visible = false
	for item in course_objects:
		if is_instance_valid(item):
			item.queue_free()
	course_objects.clear()
	for shot in projectiles:
		if is_instance_valid(shot):
			shot.queue_free()
	projectiles.clear()
	course_root.position = Vector3.ZERO
	_choose_background_view()
	while next_segment_distance < 190.0:
		_spawn_segment(-next_segment_distance)
		next_segment_distance += rng.randf_range(48.0, 74.0)
	stage_break_panel.visible = false
	stage_break_shade.visible = false
	hud.visible = true
	state = ScreenState.RUN
	_update_hud()


func _process(delta: float) -> void:
	if state != ScreenState.RUN:
		if state == ScreenState.STAGE_BREAK:
			return
		if is_instance_valid(player):
			if state == ScreenState.BUILDER:
				player.rotation.y += delta * 0.24
				camera.position = camera.position.lerp(player.position + Vector3(1.2, 3.4, 10.0), minf(delta * 3.0, 1.0))
				camera.look_at(player.position + Vector3(-4.3, 0.0, 0.0), Vector3.UP)
			else:
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
	var flame_pulse := 0.76 + 0.34 * sin(Time.get_ticks_msec() * 0.022)
	for flame in engine_flames:
		if is_instance_valid(flame):
			flame.scale.z = flame_pulse * (1.65 if boost_time > 0.0 else 1.0)
	camera.fov = lerpf(camera.fov, 86.0 if boost_time > 0.0 else 78.0, delta * 4.0)
	camera_shake = move_toward(camera_shake, 0.0, delta * 12.0)
	distance += current_speed * delta
	stage_distance += current_speed * delta
	run_score += int(current_speed * delta * 4.0)
	course_root.position.z += current_speed * delta
	starfield_offset = fmod(starfield_offset + current_speed * delta * 0.12, 210.0)
	stars.position.z = starfield_offset - 100.0
	var target := Vector3(steering_target.x, steering_target.y, 0.0)
	var response := 17.0 if equipped_parts.has("wing_pack") or equipped_parts.has("fin_set") else 13.5
	var follow := 1.0 - exp(-response * delta)
	player.position.x = lerpf(player.position.x, target.x, follow)
	player.position.y = lerpf(player.position.y, target.y, follow)
	player.position.x = clampf(player.position.x, -14.5, 14.5)
	player.position.y = clampf(player.position.y, -8.5, 8.5)
	player.rotation.z = lerpf(player.rotation.z, clampf((target.x - player.position.x) * -0.12, -0.72, 0.72), delta * 7.0)
	player.rotation.x = lerpf(player.rotation.x, clampf((target.y - player.position.y) * 0.1, -0.36, 0.36), delta * 7.0)
	var camera_target := player.position + Vector3(0.0, 3.9, 11.5)
	if camera_shake > 0.0:
		camera_target += Vector3(randf_range(-camera_shake, camera_shake), randf_range(-camera_shake, camera_shake), 0.0)
	camera.position = camera.position.lerp(camera_target, minf(delta * 6.0, 1.0))
	camera.look_at(player.position + Vector3(0.0, 0.0, -16.0), Vector3.UP)
	if stage_distance >= STAGE_DISTANCE:
		_finish_stage()
		return

	while next_segment_distance < stage_distance + 190.0:
		_spawn_segment(-next_segment_distance)
		next_segment_distance += rng.randf_range(48.0, 76.0)
	for item in course_objects:
		if is_instance_valid(item):
			if item.is_in_group("pickups"):
				item.rotation.y += delta * 1.7
			elif item.is_in_group("hazards"):
				var spin: Vector3 = item.get_meta("spin", Vector3.ZERO)
				item.rotation += spin * delta
			if item.global_position.z > 18.0:
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
	_update_hud()


func _spawn_segment(z_position: float) -> void:
	segment_number += 1
	var rift_level := maxi(int(float(segment_number) / 4.0) + 1, stage_index)
	_spawn_asteroid_corridor(z_position)
	if segment_number % 3 == 1:
		_spawn_rift_frame(z_position + 3.0, rift_level)
	var pattern := rng.randi_range(0, 5)
	match pattern:
		0:
			_spawn_gate(z_position, rng.randi_range(0, 4))
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
				_spawn_pickup(Vector3(rng.randf_range(-11.0, 11.0), rng.randf_range(-6.5, 6.5), z_position - 12.0), "scrap")
	if segment_number == secret_life_segment and not secret_life_claimed:
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		_spawn_gate(z_position - 2.0, 1 if side < 0.0 else 2)
		_spawn_pickup(Vector3(side * rng.randf_range(10.0, 13.0), rng.randf_range(-6.5, 6.5), z_position - 2.0), "life")
		secret_life_claimed = true


func _spawn_rift_frame(z_position: float, level: int) -> void:
	var colors := [Color(0.18, 0.86, 1.0), Color(0.9, 0.29, 1.0), Color(1.0, 0.53, 0.2)]
	var tint: Color = colors[(level - 1) % colors.size()]
	var frame := Node3D.new()
	frame.position.z = z_position
	frame.set_meta("spin", Vector3(0.0, 0.0, 0.0))
	var glow_tint := tint.lightened(0.18)
	for side in [-1.0, 1.0]:
		frame.add_child(_make_block(Vector3(side * 18.8, 0.0, 0.0), Vector3(0.42, 20.5, 0.5), tint, true))
		frame.add_child(_make_block(Vector3(0.0, side * 10.0, 0.0), Vector3(38.0, 0.38, 0.5), glow_tint, true))
		frame.add_child(_make_block(Vector3(side * 18.2, side * 9.5, 0.0), Vector3(1.5, 0.28, 0.5), Color(0.95, 0.95, 1.0), true))
	course_root.add_child(frame)
	course_objects.append(frame)


func _spawn_asteroid_corridor(z_position: float) -> void:
	if asteroid_templates.is_empty():
		return
	for side in [-1.0, 1.0]:
		var count := rng.randi_range(3, 5)
		for i in range(count):
			var rock: Node3D = asteroid_templates[rng.randi_range(0, asteroid_templates.size() - 1)].duplicate()
			rock.position = Vector3(side * rng.randf_range(17.0, 24.0), rng.randf_range(-9.2, 9.2), z_position - rng.randf_range(0.0, 46.0))
			rock.rotation = Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.8, 0.8), rng.randf_range(-0.7, 0.7))
			var rock_scale := rng.randf_range(0.7, 1.35)
			rock.scale = Vector3.ONE * rock_scale
			course_root.add_child(rock)
			course_objects.append(rock)


func _spawn_gate(z_position: float, open_index: int) -> void:
	var slots := [
		Vector3(-12.0, 0.0, z_position),
		Vector3(-6.0, 0.0, z_position),
		Vector3(0.0, 0.0, z_position),
		Vector3(6.0, 0.0, z_position),
		Vector3(12.0, 0.0, z_position),
	]
	for i in range(slots.size()):
		if i == open_index:
			continue
		_spawn_hazard(slots[i], Vector3(3.1, 4.0, 2.7), Color(0.76, 0.19, 0.23))
	_spawn_hazard(Vector3(0.0, 9.7, z_position), Vector3(38.0, 1.2, 2.7), Color(0.32, 0.39, 0.56))
	_spawn_hazard(Vector3(0.0, -9.7, z_position), Vector3(38.0, 1.2, 2.7), Color(0.32, 0.39, 0.56))
	if rng.randf() < 0.45:
		_spawn_pickup(Vector3(slots[open_index].x, rng.randf_range(-1.0, 1.0), z_position - 1.0), "scrap")


func _spawn_debris(z_position: float, count: int) -> void:
	for i in range(count):
		var x := rng.randf_range(-13.5, 13.5)
		var y := rng.randf_range(-7.2, 7.2)
		if absf(x) < 2.0 and absf(y) < 1.5:
			x = 4.2 if x >= 0.0 else -4.2
		var dims := Vector3(rng.randf_range(1.4, 3.4), rng.randf_range(1.2, 3.2), rng.randf_range(1.8, 4.0))
		var hue_color: Color = [Color(0.17, 0.28, 0.39), Color(0.28, 0.39, 0.5), Color(0.24, 0.31, 0.45)][rng.randi_range(0, 2)]
		_spawn_rock_hazard(Vector3(x, y, z_position - rng.randf_range(0.0, 18.0)), dims, hue_color, Vector3(rng.randf_range(-0.45, 0.45), rng.randf_range(-0.45, 0.45), rng.randf_range(-0.45, 0.45)))


func _spawn_rock_hazard(at: Vector3, dimensions: Vector3, tint: Color, spin: Vector3) -> void:
	var rock := Area3D.new()
	rock.position = at
	rock.collision_layer = 8
	rock.collision_mask = 1
	rock.add_to_group("hazards")
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions * 0.82
	shape_node.shape = shape
	rock.add_child(shape_node)
	if not asteroid_templates.is_empty():
		var visual: Node3D = asteroid_templates[rng.randi_range(0, asteroid_templates.size() - 1)].duplicate()
		visual.scale = dimensions / Vector3(4.2, 3.6, 3.6)
		visual.rotation = Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.7, 0.7), rng.randf_range(-0.4, 0.4))
		rock.add_child(visual)
	else:
		rock.add_child(_make_block(Vector3.ZERO, dimensions * 0.72, tint))
	rock.body_entered.connect(_on_hazard_body_entered.bind(rock))
	rock.set_meta("spin", spin)
	course_root.add_child(rock)
	course_objects.append(rock)


func _spawn_salvage_line(z_position: float) -> void:
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	for i in range(5):
		var x := side * (2.0 + float(i) * 1.15)
		var y := sin(float(i) * 0.85) * 1.25
		_spawn_pickup(Vector3(x, y, z_position - float(i) * 7.0), "scrap")
	_spawn_debris(z_position - 21.0, 2)


func _spawn_alternating_wall(z_position: float, level: int) -> void:
	var safe_x := rng.randf_range(-10.5, 10.5)
	var count := 3 + mini(level, 2)
	for i in range(count):
		var x := rng.randf_range(-13.8, 13.8)
		while absf(x - safe_x) < 5.5:
			x = rng.randf_range(-13.8, 13.8)
		var y := rng.randf_range(-7.2, 7.2)
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
	var tint := Color(1.0, 0.82, 0.22) if kind == "scrap" else Color(0.35, 0.9, 1.0)
	var crystal := _make_block(Vector3.ZERO, Vector3(0.78, 0.98, 0.78) if kind == "life" else Vector3(0.72, 0.92, 0.72), tint, true)
	crystal.rotation_degrees = Vector3(0.0, 45.0, 45.0)
	pickup.add_child(crystal)
	pickup.body_entered.connect(_on_pickup_body_entered.bind(pickup))
	course_root.add_child(pickup)
	course_objects.append(pickup)


func _spawn_enemy(z_position: float) -> void:
	var enemy := Area3D.new()
	enemy.position = Vector3(rng.randf_range(-11.0, 11.0), rng.randf_range(-6.0, 6.0), z_position)
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
		camera_shake = 0.24
		run_score += 25
		return
	lives -= 1
	camera_shake = 0.65
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
		run_score += 50
	pickup.queue_free()
	_update_hud()


func _activate_boost() -> void:
	if state != ScreenState.RUN or boost_cooldown > 0.0:
		return
	boost_time = boost_duration
	camera_shake = maxf(camera_shake, 0.16)
	boost_speed = 17.0 if equipped_parts.has("boost_core") else 11.0
	boost_cooldown = 5.2
	invulnerability = maxf(invulnerability, 0.5)


func _end_run() -> void:
	state = ScreenState.GAME_OVER
	hud.visible = false
	menu_panel.visible = false
	shop_panel.visible = false
	game_over_panel.visible = true
	stage_break_panel.visible = false
	stage_break_shade.visible = false
	player.visible = true
	build_grid_root.visible = false
	high_score = maxi(high_score, run_score)
	equipped_parts = ["core"]
	part_placements.clear()
	selected_placement_index = -1
	_save_profile()
	var summary: Label = game_over_panel.get_meta("summary")
	summary.text = "SCORE  %d\nUNBANKED SALVAGE LOST  %d\nBEST FLIGHT  %d\nBANKED SCRAP  %d" % [run_score, run_scrap, high_score, total_scrap]
	_rebuild_ship_mesh()


func _update_hud() -> void:
	if not is_instance_valid(hud):
		return
	lives_label.text = "LIVES  %d" % lives
	score_label.text = "SCORE  %07d" % run_score
	scrap_label.text = "SCRAP  %d  (+%d)" % [total_scrap, run_scrap]
	var multiplier := 1.0 + float(stage_index - 1) * STAGE_MULTIPLIER_STEP
	difficulty_label.text = "STAGE %d  •  x%.2f" % [stage_index, multiplier]
	boost_button.disabled = boost_cooldown > 0.0
	boost_button.text = "BOOST" if boost_cooldown <= 0.0 else "CHARGING"
	boost_meter.value = clampf(1.0 - boost_cooldown / 5.2, 0.0, 1.0)
	_update_radar()


func _update_radar() -> void:
	if not is_instance_valid(radar_widget):
		return
	radar_widget.blips.clear()
	if state == ScreenState.RUN:
		for item in course_objects:
			if not is_instance_valid(item):
				continue
			var tint := Color(1.0, 0.35, 0.27)
			if item.is_in_group("pickups"):
				tint = Color(1.0, 0.84, 0.26)
			elif not item.is_in_group("hazards") and not item.is_in_group("enemies"):
				continue
			var z_distance := item.position.z + course_root.position.z - player.position.z
			if z_distance < -145.0 or z_distance > 8.0:
				continue
			var offset := Vector2((item.position.x - player.position.x) / 31.0, z_distance / 145.0)
			if offset.length() <= 1.25:
				radar_widget.blips.append({"offset": offset, "tint": tint})
	radar_widget.queue_redraw()


func _input(event: InputEvent) -> void:
	if state == ScreenState.BUILDER:
		var screen_width := get_viewport().get_visible_rect().size.x
		if event is InputEventScreenTouch:
			if event.pressed:
				builder_pointer_start = event.position
				builder_pointer_active = true
				builder_drag_source = _part_under_pointer(event.position)
				builder_dragging = false
			else:
				var did_drag := _finish_builder_drag(event.position)
				if builder_pointer_active and not did_drag and event.position.distance_to(builder_pointer_start) < 18.0 and event.position.x > screen_width * 0.65 and event.position.y > get_viewport().get_visible_rect().size.y * 0.22 and event.position.y < get_viewport().get_visible_rect().size.y * 0.84:
					_place_selected_block(event.position)
				builder_pointer_active = false
				builder_drag_source = ""
				builder_dragging = false
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				builder_pointer_start = event.position
				builder_pointer_active = true
				builder_drag_source = _part_under_pointer(event.position)
				builder_dragging = false
			else:
				var did_drag := _finish_builder_drag(event.position)
				if builder_pointer_active and not did_drag and event.position.distance_to(builder_pointer_start) < 8.0 and event.position.x > screen_width * 0.65 and event.position.y > get_viewport().get_visible_rect().size.y * 0.22 and event.position.y < get_viewport().get_visible_rect().size.y * 0.84:
					_place_selected_block(event.position)
				builder_pointer_active = false
				builder_drag_source = ""
				builder_dragging = false
		elif event is InputEventScreenDrag:
			_move_builder_drag(event.position)
			if builder_dragging:
				return
			if event.position.x > screen_width * 0.65:
				player.rotation.y += event.relative.x * 0.006
				player.rotation.x = clampf(player.rotation.x + event.relative.y * 0.004, -0.55, 0.55)
		elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_move_builder_drag(event.position)
			if builder_dragging:
				return
			if event.position.x > screen_width * 0.65:
				player.rotation.y += event.relative.x * 0.006
				player.rotation.x = clampf(player.rotation.x + event.relative.y * 0.004, -0.55, 0.55)
		return
	if state != ScreenState.RUN:
		return
	if event is InputEventScreenDrag:
		if steering_touch_index == event.index:
			_update_steering_from_delta(event.relative)
	elif event is InputEventScreenTouch:
		if event.pressed and event.position.x < get_viewport().get_visible_rect().size.x * 0.78:
			steering_touch_index = event.index
		elif not event.pressed and steering_touch_index == event.index:
			steering_touch_index = -1
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_update_steering_from_delta(event.relative)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			firing = true
		elif event.keycode == KEY_SHIFT:
			_activate_boost()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.pressed:
		if event.keycode == KEY_SPACE:
			firing = false


func _update_steering_from_delta(drag_delta: Vector2) -> void:
	var bounds := get_viewport().get_visible_rect().size
	steering_target.x = clampf(steering_target.x + drag_delta.x * 20.0 / bounds.x, -14.5, 14.5)
	steering_target.y = clampf(steering_target.y - drag_delta.y * 14.0 / bounds.y, -8.5, 8.5)


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
	var saved_placements = config.get_value("pilot", "part_placements", [])
	part_placements.clear()
	for placement in saved_placements:
		if placement is Dictionary and PARTS.has(str(placement.get("id", ""))) and part_placements.size() < MAX_PLACED_BLOCKS:
			part_placements.append({"id": str(placement.get("id", "")), "position": placement.get("position", Vector3.ZERO), "rotation": float(placement.get("rotation", 0.0))})
	if part_placements.is_empty():
		var legacy_positions := [Vector3(-1.0, 0.0, -0.1), Vector3(1.0, 0.0, -0.1), Vector3(0.0, 0.9, -0.1)]
		var slot := 0
		for part_id in equipped_parts:
			if part_id == "core" or slot >= legacy_positions.size():
				continue
			part_placements.append({"id": part_id, "position": legacy_positions[slot], "rotation": 0.0})
			slot += 1
	_sync_equipped_parts()


func _save_profile() -> void:
	var config := ConfigFile.new()
	config.set_value("pilot", "scrap", total_scrap)
	config.set_value("pilot", "high_score", high_score)
	config.set_value("pilot", "runs_started", runs_started)
	config.set_value("pilot", "owned_parts", owned_parts)
	config.set_value("pilot", "equipped_parts", equipped_parts)
	config.set_value("pilot", "part_placements", part_placements)
	config.save(PROFILE_PATH)

