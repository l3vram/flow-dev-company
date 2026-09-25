# Token Budget — where the money actually goes

**Estimated** distribution for a typical fleet run — a design heuristic, not a measurement.
Replace it with your own ledger (`flow.sh report`) once you have real runs. The ordering is
what matters: the skill text is the smallest line item, not the biggest.

| Cost center | Share | Lever |
|---|---|---|
| Reviewing diffs with the expensive tier | ~45% | Risk router (`review.md`) — most diffs never need opus |
| Executors exploring a cold repo in worktrees | ~25% | Inline recon facts in the plan; never make an executor rediscover the build command |
| Self-contained plans copied into every agent | ~15% | Accept this cost — do not compress plans |
| Verbose agent returns landing in orchestrator context | ~8% | Return contracts (`execution.md`) |
| This skill's own text | ~7% | Progressive disclosure — load one reference per phase |

## Language policy

The tokenizer taxes non-English text ~1.5x for identical meaning. Therefore:

- **English**: every file in this skill, every agent prompt, every plan, `plans/README.md`,
  `.flow/state.json`, commit messages, the fleet panel's labels.
- **The user's language**: only what the user reads directly — questions in the Enrich
  phase, gate prompts, status prose, the final report. Match whatever language they wrote in.

Never translate a plan into the user's language "so they can read it." Plans are executor
contracts. Summarize the plan for the user instead; the file stays English.

## Compression policy — narrow on purpose

The caveman technique cuts **output tokens only**; input and reasoning are untouched.
Independent benchmarks measure 8.5–21% on real coding tasks, not the 65–75% advertised.
The full published skill costs ~1–1.5k input tokens per turn, which in a fleet of N agents
loses money. So: use the 85-token micro-directive, and only where it is safe.

**Inject into**: executor preambles, reviewer preambles, agent-to-agent reports.
**Never inject into**: plan files, code, commands, error text, diffs, or anything the
user reads. Ambiguity in a plan costs a failed execution — far more than the tokens saved.

```
Respond like smart caveman. Cut all filler, keep technical substance.
Drop articles (a, an, the), filler (just, really, basically, actually).
Drop pleasantries (sure, certainly, happy to).
No hedging. Fragments fine. Short synonyms.
Technical terms stay exact. Code blocks unchanged.
Pattern: [thing] [action] [reason]. [next step].
```

Most of the available saving comes from *asking* tightly, not from how the model talks.
A strict return contract beats any speech style.

## Tier assignment

| Work | Tier | Why |
|---|---|---|
| Planning, specifying, adjudicating findings | `opus` | Judgment compounds; a bad plan costs more than it saves |
| High-risk diff review (see `review.md` router) | `opus` | The cases where being wrong is expensive |
| Non-trivial implementation, routine review layers | `sonnet` | Most execution lives here |
| Boilerplate, docs, config, formatting, changelog | `haiku` | Specified work with no judgment left in it |

Never invert this. An expensive model executing a written plan is pure waste; a cheap model
writing the plan poisons everything downstream.

## Batching

Every agent spawn carries a fixed overhead of ~1–2k tokens (role + rules + plan preamble).
A plan whose whole content is "add three config keys" does not deserve its own spawn.

- Group trivial same-role plans (docs, config, boilerplate) into **one** `haiku` agent with
  a multi-plan prompt, as long as they share a wave and touch disjoint files.
- Keep separate spawns when plans touch overlapping files, differ in role, or carry real risk.
- A batched agent still creates one branch per plan (`flow/<run>/<id>`) so each is reviewed
  and integrated on its own.
- Ceiling: 4 plans per batched agent. Beyond that the prompt itself gets expensive and the
  agent starts losing track of which plan it is on.

## Prompt cache discipline

The session caches prompt prefixes. Structure every dispatched prompt so the stable part
comes first, byte-identical across agents of the same role:

```
[STABLE PREFIX — byte-identical per role]   role, scope rules, anti-patterns,
                                            caveman micro-directive, return contract
[VARIABLE SUFFIX]                           the plan text, worktree path, wave context
```

Do not hand-write per-agent preambles. Build the prefix from the role table in
`execution.md` verbatim, so a wave of three `backend-dev` agents shares one cached prefix.
Reordering these blocks for readability defeats the cache — keep the order.

## The ledger

`.flow/state.json` carries a `budget` block. Update it as agents report; render it at Gate B.

```json
"budget": {
  "by_phase":  { "plan": 42000, "execute": 310000, "review": 96000 },
  "by_tier":   { "opus": 138000, "sonnet": 240000, "haiku": 70000 },
  "by_plan":   { "001": 22000, "002": 61000 },
  "spawns": 7,
  "inline": 3,
  "notes": "003 retried twice — 40k of the execute total"
}
```

Token counts come from what the harness reports per agent; when a number is unavailable,
record `null` (`flow.sh budget <id> null …`) — the entry is listed as unreported, never
estimated.

Every line has a kind: `spawn` (default — a dispatched agent) or `inline` (work you did in
your own context, such as reviewing a diff yourself). Pass `inline` for your own work;
otherwise the agent count at Gate B is inflated and the next batching decision is made on
a wrong number.

```
flow.sh budget 156 119530 sonnet execute          # the executor agent
flow.sh budget 156 null   opus   review  inline   # your own review of its diff
``` A guessed ledger is worse than no ledger — it makes
the next optimization decision on fiction. Report actuals at Gate B, flag any plan that
consumed disproportionately, and say plainly which figures were unavailable.
