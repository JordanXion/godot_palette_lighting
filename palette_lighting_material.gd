@tool
class_name PaletteLightingMaterial
extends ShaderMaterial
## material-local controls; a PaletteLightingEnvironment supplies the shared profile.

enum DebugView { COMBINED, DIFFUSE, ADDITIVE, ORIENTATION }

const LIGHTING_SHADER: Shader = preload("res://addons/palette_lighting/palette_lighting.gdshader")

@export var base_texture: Texture2D:
	set(value):
		base_texture = value
		set_shader_parameter("base_texture", value)
@export var base_tint: Color = Color.WHITE:
	set(value):
		base_tint = value
		set_shader_parameter("base_tint", value)
@export_range(0, 7, 1) var diffuse_slot: int = 0:
	set(value):
		diffuse_slot = clampi(value, 0, 7)
		set_shader_parameter("palette_diffuse_slot", diffuse_slot)
@export_range(0, 7, 1) var additive_slot: int = 0:
	set(value):
		additive_slot = clampi(value, 0, 7)
		set_shader_parameter("palette_additive_slot", additive_slot)
@export var is_vertex_color_enabled: bool = false:
	set(value):
		is_vertex_color_enabled = value
		set_shader_parameter("is_vertex_color_enabled", value)
@export var is_per_vertex: bool = true:
	set(value):
		is_per_vertex = value
		set_shader_parameter("is_per_vertex", value)
@export var is_additive_enabled: bool = true:
	set(value):
		is_additive_enabled = value
		set_shader_parameter("palette_is_additive_enabled", value)
@export_range(0.0, 2.0, 0.01) var additive_strength: float = 1.0:
	set(value):
		additive_strength = value
		set_shader_parameter("palette_additive_strength", value)
## encoded RGB arithmetic is converted to the renderer's expected output space.
@export var is_using_encoded_color: bool = true:
	set(value):
		is_using_encoded_color = value
		set_shader_parameter("palette_is_encoded", value)
@export var debug_view: DebugView = DebugView.COMBINED:
	set(value):
		debug_view = value
		set_shader_parameter("debug_view", value)
@export_group("Shadows")
## needs one shadow-casting DirectionalLight3D; other light types are ignored.
@export var is_shadow_receiving_enabled: bool = false:
	set(value):
		is_shadow_receiving_enabled = value
		set_shader_parameter("is_shadow_receiving_enabled", value)
## controls how much palette illumination is removed in a full cast shadow.
@export_range(0.0, 1.0, 0.01) var shadow_strength: float = 0.7:
	set(value):
		shadow_strength = value
		set_shader_parameter("shadow_strength", value)
@export_group("Cutout")
@export var is_alpha_cutout_enabled: bool = false:
	set(value):
		is_alpha_cutout_enabled = value
		set_shader_parameter("is_alpha_cutout_enabled", value)
@export_range(0.0, 1.0, 0.01) var alpha_cutoff: float = 0.5:
	set(value):
		alpha_cutoff = value
		set_shader_parameter("alpha_cutoff", value)


func _init() -> void:
	shader = LIGHTING_SHADER
