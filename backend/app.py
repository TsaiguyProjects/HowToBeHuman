import os

from flask import Flask, jsonify, send_from_directory
from flask_cors import CORS
from werkzeug import Response as WerkzeugResponse


def create_app(static_folder: str | None = None) -> Flask:
    app = Flask(__name__, static_folder=static_folder or "../frontend/build")
    CORS(app)

    # Configuration
    app.config["SECRET_KEY"] = os.environ.get("SECRET_KEY", "dev-secret-change-in-production")

    # API Routes
    @app.route("/api/health")
    def health_check() -> WerkzeugResponse:
        return jsonify({"status": "healthy", "service": "flask-backend"})

    @app.route("/api/hello")
    def hello() -> WerkzeugResponse:
        return jsonify({"message": "Hello from Flask backend!"})

    # Serve React frontend for all non-API routes
    @app.route("/", defaults={"path": ""})
    @app.route("/<path:path>")
    def serve_frontend(path: str) -> WerkzeugResponse | tuple[WerkzeugResponse, int]:
        if path.startswith("api/"):
            return jsonify({"error": "Not found"}), 404

        static_folder = app.static_folder
        if static_folder is None:
            return jsonify({"error": "Frontend not built"}), 404

        if os.path.isfile(os.path.join(static_folder, path)):
            return send_from_directory(static_folder, path)

        index_path = os.path.join(static_folder, "index.html")
        if os.path.isfile(index_path):
            return send_from_directory(static_folder, "index.html")
        return jsonify({"error": "Frontend not built"}), 404

    return app


if __name__ == "__main__":
    app = create_app()
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port, debug=False)
