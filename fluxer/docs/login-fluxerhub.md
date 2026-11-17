# Login con código desde FluxerHub (diseño)

Flujo tipo "TV": la app muestra un código, el cliente lo introduce en el
portal de FluxerHub (ya con su sesión iniciada) y la app queda conectada a su
servidor Emby sin escribir URL, usuario ni contraseña.

## Flujo

```
App FluxerMoon                      FluxerHub                         Emby
──────────────                      ─────────                         ────
POST /api/device-login/start  ───►  crea código K7Q2M9 (10 min)
   {device_id, device_name,          + poll_token secreto
    client, version}          ◄───  {code, poll_token, verify_url,
                                     interval: 5, expires_in: 600}
muestra código + QR(verify_url)

                                    cliente → portal /portal/tv
                                    mete K7Q2M9, elige cuenta Emby
                                    (si tiene varias) y confirma
                                    ── AuthenticateByName ───────────►
                                       usuario + encrypted_managed_password
                                       cabecera X-Emby-Authorization con el
                                       DeviceId/Device/Client/Version DE LA APP
                                    ◄── AccessToken + User ───────────

POST /api/device-login/poll   ───►  pendiente → 428
   {poll_token} cada 5 s            caducado  → 410
                              ◄───  aprobado  → 200 {server_url, user_id,
                                     user_name, access_token} (una sola vez;
                                     después se borra)
guarda servidor + usuario
y abre la sesión
```

## Lado app (todo en ficheros nuevos, `lib/fluxer/`)

- `fluxer_hub_login_service.dart`: start/poll contra FluxerHub (dio).
- `fluxer_hub_login_screen.dart`: código grande + QR + "esperando…".
- Al aprobarse, reutiliza la misma vía pública que Emby Connect
  (`lib/auth/repositories/emby_connect_repository.dart`, `connectToServer`):
  `ServerRepository.addServer(serverUrl)` → `AuthenticationStore.putUser(PrivateUser)`
  → `SessionRepository.switchCurrentSession(...)`. Sin tocar `auth_repository.dart`.
- Ganchos en ficheros oficiales (marcados `// FLUXER:`):
  1. `lib/ui/navigation/app_router.dart`: una ruta.
  2. `lib/ui/screens/auth/add_server_dialog.dart` (o la pantalla inicial):
     opción "Entrar con código Fluxer".
- La URL de FluxerHub va en `fluxer/branding.json`.

## Lado FluxerHub

- Tabla `device_login_requests`: code (6 caracteres sin ambiguos), poll_token
  (hash), device_id/name/client/version, media_customer_id, media_account_id,
  estado, access_token (cifrado, se borra al entregarlo), expires_at.
- Endpoints públicos `start` y `poll` con rate limit; la página del portal
  requiere sesión de cliente.
- Usa `media_accounts.encrypted_managed_password` + `EmbyClient`
  (`Infrastructure/Providers/Emby/`).
- Las cuentas importadas sin contraseña gestionada (`is_password_managed = false`)
  no pueden usar este login: el portal lo dice y ofrece restablecer la
  contraseña (que pasa a gestionada) o usar el login normal.
- Respeta suspensiones/baneos: sin suscripción activa no se aprueba.
- Auditoría: `device_login.approved` con IP y dispositivo.
- Ojo con `emby_devices`: Emby verá el DeviceId real de la app y el nombre de
  cliente "FluxerMoon for Windows/Android TV/…"; revisar la clasificación.

## Seguridad

- Código de un solo uso, caduca a los 10 min; el poll_token no se muestra.
- El token de Emby solo viaja una vez (en el poll aprobado) y por HTTPS.
- Limitar intentos de introducir códigos por cliente/IP.
