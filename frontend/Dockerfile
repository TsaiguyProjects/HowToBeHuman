# Frontend Dockerfile - Multi-stage build with pnpm
# Stage 1: Build the React app
FROM node:24-alpine AS builder

WORKDIR /app

# Enable pnpm via corepack (matches packageManager field in package.json)
RUN corepack enable

# Copy workspace files first for better caching
# (pnpm lockfile lives at the repo root via pnpm-workspace.yaml)
COPY pnpm-workspace.yaml pnpm-lock.yaml ./
COPY frontend/package.json ./frontend/package.json

# Install dependencies with pnpm (fast, disk-efficient)
RUN pnpm install --frozen-lockfile

# Copy source and build
COPY frontend/ ./frontend/
RUN pnpm --filter frontend run build

# Stage 2: Serve with nginx
FROM nginx:alpine

# Copy built assets
COPY --from=builder /app/frontend/build /usr/share/nginx/html

# Copy nginx config
COPY frontend/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]