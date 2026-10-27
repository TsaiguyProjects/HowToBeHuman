"""Unit tests: real Flask app via test client, no mocks needed."""

from collections.abc import Iterator
from pathlib import Path

import pytest
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


def test_content_index_returns_503_without_content(content_app: Flask) -> None:
    response = content_app.test_client().get("/api/content")
    assert response.status_code == 503
    assert response.get_json() == {"error": "Content is not available"}


def test_content_index_returns_503_when_content_root_is_missing(
    content_app: Flask, tmp_path: Path
) -> None:
    content_app.config["CONTENT_ROOT"] = str(tmp_path / "not-mounted")

    response = content_app.test_client().get("/api/content")

    assert response.status_code == 503


def test_content_index_selects_newest_timestamp_directory(
    content_app: Flask, content_root: Path
) -> None:
    older = content_root / "20261024T120000Z"
    newest = content_root / "20261025T120000Z"
    invalid = content_root / "latest"
    older.mkdir()
    newest.mkdir()
    invalid.mkdir()
    (older / "old.md").write_text("Old", encoding="utf-8")
    (newest / "chapter.mmd").write_text("# Chapter", encoding="utf-8")
    (newest / "notes.txt").write_text("not markdown", encoding="utf-8")

    response = content_app.test_client().get("/api/content")

    assert response.status_code == 200
    assert response.headers["Cache-Control"] == "no-cache"
    assert response.get_json() == {
        "version": "20261025T120000Z",
        "documents": ["chapter.mmd"],
    }


def test_content_index_lists_nested_markdown(content_app: Flask, content_root: Path) -> None:
    version = content_root / "20261025T120000Z"
    (version / "essays").mkdir(parents=True)
    (version / "essays" / "one.markdown").write_text("One", encoding="utf-8")
    (version / "start.md").write_text("Start", encoding="utf-8")

    response = content_app.test_client().get("/api/content")

    assert response.get_json() == {
        "version": "20261025T120000Z",
        "documents": ["essays/one.markdown", "start.md"],
    }


def test_content_index_ignores_invalid_timestamp_directory(
    content_app: Flask, content_root: Path
) -> None:
    invalid = content_root / "20261340T250000Z"
    invalid.mkdir()
    (invalid / "notes.md").write_text("Invalid timestamp", encoding="utf-8")

    response = content_app.test_client().get("/api/content")

    assert response.status_code == 503


def test_content_index_returns_503_for_unreadable_content_root(
    content_app: Flask, content_root: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    original_iterdir = Path.iterdir

    def inaccessible_root(path: Path) -> Iterator[Path]:
        if path == content_root:
            raise PermissionError("not readable")
        return original_iterdir(path)

    monkeypatch.setattr(Path, "iterdir", inaccessible_root)

    response = content_app.test_client().get("/api/content")

    assert response.status_code == 503


def test_content_index_returns_503_when_version_tree_cannot_be_scanned(
    content_app: Flask, content_root: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    version = content_root / "20261025T120000Z"
    version.mkdir()
    original_rglob = Path.rglob

    def inaccessible_tree(path: Path, pattern: str) -> Iterator[Path]:
        if path == version:
            raise PermissionError("not readable")
        return original_rglob(path, pattern)

    monkeypatch.setattr(Path, "rglob", inaccessible_tree)

    response = content_app.test_client().get("/api/content")

    assert response.status_code == 503


def test_content_index_ignores_symlinked_version_directory(
    content_app: Flask, content_root: Path, tmp_path: Path
) -> None:
    outside = tmp_path / "outside"
    outside.mkdir()
    (outside / "secret.md").write_text("private", encoding="utf-8")
    (content_root / "20261025T120000Z").symlink_to(outside, target_is_directory=True)

    response = content_app.test_client().get("/api/content")

    assert response.status_code == 503


def test_content_route_returns_versioned_markdown(content_app: Flask, content_root: Path) -> None:
    version = "20261025T120000Z"
    version_dir = content_root / version
    version_dir.mkdir()
    (version_dir / "chapter.mmd").write_text("# A chapter", encoding="utf-8")

    response = content_app.test_client().get(f"/api/content/{version}/chapter.mmd")

    assert response.status_code == 200
    assert response.get_data(as_text=True) == "# A chapter"
    assert response.mimetype == "text/markdown"
    assert response.headers["X-Content-Version"] == version
    assert response.headers["Cache-Control"] == "no-cache"


def test_content_route_keeps_older_version_accessible(
    content_app: Flask, content_root: Path
) -> None:
    old_version = content_root / "20261024T120000Z"
    new_version = content_root / "20261025T120000Z"
    old_version.mkdir()
    new_version.mkdir()
    (old_version / "chapter.md").write_text("Old", encoding="utf-8")
    (new_version / "chapter.md").write_text("New", encoding="utf-8")

    response = content_app.test_client().get(f"/api/content/{old_version.name}/chapter.md")

    assert response.get_data(as_text=True) == "Old"


def test_content_route_rejects_invalid_version(content_app: Flask) -> None:
    response = content_app.test_client().get("/api/content/latest/chapter.md")
    assert response.status_code == 404


def test_content_route_rejects_impossible_calendar_date(content_app: Flask) -> None:
    response = content_app.test_client().get("/api/content/20261340T250000Z/chapter.md")
    assert response.status_code == 404


def test_content_route_rejects_missing_version(content_app: Flask) -> None:
    response = content_app.test_client().get("/api/content/20261025T120000Z/chapter.md")
    assert response.status_code == 404


def test_content_route_rejects_unknown_or_non_markdown_file(
    content_app: Flask, content_root: Path
) -> None:
    version = "20261025T120000Z"
    version_dir = content_root / version
    version_dir.mkdir()
    (version_dir / "notes.txt").write_text("No", encoding="utf-8")

    response = content_app.test_client().get(f"/api/content/{version}/notes.txt")
    missing = content_app.test_client().get(f"/api/content/{version}/missing.md")

    assert response.status_code == 404
    assert missing.status_code == 404


def test_content_route_rejects_symlink_escape(
    content_app: Flask, content_root: Path, tmp_path: Path
) -> None:
    version = "20261025T120000Z"
    version_dir = content_root / version
    version_dir.mkdir()
    secret = tmp_path / "secret.md"
    secret.write_text("private", encoding="utf-8")
    (version_dir / "linked.md").symlink_to(secret)

    response = content_app.test_client().get(f"/api/content/{version}/linked.md")

    assert response.status_code == 404


def test_content_route_rejects_broken_symlink(content_app: Flask, content_root: Path) -> None:
    version = "20261025T120000Z"
    version_dir = content_root / version
    version_dir.mkdir()
    (version_dir / "broken.md").symlink_to(content_root / "does-not-exist.md")

    response = content_app.test_client().get(f"/api/content/{version}/broken.md")

    assert response.status_code == 404


def test_content_route_rejects_non_utf8_document(content_app: Flask, content_root: Path) -> None:
    version = "20261025T120000Z"
    version_dir = content_root / version
    version_dir.mkdir()
    (version_dir / "invalid.md").write_bytes(b"\xff")

    response = content_app.test_client().get(f"/api/content/{version}/invalid.md")

    assert response.status_code == 404


def test_create_app_requires_secret_key_in_production(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("FLASK_ENV", "production")
    monkeypatch.delenv("SECRET_KEY", raising=False)
    with pytest.raises(RuntimeError, match="SECRET_KEY must be set in production"):
        from app import create_app

        create_app()
