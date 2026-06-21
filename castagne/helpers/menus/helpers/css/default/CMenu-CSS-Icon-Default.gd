# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends "../CMenu-CSS-Icon.gd"

export var PathIcon = "Icon"
export var PathSelect = "Select"

var _activeSelections = 0

func Setup():
	if(character == null):
		for c in get_node(".").get_children():
			c.hide()
		return

	get_node(PathIcon).set_texture(Castagne.Loader.Load(character["CSS"]["Data"]["MENU_CSSIconPath"]))
	for c in get_node(PathSelect).get_children():
		c.hide()

	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;
uniform bool grayscale = true;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = mix(c, vec4(g, g, g, c.a), float(grayscale));
}
"""
	var mat = ShaderMaterial.new()
	mat.shader = shader
	get_node(PathIcon).material = mat
	_set_grayscale(true)

func SetSelect(pid, isSelected):
	get_node(PathSelect).get_child(pid).set_visible(isSelected)
	_activeSelections += (1 if isSelected else -1)
	_set_grayscale(_activeSelections <= 0)

func _set_grayscale(enabled):
	var icon = get_node(PathIcon)
	if icon.material != null:
		icon.material.set_shader_param("grayscale", enabled)
