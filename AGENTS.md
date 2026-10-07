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
    ├── node_3d.tscn   Escena inicial (placeholder)
    └── icon.svg
```

Organización prevista dentro de `adalides/` a medida que crezca:

- `scenes/` — escenas `.tscn` (una carpeta por sistema: `combate/`, `tienda/`, `ui/`).
- `scripts/` — scripts `.gd` que no van pegados a una escena concreta (reglas, dados, estado del juego).
- `resources/` — recursos `.tres` (cartas de campeón, sinergias, configuración).
- `assets/` — arte, audio, fuentes.
- `autoload/` — singletons registrados en `project.godot`.

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

- Verificar que el proyecto carga sin errores:
  `godot --headless --path adalides --quit`
- Ejecutar una escena concreta en headless:
  `godot --headless --path adalides scenes/<escena>.tscn --quit-after 60`
- Abrir el editor: `godot -e --path adalides`
- Rama principal: `master`. Commits en español, en presente ("Agrega la escena de combate").
- No subir `adalides/.godot/` ni exportaciones; ya están en `.gitignore`.

## Glosario rápido

- **Éter**: recurso para comprar campeones. Se empieza con 20.
- **DA / DP**: dado de acción / dado de posición. Se emparejan en secreto cada asalto.
- **Asalto**: ronda de combate. Un combate dura máximo 4 asaltos.
- **Sinergia**: bonificación por tener 3, 5 o 7 campeones de una clase.
- **Comunes / Elementales / Héroes**: niveles de campeón; duplicarlos da +1/+1, +3/+3 y +5/+5.
