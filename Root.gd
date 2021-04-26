extends Node

const LevelScene = preload("res://Map/Level.tscn")
const PlayerScene = preload("res://Player/Player.tscn")

const GENERATE_LEVELS : int = 5
const TIMED_GAME_DAYS : int = 100
const TIMED_GAME_GOLD : int = 1000000

const RANGE_COSTS = [25000,80000,150000]

var rng : RandomNumberGenerator = RandomNumberGenerator.new()

var levels : Array = []
var player : Area2D = null
var gold : int = 0
var days : int = 1
var timed : bool = false
var currentChest : int = 0
var started = false
var currentLevel : TileMap = null

var cellSize : Vector2 = Vector2.ZERO

func _ready():
	$Camera2D.position = Vector2(-256,-64)

func setCurrentLevel():
	self.currentLevel = self.levels[self.player.level]

func _input(event):
	if self.started and event is InputEventMouseButton and event.is_pressed():
		var onMapPosition = event.position + $Camera2D.position
		if self.inPlayerReach(onMapPosition):
			var shovelRange = self.player.shovelRange
			var coordRange = range(-1 * shovelRange +1 , shovelRange)
			for i in coordRange:
				for j in coordRange:
					var v = onMapPosition + Vector2(i,j) * self.cellSize
					self.currentLevel.digTile(v)

func generateLevel(_depth : int):
	var level = LevelScene.instance()
	self.cellSize = level.cell_size
	level.init(_depth, 0 == _depth, self.levels[_depth-1] if 0 != _depth else null, self.rng)
	self.levels.insert(_depth, level)
	add_child(level)
	move_child(level, 0)
	level.connect("chest",self,'onFoundChest')
	level.connect("dug",self,'updateShovel')
	level.cameraOffset = level.world_to_map($Camera2D.position)
	if 0 == _depth:
		level.fade("SHOW_UP")
		
func updateShovel(tilesDug : int):
	self.player.shovelDurability -= tilesDug
	if self.player.shovelDurability <=0:
		$InGameGUI/Shovel/PanelContainer/VBoxContainer/HBoxContainer2/Gold.text = str(self.gold)
		$InGameGUI/Shovel/PanelContainer/VBoxContainer/HBoxContainer/Days.text = str(self.days)
		$InGameGUI/Shovel.visible=true
		self.started = false
		self.player.paused = true
	$GUI/Game/Shovel/ProgressBar.max_value = self.player.shovelDurabilityMax
	$GUI/Game/Shovel/ProgressBar.value = self.player.shovelDurability
	
		
func onFoundChest(_level :int):
	_level +=1
	$SFX.oneTime("CHEST")
	self.currentChest = _level * 50
	self.currentChest += self.rng.randi_range(1, _level) * 11
	self.currentChest += self.rng.randi_range(1, _level) * 1000
	self.currentChest += self.rng.randi_range(33,127)
	$InGameGUI/Chest/PanelContainer/VBoxContainer/HBoxContainer/Gold.text = str(self.currentChest)
	$InGameGUI/Chest.visible = true
	self.started = false
	self.player.paused = true
		
func goLevelDown():
	var ladder = self.currentLevel.ladderDown
	self.player.level += 1
	self.setUILevel(self.player.level)
	if self.levels.size()-1 < self.player.level:
		for i in self.GENERATE_LEVELS:
			self.generateLevel(self.player.level +i)
			
	self.currentLevel.fade("HIDE_UP")
	self.currentLevel = self.levels[self.player.level]
	self.currentLevel.fade("SHOW_UP")
	self.currentLevel.placeLadderUp(ladder)
	
func goLevelUp():
	self.player.level -=1
	self.setUILevel(self.player.level)
	self.currentLevel.fade("HIDE_DOWN")
	self.currentLevel = self.levels[self.player.level]
	self.currentLevel.fade("SHOW_DOWN")

func onPickItem(_item : Area2D):
	match _item.type:
		"LADDER_DOWN":
			$SFX.oneTime("LADDER")
			self.goLevelDown()
		"LADDER_UP":
			$SFX.oneTime("LADDER")
			self.goLevelUp()
		"CHEST":
			pass
		"GOLD":
			$SFX.oneTime("GOLD")
			self.gold += self.giveGold()
			self.setUIGold()
			self.currentLevel.items.remove(self.currentLevel.items.find(_item))
			_item.queue_free()

func giveGold() -> int:
	var sum = 0
	var level = self.player.level + 1
	sum += level * 15
	sum += self.rng.randi_range(1, level)
	sum += self.rng.randf_range(1, level) * 25
	return sum

func inPlayerReach(position : Vector2) -> bool:
	var mouseTile = self.currentLevel.world_to_map(position)
	var playerTile = self.currentLevel.world_to_map(self.player.position)
	var inReach = [
		playerTile,
		playerTile + Vector2.LEFT,
		playerTile + Vector2.RIGHT,
		playerTile + Vector2.DOWN,
		playerTile + Vector2.UP,
	]
	for tile in inReach:
		if tile == mouseTile:
			return true
	return false



func _on_Quit_pressed():
	get_tree().quit()


func _on_Credits_pressed():
	$GUI/Main/Credits.visible = true
func _on_CreditsBack_pressed():
	$GUI/Main/Credits.visible = false


func _on_InstructionsBack_pressed():
	$GUI/Main/Instructions.visible = false
func _on_Instructions_pressed():
	$GUI/Main/Instructions.visible = true


func _on_DaysPlay_pressed():
	self.initGame(true)
func _on_FreePlay_pressed():
	self.initGame()


func initGame(_timed : bool = false):
	if not $Music.playing:
		$Music.play()
	self.freshLevelData()
	self.freshPlayerData()
	self.timed = _timed
	if self.timed:
		$GUI/Game/TimedLabel.visible = true
		$GUI/Game/TimedValue.visible = true
		$GUI/Game/TimedValue.text = str(self.TIMED_GAME_DAYS)
		$GUI/Game/DaysLabel.visible = false
		$GUI/Game/DaysValue.visible = false
	else:
		$GUI/Game/DaysLabel.visible = true
		$GUI/Game/DaysValue.visible = true
		$GUI/Game/DaysValue.text = str(0)
		$GUI/Game/TimedLabel.visible = false
		$GUI/Game/TimedValue.visible = false
	self.started = true
	$GUI/Splash.visible = false
	$GUI/Main.visible = false

func freshLevelData(onlyClear : bool = false):
	if not $Music.playing:
		$Music.play()
	self.setUILevel(0)
	self.currentLevel = null
	for l in self.levels:
		l.queue_free()
	self.levels = []
	if not onlyClear:
		for i in self.GENERATE_LEVELS:
			self.generateLevel(i)
		if null != self.player:
			self.player.level = 0
			self.setCurrentLevel()

func freshPlayerData(onlyClear : bool = false):
	self.gold = 0
	self.days = 1
	self.setUIDay()
	self.setUIGold()
	if null != self.player:
		self.player.queue_free()
		self.player = null
	if not onlyClear:
		self.player = PlayerScene.instance()
		add_child(self.player)
		self.player.init(0, self.cellSize)
		self.player.position = ( levels[0].DIM / 2 ) * self.cellSize - (self.cellSize / 2)
		self.setCurrentLevel()
		self.updateShovel(0)
		self.player.connect("moved", self, 'playerMoved')

func playerMoved():
	self.currentLevel.lastPosition = Vector2.INF

func setUILevel(lvl : int):
	$GUI/Game/LevelValue.text = str(lvl)

func setUIDay():
	$GUI/Game/DaysValue.text = str(self.days)
	$GUI/Game/TimedValue.text = str(self.TIMED_GAME_DAYS - self.days)
	if self.timed and self.days >= 100:
		self.started = false
		self.player.paused = true
		$InGameGUI/Timed/PanelContainer/VBoxContainer/Win.visible = false
		$InGameGUI/Timed/PanelContainer/VBoxContainer/Lose.visible = true
		$InGameGUI/Timed/PanelContainer/VBoxContainer/HBoxContainer/Gold.text = str(self.gold)
		$InGameGUI/Timed/PanelContainer/VBoxContainer/HBoxContainer2/Days.text = str(self.days)
		$InGameGUI/Timed.visible = true

func setUIGold():
	$GUI/Game/GoldValue.text = str(self.gold)
	if self.timed and self.gold >= 1000000:
		self.started = false
		self.player.paused = true
		$InGameGUI/Timed/PanelContainer/VBoxContainer/Win.visible = true
		$InGameGUI/Timed/PanelContainer/VBoxContainer/Lose.visible = false
		$InGameGUI/Timed/PanelContainer/VBoxContainer/HBoxContainer/Gold.text = str(self.gold)
		$InGameGUI/Timed/PanelContainer/VBoxContainer/HBoxContainer2/Days.text = str(self.days)
		$InGameGUI/Timed.visible = true

func _on_MainMenu_pressed():
	self.started = false
	$InGameGUI/Shovel.visible=false
	$InGameGUI/Timed.visible=false
	$GUI/Splash.visible = true
	$GUI/Main.visible = true
	self.freshLevelData(true)
	self.freshPlayerData(true)


func _on_ToggleSound_pressed():
	var txt = $GUI/Game/ToggleSound.text
	$GUI/Game/ToggleSound.text = "Turn sound on" if txt == "Turn sound off" else "Turn sound off"


func _on_ChestCollect_pressed():
	self.gold += self.currentChest
	self.setUIGold()
	self.freshLevelData()
	self.days +=1
	$SFX.oneTime("GOLD")
	self.setUIDay()
	$InGameGUI/Chest.visible = false
	self.started = true
	self.player.paused = false


func _on_ChestContinue_pressed():
	self.currentChest = 0
	self.currentLevel.removeChest()
	$InGameGUI/Chest.visible = false
	self.started = true
	self.player.paused = false


func _on_RopeButton_pressed():
	if self.player.rope:
		for i in self.player.level:
			self.goLevelUp()
		self.player.rope = false
		$GUI/Game/Rope/Button.disabled = true

func openShop():
	var disableRope = self.gold < 150 or player.rope
	$InGameGUI/Shop/PanelContainer/VBoxContainer/Rope/Buy.disabled = disableRope
	var fixPrice = self.player.shovelDurabilityMax / 2
	$InGameGUI/Shop/PanelContainer/VBoxContainer/Fix/Price.text = str(fixPrice)
	var disableFix = self.gold < fixPrice
	$InGameGUI/Shop/PanelContainer/VBoxContainer/Fix/Buy.disabled = disableFix
	var durabilityPrice = self.player.shovelDurabilityMax * 10
	$InGameGUI/Shop/PanelContainer/VBoxContainer/Upgrade/Price.text = str(durabilityPrice)
	var disableDur = self.gold < durabilityPrice
	$InGameGUI/Shop/PanelContainer/VBoxContainer/Upgrade/Buy.disabled = disableDur
	if self.player.shovelRange >= 4:
		$InGameGUI/Shop/PanelContainer/VBoxContainer/Range.visible = false
	else:
		$InGameGUI/Shop/PanelContainer/VBoxContainer/Range.visible = true
		var price = self.RANGE_COSTS[self.player.shovelRange -1]
		$InGameGUI/Shop/PanelContainer/VBoxContainer/Range/Price.text = str(price)
		var disableRange = self.gold < price
		$InGameGUI/Shop/PanelContainer/VBoxContainer/Range/Buy.disabled = disableRange
	$InGameGUI/Shop.visible=true
	self.started = false

func closeShop():
	$InGameGUI/Shop.visible=false
	self.started = true


func _on_RopeBuy_pressed():
	$SFX.oneTime("BUY")
	self.gold-=150
	self.setUIGold()
	$InGameGUI/Shop/PanelContainer/VBoxContainer/Rope/Buy.disabled = true
	self.player.rope = true
	$GUI/Game/Rope/Button.disabled = false
	self.closeShop()
	self.openShop()

func _on_ShovelFix_pressed():
	$SFX.volume_db = 10
	$SFX.oneTime("BUY")
	$SFX.volume_db = -10
	self.gold -= self.player.shovelDurabilityMax / 2
	self.player.shovelDurability = self.player.shovelDurabilityMax
	self.setUIGold()
	self.updateShovel(0)
	self.closeShop()
	self.openShop()

func _on_ShovelDurability_pressed():
	self.gold -= self.player.shovelDurabilityMax * 10
	self.player.shovelDurabilityMax = self.player.shovelDurabilityMax*2
	self.player.shovelDurability = self.player.shovelDurabilityMax
	self.setUIGold()
	self.updateShovel(0)
	$SFX.oneTime("BUY")
	self.closeShop()
	self.openShop()


func _on_ShovelRange_pressed():
	$SFX.oneTime("BUY")
	self.gold -=self.RANGE_COSTS[self.player.shovelRange -1]
	self.player.shovelRange +=1
	self.setUIGold()
	self.closeShop()
	self.openShop()


func _on_ToggleMusic_pressed():
	var txt = $GUI/Game/ToggleMusic.text
	$GUI/Game/ToggleMusic.text = "Turn music on" if txt == "Turn music off" else "Turn music off"
	if not $Music.playing:
		$Music.play()
	else:
		$Music.stop()
