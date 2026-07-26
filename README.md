# flow-dev-company

**Orquestador de desarrollo de software de punta a punta para Claude Code.**
Un solo skill: le das un objetivo ("quiero desarrollar un chatbot"), te enriquece el spec
con preguntas y mejoras de senior, planifica, y ejecuta con una **flota de agentes en
paralelo** — un cerebro caro planea y revisa, manos baratas ejecutan en worktrees aislados,
cada tarea al modelo del tier correcto, y con panel de flota en vivo.

Autocontenido: **no depende de instalar nada más.**

---

## Idea en una línea

> Un prompter hace una pregunta. Un arquitecto dibuja un grafo.
> Este skill convierte "haz A, luego B, luego C" en olas de agentes que corren en paralelo,
> con gates humanos donde importan las decisiones y verificación donde importa la confianza.

## Cómo funciona

```
0 Intake → 1 Enrich → 2 Plan → 🚦GATE A → 3 Ejecución (olas) → 4 Verify → 5 Review → 🚦GATE B → 6 Handoff
           (preguntas   (cerebro   humano    (flota paralela     (código,   (gates en   humano   (docs)
            + mejoras)   asesor)              en worktrees)       no agente) capas)
```

- **Enrich** — se auto-especializa en el dominio, propone mejoras que un buen desarrollo
  tendría, y te hace las preguntas que faltan con opciones + presets (MVP / Producción / A medida).
- **Plan** — un cerebro asesor (tier caro) escribe planes autocontenidos con su grafo de
  dependencias (DAG).
- **🚦 Gate A** — apruebas el plan antes de gastar en la flota.
- **Ejecución por olas** — el DAG se corta en *olas* (capas topológicas); cada ola corre en
  paralelo, en worktrees aislados, con cada agente en su **rol** (backend/frontend/data/qa/
  docs…) y **tier** (haiku/sonnet/opus). Barrier entre olas.
- **Verify** — done-criteria del plan (build/test/lint), código determinista, bloqueante.
- **Review en capas** — spec-compliance → correctness → security → tests/quality, con
  verificación adversarial.
- **🚦 Gate B** — revisión final humana antes de merge.

Detalles en [`SKILL.md`](SKILL.md), el proceso conceptual en [`WORKFLOW.md`](WORKFLOW.md), y
las mecánicas de orquestación en [`references/orchestration-patterns.md`](references/orchestration-patterns.md).

## Tiering de modelos

| Tier | Modelo | Para qué |
|------|--------|----------|
| Barato | `haiku` | Ejecutar planes ya especificados, boilerplate, docs |
| Medio | `sonnet` | Implementar planes con lógica no trivial |
| Caro | `opus` | Planear, especificar, revisar, decidir |

El juicio va al caro; la ejecución de planes ya escritos, al barato. Nunca al revés.

## Instalación

Clona dentro de tu carpeta de skills de Claude Code:

```bash
git clone https://github.com/l3vram/flow-dev-company.git ~/.claude/skills/flow-dev-company
```

Reinicia la sesión de Claude Code (los skills se cargan al iniciar). Luego:

```
/flow-dev-company quiero desarrollar un chatbot
```

O invócalo vacío y te preguntará qué construir.

## Estructura

```
flow-dev-company/
  SKILL.md                              # el orquestador
  WORKFLOW.md                           # el proceso conceptual (fases, paralelo vs barrier)
  references/
    advisor.md                          # el cerebro: planear + revisar (+ modo greenfield)
    audit-playbook.md                   # categorías de auditoría (repos existentes)
    plan-template.md                    # formato de plan autocontenido
    closing-the-loop.md                 # execute / review / reconcile
    orchestration-patterns.md           # olas, roster de agentes, estado, gates en capas
```

## Créditos

- El cerebro asesor empacado (`references/advisor.md`, `audit-playbook.md`, `plan-template.md`,
  `closing-the-loop.md`) deriva del skill **`improve`** de **[shadcn](https://github.com/shadcn)**,
  licencia MIT. Se adaptó añadiéndole un **modo greenfield** para proyectos desde cero.
- Los patrones de orquestación (`orchestration-patterns.md`) destilan ideas de proyectos
  similares: [aaddrick/claude-pipeline](https://github.com/aaddrick/claude-pipeline)
  (estado JSON + gates en capas), [barkain/claude-code-workflow-orchestration](https://github.com/barkain/claude-code-workflow-orchestration)
  (wave scheduling + roster de agentes), y la arquitectura Planner→Executor→Reviewer común en
  AgentMesh / CrewAI / AutoGen.

## Licencia

MIT — ver [`LICENSE`](LICENSE). Incluye porciones MIT de terceros (ver Créditos).
