# Patch combinado de NEXUS HACK

Esta versión permite crear un patch con dos archivos y dos rutas de destino.

1. Ejecuta una vez `supabase/nexus_hack_complete_setup.sql` en el SQL Editor del mismo proyecto Supabase que usa la app. Es el script completo e incluye keys, contenido remoto, patch combinado y activación de licencias. Si ya usas los scripts separados, puedes ejecutar `supabase/remote_content_setup.sql` y después `supabase/secure_patch_keys_setup.sql`.
2. Publica el panel `admin` con el workflow actualizado.
3. En el panel, selecciona una categoría de tipo Patch, activa `Patch combinado (2 archivos / 2 rutas)`, elige los dos archivos y escribe sus rutas.
4. Pulsa `Guardar` y después `Publicar cambios`.
5. Genera una key para el patch combinado desde el selector de contenido. La key se comparte entre los dos archivos.

## Subida automática a GitHub

Abre `NEXUS-AUTO-SUBIR.cmd` una sola vez. El bot usará Git instalado en Windows, abrirá GitHub Desktop si lo encuentra, y revisará el proyecto cada 15 segundos. Cuando detecte archivos nuevos o cambios, hará commit y push automáticamente; ese push iniciará GitHub Actions.

La primera vez, Git debe tener acceso a tu cuenta de GitHub. Si aparece una ventana de autenticación, inicia sesión y luego deja el bot abierto.

La app descarga los dos objetos con SHA-256, los muestra como una sola tarjeta y crea un único proyecto de patch. `Aplicar` modifica ambos archivos en una transacción local; `Original` restaura ambos usando el mismo recibo.
