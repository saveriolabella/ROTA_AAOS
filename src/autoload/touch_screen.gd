extends CanvasLayer

const DEBUG_AUDIO_FOCUS_UI := true

func af_ui_log(msg := ""):
	if DEBUG_AUDIO_FOCUS_UI:
		print("[AudioFocusUI] ", msg)

onready var control := $Control
onready var right := $Control/HBoxRight
onready var top := $Control/HBoxTop

onready var keys := [$Control/HBoxRight/C, $Control/HBoxRight/X]
onready var buttons := [$Control/HBoxRight/C/Control/Button, $Control/HBoxRight/X/Control/Button]

onready var key_z := $Control/HBoxTop/Z
onready var pause := $Control/HBoxTop/Pause
onready var audio_focus := $Control/HBoxTop/AudioFocus
onready var audio_focus_button := $Control/HBoxTop/AudioFocus/Control/Button
onready var audio_focus_icon := $Control/HBoxTop/AudioFocus/Control/Sprite
onready var audio_focus_slash := $Control/HBoxTop/AudioFocus/Control/Slash
onready var game_hide := [$Control/HBoxRight/C/Control/Key, $Control/HBoxRight/X/Control/Key]
onready var game_show := [audio_focus, key_z, $Control/HBoxRight/C/Control/Sprite, $Control/HBoxRight/X/Control/Sprite]

onready var btns := $Control/HBoxLeft/DPad/Buttons.get_children()
onready var actions := InputMap.get_actions()

func _ready():
	set_game(false)
	visible = false
	af_ui_log("_ready() is_touch=" + str(Shared.is_touch))

	if is_instance_valid(audio_focus_button):
		audio_focus_button.connect("pressed", self, "audio_focus_pressed")
		af_ui_log("audio focus button connected")

	if is_instance_valid(Audio) and !Audio.is_connected("audio_focus_state_changed", self, "audio_focus_state_changed"):
		Audio.connect("audio_focus_state_changed", self, "audio_focus_state_changed")
		af_ui_log("connected Audio.audio_focus_state_changed")

	refresh_audio_focus_icon()
	
	yield(Shared, "scene_changed")
	visible = Shared.is_touch or ((OS.has_touchscreen_ui_hint() and OS.get_name() == "HTML5") or OS.get_name() == "Android")

func _input(event):
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		visible = true
	elif event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		visible = Shared.is_touch

func show_keys(arg_arrows := true, arg_c := true, arg_x := true, arg_pause := false, arg_passby := false):
	right.visible = arg_arrows
	keys[0].visible = arg_c
	keys[1].visible = arg_x
	top.visible = arg_pause

func set_game(arg := false):
	
	for h in game_hide:
		h.visible = !arg
	for s in game_show:
		s.visible = arg
	
	if Shared.is_arcade:
		key_z.visible = false
	pause.visible = !Shared.is_title
	refresh_audio_focus_icon()
	
	for a in actions:
		Input.action_release(a)
	
	for f in buttons:
		f.passby_press = arg

func audio_focus_pressed():
	af_ui_log("audio focus button pressed")
	if is_instance_valid(Audio):
		Audio.handle_audio_focus_icon_pressed()

func audio_focus_state_changed(_is_muted, _is_enabled):
	af_ui_log("state changed muted=" + str(_is_muted) + " enabled=" + str(_is_enabled))
	refresh_audio_focus_icon()

func refresh_audio_focus_icon():
	if !is_instance_valid(audio_focus):
		return

	var is_enabled = is_instance_valid(Audio) and Audio.should_handle_audio_focus() and !Shared.is_arcade
	audio_focus.visible = is_enabled
	af_ui_log("refresh icon visible=" + str(is_enabled) + " muted=" + str(Audio.is_audio_focus_muted if is_instance_valid(Audio) else false))

	if is_instance_valid(audio_focus_slash):
		audio_focus_slash.visible = is_enabled and Audio.is_audio_focus_muted

	if is_instance_valid(audio_focus_icon):
		audio_focus_icon.modulate = Color(1, 0.5, 0.5, 1) if (is_enabled and Audio.is_audio_focus_muted) else Color(1, 1, 1, 1)

func margin(x := 20, y := 20):
	control.margin_left = x
	control.margin_right = -x
	control.margin_top = y
	control.margin_bottom = -y
