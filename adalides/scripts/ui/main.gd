extends Control
## Pantalla de prueba: simula un combate entre dos adalides y muestra el registro.

@onready var log_label: RichTextLabel = %Log
@onready var left_panel: Label = %Left
@onready var right_panel: Label = %Right
@onready var seed_spin: SpinBox = %Seed

var game: Game


func _ready() -> void:
	%Simulate.pressed.connect(_on_simulate)
	%NewGame.pressed.connect(_new_game)
	_new_game()


func _new_game() -> void:
	game = Game.new(["Ana", "Bruno"], int(seed_spin.value))
	log_label.text = "Partida nueva. Pulsa «Simular combate»."
	_refresh()


func _on_simulate() -> void:
	game.start_round()
	var combat := game.quick_combat(game.adalids[0], game.adalids[1])
	log_label.text = "\n".join(combat.log)
	_refresh()


func _refresh() -> void:
	left_panel.text = game.adalids[0].summary()
	right_panel.text = game.adalids[1].summary()
