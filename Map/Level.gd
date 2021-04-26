extends TileMap

const DIM : int = 10

const ALPHA_STEP : float = 0.05

const GRASS_TILES : Array = [0,1]
const GROUND_TILES : Array = [3,4]
const BORDER_TILE : int = 2
const GRASS_BORDER_TILE : int = 6
const GROUND_BORDER_TILE : int = 7
const HOLE_TILE : int = 5

const SHADOW_OK = 0
const SHADOW_BAD = 1

var treasure : Vector2 = Vector2.INF
var ladderDown : Vector2 = Vector2.INF
var ladderUp : Vector2 = Vector2.INF
var depth : int = -1

var luck = 10
var items = []
var cameraOffset : Vector2 = Vector2.ZERO
var lastPosition : Vector2 = Vector2.INF

const ItemScene = preload("res://Item/Item.tscn")
const ShopScene = preload("res://Item/Shop.tscn")
const SHOP_POSITION : Vector2 = Vector2(3, -1)

func _ready():
	pass
	
func init(_depth : int, _enableCollision : bool, _upperLevel : TileMap, _rng : RandomNumberGenerator):
	self.depth = _depth
	self.set_collision_layer_bit(0, _enableCollision)
	self.visible = false
	for x in self.DIM+2:
		for y in self.DIM+2:
			set_cell(x-1,y-1,self.GRASS_BORDER_TILE if 0 == _depth else self.GROUND_BORDER_TILE)
	_rng.randomize()
	for x in self.DIM:
		for y in self.DIM:
			if 0 == _depth:
				set_cell(x, y, _rng.randi_range(self.GRASS_TILES[0], self.GRASS_TILES[1]))
			else:
				set_cell(x, y, _rng.randi_range(self.GROUND_TILES[0], self.GROUND_TILES[1]))
	if null == _upperLevel:
		var x = _rng.randi_range(0, self.DIM-1)
		var y = _rng.randi_range(0, self.DIM-1)
		self.treasure = Vector2(x,y)
		while self.treasure == Vector2(x,y):
			x = _rng.randi_range(0, self.DIM-1)
			y = _rng.randi_range(0, self.DIM-1)
		self.ladderDown = Vector2(x,y)
	else:
		var used = [_upperLevel.treasure, _upperLevel.ladderDown]
		self.ladderUp = _upperLevel.ladderDown
		var x = _rng.randi_range(0, self.DIM-1)
		var y = _rng.randi_range(0, self.DIM-1)
		while Vector2(x,y) in used:
			x = _rng.randi_range(0, self.DIM-1)
			y = _rng.randi_range(0, self.DIM-1)
		self.treasure = Vector2(x,y)
		used.append(self.treasure)
		while Vector2(x,y) in used:
			x = _rng.randi_range(0, self.DIM-1)
			y = _rng.randi_range(0, self.DIM-1)
		self.ladderDown = Vector2(x,y)
	self.position += Vector2.DOWN * self.cell_size
	
	if self.depth == 0:
		var shop = ShopScene.instance()
		add_child(shop)
		shop.position = map_to_world(self.SHOP_POSITION) + self.cell_size / 2
		shop.connect("area_entered",self,'openShop')
		shop.connect("area_exited",self,'closeShop')

func openShop(area):
	if area == get_parent().player:
		get_parent().openShop()
func closeShop(area):
	if area == get_parent().player:
		get_parent().closeShop()

const SHOW_UP : String = "SHOW_UP"
const HIDE_UP : String = "HIDE_UP"
const SHOW_DOWN : String = "SHOW_DOWN"
const HIDE_DOWN : String = "HIDE_DOWN"

func fade(_direction : String):
	var show = _direction in [self.SHOW_DOWN, self.SHOW_UP]
	var up = _direction in [self.HIDE_UP, self.SHOW_UP]
	var alphaStart = 0.0
	var alphaEnd = 0.0
	if show:
		self.visible = true
		alphaStart = 0.0
		alphaEnd = 1.0
		self.enableCollision()
	else:
		alphaStart = 1.0
		alphaEnd = 0.0
		self.disableCollision()
	var moveVector = Vector2.UP if up else Vector2.DOWN
	$Tween.interpolate_property(
		self, 
		'position', 
		self.position, 
		self.position + (moveVector * self.cell_size), 
		0.3,
		Tween.TRANS_SINE,
		Tween.EASE_IN_OUT)
	$Tween.interpolate_property(
		self.material, 
		'shader_param/custom_alpha', 
		alphaStart, 
		alphaEnd, 
		0.3,
		Tween.TRANS_SINE,
		Tween.EASE_IN_OUT)
	$Tween.start()
	if not show:
		yield($Tween, "tween_completed")
		self.visible = false

signal chest
signal dug


func digTile(_position : Vector2):
	var pos = world_to_map(_position)
	var unavailable = [self.BORDER_TILE, self.HOLE_TILE, self.GRASS_BORDER_TILE, self.GROUND_BORDER_TILE]
	if not get_cellv(pos) in unavailable and not pos == self.ladderUp:
		if pos.x in range(-1, self.DIM+1) and pos.y in range(-1, self.DIM+1):
			get_parent().get_node("SFX").oneTime("SHOVEL")
			set_cellv(pos, self.HOLE_TILE)
			emit_signal("dug", 1)
			update_bitmask_region()
			if self.treasure == pos:
				self.spawnItem("CHEST", map_to_world(pos))
				emit_signal("chest", self.depth)
			elif self.ladderDown == pos:
				self.spawnItem("LADDER_DOWN", map_to_world(pos))
			elif get_parent().rng.randi_range(0,100) <= self.luck:
				self.spawnItem("GOLD", map_to_world(pos))

func spawnItem(_type : String, _position : Vector2):
	var item = ItemScene.instance()
	item.init(_type)
	call_deferred('add_child', item)
	item.position = _position + self.cell_size / 2
	item.connect("entered", get_parent(), 'onPickItem')
	self.items.append(item)

func placeLadderUp(_position : Vector2):
	self.ladderUp = _position
	self.spawnItem("LADDER_UP", map_to_world(self.ladderUp))

func enableCollision():
	self.set_collision_layer_bit(0,true)
func disableCollision():
	self.set_collision_layer_bit(0,false)

func removeChest():
	for i in self.items:
		if i.type == "CHEST":
			self.items.remove(self.items.find(i))
			i.queue_free()
			
func _input(event):
	if event is InputEventMouseMotion:
		self.refreshShadow(event.position)

func refreshShadow(mousePosition : Vector2):
	var _position = self.cameraOffset + world_to_map(mousePosition)
	if _position.x in range(-1, self.DIM+1) and _position.y in range(-1, self.DIM+1):
		if self.lastPosition != _position:
			$Shadow.set_cellv(self.lastPosition, -1)
			self.lastPosition = _position
			var inRange = get_parent().inPlayerReach(map_to_world(self.lastPosition)) and (
				self.lastPosition != self.ladderUp) and (
					not get_cellv(self.lastPosition) in [self.BORDER_TILE, self.HOLE_TILE, self.GRASS_BORDER_TILE, self.GROUND_BORDER_TILE])
			$Shadow.set_cellv(self.lastPosition, self.SHADOW_OK if inRange else self.SHADOW_BAD)
	else:
		$Shadow.set_cellv(self.lastPosition, -1)
