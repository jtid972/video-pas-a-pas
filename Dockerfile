# Vidéo pas à pas — image CPU (linux/amd64 et linux/arm64)
# Copyright (c) 2026 Johan TIDAS — AGPL-3.0-or-later
FROM python:3.13-slim

# PRELOAD_MODEL=small intègre le modèle dans l'image (utile en serverless : pas de
# téléchargement à chaque démarrage). Vide = le modèle est téléchargé au 1er usage.
ARG PRELOAD_MODEL=""
# Numéro de version affiché (fourni par le workflow à partir de l'étiquette Git)
ARG APP_VERSION=""

RUN apt-get update \
    && apt-get install -y --no-install-recommends ffmpeg \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --uid 10001 --create-home --shell /usr/sbin/nologin app

WORKDIR /srv
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

ENV DATA_DIR=/data \
    MODELS_DIR=/opt/models \
    WHISPER_MODEL=small \
    WHISPER_DEVICE=cpu \
    WHISPER_COMPUTE=int8 \
    PYTHONUNBUFFERED=1 \
    APP_VERSION=${APP_VERSION}

RUN mkdir -p /data /opt/models \
    && if [ -n "$PRELOAD_MODEL" ]; then \
         python -c "from faster_whisper import WhisperModel as M; M('$PRELOAD_MODEL', device='cpu', compute_type='int8', download_root='/opt/models')"; \
       fi \
    && chown -R app:app /data /opt/models

COPY app ./app
COPY LICENSE NOTICE.md ./
USER app
VOLUME /data
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s \
  CMD python -c "import os,urllib.request; urllib.request.urlopen('http://127.0.0.1:%s/healthz' % os.environ.get('PORT','8000'))" || exit 1

# $PORT est fourni par Scaleway Serverless Containers ; 8000 par défaut ailleurs
CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
