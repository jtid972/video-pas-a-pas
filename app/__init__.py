"""Vidéo pas à pas — prépare une vidéo ou un audio pour une IA (transcription + captures)."""
import os

# APP_VERSION est fixé à la construction de l'image Docker à partir de l'étiquette Git (ex. v1.0.4).
__version__ = os.environ.get("APP_VERSION") or "1.0.0"
