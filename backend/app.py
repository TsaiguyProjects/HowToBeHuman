import ipaddress
import os
import re
from datetime import datetime
from pathlib import Path

from flask import Flask, Response, jsonify, request, send_from_directory
from flask_cors import CORS
from werkzeug.exceptions import NotFound

CONTENT_VERSION_PATTERN = re.compile(r"^\d{8}T\d{6}Z$")
CONTENT_SUFFIXES = frozenset({".md", ".mmd", ".markdown"})


def _is_content_version(name: str) -> bool:
    if CONTENT_VERSION_PATTERN.fullmatch(name) is None:
        return False
    try:
        datetime.strptime(name, "%Y%m%dT%H%M%SZ")
    except ValueError:
        return False
    return True


def _latest_content_directory(content_root: str) -> tuple[str, Path] | None:
    root = Path(content_root)
    if not root.is_dir():
        return None

    try:
        versions = [
            entry
            for entry in root.iterdir()
            if entry.is_dir() and not entry.is_symlink() and _is_content_version(entry.name)
        ]
    except OSError:
        return None
    if not versions:
        return None

    latest = max(versions, key=lambda entry: entry.name)
    return latest.name, latest


def _content_root(app: Flask) -> Path:
    return Path(app.config["CONTENT_DIR"])


def _content_file(directory: Path, document_path: str) -> Path | None:
    candidate = directory / document_path
    try:
        resolved = candidate.resolve(strict=True)
        resolved.relative_to(directory.resolve())
    except (OSError, RuntimeError, ValueError):
        return None

    if not resolved.is_file() or resolved.suffix.lower() not in CONTENT_SUFFIXES:
        return None
    return resolved


def create_app(static_folder: str | None = None) -> Flask:
    app = Flask(__name__, static_folder=static_folder or "../frontend/build")
    default_cors_origins = (
        "http://localhost:3000" if os.environ.get("FLASK_ENV") != "production" else ""
    )
    cors_origins = os.environ.get("CORS_ORIGINS", default_cors_origins)
    CORS(app, origins=[o.strip() for o in cors_origins.split(",") if o.strip()])

    # Configuration
    secret_key = os.environ.get("SECRET_KEY")
    if not secret_key:
        if os.environ.get("FLASK_ENV") == "production":
            raise RuntimeError("SECRET_KEY must be set in production")
        secret_key = "dev-secret-change-in-production"
    app.config["SECRET_KEY"] = secret_key
    app.config["CONTENT_DIR"] = os.environ.get("CONTENT_DIR", "/content")

    # API Routes
    @app.route("/api/health")
    def health_check() -> Response:
        return jsonify({"status": "healthy", "service": "flask-backend"})

    @app.route("/api/hello")
    def hello() -> Response:
        return jsonify({"message": "Hello from Flask backend!"})

    @app.route("/api/caddy-ask")
    def caddy_ask() -> Response | tuple[Response, int]:
        host = request.args.get("domain", "")
        try:
            ipaddress.ip_address(host)
        except ValueError:
            return jsonify({"error": "Forbidden"}), 403
        return jsonify({"status": "ok"})

    @app.route("/api/content")
    def list_content() -> Response | tuple[Response, int]:
        latest = _latest_content_directory(str(_content_root(app)))
        if latest is None:
            return jsonify({"error": "Content is not available"}), 503

        version, directory = latest
        try:
            documents = sorted(
                path.relative_to(directory).as_posix()
                for path in directory.rglob("*")
                if path.is_file()
                and not path.is_symlink()
                and path.suffix.lower() in CONTENT_SUFFIXES
            )
        except OSError:
            return jsonify({"error": "Content is not available"}), 503
        response = jsonify({"version": version, "documents": documents})
        response.headers["Cache-Control"] = "no-cache"
        return response

    @app.route("/api/content/<version>/<path:document_path>")
    def get_content(
        version: str, document_path: str
    ) -> Response | tuple[Response, int]:
        if not _is_content_version(version):
            return jsonify({"error": "Content document not found"}), 404

        directory = _content_root(app) / version
        if not directory.is_dir() or directory.is_symlink():
            return jsonify({"error": "Content document not found"}), 404

        document = _content_file(directory, document_path)
        if document is None:
            return jsonify({"error": "Content document not found"}), 404

        try:
            markdown = document.read_text(encoding="utf-8")
        except (OSError, UnicodeError):
            return jsonify({"error": "Content document not found"}), 404

        response = Response(markdown, mimetype="text/markdown")
        response.headers["X-Content-Version"] = version
        response.headers["Cache-Control"] = "no-cache"
        response.headers["X-Content-Type-Options"] = "nosniff"
        return response

    # Explicit 404s for the API namespace (never fall through to the SPA).
    @app.route("/api")
    @app.route("/api/<path:_path>")
    def api_not_found(_path: str = "") -> tuple[Response, int]:
        return jsonify({"error": "Not found"}), 404

    # Serve React frontend for all non-API routes
    @app.route("/", defaults={"path": ""})
    @app.route("/<path:path>")
    def serve_frontend(path: str) -> Response | tuple[Response, int]:
        static_folder = app.static_folder
        if static_folder is None:
            return jsonify({"error": "Frontend not built"}), 404

        if path:
            try:
                return send_from_directory(static_folder, path)
            except (OSError, ValueError, NotFound):
                pass

        index_path = os.path.join(static_folder, "index.html")
        if os.path.isfile(index_path):
            return send_from_directory(static_folder, "index.html")
        return jsonify({"error": "Frontend not built"}), 404

    return app


if __name__ == "__main__":
    app = create_app()
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port, debug=False)
