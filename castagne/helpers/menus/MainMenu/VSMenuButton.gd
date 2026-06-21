extends "../elements/CME-List.gd"

func Setup():
	.Setup()
	$NameLabel.set_text(optionData["DisplayName"])

func OnSelect():
	$NameLabel.set_text(">> " + optionData["DisplayName"] + " <<")

func OnUnselect():
	$NameLabel.set_text(optionData["DisplayName"])

func UpdateOptionDisplay():
	$OptionLabel.set_text("< " + listOptions[selectedListOption] + " >")

func SelectNextOption(_p, _extra=null):
	SelectOption((selectedListOption + 1) % listOptions.size())
	_PlayNavSound()

func SelectPreviousOption(_p, _extra=null):
	SelectOption((selectedListOption - 1 + listOptions.size()) % listOptions.size())
	_PlayNavSound()

func _PlayNavSound():
	var sound = get_parent().get_parent().get_node_or_null("MenuSound")
	if sound:
		sound.play()
