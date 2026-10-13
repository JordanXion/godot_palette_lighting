@tool
class_name PaletteLightingEnvironment
extends Node3D
## binds shared lighting to explicit materials without autoloads or project settings.

@export var profile: PaletteLightingProfile:
	set(value):
		if profile != blend_profile:
			_disconnect_profile(profile)
		profile = value
		_connect_profile(profile)
		_refresh_if_ready()
@export var blend_profile: PaletteLightingProfile:
	set(value):
		if blend_profile != profile:
			_disconnect_profile(blend_profile)
		blend_profile = value
		_connect_profile(blend_profile)
		_refresh_if_ready()
@export_range(0.0, 1.0, 0.01) var blend_factor: float = 0.0:
	set(value):
		blend_factor = clampf(value, 0.0, 1.0)
		_apply_direction_and_blend()
@export var materials: Array[ShaderMaterial] = []:
	set(value):
		materials = value
		_refresh_if_ready()
@export_group("Direction Override")
@export var is_direction_overridden: bool = false:
	set(value):
		is_direction_overridden = value
		_apply_direction_and_blend()
@export var direction_toward_light: Vector3 = Vector3(-0.4, 0.8, 0.4):
	set(value):
		direction_toward_light = value
		_apply_direction_and_blend()

var _atlas_a: Texture2D = null
var _atlas_b: Texture2D = null


func _ready() -> void:
	refresh()


## materials shared by multiple meshes need only one registration.
func register_material(material: ShaderMaterial) -> void:
	if material == null or materials.has(material):
		return
	materials.append(material)
	if is_node_ready():
		_bind_material(material)


## removes a material from subsequent updates while retaining its last parameters.
func unregister_material(material: ShaderMaterial) -> void:
	materials.erase(material)


## rebuilds authored atlases only when profiles change, not during blend animation.
func refresh() -> void:
	_atlas_a = _resolve_atlas(profile)
	_atlas_b = _resolve_atlas(blend_profile) if blend_profile != null else _atlas_a
	for material: ShaderMaterial in materials:
		if material != null:
			_bind_material(material)


func _resolve_atlas(lighting_profile: PaletteLightingProfile) -> Texture2D:
	if lighting_profile == null:
		return _create_neutral_atlas()
	if lighting_profile.is_using_gradients:
		return lighting_profile.bake_gradient_atlas()
	if lighting_profile.is_atlas_valid():
		return lighting_profile.atlas
	push_warning("Palette lighting needs a 256 x 16 atlas; using a neutral fallback.")
	return _create_neutral_atlas()


func _create_neutral_atlas() -> ImageTexture:
	var neutral: PaletteLightingProfile = PaletteLightingProfile.new()
	return neutral.bake_gradient_atlas()


func _bind_material(material: ShaderMaterial) -> void:
	material.set_shader_parameter("palette_atlas_a", _atlas_a)
	material.set_shader_parameter("palette_atlas_b", _atlas_b)
	material.set_shader_parameter("palette_direction", _get_direction())
	material.set_shader_parameter("palette_blend", blend_factor)


func _apply_direction_and_blend() -> void:
	if not is_node_ready():
		return
	var direction: Vector3 = _get_direction()
	for material: ShaderMaterial in materials:
		if material != null:
			material.set_shader_parameter("palette_direction", direction)
			material.set_shader_parameter("palette_blend", blend_factor)


func _get_direction() -> Vector3:
	var direction: Vector3 = direction_toward_light
	if not is_direction_overridden and profile != null:
		direction = profile.direction_toward_light
		if blend_profile != null:
			direction = direction.lerp(blend_profile.direction_toward_light, blend_factor)
	# opposite directions can cancel during a transition; keep the shader input finite.
	return direction.normalized() if not direction.is_zero_approx() else Vector3.UP


func _refresh_if_ready() -> void:
	if is_node_ready():
		refresh()


func _connect_profile(lighting_profile: PaletteLightingProfile) -> void:
	if lighting_profile != null and not lighting_profile.changed.is_connected(_on_profile_changed):
		lighting_profile.changed.connect(_on_profile_changed)


func _disconnect_profile(lighting_profile: PaletteLightingProfile) -> void:
	if lighting_profile != null and lighting_profile.changed.is_connected(_on_profile_changed):
		lighting_profile.changed.disconnect(_on_profile_changed)


func _on_profile_changed() -> void:
	_refresh_if_ready()
