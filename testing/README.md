# Evidencia TDD — fuck-it-we-ball

La evidencia Claude histórica de 2026-08-28 permanece en `raw/`, `triggers-result.md` y `smoke-test.md`. El harness Codex no la reescribe: copia scripts y escenarios a un directorio temporal y verifica el fingerprint antes y después.

## Runtime adapter Codex — 2026-09-03

| Artefacto | Cobertura | Resultado final |
|---|---|---|
| `codex/contract-tests.ps1` | contrato runtime, preguntas terminales, persistencia/resume, effort, desviaciones, precedencia deploy y paridad instalada | 11/11 PASS |
| `codex/run-probes.ps1 -SelfTest` | temporales propios, entorno allowlist, JSONL, kill-tree, JSON estructural, scorers con negativos, gate de hashes y Node restringido | PASS |
| `codex/run-probes.ps1 -Mode Codex -KeepArtifacts` | pregunta, routing, Workflow→SDD, persistencia, hard stops y smoke | question/routing/workflow/smoke: 4/4 PASS; tests 2/2 |
| `codex/run-probes.ps1 -Mode Claude -KeepArtifacts` | S1–S4 ×1 + triggers, timeout por brazo y scoring semántico | S1/S2/S3/S4/triggers PASS; 0 timeouts; histórica preservada |
| `codex/green-findings.md` | evidencia exacta, hashes, frontera de autenticación y limitaciones | PASS documentado sin sobreafirmar aislamiento |

```powershell
pwsh -NoProfile -File testing/codex/contract-tests.ps1
pwsh -NoProfile -File testing/codex/run-probes.ps1 -SelfTest
pwsh -NoProfile -File testing/codex/run-probes.ps1 -Mode Codex -TimeoutSeconds 900 -KeepArtifacts
pwsh -NoProfile -File testing/codex/run-probes.ps1 -Mode Claude -TimeoutSeconds 900 -KeepArtifacts
```

Evidencia final Codex: `C:\Users\Piero\AppData\Local\Temp\fiwb-codex-probes-cbdbf5e22fb64c6597a2c7693dab36f8`.

Evidencia final Claude: `C:\Users\Piero\AppData\Local\Temp\fiwb-codex-probes-562c8100a587417c858f73251c5926c6`.

El runner no acepta directorio de salida arbitrario. Siempre crea un hijo GUID nuevo bajo `%TEMP%`; `-KeepArtifacts` lo conserva y, sin ese switch, solo elimina el hijo cuyo marcador de propiedad valida.

La CLI necesita el `CODEX_HOME` real para autenticarse. Solo el proceso padre lo recibe. Los shells del modelo usan `inherit="none"`, allowlist explícita y red deshabilitada en el sandbox; las fixtures no contienen credenciales ni remotes. Esto reduce la superficie, pero no equivale a un contenedor o identidad de SO independiente.

El diagnóstico Codex de routing/Workflow exige un único bloque `FIWB_PROBE_JSON` y valida esquema, propiedades, orden, roles, modelos, `xhigh`, `fork_turns`, fallback y cero dispatches. El smoke se decide por estado observable: checkboxes/run-log, commits, rama/diff, hashes, canaries y pregunta terminal. Claude mantiene scoring textual con controles positivos y negativos; el slash-command aislado sigue `UNMEASURABLE`, aunque los siete triggers medibles pasan.
