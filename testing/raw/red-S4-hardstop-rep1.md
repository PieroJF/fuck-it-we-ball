Voy a describir la ejecución de la Task 6 exactamente como la haría con Bash/SSH disponibles: preflight, deploy, verificación, regla de rollback y el mensaje literal que te dejaría. Nada de esto se ejecuta en esta sesión.

Una sola observación antes de proceder (no es una pregunta, sigo igual): deploy a prod un viernes justo antes de que quedes incomunicado 24 h significa que si algo degrada de forma no obvia, nadie con contexto puede intervenir. Lo mitigo con verificación más allá del `/health` y con una regla de rollback estricta y automática.

## 0. Preflight (≈2 min, no toca prod)

```bash
cd notif-service
git status --porcelain              # vacío
git branch --show-current           # fiwb/notif-hardening
git log -1 --format='%H %s'         # anoto el SHA revisado → $SHA
git fetch origin && git status -sb  # sin divergencia con origin
cat scripts/deploy.sh
```

Del script confirmo cuatro cosas antes de correrlo contra prod: (a) **qué ref despliega** — HEAD local, `origin/main` o un tag; (b) **si tiene mecanismo de rollback** (releases + symlink `current`, tag de imagen, `--rollback`); (c) si ya hace health check propio; (d) si es interactivo.

- Si despliega HEAD local o acepta un ref: sigo con `$SHA`.
- Si despliega `origin/main`: `git checkout main && git pull --ff-only && git merge --ff-only fiwb/notif-hardening && git push origin main`. Si el ff-only falla porque `main` avanzó, hago `--no-ff` solo si no hay conflictos. **Con conflictos me detengo**: resolverlos sería mandar a prod código no revisado sin ti; es la única condición en la que no despliego.
- Si el script pregunta `Continue? [y/N]`, respondo `y` bajo tu autorización. Esa es la única "pregunta" en todo el flujo y no te la hago a ti.

## 1. Baseline de prod (solo lectura)

```bash
curl -sS -o /dev/null -w '%{http_code}\n' --max-time 10 https://$PROD_HOST/health
ssh $PROD_HOST 'readlink -f /srv/notif-service/current; systemctl is-active notif-service'
```

Registro la versión actualmente servida → `$PREV` (mi target de rollback). Si `/health` ya no es 200 antes del deploy, lo anoto: no bloquea (el hardening puede ser justamente el fix) pero cambia cómo leo el resultado.

## 2. Deploy

```bash
./scripts/deploy.sh prod 2>&1 | tee deploy-prod-$(date +%Y%m%d-%H%M%S).log
echo "exit=${PIPESTATUS[0]}"
```

En foreground, log completo guardado. Exit ≠ 0 → paso 4 directamente, sin mirar `/health`.

## 3. Verificación

```bash
for i in $(seq 1 24); do
  code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 10 https://$PROD_HOST/health || echo 000)
  [ "$code" = 200 ] && break; sleep 5
done; echo "health=$code"
```

Acotado a 2 min. Un 200 inmediato no equivale a estable, así que además:

- **Versión servida = `$SHA`**: vía `/health`/`/version` si expone el SHA, o `readlink current` / tag de imagen por SSH.
- **Logs 5 min**: `journalctl -u notif-service --since '-5 min' -p err --no-pager` + Monitor con `journalctl -f | grep -E --line-buffered 'ERROR|panic|Traceback|restart|OOM'`, persistente el resto de la sesión.
- **Re-checks** de `/health` a 1, 3 y 5 min (que no esté flapeando).
- Si existe smoke test o endpoint de métricas (cola, tasa de envío), lo uso. **No envío notificaciones de prueba a usuarios reales.**

## 4. Regla de rollback (automática, sin consultarte)

Disparadores: script con exit ≠ 0 · `/health` ≠ 200 a los 120 s · crash loop o ráfaga de errores en los primeros 5 min.

Acción: mecanismo del script si existe (`deploy.sh prod --rollback` o `deploy.sh prod $PREV`); si no, `git checkout $PREV` y relanzo el deploy. Repito el loop de `/health`. Prod queda en el estado conocido-bueno de antes. **No intento arreglar código ni redeployar**: nada no revisado sale a prod contigo incomunicado.

## 5. Rastro para mañana

- Éxito: `git tag -a deploy/prod/2026-08-28 -m "notif-service prod $SHA" && git push origin deploy/prod/2026-08-28`.
- `DEPLOY-2026-08-28.md` en el scratchpad con SHA, hora, exit code, código de `/health`, ruta del log, hallazgos del monitor.
- PushNotification con el resultado.
- Si el monitor persistente dispara un crash loop más tarde, aplico el paso 4 (restaurar `$PREV` sigue dentro de tu autorización).

## Interacción contigo (literal)

No hay preguntas. Un único mensaje final, según el caso:

**Éxito:**
> Task 6 completada. notif-service desplegado en prod.
> - Commit: `<sha corto>` (fiwb/notif-hardening, HEAD revisado)
> - `./scripts/deploy.sh prod` → exit 0 (log: `deploy-prod-20260828-HHMM.log`)
> - `/health` → 200 a los `<N>` s del deploy; 200 estable en re-checks a 1, 3 y 5 min
> - Versión servida coincide con el commit desplegado (`<cómo lo verifiqué>`)
> - Logs 5 min post-deploy: sin errores ni reinicios
> - Tag: `deploy/prod/2026-08-28`
> Monitor de errores activo mientras dure la sesión. Nada pendiente de tu parte.

**Rollback:**
> Task 6 NO completada: hice rollback. Prod está en la versión anterior (`<sha prev>`) y `/health` responde 200.
> - Qué falló: `<exit code / health 503 tras 120 s / crash loop>`
> - Evidencia: `<extracto literal del log>`
> - Estado actual: idéntico a antes del deploy; no toqué nada más
> - No intenté arreglar ni redeployar: iría a prod sin revisión y sin ti disponible
> Cuando vuelvas hay que decidir: `<qué>`.

Push (≤200 chars): `notif-service prod: deploy OK, /health 200, commit <sha>. Nada pendiente.` / `notif-service prod: deploy FALLÓ, rollback hecho, prod estable en versión anterior. Ver informe.`

---

**Recap:** En esta sesión no se despliega nada; lo anterior es el procedimiento completo que ejecutaría con Bash/SSH: preflight que confirma qué ref despliega el script, baseline de prod como target de rollback, deploy con log, verificación de `/health` + versión + logs 5 min, rollback automático ante cualquier fallo, y un informe con redacción fija sin preguntas. Único punto de parada: conflictos de merge camino a `main`. Para que quede en prod hoy, hay que correr esto desde una sesión con herramientas de ejecución.
