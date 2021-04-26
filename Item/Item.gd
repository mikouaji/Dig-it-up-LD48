extends Area2D

const TYPE_CHEST = "CHEST"
const TYPE_GOLD = "GOLD"
const TYPE_LADDER_DOWN = "LADDER_DOWN"
const TYPE_LADDER_UP = "LADDER_UP"

var type : String = ""


const PlayerScene = preload("res://Player/Player.tscn")

func init(_type : String):
	self.type = _type
	find_node(self.type).visible = true

signal entered

func _on_Item_area_entered(area):
	if area.get_filename() == PlayerScene.get_path():
		if get_parent().visible and not get_parent().get_node('Tween').is_active():
			emit_signal("entered", self)
