#!/usr/bin/env bash
set -euo pipefail

# run_servers_mac.sh
# Starts backend (FastAPI/uvicorn) and frontend (python http.server) for development on macOS.

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$ROOT_DIR/logs"
mkdir -p "$LOG_DIR"

echo "[info] Starting Phishing Detection AI (backend + frontend)"

# --- Backend ---
cd "$ROOT_DIR/backend"
if [ ! -d "venv" ]; then
  echo "[info] Creating Python virtual environment in backend/venv..."
  python3 -m venv venv
fi

# Activate venv
source venv/bin/activate

# Install dependencies if requirements file changed or missing (fast guard: skip if already installed)
if [ -f requirements.txt ]; then
  echo "[info] Installing backend dependencies (this may take a while the first time)..."
  pip install -r requirements.txt
fi

# Ensure spaCy model
python - <<PY
try:
    import spacy
    spacy.load('en_core_web_sm')
    print('[info] spaCy model en_core_web_sm is present')
except Exception:
    print('[info] Downloading spaCy model en_core_web_sm...')
    import subprocess
    subprocess.check_call(["python3", "-m", "spacy", "download", "en_core_web_sm"])
PY

# Create helpful directories
mkdir -p "$ROOT_DIR/models" "$ROOT_DIR/data"

# Start uvicorn in background and log output
echo "[info] Starting backend (uvicorn) on port 3000..."
nohup uvicorn app.main:app --reload --port 3000 --host 0.0.0.0 > "$LOG_DIR/backend.log" 2>&1 &
BACKEND_PID=$!

echo "[info] Backend PID: $BACKEND_PID (logs: $LOG_DIR/backend.log)"

# --- Frontend ---
cd "$ROOT_DIR/frontend"
FRONTEND_PORT=8080
echo "[info] Starting frontend (python http.server) on port $FRONTEND_PORT..."
nohup python3 -m http.server $FRONTEND_PORT > "$LOG_DIR/frontend.log" 2>&1 &
FRONTEND_PID=$!

echo "[info] Frontend PID: $FRONTEND_PID (logs: $LOG_DIR/frontend.log)"

# Print endpoints
echo "\n=== Servers started ==="
echo "Backend: http://localhost:3000" 
echo "API docs: http://localhost:3000/docs"
echo "Frontend: http://localhost:$FRONTEND_PORT"
echo "Logs: $LOG_DIR"

# Wait for processes and forward SIGINT to them
trap "echo '[info] Stopping servers...'; kill $BACKEND_PID $FRONTEND_PID 2>/dev/null || true; exit 0" INT TERM

# Wait until background processes exit
wait $BACKEND_PID $FRONTEND_PID
