# Frontend Dockerfile - Multi-stage build with pnpm
# Stage 1: Build the React app
FROM node:20-alpine AS builder

WORKDIR /app

# Enable pnpm via corepack (matches packageManager field in package.json)
RUN corepack enable

# Copy package files
COPY frontend/package.json frontend/pnpm-lock.yaml* ./

# Install dependencies with pnpm (fast, disk-efficient)
# --frozen-lockfile requires pnpm-lock.yaml; falls back if missing on first build
RUN pnpm install --frozen-lockfile || pnpm install

# Copy source and build
COPY frontend/ .
RUN pnpm run build

# Stage 2: Serve with nginx
FROM nginx:alpine

# Copy built assets
COPY --from=builder /app/build /usr/share/nginx/html

# Copy nginx config
COPY frontend/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]