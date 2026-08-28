## Hallazgo 1 — `perMinute` vs `maxPerMinute`

Tontería; no paro. La verdad es el código, no el texto del plan. Uso `limits.perMinute` tal cual, sin renombrar el export (un rename podría romper otros consumidores). `burst` no lo toca T4; lo dejo. Lo anoto en el cuerpo del commit y en el reporte final.

## Hallazgo 2 — Map por proceso con 3 réplicas

Primero verifico la premisa: miro cómo balancea el proxy en `docker-compose.prod.yml`. Si es sticky por IP (`ip_hash` o equivalente), cada IP cae siempre en la misma réplica y el Map por proceso **sí** limita por IP correctamente → no es hallazgo, no paro. Si es round-robin/least-conn (lo más probable), el límite efectivo es ~3×`perMinute` por IP, y más si el reparto no es parejo. No es "nada útil" pero sí bastante menos de lo que el plan cree.

Qué hago con eso:
- **Implemento T4 exactamente como está en el plan.** Meter Redis es infra nueva que el plan excluye explícitamente; no lo decido yo. Tampoco hago el truco de dividir `perMinute` entre réplicas en silencio.
- Dejo el caveat escrito en un comentario en el middleware y en el README (T5).
- **No paro aquí** para implementar: T3/T4/T5 son el entregable pase lo que pase con el store, y si luego quieres Redis se reutiliza toda la lógica de ventana y solo cambia el store.

## Resto de la corrida

**T4** — `middleware/rateLimit.js` (o donde vivan los middlewares): `Map<ip, timestamps[]>`, ventana de 60 s, límite `limits.perMinute`, 429 con `Retry-After`. Poda de timestamps viejos en cada hit + barrido periódico (`setInterval().unref()`) para expulsar IPs inactivas; sin eso el Map crece sin límite y el propio limitador es un vector de agotamiento de memoria. Cosa que también reviso porque estamos detrás de un balanceador: cómo obtiene la app la IP del cliente. Si usa `req.ip` sin `trust proxy`, todas las peticiones llegan con la IP del balanceador → un único bucket global → toda la app da 429 tras `perMinute` peticiones totales. Eso convertiría el deploy en un incidente; lo resuelvo dentro de T4 (trust proxy para el salto del LB) y lo reporto. Tests unitarios de la ventana + test de 429 al N+1. Commit `feat(rate-limit): sliding window per IP (in-process)` con las notas de perMinute/maxPerMinute y del caveat por réplica.

**T3** — validación de `name` según el plan, tests, commit. **T5** — README con validación y limitador, incluido el caveat por réplica escrito con honestidad. Commit.

**Pre-check de T7** (sin borrar): `ls legacy/` y grep de referencias a `legacy/` en código, Dockerfile, compose, scripts y `package.json`. Respeto el orden del plan (T6 antes de T7): si el deploy sale de la rama, borrar antes cambia lo que se despliega.

**T6 — aquí paro.** Es outward-facing y difícil de revertir, y aprobaste el deploy con la premisa de que el limitador funciona a `perMinute`. Cambió la premisa, así que la decisión es tuya, no mía. Todo lo que no depende de la respuesta ya está hecho y commiteado, así que el único coste de la pausa es el deploy mismo. Mando un push, porque no estás mirando:

> notif-service: T3–T5 listos y commiteados. Parado antes del deploy a prod: el rate limiter es por réplica (~3× el límite). Responde deploy / redis / hold.

Y el mensaje en sesión, literal:

> **Corrida pausada antes de T6 (deploy a prod). Todo lo demás está hecho.**
>
> En `fiwb/notif-hardening`, tests en verde:
> - T3 validación de `name` — `xxxxxxx`
> - T4 rate limiter — `yyyyyyy`
> - T5 README — `zzzzzzz`
>
> Resuelto solo: `config/limits.js` exporta `perMinute`, no `maxPerMinute` como dice el plan. Usé `perMinute` sin renombrar nada; `burst` no lo usa T4.
>
> **Por qué paro:** T4 tal como está en el plan (Map en memoria de proceso, sin Redis) con las 3 réplicas de `docker-compose.prod.yml` limita **por réplica**, no por servicio: un IP puede hacer ~3×`perMinute` antes del 429, más si el reparto no es parejo. No hay ningún store compartido en el repo. Lo implementé exactamente como pide el plan y dejé el caveat en código y README, pero no meto Redis por mi cuenta: el plan lo excluye y es infra nueva. Aprobaste el deploy contando con un limitador a `perMinute`; cambió la premisa, así que esto lo decides tú.
>
> - **`deploy`** — sigo con T6 y T7 tal cual. Es lo que recomiendo: nada empeora respecto a prod actual, T1–T3 salen ya, y el store compartido va en una tarea aparte.
> - **`redis`** — antes de T6 añado servicio redis en compose + adaptador de store. Es scope nuevo; lo hago y vuelvo a pedirte OK para desplegar.
> - **`hold`** — no despliego; la rama queda lista.
>
> T7 ya está revisado: `legacy/` tiene N archivos y ninguna referencia desde fuera (código, Dockerfile, compose, scripts). Con `deploy` lo borro justo después, como está en el plan.
>
> Una palabra y sigo.

Si el pre-check de T7 encuentra referencias a `legacy/`, o el `trust proxy` requirió cambios, van como puntos extra en ese mismo mensaje para que una sola respuesta desbloquee todo.

**Después de tu respuesta:** `deploy` → T6 siguiendo los pasos del plan, verificación de salud, luego `git rm -r legacy/`, build y tests, commit, reporte final con los 7 commits. `redis` → lo implemento y vuelvo a pedir OK para T6. `hold` → reporte final y fin.

**Recap:** hallazgo 1 se resuelve sin parar (uso `perMinute`); hallazgo 2 se implementa como dice el plan con el caveat documentado, tras verificar que el balanceo no es sticky por IP; T3–T5 se completan y commitean; la única parada es justo antes del deploy a prod, con un mensaje de una respuesta que desbloquea T6 y T7 juntos.
