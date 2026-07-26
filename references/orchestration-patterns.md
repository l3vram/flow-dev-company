# Patrones de orquestación (mejoras destiladas de proyectos similares)

Estas piezas las adopta `flow-dev-company` en sus fases. Destiladas de: aaddrick/claude-pipeline
(estado JSON + gates en capas), barkain/claude-code-workflow-orchestration (wave scheduling +
roster de agentes), alexop.dev (determinismo + fan-out→reduce→synthesize), y la arquitectura
Planner→Executor→Reviewer común en AgentMesh/CrewAI/AutoGen/"great_cto".

---

## 1. Wave scheduling (olas) — cómo derivar el paralelismo del DAG
No decidas "a ojo" qué corre junto. Deriva **olas** del grafo de dependencias de `plans/README.md`
por capas topológicas (Kahn):

- **Ola 1** = todos los planes sin dependencias.
- **Ola N** = planes cuyas dependencias están todas en olas < N.

Regla de ejecución:
- Los planes de **una misma ola corren en paralelo** (mismo mensaje, background).
- **Barrier entre olas:** no arranques la ola N+1 hasta que la ola N esté verde (o marcada
  BLOCKED y saltada conscientemente).
- Un plan BLOCKED no bloquea a sus hermanos de ola; sí bloquea a sus dependientes de olas
  siguientes (se posponen o escalan a gate humano).

Esto convierte "paraleliza donde puedas" en un cálculo, no una corazonada.

---

## 2. Roster de agentes especializados (cada agente sabe quién es y qué NO toca)
Cada ejecutor/revisor que despachas adopta un **rol con contrato**: alcance explícito +
anti-patrones + tier. El prompt del agente SIEMPRE incluye: su rol, sus límites de alcance,
sus anti-patrones, el plan autocontenido, y el contrato de salida. Así "tiene su contexto en
cada paso y sabe qué hacer".

| Rol | Tier | Hace | NO hace (anti-patrón) |
|-----|------|------|------------------------|
| `architect` / tech-lead | opus | Diseña, descompone en planes, adjudica findings | Escribir código de producto |
| `backend-dev` | sonnet | Implementa planes de backend/API/lógica | Tocar UI o infra fuera de su plan |
| `frontend-dev` | sonnet | Implementa UI/componentes | Cambiar contratos de API sin coordinar |
| `data-dev` | sonnet/haiku | Schema, migraciones, seeds | Lógica de negocio fuera de datos |
| `qa` / test-validator | sonnet | Escribe/corre tests, valida done-criteria | Editar código de producto (solo tests) |
| `security-reviewer` | opus | Review con lente seguridad | Reescribir; solo reporta hallazgos |
| `perf-reviewer` | sonnet | Review con lente performance | Reescribir; solo reporta |
| `docs` | haiku | Changelog, README, notas de PR | Decisiones de arquitectura |

Asignación: elige el rol por el tipo de plan (backend/frontend/data/test/docs). Si dudas entre
dos, gana el más acotado. El architect (opus) es el único que planea y adjudica.

---

## 3. Archivo de estado del run (resume + dashboard + circuit breaker)
Mantén `.flow/state.json` en el repo de trabajo. Es la fuente de verdad machine-readable:
permite reanudar un run, renderizar el panel de flota, y cortar loops infinitos.

```json
{
  "run": "2026-07-25-chatbot",
  "objective": "Chatbot de soporte con streaming y moderación",
  "phase": "execute",
  "gates": { "A": "approved", "B": "pending" },
  "waves": [["001"], ["002","003"], ["004"]],
  "current_wave": 1,
  "plans": [
    { "id": "001", "role": "data-dev", "tier": "haiku",
      "status": "green", "attempts": 1, "deps": [], "worktree": "wt-001" },
    { "id": "002", "role": "backend-dev", "tier": "sonnet",
      "status": "running", "attempts": 1, "deps": ["001"], "worktree": "wt-002" },
    { "id": "003", "role": "backend-dev", "tier": "sonnet",
      "status": "blocked", "attempts": 2, "deps": ["001"], "worktree": "wt-003" }
  ]
}
```

- `status`: `pending | running | review | green | blocked`.
- **Circuit breaker:** `attempts >= 3` en un plan → no reintentar; marcar blocked y escalar a
  gate humano. Nunca quemar presupuesto en reintentos ciegos.
- Actualiza el archivo en cada transición; el panel de flota se renderiza leyéndolo.

---

## 4. Gates de review en capas (el gauntlet de 4 capas)
Ningún diff se confía por defecto. Cada plan ejecutado pasa por, en orden:

1. **Spec-compliance** — ¿hace exactamente lo que el plan pedía? (done-criteria del plan).
2. **Correctness** — bugs, edge cases.
3. **Security** — inputs, secretos, authz.
4. **Tests & quality** — cobertura nueva, estilo, mantenibilidad.

Sobre las capas, **verificación adversarial**: cada hallazgo que sobrevive se intenta refutar
con N escépticos; se conserva solo por mayoría. Lentes diversas (correctness/security/perf/
mantenibilidad) atrapan lo que N chequeos idénticos no.

---

## 5. Determinismo (si escribes un script de orquestación real)
El control-flow es código determinista; solo el trabajo dentro de `agent()` es del modelo.
Si generas un script (dynamic workflow) para reanudar/cachear:
- Prohibido `Date.now()`, `Math.random()`, `new Date()` sin args en el control-flow.
- Pasa timestamps por `args`; varía prompts/labels por índice para diversidad.
- Combinar resultados (flatten/dedupe/filter) es código, cero tokens — no gastes un agente en plomería.

---

## 6. Modo subagente vs modo equipo, y convención de retorno
- **Default subagente:** cada plan corre en un `Agent` aislado (worktree) y devuelve resultado.
- **Modo equipo (si `TeamCreate`/`SendMessage` están disponibles):** agentes que colaboran
  peer-to-peer con lista de tareas compartida — útil cuando dos planes deben coordinarse en vivo.
- **Retorno liviano:** para artefactos grandes, el agente escribe a archivo y devuelve
  `DONE|<ruta>` en vez de volcar todo el contenido — mantiene liviano el contexto del orquestador.
  Para datos chicos, salida JSON validada por `schema`.
