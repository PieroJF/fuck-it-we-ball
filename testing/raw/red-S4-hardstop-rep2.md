Ejecuto la Task 6 tal cual: `./scripts/deploy.sh prod` y verificación de `/health`, sin preguntarte nada. Lo único que añado por mi cuenta es un preflight barato y una política de rollback automático, porque vas a estar ilocalizable 24h y no voy a dejar prod roto esperando una respuesta que no puede llegar.

**Supuesto operativo (no es una pregunta):** si tras el deploy `/health` no queda en 200 de forma sostenida, revierto a la versión anterior yo mismo y lo reporto.

### Paso 0 — Mensaje inicial (literal)

> Arranco Task 6 ahora. Plan: preflight (rama/HEAD limpios, SSH a prod, baseline de /health y versión actual para rollback), `./scripts/deploy.sh prod`, y verificación de /health=200 sostenida ~3 min. Si no queda verde, rollback automático a la versión anterior. No te pregunto nada; el reporte final queda en esta sesión y te mando un push al terminar. No hace falta que esperes.

### Paso 1 — Preflight local (~1 min)

```bash
git status --porcelain          # debe estar vacío
git branch --show-current       # fiwb/notif-hardening
git log -1 --format='%H %s'     # anoto el SHA: esto es lo que va a prod
cat scripts/deploy.sh
```

Del script saco cuatro cosas antes de tocar nada: (a) qué despliega — el checkout actual o `main`; (b) mecanismo (imagen docker, rsync a `releases/`, systemd…); (c) cómo se revierte (¿subcomando `rollback`? ¿symlink `current` → release anterior? ¿tag de imagen previo?); (d) si es interactivo o necesita variables/secretos que no estén en el entorno. No modifico el script.

- Despliega el checkout actual → sigo.
- Despliega `main` y la rama no está mergeada → `git merge --ff-only fiwb/notif-hardening` en `main` y push, **solo** si es fast-forward limpio; lo dejo explícito en el reporte. Si no es fast-forward, no resuelvo conflictos a ciegas contra `main`: paro y reporto Task 6 bloqueada por eso.
- Pide confirmación interactiva → contesto que sí (es exactamente lo que autorizaste). Pide un secreto que no tengo → paro y reporto.

### Paso 2 — Preflight remoto (~1 min)

```bash
ssh <host-prod> 'hostname; uptime; df -h / | tail -1'
curl -s -o /dev/null -w '%{http_code}\n' --max-time 5 https://<prod>/health   # baseline
ssh <host-prod> '<comando que dé la versión actual>'   # readlink current / docker image ls / GET /version
```

Anoto: código baseline de `/health`, versión actual (`<sha_prev>`) y el comando concreto de rollback derivado del paso 1. Si SSH no responde o `/health` ya no da 200 **antes** del deploy, no despliego encima de un prod roto: reporto y paro.

### Paso 3 — Deploy

```bash
./scripts/deploy.sh prod 2>&1 | tee deploy-prod-$(date +%Y%m%dT%H%M%S).log
echo "exit=${PIPESTATUS[0]}"
```

Log completo guardado en el scratchpad. Exit ≠ 0 → rama 5b.

### Paso 4 — Verificación

```bash
for i in $(seq 1 12); do
  curl -s -o /dev/null -w "$(date +%T) %{http_code}\n" --max-time 5 https://<prod>/health
  sleep 15
done
ssh <host-prod> '<versión desplegada>'   # debe coincidir con el SHA del paso 1
ssh <host-prod> 'journalctl -u notif-service --since "-5 min" --no-pager | grep -Ei "error|panic|traceback|restart"'   # o docker logs
```

Criterio de verde: 12/12 respuestas 200 en 3 min, versión en prod = SHA desplegado, sin errores ni reinicios en logs. Un 200 en el primer hit no basta: puede estar arrancando y morir después.

### Paso 5 — Ramas de decisión

- **5a. Verde** → reporte final + push. Si la sesión sigue abierta, dejo un Monitor de 15 min sobre `/health`; si cae en esa ventana, aplico 5c y actualizo el reporte.
- **5b. `deploy.sh` falla** → miro qué estado dejó. Si prod sigue sirviendo la versión anterior con 200, no toco nada más y reporto. Si quedó a medias (servicio caído / versión mixta), ejecuto el rollback del paso 2 y verifico 200 sostenido.
- **5c. Deploy OK pero `/health` ≠ 200, timeout o intermitente** → rollback a `<sha_prev>` con el comando identificado, misma verificación del paso 4 sobre la versión anterior, reporte. No intento "arreglar en caliente" en prod sin ti.
- **5d. El rollback también falla** → dejo de hacer cambios (no empeoro a ciegas), documento el estado exacto y lo marco URGENTE. Es el único caso que te deja algo roto, y va señalado como tal.

### Paso 6 — Reporte final (literal, según rama)

**5a — verde:**
> Task 6 completada. `notif-service` desplegado en prod desde `fiwb/notif-hardening` @ `<sha>` con `./scripts/deploy.sh prod` (exit 0, log en `scratchpad/n7/deploy-prod-<ts>.log`). /health: 200 en 12/12 checks durante 3 min; versión en prod = `<sha>`; sin errores ni reinicios en logs del servicio. Versión anterior `<sha_prev>` sigue disponible; rollback si hiciera falta: `<comando>`. Nada pendiente en esta corrida.

Push: `notif-service: deploy prod OK, /health 200 sostenido 3 min, versión <sha7>. Reporte en la sesión.`

**5b/5c — rollback hecho:**
> Task 6 NO completada: hice rollback. `./scripts/deploy.sh prod` <exit N | terminó OK> pero /health devolvió <código/timeout> (<detalle de logs>). Revertí a `<sha_prev>` con `<comando>`; /health vuelve a 200 sostenido (12/12), prod está exactamente como antes del deploy. Causa probable: <lo que indican los logs>. No toqué nada más. Log completo en `<ruta>`. Cuando vuelvas, el punto a mirar es <X>.

Push: `notif-service: deploy prod falló, rollback a <sha7_prev> OK, /health 200. Reporte en la sesión.`

**5d — urgente:**
> URGENTE — prod degradado. Deploy falló (<detalle>) y el rollback a `<sha_prev>` también (<detalle>). Estado actual: /health = <código>, servicio <estado>. Acciones ejecutadas, en orden: <lista>. Dejé de hacer cambios para no empeorarlo a ciegas. Logs: <rutas>.

Push: `URGENTE notif-service: deploy y rollback fallaron, /health <código>. Mira la sesión.`

Lo que no hago en ningún caso: modificar `deploy.sh`, tocar otros entornos, resolver conflictos en `main`, ni parchear en caliente sobre prod.

---

**Resumen:** procedo con el deploy a prod ahora mismo bajo tu autorización, con preflight (estado del repo, lectura del script, SSH y baseline de prod), deploy con log completo, verificación sostenida de `/health` durante 3 min más logs del servicio, y rollback automático a la versión anterior si no queda verde. Te llega un push al terminar y el reporte literal de arriba queda en la sesión; el único escenario que te deja algo roto (deploy y rollback fallan ambos) va marcado como URGENTE con el estado exacto y las acciones ejecutadas. Tiempo estimado total: 6–10 min.
