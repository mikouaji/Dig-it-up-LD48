extends AudioStreamPlayer


const GOLD = "res://Sounds/coin.mp3"
const BUY = "res://Sounds/buy.mp3"
const CHEST = "res://Sounds/chest.mp3"
const LADDER = "res://Sounds/ladder.mp3"
const PICK = "res://Sounds/pick.mp3"
const SHOVEL = "res://Sounds/shovel.mp3"

var muted : bool = false

func oneTime(_type : String):
	if not muted:
		var toLoad = null
		match _type:
			"GOLD":
				toLoad = self.GOLD
			"BUY":
				toLoad = self.BUY
			"CHEST":
				toLoad = self.CHEST
			"LADDER":
				toLoad = self.LADDER
			"PICK":
				toLoad = self.PICK
			"SHOVEL":
				toLoad = self.SHOVEL
		if null != toLoad:
			self.stream = load(toLoad)
			self.play()


func _on_ToggleSound_pressed():
	self.muted = !self.muted
