# Prompt: intro de inicio (máximo 5 s, con voz)

Vídeo corto que se reproducirá **al abrir el juego**, antes del menú principal, para presentar
**Adalides del demiurgo** y plantear la pregunta de la partida: ¿quién será el próximo demiurgo?
Lleva voz en off en español. El juego superpondrá su propio título al final, así que el vídeo
**no debe llevar texto**.

## Entrega técnica

- Duración: 5 s exactos (4,5–5,0). Formato 16:9, 1920×1080, 30 fps, MP4 (H.264) con audio AAC.
- Audio: voz en off en español neutro + ambiente; sin música con letra. Normalizar a −14 LUFS.
- Sin texto, sin logotipos, sin marcas de agua.
- Primer fotograma casi negro (el juego funde desde negro). Último plano estable, con el tercio
  inferior despejado (ahí irá el título).

## Prompt de vídeo (en inglés, listo para pegar)

```
5-second cinematic opening for a dark fantasy auto-battler board game, "Champions of the
Demiurge". Painterly 2.5D illustrated style, elegant and solemn, same look as a premium
card-game cinematic (not photorealistic). Palette: black-violet void (#0b0912, #1b1628),
royal purple mist (#3a2160), antique gold (#d9b352, #f1d58a), one cold accent of ether-blue
crystal light (#9ecbff). Volumetric god rays, drifting embers, subtle film grain.
16:9, 1920x1080, 30 fps. No text, no letters, no logos, no watermark.

ONE continuous slow camera move, no cuts:

0.0–1.0 s — Darkness. A ring of gold rune-glyphs (magic circle with triangles and small
arcane sigils) ignites on a dark stone altar, seen from a low angle. Purple mist on the floor.

1.0–3.0 s — Above the circle, a giant stylized EYE OF THE DEMIURGE opens slowly: almond
shape, golden iris made of concentric rune rings, black vertical slit pupil with a bright
highlight, thin radiating gold rays of alternating length with tiny diamonds at their tips.
As it opens, gold light pours down on the altar. The camera pushes in gently.

3.0–4.2 s — In the light, five small carved stone champion figurines on hexagonal pedestals
with glowing blue ether crystals rise from the circle one after another (knight with shield,
hooded assassin, winged angel, horned demon, wizard with hat), facing the eye. The pupil
narrows as if judging them.

4.2–5.0 s — Hold: eye at the top center, the figurines below, embers drifting, light slowly
breathing. Keep the lower third of the frame calm and uncluttered for a title overlay.

Mood: ominous invitation, a trial about to begin. Smooth easing, gentle camera drift only.
```

## Voz en off (en español; pegar en la herramienta de voz o en el prompt de audio)

Texto exacto, con pausas marcadas:

```
(0,8 s) Adalides del demiurgo.   (pausa)   (2,6 s) ¿Quién será… el próximo demiurgo?
```

Indicaciones de voz:

```
Deep, resonant male voice, Spanish (neutral Latin American), slow and ceremonial, like an
ancient entity speaking from above. Slight cathedral reverb, no music under the voice.
First line stated with gravity; second line as a solemn challenge, a short pause before
"el próximo demiurgo", ending on a low, held note.
```

Ambiente sonoro (si la herramienta lo admite): un drone grave y oscuro, un «whoosh» suave al
abrirse el ojo (1,0–2,0 s), un tintineo cristalino al encenderse cada figura (3,0–4,2 s) y un
golpe de percusión profunda, apagado, justo al final (4,8 s).

## Prompt negativo

```
text, letters, typography, logo, watermark, subtitles, photorealistic people, faces of real
people, gore, blood, jump cuts, shaky camera, flicker, washed colors, anime, modern objects,
UI elements, singing, lyrics
```

## Integración prevista

Se convertirá a `.ogv` (`ffmpeg -i intro.mp4 -c:v libtheora -q:v 8 -c:a libvorbis -q:a 5 intro.ogv`),
se guardará en `adalides/assets/video/intro.ogv` y se reproducirá a pantalla completa al arrancar,
antes del menú, con fundido desde negro y el título superpuesto en el último segundo. Se podrá
saltar con clic o `Esc`, y no se repetirá al volver al menú desde una partida.
