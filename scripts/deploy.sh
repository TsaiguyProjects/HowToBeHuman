#!/bin/bash
# Production deployment script for Digital Ocean App Platform

set -e

APP_NAME="how-to-be-human"

echo "🚀 Deploying $APP_NAME to Digital Ocean App Platform..."

# Check for doctl
if ! command -v doctl &> /dev/null; then
    echo "❌ doctl not found. Install it: https://docs.digitalocean.com/reference/doctl/how-to/install/"
    exit 1
fi

# Check authentication
if ! doctl account get &> /dev/null; then
    echo "❌ Not authenticated with Digital Ocean. Run: doctl auth init"
    exit 1
fi

# Check if app exists
APP_ID=$(doctl apps list --format ID,Spec.Name --no-header | grep "$APP_NAME" | awk '{print $1}')

if [ -z "$APP_ID" ]; then
    echo "📦 Creating new app..."
    doctl apps create --spec .do/app.yaml
else
    echo "🔄 Updating existing app (ID: $APP_ID)..."
    doctl apps update "$APP_ID" --spec .do/app.yaml
fi

echo "✅ Deployment initiated!"
echo "📊 Check status: doctl apps get $APP_ID"
echo "📝 View logs: doctl apps logs $APP_ID --follow"