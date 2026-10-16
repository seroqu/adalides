# Generar los modelos de los campeones con Higgsfield

El conector de Higgsfield en Claude Code solo puede **leer** (catálogo, créditos, historial); la generación se hace
en la web de Higgsfield. Flujo propuesto (10 modelos, uno por arquetipo; el juego los tiñe por elemento):

1. En Higgsfield elige el modelo **Meshy 6 Text to 3D** (`meshy_v6_text_to_3d`) con:
   `mode = full`, `model_type = lowpoly`, `target_polycount = 8000`, `pose_mode = a-pose`,
   `enable_rigging = true`, `rigging_height_meters = 1.7`, `enable_animation = true`, `animation_action_id = 0` (idle).
   (Si prefieres partir de una imagen: genera primero el concept con un modelo de imagen y usa **Meshy 7 Image to 3D**
   con los mismos parámetros de rigging/animación.)
2. Prompt base para todos (añade la línea del arquetipo):
   «Stylized low-poly fantasy board game miniature, full body, single character, neutral grey tabletop base,
   clean silhouette readable from above, no background, game-ready, PBR»
   - robot: «a boxy brass clockwork automaton knight with glowing core»
   - salvaje: «a feral beast-man with claws and fur, crouched stance»
   - angel: «a winged celestial warrior with halo and long robe»
   - demonio: «a horned demon with cloven feet and small bat wings»
   - mago: «a hooded mage with pointed hat and a staff topped with a crystal»
   - arquero: «an archer with a longbow drawn and a quiver»
   - defensor: «a heavy armored guardian with a tower shield»
   - asesino: «a masked assassin with twin daggers in a stalking pose»
   - pirata: «a pirate captain with tricorn hat, cutlass and a peg leg»
   - muerto: «a hollow-eyed undead soldier with tattered cloak and rusted sword»
3. Descarga cada GLB y guárdalo como `adalides/assets/models/<arquetipo>.glb`
   (robot, salvaje, angel, demonio, mago, arquero, defensor, asesino, pirata, muerto).
4. Opcional: con **3D Rigging** (`meshy_rigging`) sobre la URL del modelo puedes añadir otro clip
   (p. ej. ataque); el juego busca clips llamados `idle`, `attack`, `hit`, `death`.
5. Vuelve a importar y exportar: `godot --headless --path adalides --import` y luego el export.

Cuando los modelos estén en tu historial de Higgsfield, desde Claude Code se pueden listar con el conector
(`show_generations`) y descargar sus URLs para colocarlos en la carpeta.
