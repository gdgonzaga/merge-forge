extends Control

# Item quality as stars: one for Fine, two for Masterwork, none for Normal.
# The number of stars carries the meaning (never color alone), and the dark
# outline keeps them readable on any sprite. Drawn in code: there is no star
# art, and the game font may lack a star glyph.

const STAR_SIZE := 36.0
const FILL := Color(1.0, 0.84, 0.2)
const OUTLINE := Color(0.15, 0.1, 0.0)
const OUTLINE_WIDTH := 3.0

var quality: int = 0


func set_quality(value: int) -> void:
	quality = value
	visible = value > 0
	custom_minimum_size = Vector2(STAR_SIZE * value, STAR_SIZE)
	queue_redraw()


func _draw() -> void:
	for i in range(quality):
		var points := _star_points(Vector2(STAR_SIZE * (i + 0.5), STAR_SIZE * 0.5), STAR_SIZE * 0.5, STAR_SIZE * 0.22)
		draw_colored_polygon(points, FILL)
		var outline := points.duplicate()
		outline.append(points[0])
		draw_polyline(outline, OUTLINE, OUTLINE_WIDTH, true)


static func _star_points(center: Vector2, outer: float, inner: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for k in range(10):
		var radius := outer if k % 2 == 0 else inner
		var angle := -PI / 2.0 + k * PI / 5.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points
