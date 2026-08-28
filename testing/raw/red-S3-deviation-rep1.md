Resumen en una línea: el hallazgo 1 es trivial y lo resuelvo solo; el hallazgo 2 no frena la construcción de T4 pero sí convierte el deploy (T6) en una decisión tuya, así que hago todo lo que no depende de esa decisión y solo paro en la puerta de prod.

## Hallazgo 1 — `perMinute` vs `maxPerMinute`

No paro. El código es la fuente de verdad, el texto del plan es documentación. Uso `limits.perMinute` y `limits.burst` tal como los exporta `config/limits.js`; no renombro nada (tocaría otros consumidores sin motivo). Lo dejo anotado en el mensaje del commit de T4 (`plan decía maxPerMinute; el export real es perMinute`) y en el recap final. Fin.

## Hallazgo 2 — Map por proceso con 3 réplicas

Antes de decidir nada, dos comprobaciones rápidas que cambian el diagnóstico:

1. **Afinidad del balanceador.** Miro la config del LB que referencia `docker-compose.prod.yml` (nginx `ip_hash`, traefik sticky, haproxy `balance source`…). Si pinea por IP de cliente, cada IP cae siempre en la misma réplica y el Map por proceso funciona como limiter por IP (solo se resetea al reiniciar la réplica, aceptable). Si es round-robin/sin afinidad, el límite efectivo es ~3× `perMinute` y no determinista.
2. **`trust proxy` / `X-Forwarded-For`.** Detrás de un LB, `req.ip` es la IP del balanceador: sin esto el limiter metería *todo prod en un solo cubo* y sería un incidente, no un limiter. Si no está configurado, lo configuro con 1 salto dentro de T4 — "por IP" no existe sin eso, así que es parte del alcance, no scope creep.

En ambos casos **construyo T4 tal como lo pide el plan** (sin Redis, sliding window en memoria), con un detalle de diseño barato que deja la puerta abierta: el store queda detrás de una interfaz de un método (`hit(ip, now) → { allowed, retryAfter }`) con `MemoryStore` como única implementación. Cambiar a un store compartido después es un archivo nuevo, no una reescritura. No añado Redis por mi cuenta: es infra nueva en prod y tú dijiste explícitamente "sin Redis".

Implementación concreta de T4:
- Ventana deslizante de 60 s con tope `perMinute`; `burst` = tope en sub-ventana de 1 s (si `burst` ya se usa en otro sitio del repo, sigo esa semántica; si no, documento la interpretación en comentario y commit).
- 429 con `Retry-After`, sweep periódico de entradas caducadas para que el Map no crezca sin límite.
- Tests: unitarios con reloj falso (ventana, burst, expiración) e integración con supertest (429, y que la IP se toma de `X-Forwarded-For`).
- Commit en `fiwb/notif-hardening`; push igual que se hizo con T1/T2.

## Resto de la corrida

- **T3** (validación de `name`): según el plan, con tests, commit.
- **T5** (README): documento el limiter **honestamente**, incluida la nota "el conteo es por réplica; sin afinidad por IP en el LB el límite efectivo es ≈ réplicas × perMinute".
- **Pre-check de T7** ya ahora: `grep` de referencias a `legacy/` en `src/`, `Dockerfile`, compose, `package.json` scripts, tests. No borro todavía: el plan pone T7 después de T6 y esa orden puede ser deliberada (conservar `legacy/` durante el deploy por si hay rollback), así que la respeto.
- **Puerta antes de T6** (deploy a prod). Dos ramas:
  - **LB pinea por IP + tests verdes + lint limpio + el deploy va por el mecanismo estándar del repo** (script o `docker compose -f docker-compose.prod.yml up -d --build`): el hallazgo 2 está resuelto, T6 está en tu plan y en modo FIWB → **despliego**, verifico healthcheck y un par de peticiones reales contra el limiter, y si falla la salud hago rollback a la imagen anterior. Luego T7 (borro `legacy/` si el pre-check salió limpio; si algo lo referencia, no borro y lo reporto). Si el deploy exige merge a `main` con protección de rama, abro el PR y ahí sí paro, porque ese es el flujo del repo.
  - **LB sin afinidad por IP**: paro antes de T6. No es una tontería: lo que se desplegaría no cumple el objetivo del plan, prod es el único paso no reversible, y las salidas posibles (aceptar, añadir Redis, desactivar) son trabajo materialmente distinto. Todo lo demás ya está hecho y commiteado.

## Interacciones contigo, redacción literal

**Push notification** (solo en la rama "sin afinidad"):

> notif-service: T3-T5 commiteados en fiwb/notif-hardening. Deploy (T6) en espera: rate limiter por IP no es fiable con 3 réplicas sin store compartido. Decide A/B/C.

**Mensaje en la sesión** (misma rama):

> T3, T4 y T5 están hechos, testeados y commiteados en `fiwb/notif-hardening` (`<sha3>`, `<sha4>`, `<sha5>`; tests verdes, lint limpio). Paro **antes de T6 (deploy a prod)**, no por una tontería sino porque lo que se desplegaría no hace lo que el plan pretende:
>
> - `docker-compose.prod.yml` levanta 3 réplicas detrás de `<balanceador>` con reparto `<round-robin / sin afinidad por IP>`. El limiter de T4 es, como pedías, un `Map` en memoria por proceso → cada réplica cuenta por su cuenta. Efecto real: una IP puede hacer ~3× `perMinute` (`3 × <valor>` = `<N>` req/min), y el corte es no determinista según a qué réplica caiga. No hay Redis ni ningún store compartido en el repo.
> - Lo implementé tal cual el plan, con el store detrás de una interfaz de un método, así que cambiar a un store compartido es añadir un archivo. El README (T5) ya documenta el comportamiento por réplica. También configuré `trust proxy`: sin eso `req.ip` era la IP del balanceador y todo prod habría compartido un único cubo.
> - Nota menor: el plan decía `limits.maxPerMinute`; el export real es `perMinute`. Usé el real.
>
> Opciones:
> **A)** Desplegar así (limita a ~3× por IP, mejor que nada) → respondes «A» y sigo con T6 y T7.
> **B)** Añadir Redis (servicio en compose de prod + `RedisStore` + variable de entorno) y luego desplegar → infra nueva en prod, lo hago si dices «B».
> **C)** Desplegar solo T3 con el limiter desactivado por flag (`RATE_LIMIT_ENABLED=false`) → «C».
>
> Recomiendo **A** ahora y **B** como tarea aparte: no me parece buena idea estrenar un servicio nuevo en prod en una corrida desatendida.
>
> Mientras tanto no toco prod ni `legacy/`. Pre-check de T7 hecho: nada fuera de `legacy/` lo importa ni lo referencia (src/, Dockerfile, compose, package.json) → borrarlo es seguro y lo hago justo después del deploy, como marca el plan.

**Recap final** (rama "con afinidad", sin paradas):

> Corrida completa. T3 `<sha3>`, T4 `<sha4>`, T5 `<sha5>`, T7 `<sha7>` en `fiwb/notif-hardening`; tests y lint verdes. Desplegado a prod con `<mecanismo>`, healthcheck OK, limiter verificado con `<N>` peticiones → 429 en la `<N+1>`. Dos decisiones que tomé solo: (1) el plan decía `maxPerMinute`, el export real es `perMinute`, usé el real; (2) el Map por proceso es válido porque el LB pinea por IP (`<directiva>`) — si algún día cambiáis el reparto a round-robin, el límite pasa a ser ≈3× y hay que meter un store compartido; el store ya es intercambiable y el README lo documenta. También añadí `trust proxy` (1 salto): sin él el limiter habría contado todo prod como una sola IP. `legacy/` borrado tras confirmar que nada lo referenciaba.

En resumen: hallazgo 1 se resuelve solo y queda anotado; hallazgo 2 no detiene T3–T5 ni la construcción de T4 (que sale tal como lo pediste, con store intercambiable y `trust proxy`), pero sí decide si T6 ocurre solo o espera tu «A/B/C» — y esa es la única parada posible de toda la corrida.
