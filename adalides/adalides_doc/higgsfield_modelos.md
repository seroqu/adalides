# Generar los modelos de los campeones con Higgsfield

El conector de Higgsfield en Claude Code solo puede **leer** (catálogo, créditos, historial); la generación se hace
en la web de Higgsfield. Flujo: 10 modelos, uno por arquetipo; el juego pone el color del elemento en la base.

## Modelo y parámetros (iguales para los 10)

Modelo: **Meshy 6 Text to 3D** (`meshy_v6_text_to_3d`).

| Parámetro | Valor | Por qué |
|---|---|---|
| mode | full | con texturas |
| model_type | lowpoly | estilo de miniatura y archivo ligero |
| target_polycount | 8000 | suficiente detalle para verse desde arriba |
| topology | triangle | |
| symmetry_mode | auto | |
| pose_mode | a-pose | obligatorio para que el rigging salga limpio |
| enable_rigging | true | esqueleto humanoide |
| rigging_height_meters | 1.7 | |
| enable_animation | true | |
| animation_action_id | 0 | clip *idle* en bucle (el juego lo reproduce en batalla) |
| enable_pbr | false | el juego no lo necesita |
| enable_prompt_expansion | false | para que respete el prompt tal cual |

Si el modelo pide *negative prompt*, usa el bloque de abajo. Si prefieres partir de una imagen, genera primero el
concept con un modelo de imagen usando el mismo texto y pásalo a **Meshy 7 Image to 3D** con estos mismos valores.

## Prompt base (pégalo entero y añade la línea del arquetipo al principio)

```
[ARQUETIPO], a single full-body fantasy character designed as a tabletop board game miniature.
Style: stylized low-poly, chunky readable shapes, slightly exaggerated proportions (large head, large hands,
oversized weapon), clean hard-surface silhouette, hand-painted flat-shaded textures with soft gradients,
no photorealism, no fine fur or hair strands, no thin dangling parts.
Pose: standing upright in a relaxed A-pose with arms slightly away from the body, feet shoulder-width apart,
flat on the ground, facing forward, symmetrical body, weapon held firmly against the hand (never floating).
Camera readability: must be recognizable from a top-down 45-degree view, with the archetype's key prop
(weapon, wings, hat, shield) clearly visible from above and from the front.
Color palette: mostly neutral and desaturated (dark leather, grey steel, bone, parchment, dark cloth) with ONE
bright accent on the key prop; no element colors (no fire, ice, lightning, wind or earth effects), the element
is added later by the game.
Base: no base, no pedestal, no ground plane, nothing under the feet.
Output: one character only, centered, complete body from head to feet, no background, no text, no logo, no particles,
no glow effects, closed watertight mesh suitable for rigging and animation.
```

**Negative prompt**:

```
multiple characters, crowd, background, scenery, ground plane, pedestal, base, text, letters, logo, watermark,
photorealistic, realistic skin, fur strands, hair strands, cloth simulation, thin ribbons, floating objects,
detached weapon, transparent parts, glass, smoke, fire, ice, lightning, magic effects, particles, glow,
blurry, low detail, deformed hands, extra limbs, missing limbs, cropped body, sitting, kneeling, lying down
```

## La primera línea de cada arquetipo

Sustituye `[ARQUETIPO]` por una de estas (archivo de destino entre paréntesis):

- **robot.glb** — `A boxy brass-and-iron clockwork automaton knight with riveted plates, round glass core in the chest, a single cyclops lens eye and a heavy wrench-hammer in the right hand`
- **salvaje.glb** — `A feral beast-man warrior with a broad chest, short blocky fur suggested by texture only, clawed hands, a short tusked snout, a fur loincloth and a bone club in the right hand`
- **angel.glb** — `A celestial winged warrior with two large stylized feathered wings folded slightly back, a floating thin ring halo attached above the head, a long sleeveless robe, light pauldrons and a straight sword held point-down`
- **demonio.glb** — `A horned demon warrior with two thick curved horns, small folded bat wings on the back, cloven hooves, a spiked tail and a jagged two-handed blade resting on the shoulder`
- **mago.glb** — `A hooded mage with a tall pointed wide-brim hat, a long layered robe, a thick belt with pouches and a tall wooden staff topped with a large faceted crystal held in the right hand`
- **arquero.glb** — `An archer ranger with a hooded cloak, leather armor, a quiver of arrows on the back and a large recurve longbow held in the left hand with the string visible`
- **defensor.glb** — `A heavily armored guardian in full plate with a massive tower shield covering the left side of the body and a short mace in the right hand, wide stance, visored helmet`
- **asesino.glb** — `A masked assassin in a tight dark outfit with a half-face mask, a short hooded cape, bandaged forearms and two curved daggers, one in each hand held low`
- **pirata.glb** — `A pirate captain with a tricorn hat, a long open coat, a wooden peg leg, a hook on the left hand and a cutlass raised in the right hand, bandolier across the chest`
- **muerto.glb** — `An undead skeletal soldier with a hollow-eyed skull, a tattered hooded cloak, a cracked breastplate and a rusted notched sword held in the right hand, slightly hunched`

## Después de generar

1. Descarga cada GLB y guárdalo con el nombre indicado en `adalides/assets/models/`.
2. `godot --headless --path adalides --import` y luego el export (ver AGENTS.md).
3. El juego escala cada modelo a la casilla, lo orienta hacia el rival, reproduce el clip *idle* en bucle y, si
   más adelante añades clips llamados `attack`, `hit` o `death` (con **3D Rigging** sobre la URL del modelo), los usa
   al atacar, al recibir daño y al caer.

Consejo: genera primero `mago.glb` y pruébalo en el tablero antes de gastar los otros créditos; si el estilo o la
escala no convencen, ajusta el prompt base y repite.
