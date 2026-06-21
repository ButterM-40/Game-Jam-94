extends CanvasLayer

#Logos
var JamLogo = preload("res://castagne/helpers/menus/Bootsplash Scenes/GWJ94Mutation.jpg")
var GameLogo = preload("res://castagne/helpers/menus/Bootsplash Scenes/MutantArena.jpg")
var PresentedBy = preload("res://castagne/helpers/menus/Bootsplash Scenes/presentedby.jpg")

var Logos = [
	JamLogo,
	GameLogo,
	PresentedBy
]
var curr = 0
#Scene Variables
onready var texture_rect = $TextureRect
onready var anim = $AnimationPlayer

# Called when the node enters the scene tree for the first time.
func _ready():
	texture_rect.texture = Logos[curr]
	anim.play("Fade In")  # your fade animation
	
	pass # Replace with function body.

func _on_AnimationPlayer_animation_finished(anim_name):
	curr += 1
	if (curr < Logos.size()):
		texture_rect.texture = Logos[curr]
		anim.play("Fade In")
	else:
		get_tree().change_scene("res://castagne/helpers/menus/MainMenu/MainMenu.tscn")
	pass # Replace with function body.
