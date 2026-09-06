# Evidencia TDD — fuck-it-we-ball

La evidencia Claude histórica de 2026-08-28 permanece intacta en `raw/`, `triggers-result.md` y `smoke-test.md`. El informe vigente es [`codex/green-findings.md`](codex/green-findings.md), actualizado el 2026-09-06 con versiones, hashes, fallos conservados y verificaciones dirigidas.

| Cobertura | Resultado verificado |
|---|---|
| Contrato estático | 11/11 PASS; frontmatter y paridad del skill incluidos. |
| Self-test del runner | PASS: límites de tiempo también con stdout cerrado y stdin bloqueado; normalización de rutas Windows; tipos JSON; columnas/estados de persistencia; límites de ejecución del smoke. |
| Codex | Pregunta y Workflow PASS; routing de autenticación PASS con el skill final. Smoke: cuatro commits reales, canaries preservados y tests 2/2; artefactos reevaluados con el parser final. |
| Claude | S1–S4 PASS; siete triggers medibles tienen evidencia PASS tras un retry dirigido del único resultado inicialmente vacío. Slash-command aislado UNMEASURABLE. |
| Cambio de precedencia de modelos | Codex auth→Sol y Claude auth→Opus PASS; Claude mantiene sum/Map→Sonnet. |

No se presenta una matriz antigua como validación de una versión posterior: el informe distingue cada snapshot y conserva las corridas fallidas. Los probes de routing son diagnósticos prospectivos; no acreditan argumentos reales de spawn ni la identidad del modelo proveedor.

```powershell
pwsh -NoProfile -File testing/codex/contract-tests.ps1
pwsh -NoProfile -File testing/codex/run-probes.ps1 -SelfTest
pwsh -NoProfile -File testing/codex/run-probes.ps1 -Mode Codex -TimeoutSeconds 900 -KeepArtifacts
pwsh -NoProfile -File testing/codex/run-probes.ps1 -Mode Claude -TimeoutSeconds 900 -KeepArtifacts
```

El runner crea un hijo GUID propio bajo `%TEMP%`; no acepta destinos arbitrarios. `-KeepArtifacts` conserva la evidencia. El self-test requiere PowerShell, Git, Codex, Node y Python.

La autenticación permanece en el proceso padre; las fixtures no contienen copias de credenciales ni remotes. Los shells del modelo reciben una allowlist sin secretos y los permisos del smoke protegen sus canaries. La auditoría de comandos/rutas es observacional y no equivale a aislamiento independiente de SO/contenedor. Véanse las limitaciones completas en el informe.
