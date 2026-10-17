class_name Rules
extends RefCounted
## Constantes y enumeraciones de "Adalides del demiurgo" (v2).
## Fuente: adalides_doc/Adalides del demiurgo 2 columnas.pdf y los tableros.
## Lo marcado SUPUESTO no está en el PDF: lo fijó el autor en conversación
## (ver AGENTS.md) o se eligió para poder jugar.

# --- Adalid (tablero personal) ---
const STARTING_LIFE := 30
const STARTING_ETER := 30
const CYCLE_INCOME := 10
const INTEREST_PER := 10 # 3 de Éter por cada 10 ahorrados.
const INTEREST := 3
const MARKET_REFRESH_COST := 2 # "Roll 2"
const MARKET_SIZE := 4 # SUPUESTO
## Bono por racha (victorias o derrotas seguidas): fila 0/5/10/15/20/25/30.
## SUPUESTO: la casilla indica el Éter que da la racha.
const STREAK_TRACK: Array[int] = [0, 5, 10, 15, 20, 25, 30]
const UPGRADE_BASE_COST := 5 # Cada mejora: 5 + 5 por mejora previa en esa pista.

## Pistas del tablero personal. "H" = desbloquea un hueco de héroe.
const CUARTEL_TRACK: Array = [8, 11, 14, "H", 17, 20, "H"]
const BATTLE_TRACK: Array[int] = [3, 4, 5, 6, 7, 8, 9]
const DICE_TRACK: Array[int] = [1, 2, 3, 4, 5, 6]

# --- Draft (inicio de cada ciclo) ---
const DRAFT_CARDS_PER_PLAYER := 3 # Se muestran 3 × jugadores.
const DRAFT_PICKS := 2 # Cada uno toma 2, en orden de serpiente.

# --- Batalla ---
const ROUNDS_PER_BATTLE := 4
const ROUND_OPTIONS := [2, 3, 4, 0] # Asaltos por batalla configurables; 0 = hasta que un bando caiga.
const SUDDEN_DEATH_CAP := 20 # Tope de seguridad cuando la batalla es «hasta el final».
const BOARD_ROWS := 3 # Fila 1 = frente (SUPUESTO: las filas 1 se enfrentan).
const BOARD_COLS := 5
const SPELL_SLOTS := 2
const BASE_MOVE := 1 # SUPUESTO (autor): 1 paso por asalto.
const HERO_COST := 10

# --- Copias de una carta ---
const DUPLICATE_BONUS := 1 # 2.ª copia: +1/+1 y mejora de habilidad.
const AFI_BY_COPIES := { 1: 0, 2: 0, 3: 1, 4: 2 } # 3.ª copia AFI 1, 4.ª AFI 2.
const MAX_COPIES := 4

# --- Dados ---
## Dados de poder: la pista "Dados" del tablero personal es el TOTAL de dados de
## 3 caras (−, neutra, +) que se lanzan por asalto. Los dados se reparten entre
## los poderes: un + activa un poder de "+", dos + juntos hacen un "++", un −
## activa un poder de "-", dos − un "--", y una cara neutra activa poderes sin
## requisito. Decisión del autor: todo ocurre internamente, el jugador no asigna.
## Las comprobaciones sueltas de las habilidades ("lanza un dado; con ++/+/-")
## usan dos d3 sumados (SUPUESTO).
const DICE_SIDES := 6 # d6 auxiliar (columnas/filas).
enum Die { PIFIA, FALLO, NEUTRO, ACIERTO, CRITICO } # -- / - / ○ / + / ++
const DIE_LABELS := { Die.PIFIA: "--", Die.FALLO: "-", Die.NEUTRO: "○", Die.ACIERTO: "+", Die.CRITICO: "++" }

enum Element { FUEGO, TRUENO, TIERRA, AIRE, HIELO }
enum Archetype { ROBOT, SALVAJE, ANGEL, DEMONIO, MAGO, ARQUERO, DEFENSOR, ASESINO, PIRATA, MUERTO }

## Orden de un asalto (PDF: "El orden de asalto es").
enum Phase { HI, M, HR, A, H, HF }
const PHASE_LABELS := {
	Phase.HI: "Habilidad instantánea", Phase.M: "Movimiento", Phase.HR: "Habilidad rápida",
	Phase.A: "Ataque", Phase.H: "Habilidad normal", Phase.HF: "Habilidad de fin de asalto",
}

## Tiers: elementales 3/6/9, arquetipos 2/4/6 (contando campeones en batalla).
const ELEMENT_TIERS: Array[int] = [3, 6, 9]
const ARCHETYPE_TIERS: Array[int] = [2, 4, 6]

const ELEMENT_NAMES := {
	Element.FUEGO: "Fuego", Element.TRUENO: "Trueno", Element.TIERRA: "Tierra",
	Element.AIRE: "Aire", Element.HIELO: "Hielo",
}
const ARCHETYPE_NAMES := {
	Archetype.ROBOT: "Robot", Archetype.SALVAJE: "Salvaje", Archetype.ANGEL: "Ángel",
	Archetype.DEMONIO: "Demonio", Archetype.MAGO: "Mago", Archetype.ARQUERO: "Arquero",
	Archetype.DEFENSOR: "Defensor", Archetype.ASESINO: "Asesino", Archetype.PIRATA: "Pirata",
	Archetype.MUERTO: "Muerto",
}
## Alcance de ataque por arquetipo (autor): 1 salvo Arquero 3 y Mago 2.
const REACH := { Archetype.ARQUERO: 3, Archetype.MAGO: 2 }


static func element_label(e: int) -> String:
	return ELEMENT_NAMES.get(e, "?")


static func archetype_label(a: int) -> String:
	return ARCHETYPE_NAMES.get(a, "?")


static func reach_of(a: int) -> int:
	return REACH.get(a, 1)


static func die_label(d: int) -> String:
	return DIE_LABELS.get(d, "?")


## Nivel de tier alcanzado (0 si ninguno) para una lista de umbrales.
static func tier_index(count: int, thresholds: Array[int]) -> int:
	var reached := 0
	for i in thresholds.size():
		if count >= thresholds[i]:
			reached = i + 1
	return reached


## Coste de la siguiente mejora en una pista con `done` mejoras hechas.
static func upgrade_cost(done: int) -> int:
	return UPGRADE_BASE_COST * (done + 1)
