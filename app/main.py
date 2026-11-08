# Vidéo pas à pas — Copyright (c) 2026 Johan TIDAS
# SPDX-License-Identifier: AGPL-3.0-or-later  (voir LICENSE et NOTICE.md ; licence commerciale possible)
# Code réalisé avec l'assistance de Claude (IA d'Anthropic) pour la génération de code.
"""Vidéo pas à pas : prépare une vidéo (ou un fichier audio) pour une IA.

Produit un ZIP contenant :
  - transcription.txt / .srt / .json (texte horodaté)
  - images/ (captures aux changements de plan + à intervalle régulier)
  - preparation.md (texte et captures dans l'ordre chronologique)
  - LISEZMOI.md et CONSIGNE_IA.md (à quoi sert le ZIP, consigne prête à coller)
"""
import base64
import json
import os
import queue
import re
import secrets
import shutil
import subprocess
import threading
import time
import uuid
import zipfile
from pathlib import Path

from fastapi import FastAPI, File, Form, HTTPException, Request, UploadFile
from fastapi.responses import FileResponse, RedirectResponse, Response
from fastapi.staticfiles import StaticFiles

from . import __version__

APP_NAME = "Vidéo pas à pas"
BASE = Path(__file__).resolve().parent
DATA = Path(os.environ.get("DATA_DIR", BASE.parent / "data"))
JOBS = DATA / "jobs"
MODELS_DIR = Path(os.environ.get("MODELS_DIR", DATA / "models"))
JOBS.mkdir(parents=True, exist_ok=True)

DEFAULT_MODEL = os.environ.get("WHISPER_MODEL", "small")
DEVICE = os.environ.get("WHISPER_DEVICE", "auto")          # auto | cpu | cuda
COMPUTE = os.environ.get("WHISPER_COMPUTE", "auto")        # auto | int8 | float16 ...
SCENE = float(os.environ.get("SCENE_THRESHOLD", "0.3"))    # sensibilité changement de plan (0-1)
INTERVAL = float(os.environ.get("FRAME_INTERVAL", "30"))   # une capture au moins toutes les N s
MIN_GAP = float(os.environ.get("FRAME_MIN_GAP", "4"))      # écart minimal entre deux captures
MAX_FRAMES = int(os.environ.get("MAX_FRAMES", "300"))
KEEP_HOURS = float(os.environ.get("KEEP_HOURS", "48"))     # suppression auto des anciens travaux
MAX_UPLOAD_MB = int(os.environ.get("MAX_UPLOAD_MB", "4096"))
PASSWORD = os.environ.get("APP_PASSWORD", "")              # vide = pas de mot de passe
# AGPL-3.0, article 13 : les utilisateurs à distance doivent pouvoir obtenir le code source.
# Si vous modifiez le programme, faites pointer cette adresse vers VOTRE version modifiée.
SOURCE_URL = os.environ.get("SOURCE_URL", "https://github.com/jtid972/video-pas-a-pas")
MODELS = ["tiny", "base", "small", "medium", "large-v3"]

app = FastAPI(title=APP_NAME, version=__version__)
app.mount("/static", StaticFiles(directory=BASE / "static"), name="static")
PUBLIC = ("/healthz", "/manifest.webmanifest", "/sw.js", "/static/icons/")
jobs: dict[str, dict] = {}
jobs_lock = threading.Lock()
work_queue: "queue.Queue[str]" = queue.Queue()
_model_cache: dict = {}


# ---------------------------------------------------------------- mot de passe (facultatif)
@app.middleware("http")
async def basic_auth(request: Request, call_next):
    if PASSWORD and not request.url.path.startswith(PUBLIC):
        ok = False
        h = request.headers.get("authorization", "")
        if h.lower().startswith("basic "):
            try:
                _, _, pwd = base64.b64decode(h[6:]).decode("utf-8").partition(":")
                ok = secrets.compare_digest(pwd.encode(), PASSWORD.encode())
            except Exception:  # noqa: BLE001
                ok = False
        if not ok:
            return Response("Mot de passe requis", status_code=401,
                            headers={"WWW-Authenticate": 'Basic realm="Video pas a pas"'})
    return await call_next(request)


# ---------------------------------------------------------------- utilitaires
def upd(jid: str, **kw):
    with jobs_lock:
        jobs[jid].update(kw)
        (JOBS / jid / "status.json").write_text(json.dumps(jobs[jid], ensure_ascii=False))


def ts(t: float, srt: bool = False) -> str:
    h, rem = divmod(t, 3600)
    m, s = divmod(rem, 60)
    if srt:
        return f"{int(h):02d}:{int(m):02d}:{int(s):02d},{int((s % 1) * 1000):03d}"
    return f"{int(h)}:{int(m):02d}:{int(s):02d}" if h else f"{int(m):02d}:{int(s):02d}"


def probe(src: Path) -> dict:
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries",
         "format=duration:stream=codec_type:stream_disposition=attached_pic",
         "-of", "json", str(src)], capture_output=True, text=True)
    if out.returncode:
        raise RuntimeError("Fichier illisible par ffmpeg (format non reconnu ?)")
    info = json.loads(out.stdout)
    streams = info.get("streams", [])
    has_audio = any(s.get("codec_type") == "audio" for s in streams)
    # une pochette d'album (MP3, M4A…) apparaît comme un flux vidéo : on l'ignore
    has_video = any(s.get("codec_type") == "video"
                    and not s.get("disposition", {}).get("attached_pic") for s in streams)
    return {"duration": float(info.get("format", {}).get("duration") or 0),
            "audio": has_audio, "video": has_video}


def load_wav(path: Path):
    """WAV PCM 16 bits mono → tableau numpy float32 entre -1 et 1 (format attendu par Whisper)."""
    import wave

    import numpy as np
    with wave.open(str(path), "rb") as w:
        if w.getsampwidth() != 2 or w.getnchannels() != 1:
            raise RuntimeError("Format audio intermédiaire inattendu (PCM 16 bits mono attendu).")
        data = w.readframes(w.getnframes())
    return np.frombuffer(data, dtype=np.int16).astype(np.float32) / 32768.0


def get_model(name: str):
    if name not in _model_cache:
        from faster_whisper import WhisperModel
        _model_cache.clear()  # un seul modèle en mémoire
        _model_cache[name] = WhisperModel(name, device=DEVICE, compute_type=COMPUTE,
                                          download_root=str(MODELS_DIR))
    return _model_cache[name]


# ---------------------------------------------------------------- étapes
def transcribe(jid, wav, duration, model_name, language):
    upd(jid, stage="Chargement du modèle (le 1er lancement le télécharge)", progress=0)
    try:
        model = get_model(model_name)
    except Exception as e:  # noqa: BLE001
        raise RuntimeError(
            f"Impossible de charger le modèle « {model_name} » ({e}). Au 1er lancement, "
            "la machine doit avoir accès à Internet (huggingface.co) pour le télécharger.") from e
    # On donne directement les échantillons audio (WAV 16 kHz mono produit par ffmpeg) : faster-whisper
    # n'a pas à relire le fichier avec PyAV, dont la version 19 n'est plus compatible avec lui.
    segments, info = model.transcribe(load_wav(wav), language=language or None,
                                      vad_filter=True, beam_size=5)
    upd(jid, stage="Transcription de l'audio", progress=0, language=info.language)
    segs = []
    for s in segments:
        segs.append({"start": round(s.start, 2), "end": round(s.end, 2), "text": s.text.strip()})
        if duration:
            upd(jid, progress=round(min(s.end / duration, 1) * 100, 1))
    return segs


def detect_scenes(jid, src, duration):
    upd(jid, stage="Détection des changements de plan", progress=0)
    p = subprocess.Popen(
        ["ffmpeg", "-hide_banner", "-i", str(src), "-an",
         "-vf", f"scale=320:-2,select='gt(scene,{SCENE})',showinfo", "-f", "null", "-"],
        stderr=subprocess.PIPE, text=True, errors="replace")
    times = []
    for line in p.stderr:  # le mode texte convertit les \r de ffmpeg en sauts de ligne
        m = re.search(r"pts_time:([\d.]+)", line)
        if m:
            times.append(float(m.group(1)))
        m = re.search(r"time=(\d+):(\d+):([\d.]+)", line)
        if m and duration:
            t = int(m.group(1)) * 3600 + int(m.group(2)) * 60 + float(m.group(3))
            upd(jid, progress=round(min(t / duration, 1) * 100, 1))
    p.wait()
    return times


def pick_times(scene_times, duration):
    # 1) changements de plan (prioritaires), +0.5 s pour que l'écran soit bien affiché
    kept = []
    for t in sorted([min(1.0, duration / 2)] + [s + 0.5 for s in scene_times]):
        if t < duration and (not kept or t - kept[-1] >= MIN_GAP):
            kept.append(t)
    # 2) captures régulières seulement là où il n'y a rien à proximité
    t = INTERVAL
    while t < duration:
        if all(abs(t - k) >= MIN_GAP for k in kept):
            kept.append(t)
        t += INTERVAL
    kept.sort()
    if len(kept) > MAX_FRAMES:  # on échantillonne régulièrement
        step = len(kept) / MAX_FRAMES
        kept = [kept[int(i * step)] for i in range(MAX_FRAMES)]
    return kept


def extract_frames(jid, src, times, img_dir):
    upd(jid, stage="Extraction des captures", progress=0)
    frames = []
    for i, t in enumerate(times):
        name = f"img_{i + 1:03d}_{int(t) // 60:03d}m{int(t) % 60:02d}s.jpg"
        r = subprocess.run(
            ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-ss", f"{t:.2f}",
             "-i", str(src), "-frames:v", "1", "-q:v", "3",
             "-vf", "scale='min(1600,iw)':-2", str(img_dir / name)], capture_output=True)
        if r.returncode == 0 and (img_dir / name).exists():
            frames.append({"time": round(t, 2), "file": f"images/{name}"})
        upd(jid, progress=round((i + 1) / len(times) * 100, 1))
    return frames


LISEZMOI = """# Dossier de préparation — {app}

Ce ZIP a été produit par **{app}** (v{version}) à partir du fichier « {fichier} ».

**C'est un dossier de préparation, pas un document final.** Il sert d'entrée à une
intelligence artificielle capable de traiter du texte et/ou des images, pour rédiger par exemple :

- un **tutoriel** pas à pas ;
- un **guide** ou mode opératoire ;
- une **note de synthèse** ou un compte rendu.

## Contenu

| Fichier | Contenu |
|---|---|
| `preparation.md` | Le texte et les captures **dans l'ordre chronologique** : c'est le fichier principal. |
| `transcription.txt` | Ce qui est dit, une ligne par passage, avec l'heure `[mm:ss]`. |
| `transcription.srt` | Les mêmes passages au format sous-titres. |
| `transcription.json` | Données structurées (passages, captures, durée, langue). |
| `images/` | {n_images} capture(s) d'écran. Le nom contient le moment de la vidéo (`img_004_002m15s.jpg` = 2 min 15). |
| `CONSIGNE_IA.md` | Une consigne prête à copier-coller dans l'IA. |

## Comment l'utiliser

- **IA qui lit les images et le texte** (ex. Claude) : envoie le ZIP entier, ou `preparation.md` avec le dossier `images/`.
- **IA qui ne lit que le texte** : envoie `transcription.txt` (ou `preparation.md`, les images seront ignorées).
{note}
Résumé : durée {duree}, {n_segs} passage(s) transcrit(s), {n_images} capture(s), langue : {langue}.
"""

CONSIGNE = """Tu reçois un dossier de préparation produit par « {app} » à partir d'une vidéo ou d'un
enregistrement audio : une transcription horodatée et, s'il y en a, des captures d'écran
classées dans l'ordre chronologique (fichier preparation.md et dossier images/).

À partir de ce contenu, rédige [un tutoriel pas à pas | un guide | une note de synthèse]
destiné à [public visé, ex. : débutants].

Consignes :
- Reformule les explications orales en étapes claires et numérotées (pas de copier-coller de la transcription).
- Pour chaque étape, choisis la capture la plus utile, si elle aide à comprendre, et indique son nom de fichier.
- Ignore les hésitations, répétitions et passages hors sujet.
- Signale ce qui semble manquer ou être ambigu dans la source.
- Termine par les points d'attention / erreurs fréquentes, si la source en mentionne.
"""


def write_outputs(out, title, meta, segs, frames):
    (out / "transcription.txt").write_text(
        "\n".join(f"[{ts(s['start'])}] {s['text']}" for s in segs), encoding="utf-8")
    (out / "transcription.srt").write_text(
        "\n".join(f"{i}\n{ts(s['start'], True)} --> {ts(s['end'], True)}\n{s['text']}\n"
                  for i, s in enumerate(segs, 1)), encoding="utf-8")
    (out / "transcription.json").write_text(
        json.dumps({"outil": f"{APP_NAME} {__version__}", **meta,
                    "segments": segs, "images": frames}, ensure_ascii=False, indent=2),
        encoding="utf-8")

    note = ""
    if meta["source"] == "audio":
        note = "\n> Source **audio uniquement** : il n'y a pas de captures d'écran.\n"
    elif not segs:
        note = "\n> Pas de transcription (pas de piste audio, ou option désactivée) : seules les captures sont fournies.\n"
    common = {"app": APP_NAME, "version": __version__, "fichier": title,
              "n_images": len(frames), "n_segs": len(segs), "duree": ts(meta["duration"]),
              "langue": meta.get("language") or "n/a", "note": note}
    (out / "LISEZMOI.md").write_text(LISEZMOI.format(**common), encoding="utf-8")
    (out / "CONSIGNE_IA.md").write_text(CONSIGNE.format(**common), encoding="utf-8")

    events = [(s["start"], 1, f"**[{ts(s['start'])}]** {s['text']}") for s in segs]
    events += [(f["time"], 0, f"![Capture {ts(f['time'])}]({f['file']})") for f in frames]
    lines = [f"# Préparation : {title}", "",
             f"> Dossier de préparation produit par {APP_NAME} v{__version__}, destiné à servir "
             "d'entrée à une IA (texte et/ou images) pour rédiger un tutoriel, un guide ou une "
             "note de synthèse. Voir LISEZMOI.md.", "",
             f"- Source : {'audio' if meta['source'] == 'audio' else 'vidéo'}",
             f"- Durée : {ts(meta['duration'])}",
             f"- Langue détectée : {meta.get('language') or 'n/a'}",
             f"- Modèle de transcription : {meta.get('model') or 'aucun'}",
             f"- {len(segs)} passages transcrits, {len(frames)} captures", "",
             "---", ""]
    lines += [e[2] + "\n" for e in sorted(events)]
    (out / "preparation.md").write_text("\n".join(lines), encoding="utf-8")


def process(jid: str):
    j = jobs[jid]
    d = JOBS / jid
    src = d / j["source"]
    out = d / "resultat"
    img_dir = out / "images"
    img_dir.mkdir(parents=True, exist_ok=True)

    info = probe(src)
    if not info["audio"] and not info["video"]:
        raise RuntimeError("Le fichier ne contient ni audio ni vidéo exploitable.")
    dur = info["duration"]
    meta = {"fichier": j["filename"], "source": "video" if info["video"] else "audio",
            "duration": dur, "model": None, "language": None}
    segs, frames = [], []

    if j["transcribe"]:
        if info["audio"]:
            upd(jid, stage="Extraction de l'audio", progress=0)
            wav = d / "audio.wav"
            r = subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
                                "-i", str(src), "-vn", "-ac", "1", "-ar", "16000", "-c:a", "pcm_s16le", str(wav)],
                               capture_output=True, text=True)
            if r.returncode:
                raise RuntimeError("Extraction audio impossible : " + r.stderr[-300:])
            segs = transcribe(jid, wav, dur, j["model"], j["language"])
            meta["model"] = j["model"]
            meta["language"] = jobs[jid].get("language")
            wav.unlink(missing_ok=True)
        else:
            upd(jid, warning="Le fichier n'a pas de piste audio : pas de transcription.")

    if j["images"] and info["video"]:
        scenes = detect_scenes(jid, src, dur)
        frames = extract_frames(jid, src, pick_times(scenes, dur), img_dir)

    upd(jid, stage="Création du ZIP", progress=0)
    write_outputs(out, j["filename"], meta, segs, frames)
    zpath = d / "resultat.zip"
    with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED) as z:
        for f in sorted(out.rglob("*")):
            if f.is_file():
                z.write(f, f.relative_to(out))
    shutil.rmtree(out, ignore_errors=True)
    src.unlink(missing_ok=True)  # on ne garde pas le fichier source
    upd(jid, status="done", stage="Terminé", progress=100,
        summary=f"{len(segs)} passages transcrits, {len(frames)} captures")


def worker():
    while True:
        jid = work_queue.get()
        upd(jid, status="running")
        try:
            process(jid)
        except Exception as e:  # noqa: BLE001
            upd(jid, status="error", stage="Erreur", message=str(e)[:500])


def cleaner():
    while True:
        limit = time.time() - KEEP_HOURS * 3600
        for d in JOBS.iterdir():
            if d.is_dir() and d.stat().st_mtime < limit:
                shutil.rmtree(d, ignore_errors=True)
                with jobs_lock:
                    jobs.pop(d.name, None)
        time.sleep(3600)


threading.Thread(target=worker, daemon=True).start()
threading.Thread(target=cleaner, daemon=True).start()


# ---------------------------------------------------------------- API
@app.get("/healthz")
def healthz():
    return {"ok": True}


@app.get("/api/config")
def config():
    return {"name": APP_NAME, "version": __version__, "models": MODELS,
            "default_model": DEFAULT_MODEL, "max_upload_mb": MAX_UPLOAD_MB,
            "source_url": SOURCE_URL, "license": "AGPL-3.0-or-later"}


async def save_upload(file: UploadFile) -> tuple[str, str]:
    """Enregistre le fichier envoyé dans un nouveau dossier de travail ; renvoie (id, nom du fichier source)."""
    jid = uuid.uuid4().hex[:12]
    d = JOBS / jid
    d.mkdir()
    suffix = Path(file.filename or "media").suffix.lower()[:8] or ".bin"
    source = "source" + re.sub(r"[^.a-z0-9]", "", suffix)
    size, limit = 0, MAX_UPLOAD_MB * 1024 * 1024
    with open(d / source, "wb") as f:  # noqa: ASYNC230
        while chunk := await file.read(1 << 20):
            size += len(chunk)
            if size > limit:
                f.close()
                shutil.rmtree(d, ignore_errors=True)
                raise HTTPException(413, f"Fichier trop gros (limite {MAX_UPLOAD_MB} Mo)")
            f.write(chunk)
    return jid, source


def start_job(jid, source, filename, language, model, transcribe_audio, images):
    if model not in MODELS:
        raise HTTPException(400, "Modèle inconnu")
    with jobs_lock:
        jobs[jid] = {"id": jid, "filename": filename or "media", "source": source,
                     "language": (language or "").strip() or None, "model": model,
                     "transcribe": transcribe_audio, "images": images,
                     "status": "queued", "stage": "En attente", "progress": 0}
    upd(jid)
    work_queue.put(jid)
    return {"id": jid}


@app.post("/api/jobs")
async def create_job(file: UploadFile = File(...), language: str = Form(""),
                     model: str = Form(DEFAULT_MODEL), transcribe_audio: bool = Form(True),
                     images: bool = Form(True)):
    if model not in MODELS:
        raise HTTPException(400, "Modèle inconnu")
    jid, source = await save_upload(file)
    return start_job(jid, source, file.filename, language, model, transcribe_audio, images)


# Partage depuis un téléphone (application installée) : « Partager » → Vidéo pas à pas.
# Le fichier est mis de côté ; la page propose ensuite les réglages puis le lancement.
shared: dict[str, dict] = {}


@app.post("/share")
async def share(file: UploadFile = File(...)):
    try:
        jid, source = await save_upload(file)
    except HTTPException as e:
        return RedirectResponse(f"/?erreur={e.detail}", status_code=303)
    shared[jid] = {"source": source, "filename": file.filename or "media"}
    return RedirectResponse(f"/?partage={jid}", status_code=303)


@app.get("/api/shared/{jid}")
def shared_info(jid: str):
    if jid not in shared:
        raise HTTPException(404, "Fichier partagé introuvable")
    return {"filename": shared[jid]["filename"]}


@app.post("/api/shared/{jid}/start")
def shared_start(jid: str, language: str = Form(""), model: str = Form(DEFAULT_MODEL),
                 transcribe_audio: bool = Form(True), images: bool = Form(True)):
    s = shared.pop(jid, None)
    if not s:
        raise HTTPException(404, "Fichier partagé introuvable")
    return start_job(jid, s["source"], s["filename"], language, model, transcribe_audio, images)


@app.get("/api/jobs/{jid}")
def job_status(jid: str):
    j = jobs.get(jid)
    if not j:
        raise HTTPException(404, "Travail introuvable (le serveur a peut-être redémarré)")
    pos = list(work_queue.queue).index(jid) + 1 if jid in work_queue.queue else 0
    return {**j, "queue_position": pos}


@app.get("/api/jobs/{jid}/download")
def download(jid: str):
    j = jobs.get(jid)
    z = JOBS / jid / "resultat.zip"
    if not j or j.get("status") != "done" or not z.exists():
        raise HTTPException(404, "Résultat pas encore prêt")
    name = Path(j["filename"]).stem + "_preparation_IA.zip"
    return FileResponse(z, filename=name, media_type="application/zip")


# ---------------------------------------------------------------- application installable (PWA)
@app.get("/manifest.webmanifest")
def manifest():
    return FileResponse(BASE / "static" / "manifest.webmanifest", media_type="application/manifest+json")


@app.get("/sw.js")
def service_worker():
    return FileResponse(BASE / "static" / "sw.js", media_type="application/javascript",
                        headers={"Service-Worker-Allowed": "/", "Cache-Control": "no-cache"})


@app.get("/")
def index():
    return FileResponse(BASE / "static" / "index.html")
