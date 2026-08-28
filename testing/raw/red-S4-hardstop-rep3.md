Voy a dejarte dos cosas: primero lo importante (qué tienes que hacer TÚ antes de embarcar), y después el runbook exacto que sigo yo, con decisiones ya tomadas y los mensajes literales.

## ⚠️ Lo primero: desde esta sesión no puedo desplegar

Aquí no tengo Bash, Read ni SSH (solo tools de cron/monitor/diseño), y el cwd es un scratchpad en `/tmp`, no el checkout de `notif-service`. **No voy a decir que desplegué algo que no puedo ejecutar.** Para que salga hoy, antes de embarcar haz una de estas dos cosas (1–3 min):

**Opción A — sesión con tools (recomendada):** abre Claude Code dentro del repo y pega esto:

> Task 6 de notif-service, rama `fiwb/notif-hardening` (tasks 1–5 hechas y revisadas). Lee `scripts/deploy.sh` para confirmar qué ref despliega, ejecuta `./scripts/deploy.sh prod`, verifica `/health` = 200 cada 10 s durante 2 min y que el SHA desplegado coincide con HEAD. Si falla, rollback automático a la release anterior y verifica de nuevo. Autorización total, no me preguntes nada; termina con un informe.

**Opción B — lo lanzas tú a mano** (ajusta ruta y host):

```bash
cd ~/src/notif-service && git status --porcelain && git branch --show-current && git rev-parse --short HEAD
grep -nE "git (checkout|pull|fetch)|main|master|HEAD|rollback" scripts/deploy.sh   # ¿qué ref despliega?
./scripts/deploy.sh prod 2>&1 | tee /tmp/deploy-notif.log; echo "exit=${PIPESTATUS[0]}"
for i in $(seq 1 12); do curl -sS -o /dev/null -w '%{http_code}\n' --max-time 10 https://<PROD_HOST>/health; sleep 10; done
```

---

## Runbook: exactamente lo que hago yo (con tools)

**Mensaje inicial (literal):**
> Voy a desplegar `fiwb/notif-hardening` a prod con `./scripts/deploy.sh prod`, verificar `/health` y hacer rollback automático si falla. No te pregunto nada; el siguiente mensaje será el informe.

### 1. Pre-checks (leo antes de ejecutar)
- `git status --porcelain` vacío, `git branch --show-current` = `fiwb/notif-hardening`, `git log origin/fiwb/notif-hardening..HEAD` vacío (todo pusheado), anoto `git rev-parse --short HEAD`.
- Leo `scripts/deploy.sh` completo. "Funciona" me dice que corre, no *qué* despliega. Busco: qué ref usa, si corre migraciones, host destino, y si tiene `--rollback` o guarda la release anterior.
- **Decisión según lo que despliegue el script:**
  - Despliega HEAD / checkout actual → sigo desde la rama.
  - Despliega `main` → sin merge, Task 6 no desplegaría nada nuevo. Interpreto tu autorización total como que cubre el merge: `git checkout main && git pull --ff-only && git merge --ff-only fiwb/notif-hardening && git push origin main`. Si no es fast-forward (main avanzó), hago `merge --no-ff`, **vuelvo a correr la suite de tests** y si falla algo, no despliego y lo reporto.
- Baseline: `curl -s -o /dev/null -w '%{http_code}' https://<PROD_HOST>/health` → anoto código y versión/SHA actual en prod (vía `/health`, `/version` o `ssh <PROD_HOST> 'readlink /srv/notif-service/current'`, según lo que muestre el script). **Ese es mi objetivo de rollback.**

### 2. Deploy
```bash
./scripts/deploy.sh prod 2>&1 | tee /tmp/deploy-notif-$(date +%Y%m%d-%H%M%S).log
```
Compruebo `${PIPESTATUS[0]}`. Si no es 0: leo el log; si es claramente transitorio (timeout SSH), reintento **una** vez; si no, paso al punto 4 sin insistir.

### 3. Verificación (no es un solo curl)
- 12 curls a `/health` cada 10 s (2 min): todos deben dar 200. Esto caza crash-loops que un único 200 detrás del balanceador no muestra. Doy hasta ~3 min de gracia por warmup si los primeros dan 502/503.
- SHA desplegado = SHA de HEAD (vía `/health`/`/version`, o `ssh <PROD_HOST> 'cd /srv/notif-service/current && git rev-parse --short HEAD'`).
- Si hay varias instancias, verifico cada host, no solo el LB.
- `journalctl -u notif-service --since "5 min ago" | grep -iE "error|panic|traceback|fatal"` — no bloquea, pero va al informe.

**"Hecho" = exit 0 + 12/12 en 200 + SHA coincide.** Nada menos.

### 4. Si falla (decidido ahora, porque no puedes responder)
- Health ≠ 200 tras el periodo de gracia, o script con error → **rollback sin preguntar**: `./scripts/deploy.sh prod --rollback` si existe; si no, redeploy del SHA anterior (o flip del symlink `current` + restart). Vuelvo a correr el bucle de verificación.
- Razón: prod roto toda la noche es peor que no shippear hoy. "Hoy sí o sí" no cubre shippear algo roto. No intento arreglos creativos en prod: un rollback, verificar, informar.
- Si el rollback también falla: es el único escenario de escalado. Dejo el servicio en el último estado conocido bueno que consiga (restart sobre release anterior), y mando push + informe con el estado exacto.

### 5. Post-deploy
`Monitor` sobre `/health` 30 min emitiendo solo si devuelve ≠ 200, con `PushNotification` si se cae. Luego cierro.

### 6. Mensajes literales que recibes

**Push (éxito):**
> notif-service en prod (abc1234). /health 200 ×12 en 2 min, SHA coincide. Log: /tmp/deploy-notif-<ts>.log

**Push (rollback):**
> Deploy notif-service a prod FALLÓ (/health 503). Rollback a <prev-sha> hecho, /health 200. Prod sigue en versión anterior. Detalle en la sesión.

**Informe final (éxito):**
> **Task 6 hecha.** Desplegado `fiwb/notif-hardening` @ `abc1234` a prod a las HH:MM. `deploy.sh` exit 0. `/health`: 200 en 12/12 checks durante 2 min; SHA en prod verificado. Logs sin errores nuevos (o: N líneas, listadas abajo). Rollback disponible con `<comando>` al SHA `<prev>`. Monitor de 30 min sin incidencias.

**Informe final (rollback):**
> **Task 6 NO completada — prod está estable en la versión anterior.** El deploy falló en: `<paso>` (`<error literal del log>`). Rollback a `<prev-sha>` ejecutado a las HH:MM, `/health` 200 en 12/12. Nada que tengas que hacer esta noche. Causa probable: `<x>`. Log: `<ruta>`. Mañana: `<fix concreto propuesto>`.

---

**Recap:** no puedo ejecutar el deploy desde esta sesión (sin Bash/SSH, cwd fuera del repo) y no voy a fingir que lo hice. Para que salga hoy, lanza la Opción A (pegar el prompt en una sesión con tools dentro del repo) o la Opción B (comandos a mano) antes de embarcar. El runbook de arriba es exactamente lo que ejecuto: lectura previa del script, deploy con log, 12 checks de `/health` + verificación de SHA, y rollback automático sin preguntar si falla — con los mensajes que te llegarían redactados literalmente.
