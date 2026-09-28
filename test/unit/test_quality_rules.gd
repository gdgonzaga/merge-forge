extends TestBase

# The quality a merge group makes, and which qualities come back as refunds.
# Refunds are the group's lowest qualities, so the best inputs pay for the
# upgrade and a kept pair can't mint quality for free.

const QUALITY_RULES := preload("res://board/quality_rules.gd")


func test_three_normal_make_normal_with_no_refunds() -> void:
	var outcome := QUALITY_RULES.resolve([0, 0, 0] as Array[int], 3)
	assert_int(outcome["result_quality"]).is_equal(0)
	assert_array(outcome["refund_qualities"]).is_empty()


func test_five_normal_make_fine_and_refund_two_normal() -> void:
	var outcome := QUALITY_RULES.resolve([0, 0, 0, 0, 0] as Array[int], 5)
	assert_int(outcome["result_quality"]).is_equal(1)
	assert_array(outcome["refund_qualities"]).is_equal([0, 0])


func test_five_fine_make_masterwork() -> void:
	var outcome := QUALITY_RULES.resolve([1, 1, 1, 1, 1] as Array[int], 5)
	assert_int(outcome["result_quality"]).is_equal(2)


func test_masterwork_is_the_cap() -> void:
	var outcome := QUALITY_RULES.resolve([2, 2, 2, 2, 2] as Array[int], 5)
	assert_int(outcome["result_quality"]).is_equal(2)


func test_a_mixed_four_refunds_the_lowest_and_consumes_the_masterwork() -> void:
	# floor((2 + 0 + 0 + 0) / 4 = 0.5) + 0 = 0; one refund, the lowest (0).
	var outcome := QUALITY_RULES.resolve([2, 0, 0, 0] as Array[int], 4)
	assert_int(outcome["result_quality"]).is_equal(0)
	assert_array(outcome["refund_qualities"]).is_equal([0])


func test_refunds_are_the_lowest_whatever_the_input_order() -> void:
	# floor((1 + 2 + 0 + 2 + 1) / 5 = 1.2) + 1 = 2; refunds are the two lowest.
	var outcome := QUALITY_RULES.resolve([1, 2, 0, 2, 1] as Array[int], 5)
	assert_int(outcome["result_quality"]).is_equal(2)
	assert_array(outcome["refund_qualities"]).is_equal([0, 1])


func test_a_mixed_six_makes_two_normal_results_with_no_refunds() -> void:
	# floor(3 / 6 = 0.5) + 1 (six is 5 or more) = 1.
	var outcome := QUALITY_RULES.resolve([1, 1, 1, 0, 0, 0] as Array[int], 6)
	assert_int(outcome["result_quality"]).is_equal(1)
	assert_array(outcome["refund_qualities"]).is_empty()
