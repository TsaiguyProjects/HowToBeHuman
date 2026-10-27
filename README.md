# HowToBeHuman

A full-stack application with a Python Flask backend and React frontend, deployable to an OVHcloud VPS with Docker Compose. Published content is stored separately on the VPS.

> **Package managers:** this repo uses [`uv`](https://docs.astral.sh/uv/) for Python and [`pnpm`](https://pnpm.io/) for JavaScript. They are faster, disk-efficient drop-in replacements for `pip` and `npm`.
> Install them once: `pip install uv` (or `brew install uv`) and `corepack enable` (enables `pnpm`).

## Architecture

```
┌─────────────────┐     ┌─────────────────┐
│   Frontend      │     │   Backend       │
│   (React +      │────▶│   (Flask +      │
│    Vite +       │     │    Gunicorn)    │
│    Nginx)       │     │                 │
│   Port 80       │     │   Port 8080     │
└─────────────────┘     └─────────────────┘
         │                       │
         └───────────┬───────────┘
                     ▼
            ┌─────────────────┐
            │ OVHcloud VPS │
            │ Docker Compose │
            └─────────────────┘
```

## Project Structure

```
.
├── ovh/
│   └── terraform/            # Legacy MKS/MPR infrastructure definitions (not used by VPS deploy)
├── .github/
│   └── workflows/
│       └── ci-cd.yml         # GitHub Actions CI/CD pipeline (uv + pnpm)
├── backend/
│   ├── app.py                # Flask application factory
│   ├── pyproject.toml        # Python dependencies (uv) + tool config
│   ├── uv.lock               # Locked Python deps (generate with `uv lock`, commit it)
│   ├── .python-version       # Pinned Python version for uv
│   └── Dockerfile            # Backend container (uv-based)
├── frontend/
│   ├── src/                  # React + TypeScript source (TSX + SCSS)
│   ├── tests/
│   │   ├── unit/             # Vitest unit tests (fetch boundary stubbed)
│   │   └── e2e/              # Playwright specs (real browser, zero mocks)
│   ├── public/               # Static assets
│   ├── package.json          # Node dependencies (pnpm, packageManager pinned)
│   ├── tsconfig.json         # TypeScript project references (app + node)
│   ├── playwright.config.ts  # Playwright config (baseURL via E2E_BASE_URL)
│   ├── vite.config.ts        # Vite configuration (typed)
│   ├── nginx.conf            # Nginx reverse proxy config
│   └── Dockerfile            # Frontend container (pnpm multi-stage build)
├── pnpm-workspace.yaml       # pnpm workspace root
├── pnpm-lock.yaml            # Locked JS deps (generate with `pnpm install`, commit it)
├── .npmrc                    # pnpm settings (frozen lockfile, corepack)
├── scripts/
│   ├── dev.sh                # Development startup script
│   └── deploy.sh             # Deployment script
├── docker-compose.yml        # Local development
├── Makefile                  # DevOps command shortcuts (uv + pnpm)
├── .env.example              # Environment variables template
└── .gitignore
```

## Local Development

### Prerequisite: install uv + pnpm (once)

```bash
# Node 24.x recommended (matches CI and Docker dev images).
# If you use nvm: nvm install 24 && nvm use 24

# Python package manager (replaces pip/venv)
pip install uv
# or: brew install uv

# JavaScript package manager (replaces npm)
corepack enable   # enables pnpm via Node's built-in Corepack
# pnpm version is pinned in frontend/package.json (packageManager field)
```

### Option 1: Docker Compose (Recommended)

```bash
# Production-like containers
make dev
# Backend: http://localhost:8080
# Frontend (nginx): http://localhost:3000

# Hot-reload containers (code changes reflect instantly)
make dev-docker
# or: docker-compose --profile dev up --build backend-dev frontend-dev
# Backend dev: http://localhost:8080
# Frontend dev server: http://localhost:3000
```

### Option 2: Native Development (uv + pnpm, no Docker)

**Backend:**
```bash
cd backend
uv sync --all-groups   # creates .venv and installs all deps (fast, replaces pip install)
cp ../.env.example .env
uv run python app.py   # runs inside .venv (replaces source venv/bin/activate)
```

**Frontend:**
```bash
cd frontend
pnpm install           # replaces npm install (updates root pnpm-lock.yaml)
cp ../.env.example .env.local  # Vite uses .env.local
pnpm run dev           # replaces npm run dev
```

> **First run?** `cd backend && uv lock` generates `uv.lock`. `pnpm install` generates the root `pnpm-lock.yaml`. Commit both lockfiles — they guarantee reproducible builds in Docker, CI, and OVHcloud.

## Makefile Commands

The project includes a `Makefile` that consolidates common development and deployment tasks. Run `make help` to see all available commands.

### Quick Reference

| Command | Description |
|---------|-------------|
| `make install` | Install all dependencies (`uv sync` + `pnpm install`) |
| `make dev` | Start full dev environment with Docker Compose |
| `make dev-backend` | Start backend only (`uv run python app.py`) |
| `make dev-frontend` | Start frontend only with hot reload (`pnpm run dev`) |
| `make dev-docker` | Start hot-reload containers in Docker |
| `make build` | Build production Docker images |
| `make test` | Run all tests (`uv run pytest` + `pnpm test`) |
| `make test-backend-unit` | Backend unit tests only (no Docker needed) |
| `make test-e2e` | Backend e2e tests (testcontainers, needs Docker) |
| `make lint` | Run all linters (`uv run ruff` + `pnpm lint`) |
| `make format` | Format code (`uv run black` + `pnpm format`) |
| `make deploy` | Deploy to OVHcloud MKS |
| `make logs` | Follow app logs on OVHcloud |
| `make status` | Check app status |
| `make clean` | Remove build artifacts and containers |
| `make clean-all` | Deep clean (including node_modules, .venv) |
| `make reset` | Clean and reinstall everything |

### Development Workflow

```bash
# First time setup
make install

# Start developing (with hot reload for both)
make dev

# Or run services individually
make dev-backend      # Backend on :8080
make dev-frontend     # Frontend on :3000 (hot reload)

# Code quality
make lint             # Check for issues
make format           # Auto-fix formatting
make test             # Run tests
make type-check       # mypy + tsc
```

### Testing Workflow

```bash
make test             # Everything: backend (unit + e2e) + frontend unit
make test-backend-unit  # Backend unit tests only (fast, no Docker needed)
make test-e2e           # Backend e2e only (needs Docker, builds real images)
make test-frontend      # Frontend unit tests (Vitest + Testing Library)
make test-playwright    # Playwright e2e (boots Docker stack + real browser)
```

**Backend** (`backend/tests/`, pytest):
- `test_api.py` — unit tests against the real Flask app via test client.
  No mocks: API routes, SPA serving, and fallback logic run for real.
- `test_e2e.py` (`@pytest.mark.e2e`) — end-to-end tests with
  [testcontainers](https://testcontainers-python.readthedocs.io/): builds the
  actual `backend/Dockerfile` + `frontend/Dockerfile` images, runs them on a
  shared Docker network, and asserts over real HTTP (nginx → gunicorn
  proxying, SPA fallback, API routing). Zero mocks. Requires a Docker daemon;
  skipped automatically when one is unavailable (e.g. `pytest -m "not e2e"`).

**Frontend** (`frontend/tests/`, Vitest + Playwright):
- `tests/unit/` (Vitest + jsdom) — unit tests render real components; only the
  `fetch` network boundary is stubbed with canned responses.
- `tests/e2e/` (Playwright, Chromium) — true full end-to-end: a real browser
  drives the real production Docker stack (nginx + gunicorn), with zero mocks.
  Run via `make test-playwright`, which builds and boots the compose stack,
  waits for health, runs the specs, and tears the stack down. One-time setup:
  `cd frontend && pnpm exec playwright install chromium` (CI uses
  `--with-deps`). Point at any environment with
  `E2E_BASE_URL=https://your-env.example pnpm --filter frontend test:e2e`.
- Cross-service integration is additionally covered by the backend e2e suite,
  which serves the real built frontend bundle.

### Coverage Gates (100% enforced)

Both suites fail below 100% statements/lines/functions (and branches, frontend):

```bash
make test-backend-coverage   # pytest + pytest-cov (fail_under in pyproject.toml)
make test-frontend-coverage  # vitest --coverage (thresholds in vite.config.ts)
```

- Backend excludes only the `if __name__ == "__main__":` runner block.
- Frontend measures `src/**` (entry `main.tsx` included — tested, not excluded).
- New code must arrive with tests; CI runs both gates on every push/PR.

### Git Hooks

Versioned hooks live in `.githooks/` (installed via `make install-hooks`,
removed with `make uninstall-hooks`). They run only the suites affected by
your changes — backend-only commits skip frontend tests and vice versa.

| Hook | What runs (per changed stack) | Skips when |
|------|-------------------------------|------------|
| `pre-commit` | unit tests + coverage gate | docs-only commit |
| `pre-push` | coverage gate + **all** tests incl. e2e (testcontainers + Playwright) | docs-only push |

Scope rules: `backend/**` → backend suites; `frontend/**` (+ root
`pnpm-lock.yaml`, `pnpm-workspace.yaml`, `.npmrc`) → frontend suites; infra
(`Makefile`, `docker-compose.yml`, `ovh/`, `scripts/`, `.githooks/`,
`.github/`, `.dockerignore`) → everything.

Notes:
- Hooks call the same `make` targets as CI, so local and remote checks match.
- If a tool is missing (common with GUI git clients' minimal `PATH`), the
  hook fails with an install hint instead of a cryptic error.
- Bypass for a single run with `git commit --no-verify` / `git push --no-verify`.

### Deployment Workflow

```bash
# Build production images locally first
make build

# Deploy to OVHcloud
make deploy

# Monitor deployment
make logs             # Follow all logs
make logs-backend     # Backend only
make logs-frontend    # Frontend only
make status           # Check app status
```

### Maintenance

```bash
# Clean up Docker resources
make clean

# Nuclear option - remove everything and reinstall
make reset

# Check environment setup
make env-check
```

### CI/CD Integration

The Makefile includes targets used by GitHub Actions:

```bash
# These run in CI pipeline
make ci-install       # Install deps in CI
make ci-test          # Run tests in CI
make ci-lint          # Lint in CI
make ci-build         # Build images in CI
```

## Deployment to OVHcloud VPS (Docker Compose)

The production stack uses one VPS with a public Nginx frontend proxying API
requests to Flask. GitHub Actions tests the project, builds tagged images, copies
the images and Compose file to the VPS over SSH, then recreates the production
services. It never copies, replaces, or removes the external content directory.

### VPS setup (one-time)

1. Create an OVHcloud VPS with Docker Engine and the Docker Compose plugin. Configure the host firewall to allow SSH and web traffic (80/443); use SSH keys and a non-root deploy user that can run Docker.
2. Create the application and content directories with appropriate ownership. For a `deploy` user, run this once as an administrator on the VPS:

  ```bash
  sudo install -d -o deploy -g deploy /opt/how-to-be-human
  sudo install -d -o deploy -g deploy /srv/how-to-be-human/content
  ```

3. Create the content layout outside the application directory:

  ```text
  /srv/how-to-be-human/content/
  ├── 20261025T120000Z/
  │   ├── index.mmd
  │   └── essays/example.mmd
  └── 20261026T090000Z/
     ├── index.mmd
     └── essays/example.mmd
  ```

  Directory names must be valid UTC timestamps in `YYYYMMDDTHHMMSSZ` form.
  Upload to a staging directory whose name does not match the timestamp format
  (for example, `.staging-20261026T090000Z`), validate all files, then rename it
  to `20261026T090000Z` on the same filesystem. That final rename atomically
  publishes the complete version. The API automatically selects the newest
  timestamped directory; older versions stay addressable for rollback. Never
  overwrite a published version directory.
  The browser renderer supports standard Markdown and GitHub-Flavored Markdown.
  If source MultiMarkdown uses extensions beyond that syntax, compile it to
  `.md` during your content publishing step before promoting the version.
4. Ensure the deploy account can write to `/opt/how-to-be-human` and read the
  content directory. The content is mounted read-only into the backend; the
  frontend container does not receive the content mount.
5. Put the Flask secret in `/opt/how-to-be-human/.env` on the VPS, mode 600:

  ```dotenv
  SECRET_KEY=replace-with-a-long-random-secret
  CONTENT_DIR=/srv/how-to-be-human/content
  ```

  Generate the secret privately on the VPS. Do not store this file in GitHub.

### Manual deploy from a workstation

Option 1 — export variables in your shell:

```bash
export VPS_HOST=your-vps.example.net
export VPS_USER=deploy
# Optional overrides:
export VPS_APP_DIR=/opt/how-to-be-human
export CONTENT_DIR=/srv/how-to-be-human/content
make deploy
```

Option 2 — use a `.env.deploy` file (recommended, avoids re-exporting):

```bash
cp .env.deploy.example .env.deploy
# Edit .env.deploy with your values, then:
make deploy
make status
make logs
```

The Makefile automatically loads `.env.deploy` if it exists. The file is gitignored
(`.env.deploy`), so secrets stay local. See `.env.deploy.example` for the format.

The SSH identity defaults to `~/.ssh/id_ed25519`; override it with
`VPS_SSH_PRIVATE_KEY_FILE`. The script builds tagged Docker images locally,
transfers them and `docker-compose.prod.yml`, and runs `docker compose up` on
the VPS. It refuses to deploy if the external content directory is missing and
does not create, upload, or delete content. Invoke via `make deploy` (which
runs it with Bash) or `bash scripts/deploy.sh`.

### GitHub Actions deploy

Set repository Actions secrets and variables:

| Name | Type | Purpose |
|---|---|---|
| `VPS_HOST` | Secret | VPS host/IP |
| `VPS_USER` | Secret | SSH deployment account |
| `VPS_SSH_PRIVATE_KEY` | Secret | Private SSH key for that account |
| `VPS_KNOWN_HOSTS` | Secret | Pinned `known_hosts` entry; obtain and verify it out of band |
| `VPS_APP_DIR` | Variable (optional) | Defaults to `/opt/how-to-be-human` |
| `CONTENT_DIR` | Variable (optional) | Defaults to `/srv/how-to-be-human/content` |

On a push to `main` or `ovhcloud`, after tests and Playwright pass, Actions builds both Docker
images, transfers the version-tagged images and Compose file, then starts them.
The `.env` and versioned content directories on the VPS are untouched by deploys.

The backend discovers the highest valid timestamp directory when each content
request is made, so uploading a newer directory publishes it without rebuilding
or restarting the app. To roll content back, remove or move the newest directory
out of `CONTENT_DIR`; do not edit version directory names in place.

### Domain and TLS

Point the domain at the VPS public IP. Configure HTTPS with a reverse proxy/TLS
solution (for example, Caddy or Certbot-managed Nginx) before production use;
the Compose frontend currently publishes HTTP on port 80.

The checked-in `ovh/k8s/` manifests and `ovh/terraform/` definitions describe
the previous MKS + Managed Private Registry option. The VPS deploy workflow
does not apply those resources; don’t run `make infra-apply` for this setup.

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `SECRET_KEY` | Flask secret configured in the VPS application `.env` file | Yes (production) |
| `FLASK_ENV` | `production` or `development` | No |
| `DATABASE_URL` | PostgreSQL connection string (OVHcloud Managed Database) | If using DB |
| `VITE_API_URL` | Frontend API base URL | No (defaults to `/api`) |
| `VPS_HOST` / `VPS_USER` | SSH destination for production deploys | Deploy only |
| `CONTENT_DIR` | Absolute host path containing timestamped content versions | Deploy only |
| `TAG` | Image tag (default: git SHA) | No |
| `VPS_SSH_PRIVATE_KEY_FILE` | Local SSH identity for manual deployments | Deploy only |

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/health` | Health check |
| GET | `/api/hello` | Test endpoint |

## Adding a Database (OVHcloud Managed Database)

1. Create a PostgreSQL instance in the OVHcloud console (Public Cloud > Databases).
2. Configure secure network access from the VPS.
3. Store the connection string in the existing secret:
  `DATABASE_URL` in the VPS `/opt/how-to-be-human/.env` file, then restart
  the production Compose services.
4. Update `backend/app.py` to use SQLAlchemy/psycopg2.

## Scaling

- Resize the VPS plan in the OVHcloud Control Panel when more resources are needed.
- For multiple replicas or autoscaling, revisit the legacy Kubernetes setup in
  `ovh/`; the VPS Compose deployment currently runs one instance of each service.

## Monitoring

- **Logs:** `make logs[-backend|-frontend]` or OVHcloud console > Managed Kubernetes > Logs, or ship to OVHcloud Logs Data Platform.
- **Metrics:** `kubectl top pods` (metrics-server) or OVHcloud monitoring.
- **Alerts:** OVHcloud Metrics / webhook alert rules on MKS/load-balancer/database metrics.

## License

MIT