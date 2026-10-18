# NEXUS HACK

Private NEXUS HACK client with Supabase key activation and automatic remote patches.

## What this build does

- Shows the app as `NEXUS HACK`.
- Requires a Supabase license key before opening the app.
- Consumes each key one time on the server and binds it to one iOS device ID.
- Re-checks the license on launch, foreground, and every 10 seconds while active.
- Syncs published remote files from Supabase Storage into GREEG APP's own app storage, using a versioned `target_path` so replacing the same route downloads only the changed file.
- Downloads only changed files, verifies SHA-256, and rolls back local content if an update fails.
- Adds a PC admin panel in `admin/` for uploading, replacing, disabling, deleting, and publishing content changes.
- Creates the internal `Asset Indexer`, `Shaders`, and `144 fps` patches automatically after activation.
- Shows the extra `TIO GREEG` patch only for the special key `TIO-GREEG927394HD`.
- Lets the client use `Apply`, `Original`, and name editing only.
- Hides Files, Cleaner, Wallpapers, patch creation, import, export, and editing.

## Included private payloads

The bundled payload files live in:

```text
ThreeOneOSFive/BundledPatchPayloads/
```

Included names:

```text
assetindexer.H5ak1JM1Eck~2FxRcJrEp~2FMzeuqmY~3D
shaders.HPt9DZviTSXL9hpGW9QNOMigNLA~3D
com.dts.freefireth.plist
assetindexer.tio-greeg927394hd
```

Patch targets:

```text
Asset Indexer:
Documents/contentcache/Compulsory/ios/gameassetbundles/avatar/assetindexer.H5ak1JM1Eck~2FxRcJrEp~2FMzeuqmY~3D

Shaders:
Documents/contentcache/Optional/ios/gameassetbundles/shaders.HPt9DZviTSXL9hpGW9QNOMigNLA~3D

144 fps:
Library/Preferences/com.dts.freefireth.plist

TIO GREEG, only for `TIO-GREEG927394HD`:
Documents/contentcache/Compulsory/ios/gameassetbundles/avatar/assetindexer.H5ak1JM1Eck~2FxRcJrEp~2FMzeuqmY~3D
```

For a fresh install, you can paste `supabase/nexus_hack_complete_setup.sql` once into the Supabase SQL Editor and click Run. It combines `licenses_setup.sql`, `remote_content_setup.sql`, `admin_emails_setup.sql`, `allow_duplicate_remote_patches.sql`, and the final `activate_license.sql` refresh. The individual files remain available for partial repairs. The new license prefix is `NEXUS-` and the special key is `NEXUS-HACK-927394HD`.

The combined SQL enables remote content releases, `target_path` routing, the `nexus-hack-content` Storage bucket, and a remote visual manifest for categories, nested categories, announcements, social links, icons, and patch thumbnails. Edit the visual JSON in the panel under `Diseno remoto`, then publish; the next sync updates the app without a new IPA. The iOS client and the PC panel both use the same Supabase project URL and publishable key; admin writes require Supabase Auth plus a row in `public.license_admins`.

The app and admin panel use the Supabase project `oxtyyazqagmfhkgprpsp` and the public publishable key stored in their client configuration. The admin panel runs locally with `admin/start-panel.cmd`; it is intended to be opened at `http://localhost:8787`.

See `GREEG_BUILD_GUIDE.md` for Supabase setup and GitHub Actions build steps. The GitHub Actions workflow produces `NEXUS_HACK_unsigned.ipa`; sign that IPA with your own certificate/profile in ESign.
