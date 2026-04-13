# Security Policy

## Reporting a vulnerability

If you believe you've found a security vulnerability in this project, please **do not** open a public issue. Report it privately so a fix can be prepared before the details are public.

- **Private report:** open a confidential issue on the GitLab repository (`Issues → New issue → Confidential`).
- **Expected response time:** the maintainer aims to acknowledge within 72 hours.

Please include:

- A description of the issue and its impact.
- Steps to reproduce, proof-of-concept code, or a minimal failing test.
- The affected version / commit SHA.
- Your preferred contact method for follow-up.

## Scope

This repository is a boilerplate. Issues that qualify as in-scope:

- Vulnerabilities in the code as shipped (`apps/`, `libs/`, `scripts/`, infra configs).
- Insecure defaults that would affect every fork (e.g. permissive CORS, missing validation, leaked secrets).
- Dependency CVEs that directly affect the production runtime — not dev-only transitive deps (see `CHANGELOG.md` for the current known-dev-only list).

Out of scope:

- Vulnerabilities in forks that added their own authentication, ORMs, or business logic.
- Issues requiring a malicious local environment or physical access.

## Supported versions

The boilerplate is pre-1.0. Only the latest tagged release on `main` receives security fixes.
