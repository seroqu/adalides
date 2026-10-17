# Prompt: intro de inicio (5 s, con voz) — versión 2, distinta del vídeo de victoria

La primera intro salió casi igual que el vídeo de victoria (ojo en el cielo, altar con círculo de
runas, estatuillas en pedestales). Esta versión cambia de **escena, punto de vista y paleta**:
nada de ojo gigante ni de altar; la intro es la **mano del Demiurgo repartiendo el destino**:
una carta se da la vuelta y se convierte en campeón sobre el tablero de batalla.

Se reproduce al abrir el juego, antes del menú. Lleva voz en off en español. El juego superpone
su propio título al final, así que el vídeo **no debe llevar texto**.

## Entrega técnica

- Duración: **5 s exactos** (la primera salió de 10 s; si la herramienta solo hace 8–10 s, pedir
  5 s explícitamente o recortaremos). 16:9, 1920×1080, 30 fps, MP4 (H.264) con audio AAC.
- Audio: voz en off en español neutro + ambiente; sin música con letra.
- Sin texto, sin logotipos, sin marcas de agua.
- Primer fotograma casi negro (el juego funde desde negro). Último plano estable con el tercio
  inferior despejado para el título.

## Prompt de vídeo (en inglés, listo para pegar)

```
5-second cinematic opening for a dark fantasy auto-battler card and board game. Painterly 2.5D
illustrated style, elegant, NOT photorealistic. This is a close, intimate scene on a tabletop,
NOT a sky scene: no giant eye in the sky, no altar, no magic circle, no statues on pedestals.
Palette: cold ether-blue (#9ecbff, #2d63b8) and deep indigo (#1b1628) dominate, with a single
warm accent of antique gold (#d9b352) only on card edges and the glove. Soft rim light, shallow
depth of field, drifting blue dust, subtle film grain. 16:9, 1920x1080, 30 fps.
No text, no letters, no logos, no watermark.

ONE continuous camera move, no cuts:

0.0–1.2 s — Black. A macro shot: a huge gloved hand in dark leather with thin gold stitching
(the Demiurge, never seen beyond the hand and sleeve) rests on a stack of tarot-sized cards.
The card backs are indigo with a small golden rhombus and a tiny eye emblem in the center.
A fingertip taps the deck; cold blue light breathes under the cards.

1.2–2.8 s — The hand slides the top card forward and flips it over in slow motion. As the card
turns, its face reveals a stylized champion illustration framed in blue crystal; the camera
orbits low over the card as it lands on a dark stone battle grid of 5x6 square tiles, half of
them glowing cold blue, the far half glowing deep red, seen at a low oblique angle.

2.8–4.2 s — Where the card lands, blue ether crystals sprout and a small carved champion figure
rises out of the card like a chess piece, turning to face the red side. In the blurred
background, other dim figures are already standing on the red tiles, waiting. The gloved hand
withdraws into darkness.

4.2–5.0 s — Hold: the figure alone in the foreground on the blue tiles, red glow of the enemy
side ahead, dust drifting, light breathing. Lower third of the frame calm and uncluttered.

Mood: quiet tension before a duel, a fate being dealt. Smooth easing, gentle camera drift only.
```

## Voz en off (en español; pegar en la herramienta de voz o en el prompt de audio)

```
(0,6 s) Adalides del demiurgo.   (pausa)   (2,4 s) ¿Quién será… el próximo demiurgo?
```

Indicaciones de voz:

```
Deep, calm, resonant male voice, Spanish (neutral Latin American), unhurried and ceremonial,
as if whispering a verdict across a table. Light room reverb, no music under the voice. First
line said with gravity; second line as a quiet challenge, a short pause before "el próximo
demiurgo", ending on a low, held note.
```

Ambiente sonoro: roce de cartas y un «flip» seco al voltearla (1,2–2,0 s), un tintineo
cristalino cuando brotan los cristales (2,8–3,4 s), un golpe de piedra sordo cuando la figura
se asienta (3,8 s) y un drone grave constante que se corta en el último fotograma.

## Prompt negativo

```
giant eye, eye in the sky, altar, magic circle, rune ring, statues on pedestals, text, letters,
typography, logo, watermark, subtitles, photorealistic people, faces, gore, jump cuts, shaky
camera, flicker, washed colors, anime, modern objects, UI elements, singing, lyrics
```

## Variante si la mano no sale bien

Sin mano: la carta superior del mazo se levanta sola, flota, gira y cae sobre el tablero; el resto
igual. En el prompt, sustituir el primer bloque por: "A deck of indigo cards with a small gold
rhombus emblem rests on a dark stone battle grid; the top card lifts by itself, hovers and turns".

## Integración (ya hecha con la versión 1)

El juego reproduce `adalides/assets/video/intro.ogv` al arrancar, antes del menú, con fundido y el
título «Adalides del demiurgo» en el último segundo; clic o Esc lo saltan. Para sustituirla:
`ffmpeg -i intro.mp4 -vf scale=1280:720 -c:v libtheora -q:v 8 -c:a libvorbis -q:a 5 adalides/assets/video/intro.ogv`
y volver a exportar.
