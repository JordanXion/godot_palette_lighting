class_name PaletteLightingShowcase
extends Node3D
## an isolated comparison scene with no dependencies on gameplay or input actions.

enum LightingMode { PALETTE, SKY }

const PROFILES: Array[PaletteLightingProfile] = [
	preload("res://addons/palette_lighting/profiles/daylight.tres"),
	preload("res://addons/palette_lighting/profiles/heated_interior.tres"),
	preload("res://addons/palette_lighting/profiles/golden_evening.tres"),
	preload("res://addons/palette_lighting/profiles/cool_night.tres"),
	preload("res://addons/palette_lighting/profiles/woodland_day.tres"),
	preload("res://addons/palette_lighting/profiles/amber_twilight.tres"),
	preload("res://addons/palette_lighting/profiles/violet_night.tres"),
	preload("res://addons/palette_lighting/profiles/bright_overcast.tres"),
	preload("res://addons/palette_lighting/profiles/dark_overcast.tres"),
	preload("res://addons/palette_lighting/profiles/firelight.tres"),
	preload("res://addons/palette_lighting/profiles/authored_example.tres"),
]

var _controls: VBoxContainer = null
var _blend_slider: HSlider = null
var _status: Label = null
var _is_pulsing: bool = false
var _pulse_time: float = 0.0
var _light_yaw_degrees: float = -35.0
var _light_elevation_degrees: float = 40.0
var _materials: Array[PaletteLightingMaterial] = []
var _meshes: Array[MeshInstance3D] = []
var _normal_materials: Dictionary[PaletteLightingMaterial, StandardMaterial3D] = {}
var _palette_materials: Dictionary[MeshInstance3D, PaletteLightingMaterial] = {}
var _palette_environment: Environment = null
var _sky_environment: Environment = null
var _lighting_mode: LightingMode = LightingMode.PALETTE
var _is_shadows_enabled: bool = true
var _shadow_strength: float = 0.7
var _palette_controls: Array[Control] = []
var _debug_picker: OptionButton = null

var _lighting: PaletteLightingEnvironment = null
var _camera_rig: Node3D = null
var _camera: Camera3D = null
var _control_layer: CanvasLayer = null
var _light_marker: MeshInstance3D = null
var _world_environment: WorldEnvironment = null
var _sun: DirectionalLight3D = null


func _ready() -> void:
	_lighting = %LightingController
	_camera_rig = %CameraRig
	_camera = %Camera3D
	_control_layer = %ControlLayer
	_light_marker = %LightMarker
	_world_environment = %WorldEnvironment
	_sun = %Sun
	for material: ShaderMaterial in _lighting.materials:
		var lighting_material: PaletteLightingMaterial = material as PaletteLightingMaterial
		if lighting_material != null:
			_materials.append(lighting_material)
	_prepare_normal_lighting()
	_build_controls()
	_update_light_direction()
	_apply_lighting_mode()
	_update_status()


func _process(delta: float) -> void:
	if _is_pulsing and _lighting_mode == LightingMode.PALETTE:
		_pulse_time += delta
		_blend_slider.value = (sin(_pulse_time * 1.5) + 1.0) * 0.5


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if motion.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			_camera_rig.rotation.y -= motion.relative.x * 0.005
			_camera_rig.rotation.x = clampf(
				_camera_rig.rotation.x - motion.relative.y * 0.005, -1.2, 0.3
			)
	elif event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera.position.z = maxf(5.0, _camera.position.z - 0.5)
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera.position.z = minf(20.0, _camera.position.z + 0.5)


func _build_controls() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "ControlPanel"
	panel.position = Vector2(20.0, 20.0)
	panel.custom_minimum_size.x = 350.0
	_control_layer.add_child(panel)
	var padding: MarginContainer = MarginContainer.new()
	padding.name = "PanelPadding"
	for side: String in ["left", "right", "top", "bottom"]:
		padding.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(padding)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "ControlScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var panel_height: float = get_viewport().get_visible_rect().size.y - 80.0
	scroll.custom_minimum_size.y = clampf(panel_height, 240.0, 780.0)
	padding.add_child(scroll)
	_controls = VBoxContainer.new()
	_controls.name = "Controls"
	_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_controls.add_theme_constant_override("separation", 8)
	scroll.add_child(_controls)
	var title: Label = _add_label("Palette Lighting", "Title")
	title.add_theme_font_size_override("font_size", 24)
	var mode_picker: OptionButton = OptionButton.new()
	mode_picker.name = "LightingMode"
	mode_picker.add_item("Palette lighting")
	mode_picker.add_item("Godot sky + sun")
	mode_picker.item_selected.connect(_on_lighting_mode_item_selected)
	_controls.add_child(mode_picker)
	_add_toggle("Shadows", "Enable cast shadows", true, _on_shadows_toggled)
	_add_slider("ShadowStrength", 0.0, 1.0, 0.7, _on_shadow_strength_value_changed)
	_add_label("Source profile", "SourceLabel")
	_add_profile_picker("SourceProfile", 0, _on_source_profile_item_selected)
	_add_label("Target profile", "TargetLabel")
	_add_profile_picker("TargetProfile", 1, _on_target_profile_item_selected)
	_blend_slider = _add_slider("Blend", 0.0, 1.0, 0.0, _on_blend_value_changed)
	_palette_controls.append(_blend_slider)
	_add_slider("LightYaw", -180.0, 180.0, _light_yaw_degrees, _on_light_yaw_value_changed)
	_add_slider(
		"LightElevation", -85.0, 85.0, _light_elevation_degrees,
		_on_light_elevation_value_changed
	)
	_add_toggle("VertexSampling", "Sample lighting per vertex", true, _on_vertex_sampling_toggled)
	_add_toggle("EncodedColor", "Use encoded RGB arithmetic", true, _on_encoded_color_toggled)
	_add_toggle("AdditiveLighting", "Enable additive lighting", true, _on_additive_lighting_toggled)
	_add_toggle(
		"AlternateRamp", "Use alternate additive slots (1 / 3)", false,
		_on_alternate_ramp_toggled
	)
	_add_toggle("PulseBlend", "Animate profile blend", false, _on_pulse_blend_toggled)
	_debug_picker = OptionButton.new()
	_debug_picker.name = "DebugView"
	for text: String in ["Combined", "Diffuse ramp", "Additive ramp", "Orientation"]:
		_debug_picker.add_item(text)
	_debug_picker.item_selected.connect(_on_debug_view_item_selected)
	_controls.add_child(_debug_picker)
	_palette_controls.append(_debug_picker)
	_status = _add_label("", "Status")
	_status.add_theme_font_size_override("font_size", 14)
	var hint: Label = _add_label(
		"Right-drag outside this panel to orbit.\nScroll to zoom. White marker points toward light.",
		"OrbitHint"
	)
	hint.add_theme_font_size_override("font_size", 13)


func _add_label(text: String, node_name: String) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.text = text
	_controls.add_child(label)
	return label


func _add_profile_picker(node_name: String, selected: int, handler: Callable) -> void:
	var picker: OptionButton = OptionButton.new()
	picker.name = node_name
	for lighting_profile: PaletteLightingProfile in PROFILES:
		picker.add_item(lighting_profile.display_name)
	picker.select(selected)
	picker.item_selected.connect(handler)
	_controls.add_child(picker)
	_palette_controls.append(picker)


func _add_slider(
	node_name: String, minimum: float, maximum: float, initial: float, handler: Callable
) -> HSlider:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = node_name + "Row"
	_controls.add_child(row)
	var label: Label = Label.new()
	label.name = node_name + "Label"
	label.text = "Light yaw" if node_name == "LightYaw" else "Light elevation"
	if node_name == "Blend":
		label.text = "Blend"
	elif node_name == "ShadowStrength":
		label.text = "Shadow depth"
	label.custom_minimum_size.x = 105.0
	row.add_child(label)
	var slider: HSlider = HSlider.new()
	slider.name = node_name
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 0.01 if maximum <= 1.0 else 1.0
	slider.value = initial
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 190.0
	slider.value_changed.connect(handler)
	row.add_child(slider)
	return slider


func _add_toggle(node_name: String, text: String, initial: bool, handler: Callable) -> void:
	var toggle: CheckButton = CheckButton.new()
	toggle.name = node_name
	toggle.text = text
	toggle.button_pressed = initial
	toggle.toggled.connect(handler)
	_controls.add_child(toggle)
	if node_name != "Shadows":
		_palette_controls.append(toggle)


func _update_light_direction() -> void:
	var yaw: float = deg_to_rad(_light_yaw_degrees)
	var elevation: float = deg_to_rad(_light_elevation_degrees)
	var direction: Vector3 = Vector3(
		sin(yaw) * cos(elevation), sin(elevation), cos(yaw) * cos(elevation)
	)
	_lighting.direction_toward_light = direction
	_light_marker.position = Vector3(0.0, 1.0, 0.0) + direction * 3.8
	# a light emits along local -Z, opposite to the palette's toward-source vector.
	_sun.look_at(_sun.global_position - direction, Vector3.UP)


func _update_status() -> void:
	if _status == null:
		return
	var mode_name: String = "Palette" if _lighting_mode == LightingMode.PALETTE else "Godot sky"
	_status.text = "%s | blend: %.2f | shadow depth: %.2f\nYaw: %.0f° | elevation: %.0f°" % [
		mode_name, _lighting.blend_factor, _shadow_strength,
		_light_yaw_degrees, _light_elevation_degrees
	]


func _prepare_normal_lighting() -> void:
	_palette_environment = _world_environment.environment
	_sky_environment = Environment.new()
	_sky_environment.background_mode = Environment.BG_SKY
	_sky_environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_sky_environment.ambient_light_energy = 0.45
	_sky_environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	var sky: Sky = Sky.new()
	sky.sky_material = sky_material
	_sky_environment.sky = sky
	for node: Node in find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		var palette_material: PaletteLightingMaterial = (
			mesh.material_override as PaletteLightingMaterial
		)
		if palette_material == null:
			continue
		_meshes.append(mesh)
		_palette_materials[mesh] = palette_material
		if not _normal_materials.has(palette_material):
			var normal_material: StandardMaterial3D = StandardMaterial3D.new()
			normal_material.albedo_texture = palette_material.base_texture
			normal_material.albedo_color = palette_material.base_tint
			normal_material.roughness = 0.8
			_normal_materials[palette_material] = normal_material


func _apply_lighting_mode() -> void:
	var is_palette_mode: bool = _lighting_mode == LightingMode.PALETTE
	_world_environment.environment = _palette_environment if is_palette_mode else _sky_environment
	for mesh: MeshInstance3D in _meshes:
		var palette_material: PaletteLightingMaterial = _palette_materials[mesh]
		mesh.material_override = (
			palette_material if is_palette_mode else _normal_materials[palette_material]
		)
	for control: Control in _palette_controls:
		if control is BaseButton:
			(control as BaseButton).disabled = not is_palette_mode
		elif control is Slider:
			(control as Slider).editable = is_palette_mode and not _is_pulsing
	_apply_shadow_settings()
	_update_status()


func _apply_shadow_settings() -> void:
	_sun.shadow_enabled = _is_shadows_enabled
	for material: PaletteLightingMaterial in _materials:
		material.is_shadow_receiving_enabled = _is_shadows_enabled
		# the material controls palette shadow depth; the light controls standard shadow depth.
		material.shadow_strength = _shadow_strength
	_sun.shadow_opacity = 1.0 if _lighting_mode == LightingMode.PALETTE else _shadow_strength


func _on_lighting_mode_item_selected(index: int) -> void:
	_lighting_mode = LightingMode.PALETTE if index == 0 else LightingMode.SKY
	_apply_lighting_mode()


func _on_shadows_toggled(is_enabled: bool) -> void:
	_is_shadows_enabled = is_enabled
	_apply_shadow_settings()


func _on_shadow_strength_value_changed(value: float) -> void:
	_shadow_strength = value
	_apply_shadow_settings()
	_update_status()


func _on_source_profile_item_selected(index: int) -> void:
	_lighting.profile = PROFILES[index]


func _on_target_profile_item_selected(index: int) -> void:
	_lighting.blend_profile = PROFILES[index]


func _on_blend_value_changed(value: float) -> void:
	_lighting.blend_factor = value
	_update_status()


func _on_light_yaw_value_changed(value: float) -> void:
	_light_yaw_degrees = value
	_update_light_direction()
	_update_status()


func _on_light_elevation_value_changed(value: float) -> void:
	_light_elevation_degrees = value
	_update_light_direction()
	_update_status()


func _on_vertex_sampling_toggled(is_enabled: bool) -> void:
	for material: PaletteLightingMaterial in _materials:
		material.is_per_vertex = is_enabled


func _on_encoded_color_toggled(is_enabled: bool) -> void:
	for material: PaletteLightingMaterial in _materials:
		material.is_using_encoded_color = is_enabled


func _on_additive_lighting_toggled(is_enabled: bool) -> void:
	for material: PaletteLightingMaterial in _materials:
		material.is_additive_enabled = is_enabled


func _on_alternate_ramp_toggled(is_enabled: bool) -> void:
	for material: PaletteLightingMaterial in _materials:
		material.additive_slot = material.diffuse_slot + (1 if is_enabled else 0)


func _on_pulse_blend_toggled(is_enabled: bool) -> void:
	_is_pulsing = is_enabled
	_blend_slider.editable = not is_enabled


func _on_debug_view_item_selected(index: int) -> void:
	for material: PaletteLightingMaterial in _materials:
		match index:
			0:
				material.debug_view = PaletteLightingMaterial.DebugView.COMBINED
			1:
				material.debug_view = PaletteLightingMaterial.DebugView.DIFFUSE
			2:
				material.debug_view = PaletteLightingMaterial.DebugView.ADDITIVE
			3:
				material.debug_view = PaletteLightingMaterial.DebugView.ORIENTATION
