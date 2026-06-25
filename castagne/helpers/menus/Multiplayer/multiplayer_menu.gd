extends Control

const PORT = 6442

enum State { MAIN, HOST_SETUP, HOST_WAITING, JOIN_SETUP, LOBBY }

var _state : int = State.MAIN
var _is_host := false
var _client_peer_id := -1

var _player_names := ["", ""]
var _player_chars := [0, 0]
var _lobby_name := "Arena"
var _char_data := []
var _timeout_timer : Timer = null
var _launching := false

# Panel references
var _panel_main : Control
var _panel_host_setup : Control
var _panel_host_waiting : Control
var _panel_join : Control
var _panel_lobby : Control

# Dynamic label refs
var _code_label : Label
var _host_status : Label
var _join_status : Label
var _lobby_title : Label
var _p1_name_label : Label
var _p2_name_label : Label
var _p1_char_label : Label
var _p2_char_label : Label
var _ready_btn : Button
var _p2_waiting_label : Label

# Input refs
var _host_name_edit : LineEdit
var _host_lobby_edit : LineEdit
var _join_name_edit : LineEdit
var _join_code_edit : LineEdit

# ──────────────────────────────────────────────────────────────────────────────
# Init

func _ready():
	# Clean up any leftover peer from a previous lobby session
	if get_tree().network_peer:
		get_tree().network_peer = null
	_char_data = Castagne.baseConfigData.GetGameCharacterList()
	_build_ui()
	_goto(State.MAIN)
	get_tree().connect("network_peer_connected", self, "_net_peer_connected")
	get_tree().connect("network_peer_disconnected", self, "_net_peer_disconnected")
	get_tree().connect("server_disconnected", self, "_net_server_disconnected")
	_apply_launch_args()

func _notification(what: int):
	if what == NOTIFICATION_PREDELETE:
		_cancel_timeout()
		if is_inside_tree():
			var tree = get_tree()
			if tree.is_connected("network_peer_connected", self, "_net_peer_connected"):
				tree.disconnect("network_peer_connected", self, "_net_peer_connected")
			if tree.is_connected("network_peer_disconnected", self, "_net_peer_disconnected"):
				tree.disconnect("network_peer_disconnected", self, "_net_peer_disconnected")
			if tree.is_connected("server_disconnected", self, "_net_server_disconnected"):
				tree.disconnect("server_disconnected", self, "_net_server_disconnected")

func _apply_launch_args():
	var args = OS.get_cmdline_args()
	if "listen" in args:
		_host_name_edit.text = "Player 1"
		_host_lobby_edit.text = "Test Arena"
		_goto(State.HOST_SETUP)
	elif "join" in args:
		_join_name_edit.text = "Player 2"
		_join_code_edit.text = "127.0.0.1"
		_goto(State.JOIN_SETUP)

# ──────────────────────────────────────────────────────────────────────────────
# UI construction

func _build_ui():
	# Full-screen dark background
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.04, 0.04, 1.0)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var center = CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	add_child(center)

	var root_vbox = VBoxContainer.new()
	root_vbox.rect_min_size = Vector2(480, 0)
	center.add_child(root_vbox)

	_panel_main = _build_main_panel()
	_panel_host_setup = _build_host_setup_panel()
	_panel_host_waiting = _build_host_waiting_panel()
	_panel_join = _build_join_panel()
	_panel_lobby = _build_lobby_panel()

	for p in [_panel_main, _panel_host_setup, _panel_host_waiting, _panel_join, _panel_lobby]:
		root_vbox.add_child(p)


func _build_main_panel() -> Control:
	var p = _make_panel()
	_add_title(p, "ONLINE BATTLE")
	_add_spacer(p, 12)
	_make_btn(p, "HOST LOBBY", self, "_on_host_pressed")
	_add_spacer(p, 4)
	_make_btn(p, "JOIN LOBBY", self, "_on_join_pressed")
	_add_spacer(p, 4)
	_make_btn(p, "QUICK PLAY", self, "_on_quick_play_pressed")
	_add_spacer(p, 16)
	_make_btn(p, "BACK", self, "_on_back_pressed", true)
	return p


func _build_host_setup_panel() -> Control:
	var p = _make_panel()
	_add_title(p, "HOST LOBBY")
	_add_spacer(p, 12)
	_add_label(p, "Your Name")
	_host_name_edit = _make_line_edit(p, "Player 1")
	_add_spacer(p, 8)
	_add_label(p, "Lobby Name")
	_host_lobby_edit = _make_line_edit(p, "Arena")
	_add_spacer(p, 16)
	_make_btn(p, "CREATE LOBBY", self, "_on_create_lobby_pressed")
	_add_spacer(p, 8)
	_make_btn(p, "BACK", self, "_on_host_setup_back_pressed", true)
	return p


func _build_host_waiting_panel() -> Control:
	var p = _make_panel()
	_add_title(p, "WAITING FOR PLAYER")
	_add_spacer(p, 12)
	_add_label(p, "Share this code with your opponent:")
	_code_label = _add_label(p, "---")
	_code_label.add_color_override("font_color", Color(1.0, 0.6, 0.3, 1.0))
	_add_spacer(p, 12)
	_host_status = _add_label(p, "Waiting for opponent to connect...")
	_add_spacer(p, 16)
	_make_btn(p, "CANCEL", self, "_on_cancel_hosting_pressed", true)
	return p


func _build_join_panel() -> Control:
	var p = _make_panel()
	_add_title(p, "JOIN LOBBY")
	_add_spacer(p, 12)
	_add_label(p, "Your Name")
	_join_name_edit = _make_line_edit(p, "Player 2")
	_add_spacer(p, 8)
	_add_label(p, "Lobby Code (host's IP)")
	_join_code_edit = _make_line_edit(p, "")
	_add_spacer(p, 16)
	_make_btn(p, "JOIN", self, "_on_join_confirm_pressed")
	_join_status = _add_label(p, "")
	_add_spacer(p, 8)
	_make_btn(p, "BACK", self, "_on_join_back_pressed", true)
	return p


func _build_lobby_panel() -> Control:
	var p = _make_panel()
	_lobby_title = _add_title(p, "LOBBY")
	_add_spacer(p, 8)

	# Two-column layout for players
	var hbox = HBoxContainer.new()
	hbox.add_constant_override("separation", 16)
	p.add_child(hbox)

	var p1_col = _make_player_column(hbox, 0)
	var _sep = VSeparator.new()
	_sep.rect_min_size = Vector2(2, 0)
	hbox.add_child(_sep)
	var p2_col = _make_player_column(hbox, 1)
	p1_col.size_flags_horizontal = SIZE_EXPAND_FILL
	p2_col.size_flags_horizontal = SIZE_EXPAND_FILL

	_add_spacer(p, 16)

	_ready_btn = _make_btn(p, "READY", self, "_on_ready_pressed")
	_ready_btn.visible = false

	_p2_waiting_label = _add_label(p, "Waiting for opponent...")

	_add_spacer(p, 8)
	_make_btn(p, "LEAVE", self, "_on_leave_pressed", true)
	return p


func _make_player_column(parent: Control, pid: int) -> VBoxContainer:
	var col = VBoxContainer.new()
	col.add_constant_override("separation", 6)
	parent.add_child(col)

	var name_lbl = _add_label(col, "P%d" % (pid + 1))
	name_lbl.align = Label.ALIGN_CENTER
	if pid == 0:
		_p1_name_label = name_lbl
	else:
		_p2_name_label = name_lbl

	var char_lbl = _add_label(col, "---")
	char_lbl.align = Label.ALIGN_CENTER
	char_lbl.add_color_override("font_color", Color(0.9, 0.7, 0.4, 1.0))
	if pid == 0:
		_p1_char_label = char_lbl
	else:
		_p2_char_label = char_lbl

	_add_spacer(col, 6)

	var char_title = _add_label(col, "Pick Character")
	char_title.align = Label.ALIGN_CENTER

	for i in _char_data.size():
		var c = _char_data[i]
		var cname = _extract_char_name(c)
		var btn = Button.new()
		btn.text = cname
		btn.rect_min_size = Vector2(0, 32)
		_style_btn(btn, false)
		var i_copy = i
		var pid_copy = pid
		btn.connect("pressed", self, "_on_char_btn_pressed", [pid_copy, i_copy])
		col.add_child(btn)

	return col

# ──────────────────────────────────────────────────────────────────────────────
# Panel helpers

func _make_panel() -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.add_constant_override("separation", 6)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.06, 0.06, 0.96)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	vbox.add_stylebox_override("panel", style)

	return vbox


func _add_title(parent: Control, text: String) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.align = Label.ALIGN_CENTER
	lbl.add_color_override("font_color", Color(1.0, 0.85, 0.6, 1.0))
	parent.add_child(lbl)
	return lbl


func _add_label(parent: Control, text: String) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_color_override("font_color", Color(0.9, 0.85, 0.85, 1.0))
	parent.add_child(lbl)
	return lbl


func _add_spacer(parent: Control, height: int):
	var s = Control.new()
	s.rect_min_size = Vector2(0, height)
	parent.add_child(s)


func _make_line_edit(parent: Control, placeholder: String) -> LineEdit:
	var le = LineEdit.new()
	le.placeholder_text = placeholder
	le.rect_min_size = Vector2(0, 36)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.03, 0.03, 1.0)
	style.border_color = Color(0.45, 0.15, 0.15, 1.0)
	style.set_border_width_all(1)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	le.add_stylebox_override("normal", style)
	le.add_color_override("font_color", Color(1, 1, 1, 1))
	parent.add_child(le)
	return le


func _make_btn(parent: Control, text: String, target: Object, method: String, muted := false) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.rect_min_size = Vector2(0, 40)
	_style_btn(btn, muted)
	btn.connect("pressed", target, method)
	parent.add_child(btn)
	return btn


func _style_btn(btn: Button, muted: bool):
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.22, 0.04, 0.04, 1.0) if not muted else Color(0.12, 0.04, 0.04, 1.0)
	normal.corner_radius_top_left = 4
	normal.corner_radius_top_right = 4
	normal.corner_radius_bottom_left = 4
	normal.corner_radius_bottom_right = 4
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	btn.add_stylebox_override("normal", normal)
	var hover = normal.duplicate()
	hover.bg_color = Color(0.34, 0.08, 0.08, 1.0) if not muted else Color(0.20, 0.06, 0.06, 1.0)
	btn.add_stylebox_override("hover", hover)
	var pressed_sb = normal.duplicate()
	pressed_sb.bg_color = Color(0.16, 0.03, 0.03, 1.0)
	btn.add_stylebox_override("pressed", pressed_sb)
	btn.add_color_override("font_color", Color(1, 1, 1, 1))


func _goto(state: int):
	_state = state
	for p in [_panel_main, _panel_host_setup, _panel_host_waiting, _panel_join, _panel_lobby]:
		if p:
			p.visible = false
	match state:
		State.MAIN:          _panel_main.visible = true
		State.HOST_SETUP:    _panel_host_setup.visible = true
		State.HOST_WAITING:  _panel_host_waiting.visible = true
		State.JOIN_SETUP:    _panel_join.visible = true
		State.LOBBY:         _panel_lobby.visible = true

# ──────────────────────────────────────────────────────────────────────────────
# Main panel callbacks

func _on_host_pressed():
	_goto(State.HOST_SETUP)

func _on_join_pressed():
	_goto(State.JOIN_SETUP)

func _on_quick_play_pressed():
	_join_code_edit.text = ""
	_join_status.text = "Enter the host's lobby code to connect."
	_goto(State.JOIN_SETUP)

func _on_back_pressed():
	_close_network()
	queue_free()
	Castagne.Menus.MCB_BackToMainMenu([null, Castagne.baseConfigData])

# ──────────────────────────────────────────────────────────────────────────────
# Host setup callbacks

func _on_host_setup_back_pressed():
	_goto(State.MAIN)

func _on_create_lobby_pressed():
	var pname = _host_name_edit.text.strip_edges()
	if pname.empty(): pname = "Player 1"
	var lname = _host_lobby_edit.text.strip_edges()
	if lname.empty(): lname = "Arena"

	_player_names[0] = pname
	_player_names[1] = ""
	_player_chars[0] = 0
	_player_chars[1] = 0
	_lobby_name = lname
	_is_host = true
	_client_peer_id = -1

	var peer = NetworkedMultiplayerENet.new()
	var err = peer.create_server(PORT, 1)
	if err != OK:
		_host_status.text = "Failed to create server (port %d in use?)" % PORT
		return

	get_tree().network_peer = peer
	_code_label.text = _get_local_ip()
	_host_status.text = "Waiting for opponent to connect..."
	_goto(State.HOST_WAITING)

func _on_cancel_hosting_pressed():
	_close_network()
	_goto(State.MAIN)

# ──────────────────────────────────────────────────────────────────────────────
# Join setup callbacks

func _on_join_back_pressed():
	_close_network()
	_goto(State.MAIN)

func _on_join_confirm_pressed():
	var pname = _join_name_edit.text.strip_edges()
	if pname.empty(): pname = "Player 2"
	var code = _join_code_edit.text.strip_edges()
	if code.empty():
		_join_status.text = "Please enter the lobby code."
		return

	_player_names[1] = pname
	_player_chars[0] = 0
	_player_chars[1] = 0
	_is_host = false

	var peer = NetworkedMultiplayerENet.new()
	var err = peer.create_client(code, PORT)
	if err != OK:
		_join_status.text = "Error: could not start connection. Is the IP correct?"
		return

	get_tree().network_peer = peer
	_join_status.text = "Connecting to %s..." % code

	_timeout_timer = Timer.new()
	_timeout_timer.wait_time = 8.0
	_timeout_timer.one_shot = true
	add_child(_timeout_timer)
	_timeout_timer.connect("timeout", self, "_on_connect_timeout")
	_timeout_timer.start()

# ──────────────────────────────────────────────────────────────────────────────
# Lobby callbacks

func _on_char_btn_pressed(pid: int, char_idx: int):
	var my_pid = 0 if _is_host else 1
	if pid != my_pid:
		return  # can't pick for the other player

	_player_chars[my_pid] = char_idx
	_update_lobby_ui()

	if _is_host:
		if _client_peer_id != -1:
			rpc_id(_client_peer_id, "_rpc_char_update", 0, char_idx)
	else:
		rpc_id(1, "_rpc_char_update", 1, char_idx)

func _on_ready_pressed():
	if not _is_host:
		return
	if _client_peer_id == -1:
		return
	rpc_id(_client_peer_id, "_rpc_start_match", _player_chars[0], _player_chars[1])
	_launch_match(_player_chars[0], _player_chars[1])

func _on_leave_pressed():
	_close_network()
	_goto(State.MAIN)

# ──────────────────────────────────────────────────────────────────────────────
# Network signals

func _on_connect_timeout():
	_timeout_timer = null
	if _state == State.JOIN_SETUP and not _is_host:
		_close_network()
		_join_status.text = "Could not reach host. Check the IP and firewall."

func _cancel_timeout():
	if _timeout_timer:
		_timeout_timer.stop()
		_timeout_timer.queue_free()
		_timeout_timer = null

func _net_peer_connected(peer_id: int):
	if _launching: return
	_cancel_timeout()
	if _is_host:
		_client_peer_id = peer_id
		_host_status.text = "Opponent connected!"
		rpc_id(peer_id, "_rpc_receive_lobby_info", _player_names[0], _lobby_name)
		_goto(State.LOBBY)
		_update_lobby_ui()
	else:
		# Successfully connected to host — wait for host to send lobby info
		pass

func _net_peer_disconnected(_peer_id: int):
	if _launching: return
	if _is_host:
		_client_peer_id = -1
		_player_names[1] = ""
		_player_chars[1] = 0
		if _state == State.LOBBY:
			_update_lobby_ui()
			_p2_waiting_label.text = "Opponent disconnected. Waiting..."
			_ready_btn.visible = false
	else:
		if _state == State.LOBBY:
			_goto(State.MAIN)
			call_deferred("_deferred_peer_close")

func _net_server_disconnected():
	if _launching: return
	_cancel_timeout()
	if _join_status:
		_join_status.text = "Host disconnected."
	if _state == State.LOBBY or _state == State.JOIN_SETUP:
		_goto(State.MAIN)
	# Defer the actual peer cleanup — calling close_connection() inside
	# a network signal causes "Object freed while signal emitted" errors.
	call_deferred("_deferred_peer_close")

func _deferred_peer_close():
	_is_host = false
	_client_peer_id = -1
	if get_tree().network_peer:
		get_tree().network_peer = null

# ──────────────────────────────────────────────────────────────────────────────
# RPCs  (must be remote so they can be called across the network)

remote func _rpc_receive_lobby_info(host_name: String, lob_name: String):
	_player_names[0] = host_name
	_lobby_name = lob_name
	# Send our info back to host
	rpc_id(1, "_rpc_receive_client_info", _player_names[1])
	_goto(State.LOBBY)
	_update_lobby_ui()

remote func _rpc_receive_client_info(client_name: String):
	_player_names[1] = client_name
	_update_lobby_ui()

remote func _rpc_char_update(pid: int, char_idx: int):
	_player_chars[pid] = char_idx
	_update_lobby_ui()

remote func _rpc_start_match(p1_char: int, p2_char: int):
	_launch_match(p1_char, p2_char)

# ──────────────────────────────────────────────────────────────────────────────
# Lobby UI update

func _update_lobby_ui():
	if _lobby_title:
		_lobby_title.text = _lobby_name

	if _p1_name_label:
		_p1_name_label.text = _player_names[0] if _player_names[0] != "" else "P1"
	if _p2_name_label:
		_p2_name_label.text = _player_names[1] if _player_names[1] != "" else "Waiting..."

	if _p1_char_label:
		_p1_char_label.text = _get_char_name(_player_chars[0])
	if _p2_char_label:
		_p2_char_label.text = _get_char_name(_player_chars[1])

	var opponent_connected = _player_names[1] != ""
	if _ready_btn:
		_ready_btn.visible = _is_host
		_ready_btn.disabled = not opponent_connected
	if _p2_waiting_label:
		_p2_waiting_label.visible = not opponent_connected and _is_host

# ──────────────────────────────────────────────────────────────────────────────
# Match launch

func _launch_match(p1_char_idx: int, p2_char_idx: int):
	if _launching:
		return
	_launching = true  # stop all network callbacks from this point on

	if _char_data.empty():
		return
	p1_char_idx = clamp(p1_char_idx, 0, _char_data.size() - 1)
	p2_char_idx = clamp(p2_char_idx, 0, _char_data.size() - 1)

	# "k1" = first keyboard. "empty" = no local input (remote player's slot).
	# Host machine controls P1. Client machine controls P2.
	var devices
	if _is_host:
		devices = ["k1", "empty"]
	else:
		devices = ["empty", "k1"]

	var css_args = {
		"SelectData": [
			{"Characters": [_char_data[p1_char_idx]], "Palettes": [0]},
			{"Characters": [_char_data[p2_char_idx]], "Palettes": [0]},
		],
		"Devices": devices,
		"Stage": 0,
		"ConfigData": Castagne.baseConfigData,
		"CallbackParams": {"Mode": Castagne.GAMEMODES.MODE_BATTLE},
	}

	# Defer one frame so the start-match RPC reaches the client before the
	# host closes the connection (closing the peer fires server_disconnected).
	call_deferred("_do_launch", css_args)

func _do_launch(css_args: Dictionary):
	_cancel_timeout()

	# Build the BID directly so we can disable auto-run before the engine ticks.
	var bid = css_args["ConfigData"] \
		.GetModuleSlot(Castagne.MODULE_SLOTS_BASE.FLOW) \
		.GetBattleInitDataFromCSS(css_args)
	bid["mode"] = css_args["CallbackParams"]["Mode"]
	if bid.get("exitcallback") == null:
		bid["exitcallback"] = funcref(Castagne.Menus, "MatchExitCallback_ToPostBattle")

	var engine = Castagne.InstanceCastagneEngine(bid, css_args["ConfigData"])
	# Disable automatic physics ticking — the sync node drives it instead.
	engine.runAutomatically = false

	var local_pid   = 0 if _is_host else 1
	# Host's remote peer = the client's assigned peer ID.
	# Client's remote peer = 1 (the server is always peer 1).
	var remote_peer = _client_peer_id if _is_host else 1

	var tree = get_tree()
	queue_free()

	tree.get_root().add_child(engine)

	# Online input sync — polls local KB, sends to remote, drives LocalStepCustomInput.
	var sync = load("res://castagne/helpers/menus/Multiplayer/online_input_sync.gd").new()
	sync.setup(engine, local_pid, remote_peer)
	tree.get_root().add_child(sync)

# ──────────────────────────────────────────────────────────────────────────────
# Helpers

func _close_network():
	if get_tree().network_peer:
		get_tree().network_peer.close_connection()
		get_tree().network_peer = null
	_is_host = false
	_client_peer_id = -1


func _get_local_ip() -> String:
	for addr in IP.get_local_addresses():
		if ":" in addr:
			continue
		if addr.begins_with("127."):
			continue
		if addr.begins_with("169.254."):
			continue
		return addr
	return "127.0.0.1"


func _extract_char_name(char_entry) -> String:
	var fp = char_entry.get("Character", {}).get("Filepath", "")
	if fp == "":
		return "???"
	var parts = fp.split("/")
	for i in range(parts.size() - 1, -1, -1):
		var part = parts[i]
		if part.get_extension() == "casp":
			return part.get_basename()
		if part != "" and i < parts.size() - 1:
			return part
	return fp.get_file().get_basename()


func _get_char_name(idx: int) -> String:
	if _char_data.empty() or idx < 0 or idx >= _char_data.size():
		return "---"
	return _extract_char_name(_char_data[idx])
