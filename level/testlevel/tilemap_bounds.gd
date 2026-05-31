extends TileMapLayer

@export var left_padding: float = 0.0
@export var right_padding: float = 0.0


func _ready() -> void:
	update_tilemap_bounds()


func update_tilemap_bounds() -> void:
	var used_rect: Rect2i = get_used_rect()

	if used_rect.size == Vector2i.ZERO:
		push_warning("TileMapLayer chưa có tile nào.")
		return

	var tile_size: Vector2 = Vector2(tile_set.tile_size)

	var local_min: Vector2 = Vector2(used_rect.position) * tile_size
	var local_max: Vector2 = Vector2(used_rect.position + used_rect.size) * tile_size

	var global_min: Vector2 = to_global(local_min)
	var global_max: Vector2 = to_global(local_max)

	global_min.x += left_padding
	global_max.x -= right_padding

	LevelManager.change_tilemap_bounds([
		global_min,
		global_max
	])

	print("TileMap bounds LEFT: ", global_min.x)
	print("TileMap bounds RIGHT: ", global_max.x)
