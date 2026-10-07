extends Control
## Pantalla de prueba: partida de 6 adalides jugada por la IA, ronda a ronda.

@onready var log_label: RichTextLabel = %Log
@onready var standings: Label = %Standings
@onready var seed_spin: SpinBox = %Seed
@onready var play_button: Button = %PlayRound

const NAMES: PackedStringArray = ["Ana", "Bruno", "Carla", "Dani", "Eva", "Fito"]

var game: Game


func _ready() -> void:
	play_button.pressed.connect(_on_play_round)
	%NewGame.pressed.connect(_new_game)
	_new_game()


func _new_game() -> void:
	game = Game.new(NAMES, int(seed_spin.value))
	log_label.text = "Partida nueva con 6 adalides. Pulsa «Jugar ronda»."
	play_button.disabled = false
	_refresh()


func _on_play_round() -> void:
	if not game.play_round():
		return
	log_label.text = "\n".join(game.log)
	if game.is_over():
		play_button.disabled = true
	_refresh()


func _refresh() -> void:
	var lines: PackedStringArray = ["Ronda %d" % game.round_no]
	for a in game.adalids:
		lines.append(a.summary())
	standings.text = "\n".join(lines)
