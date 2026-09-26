extends TestBase

# The pure maths behind the heavy-attack telegraph: the windup countdown that
# drives the line's fill, the HP ghost span, and the line width steps.

const ENGINE := preload("res://dungeon/combat_engine.gd")
const HP_GHOST := preload("res://dungeon/hp_ghost.gd")
const OVERLAY := preload("res://dungeon/telegraph_overlay.gd")


func test_windup_progress_across_a_two_tick_windup() -> void:
	# Windup starts: heavy_in 2, the timer just restarted.
	assert_float(ENGINE.windup_progress(2, 2, 1.0, 1.0)).is_equal_approx(0.0, 0.001)
	assert_float(ENGINE.windup_progress(2, 2, 0.5, 1.0)).is_equal_approx(0.25, 0.001)
	assert_float(ENGINE.windup_progress(1, 2, 1.0, 1.0)).is_equal_approx(0.5, 0.001)
	# Just before the landing tick.
	assert_float(ENGINE.windup_progress(1, 2, 0.0, 1.0)).is_equal_approx(1.0, 0.001)


func test_windup_progress_scales_with_windup_and_tick_length() -> void:
	# Remaining 1 * 2.0 + 0.8 = 2.8 of 3 * 2.0 = 6.0 -> 1 - 2.8 / 6.0.
	assert_float(ENGINE.windup_progress(2, 3, 0.8, 2.0)).is_equal_approx(0.5333, 0.001)


func test_windup_progress_is_clamped() -> void:
	assert_float(ENGINE.windup_progress(3, 2, 1.0, 1.0)).is_equal(0.0)
	assert_float(ENGINE.windup_progress(0, 2, 0.0, 1.0)).is_equal(1.0)


func test_ghost_span_marks_the_chunk_the_hit_takes() -> void:
	assert_vector(HP_GHOST.ghost_span(90, 120, 30)).is_equal_approx(Vector2(0.5, 0.75), Vector2(0.001, 0.001))
	assert_vector(HP_GHOST.ghost_span(40, 50, 25)).is_equal_approx(Vector2(0.3, 0.8), Vector2(0.001, 0.001))


func test_ghost_span_covers_the_whole_bar_when_lethal() -> void:
	assert_vector(HP_GHOST.ghost_span(20, 50, 25)).is_equal_approx(Vector2(0.0, 0.4), Vector2(0.001, 0.001))


func test_ghost_span_is_empty_without_incoming_damage() -> void:
	var span: Vector2 = HP_GHOST.ghost_span(50, 50, 0)
	assert_float(span.x).is_equal(span.y)


func test_line_width_steps_by_share_of_target_max_hp() -> void:
	assert_float(OVERLAY.line_width(10, 100)).is_equal(8.0)
	assert_float(OVERLAY.line_width(20, 100)).is_equal(14.0)
	assert_float(OVERLAY.line_width(39, 100)).is_equal(14.0)
	assert_float(OVERLAY.line_width(40, 100)).is_equal(20.0)
	assert_float(OVERLAY.line_width(12, 30)).is_equal(20.0)
