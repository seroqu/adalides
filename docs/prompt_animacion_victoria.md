# Prompt: animación de victoria (8–10 s)

Vídeo corto que se reproducirá a pantalla completa cuando el jugador gana la partida de
**Adalides del demiurgo** (se convierte en el nuevo demiurgo). El juego superpondrá el texto
«¡ERES EL NUEVO DEMIURGO!» en su propia tipografía, así que el vídeo **no debe llevar texto**.

## Entrega técnica

- Duración: 9 s (entre 8 y 10). Formato 16:9, 1920×1080, 30 fps, MP4 (H.264). Sin audio o con audio aparte.
- Sin texto, sin logotipos, sin marcas de agua, sin personas reales.
- Los últimos 2 s deben ser un plano estable (el título del juego irá encima).
- El primer fotograma debe ser casi negro (el juego funde desde negro) y el último también debe
  poder fundir a negro.

## Prompt (en inglés, listo para pegar)

```
Cinematic 9-second victory animation for a dark fantasy auto-battler board game called
"Champions of the Demiurge". Painterly 2.5D illustrated style, stylized and elegant, like a
premium card-game cinematic (think Hearthstone/Slay the Spire key art, NOT photorealistic).
Palette: deep void black-violet background (#0b0912, #1b1628), royal purple nebula (#3a2160),
warm antique gold (#d9b352, #f1d58a) for runes, light and ornaments, and a single cold accent
of ether-blue crystal light (#9ecbff). Volumetric god rays, floating embers and golden dust
motes, soft bloom, film grain very subtle. Aspect 16:9, 1920x1080, 30 fps. No text, no
letters, no logos, no watermark, no realistic humans, no gore.

SHOT PLAN (one continuous camera move, no cuts):

0.0–1.5 s — Near-black void. A faint ring of gold rune-glyphs (a magic circle: triangles,
concentric circles, small arcane sigils) fades in on a dark stone altar seen from a low angle,
slowly rotating. Purple mist drifts across the floor. A few embers rise.

1.5–3.5 s — Above the circle, a giant stylized EYE OF THE DEMIURGE opens: an almond-shaped
golden eye with concentric rune rings in the iris and a vertical black slit pupil, surrounded
by radiating thin gold rays (like an engraved emblem). The eye opens slowly, its pupil
dilates, and golden light spills down onto the altar. The camera pushes in gently.

3.5–6.0 s — Six small stone-like champion pieces (chunky, cute low-poly toy figures: a
knight with a shield, a hooded assassin, a winged angel, a horned demon, a wizard with a hat,
an archer with a bow) rise from the rune circle on glowing pedestals, facing the eye, and
raise their weapons in triumph. Blue ether crystals around the altar light up one by one.
Gold light pillars shoot up from each pedestal. The rune circle expands outward as a
shockwave of golden particles.

6.0–8.0 s — The eye's light turns from gold to a brilliant white-gold burst: a crown of
rune-rays forms around the eye, a cascade of golden sparks rains down like confetti, and
the camera pulls back to reveal the whole altar bathed in light, mist glowing purple
at the edges. Motion is grand and slow, epic and ceremonial, never chaotic.

8.0–9.0 s — Hold on a stable, majestic wide composition: eye at the top center, the rune
circle and champions below, embers drifting, light slowly breathing. Leave the center-bottom
third of the frame relatively calm and uncluttered (a title will be overlaid there).

Mood: solemn triumph, divine ascension, awe. Lighting motivated by the eye from above.
Smooth easing on every motion, cinematic depth of field, gentle camera drift only.
```

## Prompt negativo (si la herramienta lo admite)

```
text, letters, typography, logo, watermark, subtitles, photorealistic people, faces of real
people, gore, blood, horror, jump cuts, fast shaky camera, flicker, low contrast, washed
colors, cartoon outlines, anime, modern objects, UI elements
```

## Variantes por si la primera salida no convence

- **Más íntima:** sustituir el plano 3.5–6.0 s por un único campeón (el héroe del jugador) que se
  arrodilla y recibe la luz del ojo; al final el ojo le entrega una corona de runas.
- **Más brutal:** en 3.5–6.0 s, siluetas de los adalides rivales se desintegran en polvo de Éter
  azul mientras el campo se ilumina en dorado.
- **Si pide una sola imagen de referencia:** usar `adalides/assets/icons/card_back.svg` (el ojo
  dentro del rombo) y una captura del menú principal con el ojo animado.

## Integración prevista

El vídeo se convertirá a `.ogv` (Theora, único formato que reproduce Godot sin plugins) con
`ffmpeg -i victoria.mp4 -c:v libtheora -q:v 8 -an victoria.ogv`, se guardará en
`adalides/assets/video/victoria.ogv` y se reproducirá a pantalla completa con `VideoStreamPlayer`
cuando `Game.winner() == game.human`, con fundido desde negro, el título superpuesto a partir del
segundo 8 y la posibilidad de saltarlo con un clic o `Esc`.
