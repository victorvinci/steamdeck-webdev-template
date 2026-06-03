# syntax=docker/dockerfile:1
#
# Production image for the Express backend.
#
# Build from the repo ROOT (the build needs the whole workspace + the root
# lockfile), pointing Docker at this file:
#
#   docker build -f apps/backend/Dockerfile -t steamdeck-backend .
#   docker run --rm -p 3000:3000 --env-file .env steamdeck-backend
#
# Two stages: `build` compiles the backend with Nx; `runtime` ships only the
# compiled output plus production dependencies on a slim, non-root base.
#
# The base image is pinned by digest (the tag is kept alongside for Renovate's
# Docker manager, the same policy as .github/docker/playwright-e2e.Dockerfile)
# so builds are reproducible and OpenSSF Scorecard's Pinned-Dependencies check
# stays satisfied.

# ---- build stage ----
FROM node:24-bookworm-slim@sha256:242549cd46785b480c832479a730f4f2a20865d61ea2e404fdb2a5c3d3b73ecf AS build
WORKDIR /workspace

# Run Nx without Nx Cloud — there's no token in the build and we want the
# image build to be hermetic and offline-friendly.
ENV NX_NO_CLOUD=true

# Install the full workspace (dev deps included — they're needed to build).
# `--legacy-peer-deps` matches the repo's install policy: Nx's internal
# exact-pinned peers are incompatible with npm's strict resolver (see
# docs/TROUBLESHOOTING.md). Copy the manifests first so this layer caches
# across source-only changes.
COPY package.json package-lock.json ./
RUN npm ci --legacy-peer-deps

COPY . .

# `bundle: false` + `generatePackageJson: true` (apps/backend/project.json)
# emit a self-contained tree at dist/apps/backend: main.js, the compiled
# apps/ + libs/ (workspace libs are compiled in, not bundled), and a pruned
# package.json / package-lock.json listing only the runtime dependencies.
RUN npx nx build backend --configuration=production

# ---- runtime stage ----
FROM node:24-bookworm-slim@sha256:242549cd46785b480c832479a730f4f2a20865d61ea2e404fdb2a5c3d3b73ecf AS runtime
ENV NODE_ENV=production
# env.HOST defaults to `localhost`, which is unreachable from outside a
# container. Bind all interfaces — exposure is governed by the container /
# orchestrator network policy, not by the process bind address.
ENV HOST=0.0.0.0
ENV PORT=3000
WORKDIR /app

# Install ONLY production dependencies, from the pruned manifest the build
# generated — this is the whole point of generatePackageJson. Done before
# copying the app so it caches independently of source changes.
COPY --from=build /workspace/dist/apps/backend/package.json /workspace/dist/apps/backend/package-lock.json ./
RUN npm ci --omit=dev --legacy-peer-deps && npm cache clean --force

# Compiled application tree (main.js + apps/ + libs/). Contains no
# node_modules, so it doesn't clobber the layer installed above.
COPY --from=build /workspace/dist/apps/backend ./

# Run unprivileged. The official node images ship a non-root `node` user.
USER node

EXPOSE 3000

# Container healthcheck → the liveness probe (no DB dependency, matching the
# orchestrator guidance in README → Production Deployment). Uses Node's
# built-in global fetch so the image needs no curl/wget.
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||3000)+'/api/health/live').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node", "main.js"]
