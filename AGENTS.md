# AGENTS.md

Guía para agentes de IA y colaboradores que trabajen en este repositorio.

## Qué es Adalides

**Adalides del demiurgo** es un juego de mesa de autobatallas: cada jugador ("adalid") arma un ejército de campeones
(arquetipo × elemento) con Éter y lo enfrenta al de los demás en batallas automáticas de 4 asaltos. Este repositorio
es su adaptación digital con **Godot 4.7** y **GDScript**.

Las reglas vigentes están en `README.md`, que ordena el documento de diseño del autor
(`adalides/adalides_doc/Adalides del demiurgo 2 columnas.pdf`, los tableros `Matt batalla azul.png` y
`Matt magenta.png`, y `recuento adalides.png`). Son la fuente de verdad: antes de implementar una mecánica léelas.
Si una regla es ambigua, **pregunta al autor** en lugar de inventar; él lo pidió explícitamente. La versión anterior
del juego (README v1: sinergias 3/5/7, DA+DP, estertores) quedó obsoleta el 2026-10-16 y solo vive en el historial.

## Estructura

```
.
├── README.md        Reglas del juego v2 (diseño)
├── AGENTS.md        Este archivo
└── adalides/        Proyecto de Godot (abrir esta carpeta con el editor)
    ├── project.godot
    ├── adalides_doc/            Documentos del autor (PDF y tableros)
    ├── scenes/main.tscn         Pantalla de partida (la UI se construye en código)
    ├── scripts/
    │   ├── core/                Reglas puras, sin nodos (se prueban en headless)
    │   │   ├── rules.gd         Constantes, enums, pistas del tablero, supuestos (Rules)
    │   │   ├── dice.gd          d6 (--/-/+/++) y d20 (Dice)
    │   │   ├── champion_data.gd Carta: arquetipo, elemento, coste, ataque, vida, poder (ChampionData)
    │   │   ├── champion.gd      Campeón del cuartel: copias/AFI y estado de batalla (Champion)
    │   │   ├── adalid.gd        Tablero personal: vida, Éter, racha, pistas, cuartel (Adalid)
    │   │   ├── board.gd         Cuadrícula 6×5 (dos tableros 3×5 enfrentados), distancias (Board)
    │   │   ├── tiers.gd         Tiers elementales 3/6/9 y de arquetipo 2/4/6 (Tiers)
    │   │   ├── battle.gd        Batalla: fases HI/M/HR/A/H/HF, movimiento y objetivo automáticos,
    │   │   │                    ataques, pasivas de tier, fin y pérdida de vida (Battle)
    │   │   ├── powers.gd        Poderes de personaje; IMPLEMENTED lista los que ya hacen algo (Powers)
    │   │   ├── deck.gd          Mazo del demiurgo (Deck)
    │   │   ├── schedule.gd      Tabla de batallas (4 y 6 jugadores; round-robin para otros) (Schedule)
    │   │   └── game.gd          Partida: draft → mercado → alineación → batallas, IA y humano (Game)
    │   ├── data/catalog.gd      50 campeones base + 5 héroes con stats, precios y poderes (Catalog)
    │   ├── ui/main.gd           Partida jugable: tú contra 5 IA (menú, barra superior, columna lateral, mano)
    │   ├── ui/card_view.gd      Carta 2D (mano y detalle); ui/game_theme.gd tema; ui/icons.gd iconos y texturas
    │   ├── ui/help_page.gd      Guía visual «Cómo se juega» (HelpPage.build())
    │   ├── ui/tutorial.gd       Tutorial guiado por pasos (Tutorial: duelo con vida y Éter 5, semilla fija)
    │   └── view3d/              Tablero, fichas con modelos GLB, cartas 3D (card_3d.gd), mesa del draft,
    │                            efectos (fx.gd) y decorado compartido (deco.gd: sellos, braseros, motas)
    ├── assets/particles/        Sprites de partículas del Particle Pack de Kenney (CC0); Fx.tex("nombre")
    ├── assets/shaders/          tile.gdshader (casillas: borde, vetas, highlight/hover) y table.gdshader (mesa)
    ├── assets/icons/            SVG de arquetipos y elementos (game-icons.net, CC BY; ver CREDITS.md), marco, dorso y sello
    ├── assets/models/           GLB por arquetipo generados con tools/build_champions.py (Blender)
    └── tools/build_champions.py Construye y anima los diez modelos en Blender (clips idle, walk,
                                 attack por arquetipo, hit, death, cheer; exporta NLA_TRACKS)
    └── tests/
        ├── test_rules.gd        Pruebas de reglas (SceneTree, sin editor)
        └── demo_game.gd         Imprime una partida completa de 6 adalides
```

## Supuestos de implementación

Lo que el PDF no fija. Las **decisiones del autor** se tomaron en conversación el 2026-10-16; el resto son
supuestos marcados `SUPUESTO` en el código y candidatos a preguntar.

Decisiones del autor:
- Vida inicial 30. Éter inicial 30. Por ciclo: 10 + interés (3 por cada 10 ahorrados) + bono de racha.
- La racha cuenta victorias **o** derrotas seguidas; es la fila 0/5/10/15/20/25/30 del tablero personal.
- "Roll 2" = refrescar el mercado cuesta 2.
- Mejoras: tres pistas (cuartel, campeones en batalla, dados); cada mejora cuesta 5 + 5 por mejora previa en la pista.
- Movimiento 1 paso por asalto; alcance 1 salvo Arquero 3 y Mago 2.
- Los tiers se cuentan con los campeones en batalla.
- La marca "inactiva" del tablero físico no se implementa.
- Las filas 1 de los dos tableros se enfrentan (confirmado el 2026-10-16).

Supuestos del código:
- El bono de racha es el número de la casilla (5, 10, …, 30 de Éter). Probablemente excesivo: preguntar.
- La cuadrícula 6×5 es transitable por ambos bandos.
- Mercado de 4 cartas; el draft lo empieza quien tiene menos vida; vender devuelve la mitad del coste.
- Mazo: 4 copias de cada carta base y 1 de cada héroe. Los héroes no tienen elemento.
- Los d20 de Tifón/Herejía/Magia desatada señalan casillas 1..15 (16–20 nada). Tormenta, Cosecha oscura,
  Tormenta de flechas y Curación relámpago usan d6: (valor − 1) mod 5 = columna, (valor − 1) mod 3 + 1 = fila.
- Las acciones defensivas de un asalto se marcan en HI y afectan a los ataques del mismo asalto.
- "Batallas realizadas" para la pérdida de vida = número del ciclo (cada adalid pelea una vez por ciclo).
- Un adalid eliminado deja a su rival de la tabla sin batalla; los sueltos se emparejan entre sí.
- Hechizos y quintaesencias no están implementados (el PDF no dice cómo se compran).
- Poderes sin implementar (solo se registran, la IA no les asigna dados): Aura estoica, Abjuración herética,
  Hedor profano, Disparos de viento, Distancia, Escudo reflectivo, Agarre de kraken, Tengo un jarrón, Aire vital,
  Tierra maldita, Golpe rebotante, Golpe fantasma, Excavadora, Saltos continuos, Aura de puntería divina,
  Atracción letal, Matriz de protección. Tiers sin implementar: Pacto demoníaco, Frenesí canino, Ejército de la
  tumba, Amplificación arcana.

## Interfaz

`main.gd` construye toda la UI en código: menú principal y de pausa (`Esc` o «☰»; la pausa usa
`get_tree().paused`, por eso la capa de UI es `PROCESS_MODE_ALWAYS` y los temporizadores usan
`create_timer(t, false)`), barra superior (vida, Éter, racha, fase y tiempo), columna lateral con solo los controles
de la fase (en batalla: gemas de asalto, vida de cada adalid en número y barra con la vida total de sus campeones;
cada asalto se anuncia con un rótulo), mano de cartas abajo
(en la alineación solo las cartas que no están en el tablero) y paneles desplegables (Adalides, Habilidades, Crónica, Cómo se juega).
La cámara cambia por fase (`_camera_view`: tablero, draft o mercado). Las cartas 3D usan
`assets/icons/card_frame.svg` teñido del color del elemento y `card_back.svg` como dorso.

## Modos, jugadores y tutorial

El menú «Jugar» pide modo, número de adalides (3, 4 o 6) y asaltos por batalla (`Rules.ROUND_OPTIONS`: 2, 3, 4 o
«hasta el final», que es `Battle.max_rounds = 0` con tope `Rules.SUDDEN_DEATH_CAP`). La semilla es aleatoria y no se
muestra; solo el tutorial usa una fija. Por defecto: Amateur, 4 adalides, 4 asaltos. El fin de ciclo
espera a que termine la celebración y muestra una clasificación con barras de vida, lo perdido en el ciclo, Éter,
racha y resultado (`_fill_standings`). El modo es `Game.Difficulty` y solo cambia a la IA:
Principiante mete mucho ruido en sus puntuaciones, guarda margen antes de mejorar y compra una carta por ciclo;
Amateur es la IA original con algo de ruido; Profesional no falla combos, invierte antes y refresca el mercado
si la oferta es floja. Los rivales se llaman Kaelum de las Brasas, Ysolda la Gélida, Tharok Piedrafirme,
Selenia del Céfiro y Vargo Truenante (`MainScene.AI_NAMES`). «Tutorial» crea un duelo contra Kaelum con
`Game.set_start(5, 5)` y semilla fija; `Tutorial` encadena 14 pasos (draft guiado con una carta obligada,
salta el primer mercado, alineación a mano, primera batalla asalto a asalto, mercado y mejoras, segunda batalla
automática, cierre). Sin temporizadores. Se prueba con `godot --path adalides -- --tutorial DIR`, que ejecuta
cada paso solo y captura pantallas.

## Cómo fluye una partida con jugador humano

`Game` es una máquina de estados (`Game.State`): `begin_cycle()` reparte el draft y ejecuta los picks de la IA hasta
que toca al humano (`DRAFT`, `human_draft_pick`); al acabar cobra y abre el mercado (`MARKET`: `human_buy`,
`human_refresh_market`, `human_sell`, `human_upgrade`, `finish_market`); `set_lineup({Vector2i(col, fila): Champion})`
valida y lanza las batallas de la tabla hasta la del humano (`BATTLE`). En batalla, `Battle.begin_round()` lanza los
dados y `commit_human_dice({Champion: Rules.Die})` resuelve el asalto. `advance()` termina el ciclo
(`CYCLE_END` u `OVER`). Sin humano, `play_cycle()` lo hace todo con la IA: así corren las pruebas.

Lo que decide el motor por el humano: la asignación de dados a poderes, movimiento y objetivo de cada campeón
(reglas de prioridad del PDF) y a quién afecta cada poder. La UI resuelve cada asalto con `Battle.commit_round()`,
lee `Battle.events` (move / attack / damage / heal / power / tier / dodge / freeze / curse / death) y los anima
(`main.gd: _animate_events`) antes de `begin_round()`.

## Convenciones

- Lenguaje: GDScript con tipado estático (`var vida: int = 20`, `func atacar() -> void`). Las advertencias de
  inferencia desde Variant se tratan como error: anota el tipo al sacar elementos de arrays sin tipo.
- Nombres: `snake_case` para archivos, funciones y variables; `PascalCase` para clases y nodos;
  `SCREAMING_SNAKE_CASE` para constantes.
- Idioma: identificadores en inglés, textos visibles para el jugador y comentarios en español.
- La lógica de reglas va en scripts puros sin nodos, para probarla sin abrir el editor.
- `Rules.Reach`/`Range`: no uses `Range` ni `range` como nombres; chocan con Godot.

## Flujo de trabajo

- Tras crear scripts nuevos con `class_name`: `godot --headless --path adalides --import`
- Pruebas (deben quedar en 0 fallos): `godot --headless --path adalides -s tests/test_rules.gd`
- Partida completa de ejemplo: `godot --headless --path adalides -s tests/demo_game.gd -- 2026`
- Escena principal: `godot --headless --path adalides --quit-after 5`
- Capturas de cada fase (abre una ventana real unos segundos):
  `godot --path adalides --resolution 1500x950 -- --screenshots /ruta/de/salida`
- Recorrido automático del tutorial con capturas: `godot --path adalides -- --tutorial /ruta/de/salida`
- Exportar (plantillas en `~/.local/share/godot/export_templates/4.7.2.stable/`, instaladas desde el .tpz oficial):
  `godot --headless --path adalides --export-release Linux ../build/adalides.x86_64`,
  `--export-release Web ../build/web/index.html` (sin hilos: no necesita cabeceras COOP/COEP, pero sí un
  servidor http), `--export-release macOS ../build/mac/Adalides_del_demiurgo.zip` (universal, firma ad hoc
  integrada; requiere `import_etc2_astc=true` en project.godot) y `--export-release Windows
  ../build/windows/Adalides_del_demiurgo.exe`. Las rutas de exportación no admiten espacios.
- Editor: `godot -e --path adalides`
- Rama principal: `master`. Commits en español, en presente ("Agrega la escena de combate").
- No subir `adalides/.godot/` ni exportaciones; ya están en `.gitignore`.

## Glosario rápido

- **Éter**: recurso para comprar y mejorar. **Vida**: 30; se pierde al perder batallas.
- **Ciclo**: draft + mercado + alineación + una batalla por adalid. **Asalto**: una de las 4 rondas de una batalla.
- **Cuartel**: todas las cartas del adalid. **Copias**: 2.ª = duplicado (+1/+1), 3.ª/4.ª = AFI 1/2.
- **Tier**: habilidad de elemento (3/6/9 campeones) o de arquetipo (2/4/6) en la batalla.
- **PA / PP**: poder activo (sustituye el ataque) / pasivo (se suma al ataque). Ambos necesitan un dado.
