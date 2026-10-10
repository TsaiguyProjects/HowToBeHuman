"""Unit tests: real Flask app via test client, no mocks needed."""

from flask import Flask
from flask.testing import FlaskClient


def test_health_check(client: FlaskClient) -> None:
    resp = client.get("/api/health")
    assert resp.status_code == 200
    assert resp.get_json() == {"status": "healthy", "service": "flask-backend"}


def test_hello(client: FlaskClient) -> None:
    resp = client.get("/api/hello")
    assert resp.status_code == 200
    assert resp.get_json() == {"message": "Hello from Flask backend!"}


def test_unknown_api_route_returns_json_404(client: FlaskClient) -> None:
    """API namespace must never fall through to the SPA fallback."""
    resp = client.get("/api/does-not-exist")
    assert resp.status_code == 404
    assert resp.is_json
    assert resp.get_json() == {"error": "Not found"}


def test_spa_index_served_at_root(build_client: FlaskClient) -> None:
    resp = build_client.get("/")
    assert resp.status_code == 200
    assert "text/html" in resp.content_type
    assert "How To Be Human" in resp.get_data(as_text=True)


def test_spa_static_asset_served(build_client: FlaskClient) -> None:
    resp = build_client.get("/asset.js")
    assert resp.status_code == 200
    assert "console.log('hi')" in resp.get_data(as_text=True)


def test_spa_fallback_for_client_side_routes(build_client: FlaskClient) -> None:
    """Deep links (e.g. /dashboard/settings) serve index.html for the SPA router."""
    resp = build_client.get("/dashboard/settings")
    assert resp.status_code == 200
    assert "text/html" in resp.content_type
    assert "How To Be Human" in resp.get_data(as_text=True)


def test_missing_frontend_build_reports_json_404(
    app_without_frontend_build: Flask,
) -> None:
    client = app_without_frontend_build.test_client()
    resp = client.get("/")
    assert resp.status_code == 404
    assert resp.get_json() == {"error": "Frontend not built"}


def test_none_static_folder_reports_json_404(
    app_without_frontend_build: Flask,
) -> None:
    app_without_frontend_build.static_folder = None
    resp = app_without_frontend_build.test_client().get("/")
    assert resp.status_code == 404
    assert resp.get_json() == {"error": "Frontend not built"}
