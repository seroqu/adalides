extends SceneTree
## Imprime un combate de ejemplo. Uso:
##   godot --headless --path adalides -s tests/demo_combat.gd [-- semilla]

func _init() -> void:
	var seed_value := 2026
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		seed_value = int(args[0])
	var game := Game.new(["Ana", "Bruno"], seed_value)
	game.start_round()
	var combat := game.quick_combat(game.adalids[0], game.adalids[1])
	for line in combat.log:
		print(line)
	print("")
	for a in game.adalids:
		print(a.summary())
	quit(0)
