extends Node


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	var configData = Castagne.Menus.In
	var menuData = Castagne.Menus.GetMenuData("MainMenu")
	
	var menu = get_node("YourMainMenuNode")
	menu._configData = configData
	menu.InitMenu(menuData, null)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
