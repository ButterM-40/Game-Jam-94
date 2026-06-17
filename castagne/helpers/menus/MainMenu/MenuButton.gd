extends "../elements/CME-Action.gd"

func Setup():
	.Setup()
	$ColorRect/Label.set_text(optionData["DisplayName"])

func OnSelect():
	$ColorRect/Label.set_text(">> " + optionData["DisplayName"] + " <<")

func OnUnselect():
	$ColorRect/Label.set_text(optionData["DisplayName"])
