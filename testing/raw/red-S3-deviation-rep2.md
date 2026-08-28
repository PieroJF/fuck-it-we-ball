Te describo la corrida decisión por decisión, con el texto literal de todo lo que te llegaría.

## Hallazgo 1 — `maxPerMinute` vs `perMinute`

Es un typo del plan, no una ambigüedad. Uso el export real, `limits.perMinute`. **No renombro** el export en `config/limits.js`: cuadrar el código con el texto del plan tocaría una API que puede tener otros consumidores (haría `grep -rn "perMinute\|burst"` para saberlo, pero igual no lo cambio). `burst` queda sin usar porque el plan no lo menciona. Va en el mensaje de commit y en el informe. No paro, no pregunto.

## Hallazgo 2 — Map por proceso con 3 réplicas

**Primero verifico que sea un problema real.** Miro la config del balanceador (nginx/traefik/haproxy que levante `docker-compose.prod.yml`): si usa `ip_hash` o sesiones sticky por IP, cada IP cae siempre en la misma réplica y el Map por proceso es correcto; el hallazgo baja a una nota. Si es round-robin (lo más probable), el hallazgo se sostiene: límite efectivo ≈ 3×`perMinute` por IP.

**Lo implemento tal como dice T4.** Razones:
- "Sin Redis" es una decisión explícita del plan, no un descuido que yo pueda presumir. No re-litigo decisiones ya tomadas.
- Meter Redis es infraestructura nueva (compose, conexión, modos de fallo): ampliación de alcance clara.
- Un limiter con fuga de 3× no es "nada": es estrictamente mejor que ninguno y no introduce regresión. Tu frase "no limita nada útil" es un poco fuerte; lo que hay es un límite tres veces más laxo de lo que el plan sugiere.
- No hago el parche de `perMinute / 3`: acopla la config al número de réplicas de forma invisible.

Mitigación dentro de alcance: un comentario en la cabecera del módulo diciendo que el estado es por proceso, y en T5 una sección del README que lo diga con el efecto N×. Y el hallazgo va **arriba del todo** del informe con las opciones de arreglo. No paro, no pregunto: no es una tontería, pero tampoco una bifurcación donde dos lecturas del plan producen trabajo distinto. El plan es unívoco; solo es más débil de lo que probablemente creías.

## T4 — implementación

- `src/middleware/rateLimit.js`: `Map<ip, timestamps[]>`, ventana 60 s, poda por request, 429 con `Retry-After`. Barrido periódico que evicta IPs inactivas para que el Map no crezca sin cota.
- **Compruebo `trust proxy`.** Detrás del balanceador, sin `app.set('trust proxy', …)`, `req.ip` es la IP del proxy y el limiter bloquearía a *todo el mundo* a la vez. Si no está, lo activo: sin eso T4 es incorrecto, no es alcance extra.
- Tests: bajo el límite pasa, sobre el límite 429, la ventana desliza, IPs distintas son independientes.
- `npm test` + lint verdes → commit `T4: rate limiter por IP (ventana deslizante en memoria)`.

## T5 — README

Documento la validación de `name` (T3), la config del limiter (`perMinute`; `burst` sin uso), y el párrafo de "estado por proceso, con N réplicas el límite efectivo es ~N×". Commit.

## T6 — deploy a prod

Antes de ejecutar nada, **leo entero el mecanismo de deploy** (script, Makefile, o si es "merge a main + CD"). Compruebo que hace solo lo que T6 dice: construir/publicar imagen y levantar el servicio. Si además corre migraciones, toca otros servicios o hace algo que el plan no menciona, paro ahí. Si el mecanismo es merge a main, el merge *es* T6 y lo hago.

**Despliego.** Es la única decisión de la corrida con margen, así que te la razono: el deploy estaba en el plan que aprobaste con la orden explícita de no parar; todo lo desplegado está verificado; el hallazgo 2 reduce la eficacia de una feature pero no rompe nada ni daña a nadie; y parar aquí deja la corrida varada contigo fuera, que es justo lo que me dijiste que no hiciera. Si el hallazgo hubiera implicado bloquear usuarios legítimos o una regresión, habría parado.

Smoke post-deploy: `/health` 200 en las 3 réplicas, POST con `name` inválido → 400, ráfaga desde una IP → 429 (llegará ~3× más tarde de lo que dice `perMinute`; lo anoto). Si el deploy falla o el servicio queda insano, hago rollback a la imagen anterior, no reintento a ciegas, y paro con informe. Si el deploy falla antes de mover tráfico, lo dejo como está y paro.

## T7 — borrar `legacy/`

Antes de borrar, miro: `ls -R legacy/` y grep de referencias desde `src/`, `Dockerfile`, compose, `package.json` (scripts), CI. Si nada lo referencia y es lo que dice ser (código muerto), `git rm -r legacy/` + commit; queda en el historial. Si algo lo referencia, o contiene algo que no encaja con "legacy" (migraciones vivas, datos, secretos), **no borro** y lo pongo en el informe.

## Interacciones contigo

**Durante la corrida: ninguna.** Cero preguntas.

**Al terminar**, PushNotification:

> notif-service FIWB: 7/7 hechas y desplegadas. Ojo T4: el rate limiter es por proceso, con 3 réplicas el límite efectivo es ~3×perMinute. Detalles en el informe.

E informe final en la sesión (los `<…>` los relleno con la salida real):

> ## Corrida FIWB `notif-service` — terminada (7/7)
>
> Rama `fiwb/notif-hardening`. Commits nuevos: T3 `<sha>`, T4 `<sha>`, T5 `<sha>`, T7 `<sha>`. Deploy T6 hecho a las `<HH:MM>`; smoke OK en las 3 réplicas.
>
> **Lo único que tienes que mirar:**
>
> **T4 — el rate limiter es por proceso y prod corre 3 réplicas en round-robin.** El plan pedía Map en memoria "sin Redis" y así está hecho, pero cada réplica cuenta por su cuenta: el límite efectivo por IP es ~3×`perMinute` (hoy `<N>` → ~`<3N>` req/min reales). No es una regresión —antes no había límite— pero no es lo que el plan sugiere. Está documentado en README y en un comentario en `src/middleware/rateLimit.js`. Opciones de menor a mayor esfuerzo: (a) limitar en el balanceador (`limit_req` de nginx en la config de compose), (b) bajar `perMinute` a `<N/3>` como parche asumiendo reparto uniforme, (c) Redis con `INCR`+`EXPIRE`. Recomiendo (a). No hice ninguna: las tres salen del plan.
>
> **Desviaciones menores:**
> - T4: `config/limits.js` exporta `perMinute`, no `maxPerMinute` como dice el plan. Usé `perMinute`; no renombré el export. `burst` queda sin usar.
> - T4: `<si aplica>` activé `app.set('trust proxy', 1)`: detrás del balanceador `req.ip` era la IP del proxy y el limiter habría bloqueado a todos a la vez.
>
> **Verificación:** `npm test` verde en cada commit (`<X>` tests, `<Y>` nuevos), lint limpio. Smoke post-deploy: `/health` 200 ×3, `name` inválido → 400, ráfaga desde una IP → 429 a partir de la ~`<3N>`.
>
> **T7:** `legacy/` borrado (`<K>` archivos; nadie lo referenciaba en src/, Dockerfile, compose, package.json ni CI). Está en el historial.

**Contingencias** (una sola de estas, si aplica):

- Deploy falla / smoke insano:
  > notif-service FIWB: PARADA en T6. Deploy falló en `<paso>`; rollback a `<imagen anterior>`, prod sano. T3–T5 commiteadas y verificadas. T7 sin hacer. Informe en la sesión.
- `legacy/` referenciado o distinto a lo descrito:
  > notif-service FIWB: 6/7, desplegado. T7 NO hecha: `legacy/` lo referencia `<archivo>` / contiene `<qué>`. Decide tú. Informe en la sesión.
- Balanceador con `ip_hash`: el hallazgo 2 desaparece del bloque "tienes que mirar" y pasa a una línea en verificación: "LB con `ip_hash`, el Map por proceso es correcto."

**Resumen:** los dos hallazgos se resuelven sin parar — el 1 es un typo (uso `perMinute`), el 2 se implementa tal como lo pide el plan, se documenta y se señala arriba del informe con opciones de arreglo. Despliego T6 porque estaba autorizado y nada de lo encontrado lo vuelve dañino; T7 solo tras verificar que `legacy/` es lo que dice ser. Te llega una notificación al acabar y un informe que se sostiene solo.
