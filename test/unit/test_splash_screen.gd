extends TestBase

const MAIN := preload("res://core/main.tscn")


func test_startup_video_reveals_main_menu_when_it_finishes() -> void:
	var main: Node = auto_free(MAIN.instantiate())
	add_child(main)
	var splash: Control = main.get_node_or_null("SplashLayer/SplashScreen")
	assert_object(splash).is_not_null()
	assert_object(main.get_node("SceneContainer/MainMenu")).is_not_null()
	var video: VideoStreamPlayer = splash.get_node("%VideoPlayer")
	assert_bool(video.is_playing()).is_true()
	video.finished.emit()
	await get_tree().process_frame
	assert_bool(main.has_node("SplashLayer")).is_false()
	assert_object(main.get_node("SceneContainer/MainMenu")).is_not_null()


func test_splash_timeout_reveals_main_menu() -> void:
	var main: Node = auto_free(MAIN.instantiate())
	add_child(main)
	var timer: Timer = main.get_node("SplashLayer/SplashScreen/%SplashTimer")
	timer.timeout.emit()
	await get_tree().process_frame
	assert_bool(main.has_node("SplashLayer")).is_false()
	assert_object(main.get_node("SceneContainer/MainMenu")).is_not_null()


func test_android_back_dismisses_splash() -> void:
	var main: Node = auto_free(MAIN.instantiate())
	add_child(main)
	var splash: Control = main.get_node("SplashLayer/SplashScreen")
	splash.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await get_tree().process_frame
	assert_bool(main.has_node("SplashLayer")).is_false()
	assert_object(main.get_node("SceneContainer/MainMenu")).is_not_null()
