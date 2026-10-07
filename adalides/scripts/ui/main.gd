extends Control
## Pantalla de partida: tú eres uno de los seis adalides; el resto los lleva la IA.
## La interfaz se construye en código para no depender del formato .tscn.

const NAMES: PackedStringArray = ["Tú", "Bruno", "Carla", "Dani", "Eva", "Fito"]

var game: Game
var seed_spin: SpinBox
var standings: Label
var log_label: RichTextLabel
var phase_title: Label
var panels: Dictionary = {} # Game.State → Control

# Tienda
var shop_box: HBoxContainer
var reserve_list: ItemList
var sell_button: Button
var level_button: Button
var ransom_button: Button
# Alineación
var lineup_source: ItemList
var slot_buttons: Array[Button] = []
var lineup: Array = [] # Champion o null por casilla
var lineup_errors: Label
# Combate
var combat_title: Label
var foe_board_label: RichTextLabel
var my_board_label: RichTextLabel
var dp_box: HBoxContainer
var da_box: HBoxContainer
var pairs_label: Label
var reveal_button: Button
var pairs: Array = [] # [dp, da]
var selected_dp: int = -1
var used_dp: Array[int] = []
var used_da: Array[int] = []


func _ready() -> void:
	_build_ui()
	_new_game()
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2 and args[0] == "--screenshots":
		_screenshot_tour(args[1])


## Recorre las fases y guarda una captura de cada una (para revisar la UI sin abrirla).
func _screenshot_tour(dir: String) -> void:
	await _snap(dir.path_join("1_tienda.png"))
	if game.state == Game.State.SHOPPING and not game.shop.is_empty():
		game.human_buy(game.shop[0])
		_refresh_shop()
		_refresh()
		await _snap(dir.path_join("2_tienda_compra.png"))
		game.finish_shopping()
		_start_lineup()
		await _snap(dir.path_join("3_alineacion.png"))
		_on_lineup_done()
	if game.state == Game.State.COMBAT:
		_on_dp_pressed(0)
		await _snap(dir.path_join("4_combate_dp.png"))
		if selected_dp >= 0:
			_on_da_pressed(0)
		await _snap(dir.path_join("5_combate_pareja.png"))
		_on_reveal()
		await _snap(dir.path_join("6_combate_resuelto.png"))
	get_tree().quit()


func _snap(path: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)


# ---------------------------------------------------------------- construcción

func _build_ui() -> void:
	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 420
	left.size_flags_horizontal = Control.SIZE_FILL
	root.add_child(left)
	var title := Label.new()
	title.text = "Adalides"
	title.add_theme_font_size_override("font_size", 22)
	left.add_child(title)
	var controls := HBoxContainer.new()
	left.add_child(controls)
	var seed_label := Label.new()
	seed_label.text = "Semilla"
	controls.add_child(seed_label)
	seed_spin = SpinBox.new()
	seed_spin.max_value = 999999
	seed_spin.custom_minimum_size.x = 120
	controls.add_child(seed_spin)
	var new_button := Button.new()
	new_button.text = "Partida nueva"
	new_button.pressed.connect(_new_game)
	controls.add_child(new_button)
	standings = Label.new()
	left.add_child(standings)
	left.add_child(_label("Registro"))
	log_label = RichTextLabel.new()
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.scroll_following = true
	left.add_child(log_label)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	root.add_child(right)
	phase_title = Label.new()
	phase_title.add_theme_font_size_override("font_size", 20)
	right.add_child(phase_title)

	panels[Game.State.SHOPPING] = _build_shop_panel()
	panels[Game.State.LINEUP] = _build_lineup_panel()
	panels[Game.State.COMBAT] = _build_combat_panel()
	panels[Game.State.ROUND_END] = _build_round_end_panel()
	panels[Game.State.OVER] = _build_over_panel()
	for p in panels.values():
		p.size_flags_vertical = Control.SIZE_EXPAND_FILL
		right.add_child(p)


func _build_shop_panel() -> Control:
	var box := VBoxContainer.new()
	box.add_child(_label("Tienda — pulsa una carta para comprarla"))
	shop_box = HBoxContainer.new()
	shop_box.add_theme_constant_override("separation", 8)
	box.add_child(shop_box)
	box.add_child(_label("Tu reserva"))
	reserve_list = ItemList.new()
	reserve_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(reserve_list)
	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	sell_button = Button.new()
	sell_button.text = "Vender seleccionada"
	sell_button.pressed.connect(_on_sell)
	buttons.add_child(sell_button)
	level_button = Button.new()
	level_button.pressed.connect(func() -> void:
		game.human_level_up()
		_refresh())
	buttons.add_child(level_button)
	ransom_button = Button.new()
	ransom_button.text = "Pagar rescate (%d)" % Rules.RANSOM_COST
	ransom_button.pressed.connect(func() -> void:
		game.human_pay_ransom()
		_refresh())
	buttons.add_child(ransom_button)
	var done := Button.new()
	done.text = "Terminar compras →"
	done.pressed.connect(func() -> void:
		game.finish_shopping()
		_start_lineup())
	buttons.add_child(done)
	return box


func _build_lineup_panel() -> Control:
	var box := VBoxContainer.new()
	box.add_child(_label("Alineación — pulsa una carta de la reserva para ponerla en el mapa; pulsa una casilla para vaciarla"))
	lineup_source = ItemList.new()
	lineup_source.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lineup_source.item_activated.connect(_on_lineup_pick)
	lineup_source.item_selected.connect(_on_lineup_pick)
	box.add_child(lineup_source)
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 6)
	box.add_child(slots)
	for i in Rules.BOARD_SIZE:
		var b := Button.new()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_slot_clear.bind(i))
		slots.add_child(b)
		slot_buttons.append(b)
	lineup_errors = Label.new()
	lineup_errors.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(lineup_errors)
	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	var auto := Button.new()
	auto.text = "Alinear automáticamente"
	auto.pressed.connect(func() -> void:
		lineup = Roster.auto_pick(game.human)
		lineup.resize(Rules.BOARD_SIZE)
		_refresh_lineup())
	buttons.add_child(auto)
	var go := Button.new()
	go.text = "¡Al combate! →"
	go.pressed.connect(_on_lineup_done)
	buttons.add_child(go)
	return box


func _build_combat_panel() -> Control:
	var box := VBoxContainer.new()
	combat_title = Label.new()
	box.add_child(combat_title)
	var boards := HBoxContainer.new()
	boards.add_theme_constant_override("separation", 16)
	box.add_child(boards)
	foe_board_label = RichTextLabel.new()
	foe_board_label.bbcode_enabled = true
	foe_board_label.custom_minimum_size.y = 190
	foe_board_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boards.add_child(foe_board_label)
	my_board_label = RichTextLabel.new()
	my_board_label.bbcode_enabled = true
	my_board_label.custom_minimum_size.y = 190
	my_board_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boards.add_child(my_board_label)
	box.add_child(_label("Tus dados de posición (DP): elige uno y luego un DA. Un DP sobre un congelado lo libera."))
	dp_box = HBoxContainer.new()
	dp_box.add_theme_constant_override("separation", 6)
	box.add_child(dp_box)
	box.add_child(_label("Tus dados de acción (DA)"))
	da_box = HBoxContainer.new()
	da_box.add_theme_constant_override("separation", 6)
	box.add_child(da_box)
	pairs_label = Label.new()
	pairs_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(pairs_label)
	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	var undo := Button.new()
	undo.text = "Deshacer parejas"
	undo.pressed.connect(func() -> void:
		_reset_pairs()
		_refresh_combat())
	buttons.add_child(undo)
	var auto := Button.new()
	auto.text = "Emparejar automáticamente"
	auto.pressed.connect(func() -> void:
		_reset_pairs()
		for pair in game.current_combat.auto_pairs(0):
			_add_pair(pair[0], pair[1])
		_refresh_combat())
	buttons.add_child(auto)
	reveal_button = Button.new()
	reveal_button.text = "Revelar acciones →"
	reveal_button.pressed.connect(_on_reveal)
	buttons.add_child(reveal_button)
	return box


func _build_round_end_panel() -> Control:
	var box := VBoxContainer.new()
	box.add_child(_label("Ronda terminada. Revisa el registro y continúa."))
	var next := Button.new()
	next.text = "Siguiente ronda →"
	next.pressed.connect(_next_round)
	box.add_child(next)
	return box


func _build_over_panel() -> Control:
	var box := VBoxContainer.new()
	var l := Label.new()
	l.name = "Result"
	l.add_theme_font_size_override("font_size", 24)
	box.add_child(l)
	return box


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	return l


# ---------------------------------------------------------------- flujo

func _new_game() -> void:
	game = Game.new(NAMES, int(seed_spin.value))
	game.set_human(0)
	_next_round()


func _next_round() -> void:
	if not game.begin_round():
		_refresh()
		return
	if game.state == Game.State.SHOPPING:
		_refresh_shop()
	_refresh()


func _start_lineup() -> void:
	lineup = Roster.auto_pick(game.human)
	lineup.resize(Rules.BOARD_SIZE)
	_refresh_lineup()
	_refresh()


func _on_lineup_done() -> void:
	var chosen: Array[Champion] = []
	for ch in lineup:
		if ch != null:
			chosen.append(ch)
	var errors := game.set_lineup(chosen)
	if not errors.is_empty():
		lineup_errors.text = "\n".join(errors)
		return
	_enter_state()


func _enter_state() -> void:
	match game.state:
		Game.State.COMBAT:
			_reset_pairs()
			_refresh_combat()
		Game.State.OVER:
			var res: Label = panels[Game.State.OVER].get_node("Result")
			var w := game.winner()
			res.text = "¡Eres el nuevo demiurgo!" if w == game.human else (
				"Has sido eliminado. Gana %s." % (w.display_name if w != null else "nadie"))
	_refresh()


func _on_reveal() -> void:
	game.commit_human_pairs(pairs)
	_enter_state()


# ---------------------------------------------------------------- tienda

func _on_sell() -> void:
	var sel := reserve_list.get_selected_items()
	if sel.is_empty():
		return
	game.human_sell(game.human.reserve[sel[0]])
	_refresh_shop()
	_refresh()


func _refresh_shop() -> void:
	for c in shop_box.get_children():
		c.queue_free()
	for card in game.shop:
		var b := Button.new()
		b.text = "%s\n%s\n%s · %d/%d\n%d Éter" % [card.display_name, _classes(card),
			Rules.tier_label(card.tier), card.attack, card.defense, card.cost]
		b.tooltip_text = card.notes if card.notes != "" else Rules.tier_label(card.tier)
		b.disabled = not game.human.can_pay(card.cost)
		b.pressed.connect(func() -> void:
			game.human_buy(card)
			_refresh_shop()
			_refresh())
		shop_box.add_child(b)
	reserve_list.clear()
	for ch in game.human.reserve:
		var tag := " [secuestrado]" if ch == game.human.kidnapped else ""
		reserve_list.add_item("%s — vender por %d%s" % [_champion_text(ch), game.human.sell_value(ch), tag])
	level_button.text = "Subir a nivel %d (%d Éter)" % [game.human.level + 1, Rules.LEVEL_UP_COST]
	level_button.disabled = not game.human.can_level_up()
	ransom_button.visible = game.human.kidnapped != null
	ransom_button.disabled = not game.human.can_pay(Rules.RANSOM_COST)


# ---------------------------------------------------------------- alineación

func _on_lineup_pick(index: int) -> void:
	var usable := game.human.usable_cards()
	if index < 0 or index >= usable.size():
		return
	var ch: Champion = usable[index]
	if lineup.has(ch):
		return
	var free := lineup.find(null)
	if free < 0:
		lineup_errors.text = "El mapa está lleno; vacía una casilla primero."
		return
	lineup[free] = ch
	_refresh_lineup()


func _on_slot_clear(i: int) -> void:
	lineup[i] = null
	_refresh_lineup()


func _refresh_lineup() -> void:
	lineup_source.clear()
	for ch in game.human.usable_cards():
		lineup_source.add_item(_champion_text(ch) + ("  ✔" if lineup.has(ch) else ""))
	for i in Rules.BOARD_SIZE:
		var ch = lineup[i] if i < lineup.size() else null
		slot_buttons[i].text = "%d\n%s" % [i + 1, "—" if ch == null else ch.data.display_name]
	var chosen: Array[Champion] = []
	for ch in lineup:
		if ch != null:
			chosen.append(ch)
	var errors := Roster.validate(game.human, chosen)
	var active := Synergy.active(chosen)
	var parts: PackedStringArray = []
	for c in active:
		parts.append("%s (%d)" % [Rules.class_label(c), active[c]])
	lineup_errors.text = ("Sinergias: " + ", ".join(parts) + "\n" if not parts.is_empty() else "") + "\n".join(errors)


# ---------------------------------------------------------------- combate

func _reset_pairs() -> void:
	pairs.clear()
	used_dp.clear()
	used_da.clear()
	selected_dp = -1


func _add_pair(dp_index: int, da_value: int) -> void:
	# auto_pairs devuelve valores; aquí trabajamos con índices de dado para
	# distinguir dados repetidos.
	var dice: Dictionary = game.current_combat.dice[0]
	var dp_i := _free_index(dice["dp"], dp_index, used_dp)
	if dp_i < 0:
		return
	used_dp.append(dp_i)
	var da_i := -1
	if da_value >= 0:
		da_i = _free_index(dice["da"], da_value, used_da)
		if da_i >= 0:
			used_da.append(da_i)
	pairs.append([dice["dp"][dp_i], dice["da"][da_i] if da_i >= 0 else -1])


func _free_index(values: Array, value: int, used: Array[int]) -> int:
	for i in values.size():
		if values[i] == value and not used.has(i):
			return i
	return -1


func _on_dp_pressed(i: int) -> void:
	var combat := game.current_combat
	var p: int = combat.dice[0]["dp"][i]
	var ch := combat.sides[0].champion_at(p - 1)
	if ch != null and ch.alive and ch.frozen:
		used_dp.append(i)
		pairs.append([p, -1])
		selected_dp = -1
	else:
		selected_dp = i
	_refresh_combat()


func _on_da_pressed(i: int) -> void:
	if selected_dp < 0:
		return
	var combat := game.current_combat
	used_dp.append(selected_dp)
	used_da.append(i)
	pairs.append([combat.dice[0]["dp"][selected_dp], combat.dice[0]["da"][i]])
	selected_dp = -1
	_refresh_combat()


func _refresh_combat() -> void:
	var combat := game.current_combat
	if combat == null:
		return
	var me := combat.sides[0]
	var foe := combat.sides[1]
	combat_title.text = "Combate contra %s — asalto %d de %d" % [foe.owner.display_name, combat.round_no, Rules.MAX_ROUNDS]
	foe_board_label.text = "[b]Mapa de %s[/b]\n%s" % [foe.owner.display_name, "\n".join(foe.describe())]
	my_board_label.text = "[b]Tu mapa[/b]\n%s" % "\n".join(me.describe())
	for c in dp_box.get_children():
		c.queue_free()
	for c in da_box.get_children():
		c.queue_free()
	var dice: Dictionary = combat.dice[0]
	for i in dice["dp"].size():
		var p: int = dice["dp"][i]
		var ch := me.champion_at(p - 1)
		var b := Button.new()
		b.text = "DP %d\n%s" % [p, "vacío" if ch == null or not ch.alive else ch.data.display_name]
		b.disabled = used_dp.has(i)
		b.toggle_mode = true
		b.button_pressed = selected_dp == i
		b.pressed.connect(_on_dp_pressed.bind(i))
		dp_box.add_child(b)
	for i in dice["da"].size():
		var v: int = dice["da"][i]
		var b := Button.new()
		var preview := ""
		if selected_dp >= 0:
			var ch := me.champion_at(dice["dp"][selected_dp] - 1)
			if ch != null:
				var names: PackedStringArray = []
				for kw in ch.data.keywords_for(v):
					names.append(Rules.keyword_label(kw))
				preview = "\n" + (" + ".join(names) if not names.is_empty() else "nada")
		b.text = "DA %d%s" % [v, preview]
		b.disabled = used_da.has(i) or selected_dp < 0
		b.pressed.connect(_on_da_pressed.bind(i))
		da_box.add_child(b)
	var parts: PackedStringArray = []
	for pair in pairs:
		var ch := me.champion_at(pair[0] - 1)
		var who := "vacío" if ch == null else ch.data.display_name
		parts.append("DP %d → %s%s" % [pair[0], who, "" if pair[1] < 0 else " con DA %d" % pair[1]])
	pairs_label.text = "Parejas: " + (", ".join(parts) if not parts.is_empty() else "ninguna")


# ---------------------------------------------------------------- refresco general

func _refresh() -> void:
	for st in panels:
		panels[st].visible = st == game.state
	phase_title.text = {
		Game.State.SHOPPING: "Ronda %d — Preparación" % game.round_no,
		Game.State.LINEUP: "Ronda %d — Alineación" % game.round_no,
		Game.State.COMBAT: "Ronda %d — Combate" % game.round_no,
		Game.State.ROUND_END: "Ronda %d — Fin de ronda" % game.round_no,
		Game.State.OVER: "Partida terminada",
	}.get(game.state, "")
	var lines: PackedStringArray = []
	for a in game.adalids:
		lines.append(("► " if a == game.human else "   ") + a.summary())
	standings.text = "\n".join(lines)
	var text := "\n".join(game.log)
	if game.current_combat != null:
		text += "\n" + "\n".join(game.current_combat.log)
	log_label.text = text


func _classes(card: ChampionData) -> String:
	var names: PackedStringArray = []
	for c in card.classes:
		names.append(Rules.class_label(c))
	return ", ".join(names)


func _champion_text(ch: Champion) -> String:
	var copies := "" if ch.duplicates == 0 else " x%d" % (ch.duplicates + 1)
	return "%s%s [%s] %d/%d" % [ch.data.display_name, copies, _classes(ch.data), ch.attack(), ch.max_defense()]
