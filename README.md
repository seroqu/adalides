# Adalides

Adaptación digital del juego de mesa **Adalides**, hecha con [Godot 4.7](https://godotengine.org/) y GDScript.

- El proyecto de Godot está en la carpeta `adalides/` (ábrela desde el gestor de proyectos o con `godot -e --path adalides`).
- Las reglas del juego están a continuación en este mismo archivo.
- Si trabajas con un agente de IA, lee `AGENTS.md`.

---

## Reglas del juego

Bienvenido a Adalides, el juego de mesa en el que has sido escogido como aspirante para reemplazar al demiurgo. En esta guía encontrarás todas las reglas del juego.

### Índice

1. [Componentes](#componentes)
2. [Objetivo del juego](#objetivo-del-juego)
3. [Economía de Éter](#economía-de-éter)
4. [Clases](#clases)
5. [Duplicar cartas](#duplicar-cartas)
6. [Palabras clave](#palabras-clave)
7. [Combate](#combate)
8. [Sinergias por clase](#sinergias-por-clase)
9. [Señores elementales](#señores-elementales)
10. [Héroes](#héroes)
11. [Legendarios](#legendarios)
12. [Requisitos para usar campeones](#requisitos-para-usar-campeones)
13. [Muerte de un adalid y estertores](#muerte-de-un-adalid-y-estertores)
14. [Glosario de dados](#glosario-de-dados)

---

### Componentes

| Cantidad | Componente | Detalle |
|---------:|------------|---------|
| 6 | Tableros de jugador | |
| 48 | Marcadores de desarrollo | 7 por color |
| 114 | Dados | 19 por color |
| 30 | Hexágonos de movimiento oculto | 6 por color |
| 12 | Mapas de combate | 2 por jugador, cada uno de 2 caras |
| 200 | Cartas de campeón | |

### Objetivo del juego

El demiurgo, señor y creador de todo lo que ha existido y existirá, se quiere retirar. Para reemplazarlo nombró a 6 seres de inconmensurable poder como sus posibles sucesores. A cada uno lo dotó con el poder de crear seres y le dio un poco de **Éter**, la materia elemental con la que se crean todas las cosas, y le ordenó crear un ejército digno de su magnificencia. Pero esta es una competencia a muerte: quien no tenga un ejército digno del demiurgo se desintegrará poco a poco hasta quedar reducido al mismo Éter del que fue hecho.

Tú eres uno de esos adalides. ¿Serás capaz de gestionar tus recursos y tu ingenio para ganar el puesto de creador de todas las cosas?

Para lograrlo, lo único que debes hacer es borrar a tus competidores de la existencia misma, cosa que conseguirás cuando lleves sus **puntos de vitalidad** a 0.

### Economía de Éter

| Concepto | Éter |
|----------|-----:|
| Éter inicial | 20 |
| Por ganar un combate | 7 |
| Por racha | 2 por cada racha |
| Interés | 3 |
| Por ronda | 10 |

### Clases

| Color | Clase |
|-------|-------|
| Rojo | Fuego |
| Amarillo | Eléctrico |
| Café | Tierra |
| Gris | Aire |
| Azul oscuro | Hielo |
| Verde | Salvaje |
| Plata | Robot |
| Morado | Mal (Demonio) |
| Dorado | Bien (Ángel) |
| Escudo | Protector |
| Daga | Asesino |
| Símbolo arcano | Mago |

### Duplicar cartas

Por cada carta duplicada el campeón recibe una bonificación según su tipo:

| Tipo de campeón | Bonificación por duplicado |
|-----------------|---------------------------|
| Común | +1/+1 |
| Elemental | +3/+3 |
| Héroe | +5/+5 |

### Palabras clave

#### Aclaraciones

- Si una palabra clave está seguida por otra entre paréntesis, esta última se refiere a su objetivo.
- Si hay dos palabras clave en una acción, la primera es condición necesaria para la segunda. Si ambas necesitan un hexágono de dirección, se colocan uno sobre otro, y el de arriba define la primera acción.

#### ATK — Atacar

Ataca a un campeón infligiendo el total de su daño. Si no hay nadie en ese espacio, no se inflige daño alguno.

- Si el atacante es de alcance **Cuerpo a cuerpo**, debe elegir la dirección del ataque.
- Si el atacante es de alcance **Emboscador**, su objetivo es el espacio contrario al que ocupa (es decir, el que tiene el mismo número).
- Si el atacante es de alcance **Rango**, se debe colocar un DP que no se esté usando para definir la posición antes de la revelación de acciones.

#### MOV — Mover

Mueve a un campeón en la dirección adyacente seleccionada. Si existe otro campeón en esa dirección, intercambian posiciones.

- No se puede mover a una casilla del mapa enemigo.
- No se puede intercambiar posición con un aliado congelado.

#### CONG — Congelar

Congela a un enemigo (esto se denota volteando la carta).

- Para descongelarlo, el enemigo debe gastar un DP que indique esa posición.
- Mientras un campeón esté congelado, no puede hacer ninguna acción.
- La acción de congelar respeta las normas de alcance, a menos que se especifique el objetivo de la misma.

#### PRO — Producir

Añade la cantidad seleccionada a tus reservas de Éter.

- Si está precedida por una acción, esta es condición necesaria para producir.

#### SPEC — Especial

Debes buscar esta ficha en el cuadernillo del demiurgo para saber qué habilidades oculta.

#### CUR — Curar

Cura a un campeón el valor indicado entre paréntesis. Se debe colocar un DP que no esté en uso para marcar el campeón que será curado.

- Si por ejemplo dice `CUR(DEF)`, ese campeón curará el valor total de sus puntos de defensa.
- Si un campeón que ha muerto por quedarse sin puntos de defensa es curado durante el mismo asalto en que sus puntos fueron reducidos a menos de 1, no morirá y quedará vivo con la diferencia que corresponda. Si esa suma es menor que 1, sigue muerto.
- Un campeón no puede ser curado por encima de su vida máxima.
- La acción de curar no respeta las normas de alcance.

#### BLOCK — Bloquear

El campeón que bloquea recibe el daño en lugar de un aliado en la dirección adyacente seleccionada.

- Si el campeón que bloquea muere, el exceso de daño se le inflige al campeón que debía recibirlo.
- El daño de área no puede ser bloqueado.

#### ESQ — Esquivar

El campeón evita el daño que le fuera a ser infligido en este asalto.

- El daño de área no puede ser esquivado.

#### ANIQUILA — Aniquilar

El campeón mata definitivamente a un campeón enemigo; es decir, el enemigo lo regresa a la baraja del demiurgo.

- Este efecto respeta las reglas de alcance.
- Esta acción no puede ser bloqueada ni esquivada.

### Combate

#### Preparación del combate

1. Cada jugador lanza 2D10 y se ordenan los resultados numéricamente. Se enfrentan los dos resultados mayores, luego el tercero y el cuarto, y así sucesivamente.
2. Si algún jugador queda sin pareja, no se enfrenta a nadie y mantiene su racha, pero no puede ganar Éter por la victoria ni aumentar su racha.
3. Se ponen las cartas de campeón boca abajo formando el mapa correspondiente a cada adalid.

El combate se divide en **asaltos**.

#### Asaltos

Cada asalto, los adalides lanzan sus DA y sus DP y forman parejas de un DA y un DP en secreto bajo la cortina de asalto. Luego estas acciones se revelan y se llevan a cabo de forma simultánea en el siguiente orden:

1. **Acciones de movimiento.** Todas de forma simultánea; si dos o más movimientos generan un conflicto, no se hace ninguno.
2. **Acciones ofensivas.** Todas aquellas que hagan daño a otros jugadores.
3. **Acciones defensivas.** Todas las que eviten algún tipo de daño.
4. **Acciones especiales.** Todas las que no clasifiquen en ninguna de las anteriores (como congelar o entrar en sigilo).

> La cantidad de parejas de dados que puede formar el adalid define la cantidad de acciones que ejecuta durante un asalto. Aun así, el adalid puede hacer acciones de combate que no implican parejas de DP y DA: son las habilidades de sus sinergias, y puede usar tantas como consiga según los requerimientos de dados de cada una.

Luego se asignan los daños. Si un campeón se queda sin puntos de defensa, es retirado de la batalla y su espacio queda libre.

#### Fin del combate

El combate puede terminar por 3 razones:

1. Que el enemigo se quede sin campeones disponibles.
2. Que pasen 4 asaltos.
3. Que un jugador se rinda, renunciando a hacer cualquier tipo de daño a los puntos de vitalidad del adalid enemigo.

En cualquiera de estos casos:

- **Se escoge al adalid ganador**: quien tenga más campeones en el campo de batalla. En caso de empate numérico no hay ganador, y ambos pierden su racha y 2 puntos de vida.
- **El perdedor recibe daño** a sus puntos de vitalidad igual a la diferencia de campeones enemigos que sigan en pie, +1. Los campeones elementales cuentan como 2 campeones y los heroicos como 3.

#### ¿Qué obtiene el ganador?

El ganador obtiene siempre 7 de Éter y es parte del primer grupo en la siguiente fase de preparación.

#### ¿Qué pasa si un adalid se queda sin puntos de vitalidad?

El adalid es **eliminado** del juego.

### Sinergias por clase

Cada clase otorga bonificaciones al tener **3**, **5** o **7** campeones de esa clase. Algunas clases tienen además un efecto de **pifia** (marcado como **P**).

#### Fuego

- **(3)** Pool de 2 DF. Cuando un fuego hace daño, lanza tantos DF como su ataque. Un crítico en un DF puede usarse para hacer un daño al adalid enemigo (este efecto anula el daño que produce en área). Un par de pifias en DF (se acumulan entre turnos) implican un daño obligatorio para el adalid que controla a los fuego.
- **(5)** Pool de 4 DF. Cada DF con un acierto causa un daño a los enemigos al lado del objetivo. Estos daños se computan como un solo impacto.
- **(7)** Pool de 6 DF. El daño de área aplica a todos los enemigos adyacentes. Puedes usar un par de DA para asignar un DF al campeón que prefieras; antes de cada asalto el enemigo lanza ese DF y, si no es un acierto, muere, aplicando daño de fuego como si se hubiera atacado a sí mismo.

#### Eléctrico

- **(P)** Con cada pifia se pierde una carga.
- **(3)** Antes de lanzar los dados de asalto, lanza 2 DA. Por cada acierto, pon un contador de carga +1/+1 en el campeón que quieras.
- **(5)** 3 DA antes de los dados de asalto. Puedes gastar un DP correspondiente a un campeón eléctrico y un par de DA para descargarlo y hacer un daño igual al número de cargas que tenga a todos los enemigos. Este efecto le quita todas las cargas al campeón seleccionado.
- **(7)** 5 DA antes de los dados de asalto. Puedes gastar un trío de DA para dejar una carga permanente en un campeón.

> Las cargas eléctricas aplican mejoras a todas las habilidades.

#### Tierra

- **(3)** Cuando un tierra pierde, recibe 1 menos de daño.
- **(5)** Todo el daño recibido se reduce en 1. Puedes usar un DP para evitar todo el daño que el campeón correspondiente va a sufrir este turno.
- **(7)** 2 menos de daño al perder. Todo el daño recibido se reduce en 3. Puedes usar un trío de DA para sepultar a un enemigo aleatorio (lanza un DP).

#### Aire

- **(3)** Cada vez que un aire recibe daño, lanza 2 DR. Si hay 2 aciertos, el aire esquiva el impacto.
- **(5)** Cada vez que un aire recibe daño, lanza 1 DR. Si hay al menos un acierto, el aire esquiva el impacto. Al comenzar la batalla, lanza un DP enemigo y exilia de la batalla al campeón en esa posición.
- **(7)** Cada vez que un aire recibe daño, lanza 2 DR. Si hay al menos un acierto, el aire esquiva el impacto. Al comenzar la batalla, lanza un DP enemigo y exilia de la batalla al campeón en esa posición. Cada crítico en un DR se puede usar como contraataque, aplicando el daño del aire al agresor.

> No se puede esquivar el daño de área.

#### Hielo

- **(P)** Cada pifia quita un marcador de hielo de un enemigo.
- **(3)** Cada vez que un hielo recibe o hace daño, lanza 1 DA. Si consigues al menos un acierto, congela al agresor u objetivo.
- **(5)** Lanza 2 DA. Cuando un hielo ataca a un enemigo congelado con un ataque directo, este muere.
- **(7)** Lanza 3 DA. Puedes usar un trío de DA para congelar a todos los campeones del enemigo.

#### Salvaje

- **(3)** Pool de 3 DS. Puedes asignar DS a tus campeones en cada asalto, máximo 1 por campeón. Cuando un campeón recibe o hace daño, puede lanzar un DS; si es un acierto, puede potenciar o atenuar ese daño con una bonificación de 1.
- **(5)** Pool de 6 DS. Máximo 2 DS por campeón. Bonificación de 2 para aumentar o atenuar el daño.

#### Robot

- **(3)** Puedes volver a lanzar los dados de asalto una vez más. Produces el doble de Éter al usar la acción producir.
- **(5)** El enemigo pierde la capacidad de volver a lanzar sus DA y juega con un dado de acción menos. Produces el triple de Éter al usar la acción producir. *(Preparación siguiente)* Todas las mejoras de tu tablero personal cuestan 3 menos si en el combate anterior tenías 5 robots en el campo de batalla.

#### Demonio (Mal)

- **(3)** Puedes usar un DP para ANIQUILAR a un campeón demonio tuyo, quitar 1 de vida a tu oponente y aumentar 1 de vida a ti. (Recuerda que aniquilar implica que ese campeón se pierde para siempre.)
- **(5)** Al aniquilar recuperas el Éter gastado en el campeón. Puedes usar un par de DA para poner en tu reserva un campeón que fuera aniquilado este combate, pagando su costo de Éter. Cuando un campeón demonio sale de un combate por cualquier razón, lanza un DP y haz su daño al campeón enemigo en esa posición. *(Preparación siguiente)* Tu tienda tiene siempre una carta más (5 en total).

#### Ángel (Bien)

- **(3)** Pool de 3 DD. Al comenzar la batalla gana 1 punto de vida. Cuando un ángel muere, lanza tantos DD como ángeles tengas; cada acierto cuenta como un daño de venganza que recibe quien causó la muerte (campeones o adalides). Este daño es directo y anula toda forma de defensa.
- **(5)** Pool de 6 DD. 2 puntos de vida al comenzar la batalla. Los críticos en DD se pueden utilizar también para ganar 1 PV del adalid. Si el enemigo castigado muere, puedes revivir a uno de tus ángeles pagando 2 puntos de vida del adalid (no puedes revivir al ángel que acaba de morir).

#### Protector

- **(3)**
  - Todos los DA usados en campeones protectores aumentan su valor en 1 (máximo 6).
  - Cuando un campeón bloquea, hace su daño al enemigo que atacó al campeón protegido.
  - Los campeones protectores pueden bloquear en 2 direcciones.
- **(5)**
  - Los campeones protectores aumentan en 5 puntos su vida.
  - Cuando un campeón bloquea, hace su daño al enemigo que atacó al campeón protegido.
  - Todos los DA usados en campeones protectores aumentan su valor en 2.
  - Cuando un campeón protector bloquea, no recibe el daño en lugar de su aliado.
  - Los campeones protectores pueden bloquear en 2 direcciones.
  - Elige arbitrariamente el valor de uno de tus dados de posición.
  - Puedes usar un par de DA para cancelar una acción del adversario (por ejemplo, un par de 3 cancela la acción número 3). Esta acción sucede antes que los movimientos.

#### Asesino

- **(3)**
  - Todos los asesinos comienzan en sigilo.
  - Los asesinos hacen el doble de daño cuando salen de sigilo.
  - Puedes usar un DP para poner en sigilo a uno de tus asesinos. Los comodines no aplican para este efecto.
- **(5)**
  - Todos los asesinos comienzan en sigilo y ganan 2 puntos de daño.
  - Los comodines también pueden poner a un asesino en sigilo.
  - Cuando un asesino sale de sigilo, puedes lanzar un DA: si aciertas, vuelve a ponerlo en sigilo; si pifias, saca de sigilo al asesino de tu preferencia.

#### Mago

- **(3)** Tienes un dado de acción más.
- **(5)** Tienes un dado de acción más.

### Señores elementales

Campeones elementales formados por dos clases. El número junto al nombre es su coste. La columna de dado indica qué acción ejecuta según el resultado del DA.

| Carta | Clases | Coste | Dado | Acción |
|-------|--------|------:|------|--------|
| **Plasma** | Fuego + Eléctrico | 7 | 6 | Hace 5 de daño a un enemigo y 1 a todos los otros |
| | | | 3–5 | MOV + ATK |
| | | | 1–2 | MOV |
| **Lava** | Fuego + Tierra | 9 | 6 | Hace un daño igual al valor de la casilla en la que está cada carta enemiga, −2 |
| | | | 4–5 | MOV + ATK |
| | | | 1–3 | BLOCK |
| **Glacial** | Hielo + Tierra | 10 | — | Bloquea todos los turnos. Cuando el glacial muere, lanza 2 DP enemigos y mata instantáneamente lo que se encuentre ahí |
| **Tormenta** | Hielo + Eléctrico | 9 | 6 | Lanza 3 dados de ubicación enemiga; hace daño a todos los que se encuentren en esos espacios y los congela |
| | | | 3–5 | ATK |
| | | | 1–2 | MOV |
| **Señores del aire** | Aire | 10 | 6 | Hacen su daño a todos los enemigos |
| | | | 4–5 | Ataca y mueve |
| | | | 3 | Mueve un enemigo y ataca |
| | | | 1–2 | MOV |

Notas sobre los Señores del aire:

- Todos tienen posibilidad de esquivar daño sacando 6 en un d6.
- Su daño es el cuadrado de la cantidad de señores elementales que existan en la mano del adalid.

### Héroes

Campeones formados por tres clases. Las letras indican las clases que los componen: **F** Fuego, **E** Eléctrico, **T** Tierra, **A** Aire, **H** Hielo, **R** Robot, **M** Mal, **P** Protector.

| Carta | Clases | Dado | Acción |
|-------|--------|------|--------|
| **Demonio eléctrico** | M E F | 3–6 | Toma un aliado adyacente y lo hace explotar, haciendo todo su daño al enemigo y la mitad a los aliados |
| | | 1–2 | MOV + ATK |
| **Demonio de arena** | M T F | 3–6 | Tira 5 dados de ubicación enemiga, roba la mitad de esa vida y añádela al demonio de arena |
| | | 1–2 | BLOCK |
| **Mago de plasma** | E F M | 3–6 | Explota y hace daño a todos los no magos |
| | | 1–2 | Duplica su daño |
| **Mago de tormenta** | E H M | 4–6 | Congela a todos los enemigos y les hace dos daños |
| | | 2–3 | Desvía en la dirección seleccionada el daño del enemigo seleccionado |
| | | 1 | MOV + ATK |
| **Gigante de hielo** | T P H | 6 | BLOCK |
| | | 1–5 | Mueve y ataca |
| **Gigante infernal** | T P F | 6 | BLOCK |
| | | 1–5 | Mueve y ataca |
| **Androide glacial** | H R T | 5–6 | Paga la cantidad de Éter que quieras para hacer ese daño a un enemigo |
| | | 1–4 | Paga la cantidad de Éter que quieras para congelar esos turnos a un enemigo |
| **Androide del huracán** | H R E | 4–6 | Duplica tu Éter |
| | | 1–3 | Paga X Éter para hacer X/5 daños a todos los enemigos |
| **Cazador del viento** | C V A | — | Nunca sale de sigilo (en lugar de entrar en sigilo, mueve y ataca) |

Pasivas:

- **Gigante de hielo**: siempre recibe 2 menos de daño. Siempre que recibe daño, congela al atacante.
- **Gigante infernal**: siempre recibe 2 menos de daño. Siempre que recibe daño, hace 2 de daño al atacante.
- **Cazador del viento**: siempre tiene oportunidad de esquivar daño si saca 6 en un DA (incluso cuando es daño de área). Siempre que esquiva, puede mover y atacar.

### Legendarios

#### Arcángel

- Cuenta como Bien y como cualquier otra clase.
- Es un 20/20.
- **1–6**: mueve y ataca.
- Si continúa vivo al final de un combate, aumenta en 2 tu salud.
- No se puede subir de nivel.

#### Señor demonio

- No se puede subir de nivel.
- **4–6**: ANIQUILA. Se lleva consigo al infierno la carta que ataca; si la carta está duplicada, solo se lleva una copia. Tanto el señor demonio como la carta atacada son descartados.
- **1–3**: MOV.

### Requisitos para usar campeones

| Tipo | Requisitos | Límite |
|------|------------|--------|
| Elemental | Tener en rango **(3)** una sinergia que lo conforme y ser de **nivel 2** | 1 elemental en nivel 2, 2 elementales en nivel 3 |
| Heroico | Tener una de sus categorías en rango **(5)** y ser de **nivel 3** | 1 heroico por grupo: si ya pusiste un heroico por el grupo de fuego, no puedes colocar otro por ese grupo |
| Legendario | Ser de **nivel 3** | |

### Muerte de un adalid y estertores

Cuando un adalid es asesinado por otro:

1. El asesino primero recibe el **estertor** del adalid muerto.
2. Luego puede comprar cualquiera de las cartas que el adalid muerto tenía en su reserva.
3. Las cartas que no son compradas se vuelven a mezclar con el mazo de juego.

El estertor depende de la clase elemental de la que el adalid asesinado tenía más campeones en su reserva (en caso de empate, el asesinado escoge el estertor):

| Clase | Estertor | Efecto sobre el asesino |
|-------|----------|-------------------------|
| Fuego | Venganza ígnea | Recibes 3 de daño |
| Eléctrico | Descarga | Elimina las multiplicaciones de todos tus campeones |
| Tierra | Desmoronar | Elimina una carta aleatoria de tu reserva (si tiene duplicado, este también se elimina) |
| Aire | Vientos en contra | No puedes comprar ninguna carta de la reserva enemiga |
| Hielo | Cristalizar | Por 3 turnos no recibes intereses |
| Malvado | Fantasma | El adalid asesinado puede seguir combatiendo, pero no tiene fases de preparación; las cartas aniquiladas le son entregadas |
| Ángel | Resurrección | El adalid gana 5 puntos de vida y resucita, pero pierde todas sus cartas de Ángel |
| Salvaje | Veneno | Siempre que pierdes un combate, pierdes 1 de vida adicional por turno |
| Robot | Hackeo | Pierdes la mitad de tu Éter |
| Mago | Encantamiento | Tu interés produce solo 2 de Éter por cada 10 |
| Protector | Deshonor | Vender a tus campeones ahora solo te da 1 de Éter |
| Asesino | Secuestro | El asesino selecciona una de tus cartas; no puedes usarla ni usar una copia mientras no pagues 30 de Éter como rescate |

### Glosario de dados

| Sigla | Dado |
|-------|------|
| DA | Dado de acción |
| DP | Dado de posición |
| DF | Dado de fuego |
| DR | Dado de aire |
| DS | Dado salvaje |
| DD | Dado de ángel |

Resultados posibles de un dado: **acierto**, **crítico** y **pifia**. Los **comodines** son dados que pueden sustituir a otro resultado, salvo donde las reglas lo excluyan.
