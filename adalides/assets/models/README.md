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
