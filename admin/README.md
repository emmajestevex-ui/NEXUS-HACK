# NEXUS HACK Admin

Panel estatico para administrar contenido remoto propio de NEXUS HACK desde una PC.

## Uso

1. Ejecuta una sola vez `supabase/nexus_hack_complete_setup.sql` en el SQL Editor del proyecto Supabase. Ese archivo ya incluye tablas, funciones, storage, admins por correo y la correccion final de licencias. Los SQL separados quedan disponibles para reparaciones parciales.
2. Los correos `ysiemmanuel9@gmail.com`, `2008yashirchavez@gmail.com`, `emmajestevex@gmail.com` y `grego23500@gmail.com` ya quedan incluidos como admins en ese SQL.
3. Si el backend ya estaba instalado y solo falta permiso admin, ejecuta `supabase/admin_emails_setup.sql`.
4. Abre `admin/index.html` en el navegador o sube la carpeta `admin/` a un hosting privado.
5. Entra con tu correo y contrasena de Supabase. Si todavia no tienes acceso, escribe uno de los correos admin, pon una contrasena nueva y pulsa `Crear acceso`.
6. Sube o reemplaza archivos y pulsa `Publicar cambios`.
7. Para publicar un patch ya creado en la app, activa `Ya exportado como paquete .3105`, selecciona el archivo `.3105`, elige la categoría y publica. El paquete se conserva completo y el iPhone lo importa sin convertirlo.
8. En `Diseno remoto` edita el JSON para agregar categorias o subcategorias (`parent_id`), anuncios, iconos, colores `blue`, `gray` o `black`, y redes. Guarda el diseno y despues pulsa `Publicar cambios`; la app lo recibe al sincronizar sin una IPA nueva.
9. Al crear un patch puedes adjuntar una imagen pequena. El panel la guarda en Storage y la app la muestra junto al nombre.

En Windows tambien puedes abrir `admin/start-panel.cmd`; eso levanta el panel en `http://127.0.0.1:8787/` para evitar problemas del navegador con `file://`.

## Crear o reemplazar un patch

1. Toca una plantilla en `Patches listos`, por ejemplo `Asset Indexer`, `Shaders`, `144 fps` o `Aimbot Drag FF Max`.
2. El panel llena nombre, categoria, slug, `App destino` y `Ruta en NEXUS HACK`.
3. Selecciona el archivo nuevo desde tu PC.
4. Pulsa `Guardar cambio`.
5. Pulsa `Publicar cambios`.

Para editar uno ya publicado, pulsa `Reemplazar` en la tarjeta del patch o vuelve a tocar la misma plantilla. Algunos patches, como `Aimbot Drag FF Max`, tienen dos reglas dentro del mismo patch; toca la regla que quieres reemplazar, por ejemplo `Assembly-CSharp-patch.bytes` o `localConfig.json`. Si usas la misma combinacion de `App destino` y `Ruta en NEXUS HACK`, el iPhone descarga solo el archivo cambiado y reemplaza esa copia local despues de verificar el SHA-256.

Los paquetes `.3105` ya exportados no necesitan ruta interna de reemplazo: el panel les asigna una ruta técnica de almacenamiento y la app usa la información que ya está dentro del paquete.

Para quitar un patch integrado, pulsa `Quitar` en su plantilla y despues `Publicar cambios`. La app lo oculta despues de buscar actualizaciones. Para traerlo de vuelta, vuelve a tocar la plantilla, sube un archivo nuevo y publica.

La app iOS usa la misma publishable key y descarga solo los archivos publicados que cambien. No se incluye ninguna `service_role` ni secret key en este panel. Las keys nuevas usan el prefijo `NEXUS-`.
