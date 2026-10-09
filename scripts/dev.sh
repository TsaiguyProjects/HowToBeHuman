#!/bin/bash
# Development startup script - uses uv (Python) and pnpm (Node)

set -e

echo "🚀 Starting HowToBeHuman development environment..."

# Check for .env file
if [ ! -f .env ]; then
    echo "📋 Creating .env from .env.example..."
    cp .env.example .env
fi

# Check for required tools
check_tool() {
    if ! command -v $1 &> /dev/null; then
        echo "⚠️  $1 not found. Install it for native development:"
        echo "   $2"
        return 1
    fi
    return 0
}

echo "🔍 Checking development tools..."
check_tool uv "pip install uv" || true
check_tool pnpm "npm install -g pnpm" || true

# Function to cleanup on exit
cleanup() {
    echo ""
    echo "🛑 Shutting down..."
    docker-compose down
    exit 0
}
trap cleanup INT TERM

# Start services with hot reload
echo "🐳 Starting Docker containers with hot reload..."
docker-compose --profile dev up --build

# This will run until Ctrl+C
wait