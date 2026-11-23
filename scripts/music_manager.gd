extends Node

const FADE_SECONDS := 0.8
const PLAYBACK_DB := -8.0
const SILENT_DB := -60.0
const NON_COMBAT: Array[String] = [
	"story_opening_v1", "story_opening_v2", "seeking_light_v1",
	"seeking_light_v2", "shadow_steps_v1", "shadow_steps_v2",
]
const COMBAT: Array[String] = [
	"radiance_v1", "radiance_v2", "shadow_eclipse_v1",
	"shadow_eclipse_v2", "light_shadow_cycle_v1", "light_shadow_cycle_v2",
]

var context: StringName = &""
var current_track: String = ""
var players: Array[AudioStreamPlayer] = []
var active_player: AudioStreamPlayer
var _bags: Dictionary = {}
var _fade: Tween
var _first_track: bool = true

func _ready() -> void:
	# Keep music and volume controls available while the game is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for index in range(2):
		var player := AudioStreamPlayer.new()
		player.name = "MusicChannel%d" % index
		player.bus = &"Music"
		player.volume_db = SILENT_DB
		add_child(player)
		players.append(player)
		player.finished.connect(_on_track_finished.bind(player))

func set_context(next_context: StringName) -> void:
	if next_context not in [&"non_combat", &"combat"]:
		return
	if context == next_context and is_instance_valid(active_player) and active_player.playing:
		return
	context = next_context
	_play_next()

func _choose_track() -> String:
	var pool: Array[String] = COMBAT if context == &"combat" else NON_COMBAT
	var bag: Array = _bags.get(context, [])
	if bag.is_empty():
		bag = pool.duplicate()
		bag.shuffle()
		if bag.size() > 1 and bag.back() == current_track:
			var swap = bag[0]
			bag[0] = bag[-1]
			bag[-1] = swap
	# Open the main menu with one of the two opening-theme versions.
	if _first_track and context == &"non_combat":
		var opening: String = "story_opening_v%d" % randi_range(1, 2)
		bag.erase(opening)
		_bags[context] = bag
		_first_track = false
		return opening
	_first_track = false
	var track: String = bag.pop_back()
	_bags[context] = bag
	return track

func _play_next() -> void:
	var track := _choose_track()
	var stream := load("res://assets/audio/music/%s.mp3" % track) as AudioStreamMP3
	if stream == null:
		push_error("Unable to load BGM: %s" % track)
		return
	stream.loop = false
	if is_instance_valid(_fade):
		_fade.kill()
	var previous := active_player
	active_player = players[1] if previous == players[0] else players[0]
	active_player.stop()
	active_player.stream = stream
	active_player.volume_db = SILENT_DB
	current_track = track
	active_player.play()
	_fade = create_tween().set_parallel(true)
	_fade.tween_property(active_player, "volume_db", PLAYBACK_DB, FADE_SECONDS)
	if is_instance_valid(previous):
		_fade.tween_property(previous, "volume_db", SILENT_DB, FADE_SECONDS)
		_fade.chain().tween_callback(previous.stop)

func _on_track_finished(player: AudioStreamPlayer) -> void:
	if player == active_player:
		_play_next()

func _exit_tree() -> void:
	if is_instance_valid(_fade):
		_fade.kill()
	_fade = null
	for player in players:
		player.stop()
		player.stream = null
