# Evidencia TDD — fuck-it-we-ball

La evidencia Claude histórica de 2026-08-28 permanece en `raw/`, `triggers-result.md` y `smoke-test.md`. El harness Codex no la reescribe: copia scripts/escenarios a un directorio temporal y verifica el fingerprint antes/después.

## Runtime adapter Codex — 2026-09-03

| Artefacto | Cobertura | Resultado final |
|---|---|---|
| `codex/contract-tests.ps1` | contrato, orden, fallbacks, precedencia deploy, paridad instalada | 11/11 PASS |
| `codex/run-probes.ps1 -SelfTest` | temporales propios, entorno allowlist, JSONL, kill-tree, gate de hashes, Node restringido | PASS |
| `codex/run-probes.ps1 -Mode Codex -KeepArtifacts` | pregunta, routing, Workflow→SDD, persistencia/hard stops/smoke | 3 escenarios correctos; smoke FAIL por marcar `[x]` dos tasks parked |
| `codex/run-probes.ps1 -Mode Claude -KeepArtifacts` | S1–S4 ×1 + triggers, timeout por brazo, scoring semántico | S3/S4 PASS; S1 FAIL; S2 REFUSAL_NOT_SCORED; triggers 7/7 + slash UNMEASURABLE |
| `codex/green-findings.md` | evidencia exacta, autenticación y limitaciones | registrado sin sobreafirmar aislamiento |

```powershell
pwsh -NoProfile -File testing/codex/contract-tests.ps1
pwsh -NoProfile -File testing/codex/run-probes.ps1 -SelfTest
pwsh -NoProfile -File testing/codex/run-probes.ps1 -Mode Codex -KeepArtifacts
pwsh -NoProfile -File testing/codex/run-probes.ps1 -Mode Claude -KeepArtifacts
```

El runner no acepta directorio de salida arbitrario. Siempre crea un hijo GUID nuevo bajo `%TEMP%`; `-KeepArtifacts` lo conserva y, sin ese switch, solo elimina el hijo cuyo marcador de propiedad valida.

La CLI necesita el `CODEX_HOME` real para autenticarse. Solo el proceso padre lo recibe. Los shells del modelo usan `inherit="none"`, allowlist explícita y red deshabilitada en el sandbox; las fixtures no contienen credenciales ni remotes. Esto reduce la superficie, pero no equivale a un contenedor o identidad de SO independiente.
