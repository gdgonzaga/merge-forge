extends TestBase

const PRESENTER_SCRIPT := preload("res://dungeon/combat_presenter.gd")

func test_presenter_has_tunable_flight_duration() -> void:
	var presenter = PRESENTER_SCRIPT.new()
	assert_float(presenter.get_flight_duration()).is_equal(0.25)
	presenter.set_flight_duration(0.3)
	assert_float(presenter.get_flight_duration()).is_equal(0.3)
	presenter.free()
