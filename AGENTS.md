# AGENTS.md

Guía para agentes de IA y colaboradores que trabajen en este repositorio.

## Qué es Adalides

Adalides es un juego de mesa de estrategia por combates en el que cada jugador
("adalid") construye un ejército de campeones con Éter y lucha por ser el
sucesor del demiurgo. Este repositorio contiene la adaptación digital del juego,
hecha con **Godot 4.7** y **GDScript**.

Las reglas completas del juego están en `README.md`. Son la fuente de verdad del
diseño: antes de implementar una mecánica, léelas y respétalas. Si una regla es
ambigua, pregunta en lugar de inventar.

## Estructura

```
.
├── README.md        Reglas del juego (diseño)
├── AGENTS.md        Este archivo
├── .gitignore
└── adalides/        Proyecto de Godot (abrir esta carpeta con el editor)
    ├── project.godot
    ├── scenes/
    │   └── main.tscn            Pantalla de prueba: simula combates y muestra el registro
    ├── scripts/
    │   ├── core/                Reglas puras, sin nodos (se prueban en headless)
    │   │   ├── rules.gd         Constantes, enums y supuestos (Rules)
    │   │   ├── dice.gd          Tiradas d6: pifia / fallo / acierto / crítico (Dice)
    │   │   ├── champion_data.gd Carta de campeón: clases, nivel, coste, tabla de acciones (ChampionData)
    │   │   ├── champion.gd      Campeón en juego: vida, congelado, sigilo, duplicados (Champion)
    │   │   ├── adalid.gd        Jugador: vitalidad, Éter, racha, nivel, reserva (Adalid)
    │   │   ├── economy.gd       Ingresos, interés, racha, premio y castigo (Economy)
    │   │   ├── synergy.gd       Conteo por clase y niveles 3/5/7 (Synergy)
    │   │   ├── battlefield.gd   Mapa de 6 posiciones, adyacencias, fuerza (Battlefield)
    │   │   ├── combat.gd        Simulador de combate por asaltos con IA simple (Combat)
    │   │   └── game.gd          Estado de partida y montaje de mapas (Game)
    │   ├── data/
    │   │   └── catalog.gd       Catálogo de cartas (Catalog)
    │   └── ui/
    │       └── main.gd          Script de la pantalla de prueba
    └── tests/
        ├── test_rules.gd        Pruebas de reglas (SceneTree, sin editor)
        └── demo_combat.gd       Imprime un combate de ejemplo
```

Pendiente de crear: `resources/` (cartas como `.tres` cuando el catálogo se estabilice), `assets/` (arte, audio) y `autoload/`.

## Supuestos de implementación

Las reglas del README no cubren todo. Lo que se decidió para poder jugar está
marcado con `SUPUESTO` en `scripts/core/rules.gd` y en los comentarios del código:

- Vitalidad inicial del adalid: 20.
- Dados: todos son d6. Pifia = 1, acierto = 4–6, crítico = 6 (también cuenta como acierto).
- Cada adalid forma 3 parejas DA+DP por asalto (Mago (3) da +1, Mago (5) otro +1).
- El mapa tiene 6 posiciones. Los dos mapas se enfrentan como filas: la posición `i`
  es adyacente a las enemigas `i-1`, `i`, `i+1` y a las propias `i-1`, `i+1`.
  El "espacio contrario" del Emboscador es la posición enemiga con el mismo número.
- Las acciones defensivas (BLOCK, ESQ) se aplican antes de resolver el daño del
  mismo asalto, aunque el orden escrito ponga ofensivas antes que defensivas:
  en la mesa todo se revela a la vez.
- PRO sin cantidad produce 1 de Éter; CUR sin valor cura 1.
- "3 interés" se interpreta como +3 de Éter por ronda si se tiene Éter ahorrado.
- Las 12 cartas comunes del catálogo son relleno (`placeholder = true`); las 200
  cartas reales no están documentadas.
- Sinergias implementadas: Asesino (3) sigilo y doble daño, Ángel (3)/(5) vida
  inicial, Protector (3)/(5) bonus de DA y bloqueo, Tierra (5)/(7) reducción,
  Aire (3)/(5)/(7) esquiva, Hielo (3) congelar, Robot (3)/(5) producción, Mago (3)/(5)
  dados extra. El resto (Fuego, Eléctrico, Salvaje, Demonio, Ángel venganza, etc.)
  y las habilidades `SPEC` de elementales y héroes solo están descritas en `notes`.

## Convenciones

- Lenguaje: GDScript con tipado estático (`var vida: int = 20`, `func atacar() -> void`).
- Nombres: `snake_case` para archivos, funciones y variables; `PascalCase` para
  clases y nodos; `SCREAMING_SNAKE_CASE` para constantes.
- Idioma: identificadores en inglés, textos visibles para el jugador y comentarios en español.
- Un script por escena, señales para comunicar hijos → padres, llamadas directas para padres → hijos.
- La lógica de reglas (daño, dados, Éter, rachas) va en scripts puros sin dependencia de nodos,
  para que se pueda probar sin abrir el editor.
- No editar `.tscn`/`.tres` a mano salvo cambios triviales; el editor reescribe el formato.

## Flujo de trabajo

- Tras crear scripts nuevos con `class_name`, regenerar la caché de clases:
  `godot --headless --path adalides --import`
- Ejecutar las pruebas de reglas (deben quedar en 0 fallos):
  `godot --headless --path adalides -s tests/test_rules.gd`
- Ver un combate de ejemplo: `godot --headless --path adalides -s tests/demo_combat.gd -- 2026`
- Verificar que la escena principal carga: `godot --headless --path adalides --quit-after 5`
- Abrir el editor: `godot -e --path adalides`
- Rama principal: `master`. Commits en español, en presente ("Agrega la escena de combate").
- No subir `adalides/.godot/` ni exportaciones; ya están en `.gitignore`.

## Glosario rápido

- **Éter**: recurso para comprar campeones. Se empieza con 20.
- **DA / DP**: dado de acción / dado de posición. Se emparejan en secreto cada asalto.
- **Asalto**: ronda de combate. Un combate dura máximo 4 asaltos.
- **Sinergia**: bonificación por tener 3, 5 o 7 campeones de una clase.
- **Comunes / Elementales / Héroes**: niveles de campeón; duplicarlos da +1/+1, +3/+3 y +5/+5.
