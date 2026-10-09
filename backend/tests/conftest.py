"""Shared fixtures: real Flask app instances, no mocks."""

from pathlib import Path

import pytest
from flask import Flask
from flask.testing import FlaskClient

from app import create_app


@pytest.fixture()
def app() -> Flask:
    return create_app()


@pytest.fixture()
def client(app: Flask) -> FlaskClient:
    return app.test_client()


@pytest.fixture()
def app_without_frontend_build(tmp_path: Path) -> Flask:
    """App whose static folder is an empty dir (simulates 'frontend not built')."""
    return create_app(static_folder=str(tmp_path))


@pytest.fixture()
def content_app(tmp_path: Path) -> Flask:
    content_root = tmp_path / "content"
    content_root.mkdir()
    app = create_app(static_folder=str(tmp_path))
    app.config["CONTENT_ROOT"] = str(content_root)
    return app


@pytest.fixture()
def content_root(content_app: Flask) -> Path:
    return Path(content_app.config["CONTENT_ROOT"])


@pytest.fixture()
def app_with_frontend_build(tmp_path: Path) -> Flask:
    """App pointed at a real on-disk build dir (real files, no mocks)."""
    build_dir = tmp_path / "build"
    build_dir.mkdir()
    (build_dir / "index.html").write_text(
        "<html><head><title>How To Be Human</title></head></html>", encoding="utf-8"
    )
    (build_dir / "asset.js").write_text("console.log('hi')", encoding="utf-8")
    return create_app(static_folder=str(build_dir))


@pytest.fixture()
def build_client(app_with_frontend_build: Flask) -> FlaskClient:
    return app_with_frontend_build.test_client()
