#!/usr/bin/env sh
# Vidéo pas à pas — lancement sans Docker sur macOS et Linux
# Usage : ./scripts/lancer.sh        (HOST=0.0.0.0 pour ouvrir au réseau local, PORT=8080 par défaut)
set -e
cd "$(dirname "$0")/.."

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ffmpeg est manquant."
  echo "  macOS  : brew install ffmpeg"
  echo "  Debian/Ubuntu : sudo apt install ffmpeg"
  echo "  Fedora : sudo dnf install ffmpeg"
  exit 1
fi
PY=$(command -v python3 || command -v python || true)
if [ -z "$PY" ]; then
  echo "Python 3.10+ est manquant (macOS : brew install python ; Linux : sudo apt install python3 python3-venv)"
  exit 1
fi

[ -d .venv ] || "$PY" -m venv .venv
. .venv/bin/activate
python -m pip install -q --upgrade pip
python -m pip install -q -r requirements.txt

HOST=${HOST:-127.0.0.1}
PORT=${PORT:-8080}
URL="http://localhost:$PORT"
echo "Vidéo pas à pas démarre sur $URL  (Ctrl+C pour arrêter)"
( sleep 3; if command -v open >/dev/null 2>&1; then open "$URL"; elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$URL"; fi ) >/dev/null 2>&1 &
exec python -m uvicorn app.main:app --host "$HOST" --port "$PORT"
