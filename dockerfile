# syntax=docker/dockerfile:1.7

# --- builder: compila el monorepo con turborepo en glibc ---
FROM node:22.18-bookworm-slim AS builder
WORKDIR /app

# deps del SO mínimas
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates openssl && rm -rf /var/lib/apt/lists/*

# pnpm 10 fijo
RUN corepack enable && corepack prepare pnpm@10.18.3 --activate

# copiamos TODO (simple; luego optimizamos)
COPY . .

# install RECURSIVO del workspace, sin modo prod y con optional deps (rolldown)
RUN --mount=type=cache,target=/root/.local/share/pnpm/store \
    PNPM_CONFIG_FROZEN_LOCKFILE=true NODE_ENV=development npm_config_production=false \
    pnpm -r install --include=optional

# build del monorepo
RUN npx turbo run build --cache-dir=.turbo

# --- runner: runtime liviano ---
FROM node:22.18-bookworm-slim AS runner
WORKDIR /app

RUN corepack enable && corepack prepare pnpm@10.18.3 --activate
ENV NODE_ENV=production

# trae artefactos ya construidos
COPY --from=builder /app ./

# (opcional) quitar dev deps de los paquetes para el runtime
RUN pnpm -r prune --prod || true

EXPOSE 5678
CMD ["pnpm","--filter","n8n","start"]
