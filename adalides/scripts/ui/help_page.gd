class_name HelpPage
extends ScrollContainer
## Guía visual «Cómo se juega»: el ciclo, la carta, elementos, arquetipos,
## batalla y dados, Éter y mejoras. Se construye en código con el tema del juego.

const BLUE := Color(0.62, 0.8, 1.0)
const GREEN := Color(0.5, 0.88, 0.5)
const RED := Color(1.0, 0.55, 0.45)


static func build() -> HelpPage:
	var page := HelpPage.new()
	page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 18)
	page.add_child(v)
	page._hero(v)
	page._cycle(v)
	page._card(v)
	page._elements(v)
	page._archetypes(v)
	page._battle(v)
	page._eter(v)
	return page


# ---------------------------------------------------------------- piezas

static func _section(v: VBoxContainer, title: String, lead := "") -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var t := GameTheme.title(title, 20)
	box.add_child(t)
	var rule := ColorRect.new()
	rule.color = GameTheme.GOLD_DIM
	rule.custom_minimum_size = Vector2(0, 1)
	box.add_child(rule)
	if lead != "":
		box.add_child(_text(lead))
	v.add_child(box)
	return box


static func _text(s: String, size := 14, color := GameTheme.TEXT) -> RichTextLabel:
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	l.add_theme_font_size_override("normal_font_size", size)
	l.add_theme_font_size_override("bold_font_size", size)
	l.add_theme_font_override("bold_font", GameTheme.bold_font)
	l.add_theme_color_override("default_color", color)
	l.text = s
	return l


static func _icon(tex: Texture2D, size: float, color: Color) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.modulate = color
	tr.custom_minimum_size = Vector2(size, size)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return tr


static func _chip(text: String, color: Color, min_w := 0.0) -> PanelContainer:
	var p := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(color.r, color.g, color.b, 0.18)
	st.border_color = color
	st.set_border_width_all(1)
	st.set_corner_radius_all(8)
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 4
	st.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", st)
	p.custom_minimum_size.x = min_w
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", GameTheme.bold_font)
	l.add_theme_color_override("font_color", color.lightened(0.3))
	p.add_child(l)
	return p


static func _tile(title: String, glyph: Control, body: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st := GameTheme.panel_style()
	st.bg_color = Color(0.1, 0.09, 0.15, 0.9)
	st.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", st)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	box.add_theme_constant_override("separation", 6)
	p.add_child(box)
	glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(glyph)
	var t := GameTheme.heading(title, 15)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var b := _text(body, 13, GameTheme.TEXT_DIM)
	box.add_child(b)
	return p


static func _glyph(text: String, color: Color, size := 34) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


# ---------------------------------------------------------------- secciones

func _hero(v: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	var back := _icon(Icons.card_back(), 96, Color.WHITE)
	back.custom_minimum_size = Vector2(68, 96)
	row.add_child(back)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	row.add_child(col)
	col.add_child(_text("[b]Eres un adalid con 30 de vida.[/b] Cada ciclo compras campeones con Éter, los colocas en tu campo y el Demiurgo enfrenta tu ejército al de otro adalid en una batalla automática de varios asaltos (2, 3, 4 o hasta el final, según la partida). Pierdes vida al perder batallas. El último adalid en pie se convierte en el nuevo demiurgo.", 15))
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 8)
	col.add_child(chips)
	chips.add_child(_chip("♥ 30 vida", GREEN))
	chips.add_child(_chip("30 Éter inicial", BLUE))
	chips.add_child(_chip("4 o 6 adalides", GameTheme.GOLD))
	chips.add_child(_chip("2 a 4 asaltos o hasta el final", RED))


func _cycle(v: VBoxContainer) -> void:
	var box := _section(v, "El ciclo", "Cada ciclo pasa por cuatro fases. Lo que decides tú está en el mercado y en la alineación; la batalla la resuelve el Demiurgo.")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	var steps := [
		["Draft", _icon(Icons.card_back(), 56, Color.WHITE), "Solo el primer ciclo. Pulsa el mazo y, por turnos, cada adalid arrastra dos cartas a su cuartel."],
		["Mercado", _icon(Icons.eter(), 44, Color.WHITE), "60 segundos. Compra cartas del mazo, refresca por 2 de Éter, vende de tu mano o sube tus tres pistas."],
		["Alineación", _glyph("▦", GREEN, 40), "30 segundos. Arrastra cartas de tu mano a tu mitad del campo, hasta el tope de tu pista «En batalla»."],
		["Batalla", _glyph("⚔", RED, 40), "Automática. En cada asalto: moverse, atacar y poderes con dados. Quien pierde, pierde vida."],
	]
	for i in steps.size():
		var s: Array = steps[i]
		row.add_child(_tile(s[0], s[1], s[2]))
		if i < steps.size() - 1:
			var arrow := _glyph("→", GameTheme.GOLD, 30)
			arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(arrow)


func _card(v: VBoxContainer) -> void:
	var box := _section(v, "La carta", "Cada campeón es un arquetipo de un elemento. El marco y los iconos te dicen de un vistazo qué es.")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	box.add_child(row)
	var sample: ChampionData = Catalog.by_id(Catalog.id_for(Rules.Archetype.DEFENSOR, Rules.Element.FUEGO))
	if sample == null:
		sample = Catalog.base_cards()[0]
	var cv := CardView.new()
	cv.setup(sample)
	cv.custom_minimum_size.x = 210
	cv.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(cv)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	row.add_child(col)
	var legend := [
		[_icon(Icons.archetype(sample.archetype), 30, Color.WHITE), "[b]Arquetipo[/b] (icono): decide el alcance y su tier con 2 / 4 / 6 iguales en batalla."],
		[_icon(Icons.element(sample.element), 30, Icons.color_of(sample)), "[b]Elemento[/b] (color): su tier se activa con 3 / 6 / 9 iguales en batalla."],
		[_icon(Icons.eter(), 28, Color.WHITE), "[b]Coste[/b] en Éter para comprarla; se vende por la mitad."],
		[_glyph("⚔ ♥", RED, 20), "[b]Ataque[/b] y [b]vida[/b] del campeón en batalla."],
		[_glyph("✦", GameTheme.GOLD, 24), "[b]Poder[/b]: activo (sustituye el ataque) o pasivo (se suma). Necesita un dado con el signo que pida."],
	]
	for item in legend:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 10)
		var ic: Control = item[0]
		ic.custom_minimum_size.x = 36
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(ic)
		r.add_child(_text(item[1], 14))
		col.add_child(r)
	col.add_child(GameTheme.heading("Copias", 14))
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 6)
	col.add_child(chips)
	chips.add_child(_chip("×1 base", GameTheme.TEXT_DIM))
	chips.add_child(_glyph("→", GameTheme.GOLD, 18))
	chips.add_child(_chip("×2  +1 / +1", GREEN))
	chips.add_child(_glyph("→", GameTheme.GOLD, 18))
	chips.add_child(_chip("×3  AFI 1", GameTheme.GOLD))
	chips.add_child(_glyph("→", GameTheme.GOLD, 18))
	chips.add_child(_chip("×4  AFI 2", GameTheme.GOLD))
	col.add_child(_text("Las copias de una misma carta se funden: la segunda da +1/+1 y la tercera y cuarta mejoran su poder (AFI). Los héroes (★) no tienen elemento y necesitan un hueco H del cuartel.", 13, GameTheme.TEXT_DIM))


func _elements(v: VBoxContainer) -> void:
	var box := _section(v, "Elementos · tiers con 3 / 6 / 9 en batalla")
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	for e in Catalog.ELEM_ORDER:
		var color: Color = Icons.ELEMENT_COLORS[e]
		var text: String = TierTexts.ELEMENTS[e]
		grid.add_child(_tile(Rules.element_label(e), _icon(Icons.element(e), 44, color), _short(text, 110)))


func _archetypes(v: VBoxContainer) -> void:
	var box := _section(v, "Arquetipos · tiers con 2 / 4 / 6 en batalla")
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	for a in Catalog.ARCH_ORDER:
		var reach := Rules.reach_of(a)
		var text: String = TierTexts.ARCHETYPES[a]
		grid.add_child(_tile("%s · alcance %d" % [Rules.archetype_label(a), reach], _icon(Icons.archetype(a), 44, Color.WHITE), _short(text, 100)))


func _battle(v: VBoxContainer) -> void:
	var box := _section(v, "Batalla y dados")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	box.add_child(row)
	# Mini tablero: tu mitad azul abajo, la rival roja arriba, el frente junto a la línea.
	var bcol := VBoxContainer.new()
	bcol.add_theme_constant_override("separation", 4)
	row.add_child(bcol)
	bcol.add_child(_glyph("rival", RED, 12))
	var grid := GridContainer.new()
	grid.columns = Rules.BOARD_COLS
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	bcol.add_child(grid)
	for y in 2 * Rules.BOARD_ROWS:
		for x in Rules.BOARD_COLS:
			var c := ColorRect.new()
			c.custom_minimum_size = Vector2(26, 20)
			var enemy := y < Rules.BOARD_ROWS
			var front := y == Rules.BOARD_ROWS - 1 or y == Rules.BOARD_ROWS
			var base := Color(0.5, 0.22, 0.25) if enemy else Color(0.2, 0.3, 0.5)
			c.color = base.lightened(0.2) if front else base
			grid.add_child(c)
			if y == Rules.BOARD_ROWS - 1 and x == Rules.BOARD_COLS - 1:
				pass
	var line := ColorRect.new()
	line.color = GameTheme.GOLD
	line.custom_minimum_size = Vector2(0, 2)
	bcol.add_child(line)
	bcol.move_child(line, 2) # Entre las dos mitades no se puede partir el grid: la línea va debajo como referencia.
	bcol.add_child(_glyph("tú", BLUE, 12))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	row.add_child(col)
	col.add_child(_text("[b]Cada asalto[/b], cada campeón avanza un paso hacia el rival más cercano, ataca si lo tiene a su alcance (1 casilla; Arquero 3, Mago 2) y usa su poder si tiene un dado que lo permita. Las filas más claras son el frente: las dos se tocan.", 14))
	col.add_child(_text("[b]Los dados.[/b] Tu pista de Dados dice cuántos dados de tres caras lanzas por asalto. El Demiurgo los reparte entre tus poderes:", 14))
	var dice := HBoxContainer.new()
	dice.add_theme_constant_override("separation", 8)
	col.add_child(dice)
	dice.add_child(_chip("−  fallo: activa poderes de −", RED))
	dice.add_child(_chip("○  neutra: poderes sin requisito", GameTheme.TEXT_DIM))
	dice.add_child(_chip("+  acierto: poderes de +", GREEN))
	col.add_child(_text("Dos + juntos hacen un ++ y dos − un −−, los efectos más fuertes de cada poder. Al terminar los asaltos, quien tenga más campeones en pie gana; el perdedor pierde vida según los campeones que sobrevivieron al rival y el ciclo en curso.", 13, GameTheme.TEXT_DIM))


func _eter(v: VBoxContainer) -> void:
	var box := _section(v, "Éter y mejoras", "Al empezar cada ciclo (salvo el primero) cobras 10 de Éter, más 3 por cada 10 ahorrados, más el bono de racha por victorias o derrotas seguidas.")
	var tracks := [
		["⌂ Cuartel", "cartas que caben en tu cuartel (H = hueco de héroe)", Rules.CUARTEL_TRACK],
		["⚔ En batalla", "campeones que puedes alinear", Rules.BATTLE_TRACK],
		["⚅ Dados", "dados de tres caras por asalto", Rules.DICE_TRACK],
	]
	for t in tracks:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 10)
		box.add_child(r)
		var name := GameTheme.heading(t[0], 14)
		name.custom_minimum_size.x = 120
		r.add_child(name)
		var pips := HBoxContainer.new()
		pips.add_theme_constant_override("separation", 4)
		r.add_child(pips)
		var values: Array = t[2]
		for i in values.size():
			pips.add_child(_chip(str(values[i]), GameTheme.GOLD if i == 0 else GameTheme.GOLD_DIM, 34))
		var d := _text(t[1], 13, GameTheme.TEXT_DIM)
		r.add_child(d)
	box.add_child(_text("Cada mejora cuesta 5 de Éter más 5 por cada mejora anterior de esa misma pista (5, 10, 15…). Refrescar el mercado cuesta 2 y vender una carta devuelve la mitad de su coste.", 13, GameTheme.TEXT_DIM))


static func _short(text: String, max_len: int) -> String:
	var t := text.strip_edges()
	if t.length() <= max_len:
		return t
	var cut := t.rfind(" ", max_len)
	return t.substr(0, cut if cut > 40 else max_len) + "…"
