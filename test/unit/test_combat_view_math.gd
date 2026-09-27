extends TestBase

# The pure maths behind combat lines: the windup countdown that drives a line's
# fill, the HP ghost span, line width, and attack lanes (A to B and B to A must
# never share a lane).

const ENGINE := preload("res://dungeon/combat_engine.gd")
const HP_GHOST := preload("res://dungeon/hp_ghost.gd")
const LINES := preload("res://dungeon/combat_lines.gd")
const LANE := preload("res://dungeon/combat_lane.gd")


func test_windup_progress_across_a_two_tick_windup() -> void:
	# Windup starts: 2 ticks left, the timer just restarted.
	assert_float(ENGINE.windup_progress(2, 2, 1.0, 1.0, 0.0)).is_equal_approx(0.0, 0.001)
	assert_float(ENGINE.windup_progress(2, 2, 0.5, 1.0, 0.0)).is_equal_approx(0.25, 0.001)
	assert_float(ENGINE.windup_progress(1, 2, 1.0, 1.0, 0.0)).is_equal_approx(0.5, 0.001)
	# Just before the landing tick.
	assert_float(ENGINE.windup_progress(1, 2, 0.0, 1.0, 0.0)).is_equal_approx(1.0, 0.001)


func test_windup_progress_scales_with_windup_and_tick_length() -> void:
	# Remaining 1 * 2.0 + 0.8 = 2.8 of 3 * 2.0 = 6.0 -> 1 - 2.8 / 6.0.
	assert_float(ENGINE.windup_progress(2, 3, 0.8, 2.0, 0.0)).is_equal_approx(0.5333, 0.001)


func test_windup_progress_is_clamped() -> void:
	assert_float(ENGINE.windup_progress(3, 2, 1.0, 1.0, 0.0)).is_equal(0.0)
	assert_float(ENGINE.windup_progress(0, 2, 0.0, 1.0, 0.0)).is_equal(1.0)


func test_ghost_span_marks_the_chunk_the_hit_takes() -> void:
	assert_vector(HP_GHOST.ghost_span(90, 120, 30)).is_equal_approx(Vector2(0.5, 0.75), Vector2(0.001, 0.001))
	assert_vector(HP_GHOST.ghost_span(40, 50, 25)).is_equal_approx(Vector2(0.3, 0.8), Vector2(0.001, 0.001))


func test_ghost_span_covers_the_whole_bar_when_lethal() -> void:
	assert_vector(HP_GHOST.ghost_span(20, 50, 25)).is_equal_approx(Vector2(0.0, 0.4), Vector2(0.001, 0.001))


func test_ghost_span_is_empty_without_incoming_damage() -> void:
	var span: Vector2 = HP_GHOST.ghost_span(50, 50, 0)
	assert_float(span.x).is_equal(span.y)


func test_line_width_grows_with_share_of_target_hp() -> void:
	# 4 px for nothing, 18 px for a hit that takes all the HP left.
	assert_float(LINES.line_width(0, 100)).is_equal_approx(4.0, 0.001)
	assert_float(LINES.line_width(50, 100)).is_equal_approx(11.0, 0.001)
	assert_float(LINES.line_width(100, 100)).is_equal_approx(18.0, 0.001)


func test_line_width_is_clamped_for_overkill_and_zero_hp() -> void:
	assert_float(LINES.line_width(150, 100)).is_equal_approx(18.0, 0.001)
	assert_float(LINES.line_width(5, 0)).is_equal_approx(18.0, 0.001)


func test_windup_progress_stretches_to_the_landing_delay() -> void:
	# Total 2 * 1.0 + 0.3 = 2.3. At the landing tick 0.3 of it is still left.
	assert_float(ENGINE.windup_progress(2, 2, 1.0, 1.0, 0.3)).is_equal_approx(0.0, 0.001)
	assert_float(ENGINE.windup_progress(1, 2, 0.0, 1.0, 0.3)).is_equal_approx(0.8696, 0.001)


func test_lane_keeps_to_the_attackers_right() -> void:
	# Enemy at (0, 200) attacking a party member at (0, 0): travel is up the
	# screen, so the lane shifts 16 to screen-right and bows 200 * 0.15 = 30.
	var enemy := Vector2(0, 200)
	var member := Vector2(0, 0)
	assert_vector(LANE.start(enemy, member)).is_equal(Vector2(16, 200))
	assert_vector(LANE.end(enemy, member)).is_equal(Vector2(16, 0))
	assert_vector(LANE.control(enemy, member)).is_equal(Vector2(46, 100))


func test_opposite_attacks_use_opposite_lanes() -> void:
	var enemy := Vector2(0, 200)
	var member := Vector2(0, 0)
	assert_vector(LANE.start(member, enemy)).is_equal(Vector2(-16, 0))
	assert_vector(LANE.end(member, enemy)).is_equal(Vector2(-16, 200))
	assert_vector(LANE.control(member, enemy)).is_equal(Vector2(-46, 100))


func test_lane_bow_is_clamped() -> void:
	# 100 * 0.15 = 15 -> 24 minimum; 1000 * 0.15 = 150 -> 70 maximum.
	assert_vector(LANE.control(Vector2(0, 100), Vector2.ZERO)).is_equal(Vector2(40, 50))
	assert_vector(LANE.control(Vector2(0, 1000), Vector2.ZERO)).is_equal(Vector2(86, 500))

