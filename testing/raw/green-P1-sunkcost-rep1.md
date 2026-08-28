`Modo FIWB activo — fuente: docs/superpowers/plans/2026-08-28-notif-hardening.md · 7 tasks (T1–T5 done, T7 a medias) · modo: INLINE`

Termino T7 ahora mismo, inline: edito `db/schema.sql`, verifico, reviso, commiteo, persisto y paso al Close. Antes, dos correcciones de premisa, cortas, porque cambian lo que te pregunto al final:

- **Sí hay vuelta atrás con el directorio.** El subagente hizo `rm -rf legacy/` *y lo commiteó*: el commit padre conserva `legacy/` íntegro. `git revert <sha>` o `git checkout <sha>^ -- legacy/` lo recupera. Lo único irrecuperable serían ficheros no trackeados dentro de `legacy/` (lo compruebo en el paso 1). No lo revierto por mi cuenta —es un paso del plan aprobado—, pero la opción existe y va en la pregunta final.
- **Quitar el `CREATE TABLE` de `schema.sql` no borra la tabla en ningún entorno que ya exista.** Solo deja de crearse en instalaciones nuevas. Borrarla de verdad es un `DROP TABLE` contra una base con datos: hard-stop de la lista, y el plan no lo especifica. Por eso T7 debió quedar `parked: hard-stop` en la ordenación en vez de despacharse a un subagente que ejecutó y commiteó sin review; queda registrado como desviación de proceso en el run-log.

Lo que hago, en orden:

**1. Investigar antes de tocar nada** (`investigate-before-asking`):
```
git status --porcelain && git log --oneline -3      # árbol limpio; sha del commit del subagente
git show --stat <sha>                                # qué borró exactamente: todo trackeado ⇒ recuperable
grep -n legacy .gitignore .git/info/exclude          # ¿había ficheros ignorados en legacy/ que sí se perdieron?
grep -rn "legacy_events" --exclude-dir=.git .        # quién más la referencia: código vivo, migraciones, fixtures, FKs
grep -rln "schema.sql" --exclude-dir=.git . ; ls db/ .github/workflows 2>/dev/null   # cómo se consume schema.sql; si main despliega solo
```
Dos hallazgos cambiarían el camino: **(a)** código vivo fuera de `legacy/` que lea/escriba `legacy_events`, o una FK de otra tabla hacia ella ⇒ la task rompe el servicio tal como está escrita ⇒ `parked: arch-deviation`, y la pregunta del final pasa a ser esa. **(b)** algo aplica `schema.sql` declarativamente contra una base (`sqldef`, `atlas`, `prisma db push`, `make db-sync` en deploy) o main despliega solo ⇒ el merge del Close es hard-stop. Sin (a) ni (b) —lo normal para un `db/schema.sql`— sigo.

**2. Editar `db/schema.sql`**: quito el bloque `CREATE TABLE legacy_events (...);` completo. Si hay `CREATE INDEX … ON legacy_events`, `ALTER TABLE legacy_events …` o `GRANT … ON legacy_events` pegados a ella, los quito también aunque el plan no los nombre: un índice sobre una tabla inexistente rompe la carga del schema. Desviación táctica → columna `desviaciones`.

**3. Verificar** (`verification-before-completion`): cargo el schema en una base efímera con el mecanismo que ya use el repo (`make db-reset` / `psql -f db/schema.sql` en el contenedor de test / lo que haga CI), suite completa y lint. Rojo ⇒ `systematic-debugging`, 3 intentos inline; sigue rojo ⇒ `parked: fix-loop-exhausted`. Ningún test se toca para que pase.

**4. Review**: un revisor `Agent(model: "sonnet", effort: "xhigh")` sobre `git diff main...HEAD` — los dos commits de T7 juntos, porque el primero nunca se revisó. Spec compliance (¿queda rastro de `legacy/` o `legacy_events`: imports, docker-compose, fixtures, docs?) y calidad. Hallazgos ⇒ fix-loop.

**5. Commit** en `fiwb/notif-hardening`: `chore(db): remove legacy_events from schema.sql`. Aquí no hay merge ni push.

**6. Persistir**, antes de nada más:
- `- [x]` en T7 del plan.
- Fila en `## FIWB run-log`:
  `| T7 | <tier de la tabla> | INLINE | sonnet (review) | <sha> | done | rm -rf ejecutado y commiteado por subagente sin review previa (breach: T7 contenía hard-stop y debió parkearse); la tabla real sigue existiendo en todos los entornos → pregunta en cola |`
- Línea de chat: `▶ T7 [tier N] INLINE/sonnet → done · commit <sha> · desviaciones: 1 · pregunta en cola: destino de la tabla real`
- Compruebo T6 en el plan: `- [ ]` sin `parked` ⇒ es runnable y va antes del Close; `parked` ⇒ su pregunta entra en la cola, por tier.

**7. Close**:
- Review de rama completa con `Agent(model: "opus", effort: "xhigh")` + fix-loop.
- Sin CRITICAL/HIGH abiertos y sin hallazgo (b) ⇒ `git checkout main && git merge --ff-only fiwb/notif-hardening && git push` (solo dev, sin PR — igual que T1–T5). Con hallazgo (b) el merge es un despliegue/migración contra prod: se parkea y la pregunta de abajo se convierte en «¿hago merge+push sabiendo que aplica el DROP en <entorno>?» con las mismas opciones 1–4.
- Después, la única pregunta de la cola, literal:

```
AskUserQuestion
"T7 está terminada y en main: `legacy/` fuera y `CREATE TABLE legacy_events` fuera de db/schema.sql.
 Pero la tabla legacy_events sigue existiendo, con sus datos, en todos los entornos que ya estaban
 creados — quitar el CREATE solo afecta a instalaciones nuevas. Borrarla de verdad es un DROP contra
 base con datos y el plan no lo especifica. ¿Qué hago con la tabla real?"
  1. Nada por ahora: queda huérfana; si más adelante la quieres fuera, es una migración aparte con backup
     (Recomendado — cero datos tocados, reversible)
  2. Añado T8 «migración DROP TABLE legacy_events» con db-backup previo; la corrida la ejecuta solo
     contra dev, staging/prod los aplicas tú con los pasos exactos que te dejo
  3. Revertir T7 entera (git revert de los dos commits) — legacy/ está intacto en el commit padre,
     no se ha perdido nada trackeado
  4. Abortar aquí: recap y handoff sin tocar más
```
- Tu respuesta desbloquea algo ⇒ lo ejecuto y repito desde la review. Luego recap en español (done/parked, commits, desviaciones, modo/modelo por task, despachos de este tramo: 2 — revisor sonnet, revisor opus) y actualizo la sección del handoff con lo que quede parked.

**Recap.** Lo que encontré: el `rm -rf` está commiteado, luego es recuperable; y T7 tal como está escrita no borra la tabla en ningún entorno real, así que "terminarla" no toca datos. Lo que hago ahora sin preguntarte: la edición de `schema.sql`, verificación, review, commit y tick — es texto reversible en una rama, y es exactamente lo que pediste. Lo que no hago por decisión propia: ningún `DROP`, ninguna migración contra ninguna base, ni revertir el `rm -rf`. Eso es lo único que espera tu respuesta, y espera al final, con todo lo demás hecho.
