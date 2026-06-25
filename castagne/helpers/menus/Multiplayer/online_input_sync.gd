extends Node

# Drives the CastagneEngine tick with synchronized two-player input.
# Both machines poll their own keyboard, send it to the other machine via RPC,
# and assemble [p1_input, p2_input] before calling LocalStepCustomInput.

var _engine       = null
var _local_pid    : int = 0   # 0 = host controls P1, 1 = client controls P2
var _remote_peer  : int = -1  # peer_id to send our input to
var _remote_raw   : Dictionary = {}
var _has_remote   := false

func setup(engine, local_pid: int, remote_peer: int) -> void:
	_engine      = engine
	_local_pid   = local_pid
	_remote_peer = remote_peer
	name = "OnlineInputSync"

func _physics_process(_delta) -> void:
	if _engine == null or not is_instance_valid(_engine):
		queue_free()
		return

	var ci = _engine.configData.Input()

	# Poll this machine's own player
	var local_device = "k1"
	if _engine.devicesToPoll.size() > _local_pid:
		local_device = _engine.devicesToPoll[_local_pid]
	var local_raw = ci.PollDevice(local_device)
	if local_raw == null:
		local_raw = {}

	# Send our input to the other machine
	if get_tree().network_peer and _remote_peer > 0:
		rpc_id(_remote_peer, "_recv_input", local_raw)

	# Neutral placeholder for the remote player until first packet arrives
	var empty_raw = ci.PollDevice("empty")
	if empty_raw == null:
		empty_raw = {}
	var remote_raw = _remote_raw if _has_remote else empty_raw

	# Assemble [p1_raw, p2_raw] and tick the engine
	var inputs : Array
	if _local_pid == 0:
		inputs = [local_raw, remote_raw]
	else:
		inputs = [remote_raw, local_raw]

	_engine.LocalStepCustomInput(inputs)

remote func _recv_input(raw: Dictionary) -> void:
	_remote_raw  = raw
	_has_remote  = true
