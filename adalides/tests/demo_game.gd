extends SceneTree
## Juega una partida completa de 6 adalides y la imprime. Uso:
##   godot --headless --path adalides -s tests/demo_game.gd [-- semilla]

func _init() -> void:
	var seed_value := 2026
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		seed_value = int(args[0])
	var game := Game.new(["Ana", "Bruno", "Carla", "Dani", "Eva", "Fito"], seed_value)
	while game.play_round():
		for line in game.log:
			print(line)
		print("")
	quit(0)
