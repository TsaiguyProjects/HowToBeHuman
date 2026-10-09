import os
from flask import Flask, jsonify, send_from_directory
from flask_cors import CORS


def create_app():
    app = Flask(__name__, static_folder="../frontend/build")
    CORS(app)

    # Configuration
    app.config["SECRET_KEY"] = os.environ.get("SECRET_KEY", "dev-secret-change-in-production")

    # API Routes
    @app.route("/api/health")
    def health_check():
        return jsonify({"status": "healthy", "service": "flask-backend"})

    @app.route("/api/hello")
    def hello():
        return jsonify({"message": "Hello from Flask backend!"})

    # Serve React frontend for all non-API routes
    @app.route("/", defaults={"path": ""})
    @app.route("/<path:path>")
    def serve_frontend(path):
        if path.startswith("api/"):
            return jsonify({"error": "Not found"}), 404

        static_folder = app.static_folder
        if static_folder and os.path.exists(os.path.join(static_folder, path)):
            return send_from_directory(static_folder, path)
        else:
            index_path = os.path.join(static_folder, "index.html")
            if os.path.exists(index_path):
                return send_from_directory(static_folder, "index.html")
            return jsonify({"error": "Frontend not built"}), 404

    return app


if __name__ == "__main__":
    app = create_app()
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port, debug=False)
