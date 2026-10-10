# HowToBeHuman

A full-stack application with a Python Flask backend and React frontend, deployable to Digital Ocean App Platform.

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
            │ Digital Ocean   │
            │ App Platform    │
            └─────────────────┘
```

## Project Structure

```
.
├── .do/
│   └── app.yaml              # Digital Ocean App Platform spec (both services use Dockerfiles)
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
# Node 20.19+ required (Vite 8 engines); latest LTS (24.x) recommended.
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

> **First run?** `cd backend && uv lock` generates `uv.lock`. `pnpm install` generates the root `pnpm-lock.yaml`. Commit both lockfiles — they guarantee reproducible builds in Docker, CI, and Digital Ocean.

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
| `make deploy` | Deploy to Digital Ocean App Platform |
| `make logs` | Follow app logs on Digital Ocean |
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
(`Makefile`, `docker-compose.yml`, `.do/`, `scripts/`, `.githooks/`,
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

# Deploy to Digital Ocean
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

## Deployment to Digital Ocean App Platform

### Prerequisites

1. [Digital Ocean account](https://cloud.digitalocean.com/registrations/new)
2. [doctl CLI](https://docs.digitalocean.com/reference/doctl/how-to/install/) installed and authenticated
3. GitHub repository with this code
4. Lockfiles committed: `backend/uv.lock` (`uv lock`) and `frontend/pnpm-lock.yaml` (`pnpm install`)

> **Why Docker-based services?** Both backend and frontend deploy via `Dockerfile` in `.do/app.yaml`. This is what lets production use `uv` and `pnpm` instead of Digital Ocean's default `pip`/`npm` buildpacks — same toolchain locally, in CI, and in production.

### Setup

1. **Push to GitHub:**
   ```bash
   git init
   git add .
   git commit -m "Initial commit"
   git remote add origin https://github.com/YOUR_USERNAME/HowToBeHuman.git
   git push -u origin main
   ```

2. **Update `.do/app.yaml`:**
   - Replace `YOUR_GITHUB_USERNAME` with your GitHub username

3. **Create the app:**
   ```bash
   doctl apps create --spec .do/app.yaml
   ```

4. **Set secrets (required):**
   ```bash
   # Generate a secure secret key
   python -c "import secrets; print(secrets.token_hex(32))"
   
   # Set in Digital Ocean dashboard or via doctl
   doctl apps update <APP_ID> --spec .do/app.yaml
   # Then add SECRET_KEY in the Digital Ocean console under Settings > Environment Variables
   ```

### Custom Domain

1. In Digital Ocean console: Settings > Domains > Add Domain
2. Configure DNS records as instructed
3. Enable HTTPS (automatic with Let's Encrypt)

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `SECRET_KEY` | Flask secret for sessions/CSRF | Yes (production) |
| `FLASK_ENV` | `production` or `development` | No |
| `DATABASE_URL` | PostgreSQL connection string | If using DB |
| `VITE_API_URL` | Frontend API base URL | No (defaults to `/api`) |

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/health` | Health check |
| GET | `/api/hello` | Test endpoint |

## Adding a Database

1. Uncomment the `databases` section in `.do/app.yaml`
2. Add `DATABASE_URL` to backend env vars (auto-injected by DO)
3. Update `backend/app.py` to use SQLAlchemy/psycopg2

## Scaling

In `.do/app.yaml`, adjust:
- `instance_count`: Number of containers
- `instance_size_slug`: Container size (basic-xxs, basic-xs, basic-s, etc.)

## Monitoring

- **Logs:** Digital Ocean console > Apps > your-app > Logs
- **Metrics:** Insights tab in App console
- **Alerts:** Configure in Settings > Alert Policies

## Troubleshooting

**Backend not starting:**
- Check logs for import errors (`make logs-backend`)
- Verify `backend/pyproject.toml` has all dependencies (uv manages this, not `requirements.txt`)
- Ensure `uv.lock` is committed and in sync (`cd backend && uv lock --check`)
- Ensure `gunicorn` command matches your app factory (`app:create_app()`)

**Frontend not loading:**
- Check nginx config for correct proxy_pass to backend service name
- Verify build output in `/usr/share/nginx/html`
- Check browser console for API errors

**API calls failing:**
- Ensure frontend nginx proxies `/api/*` to backend service
- Check CORS settings in Flask (`flask-cors`)
- Verify health check endpoint returns 200

## License

MIT