extends "../elements/CME-List.gd"

var _texSelected = preload("res://castagne/assets/ui/menu-ui/UIboard2.png")
var _texNormal = preload("res://castagne/assets/ui/menu-ui/UIboard1.png")

const SLIDE_OUT_X = 391.0
const SLIDE_IN_X = 211.0
const SLIDE_DURATION = 0.15

var _isSelected = false
var _inSubOptions = false

func Setup():
	.Setup()
	$NameLabel.set_text(optionData["DisplayName"])

func _ready():
	if _isSelected:
		_SlideIn()
		_UpdateSubHighlights()

func OnSelect():
	_isSelected = true
	$NameLabel.set_text(">> " + optionData["DisplayName"] + " <<")
	_UpdateSubHighlights()
	_SlideIn()

func OnUnselect():
	_isSelected = false
	_inSubOptions = false
	$NameLabel.set_text(optionData["DisplayName"])
	_SlideOut()

func UpdateOptionDisplay():
	_UpdateSubHighlights()

func _UpdateSubHighlights():
	if listOptions == null:
		return
	for i in range($SubOptions.get_child_count()):
		var btn = $SubOptions.get_child(i)
		var bg = btn.get_node_or_null("BoardBG")
		var label = btn.get_node_or_null("Label")
		var selected = _inSubOptions and (i == selectedListOption)
		if bg:
			bg.texture = _texSelected if selected else _texNormal
		if label and i < listOptions.size():
			label.set_text(">> " + listOptions[i] + " <<" if selected else listOptions[i])

func _SlideIn():
	$Tween.stop_all()
	$Tween.interpolate_property($SubOptions, "rect_position:x",
		$SubOptions.rect_position.x, SLIDE_IN_X, SLIDE_DURATION,
		Tween.TRANS_QUAD, Tween.EASE_OUT)
	$Tween.interpolate_property($SubOptions, "modulate:a",
		$SubOptions.modulate.a, 1.0, SLIDE_DURATION,
		Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	$Tween.start()

func _SlideOut():
	$Tween.stop_all()
	$Tween.interpolate_property($SubOptions, "rect_position:x",
		$SubOptions.rect_position.x, SLIDE_OUT_X, SLIDE_DURATION,
		Tween.TRANS_QUAD, Tween.EASE_IN)
	$Tween.interpolate_property($SubOptions, "modulate:a",
		$SubOptions.modulate.a, 0.0, SLIDE_DURATION,
		Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	$Tween.start()

func UseMenuAction(actionType, extraData = null):
	if not _inSubOptions:
		# Right or Confirm on VS enters the sub-options at Local
		if actionType == "Right" or actionType == "Confirm":
			_inSubOptions = true
			selectedListOption = 0
			$NameLabel.set_text(optionData["DisplayName"])
			_UpdateSubHighlights()
			_PlayNavSound()
			return
		# Up/Down/Back fall through to navigate the main menu list
	else:
		if actionType == "Down":
			if selectedListOption < listOptions.size() - 1:
				SelectOption(selectedListOption + 1)
				_PlayNavSound()
			return
		if actionType == "Up":
			if selectedListOption > 0:
				SelectOption(selectedListOption - 1)
				_PlayNavSound()
			return
		if actionType == "Left":
			_inSubOptions = false
			$NameLabel.set_text(">> " + optionData["DisplayName"] + " <<")
			_UpdateSubHighlights()
			_PlayNavSound()
			return
		if actionType == "Confirm":
			# Fall through to fire MCB_MMVS with selectedListOption
			pass
	.UseMenuAction(actionType, extraData)

func _PlayNavSound():
	var sound = get_parent().get_parent().get_node_or_null("MenuSound")
	if sound:
		sound.play()
