extends RefCounted

# Pure geometry for attack lines. Every line keeps to its lane: it's shifted and
# bent toward the attacker's right (measured from its direction of travel), so
# an attack from A to B and one from B to A run in two separate lanes that
# never touch. Returns only Vector2 values, so callers can sample curves every
# frame without allocating.

const LANE_OFFSET := 16.0
const BOW_RATIO := 0.15
const BOW_MIN := 24.0
const BOW_MAX := 70.0


# The attacker's right-hand side for travel from `from` to `to`, in screen
# coordinates (y down).
static func right_of(from: Vector2, to: Vector2) -> Vector2:
	var dir := (to - from).normalized()
	return Vector2(-dir.y, dir.x)


static func start(from: Vector2, to: Vector2) -> Vector2:
	return from + right_of(from, to) * LANE_OFFSET


static func end(from: Vector2, to: Vector2) -> Vector2:
	return to + right_of(from, to) * LANE_OFFSET


# Control point of the lane's quadratic curve: pushed further right by a bow
# that grows with distance, clamped so short lanes don't loop.
static func control(from: Vector2, to: Vector2) -> Vector2:
	var bow := clampf(from.distance_to(to) * BOW_RATIO, BOW_MIN, BOW_MAX)
	var mid := (start(from, to) + end(from, to)) * 0.5
	return mid + right_of(from, to) * bow


static func point(a: Vector2, c: Vector2, b: Vector2, t: float) -> Vector2:
	return a.lerp(c, t).lerp(c.lerp(b, t), t)


static func tangent(a: Vector2, c: Vector2, b: Vector2, t: float) -> Vector2:
	return ((c - a) * (1.0 - t) + (b - c) * t) * 2.0


# (tail, head) of a tracer comet as 0..1 positions along its lane. The head
# eases out from the attacker and reaches 1 (the hit arrives) before the end of
# `duration`; the tail follows `length` behind and drains into the target.
static func tracer_span(elapsed: float, duration: float, length: float) -> Vector2:
	var u := clampf(elapsed / duration, 0.0, 1.0)
	var eased := 1.0 - (1.0 - u) * (1.0 - u)
	var head := eased * (1.0 + length)
	return Vector2(clampf(head - length, 0.0, 1.0), clampf(head, 0.0, 1.0))
