class_name Rules
extends RefCounted
## Constantes y enumeraciones del juego. Fuente: README.md (Reglas del juego).
## Los valores marcados con "SUPUESTO" no están en las reglas y se eligieron
## para poder jugar; ajustarlos aquí cambia todo el juego.

# --- Economía de Éter (README: "Economía de Éter") ---
const STARTING_ETER := 20
const WIN_REWARD := 7
const STREAK_BONUS := 2
const INTEREST := 3
const ROUND_INCOME := 10

# --- Adalid ---
const STARTING_VITALITY := 20 # SUPUESTO: las reglas no fijan la vitalidad inicial.
const TIE_VITALITY_LOSS := 2
const MAX_LEVEL := 3

# --- Preparación ---
const SHOP_SIZE := 4 # SUPUESTO: la tienda muestra 4 cartas (Demonio (5): 5).
const LEVEL_UP_COST := 10 # SUPUESTO: subir de nivel cuesta 10 de Éter.
const SELL_DIVISOR := 2 # SUPUESTO: vender devuelve la mitad del coste (mín. 1).
const RANSOM_COST := 30 # Secuestro: rescate de la carta.
const MAX_ELEMENTALS_BY_LEVEL := { 1: 0, 2: 1, 3: 2 }
## Copias de cada carta en el mazo del demiurgo (≈200 cartas en total).
const DECK_COPIES := {
	Tier.COMUN: 14,
	Tier.ELEMENTAL: 4,
	Tier.HEROE: 1,
	Tier.LEGENDARIO: 1,
}

# --- Combate ---
const MAX_ROUNDS := 4 # Un combate dura máximo 4 asaltos.
const BOARD_SIZE := 6 # SUPUESTO: 6 posiciones por mapa (6 hexágonos por color).
const BASE_ACTION_DICE := 3 # SUPUESTO: parejas DA+DP base por asalto.

# --- Dados (d6) ---
const DICE_SIDES := 6
const PIFIA := 1
const ACIERTO_MIN := 4 # SUPUESTO: 4-6 es acierto.
const CRITICO := 6 # El 6 es crítico (y también acierto).

# --- Sinergias ---
const SYNERGY_TIERS: Array[int] = [3, 5, 7]

# --- Fuerza de un campeón al contar supervivientes (README: "Fin del combate") ---
const STRENGTH_BY_TIER := {
	Tier.COMUN: 1,
	Tier.ELEMENTAL: 2,
	Tier.HEROE: 3,
	Tier.LEGENDARIO: 3, # SUPUESTO: se cuenta como heroico.
}

# --- Bonificación por duplicar cartas (README: "Duplicar cartas") ---
const DUPLICATE_BONUS := {
	Tier.COMUN: 1,
	Tier.ELEMENTAL: 3,
	Tier.HEROE: 5,
	Tier.LEGENDARIO: 0, # No se puede subir de nivel.
}

enum ClassType { FUEGO, ELECTRICO, TIERRA, AIRE, HIELO, SALVAJE, ROBOT, MAL, BIEN, PROTECTOR, ASESINO, MAGO }
enum Tier { COMUN, ELEMENTAL, HEROE, LEGENDARIO }
enum Reach { CUERPO_A_CUERPO, EMBOSCADOR, RANGO }
enum Keyword { ATK, MOV, CONG, PRO, SPEC, CUR, BLOCK, ESQ, ANIQUILA }
## Orden de resolución de un asalto (README: "Asaltos").
enum Phase { MOVIMIENTO, OFENSIVA, DEFENSIVA, ESPECIAL }

const CLASS_NAMES := {
	ClassType.FUEGO: "Fuego", ClassType.ELECTRICO: "Eléctrico", ClassType.TIERRA: "Tierra",
	ClassType.AIRE: "Aire", ClassType.HIELO: "Hielo", ClassType.SALVAJE: "Salvaje",
	ClassType.ROBOT: "Robot", ClassType.MAL: "Mal", ClassType.BIEN: "Bien",
	ClassType.PROTECTOR: "Protector", ClassType.ASESINO: "Asesino", ClassType.MAGO: "Mago",
}

const TIER_NAMES := {
	Tier.COMUN: "Común", Tier.ELEMENTAL: "Elemental", Tier.HEROE: "Héroe", Tier.LEGENDARIO: "Legendario",
}

const KEYWORD_NAMES := {
	Keyword.ATK: "ATK", Keyword.MOV: "MOV", Keyword.CONG: "CONG", Keyword.PRO: "PRO",
	Keyword.SPEC: "SPEC", Keyword.CUR: "CUR", Keyword.BLOCK: "BLOCK", Keyword.ESQ: "ESQ",
	Keyword.ANIQUILA: "ANIQUILA",
}

## Fase en la que se resuelve cada palabra clave.
const KEYWORD_PHASE := {
	Keyword.MOV: Phase.MOVIMIENTO,
	Keyword.ATK: Phase.OFENSIVA,
	Keyword.ANIQUILA: Phase.OFENSIVA,
	Keyword.BLOCK: Phase.DEFENSIVA,
	Keyword.ESQ: Phase.DEFENSIVA,
	Keyword.CONG: Phase.ESPECIAL,
	Keyword.PRO: Phase.ESPECIAL,
	Keyword.SPEC: Phase.ESPECIAL,
	Keyword.CUR: Phase.ESPECIAL,
}


static func class_label(c: int) -> String:
	return CLASS_NAMES.get(c, "?")


static func keyword_label(k: int) -> String:
	return KEYWORD_NAMES.get(k, "?")


static func tier_label(t: int) -> String:
	return TIER_NAMES.get(t, "?")
