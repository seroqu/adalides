# Modelos 3D de los campeones

Coloca aquí los GLB generados (por ejemplo con Higgsfield → Meshy 7 / Meshy 6 con rigging y animación).
El juego los carga automáticamente si existen; si falta alguno, la ficha usa el icono del arquetipo.

Nombre de archivo esperado (uno por arquetipo; el color del elemento lo pone el juego):

    robot.glb  salvaje.glb  angel.glb  demonio.glb  mago.glb
    arquero.glb  defensor.glb  asesino.glb  pirata.glb  muerto.glb

Opcionalmente, un modelo por carta concreta tiene prioridad: `<arquetipo>_<elemento>.glb`
(p. ej. `mago_fuego.glb`) y para héroes `<id>.glb` (p. ej. `robot_caballero.glb`).

Animaciones: si el GLB trae un clip, se reproduce en bucle como "idle". Si trae varios,
se buscan por nombre: `idle`, `attack`, `hit`, `death` (sin distinguir mayúsculas).

## Modelos actuales

Los diez arquetipos están modelados con geometría procedural desde Blender (vía el puente de Higgsfield,
sin gastar créditos): `scripts` no los genera; se construyeron con `bpy` y se exportaron como GLB de ~50–70 KB.
`mago.glb` es el generado con Tripo (Higgsfield); `mago_lowpoly_alt.glb` es la versión procedural a juego con
los demás: renómbrala a `mago.glb` si prefieres uniformidad.
