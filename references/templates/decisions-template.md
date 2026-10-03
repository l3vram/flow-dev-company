# Decisions Template — decisions.md

Use this template for `tasks/TASK-<number>/decisions.md`. Required for Tier 3 tasks only.

Decisions are frozen once recorded. If a decision changes, create a new entry that supersedes the prior one. This preserves the reasoning chain.

---

```markdown
# Decisions — TASK-<number>

## DEC-<number>-01 — <decision title>

**Status**: ACCEPTED

### Decision

<What was decided, stated clearly and briefly.>

Example: "Use HS256 with server-side secret for JWT signing, not RS256."

### Context

<Why a decision was needed.>

Example: "RS256 requires key rotation infrastructure we don't have. HS256 is simpler and sufficient for our use case."

### Alternatives considered

1. RS256 with key rotation
2. HS256 with client-side secret (shared)
3. OAuth2 with external provider

### Rationale

<Short factual reasoning. 2–3 sentences.>

Example: "HS256 requires only one secret stored on the server. Key rotation is manual but infrequent. RS256 adds operational overhead without benefit for our scale."

### Consequences

- JWT signing happens server-side only
- Token validation requires the server secret
- Secret rotation requires downtime or cache invalidation
- Cannot delegate token validation to a separate microservice

### Evidence

- Issue: <URL or none>
- Commit: `<sha>` or `<sha range>`
- File: `path/to/file:line`
- ADR or decision doc: <URL or path>

---

## DEC-<number>-02 — <decision title>

**Status**: ACCEPTED (supersedes DEC-<number>-01)

### Decision

<New decision that overrides the prior one.>

Example: "Switch to RS256 with automated key rotation via HashiCorp Vault."

### Context

<Why the prior decision no longer holds.>

Example: "We now have Vault deployed in production. Key rotation is automated. The operational overhead is zero. RS256 is now the better choice because it allows stateless token validation."

### Alternatives considered

1. Keep HS256 as is
2. Switch to RS256 with Vault
3. Switch to OAuth2

### Rationale

<Reasoning for this new decision.>

Example: "Vault removes the operational friction. RS256 with automated rotation is now preferred because microservices can validate tokens without the server secret."

### Consequences

- Token validation can happen offline or in separate services
- Public key is published; private key is in Vault only
- Key rotation is transparent to applications
- Dependency on Vault availability

### Evidence

- Issue: <URL>
- Commit: `<sha>`
- File: `path/to/file`

---

## (No more decisions)
```

---

## Notes

- Decisions are immutable once recorded.
- If a decision is wrong, do not edit it; create a new decision that supersedes it.
- This preserves the reasoning chain: future maintainers can see why a decision was made and why it changed.
- Keep decisions short but complete: 1 page per decision max.
- Reference commit SHAs and file paths for evidence.
- Use the "supersedes" pattern when decisions change to keep the audit trail.
