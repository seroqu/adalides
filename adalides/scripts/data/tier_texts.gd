class_name TierTexts
extends RefCounted
## Resumen de las habilidades por elemento (tiers 3/6/9) y arquetipo (2/4/6),
## para la pantalla de consulta. Fuente: README, secciones de habilidades.

const E := Rules.Element
const A := Rules.Archetype

const ELEMENTS := {
	E.FUEGO: "Quemadura: los Fuego hacen (mitad / mitad / total) de su ataque básico a los otros campeones a (1/2/3) casillas del objetivo. Piel ígnea: los Fuego no sufren quemaduras.",
	E.TRUENO: "(HF) Tormenta: lanza (1/2/4) dados y haz (1/2/4) de daño a los enemigos de esa columna. Trueno: un 6 mata al enemigo con más vida máxima.",
	E.TIERRA: "Piel pétrea: los ataques a un Tierra hacen (1/2/4) menos. Roca afilada: quien ataque cuerpo a cuerpo a un Tierra recibe (0/1/2).",
	E.AIRE: "Céfiro: al recibir daño directo, lanza un dado; con (++ / + / -) lo esquiva. (HI) Tifón: (1/2/4) d20; los enemigos ahí son arrastrados (1/2/3) atrás; si chocan, (1/2/3) de daño verdadero a ambos.",
	E.HIELO: "Venas heladas: al dañar con ataque básico lanza un dado; con (++ / + / -) congela. Quebrar: un enemigo congelado atacado por un Hielo muere.",
}

const ARCHETYPES := {
	A.ANGEL: "(HF) Luz renovadora: cura (1/2/4) a los aliados heridos. (HF) Resurrección: (4/2/1) dados; si todos aciertan vuelven los muertos del asalto. Pacto de fe: (1/2/3) dados de fe; al final cura al adalid por cada +.",
	A.DEMONIO: "Maldición: quien mata a un demonio queda maldito y cada asalto con (++ / + / -) muere. (HI) Herejía: (1/2/3) d20; los enemigos ahí pierden habilidades. Pacto demoníaco: (1/2/3) preguntas; cada mentira cuesta (1/2/3) de vida.",
	A.ARQUERO: "Disparo certero: +(1/2/4) de ataque. A los puntos vitales: al atacar, con (++ / ++ / +) duplica su daño básico.",
	A.MAGO: "(HI) Magia desatada: (1/2/4) d20; los aliados ahí usan su poder como si el dado fuera (- / + / ++). (HF) Amplificación arcana: hechizos +(0/1/2).",
	A.DEFENSOR: "Unidad defensiva: +(0/1/2) de vida por defensor alrededor de otro defensor. Bloqueo: recibe el daño de los aliados no defensores adyacentes.",
	A.PIRATA: "Tatuko: al matar, lanza un dado: -- pierde (2/1/0) vida, - recupera (0/1/2), + gana (1/2/3) Éter, ++ roba (1/2/4) cartas. (6) Venganza: al perder, un dado: sabotaje / saqueo de 10 Éter / roba una carta.",
	A.MUERTO: "(6) Ejército de la tumba: los muertos siguen atacando hasta que caen todos. (HF) Marchitar: los vivos enemigos pierden (1/2/2) de ataque cada turno.",
	A.ASESINO: "(0) Marcado para morir: saltan junto a la víctima más cercana a su casilla opuesta. (2) Sigilo al comenzar. Desde las sombras: al salir, +(1 / 2 / el doble) de daño. Capa negra: al matar, con (++ / + / -) vuelve al sigilo.",
	A.ROBOT: "Optimización: producen (1/2/5) más de Éter. Protocolo de protección: pierdes (1/2/4) menos de vida al perder. (6) Hackeo: los dados enemigos empeoran un rango.",
	A.SALVAJE: "Alas de ave: se mueven (1/2/4) pasos más. Frenesí canino: habilidades (1/2/3) veces. (6) Garras felinas: golpean también en diagonal.",
}
