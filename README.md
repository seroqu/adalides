# adalides
Spring and react latform to play with friends

# **Adalides**

Bienvenido a adalides , el juego de mesa en el que has sido escogido como aspirante para reemplazar al demiurgo, en esta guía podrás encontrar todas las reglas concernientes a este juego.


### Componentes

1. 6 tableros de jugador
2. 48 marcadores de desarrollo (7 por color)
3. 114 dados (19 por color)
4. 30 exágonos de movimiento oculto (6 por color)
5. 12 mapas de combate (2 por jugador (Cada uno de 2 caras))
6. 200 cartas de campeón


### Objetivo del juego:

El demiurgo, señor y creador de todo lo que ha existido y existirá, se quiere retirar y para reemplazarlo, nombró a 6 seres de
inconmensurable poder como sus posibles sucesores, a cada uno de ellos los dotó con el poder de crear seres y les dió un poco de Éter, materia elemental con que se crea todas las cosa, les ordenó crear un ejército digno de su magnificencia, pero esta es una
competencia a muerte, pues quien no tenga un ejercito digno del demiurgo se desintegrará poco a poco hasta quedar reducido al mismo Eter del que fue hecho 

Tu eres uno de esos adalides ¿serás capaz de gestionar tus recursos y tu ingenio para ganar el puesto de creador de todas las cosas?. 
Para lograrlo lo único que debes hacer es borrar a tus competidores de la existencia misma, cosa que lograrás cuando lleves sus puntos vitales a 0.

### Preparacion del juego:

* se comienza con 20 eter
* por ganar se dan 7
* en racha 2 por racha
* 3 interés
* 10 por ronda

### Clases

- rojo fuego
- amarillo electrico
- café tierra
- gris, aire
- azul oscuro, hielo
- verde, salvaje
- plata robot
- morado mal
- dorado bien
- escudo protector
- daga asesino
- Símbolo arcano mago

Duplicar cartas, por cada una, Comunes +1/+1 Elementales +3/+3 heroes +5/+5.

#### Aclaraciones antes de las palabras clave:

-Si una palabra clave está sucedida por otra entre paréntesis, este se refiere a su objetivo.

-Si hay dos palabras clave en una acción, la primera es condición necesaria para la segunda. y si ambas necesitan un hexágono de dirección se colocarán uno sobre otro,siendo el de arriba el que define la primera acción.

ATK: Ataca un campeón infringiendo el tottal de su daño, Si no existe nadie en ese espacio no se inflige daño alguno.

-Si el atacante es de alcance (Cuerpo a cuerpo), debe elegir la dirección del ataque,
-Si es de alcance (Emboscador) su objetivo o es el espacio contrario al que el ocupa (Es decir, el que tiene el mismo número)
-Si el atacante es de alcance (Rango) se debe colocar un dado DP que no se esté usado,para definir la posición antes de la revelación de acciones

MOV: Mueve a un campeón en la dirección adyacente seleccionada, si existe otro campeónes esa dirección, intercambian posiciones
-No se puede mover a una casilla del mapa enemigo
-No se puede intercambiar posición con un aliado congelado

CONG: Congela a un enemigo (Esto se denota volteando la carta)
-Para descongelarlo, el enemigo debe gastar un DP que indique esa posición,
-Mientras un campeón esté congelado, no puede hacer ninguna acción.
-La acción de congelar respeta las normas de alcance a menos que se especifique el objetivo de la misma.

PRO: Añade la cantidad seleccionada a tus reservas de Éter.
-si está precedida por una acción, ésta es condición necesaria para realizar la acción de producir.

SPEC: Debes buscar esta ficha en el cuadernillo del demiurgo para saber que habilidades oculta.

CUR: Cura a un Campeón el valor mencionado entre paréntesis, se debe colocar un dado de posición que no esté en uso para marcar el campeón que será curado.
-Si por ejemplo dice CUR(DEF) Ese campeón curará el valor total de sus puntos de defenza.
-Si un campeón que ha muerto por no tener puntos de defensa es curado durante el mismo asalto en que sus puntos de defensa fueron reducidos a menos de 1, este no morirá y quedará vivo con la diferencia total que corresponda, si esta suma es menor que uno, el
sigue muerto.
-Un capeón no puede ser curado por encima de su vida máxima.
-la acción de curar no respeta las normas de alcance.

BLOCK: El campeón que bloquea recibe daño en lugar de un aliado en la dirección adyacente selecionada.
-Si el campeón que bloquea muere, el exceso de daño se le inflige al campeón que debía recibirlo.
-El daño de Area no puede ser bloqueado.

ESQ: el campeón evita el daño que le fuere a ser inflingido por este asalto-El daño en area no puede ser esquivado.
ANIQUILA: El campeón mata definitivamente a un Capeón enemigo, es decir, el enemigo lo regresa a la baraja del demiurgo.
-Este efecto respeta las reglas de alcance 
-Esta acción no puede ser bloqueado ni esquivado.

### Combate

#### Preparación del combate.

Se seleccionan los oponentes ordenándolos numéricamente luego de lanzar 2D10, se enfrentarán entonces, los dos resultados mayores, y luego el tercero y cuarto mayores y así sucesivamente, si algún jugador queda sin pareja, no se enfrentará a nadie y mantendrá su
racha, pero no podrá ganar Éter por conseguir la victoria en el combate ni aumentar su racha.

Se ponen las cartas de campeón boca abajo formando el mapa correspondiente a cada adalid, El combate se divide en asaltos.

#### Asaltos:
Cada asalto los adalides lanzarán tanto sus DA como sus DP y formarán parejas de un DA y un DP en secreto bajo la cortina de asalto, luego estas acciones se revelan y se llevan a cabo en el siguiente orden y de forma simultánea.

- Acciones de movimiento (Todas de forma simultanea, si dos o más movimientos generan un conflicto no se hará ninguno).
- Acciones ofensivas: Todas aquellas que hagan daño a otros jugadores.
- Acciones Defensivas: Todas las que eviten algún tipo de daño.
- Acciones especiales: todas las que no clasifiquen en ninguna de las anteriores (Como congelar o meterse en sigilo).

Nota: la cantidad de parejas de dados que puede formar el adalid define la cantidad de acciones que ejecutará, este durante un asalto, aún así el adalid podría hacer acciones de combate que no implican parejas formadas por un DP y un DA estas son habilidades de sus sinergias y se pueden usar cuantas el adalid consiga según los requerimientos de dados de las mismas.

Luego se asignan los daños, Si un Campeón se quedó sin puntos de defensa es retirado de la batalla y su espacio queda libre.

Fin del combate:

El combate Puede terminar por 3 razones.

1. Que el enemigo se quede sin campeones disponibles
2. Que pasen 4 asaltos.3. Que un jugador se rinda, renunciando a hacer cualquier tipo de daño a los puntos de vitalidad del adalid enemigo 

En cualquiera de estos casos, suceden 2 cosas.
Se escoge el Adalid ganador, que será quien tenga más campeones en el campo de batalla, en caso de empate numérico no habrá ganador y ambos perderán su racha. y 2 puntos de vida.

El perdedor recibira daños a sus puntos de vitalidad correspondientes a la diferencia de cantidad de campeones enemigos que sigan en pie, +1 Los campeones elementales cuentan como 2 campeones y lo heroicos como 3.

#### ¿Qué obtiene el ganador?

El ganador obtiene siempre 7 de Éter y será parte del primer grupo en la siguiente fase de preparación.

¿Que pasa si un adalid se queda sin puntos de vitalidad?
 En ese caso el adalid es _**eliminado**_ del juego.


### Fuego

(3)
​ Pool 2 DF cuando un fuego hace daño, lanza DF (Dado de fuego) equivalentes a su ataque. Un crítico en un DF puede usarse para hacer un daño al adalid enemigo. (Este efecto anula el daño que produce en area) Un par de pifias en un DF (se acumulan con los turnos) Implican un daño obligatorio para el adalid que controla a los fuego

(5)
​ Pool 4 DF cada DF con un acierto, causa un daño a
los enemigos Al lado del objetivo, Estos
daños se computan como un solo impacto

(7) 
​ Pool 6 DF El Daño de area aplica a todos los enemigos adyacentes. Puedes usar un par de DA para asignar una DF en el campeón que prefieras antes de cada asalto el enemigo lanzará ese DF, si no es un acierto (Muere) aplicando daño de fuego como si se hubiera atacado a si mismo.

### Eléctrico

(​ P ​ ) 
Cada pifia se pierde una carga Aclaraciones 
​ las cargas electricas aplican mejoras a todas la habilidades.

(3)
​ Antes de lanzar los dados de asaltolanza 2 DA, por cada acierto por un contador de carga +1/+1 en el campeón que quieras.

(5) 
​ 3DA antes de los dados de asalto, Puedes gastar un DP correspondiente a un campeón eléctrico y un par de DA para descargarlo y hacerle un daño igual al número de cargas que tenga este a todos los enemigos. este efecto le quita todas las cargas al campeón seleccionado.

(7) 
​ 5DA antes de los dados de asalto Puedes gastar un trío de dados de acción para dejar una carga permanente en un campeón

### Tierra

(3)
​ ​ Cuando un tierra pierde recibe 1 menos de daño

(5)
​ ​ Todo el daño recibido se reduce en 1 puedes usar un DP para evitar todo el daño que un campeón correspondiente va a sufrir este turno

(7) 
​ 2 menos de daño al perder Todo el daño recibido se reduce en 3 puedes usar un trio de dados de acción para sepultar un enemigo aleatorio (Lanza un DP)

### Aire

(3) 
​ Cada vez que un aire recibe daño, Lanza un 2DR(Dado de aire) si hay 2 aciertos el aire esquiva el impacto

(5) 
​ Cada vez que un aire recibe daño,Lanza 1DR(Dado de aire) si hay al menos un acierto el aire esquiva el impacto. Al comenzar la batalla lanza un DP enemigo y exilia de la batalla al campeón en esa posición.

(7)
​ Cada vez que un aire recibe daño, Lanza 2 DA(Dado de aire) si hay al menos un acierto el aire esquiva el impacto. Al comenzar la batalla lanza un DP enemigo y exilia de la batalla al campeón en esa posición. Cada crítico en un DA se puede usar como un contraataque, aplicando el daño de aire al agresor.
-Aclaración, no se puede esquivar el daño de área.

### Hielo

(​ P ​ ) 
cada pifia quita un marcador de hielo de un enemigo

(3) 
​ Cada vez que un hielo recibe o hace daño, lanza 1 DA si se consigue al menos un acierto congela al agresor u objetivo.

(5) 
​ Lanza 2 DA. Cuando un hielo ataca un enemigo congelado con un ataque directo este muere.

(7)
​ lanza 3 DA Puedes usar un trío de DA para congelar todos los campeones del enemigo.

### Salvaje

(3)
​ Pool 3 DS Puedes asignar DS a tus campeones en cada asalto, máximo 1 por campeón Cuando un campeón recibe o hace daño
Puede lanzar un DS, si este es un acierto, Puede potenciar o atenuar ese daño con una bonificación de 1.

(5)
​ Pool 6 DS Máximo 2 Ds por campeón Bonificación de 2 pata aumentar o atenuar ataque 

### Robot

(3) 
​ Puedes volver a lanzar los dados de asalto una vez más. produces el doble de éter al usar la acción producir.

(5) 
​ el enemigo pierde la capacidad de volver a lanzar sus DA El enemigo juega con un dado de acción menos Produces el triple de éter al usar la acción "producir" (Preparación siguiente)Todas las mejoras de tu tablero personal cuestan 3 menos, si el combate anterior tenías 5 robots en el campo de batalla.

### Demonio
(3)
​ Puedes usar un DP para ANIQUILAR a un campeón demonio tuyo, y quitar 1 de vida a tu oponente y aumentar 1 de vida a ti.
(Recuerda que aniquilar implica que ese personaje se perderá para siempre) 

(5)
​ Al aniquilar recuperas el eter gastado en el campeón.Puedes usar un par de dados de acción para poner en tu reserva un campeón que
fuere, aniquilado este combate, pagando su costo de eter. Cuando un campeón demonio sale de un combate por cualquier razón lanza un DP y haz su daño al campeón enemigo en esa posición. (Preparación siguiente) tu tienda tiene siempre una carta más (5 en total) 

### Angel

(3) 
​ Pool 3DD Al comenzar la batalla gana 1 punto de vida Cuando un angel muere, lanza tantos DD Como ángeles tengas, cada Acierto
cuenta como un daño de venganza, que recibirá quien causó la muerte (Campeones como adalides) Este daño es directo y anula toda forma de defensa.

(5)
​ Pool 6 DD 2 puntos al comenzar la batalla. Los críticos en DD Se puede utilizar también para ganar 1 PV del adalid Si el enemigo castigado muere puedes revivir a uno de tus ángeles pagando 2 puntos de vida del adalid, (No puedes revivir al angel que acaba de morir)

### Protector

(3) 
​ Todos los DA usados en campeones protectores aumentan su valor en 1  (Máximo 6)
Cuando un campeón bloquea, hace su daño al enemigo que atacó al campeón protegido.
Los campeones protectores pueden bloquear en 2 direcciones

(5) 
​ Los campeones protectores aumentan en 5 puntos su vida.
Cuando un campeón bloquea, hace su daño al enemigo que atacó al campeón protegido.
Todos los DA usados en campeones protectores aumentan su valor en 2 Cuando un campeón protector bloquea no recibe el daño en lugar de su aliado.
Los campeones protectores pueden bloquear en 2 direcciones. Elige arbitrariamente el valor de uno de tus dados de posición
Puedes usar un par de dados de acción para cancelar una acción del adversario, (Por ejemplo un par de 3 cancela la
acción número 3) esta acción sucede antes que los movimientos.

### Assesino

(3)
​ Todos los asesinos comienzan en Sigilo.
Los asesinos hacen el doble de daño cuando salen de sigilo.
Puedes usar un DP para poner en sigilo a uno de tus asesinos los comodines no
aplican para este efecto Glacial(​ H ​ T ​ )/10

(5) 
​ Todos los asesinos comienzan en Sigilo y ganan 2 puntos de daño.
Los Comodines también pueden poner a un asesino en sigilo
Cuando un asesino Sale de sigilo, puedes lanzar un DA si aciertas vuelve a ponerlo
en sigilo, si pifias, saca de sigilo al asesino de tu preferencia

### Magos
(3) 
Tienes un dado de acción más
(5)
Tienes un dado de acción más Señores elementales Plasma(​ F E​ )

7

6 hace 5 de daño a un enemigo y 1 a todos los otros
3-5 mov átk
1-2 mov
lava(​ F T​ )
9
6 hace un daño igual al valor de la casilla  en la que está cada carta enemiga -2
4-5 mov + atk
1-3 block


Bloquea todos los turnos.

Cuando el glacial muere lanza 2 DP
enemigos, instantáneamente mata lo que se encuentre ahí.
Tormenta(​ H ​ E ​ )/9
6 LANZA 3 Dados de ubicación enemiga,
HACE DAÑO A todos los que se encuentren en esos espacios y los congela
3-5 ATK
1-2 MOV

Señores del aire/10
Todos tienen posibilidad de esquivar daño sacando 6 en un d6.
Su daño, es el cuadrado de la cantidad de señores elementales que existan en la mano del adalid 6, hacen su daño a todos los enemigos4-5 ataca y mueve 3 mueve un enemigo y ataca. 1 - 2 MOV

HEROES
M​ E ​ F ​ Demónio eléctrico 3/6 toma un aliado adyacente y lo hace explotar haciendo todo su daño al enemigo y la mitad a los aliados. 12/ mov +ataque

M​ T ​ F ​ Demonio de arena 3/6 tira 5 dados de ubicación enemiga, roba la mitad de esa vida y añádela al demonio de arena 1/2 bloquea.

E​ F ​ M ​ Mago de plasma 3/6 explota y hace daño a todos los no magos
ATL 1/2 duplica su daño 

E​ H ​ M ​ Mago de tormenra 4/6 congela a todos los enemigos y les hace dos daños 2/3 desvía en la dirección seleccionada, el
daño de el enemigo seleccionado. 1 Mov + Atk

T​ P ​ H ​ Gigante de hielo Siempre recibe 2 menos de daño Siempre que recibe daño, congela al atacante. 6 BLOCK 1/5 mueve y ataca

T​ P ​ F ​ Gigante Infernal Siempre recibe 2 menos de daño Siempre que recibe daño, hace 2 de daño al atacante. Restricciones
6 BLOCK 1/5 mueve y ataca

H​ R T​ Androide glacial 5/6 paga la cantidad de eter que quieras para hacer ese daño a un enemigo 1/4 paga la cantidad de eter que quieras para congelar esos turnos a un enemigo H​ R E

​ Androide del uracán. 4/6 duplica tu eter 1/3 paga x eter para hacer x/5 daños a todos los enemigos.

C​ V A Cazador del viento Nunca sale de sigilo (en lugar de entrar en sigilo mueve y ataca)

Siempre tiene oportunidad de esquivar daño si saca 6 en un DA (Incluso cuando es daño de area)
Siempre que esquiva puede mover y atacar.

Arcangel: cuenta como bien y como cualquier otro, es un 20/20 1/6 mueve y ataca 

Si continúa vivo al final de un combate, aumenta en 2 tu salud 
No se puede subir de nivel
Señor demonio, no se puede subir de nivel.
4-6 ANIQUILA, se lleva con el la carta que ataca al infierno, si la carta está duplicada solo se lleva una copia, tanto el señor
demonio como la carta atacada son descartados.

1-3 MOV.para usar un capeón elemental es necesario tener en rango de (3) una sinergia que lo conforme, y ser de nivel 2,
Solo puedes usar 1 campeón elemental siendo nivel 2 y puedes usar 2 siendo nivel 3.
Para usar un campeón heroico, es necesario tener una de sus categorías en rango (5) y ser
de nivel 3.

Solo Puedes usar 1 campeón heroico. por cada grupo, es decir,Si ya pusiste un campeón heróico por el grupo de fuego, no puedes colocar otro por ese grupo. para usar un campeón legendario es necesario ser nivel 3 

Cuando un adalid es asesinado por otro, primero recibe su estertor puede comprar cualquiera de las cartas que el tenía en su reserva, las cartas que no son compradas se vuelven a mezclar con el mazo de juego.

Estertores, Cuando un adalid es asesinado, revisa cual es la clase elemental de la que más campeones tiene en su reserva,(en caso de empate, escoge tú el estertor) según el caso haz una de estas cosas:

_Fuego_ (Venganza ignea) ​ Recibes 3 de daño

_Electrico_ (Descarga)​ ​ Elimina las multiplicaciones de todos tus campeones

_Tierra_ (Desmoronar) ​ Elimina una carta aleatoria de tu reserva (Si tiene duplicado este también se elimina)

_Aire_ (Vientos en contra) ​ No puedes comprar ninguna carta de la reserva enemiga.

_Hielo_ (cristalizar) ​ Por 3 turnos, no recibes interéses.

_Malvado_ (Fantasma) ​ El adalid asesinado puede seguir combatiendo, pero no tiene fases de preparación, las cartas aniquiladas le son entregadas.

_Angel_ (Resurrección) ​ El adalid gana 5 puntos de vida, resucita, pero pierde todas su cartas de Angel.

_Salvaje_ (veneno) ​ Siempre que pierdes un combate, pierdes uno de vida adicional por turno.

_Robot_(Hackeo)​ Pierdes la mitad de tu eter

_Mago_(encantamiento) Tu interés porduce solo 2 de eter por cada 10

_Protector_(Deshonor) vender a tus campeones ahora solo te dá uno de heter.

_Asesino_(Secuestro) ​ El asesino selecciona una de tus cartas, no puedes usarla, ni usar una copia mientras no pagues 30 de eter como rescate.
