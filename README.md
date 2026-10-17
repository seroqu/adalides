# Adalides del demiurgo

Adaptación digital del juego de mesa **Adalides del demiurgo**, hecha con [Godot 4.7](https://godotengine.org/) y GDScript.

- El proyecto de Godot está en `adalides/` (`godot --path adalides` para jugar, `godot -e --path adalides` para editar).
- Las reglas vigentes están a continuación. Son la transcripción ordenada del documento de diseño
  `adalides/adalides_doc/Adalides del demiurgo 2 columnas.pdf` y de los tableros, más las decisiones del autor
  sobre lo que el documento no fija (marcadas como **Decisión del autor**). La versión anterior de las reglas
  (sinergias 3/5/7, dados DA+DP, estertores) quedó obsoleta y vive solo en el historial de git.
- Si trabajas con un agente de IA, lee `AGENTS.md`.

---

## Índice

1. [Resumen](#resumen)
2. [Dados](#dados)
3. [Tablero personal](#tablero-personal)
4. [El ciclo](#el-ciclo)
5. [La batalla](#la-batalla)
6. [Campeones](#campeones)
7. [Habilidades elementales](#habilidades-elementales)
8. [Habilidades de arquetipo](#habilidades-de-arquetipo)
9. [Poderes de personaje](#poderes-de-personaje)
10. [Hechizos](#hechizos)
11. [Quintaesencias](#quintaesencias)
12. [Glosario](#glosario)
13. [Pendiente de diseño](#pendiente-de-diseño)

---

## Resumen

Cada jugador es un **adalid** que construye un ejército de **campeones** con **Éter** y lo enfrenta al de los demás en
batallas automáticas. La partida avanza por **ciclos**: draft de cartas, mercado y mejoras del tablero personal,
alineación en el tablero de batalla y las batallas que marca la tabla. Quien se queda sin vida se desintegra; el último
en pie es el nuevo demiurgo. Si los dos últimos caen a la vez, gana el Demiurgo.

## Dados

Los dados de poder son **dados de tres caras**: `−`, neutra (`○`) y `+`. La pista **Dados** del tablero personal
(1 → 6) es el **total de dados que se lanzan por asalto**. Los dados se reparten entre los poderes de los campeones
(*Decisión del autor: todo ocurre internamente; el jugador no asigna dados*):

| Resultado | Dados que lo forman |
|-----------|---------------------|
| `--` Pifia | dos caras `−` |
| `-` Fallo | una cara `−` |
| `○` Neutro | una cara neutra (solo activa poderes sin requisito) |
| `+` Acierto | una cara `+` |
| `++` Crítico | dos caras `+` |

Un poder con requisito (`++`, `+ o ++`, `-`…) se activa gastando las caras que lo forman; el motor activa el mayor
número de poderes posible, empezando por los campeones más fuertes y gastando lo mínimo en cada uno. Los poderes
activos sustituyen al ataque básico; los pasivos se suman. Las comprobaciones sueltas de las habilidades ("lanza un
dado; con ++/+/-") tiran dos d3 y suman (*supuesto*). El *Trueno* de la Tormenta cae con un `++`.

Algunas habilidades usan un **d20** para señalar casillas (1–15; 16–20 no señalan nada) y un d6 para columnas o filas.

## Tablero personal

| Pista | Valores | Qué es |
|-------|---------|--------|
| Éter | 0–99 | Recurso para comprar y mejorar |
| Vida | 1–30 | Se empieza con **30** |
| Racha | 0 · 5 · 10 · 15 · 20 · 25 · 30 | Bono de Éter por victorias **o derrotas** seguidas |
| ✔ / ✖ | | Si la racha es de victorias o de derrotas |
| Cuartel | 8 · 11 · 14 · **H** · 17 · 20 · **H** | Cuántas cartas base caben en el cuartel; cada **H** desbloquea un hueco de héroe |
| Campeones en batalla | 3 · 4 · 5 · 6 · 7 · 8 · 9 | Cuántos campeones puedes alinear |
| Dados | 1 · 2 · 3 · 4 · 5 · 6 | Cuántos dados lanzas por asalto para activar poderes |

Recordatorios impresos en el tablero:

- **Roll 2**: refrescar el mercado cuesta 2 de Éter.
- **Mejora**: avanzar una casilla en una pista cuesta **5 + 5 por cada mejora anterior en esa misma pista**
  (5, 10, 15, 20…). Ejemplo: cuartel 8→11 cuesta 5, 11→14 cuesta 10, 14→H cuesta 15. *Decisión del autor.*
- **Interés 3 por cada 10 de Éter** ahorrados.

### Economía

- Se empieza con **30 de Éter** y **30 de vida**. *Decisión del autor.*
- Cada ciclo se cobra **10 + interés + bono de racha**. *Decisión del autor.*
- Vender una carta devuelve la mitad de su coste (mínimo 1). *Supuesto de la implementación.*

## El ciclo

1. **Draft** (solo en el primer ciclo). Se muestran **3 × jugadores** cartas del mazo del demiurgo (nunca héroes;
   si salen se reemplazan). Cada adalid toma **2**, por turnos en orden de serpiente (estilo Catan).
   *Supuesto:* empieza quien tiene menos vida.
2. **Mercado y mejoras.** Cada adalid cobra (salvo en el primer ciclo), compra cartas del mercado (4 cartas;
   refrescar cuesta 2), vende y mejora su tablero personal. La fase dura **60 segundos** en la versión digital.
   Los héroes cuestan **10**, aparecen en el mercado aunque no quepan y solo se pueden comprar con un hueco **H** libre.
   El mazo del demiurgo es **finito**: las cartas que tienen los demás adalides no vuelven a salir hasta que se vendan
   o su dueño sea eliminado.
3. **Alineación.** Cada adalid coloca hasta *campeones en batalla* cartas de su cuartel en su tablero de 3 × 5.
4. **Batallas.** Antes de cada ciclo los contrincantes toman una **ficha de destino**: las batallas siguen la tabla.

| 4 jugadores | | |
|---|---|---|
| A–B | A–C | A–D |
| C–D | B–D | B–C |

| 6 jugadores | | | | |
|---|---|---|---|---|
| A–B | A–C | A–D | A–E | A–F |
| C–D | B–E | B–F | B–D | B–C |
| E–F | D–F | C–E | C–F | D–E |

Cada columna es un ciclo; al acabar la tabla vuelve a empezar. Si un adalid eliminado deja a otro sin rival, los
sueltos se emparejan entre sí; si queda uno solo, descansa. *Supuesto.*

## La batalla

### Tablero

Cada adalid tiene un tablero de **3 filas × 5 columnas** más 2 huecos de hechizo. Los dos tableros se enfrentan por
la **fila 1** (el frente) formando una cuadrícula de 6 × 5 por la que los campeones se mueven libremente. *Supuesto.*
La **distancia** es el número mínimo de movimientos ortogonales; **adyacente** = a distancia 1. La **casilla opuesta**
es el espejo de la propia en el tablero rival.

### Movimiento y objetivo

Los campeones actúan solos:

- **Movimiento**: 1 paso por asalto (*Decisión del autor*; los Salvajes tienen más). Se mueve primero por el eje de
  mayor distancia y luego por el menor, y se prioriza atrás/adelante sobre izquierda/derecha. Si dos campeones se van
  a mover el uno hacia el otro y se encuentran en diagonal, avanza el que más vida tenga y el otro se queda quieto.
- **Objetivo**: el enemigo más cercano con la misma prioridad; a igual distancia, la misma columna antes que los lados
  y la derecha antes que la izquierda. Un campeón en sigilo no puede ser elegido.
- **Alcance** de ataque: 1 (adyacente) salvo **Arquero 3** y **Mago 2**. *Decisión del autor.*

### Asalto

Una batalla son **4 asaltos** (la versión digital permite elegir 2, 3, 4 o «hasta el final»). Al empezar cada asalto el adalid lanza tantos dados como marque su pista de dados y el
motor los reparte entre sus campeones: cada poder necesita un dado y (a veces) un resultado concreto. Un **poder activo
(PA)** sustituye la acción del campeón; un **poder pasivo (PP)** se suma a su acción normal. Sin dado, el campeón ataca.
En la versión digital los asaltos se resuelven solos cada 2 segundos y se animan (movimientos, daño, poderes y tiers);
se pueden detener y avanzar de uno en uno. El orden es:

1. **HI** — Habilidad instantánea
2. **M** — Movimiento
3. **HR** — Habilidad rápida
4. **A** — Ataque (solo los que no usaron habilidad activa)
5. **H** — Habilidad normal
6. **HF** — Habilidad de fin de asalto

### Fin de la batalla

- Pierde quien tenga **menos campeones** al final de los 4 asaltos (tras la última HF) o quien se quede sin ellos.
- El perdedor pierde **tanta vida como batallas se hayan realizado** (contando esta) **+1 por cada campeón de ventaja**
  del rival (no cuenta el primero, que es el que da la victoria).
- **Empate**: los dos perdieron.
- Si los dos últimos adalides mueren a la vez, gana el Demiurgo.

## Campeones

Cada campeón base es un **arquetipo** (Robot, Salvaje, Ángel, Demonio, Mago, Arquero, Defensor, Asesino, Pirata,
Muerto) de un **elemento** (Fuego, Trueno, Tierra, Aire, Hielo). Los **héroes** combinan dos arquetipos, cuestan 10 y
no tienen elemento (*supuesto*).

### Poder inicial (ataque/vida) y precio

Valores del documento, ya con las anotaciones aplicadas: **+2 de vida a todos** salvo Arqueros, Magos y Piratas
(**+1**), y **+1 de ataque a los Asesinos**.

| | Robot | Salvaje | Ángel | Demonio | Mago | Arquero | Defensor | Asesino | Pirata | Muerto |
|---|---|---|---|---|---|---|---|---|---|---|
| **Fuego** | 2/4 · 1 | 2/6 · 2 | 2/6 · 2 | 3/6 · 3 | 2/3 · 2 | 1/3 · 1 | 1/6 · 1 | 3/3 · 1 | 2/7 · 3 | 2/6 · 2 |
| **Trueno** | 2/8 · 3 | 2/4 · 1 | 1/8 · 2 | 2/6 · 2 | 2/3 · 2 | 2/5 · 3 | 1/6 · 1 | 4/4 · 2 | 1/5 · 1 | 1/6 · 1 |
| **Tierra** | 2/6 · 2 | 2/4 · 1 | 1/6 · 1 | 1/6 · 1 | 1/3 · 1 | 2/3 · 2 | 1/10 · 3 | 4/4 · 2 | 1/7 · 2 | 2/8 · 3 |
| **Aire** | 1/6 · 1 | 3/6 · 3 | 2/8 · 3 | 2/6 · 2 | 1/3 · 1 | 2/3 · 2 | 1/8 · 2 | 3/3 · 1 | 1/7 · 2 | 1/6 · 1 |
| **Hielo** | 2/6 · 2 | 2/6 · 2 | 1/6 · 1 | 1/6 · 1 | 2/5 · 3 | 1/3 · 1 | 1/8 · 2 | 6/4 · 3 | 1/5 · 1 | 2/6 · 2 |

Formato: ataque/vida · precio en Éter.

### Héroes (10 Éter)

| Héroe | Arquetipos | Ataque/vida |
|-------|-----------|-------------|
| Robot caballero | Robot + Defensor | 3/8 |
| Salvaje asesino | Salvaje + Asesino | 7/4 |
| Ángel arquero | Ángel + Arquero | 4/5 |
| Demonio mago | Demonio + Mago | 3/6 |
| Pirata muerto | Pirata + Muerto | 4/7 |

### Copias, duplicados y afinidad

- **2.ª copia (duplicado)**: +1/+1 y el poder de la carta mejora.
- **3.ª copia**: afinidad (AFI) 1. **4.ª copia**: AFI 2. Cada punto de AFI da +1 de ataque y +1 de vida.
- Los valores `(a/b/c/d)` de un poder corresponden a 1 copia / 2 copias / AFI 1 / AFI 2.
- Las copias cuentan para la capacidad del cuartel.

## Habilidades elementales

Tiers **3 / 6 / 9** campeones del elemento **en la batalla** (*Decisión del autor*). "La mitad" o "un tercio" se
redondean hacia abajo.

- **Fuego** — *Quemadura*: los Fuego hacen (la mitad / la mitad / el total) de su daño de ataque básico a los otros
  campeones a (1/2/3) casillas del objetivo. *Piel ígnea*: los Fuego no reciben daño por quemadura.
- **Hielo** — *Venas heladas*: cada vez que un Hielo daña con su ataque básico lanza un dado; con (++ / + / -) el
  enemigo queda congelado. *Quebrar*: un enemigo congelado atacado por un Hielo muere resquebrajado.
- **Trueno** — *(HF) Tormenta*: lanza (1/2/4) dados de tormenta y haz (1/2/4) daños a los enemigos de esa columna.
  *Trueno*: si un dado saca 6 mata al enemigo con más vida máxima (a igual vida, el de más ataque; si siguen empatando,
  mueren ambos).
- **Aire** — *Céfiro*: cada vez que un Aire va a recibir daño directo lanza un dado; con (++ / + / -) lo esquiva.
  *(HI) Tifón*: lanza (1/2/4) d20; los enemigos en esas casillas son arrastrados (1/2/3) espacios hacia atrás; si chocan
  con otro o no tienen sitio, ambos reciben (1/2/3) de daño verdadero.
- **Tierra** — *Piel pétrea*: todos los ataques a un Tierra reducen su daño en (1/2/4). *Roca afilada*: quien ataque
  cuerpo a cuerpo a un Tierra recibe (0/1/2) de daño.

## Habilidades de arquetipo

Tiers **2 / 4 / 6** campeones del arquetipo en la batalla.

- **Ángel** — *(HF) Luz renovadora*: cura (1/2/4) a todos los aliados heridos. *(HF) Resurrección*: lanza (4/2/1)
  dados; si todos aciertan, resucita a todos los aliados muertos este asalto. *Pacto de fe*: al comenzar asigna (1/2/3)
  dados de fe a tus campeones; al final lanza los de los que sobrevivan y cura al adalid la cantidad de `+`.
- **Demonio** — *Maldición*: quien mata a un demonio queda maldito; *(HI)* lanza un dado y con (++ / + / -) muere.
  *(HI) Herejía*: lanza (1/2/3) d20; los enemigos en esas casillas pierden sus (habilidades / habilidades y arquetipo /
  habilidades, arquetipo y elemento). *Pacto demoníaco*: antes del combate el demonio hace (1/2/3) preguntas de sí o no
  sobre el tablero enemigo; el rival puede mentir, pero cada mentira cuesta (1/2/3) de vida.
- **Arquero** — *Disparo certero*: todos los arqueros ganan (1/2/4) de ataque. *A los puntos vitales*: al atacar lanza un
  dado; con (++ / ++ / +) duplica su daño básico.
- **Mago** — *(HI) Magia desatada*: lanza (1/2/4) d20; los aliados en esas casillas realizan sus poderes como si el
  resultado fuera (- / + / ++). *(HF) Amplificación arcana*: el daño y la sanación de tus hechizos aumentan en (0/1/2).
- **Defensor** — *Unidad defensiva*: al comenzar, por cada defensor alrededor (incluidas diagonales) de otro defensor,
  este gana (0/1/2) de vida. *Bloqueo*: un defensor recibe el daño que fueran a recibir los aliados no defensores
  adyacentes.
- **Pirata** — *Tatuko*: cuando un pirata mata, lanza un dado: `--` pierde (2/1/0) de vida; `-` recupera (0/1/2);
  `+` gana (1/2/3) de Éter; `++` roba (1/2/4) cartas del mazo. *(6) Venganza*: cuando un adalid enemigo te gana una
  batalla lanza un dado: `--` nada; `-` sabotaje (baja un marcador del tablero enemigo); `+` saqueo (roba 10 de Éter);
  `++` oleada de cañones (roba una carta del cuartel enemigo).
- **Muerto** — *(6) Ejército de la tumba*: los muertos no dejan de atacar hasta que todos los demás muertos pierdan su
  vida, pero no cuentan como objetivos. *(HF) Marchitar*: cada turno los vivos enemigos pierden (1/2/2) de ataque.
- **Asesino** — *(0) Marcado para morir*: al comenzar, los asesinos saltan hacia la víctima más cercana a la casilla
  opuesta de donde están. *(2) Sigilo*: todos comienzan en sigilo. *Desde las sombras*: al salir de sigilo ganan
  (1 / 2 / el doble) de daño de ataque y (0/1/2) de daño de habilidad. *Capa negra*: al matar, lanza un dado; con
  (++ / + / -) vuelve al sigilo.
- **Robot** — *Optimización*: aumentan su producción de Éter en (1/2/5). *Protocolo de protección*: recibes (1/2/4)
  menos de daño al perder una batalla. *(6) Hackeo*: los dados enemigos empeoran un rango (`++`→`+`, `+`→`-`, `-`→`--`).
- **Salvaje** — *Alas de ave*: se mueven (1/2/4) pasos más. *Frenesí canino*: hacen (1/2/3) veces sus habilidades.
  *(6) Garras felinas*: golpean también a los objetivos diagonales en la dirección de su objetivo.

## Poderes de personaje

Cada campeón tiene un poder que activa con un dado. `Req` indica el resultado necesario; `PA` sustituye la acción,
`PP` se suma a ella. Los valores `(a/b/c/d)` son por copias (1 / 2 / AFI 1 / AFI 2).

| Campeón | Poder | Fase | Tipo | Req | Efecto |
|---|---|---|---|---|---|
| Ángel de fuego | Aura de retribución | HI | PA | | Este asalto, los enemigos a distancia (0/1/2/3) que hagan un ataque básico reciben 1+AFI |
| Ángel de hielo | Aura estoica | HI | PA | | Aliados a distancia (0/1/2/3) tienen (0/0/1/2) movimientos menos y son inmunes a control |
| Ángel de trueno | Curación relámpago | HF | PP | | Lanza (0/1/2/3) dados; los aliados de esas filas curan 1+AFI |
| Ángel de aire | Aura de paz | HI | PA | | El daño directo a aliados a distancia (0/1/2/3) se reduce en 1+AFI |
| Ángel de tierra | Aura de resurrección | HF | PA | | Resucita (0/0/1/2) aliados muertos este asalto (distancia ≤ 2) con 1+AFI de vida |
| Demonio de fuego | Inmolación infernal | HF | PP | | Se suicida: 0+AFI de vida al adalid y maldice a los (0/1/2/3) enemigos más cercanos |
| Demonio de hielo | Abjuración herética | HI | PP | ++ | Congela a los afectados por Herejía y usa 1+AFI poderes robados |
| Demonio de trueno | Cosecha oscura | HF | PA | | Lanza (0/1/2/3) dados; los malditos en esas columnas mueren; si cosecha ≥1, AFI al adalid enemigo |
| Demonio de aire | Hedor profano | HF | PA | ++ | 1+AFI a los enemigos que se muevan el siguiente asalto |
| Demonio de tierra | Sepultar | HF | PA | | Se entierra con los enemigos a (0/0/1/2) y maldice a AFI enemigos cercanos |
| Arquero de fuego | Disparo de fuego | HI | PP | | El siguiente ataque gana (0/0/1/2)+AFI |
| Arquero de hielo | Disparo de hielo | H | PA | | Congela al objetivo y a los enemigos a (0/0/1/2), con 1+AFI de daño |
| Arquero de trueno | Tormenta de flechas | H | PA | | Lanza (0/1/2/3) dados; ataque base a los enemigos de esas columnas |
| Arquero de aire | Disparos de viento | HI | PP | | El siguiente golpe empuja 1+AFI atrás y aplica Céfiro |
| Arquero de tierra | Camuflaje | HI | PP | ++ | Esquiva el daño de poderes este turno |
| Mago de fuego | Bola de fuego | H | PA | + ++ | Golpea con (2+AFI) × su ataque |
| Mago de hielo | Congelación profunda | HI | PP | - -- | Aliados a distancia 0+AFI (y él) inmunes a todo daño |
| Mago de trueno | Energizar | H | PA | | El aliado con más vida gana (0/1/2/3)+AFI de ataque |
| Mago de aire | Distancia | H | PA | | Empuja (0/1/2/3) a los que estén a 1; aplica Céfiro |
| Mago de tierra | Arenas movedizas | HI | PA | + ++ | Anula las habilidades de los enemigos a 1 |
| Defensor de fuego | Cauterizar | A | PP | ++ | Sus ataques fijan la vida máxima del enemigo en lo que le queda |
| Defensor de hielo | Armadura de escarcha | HI | PP | ++ | Los que lo ataquen con ataques normales quedan congelados |
| Defensor de trueno | Electrocutar | HI | PP | + ++ | Los que lo ataquen reciben 1+AFI y se lo hacen a sus adyacentes |
| Defensor de aire | Viento arrebatado | HI | PP | - | Evita los ataques básicos este asalto |
| Defensor de tierra | Escudo reflectivo | HI | PA | ++ | Un dado por hechizo que lo afecte; con ++ lo refleja |
| Pirata de fuego | Pistolazo | HI | PP | | Siguiente ataque +(0/1/2/3) y rebota a 1+AFI enemigos cercanos |
| Pirata de hielo | Agarre de kraken | H | PA | ++ | Atrae a los (0/0/1/2) enemigos más lejanos y los congela |
| Pirata de trueno | Saquear el tesoro | HF | PA | | Roba (0/1/2/3)+AFI de Éter al enemigo |
| Pirata de aire | Enemigo a la vista | H | PA | | Un enemigo recibirá (0/1/2/3) más de daño de cualquier fuente |
| Pirata de tierra | Tengo un jarrón | HI | PA | ++ | Quien contribuya a matarlo este asalto muere con él |
| Muerto de fuego | Fundir | H | PA | | Deja al objetivo con (4/3/2/1)−AFI de vida |
| Muerto de hielo | Frío fantasmal | H | PA | | Los enemigos a (0/0/1/2) pierden el turno si no han usado habilidad |
| Muerto de trueno | Drenar energía | HF | PA | ++ | Iguala la vida de los enemigos a (0/1/2/3) × su ataque |
| Muerto de aire | Aire vital | HF | PP | ++ | Si mata este turno, revive a la víctima atacando a su equipo |
| Muerto de tierra | Tierra maldita | HF | PP | ++ | Si muere este turno queda tirado; los enemigos a (0/0/1/2) reciben 1+AFI al final |
| Asesino de fuego | Corte de fuego | H | PA | | Su daño se extiende (0/0/1/2) casillas en la dirección del enemigo |
| Asesino de hielo | Corte helado | H | PA | | Además congela a los enemigos a (0/0/1/2) en esa dirección |
| Asesino de trueno | Golpe rebotante | H | PA | ++ | Cada vez que mate este turno salta a su nuevo objetivo y golpea |
| Asesino de aire | Golpe fantasma | HI | PA | | Cambia el objetivo de su objetivo por el aliado más lejano |
| Asesino de tierra | Capa de sombras | HI | PA | | Pone en sigilo a los aliados a (0/1/2/3) |
| Robot de fuego | Caldero a presión | HF | PA | | 1+AFI a los enemigos a (0/0/1/2); por cada herido produce 1 de Éter |
| Robot de hielo | Cero absoluto | H | PA | | Congela a todos a (0/0/1/2); por cada congelado produce 1 de Éter |
| Robot de trueno | Energía renovable | HI | PP | ++ | Por cada 1 de daño recibido este asalto produce 1+AFI de Éter |
| Robot de aire | Energía eólica | HI | PP | ++ | Cada vez que alguien esquive este asalto produce 1+AFI de Éter |
| Robot de tierra | Excavadora | HF | PA | | Túnel a la posición contraria con los aliados a (0/1/2/3); AFI de daño a enemigos a (0/0/0/1); 1 de Éter por daño |
| Salvaje de fuego | Garras ígneas | HI | PA | ++ | +1+AFI de daño el resto del combate |
| Salvaje de hielo | Quebrar | HF | PA | | (1/2/3/4)+AFI a los congelados a (0/0/1/2) del objetivo y los descongela |
| Salvaje de trueno | Saltos continuos | H | PP | | Al atacar lanza su dado; si supera al asignado salta al enemigo más lejano (++ siempre) |
| Salvaje de aire | Agilidad trémula | M | PP | + ++ | Este turno puede moverse y atacar |
| Salvaje de tierra | Espinas afiladas | HI | PA | -- - | Roca afilada aumenta en 1+AFI este asalto |
| **Ángel arquero** | Aura de puntería divina | HI | PP | -- | Este asalto el daño también cura aliados y la curación daña enemigos |
| **Demonio mago** | Atracción letal | H | PA | -- | Atrae a los 1+AFI enemigos más lejanos y los maldice |
| **Robot caballero** | Matriz de protección | HI | PA | -- | Anula los poderes usados a distancia 1+AFI |
| **Pirata muerto** | Oro maldito | HF | PP | | Si no muere, al final roba 1+AFI de vida al adalid enemigo |
| **Salvaje asesino** | Frenesí | HF | PA | -- | Solo en el último asalto: ataca a todos los enemigos y muere |

## Hechizos

Cartas con afinidad elemental que se descartan al usarse. Se compran con Éter y se activan con **4 dados** que pueden
"pagarse" con sinergias elementales o de arquetipo. El número entre paréntesis es el asalto en que actúan.

| Hechizo | Asalto / fase | Efecto |
|---|---|---|
| Tsunami de lava | (4) HF | 5 de daño a todos los campeones enemigos, sin resistencia posible |
| Llamas abrasadoras | (2) HI | Este turno todos tus campeones tienen 1 más de daño |
| Cubo de hielo | PP | Este turno no recibes daño de fatiga |
| Nova de escarcha | (3) HF | Congela a todos los enemigos |
| Abrir la tierra | (1) HI | Todos los campeones de la fila 1 de cada jugador mueren sepultados |
| Resistencia del diamante | (2) HI | Tus campeones son inmunes al daño este turno |
| Cadena de truenos | (3) HF | Mata a todos los campeones de las columnas pares |
| Recargar | (2) HF | Tus aliados recuperan toda su vida |
| Corriente continua | (1) HI | Tras ver la posición inicial, 5 segundos para cambiar dos campeones de sitio |
| Pies livianos | PP | Durante todo el combate tus campeones tienen un movimiento más |

## Quintaesencias

Cartas que permiten a un campeón contar como parte de un arquetipo al que no pertenece. Solo se equipan en un campeón con
**AFI 2** y no se quitan salvo que se venda el campeón; en ese caso la quintaesencia se vende por la mitad de su precio.

## Glosario

- **Congelado**: se coloca un contador de hielo; en la fase de movimiento el campeón con contador no actúa y se le quita.
- **Daño / vida básica**: la del campeón contando solo los bonificadores de duplicación.
- **Cuartel**: donde el adalid guarda todos sus campeones.
- **Distancia**: movimientos ortogonales mínimos entre dos casillas. **Adyacente**: a 1.
- **Sigilo**: no puede ser elegido como objetivo; se sale al hacer o recibir daño o habilidad.
- **AFI (afinidad)**: 3.ª copia 1, 4.ª copia 2; +1 ataque y +1 vida por punto.
- **Maldito**: lanza un dado cada asalto; según el tier Demonio puede morir.
- **Sepultado**: fuera de la batalla (Sepultar, Abrir la tierra).

## Pendiente de diseño

Lo que el documento no fija y la implementación resuelve con un supuesto (ver `AGENTS.md`), o que falta por diseñar:

- Imágenes: piratas y arqueros de los cinco elementos, caballero de fuego, salvaje de trueno, asesino (ninja) de tierra,
  robot caballero, ángel arquero, demonio mago, pirata muerto.
- Cómo se compran los hechizos y las quintaesencias (precio, dónde aparecen) y qué es el "daño de fatiga".
- Qué dados (d6/d20) usan Tormenta, Curación relámpago, Cosecha oscura y Tormenta de flechas para señalar columnas/filas.
- Elemento de los héroes y si el "5/6 base" de la tabla de héroes es una carta.
- Tamaño del mercado y orden del draft.


## Modos de juego y tutorial (versión digital)

- **Principiante, Amateur y Profesional** cambian solo la inteligencia de los rivales (elección de cartas,
  mejoras y refrescos del mercado). Las reglas son las mismas.
- Partidas de **4 o 6 adalides**, para que nadie descanse ningún ciclo.
- **Tutorial**: duelo guiado contra un rival con 5 de vida y 5 de Éter, sin temporizadores, que enseña el draft,
  la alineación, la batalla asalto a asalto, el mercado y las mejoras en dos ciclos.
