extends "../elements/CME-Action.gd"

func Setup():
	.Setup()
	$Label.set_text(optionData["DisplayName"])

func OnSelect():
	$Label.set_text(">> " + optionData["DisplayName"] + " <<")

func OnUnselect():
	$Label.set_text(optionData["DisplayName"])
