@tool
class_name PaletteLightingProfile
extends Resource
## a portable atlas or authored gradient pair for orientation-based lighting.

const ATLAS_WIDTH: int = 256
const ATLAS_HEIGHT: int = 16

@export var display_name: String = "Custom":
	set(value):
		display_name = value
		emit_changed()
## atlases use alternating diffuse/additive rows for eight independent slots.
@export var atlas: Texture2D:
	set(value):
		atlas = value
		emit_changed()
## points toward the light, rather than along its emitted rays.
@export var direction_toward_light: Vector3 = Vector3(-0.4, 0.8, 0.4):
	set(value):
		direction_toward_light = value
		emit_changed()
@export_group("Authored Gradients")
## when enabled, one authored pair fills all slots of the generated atlas.
@export var is_using_gradients: bool = false:
	set(value):
		is_using_gradients = value
		emit_changed()
@export var diffuse_gradient: Gradient:
	set(value):
		if diffuse_gradient != additive_gradient:
			_disconnect_gradient(diffuse_gradient)
		diffuse_gradient = value
		_connect_gradient(diffuse_gradient)
		emit_changed()
@export var additive_gradient: Gradient:
	set(value):
		if additive_gradient != diffuse_gradient:
			_disconnect_gradient(additive_gradient)
		additive_gradient = value
		_connect_gradient(additive_gradient)
		emit_changed()


## builds a lossless atlas from the currently authored color stops.
func bake_gradient_atlas() -> ImageTexture:
	var image: Image = Image.create(ATLAS_WIDTH, ATLAS_HEIGHT, false, Image.FORMAT_RGB8)
	for index: int in range(ATLAS_WIDTH):
		var offset: float = float(index) / float(ATLAS_WIDTH - 1)
		var diffuse: Color = Color.WHITE
		var additive: Color = Color.BLACK
		if diffuse_gradient != null:
			diffuse = diffuse_gradient.sample(offset)
		if additive_gradient != null:
			additive = additive_gradient.sample(offset)
		for slot: int in range(8):
			image.set_pixel(index, slot * 2, diffuse)
			image.set_pixel(index, slot * 2 + 1, additive)
	return ImageTexture.create_from_image(image)


## rejects incompatible images before an atlas reaches the shader.
func is_atlas_valid() -> bool:
	return atlas != null and atlas.get_width() == ATLAS_WIDTH and atlas.get_height() == ATLAS_HEIGHT


func _connect_gradient(gradient: Gradient) -> void:
	if gradient != null and not gradient.changed.is_connected(_on_gradient_changed):
		gradient.changed.connect(_on_gradient_changed)


func _disconnect_gradient(gradient: Gradient) -> void:
	if gradient != null and gradient.changed.is_connected(_on_gradient_changed):
		gradient.changed.disconnect(_on_gradient_changed)


func _on_gradient_changed() -> void:
	emit_changed()
