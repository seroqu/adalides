class_name Tutorial
extends Node
## Tutorial guiado: una partida corta contra un solo rival, con vida y Éter reducidos.
## Cada paso muestra un texto, resalta el control o el punto del tablero que
## toca, y avanza solo cuando el jugador hace lo que se pide (o con «Siguiente»).

const LIFE := 5
const ETER := 5
const SEED := 20261016

var main: MainScene
var panel: PanelContainer
var title: Label
var body: RichTextLabel
var next_button: Button
var highlight: Highlight
var steps: Array[Dictionary] = []
var index: int = -1
var allowed_card: ChampionData = null # Carta que se puede tomar en el draft (null = cualquiera).
var allowed: PackedStringArray = [] # Acciones permitidas en el paso actual.
var finished: bool = false


## Anillo o marco dorado que late alrededor del objetivo del paso.
class Highlight:
	extends Control
	var rect := Rect2()
	var center := Vector2.ZERO
	var radius := 0.0
	var active: bool = false
	var _t: float = 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		if not active:
			return
		var pulse := 0.5 + 0.5 * sin(_t * 5.0)
		var col := Color(1.0, 0.85, 0.35, 0.45 + 0.5 * pulse)
		if radius > 0.0:
			draw_arc(center, radius + pulse * 5.0, 0.0, TAU, 64, col, 4.0, true)
			draw_arc(center, radius * 0.75, 0.0, TAU, 48, Color(col.r, col.g, col.b, col.a * 0.4), 2.0, true)
		else:
			var r := rect.grow(6.0 + pulse * 4.0)
			draw_rect(r, col, false, 4.0)
			draw_rect(r.grow(5.0), Color(col.r, col.g, col.b, col.a * 0.35), false, 2.0)


func setup(p_main: MainScene) -> void:
	main = p_main
	highlight = Highlight.new()
	main.fx_layer.add_child(highlight)
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 12
	panel.offset_top = 100
	panel.offset_right = 452
	var st := GameTheme.panel_style()
	st.bg_color = Color(0.06, 0.04, 0.1, 0.96)
	st.border_color = GameTheme.GOLD
	st.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", st)
	main.root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	title = GameTheme.title("Tutorial", 17)
	v.add_child(title)
	body = RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	body.add_theme_font_size_override("normal_font_size", 15)
	body.add_theme_font_size_override("bold_font_size", 15)
	body.add_theme_font_override("bold_font", GameTheme.bold_font)
	v.add_child(body)
	next_button = Button.new()
	next_button.text = "Siguiente ▶"
	next_button.custom_minimum_size = Vector2(0, 40)
	GameTheme.primary_button(next_button)
	next_button.pressed.connect(_on_next)
	v.add_child(next_button)
	_build_steps()
	_go(0)


## Permite tomar esa carta en el draft (si el paso restringe la elección).
func allows(card: ChampionData) -> bool:
	return allowed_card == null or card == allowed_card


## Si la acción está permitida en el paso actual (deal, take, buy, refresh, sell,
## upgrade_battle, upgrade_other, market_done, lineup_drag, lineup_auto,
## lineup_clear, lineup_go, battle_step, battle_pause, next_cycle).
func can(action: String) -> bool:
	return allowed.has(action)


## En la primera batalla los asaltos van a mano; en la segunda, solos.
func pause_first_battle() -> bool:
	return main.game != null and main.game.cycle == 1


func _step(text: String, target: Callable, done: Variant = null, enter: Variant = null, on_next: Variant = null, allow: PackedStringArray = []) -> void:
	steps.append({ "text": text, "target": target, "done": done, "enter": enter, "on_next": on_next, "allow": allow })


func _no_target() -> Variant:
	return null


func _game() -> Game:
	return main.game


func _human() -> Adalid:
	return main.game.human


func _my_turn() -> bool:
	var g := _game()
	return g.state == Game.State.DRAFT and main.table.dealt and not main.table_busy and g.draft_current() == g.human


## Elige la carta que el tutorial pide en el draft: cuerpo a cuerpo barata la
## primera; la segunda, la que mejor combine (mismo elemento) según la IA.
func _pick_draft_card(first: bool) -> ChampionData:
	var g := _game()
	var best: ChampionData = null
	var best_score := -1.0
	for card in g.draft_pool:
		if card.hero or not g.human.can_add(card):
			continue
		var score := Game.card_score(g.human, card)
		if first and card.reach() == 1 and card.cost <= 2:
			score += 10.0
		if score > best_score:
			best = card
			best_score = score
	return best


func _card_target() -> Variant:
	if allowed_card == null:
		return null
	var c3d := main.table.find_card(allowed_card)
	if c3d == null:
		return null
	return c3d.global_position + Vector3(0, 0.2, 0)


func _build_steps() -> void:
	var cfg := "[b]Bienvenido, adalid.[/b] Esta partida corta te enseña lo básico: elegir cartas, colocarlas, luchar y comprar. Empiezas con [color=#7ee07e]♥ %d[/color] de vida y [color=#9ecbff]◆ %d[/color] de Éter.\n\nEste es el [b]mazo del Demiurgo[/b]. Púlsalo para repartir." % [LIFE, ETER]
	_step(cfg, func() -> Variant: return main.table.deck_pos + Vector3(0, 0.3, 0),
		func() -> bool: return _my_turn(), null, null, ["deal"])
	_step("Cada carta es un [b]campeón[/b]: el icono es su arquetipo, el color su elemento; abajo, ataque ⚔, vida ♥ y coste ◆.\n\n[b]Arrastra «%s»[/b] hasta el panel de la derecha para tomarla.",
		_card_target,
		func() -> bool: return _human().cuartel.size() >= 1 and (_my_turn() or _game().state != Game.State.DRAFT),
		func() -> void:
			allowed_card = _pick_draft_card(true)
			body.text = steps[index]["text"] % (allowed_card.display_name if allowed_card != null else "una carta")
			main._refresh_draft(),
		null, ["take"])
	_step("Tu rival también elige por turnos. Tu segunda carta: [b]«%s»[/b]. Las cartas del mismo elemento o arquetipo activan [b]tiers[/b] cuando coinciden en batalla.",
		_card_target,
		func() -> bool: return _human().cuartel.size() >= 2,
		func() -> void:
			allowed_card = _pick_draft_card(false)
			body.text = steps[index]["text"] % (allowed_card.display_name if allowed_card != null else "la que quieras")
			main._refresh_draft(),
		null, ["take"])
	_step("Ya tienes ejército; el mercado lo veremos después de pelear. Este es [b]tu campo[/b]: la fila junto a la línea dorada es el [b]frente[/b], donde se pelea cuerpo a cuerpo. Los arqueros (alcance 3) y magos (alcance 2) van mejor detrás.\n\n[b]Arrastra tus dos cartas[/b] de la mano a las casillas; luego pulsa [b]¡A la batalla![/b]",
		func() -> Variant: return main.lineup_go_button if main.lineup.size() >= 2 else null,
		func() -> bool: return _game().state == Game.State.BATTLE,
		func() -> void:
			allowed_card = null
			main.hint.text = "",
		null, ["lineup_drag", "lineup_clear", "lineup_go"])
	_step("[b]La batalla[/b] tiene 4 asaltos. En cada uno, tus campeones avanzan un paso, se giran hacia su objetivo y atacan al rival más cercano a su alcance (la mira marca a quién).\n\nPulsa [b]Asalto ▶[/b] para jugar el primero.",
		func() -> Variant: return main.step_button,
		func() -> bool: return _game().current_battle != null and _game().current_battle.round_no >= 2 and not main.battle_playing,
		func() -> void: main.hint.text = "",
		null, ["battle_step"])
	_step("Los números rojos son [b]daño[/b] y las barras, la vida que queda (borde azul: los tuyos; rojo: el rival).\n\nPulsa [b]Asalto ▶[/b] otra vez.",
		func() -> Variant: return main.step_button,
		func() -> bool: return _game().current_battle != null and _game().current_battle.round_no >= 3 and not main.battle_playing,
		null, null, ["battle_step"])
	_step("[b]Dados y poderes.[/b] Cada asalto lanzas tantos dados de tres caras (−, ○, +) como marque tu pista de Dados; el Demiurgo los reparte entre los poderes de tus campeones, que anuncian su nombre al activarse.\n\nSigue pulsando [b]Asalto ▶[/b] hasta el final.",
		func() -> Variant: return main.step_button,
		func() -> bool: return _game().state == Game.State.CYCLE_END or _game().state == Game.State.OVER,
		null, null, ["battle_step"])
	_step("Gana quien tiene más campeones en pie; el perdedor [b]pierde vida[/b] según los campeones rivales que quedaron y el ciclo. Tu vida va arriba a la izquierda.\n\nPulsa [b]Siguiente ciclo[/b].",
		func() -> Variant: return main.next_cycle_button if _game().state == Game.State.CYCLE_END else null,
		func() -> bool: return _game().state == Game.State.MARKET or _game().state == Game.State.OVER,
		null, null, ["next_cycle"])
	_step("[b]El mercado.[/b] Cada ciclo cobras 10 ◆ más intereses (3 por cada 10 ahorrados) y el bono de racha. Tu Éter está en la cabecera de la tienda.\n\n[b]Arrastra una carta[/b] de la mesa al panel para comprarla.",
		func() -> Variant: return main.buy_button,
		func() -> bool: return _human().cuartel.size() >= 3 or _game().state != Game.State.MARKET,
		func() -> void: main.hint.text = "",
		null, ["buy"])
	_step("[b]Mejoras.[/b] Tres pistas: tamaño del cuartel, campeones en batalla y dados. Cada mejora cuesta 5 ◆ más que la anterior de su pista.\n\nSube [b]«En batalla»[/b] para alinear un campeón más.",
		func() -> Variant: return main.upgrade_buttons[Adalid.Track.BATTLE],
		func() -> bool: return _human().upgrades[Adalid.Track.BATTLE] >= 1 or not _human().can_pay(_human().upgrade_cost(Adalid.Track.BATTLE)) or _game().state != Game.State.MARKET,
		null, null, ["upgrade_battle"])
	_step("Dos cosas más: [b]Refrescar[/b] cambia las cartas de la mesa por 2 ◆, y pulsar una carta de tu mano y [b]Vender[/b] devuelve la mitad de su coste. Las copias de una misma carta se funden y la hacen más fuerte. Prueba lo que quieras.\n\nCuando termines, pulsa [b]Listo, a alinear[/b].",
		func() -> Variant: return main.market_done_button,
		func() -> bool: return _game().state != Game.State.MARKET,
		null, null, ["buy", "refresh", "sell", "upgrade_battle", "upgrade_other", "market_done"])
	_step("Coloca a tus campeones (o pulsa [b]Auto[/b]) y ve a la batalla. Esta vez correrá sola, un asalto cada 2 segundos; puedes detenerla con ⏸ para verla paso a paso.",
		func() -> Variant: return main.lineup_go_button,
		func() -> bool: return _game().state == Game.State.CYCLE_END or _game().state == Game.State.OVER,
		null, null, ["lineup_drag", "lineup_auto", "lineup_clear", "lineup_go", "battle_pause", "battle_step"])
	_step("[b]¡Tutorial completado![/b] Ya conoces el draft, la alineación, la batalla, el mercado y las mejoras. En una partida normal empiezas con 30 de vida y 30 de Éter, y el último adalid en pie se convierte en el nuevo demiurgo.\n\nPulsa [b]Terminar[/b] para volver al menú.",
		_no_target, null,
		func() -> void:
			next_button.text = "Terminar ✔"
			main._auto_token += 1,
		func() -> void:
			finished = true
			main._show_main_menu(),
		[])


func _go(i: int) -> void:
	index = i
	if index >= steps.size():
		return
	main.hint.text = ""
	var st: Dictionary = steps[index]
	title.text = "Tutorial · paso %d de %d" % [index + 1, steps.size()]
	body.text = st["text"]
	allowed = st["allow"]
	main._tut_apply_locks()
	next_button.visible = st["done"] == null
	if st["enter"] != null:
		(st["enter"] as Callable).call()
	_update_highlight()


func _on_next() -> void:
	var st: Dictionary = steps[index]
	if st["on_next"] != null:
		(st["on_next"] as Callable).call()
	if index < steps.size() - 1 and not finished:
		_go(index + 1)


func _process(_delta: float) -> void:
	if finished or index < 0 or index >= steps.size() or main.game == null:
		return
	var st: Dictionary = steps[index]
	if st["done"] != null and (st["done"] as Callable).call():
		_go(index + 1)
		return
	# Si el juego va por delante del guion (batalla ya resuelta, partida acabada), salta.
	var g := main.game
	if g.state == Game.State.OVER and index < steps.size() - 1:
		_go(steps.size() - 1)
		return
	if g.state == Game.State.CYCLE_END and index >= 3 and index < 7:
		_go(7)
		return
	if g.state == Game.State.MARKET and g.cycle >= 2 and index < 8:
		_go(8)
		return
	if g.state == Game.State.LINEUP and g.cycle >= 2 and index < 11:
		_go(11)
		return
	_update_highlight()


func _update_highlight() -> void:
	if index < 0 or index >= steps.size():
		highlight.active = false
		return
	var target: Variant = (steps[index]["target"] as Callable).call()
	highlight.active = false
	if target is Control:
		var c: Control = target
		if c.is_visible_in_tree():
			highlight.rect = c.get_global_rect()
			highlight.radius = 0.0
			highlight.active = true
	elif target is Vector3:
		var cam := main.camera
		if cam != null and not cam.is_position_behind(target):
			highlight.center = cam.unproject_position(target)
			highlight.radius = 54.0
			highlight.active = true


func close() -> void:
	finished = true
	if is_instance_valid(highlight):
		highlight.queue_free()
	if is_instance_valid(panel):
		panel.queue_free()
	queue_free()
