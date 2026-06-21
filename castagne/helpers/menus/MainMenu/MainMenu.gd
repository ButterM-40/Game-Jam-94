# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends "../CastagneMenuCore.gd"

onready var _deviceSelect = $CanvasLayer/DeviceSelect
onready var _menuSound = $CanvasLayer/MenuSound
var _menuInitialized = false

func _ready():
	_configData = Castagne.baseConfigData
	if _menuSound != null and _menuSound.stream != null:
		_menuSound.stream = _menuSound.stream.duplicate()
		_menuSound.stream.loop = false
	var menuData = Castagne.baseConfigData.Get("MenuData-MainMenu").duplicate(true)
	menuData["DefaultElements"] = {
		Castagne.MENUS_ELEMENT_TYPES.ACTION: Castagne.Loader.Load("res://castagne/helpers/menus/elements/default/CMED-Action.tscn"),
		Castagne.MENUS_ELEMENT_TYPES.LIST: Castagne.Loader.Load("res://castagne/helpers/menus/elements/default/CMED-List.tscn"),
	}
	InitMenu(menuData, null)
	_PlayMenuMusic()
	_PoseCharacter($Model, "5C", 0.0)
	_PoseCharacter($Thala, "5C", 0.167)
	_menuInitialized = true

func Select(option, _extra=null):
	.Select(option, _extra)
	if _menuInitialized:
		_menuSound.play()

func _PoseCharacter(model, animName, seek):
	if model == null:
		return
	var animPlayer = model.get_node_or_null("AnimationPlayer")
	animPlayer.play(animName)
	animPlayer.seek(seek, true)
	animPlayer.stop(false)

func _PlayMenuMusic():
	if get_tree().get_nodes_in_group("MenuMusic").size() > 0:
		return
	var musicPlayer = AudioStreamPlayer.new()
	musicPlayer.set_script(load("res://castagne/modules/general/CMAudio_MusicPlayer.gd"))
	musicPlayer.add_to_group("MenuMusic")
	get_tree().get_root().add_child(musicPlayer)
	musicPlayer.InitFromData({
		"Filepath": "res://castagne/assets/music/maiin menu ttheme.mp3",
		"Volume": 0,
		"LoopStart": 0,
		"LoopEnd": 0,
	})
	musicPlayer.play()

func Setup(menuData, menuParams):
	for option in menuData["Options"]:
		if option["ScenePath"] == null:
			if option.get("Type", 0) == 1:
				option["ScenePath"] = "res://castagne/helpers/menus/MainMenu/VSMenuButton.tscn"
			else:
				option["ScenePath"] = "res://castagne/helpers/menus/MainMenu/MenuButton.tscn"
	.Setup(menuData, menuParams)

func MCB_MMTraining(_args):
	StartDeviceSelect(funcref(self, "TrainingStart"))
func MCB_MMVS(_args, selectedOption):
	if selectedOption == 0:
		StartDeviceSelect(funcref(self, "LocalBattleStart"))
	else:
		StartDeviceSelect(funcref(self, "VsCPUStart"))
func MCB_MMOptions(_args):
	queue_free()
	get_tree().get_root().add_child(Castagne.Menus.InstanceMenu("Options", null, _configData))


func _MatchCSSParamsCommon(devices, mode):
	return {
		"Devices": devices,
		"CallbackBack": FindMenuCallback("BackToMainMenu"),
		"CallbackBackParams": [null, _configData],
		"CallbackAdvance": FindMenuCallback("StartMatchFromCSS"),
		"CallbackAdvanceParams": {
			"Mode": mode,
		}
	}

func TrainingStart(devices):
	queue_free()
	var menuParams = _MatchCSSParamsCommon(devices, Castagne.GAMEMODES.MODE_TRAINING)
	get_tree().get_root().add_child(Castagne.Menus.InstanceMenu("CSS", menuParams, _configData))

func LocalBattleStart(devices):
	queue_free()
	var menuParams = _MatchCSSParamsCommon(devices, Castagne.GAMEMODES.MODE_BATTLE)
	get_tree().get_root().add_child(Castagne.Menus.InstanceMenu("CSS", menuParams, _configData))

func VsCPUStart(devices):
	queue_free()
	var menuParams = _MatchCSSParamsCommon([devices[0], null], Castagne.GAMEMODES.MODE_BATTLE)
	menuParams["CallbackAdvance"] = Castagne.Menus.FindMenuCallback("StartVsCPUFromCSS")
	get_tree().get_root().add_child(Castagne.Menus.InstanceMenu("CSS", menuParams, _configData))

func StartDeviceSelect(advanceCallback):
	_active = false
	_deviceSelect.Start(self, advanceCallback, funcref(self, "StopDeviceSelect"))

func StopDeviceSelect():
	_active = true
