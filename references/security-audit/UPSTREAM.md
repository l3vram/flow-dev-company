# Vendored: Cloudflare `security-audit`

- **Source**: https://github.com/cloudflare/security-audit-skill, path `skills/security-audit/`
- **Commit**: `c1c8a8c1471069fb0e188eeaff69b8e8db6564a8` (2026-09-14, "Clarify guidance and full audit modes")
- **Vendored**: 2026-10-28
- **License**: MIT, Copyright (c) 2025-2026 Cloudflare, Inc. — see `LICENSE` in this directory.

Every file here except this one and `LICENSE` is byte-identical to upstream. **Do not edit
them.** flow-dev-company's adaptation — when to use the methodology, at what cost, and how its
output becomes plans — lives in `../security.md`.

Bundled, not registered: the orchestrator reads these files; nothing invokes them through the
Skill tool. `SKILL.md` keeps its frontmatter only so the copy stays identical to upstream.

## Re-sync

```bash
git clone --depth 1 https://github.com/cloudflare/security-audit-skill /tmp/sas
rsync -a --delete --exclude UPSTREAM.md --exclude LICENSE \
  /tmp/sas/skills/security-audit/ references/security-audit/
cp /tmp/sas/LICENSE references/security-audit/LICENSE
node references/security-audit/validate-findings.test.cjs
node references/security-audit/validate-coverage-ledger.test.cjs
scripts/test-flow.sh   # its security-audit section checks the headings security.md points at
```

Then update the commit above, and fix `../security.md` if `test-flow.sh` reports a moved heading.
