# Frontend Dockerfile - Multi-stage build with pnpm
# Stage 1: Build the React app
FROM node:24-alpine AS builder

WORKDIR /app/frontend

# Enable pnpm via corepack (matches packageManager field in package.json)
RUN corepack enable

# Copy workspace/lockfile/config first for better caching
COPY frontend/pnpm-workspace.yaml frontend/pnpm-lock.yaml frontend/.npmrc ./
COPY frontend/package.json ./

# Install dependencies with pnpm (fast, disk-efficient)
RUN pnpm install --frozen-lockfile

# Copy source and build
COPY frontend/ ./
RUN pnpm run build

# Stage 2: Serve with nginx
FROM nginx:alpine

# Copy built assets
COPY --from=builder /app/frontend/build /usr/share/nginx/html

# Copy nginx config
COPY frontend/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]