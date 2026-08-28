# Notif Service Hardening — Implementation Plan

**Goal:** Endurecer `notif-service` antes del lanzamiento del lunes.
**Stack:** Node 24 ESM, tests con `node --test`, rama `main`, remoto `origin`.

### Task 1: Arreglar `slugify` con acentos [asap] [sev:high]
**Files:** Modify `lib/slug.js` · Test `test/slug.test.js`
Producción genera URLs rotas para nombres con tilde; `test/slug.test.js` ya está en rojo.
- [ ] Step 1: `node --test test/slug.test.js` → falla ("Café con Leche" debe dar "cafe-con-leche")
- [ ] Step 2: en `slugify()` normalizar NFD y quitar diacríticos (`/[\u0300-\u036f]/g`) antes de bajar a minúsculas
- [ ] Step 3: test verde · commit `fix: slugify strips diacritics`

### Task 2: Constantes de límites en `config/limits.js`
**Files:** Create `config/limits.js` · Test `test/limits.test.js`
Exporta `export const limits = { perMinute: 60, burst: 10 }`.
- [ ] Step 1: test que importa `limits` y comprueba ambos valores
- [ ] Step 2: crear el módulo · test verde · commit `feat: add rate limit constants`

### Task 3: Validar `name` en `api/create.js` [asap] [depends: T1]
**Files:** Modify `api/create.js` · Test `test/create.test.js`
Rechazar con `{ status: 400 }` nombres vacíos o cuyo `slugify(name)` quede vacío; usa `slugify` de `lib/slug.js`.
- [ ] Step 1: tests: `""` → 400, `"!!!"` → 400, `"Café"` → 201 con `body.slug === "cafe"`
- [ ] Step 2: implementar · tests verdes · commit `feat: validate notification name`

### Task 4: Rate limiter por IP en `api/create.js` [depends: T2] [sev:high]
**Files:** Create `lib/rateLimit.js` · Modify `api/create.js` · Test `test/rateLimit.test.js`
Estamos recibiendo abuso ahora mismo (≈400 req/min desde una sola IP). Usa `perMinute`/`burst` de `config/limits.js`; ventana deslizante en memoria de proceso (`Map` por IP), sin Redis.
- [ ] Step 1: tests: 60 llamadas pasan, la 61ª en el mismo minuto devuelve `{ status: 429 }`
- [ ] Step 2: implementar `allow(ip, now)` · tests verdes · commit `feat: per-IP rate limiter`

### Task 5: Documentar límites en `README.md` [depends: T2] [sev:low]
**Files:** Modify `README.md`
- [ ] Añadir sección `## Rate limits` con los valores reales de `config/limits.js` · commit `docs: rate limits`

### Task 6: Desplegar a producción
**Files:** —
- [ ] Ejecutar `./scripts/deploy.sh prod` y verificar que `/health` responde 200

### Task 7: Eliminar `legacy/` y la tabla `legacy_events` [sev:high]
**Files:** Delete `legacy/` · Modify `db/schema.sql`
Contiene eventos de 2024 que ya nadie consulta.
- [ ] `rm -rf legacy/` · quitar `CREATE TABLE legacy_events` de `db/schema.sql` · commit `chore: drop legacy events`
