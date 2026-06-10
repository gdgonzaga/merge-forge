extends Node

var music_player: AudioStreamPlayer
var music_fade: Tween
var sfx_pool: Array[AudioStreamPlayer] = []
var sfx_map: Dictionary = {}


func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	for i in range(6):
		var player := AudioStreamPlayer.new()
		add_child(player)
		sfx_pool.append(player)


func play_music(track: String) -> void:
	var stream := _load_audio(track)
	if not stream:
		return
	if music_player.playing and music_player.stream == stream:
		return
	if music_player.playing:
		if music_fade:
			music_fade.kill()
		music_fade = create_tween()
		music_fade.tween_property(music_player, "volume_db", -80.0, 1.0)
		music_fade.tween_callback(func(): _start_music(stream))
	else:
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
	music_player.stream = stream
	music_player.volume_db = 0.0
	music_player.play()


func _load_audio(path: String) -> AudioStream:
	if not FileAccess.file_exists(path):
		return null
	if path.ends_with(".ogg"):
		return load(path)
	if path.ends_with(".wav"):
		return load(path)
	return null
