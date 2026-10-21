# NEXUS — keys por patch

La app conserva el cifrado local de los paquetes `.3105` y ahora agrega una
segunda barrera para el contenido remoto:

- Cada archivo remoto puede marcarse como protegido y tiene precio de referencia
  de `$15.00 USD`.
- El panel crea una key limitada al patch elegido mediante la capacidad
  `content:<id-del-archivo>`.
- El iPhone no descarga ni aplica el payload protegido hasta validar la key en
  Supabase y vincularla al dispositivo.
- Las keys no se incrustan en la IPA. La validación ocurre en el RPC del
  servidor y el archivo descargado se vuelve a comprobar por SHA-256.

## Activación

Ejecuta en Supabase, en este orden:

1. `supabase/licenses_setup.sql` (si la instalación todavía no tiene licencias).
2. `supabase/remote_content_setup.sql`.
3. `supabase/secure_patch_keys_setup.sql`.

Después actualiza el panel, edita o crea un archivo, deja marcada la opción
“Proteger este archivo con key individual” y publica. En la sección Keys elige
ese patch, crea la key y entrega la key al cliente.

La protección no puede ser absoluta contra un dispositivo con jailbreak,
debugger o acceso al servidor; ningún secreto puesto dentro de una IPA es
irrompible. Esta implementación evita que una copia normal de la IPA o del
cache obtenga el contenido sin una key válida y permite revocar el acceso desde
Supabase.
