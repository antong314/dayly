#!/bin/bash
cd "$(dirname "$0")/backend"
echo "🚀 Starting Dayly Backend Server..."
echo "   Your backend will be available at: http://192.168.68.59:8000"
echo ""
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
