# syntax=docker/dockerfile:1
#
# Playwright image pre-baked with mysql-client + lsof for our e2e runs.
# The base Playwright image doesn't ship either; without this layer the
# e2e job would spend ~30s per run on `apt-get install`. Building it once
# per Playwright version into GHCR pushes that cost to publish-time.
#
# Consumers: the `playwright-image` job in `.github/workflows/ci.yml`
# builds and pushes this to `ghcr.io/<owner>/playwright-e2e:<tag>-mysql`
# on every CI run (the GHA cache keeps it near-free when unchanged), and
# the `e2e` job consumes the resulting tag.
#
# Version bumps: Renovate's built-in Docker manager watches the FROM
# line, so the Playwright image bumps automatically. The `-mysql` tag
# suffix is appended by the publish job, not by Renovate.
FROM mcr.microsoft.com/playwright:v1.59.1-jammy

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        default-mysql-client \
        lsof \
    && rm -rf /var/lib/apt/lists/*
