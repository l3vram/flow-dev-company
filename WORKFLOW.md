# End-to-End Software Workflow con Agentes

> Un workflow de punta a punta para construir software usando agentes como trabajadores.
> Columna vertebral **secuencial** con **islas de paralelismo** e **islas humanas (gates)**.
>
> Idea rectora (adaptada del roadmap de grafos): _un nodo es juicio, una arista es plomería._
> Paraleliza donde el trabajo es independiente. Pon gates donde la confianza importa.
> **Pero:** el software tiene estado compartido y dependencias duras — no todo se puede fanear.

---

## Los 3 tipos de "cosa" en este workflow

| Tipo | Qué es | Quién lo hace | Cuesta tokens |
|------|--------|---------------|---------------|
| **Nodo-juicio** | Decidir, diseñar, revisar, sintetizar | Un agente | Sí |
| **Nodo-verificación** | Correr tests / build / lint / typecheck | Código (comando) | No (o casi) |
| **Arista** | Pasar/transformar datos entre nodos (flatten, dedupe, filtrar) | Código JS | No |
| **Gate humano** | Aprobar antes de continuar | Tú | — |

Regla que ahorra dinero: **si "combinar resultados" es `flatMap` + `Set`, es una arista, no un agente.**

---

## La columna vertebral (fases)

```
0. Intake ──▶ 1. Discovery ──▶ 2. Plan ──▶ [GATE A] ──▶ 3. Decompose
                (paralelo)      (síntesis)   humano      (arista/juicio)
                                                              │
                                                              ▼
   8. Handoff ◀── [GATE B] ◀── 7. Integrate ◀── 6. Review ◀── 5. Verify ◀── 4. Build
      (síntesis)   humano       (barrier)       (paralelo)     (código)      (paralelo,
                                                +adversarial                  worktrees)
```

Nota clave: las fases **4–6 forman un ciclo** por unidad de trabajo (build → verify → review → volver a build si falla). Es el único ciclo, y **converge** con un tope de iteraciones.

---

### Fase 0 — Intake / Scoping
- **Nodo:** 1 agente (o tú).
- **Salida (contrato):** objetivo, restricciones, criterios de "hecho", stack, no-goals.
- **Por qué importa:** todo lo demás hereda ambigüedad de aquí. No la paralelices.

### Fase 1 — Discovery (PARALELO — fan-out)
Corre en paralelo porque son lecturas independientes del mundo:
- Explorar el codebase existente (estructura, convenciones, puntos de extensión).
- Prior art / dependencias / APIs relevantes.
- Restricciones (tests actuales, CI, estándares de seguridad).
- **Cada agente devuelve JSON validado** (schema), no texto libre.
- **Arista:** dedupe + merge de hallazgos → contexto único. Código, cero tokens.
- Modelo: **tier barato** (es extracción, no juicio).

### Fase 2 — Plan / Arquitectura (SÍNTESIS — barrier)
- **Nodo:** 1 agente potente (tier caro). Necesita _todo_ el discovery junto → barrier legítimo.
- **Salida:** plan por fases, decomposición en unidades de trabajo *independientes*, contratos entre módulos, estrategia de test.
- Aquí es donde decides qué se podrá paralelizar en la Fase 4.

### 🚦 GATE A — Aprobación de plan (HUMANO)
- **No sigas sin esto.** El error más caro es fanear 20 agentes sobre un plan malo.
- Tú apruebas: arquitectura, alcance, criterios de aceptación.
- Este gate **no vive en el script** — vive en el proceso. El script arranca *después*.

### Fase 3 — Decompose (ARISTA + juicio ligero)
- Convertir el plan en N unidades de trabajo con **contrato explícito**: qué lee, qué produce, qué test la valida.
- Marcar dependencias reales entre unidades (¿la unidad B lee la salida de A? entonces hay arista → no van en el mismo batch paralelo).
- Resultado: un DAG de tareas. Las que no tienen arista entre sí → mismo `parallel()`.

### Fase 4 — Build / Implementación (PARALELO + AISLAMIENTO)
- **Fan-out:** un agente por unidad independiente.
- **Aislamiento obligatorio si escriben en paralelo:** `isolation: "worktree"` — cada agente en su propio git worktree, mergea limpio. Es el cinturón para la única topología que lo necesita.
- Un thunk que falla → `null`, no tumba el batch. `.filter(Boolean)`.
- Modelo: tier medio/alto según complejidad de la unidad.

### Fase 5 — Verify (CÓDIGO — gate determinista)
- **No es un agente.** Corre: `build`, `typecheck`, `lint`, `test` sobre cada unidad.
- Es un **gate que bloquea**: unidad que no pasa → vuelve a Fase 4 (ciclo).
- Determinista = reproducible = confiable. Esta es la mitad de la calidad, gratis en tokens.

### Fase 6 — Review (PARALELO — lentes diversas + adversarial)
- Por cada unidad (o por el diff agregado), fan-out de revisores con **lentes distintas**:
  - correctness · security · performance · legibilidad/mantenibilidad.
- **Verificador adversarial:** cada hallazgo se intenta refutar antes de contar. Si sobrevive, cuenta.
- Router opcional: diff pequeño → 1 pase rápido; diff grande → auditoría paralela completa.
- Modelo: tier alto (esto es juicio puro).

### Fase 7 — Integrate (BARRIER)
- Merge de worktrees, resolución de conflictos, correr la **suite completa** una vez integrada.
- Barrier real: necesitas *todas* las unidades juntas para probar el sistema.

### 🚦 GATE B — Revisión final (HUMANO)
- Tú revisas: ¿cumple los criterios de la Fase 0? ¿algún hallazgo de seguridad abierto?
- Decisión: merge / iterar / descartar.

### Fase 8 — Handoff (SÍNTESIS)
- 1 agente: changelog, docs, notas de PR, resumen de decisiones.
- Guardar el workflow si funcionó (`.claude/workflows/`) para re-correrlo por nombre.

---

## Dónde va el ciclo (y cómo converge)

El ciclo es **build → verify → review → build** por unidad. Converge con:
- **Tope duro de iteraciones** por unidad (p. ej. 3). Al agotarse → escalar a gate humano, no seguir quemando.
- Dedupe de hallazgos **contra todo lo visto**, no solo contra lo confirmado (si no, los rechazados reaparecen cada ronda y el loop nunca se seca).

---

## Tabla de decisión: ¿paralelo o barrier?

| Fase | Modo | Razón |
|------|------|-------|
| Discovery | `parallel` | Lecturas independientes |
| Plan | barrier | Necesita todo el discovery |
| Build | `parallel` + worktree | Unidades independientes que escriben |
| Verify | por-unidad (código) | Gate determinista |
| Review | `parallel` | Lentes independientes |
| Integrate | barrier | Necesita el sistema completo |

**Default del texto original era `pipeline()`. Aquí NO** — el software tiene demasiadas dependencias duras y gates. Usa barrier cuando una fase de verdad necesita el set completo (Plan, Integrate). Paraleliza *dentro* de fases, no *entre* fases con dependencia.

---

## Tiers de modelo (la palanca de costo)

- **Barato:** discovery/extracción, clasificación, formateo de docs.
- **Medio:** implementación de unidades acotadas.
- **Caro:** Plan/arquitectura, Review adversarial, síntesis final.
- Revisa `/model` antes de una corrida grande. El `model` por-`agent()` enruta solo ese nodo.

---

## Esqueleto de orquestación (islas de paralelismo)

> El script orquesta **una fase paralela a la vez**. Los gates humanos (A, B) ocurren
> ENTRE corridas del script, no dentro. Arranca el script después de aprobar el plan.

```js
// ─── Contratos (schemas) ────────────────────────────────────────────────
const UNIT_RESULT = {
  type: 'object', additionalProperties: false,
  properties: {
    unit:   { type: 'string' },
    files:  { type: 'array', items: { type: 'string' } },
    status: { type: 'string', enum: ['done', 'blocked'] },
    notes:  { type: 'string' },
  },
  required: ['unit', 'status'],
};

const FINDING = {
  type: 'object', additionalProperties: false,
  properties: {
    unit:     { type: 'string' },
    lens:     { type: 'string', enum: ['correctness','security','perf','maintainability'] },
    severity: { type: 'string', enum: ['high','medium','low'] },
    claim:    { type: 'string' },
  },
  required: ['unit','lens','severity','claim'],
};

// ─── Fase 4: BUILD (fan-out con worktrees) ──────────────────────────────
phase('Build');
const built = (await parallel(
  UNITS.map((u) => () =>
    agent(u.prompt, {
      label: `build:${u.name}`,
      phase: 'Build',
      schema: UNIT_RESULT,
      agentType: 'general-purpose',
      isolation: 'worktree',     // aislar: escriben en paralelo
      // model: 'claude-sonnet-5', // tier medio para unidades acotadas
    }),
  ),
)).filter(Boolean);              // los que fallaron caen como null

// ─── Fase 5: VERIFY (código, gate determinista — NO agente) ─────────────
phase('Verify');
const verified = [];
for (const u of built) {
  const ok = await runChecks(u.unit);   // build + typecheck + lint + test
  if (ok) verified.push(u);
  else log(`FAIL verify: ${u.unit} → re-encolar a Build (máx 3 iter)`);
}

// ─── Fase 6: REVIEW (fan-out de lentes + verify adversarial) ────────────
phase('Review');
const LENSES = ['correctness','security','perf','maintainability'];
const findings = (await parallel(
  verified.flatMap((u) =>
    LENSES.map((lens) => () =>
      agent(`Revisa la unidad ${u.unit} bajo la lente ${lens}. Diff:\n${diffOf(u)}`, {
        label: `review:${u.unit}:${lens}`,
        phase: 'Review',
        schema: { type: 'object', properties: { findings: { type: 'array', items: FINDING } },
                  required: ['findings'] },
        // model: 'claude-opus-4-8', // tier caro: esto es juicio
      }),
    ),
  ),
)).filter(Boolean).flatMap((r) => r.findings);   // ← arista: flatten, cero tokens

// Verify adversarial: intenta refutar cada hallazgo antes de que cuente.
const confirmed = (await parallel(
  findings.map((f) => () =>
    parallel([1,2,3].map(() => () =>
      agent(`Intenta REFUTAR este hallazgo. ¿Es real? "${f.claim}"`, {
        schema: { type: 'object', properties: { real: { type: 'boolean' } }, required: ['real'] },
      }),
    )).then((votes) => ({
      f,
      survives: votes.filter(Boolean).filter((v) => v.real).length >= 2, // mayoría
    })),
  ),
)).filter((r) => r.survives).map((r) => r.f);

// ─── Fase 7: INTEGRATE (barrier) ────────────────────────────────────────
phase('Integrate');
log(`Unidades ok: ${verified.length} · hallazgos confirmados: ${confirmed.length}`);
// merge de worktrees + suite completa → luego GATE B humano.
```

---

## Cómo lo disparas en la práctica

1. **Fases 0–2 conversacionales** contigo (o con `EnterPlanMode` para el plan). Aterrizan en un plan escrito.
2. **GATE A:** apruebas el plan.
3. Le dices a Claude: _"corre un **workflow** que ejecute las Fases 4–7 de WORKFLOW.md sobre estas unidades"_. La palabra **workflow** hace que Claude escriba el script de orquestación y lo lance en background.
4. Tú sigues trabajando mientras la flota corre; los gates de verify son deterministas.
5. **GATE B:** revisas el resultado integrado.
6. Fase 8: docs + guardar el workflow (`s` para persistirlo en `.claude/workflows/`).

---

## Diferencias clave vs. el texto original (por qué las hice)

1. **No default a `pipeline()`.** Software = dependencias duras. Barrier entre fases con dependencia real (Plan, Integrate); paralelismo *dentro* de cada fase.
2. **Gates humanos explícitos (A, B).** El texto asumía tareas stateless sin checkpoints. Tú los pediste; van en el proceso, no en el script.
3. **Verify determinista como gate que bloquea.** El texto habla de verificadores-agente; en software, la mitad de la calidad es `test`/`build`/`lint` — código, no modelo. Más barato y más confiable.
4. **Ciclo build↔verify acotado.** Con tope de iteraciones para que converja en vez de quemar presupuesto.
5. **Aislamiento solo en Build.** Worktrees donde de verdad hay escritura paralela, no como impuesto global.
```
