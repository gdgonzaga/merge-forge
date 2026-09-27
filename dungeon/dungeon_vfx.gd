# Dungeon VFX helper – overlay for visual effects
extends Control

# This node is instantiated as `AnimOverlay` in `dungeon_run.tscn`.
# It provides lightweight helpers for spawning temporary VFX such as floating text,
# slash sprites, impact bursts, heal/buff sparkles, and screen shake.
# All effects are short‑lived (0.2‑0.4 s) and free themselves when finished.

func _to_local(global_pos: Vector2) -> Vector2:
	return global_pos - global_position


# -----------------------------------------------------------------------------
# Floating combat text
func spawn_floating_text(global_pos: Vector2, text: String, color: Color, is_crit: bool = false) -> void:
	var lbl := Label.new()
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.text = text
	lbl.modulate = color
	lbl.add_theme_font_override("font", load("res://resources/fonts/RobotoCondensed-VariableFont_wght.ttf"))
	lbl.add_theme_font_size_override("font_size", 36 if is_crit else 28)
	lbl.position = _to_local(global_pos) - Vector2(30, 15)
	add_child(lbl)
	var tween := create_tween()
	tween.tween_property(lbl, "position:y", lbl.position.y - 40, 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.4).set_ease(Tween.EASE_IN)
	tween.finished.connect(lbl.queue_free)


# Slash VFX
func spawn_slash(global_pos: Vector2, direction: Vector2) -> void:
	var sprite := TextureRect.new()
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.texture = load("res://resources/sprites/vfx/slash.png")
	var tex_size := sprite.texture.get_size() if sprite.texture else Vector2(32, 32)
	sprite.pivot_offset = tex_size * 0.5
	sprite.position = _to_local(global_pos) - tex_size * 0.5
	sprite.rotation = direction.angle()
	sprite.scale = Vector2.ONE * 1.0
	add_child(sprite)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_IN)
	tween.finished.connect(sprite.queue_free)


# Impact burst
func spawn_impact(global_pos: Vector2, is_crit: bool) -> void:
	var sprite := TextureRect.new()
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.texture = load("res://resources/sprites/vfx/hit_impact.png")
	var tex_size := sprite.texture.get_size() if sprite.texture else Vector2(32, 32)
	sprite.pivot_offset = tex_size * 0.5
	sprite.position = _to_local(global_pos) - tex_size * 0.5
	sprite.scale = Vector2.ONE * (1.6 if is_crit else 1.0)
	add_child(sprite)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
	tween.finished.connect(sprite.queue_free)


# Heal sparkle
func spawn_heal_fx(global_pos: Vector2) -> void:
	var sprite := TextureRect.new()
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.texture = load("res://resources/sprites/vfx/heal_sparkle.png")
	var tex_size := sprite.texture.get_size() if sprite.texture else Vector2(32, 32)
	sprite.pivot_offset = tex_size * 0.5
	sprite.position = _to_local(global_pos) - tex_size * 0.5
	sprite.scale = Vector2.ONE * 0.8
	add_child(sprite)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.35).set_ease(Tween.EASE_IN)
	tween.finished.connect(sprite.queue_free)


# Buff aura
func spawn_buff_fx(global_pos: Vector2) -> void:
	var sprite := TextureRect.new()
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.texture = load("res://resources/sprites/vfx/buff_aura.png")
	var tex_size := sprite.texture.get_size() if sprite.texture else Vector2(48, 48)
	sprite.pivot_offset = tex_size * 0.5
	sprite.position = _to_local(global_pos) - tex_size * 0.5
	sprite.scale = Vector2.ONE * 1.0
	add_child(sprite)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.4).set_ease(Tween.EASE_IN)
	tween.finished.connect(sprite.queue_free)


# Death poof
func spawn_death_poof(global_pos: Vector2) -> void:
	var sprite := TextureRect.new()
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.texture = load("res://resources/sprites/vfx/death_poof.png")
	var tex_size := sprite.texture.get_size() if sprite.texture else Vector2(48, 48)
	sprite.pivot_offset = tex_size * 0.5
	sprite.position = _to_local(global_pos) - tex_size * 0.5
	sprite.scale = Vector2.ONE * 1.0
	add_child(sprite)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.4).set_ease(Tween.EASE_IN)
	tween.finished.connect(sprite.queue_free)


# Simple screen shake – moves the root node a little and restores it.
func screen_shake(intensity: float = 5.0, duration: float = 0.2) -> void:
	var original := position
	var tween := create_tween()
	tween.tween_property(self, "position", original + Vector2(randf() * intensity - intensity * 0.5, randf() * intensity - intensity * 0.5), duration * 0.5)
	tween.tween_property(self, "position", original, duration * 0.5)
	tween.finished.connect(func(): position = original)
