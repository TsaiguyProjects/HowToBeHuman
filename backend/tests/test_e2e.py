"""End-to-end tests against the real production Docker images.

No mocks: builds ``backend/Dockerfile`` and ``frontend/Dockerfile`` from the
repo root, runs them on a shared Docker network, and asserts over real HTTP
(nginx -> gunicorn proxying, SPA serving, API routing).

Requires a Docker daemon; skipped automatically when one is unavailable.
Run with: ``pytest -m e2e`` (or ``make test-e2e``).
"""

from collections.abc import Iterator
from pathlib import Path
from time import monotonic, sleep

import docker
import pytest
import requests
from testcontainers.core.container import DockerContainer
from testcontainers.core.image import DockerImage
from testcontainers.core.network import Network

ROOT = Path(__file__).resolve().parents[2]
BACKEND_TAG = "htbh-e2e-backend"
FRONTEND_TAG = "htbh-e2e-frontend"
BACKEND_HOSTNAME = "htbh-e2e-backend"


def _docker_available() -> bool:
    try:
        docker.from_env().ping()
    except Exception:
        return False
    return True


pytestmark = [
    pytest.mark.e2e,
    pytest.mark.skipif(not _docker_available(), reason="Docker daemon not available"),
]


@pytest.fixture(scope="session")
def backend_image() -> Iterator[DockerImage]:
    image = DockerImage(path=str(ROOT), dockerfile_path="backend/Dockerfile", tag=BACKEND_TAG)
    image.build()
    yield image
    image.remove()


@pytest.fixture(scope="session")
def frontend_image() -> Iterator[DockerImage]:
    image = DockerImage(path=str(ROOT), dockerfile_path="frontend/Dockerfile", tag=FRONTEND_TAG)
    image.build()
    yield image
    image.remove()


@pytest.fixture(scope="session")
def e2e_network() -> Iterator[Network]:
    network = Network()
    network.create()
    yield network
    network.remove()


def _wait_for_http(url: str, timeout: int = 180) -> requests.Response:
    """Poll until the URL responds with a non-5xx status (services need boot time)."""
    deadline = monotonic() + timeout
    last_error: Exception | None = None
    while monotonic() < deadline:
        try:
            resp = requests.get(url, timeout=5)
            if resp.status_code < 500:
                return resp
        except requests.RequestException as exc:
            last_error = exc
        sleep(2)
    raise AssertionError(f"{url} never became ready (last error: {last_error})")


@pytest.fixture(scope="session")
def frontend_url(
    e2e_network: Network, backend_image: DockerImage, frontend_image: DockerImage
) -> Iterator[str]:
    """Run backend + frontend containers on a shared network; yield frontend base URL."""
    backend = (
        DockerContainer(BACKEND_TAG)
        .with_name(BACKEND_HOSTNAME)
        .with_network(e2e_network)
        .with_network_aliases("backend")
        .with_exposed_ports(8080)
        .with_env("SECRET_KEY", "e2e-test-secret")
        .with_env("FLASK_ENV", "production")
    )
    frontend = (
        DockerContainer(FRONTEND_TAG)
        .with_name("htbh-e2e-frontend")
        .with_network(e2e_network)
        .with_exposed_ports(80)
    )
    with backend, frontend:
        host = frontend.get_container_host_ip()
        port = frontend.get_exposed_port(80)
        base_url = f"http://{host}:{port}"
        # Block until the full proxy chain (nginx -> gunicorn) is serving.
        _wait_for_http(f"{base_url}/api/health")
        yield base_url


def test_e2e_frontend_serves_spa(frontend_url: str) -> None:
    resp = requests.get(f"{frontend_url}/", timeout=10)
    assert resp.status_code == 200
    assert "text/html" in resp.headers["Content-Type"]
    assert "How To Be Human" in resp.text


def test_e2e_api_health_proxied(frontend_url: str) -> None:
    resp = requests.get(f"{frontend_url}/api/health", timeout=10)
    assert resp.status_code == 200
    assert resp.json() == {"status": "healthy", "service": "flask-backend"}


def test_e2e_api_hello_proxied(frontend_url: str) -> None:
    resp = requests.get(f"{frontend_url}/api/hello", timeout=10)
    assert resp.status_code == 200
    assert resp.json() == {"message": "Hello from Flask backend!"}


def test_e2e_spa_fallback_for_client_side_routes(frontend_url: str) -> None:
    resp = requests.get(f"{frontend_url}/dashboard/settings", timeout=10)
    assert resp.status_code == 200
    assert "text/html" in resp.headers["Content-Type"]
    assert "How To Be Human" in resp.text


def test_e2e_unknown_api_route_returns_json_404(frontend_url: str) -> None:
    resp = requests.get(f"{frontend_url}/api/does-not-exist", timeout=10)
    assert resp.status_code == 404
    assert resp.json() == {"error": "Not found"}
