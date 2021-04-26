extends Area2D

var tileSize : Vector2 = Vector2.ZERO
var direction : Vector2 = Vector2.ZERO
var movementSpeed : float = 0.4

var level = 0

var shovelRange = 1
var shovelDurabilityMax = 250
var shovelDurability = 250
var rope = false

var paused = false

func _ready():
	pass

func init(_level : int, _cellSize : Vector2):
	self.level = _level
	self.tileSize = _cellSize

func _input(event):
	if not self.paused:
		if event is InputEventKey and event.is_pressed():
			self.move()
	
signal moved
	
func move():
	if $Tween.is_active():
		return
	if Input.is_action_pressed('ui_right'):
		self.direction = Vector2.RIGHT
	if Input.is_action_pressed('ui_left'):
		self.direction = Vector2.LEFT
	if Input.is_action_pressed('ui_down'):
		self.direction = Vector2.DOWN
	if Input.is_action_pressed('ui_up'):
		self.direction = Vector2.UP
	var positionVector = self.direction * self.tileSize
	$RayCast2D.cast_to = positionVector
	$RayCast2D.force_raycast_update()
	if not $RayCast2D.is_colliding():
		$AnimatedSprite.play('walk')
		$Tween.interpolate_property(
			self, 
			'position', 
			self.position, 
			self.position + positionVector, 
			self.movementSpeed,
			Tween.TRANS_SINE,
			Tween.EASE_IN_OUT)
		$Tween.start()
		yield($Tween, "tween_completed")
		$AnimatedSprite.play('idle')
		emit_signal("moved")
