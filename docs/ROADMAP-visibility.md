# Roadmap — visibility & adoption (PENDING, not started)

Status as of 2026-10-13: repo has 1 star. The skill's quality is not the bottleneck;
discoverability and first-10-seconds onboarding are. Nothing below is done yet.

## Diagnosis

1. No one-step install — only `git clone`, while comparable projects (ponytail,
   addyosmani/agent-skills, graphify) install via `/plugin marketplace add`.
2. No visible proof — no GIF/demo, no real-world run with numbers.
3. Repo description is in Spanish and has no topics → invisible in GitHub search.
4. Coupled to the author's setup (Basic Memory mentions, `jq` requirement) — friction for
   new users.
5. README explains everything but does not hook in the first screen.

## Plan, in order of impact

1. **Plugin packaging.** Add `.claude-plugin/marketplace.json` (+ `plugin.json`) so
   `/plugin marketplace add l3vram/flow-dev-company` works. Keep the `git clone` path working.
   Verify the current plugin layout spec (skills dir location) before moving any file.
2. **GitHub metadata.** English description; topics: `claude-code`, `claude-skills`,
   `agent-skills`, `multi-agent`, `orchestration`, `ai-coding`.
3. **Real case study with numbers.** Run the skill end to end on a real target (candidate:
   the Android app goal, or a flow-harness feature). Capture a GIF of `flow.sh panel` across
   waves and a table: objective → plans → waves → tokens (`flow.sh report`) → outcome.
   Needs the maintainer present — do together.
4. **README hook.** First screen: one sentence, GIF, install command. Details below the fold.
   Make Basic Memory explicitly optional.
5. **Distribution.** PR to awesome-claude-code; list on claudemarketplaces.com / skillsmp;
   post on r/ClaudeAI and Show HN with the case study. No inflated numbers.
6. **Releases.** Tag v1.0.0 with a CHANGELOG so users trust it is maintained.

## Done so far (verified)

- Executor rules: minimal code (from ponytail), test-first for fixes and source-driven API
  use (from agent-skills). Size-compliance review. Optional graphify map in recon.
  `scripts/test-flow.sh`: 46/46 pass.
