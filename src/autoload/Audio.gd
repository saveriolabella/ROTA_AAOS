extends Node

signal audio_focus_state_changed(is_muted, is_enabled)
const DEBUG_AUDIO_FOCUS := true

export var is_refresh := false setget set_refresh

var dict = {}

onready var music_player := $Music/Music
export (Array, AudioStream) var ost = []
var last_song := -1
var music_que = []

export var wait_range := Vector2(10, 90)
var wait_clock := 0.0
var wait_time := 10.0
var music_ease := EaseMover.new(1.0, -1)
var android_audio_focus_plugin = null
var is_audio_focus_muted := false

func af_log(msg := ""):
	if DEBUG_AUDIO_FOCUS:
		print("[AudioFocus] ", msg)

func _ready():
	music_player.connect("finished", self, "music_finished")
	set_refresh()
	
	randomize()
	wait_clock = 4.0
	af_log("_ready() os=" + OS.get_name())
	
	if OS.get_name() == "Android":
		bind_android_audio_focus_signal()
		if should_handle_audio_focus():
			var granted := request_android_audio_focus()
			af_log("initial request_audio_focus granted=" + str(granted))
			if !granted:
				push_warning("Android audio focus was not granted.")

func play(arg = "menu_cursor", from := 1.0, to := -1.0, pos := 0.0):
	if arg is String and dict.has(arg):
		arg = dict[arg]
	
	if is_instance_valid(arg) and (arg is AudioStreamPlayer or arg is AudioStreamPlayer2D):
		arg.pitch_scale = from if to < 0 else rand_range(from, to)
		arg.play(pos)

func _physics_process(delta):
	if wait_clock > 0:
		wait_clock -= delta
		if wait_clock <= 0:
			music_play()
	
	var s = music_ease.count(delta, !Shared.is_arcade)
	if !music_ease.is_last:
		var m = dict["music_music"]
		m.volume_db = lerp(-30.0, 0.0, s)
		
		if music_ease.clock == 0.0:
			m.stop()
		elif music_ease.last == 0.0 and !m.playing:
			m.play(m.get_playback_position())

func music_finished():
	if !Shared.is_arcade:
		wait_clock = rand_range(wait_range.x, wait_range.y)
		print("music_finished, wait_clock: ", wait_clock)

func music_play():
	if music_que.empty():
		music_que = range(ost.size())
		music_que.erase(last_song)
		music_que.shuffle()
	
	last_song = music_que.pop_front()
	music_player.stream = ost[last_song]
	music_player.play()

func set_refresh(arg := false):
	is_refresh = arg
	dict = {}
	for i in Shared.get_all_children(self):
		if i is AudioStreamPlayer or i is AudioStreamPlayer2D:
			dict[str(get_path_to(i)).to_lower().replace("/", "_")] = i
	
	print("Audio.dict refresh: ", dict.keys())

func get_android_audio_focus_singleton():
	if android_audio_focus_plugin != null:
		return android_audio_focus_plugin

	if Engine.has_singleton("RotaAudioFocusPlugin"):
		android_audio_focus_plugin = Engine.get_singleton("RotaAudioFocusPlugin")
		af_log("singleton acquired via name='RotaAudioFocusPlugin': " + str(android_audio_focus_plugin))
		return android_audio_focus_plugin

	af_log("Engine singleton RotaAudioFocusPlugin not found")
	return android_audio_focus_plugin

func request_android_audio_focus() -> bool:
	if OS.get_name() != "Android":
		af_log("request_audio_focus bypass (non-Android)")
		return true

	var audio_focus = get_android_audio_focus_singleton()

	if audio_focus == null:
		push_warning("RotaAudioFocusPlugin Android plugin is not available.")
		af_log("request_audio_focus failed (singleton null)")
		return false

	var granted = audio_focus.request_audio_focus()
	af_log("request_audio_focus result=" + str(granted))
	return granted

func abandon_android_audio_focus() -> void:
	if OS.get_name() != "Android":
		af_log("abandon_audio_focus bypass (non-Android)")
		return

	var audio_focus = get_android_audio_focus_singleton()

	if audio_focus == null:
		af_log("abandon_audio_focus skipped (singleton null)")
		return

	var released = audio_focus.abandon_audio_focus()
	af_log("abandon_audio_focus result=" + str(released))

func bind_android_audio_focus_signal() -> void:
	var audio_focus = get_android_audio_focus_singleton()

	if audio_focus == null:
		af_log("bind signal skipped (singleton null)")
		return

	if audio_focus.has_signal("focus_changed") and !audio_focus.is_connected("focus_changed", self, "_on_android_audio_focus_changed"):
		audio_focus.connect("focus_changed", self, "_on_android_audio_focus_changed")
		af_log("connected focus_changed signal")
	else:
		af_log("focus_changed missing or already connected")

func _set_all_audio_muted(arg := false) -> void:
	for i in range(AudioServer.get_bus_count()):
		AudioServer.set_bus_mute(i, arg)

func should_handle_audio_focus() -> bool:
	return OS.get_name() == "Android" and get_android_audio_focus_singleton() != null

func set_audio_focus_muted(arg := is_audio_focus_muted) -> void:
	is_audio_focus_muted = bool(arg)
	af_log("set_audio_focus_muted -> " + str(is_audio_focus_muted))
	_set_all_audio_muted(is_audio_focus_muted)
	emit_signal("audio_focus_state_changed", is_audio_focus_muted, should_handle_audio_focus())

func _on_android_audio_focus_changed(focus_change : int) -> void:
	af_log("focus_changed signal value=" + str(focus_change))

	if focus_change == 1:
		set_audio_focus_muted(false)
	elif focus_change < 0:
		set_audio_focus_muted(true)

func handle_audio_focus_icon_pressed() -> void:
	af_log("icon pressed muted=" + str(is_audio_focus_muted) + " enabled=" + str(should_handle_audio_focus()))
	if !should_handle_audio_focus():
		af_log("icon press ignored (handling disabled)")
		return

	if is_audio_focus_muted:
		var granted := request_android_audio_focus()
		af_log("icon request_audio_focus granted=" + str(granted))
		if granted:
			set_audio_focus_muted(false)
	else:
		set_audio_focus_muted(true)
		af_log("icon abandon_audio_focus()")
		abandon_android_audio_focus()

func _notification(what):
	match what:
		MainLoop.NOTIFICATION_APP_PAUSED:
			# Android onPause / onStop: The app is minimized
			af_log("NOTIFICATION_APP_PAUSED abandoing audio focus")
			abandon_android_audio_focus()

		MainLoop.NOTIFICATION_APP_RESUMED:
			# Android onResume: The app is brought back to the foreground
			if should_handle_audio_focus():
				bind_android_audio_focus_signal()
				var granted := request_android_audio_focus()
				af_log("NOTIFICATION_APP_RESUMED request_audio_focus granted=" + str(granted))
				if !granted:
					push_warning("Android audio focus was not granted.")

		MainLoop.NOTIFICATION_WM_GO_BACK_REQUEST:
			# The back button was pressed
			af_log("NOTIFICATION_WM_GO_BACK_REQUEST abandoing audio focus")
			abandon_android_audio_focus()

		MainLoop.NOTIFICATION_WM_QUIT_REQUEST:
			# The back button was pressed
			af_log("NOTIFICATION_WM_QUIT_REQUEST abandoing audio focus")
			abandon_android_audio_focus()	
			get_tree().quit()
