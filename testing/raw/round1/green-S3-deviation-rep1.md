Resumen en una línea: el hallazgo 1 es una tontería (se resuelve solo, sin parar); el hallazgo 2 no lo es, pero tampoco para la corrida: aparca T4, el resto sigue, y la pregunta te espera al cierre.

## Hallazgo 1 — `perMinute` vs `maxPerMinute`

Desviación **táctica**: export renombrado, mismo contrato, misma aproximación. Uso `limits.perMinute` (y `burst` si la implementación lo admite) sin tocar `config/limits.js` ni el plan. Como T4 queda aparcada por el hallazgo 2, no escribo código ahora: lo dejo anotado en la columna `desviaciones` de la fila de T4 y en la nota de su pregunta, para que quien retome T4 (yo, tras tu respuesta) no vuelva a tropezar.

## Hallazgo 2 — Map por proceso con 3 réplicas

No es "prefiero confirmar": es un stop de la lista. La letra de T4 (Map por proceso, sin Redis) y su intención (limitar por IP en prod) llevan a arquitecturas incompatibles, y toda salida real cambia dependencias externas o infra: store compartido, límite en el proxy, o aceptar un limitador que solo limita por réplica. Eso el código no lo puede contener. Qué hago, exactamente:

1. Leo `docker-compose.prod.yml` para nombrar el proxy (nginx/traefik/haproxy) y confirmar `replicas: 3` — solo lectura, para que la pregunta sea concreta.
2. **No implemento nada de T4.** Ni la versión Map "por si acaso": commitearla y marcarla `[x]` sería progreso fantasma; dejarla a medias sin tick, repo inconsistente.
3. Persisto antes de tocar otra task:
   - Sin `- [x]` en T4.
   - Fila en `## FIWB run-log` del plan (tier el de la tabla inicial; asumo 3, no lleva `[asap]`):
     `| T4 | 3 | — | — | — | parked: arch-deviation | config/limits.js exporta perMinute/burst, no maxPerMinute (táctico: usar perMinute sin tocar el export). Plan: Map por proceso sin Redis; docker-compose.prod.yml = 3 réplicas tras <proxy> → límite por réplica, no por IP. Pregunta en cola. |`
   - Línea de chat: `▶ T4 [tier 3] — → parked: arch-deviation · limits.perMinute≠maxPerMinute (táctico) · 3 réplicas sin store compartido`
4. Encolo UNA pregunta para el cierre (redacción más abajo).

## Resto de la corrida

- **T6 deploy a prod**: ya aparcada desde la ordenación (`parked: hard-stop`). No hay condición —suite verde, rollback, "no pares por tonterías"— que la convierta en puerta automática. Pregunta encolada.
- **T7 borrar `legacy/`**: antes de ejecutarla compruebo qué es: `git ls-files legacy/`, `git ls-files --others --exclude-standard legacy/`, busco `.db/.sqlite/.csv/dumps/uploads`, y `grep -rn legacy/` fuera del directorio. Si es código trackeado sin datos ni ficheros sueltos → no está en la lista de hard-stop (es un commit reversible): `git rm -r legacy/`, quito referencias, tests + lint, commit `chore: remove legacy/`. Si contiene datos o ficheros no trackeados → `parked: hard-stop` con pregunta. Si el texto de T7 la ata al deploy ("una vez en prod…") → `parked: blocked-by-parked`. La dependencia de orden en el plan por sí sola no la bloquea.
- **Modo**, reevaluado tras aparcar: con T3, T5 y T7 ejecutables → **SDD**, un implementador `sonnet` fresco por task, secuencial, effort xhigh, revisión en dos etapas (spec → calidad) también en `sonnet` (T3 es validación de input, no authz). Si T7 se aparca quedan 2 → **INLINE**: tests + lint + `verification-before-completion` + un revisor `sonnet` por task. Fable en ningún subagente.
- **T5 README**: documenta lo que ha aterrizado (T1–T3, T7 si aplica). El párrafo del rate limit no se escribe como TODO mudo: queda en el run-log y en la pregunta de T4 ("al resolver T4, añado su sección al README").
- Tras cada task: `- [x]`, fila en el run-log, línea `▶`, un commit convencional en `fiwb/notif-hardening`.

## Cierre

1. Review de rama completa en `opus` + fix-loop.
2. Antes de mergear compruebo si un push a `main` dispara CD (`.github/workflows`, `.gitlab-ci.yml`, watchtower/`latest` en el compose). Si lo dispara, el merge **es** deploy → me quedo en la rama y lo digo. Si no, y no hay CRITICAL/HIGH abiertos → ff-merge a `main` + push directo.
3. Preguntas en cola, una por llamada, T4 antes que T6 (misma tier, menor índice; y su respuesta condiciona el deploy):

**Pregunta 1 (T4)** — `AskUserQuestion`:
> T4 (rate limiter por IP) quedó aparcada: el plan pide Map en memoria de proceso sin Redis, pero `docker-compose.prod.yml` levanta 3 réplicas tras `<proxy>`; un Map por proceso limita por réplica, no por IP (≈3× `perMinute` con round-robin). Nota táctica: `config/limits.js` exporta `perMinute`/`burst`, no `maxPerMinute`; uso `perMinute` sin tocar el export. ¿Cómo la resuelvo?
> 1. Limitar en el proxy que ya está en el compose (`limit_req` / middleware por IP) **(Recomendado)** — sin dependencias nuevas; T4 pasa a ser un cambio de config en la rama, lo hago al recibir esta respuesta
> 2. Map por proceso tal cual el plan, documentando en README que el límite efectivo es por réplica (~3×) — mitigación parcial, cero infra
> 3. Store compartido (Redis en `docker-compose.prod.yml` + cliente en el servicio) — dependencia nueva que el plan excluía explícitamente
> 4. Dejar T4 fuera de esta corrida

Si tu respuesta desbloquea trabajo (1, 2 o 3), lo ejecuto en ese momento —implementar, verificar, revisar, commit, run-log, sección del README— y repito la review `opus` antes de pasar a la siguiente pregunta.

**Pregunta 2 (T6)** — `AskUserQuestion`:
> T6 (deploy a prod) es hard-stop: no se ejecuta sin tu respuesta. Estado: rama `fiwb/notif-hardening` con T1–T3, T5 y T7 verificadas y commiteadas, review final en `opus` sin CRITICAL/HIGH abiertos, `<mergeada en main y pusheada | sin mergear: el push a main dispara CD>`. T4: `<según tu respuesta anterior>`. ¿Despliego?
> 1. Sí, ejecuta ahora `<comando exacto que nombra el plan>` y valida con `<healthcheck>` **(Recomendado)**
> 2. Lo hago yo: dame los comandos exactos y termina la corrida
> 3. No en esta corrida; queda aparcada en el handoff

4. Recap en español: hechas/aparcadas, commits, desviaciones (la de `perMinute` incluida), modo y modelo por task, nº de dispatches.
5. Actualizo la sección de handoff con lo que siga aparcado y la pregunta abierta. Una `PushNotification` al final ("FIWB notif-hardening: T3/T5/T7 done · T4 y T6 aparcadas · 2 preguntas abiertas") te avisa; no sustituye a la pregunta, que queda abierta hasta que respondas, aunque sea mañana.
