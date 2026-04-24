# Security Audit — v1.0.0 Actions Taken

**Date:** 2026-04-21
**Branch:** `chore/v1.0.0-prep`
**Remediated by:** Claude Opus 4.7 (automated, human-directed)
**Original audit:** [`docs/SECURITY-AUDIT-v1.0.0.md`](./SECURITY-AUDIT-v1.0.0.md)

## Summary

All 10 findings from the v1.0.0 pre-release security audit have been remediated. Three tranches in order of severity:

| ID  | Severity      | Area                                           | Status    |
| --- | ------------- | ---------------------------------------------- | --------- |
| M1  | Medium        | Shared MySQL app/root password                 | **Fixed** |
| M2  | Medium        | MySQL port bound on all interfaces             | **Fixed** |
| L1  | Low           | Awk regex interpolation in CHANGELOG extractor | **Fixed** |
| L2  | Low           | SQL-HEREDOC password interpolation             | **Fixed** |
| L3  | Low           | `validate.ts` mutates `req.*`                  | **Fixed** |
| L4  | Low           | Unvalidated client `x-request-id`              | **Fixed** |
| L5  | Low           | Unpinned `renovate` in CI                      | **Fixed** |
| I1  | Informational | `pull_request_target` foot-gun banner          | **Added** |
| I2  | Informational | `trust proxy` deployment topology docs         | **Added** |
| I3  | Informational | JSONL validity guard in CI                     | **Added** |

## Where to read the details

Per-finding file:line changes, rationale, and before/after behaviour are in [`CHANGELOG.md`](../CHANGELOG.md) under the `[Unreleased] → Security` section — one bullet per finding. The provenance log has three matching entries (`security-audit-m1-m2`, `security-audit-low-findings`, `security-audit-info-findings`) in [`.ai-attribution.jsonl`](../.ai-attribution.jsonl).

## Verification

- `npm run typecheck` — clean
- `npm run lint` — clean
- `npm run test:be` — clean
- `npm audit` — 0 vulnerabilities (re-confirmed post-remediation)
- YAML workflows re-parsed; shell scripts re-checked with `bash -n`

## What's next

The audit is closed from the findings side. Tagging v1.0.0 can proceed per [`docs/RELEASE.md`](./RELEASE.md). If a future change reopens one of these surfaces (e.g. a new workflow that uses `pull_request_target`, a new route that reads `req.body` directly), re-open the corresponding finding in a fresh audit rather than editing this file — this document is a point-in-time record.
