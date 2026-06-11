extends Node

var music_player: AudioStreamPlayer
var music_fade: Tween
var sfx_pool: Array[AudioStreamPlayer] = []
var sfx_map: Dictionary = {}
var _prev_gold: int = 0

const SFX_BASE := "res://resources/audio/sfx/"
const MUSIC_BASE := "res://resources/audio/music/"


func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	for i in range(6):
		var player := AudioStreamPlayer.new()
		add_child(player)
		sfx_pool.append(player)

	sfx_map = {
		"item_place": SFX_BASE + "item_place.wav",
		"merge_complete": SFX_BASE + "merge_complete.wav",
		"despawn": SFX_BASE + "despawn.wav",
		"customer_happy": SFX_BASE + "customer_happy.wav",
		"customer_reject": SFX_BASE + "customer_reject.wav",
		"gold_earn": SFX_BASE + "gold_earn.wav",
		"session_start": SFX_BASE + "session_start.wav",
		"session_end": SFX_BASE + "session_end.wav",
		"dungeon_start": SFX_BASE + "dungeon_start.wav",
		"dungeon_clear": SFX_BASE + "dungeon_clear.wav",
		"dungeon_fail": SFX_BASE + "dungeon_fail.wav",
		"ko": SFX_BASE + "ko.wav",
		"purchase": SFX_BASE + "purchase.wav",
		"crate_open": SFX_BASE + "crate_open.wav",
	}

	EventBus.merge_completed.connect(func(_id, _gold): play_sfx("merge_complete"))
	EventBus.customer_fulfilled.connect(func(_id): play_sfx("customer_happy"))
	EventBus.customer_rejected.connect(func(_id): play_sfx("customer_reject"))
	EventBus.session_ended.connect(func(_s): play_sfx("session_end"))
	EventBus.dungeon_cleared.connect(func(_r): play_sfx("dungeon_clear"))
	EventBus.dungeon_failed.connect(func(_s): play_sfx("dungeon_fail"))
	GameManager.blueprint_added.connect(func(_id): play_sfx("purchase"))
	GameManager.upgrade_added.connect(func(_id): play_sfx("purchase"))
	GameManager.gold_changed.connect(_on_gold_changed)

	_prev_gold = GameManager.gold


func _on_gold_changed(new_amount: int) -> void:
	if new_amount > _prev_gold:
		play_sfx("gold_earn")
	_prev_gold = new_amount


func play_music(track: String) -> void:
	print("[Audio] play_music called: track='%s'" % track)
	var path1 := MUSIC_BASE + track + ".wav"
	var path2 := SFX_BASE + track + ".wav"
	print("[Audio] trying path1='%s' file_exists=%s" % [path1, str(FileAccess.file_exists(path1))])
	var stream := _load_audio(path1)
	if not stream:
		print("[Audio] path1 failed, trying path2='%s' file_exists=%s" % [path2, str(FileAccess.file_exists(path2))])
		stream = _load_audio(path2)
	if not stream:
		push_error("[Audio] FAILED to load music track: %s" % track)
		return
	print("[Audio] loaded stream: %s type=%s" % [str(stream), stream.get_class()])
	if music_player.playing and music_player.stream == stream:
		print("[Audio] already playing this track, skip")
		return
	if music_player.playing:
		print("[Audio] crossfading from current track")
		if music_fade:
			music_fade.kill()
		music_fade = create_tween()
		music_fade.tween_property(music_player, "volume_db", -80.0, 1.0)
		music_fade.tween_callback(func(): _start_music(stream))
	else:
		print("[Audio] starting music (not currently playing)")
		_start_music(stream)


func stop_music() -> void:
	if not music_player.playing:
		return
	if music_fade:
		music_fade.kill()
	music_fade = create_tween()
	music_fade.tween_property(music_player, "volume_db", -80.0, 1.0)
	music_fade.tween_callback(music_player.stop)


func play_sfx(sfx_name: String) -> void:
	var path: String = sfx_map.get(sfx_name, "")
	if path == "":
		return
	var stream := _load_audio(path)
	if not stream:
		return
	for player in sfx_pool:
		if not player.playing:
			player.stream = stream
			player.volume_db = 0.0
			player.play()
			return


func _start_music(stream: AudioStream) -> void:
	print("[Audio] _start_music: stream=%s class=%s" % [str(stream), stream.get_class()])
	music_player.stream = stream
	music_player.volume_db = 0.0
	music_player.play()
	print("[Audio] music_player.playing=%s volume_db=%s" % [str(music_player.playing), str(music_player.volume_db)])


func _load_audio(path: String) -> AudioStream:
	if not FileAccess.file_exists(path):
		print("[Audio] _load_audio: file NOT found: %s" % path)
		return null
	print("[Audio] _load_audio: file found, loading: %s" % path)
	var res = load(path)
	if res == null:
		print("[Audio] _load_audio: load() returned null for: %s" % path)
		return null
	print("[Audio] _load_audio: loaded type=%s" % res.get_class())
	if res is AudioStream:
		return res
	print("[Audio] _load_audio: NOT an AudioStream: %s" % res.get_class())
	return null
