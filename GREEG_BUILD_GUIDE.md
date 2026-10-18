# greeg app - Guia breve

Este paquete es la version cliente de greeg app. La app crea automaticamente los patches internos despues de activar una key, sin pedirle al cliente que importe ni guarde un archivo `.3105`.

## 1. Archivos privados de los patches

Los archivos privados ya van colocados aqui:

```text
ThreeOneOSFive/BundledPatchPayloads/
```

Nombres incluidos:

```text
assetindexer.H5ak1JM1Eck~2FxRcJrEp~2FMzeuqmY~3D
shaders.HPt9DZviTSXL9hpGW9QNOMigNLA~3D
com.dts.freefireth.plist
assetindexer.tio-greeg927394hd
```

La app creara automaticamente tres patches internos para cualquier key valida.

Patch `Asset Indexer`:

```text
com.dts.freefireth
Documents/contentcache/Compulsory/ios/gameassetbundles/avatar/assetindexer.H5ak1JM1Eck~2FxRcJrEp~2FMzeuqmY~3D
```

Patch `Shaders`:

```text
com.dts.freefireth
Documents/contentcache/Optional/ios/gameassetbundles/shaders.HPt9DZviTSXL9hpGW9QNOMigNLA~3D
```

Patch `144 fps`:

```text
com.dts.freefireth
Library/Preferences/com.dts.freefireth.plist
```

Patch especial `TIO GREEG`, solo si la key tiene el permiso `special_assetindexer`:

```text
com.dts.freefireth
Documents/contentcache/Compulsory/ios/gameassetbundles/avatar/assetindexer.H5ak1JM1Eck~2FxRcJrEp~2FMzeuqmY~3D
```

Los patches internos se guardan en Application Support, no en Documents. La UI no muestra importar, exportar ni cambiar reglas; solo deja editar el nombre del patch.

## 2. Supabase

La app ya esta configurada con:

```text
Project URL: https://oqpgabogasnxjejgakrt.supabase.co
Publishable key: sb_publishable_yL2R4NnUAO5SBP04edbPrg_zWpPFA31
Funciones cliente:
- public.activate_license(p_license_key text, p_device_id text)
- public.check_license(p_license_key text, p_device_id text)
```

Ejecuta este SQL en Supabase para activar la seguridad nueva:

```text
supabase/licenses_setup.sql
```

Ejecuta tambien este SQL para activar el contenido remoto administrado desde PC:

```text
supabase/remote_content_setup.sql
```

El SQL nuevo funciona asi:

- Si la key no existe, responde `Invalid key`.
- Si la key es numerica vieja tipo `GREEG-1`, responde `Old numeric keys are disabled`.
- Si la key esta pausada, bloqueada o expirada, la app vuelve al login.
- Si la key ya se activo en otro iOS, responde `This key is already used on another device`.
- Si es la primera vez, guarda `device_id`, `activated_at`, `used_at`, cambia la key a `active` y responde `Key activated successfully`.

La app verifica Supabase al abrir, al volver al frente y cada 10 segundos mientras esta activa. Si un fundador pausa, bloquea o expira una key desde el panel admin, el cliente pierde acceso y vuelve al login.

Para crear el primer fundador:

```sql
insert into public.license_admins (user_id, role)
select id, 'founder'
from auth.users
where email = 'TU_EMAIL_AQUI';
```

No pongas ninguna `secret key` ni `service_role` dentro de la app.

## 3. Panel de PC para archivos / contenido

El panel nuevo vive en:

```text
admin/index.html
```

Desde ahi puedes entrar con Supabase Auth, elegir una plantilla como `Asset Indexer`, `Shaders` o `144 fps`, subir archivos nuevos, elegir la `Ruta en GREEG APP`, reemplazarlos, activar/desactivar, marcar eliminacion y pulsar `Publicar cambios`. Si guardas otro archivo con la misma ruta, el panel lo trata como reemplazo versionado. La app iOS revisa el manifest publicado al abrir y tambien desde el boton `Check updates` en `Remote Files`.

La sincronizacion descarga solo archivos cambiados, verifica SHA-256 antes de instalar y guarda respaldo local para restaurar si algo falla. Los archivos se guardan dentro del almacenamiento propio de GREEG APP.

## 4. Subir a GitHub

1. Crea un repositorio nuevo, por ejemplo `GREEG-APP`.
2. No agregues README automatico.
3. Descomprime este ZIP.
4. Sube todo el contenido de esta carpeta.
5. Asegurate de que suba tambien la carpeta `.github`.

La estructura debe quedar asi:

```text
GREEG-APP/
├── .github/workflows/build-ios.yml
├── ThreeOneOSFive/
├── ThreeOneOSFive.xcodeproj/
├── supabase/
├── README.md
└── GREEG_BUILD_GUIDE.md
```

## 5. Compilar la IPA unsigned

1. Entra al repositorio en GitHub.
2. Abre `Actions`.
3. Entra en `Build GREEG APP (unsigned)`.
4. Pulsa `Run workflow`.
5. Espera a que termine en verde.
6. Abre la ejecucion terminada.
7. Descarga el artifact `GREEG-APP-unsigned`.

Dentro estara:

```text
GREEG-APP-unsigned.ipa
```

El mismo run tambien sube el artifact:

```text
GREEG-admin-panel
```

Ese ZIP contiene el panel de PC y el SQL de contenido remoto.

La IPA queda sin firmar para que despues uses tu metodo de firma autorizado.

## 6. Cambios hechos

- Nombre visible cambiado a `greeg app`.
- Pantalla de key en ingles.
- Cleaner, Wallpapers y Files ocultos de la navegacion.
- Patches `Asset Indexer`, `Shaders` y `144 fps` generados automaticamente desde payloads embebidos.
- Patch especial `TIO GREEG` generado solo para la key `TIO-GREEG927394HD`.
- Botones cliente: `Apply`, `Original` y `Edit Name`.
- Importar, exportar, crear y editar reglas removidos de la UI.
- `UIFileSharingEnabled` desactivado.
- Supabase configurado para key de un solo uso, bloqueo remoto, pausa remota, expiracion y keys seguras generadas desde el panel admin.
- Supabase configurado para releases de contenido remoto, manifest versionado, Storage con RLS y panel admin con Auth.
- La app tiene un apartado `Remote Files` con progreso, estado y boton para buscar actualizaciones.

Nota honesta: cualquier archivo dentro de una IPA puede ser extraido por alguien con conocimientos tecnicos. Este cambio evita que el cliente reciba el paquete en Files o lo exporte desde la app; no convierte la IPA en una caja imposible de inspeccionar.
