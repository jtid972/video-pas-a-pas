"""Tests de bout en bout (sans modèle Whisper, sauf si RUN_WHISPER=1)."""
import io
import os
import shutil
import subprocess
import tempfile
import time
import zipfile

import pytest

os.environ.setdefault("DATA_DIR", tempfile.mkdtemp(prefix="vpap-"))
os.environ.setdefault("FRAME_INTERVAL", "5")
os.environ.setdefault("WHISPER_MODEL", "tiny")

from fastapi.testclient import TestClient  # noqa: E402

from app import main  # noqa: E402

client = TestClient(main.app)


def ffmpeg(*args):
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", *args], check=True)


@pytest.fixture(scope="module")
def media(tmp_path_factory):
    d = tmp_path_factory.mktemp("media")
    # vidéo : 3 plans différents de 8 s + son
    ffmpeg("-f", "lavfi", "-i", "testsrc=d=8:s=640x360", "-f", "lavfi", "-i", "smptebars=d=8:s=640x360",
           "-f", "lavfi", "-i", "color=c=blue:d=8:s=640x360", "-f", "lavfi", "-i", "sine=f=440:d=24",
           "-filter_complex", "[0][1][2]concat=n=3:v=1:a=0[v]", "-map", "[v]", "-map", "3",
           "-shortest", str(d / "video.mp4"))
    ffmpeg("-f", "lavfi", "-i", "sine=f=300:d=6", str(d / "son.mp3"))
    ffmpeg("-f", "lavfi", "-i", "color=c=red:s=300x300:d=1", "-frames:v", "1", str(d / "cover.jpg"))
    ffmpeg("-i", str(d / "son.mp3"), "-i", str(d / "cover.jpg"), "-map", "0", "-map", "1", "-c", "copy",
           "-id3v2_version", "3", "-disposition:v", "attached_pic", str(d / "son_pochette.mp3"))
    ffmpeg("-f", "lavfi", "-i", "sine=f=300:d=6", "-c:a", "aac", str(d / "son.m4a"))
    return d


def run_job(path, **form):
    # format=zip par défaut dans les tests existants : ils inspectent le contenu fichier par
    # fichier. Le format par défaut de l'application (voir test_sortie_pdf_par_defaut) est pdf.
    data = {"transcribe_audio": "false", "images": "true", "model": "tiny",
            "output_format": "zip", **form}
    with open(path, "rb") as f:
        r = client.post("/api/jobs", files={"file": (path.name, f)}, data=data)
    assert r.status_code == 200, r.text
    jid = r.json()["id"]
    for _ in range(240):
        j = client.get(f"/api/jobs/{jid}").json()
        if j["status"] in ("done", "error"):
            break
        time.sleep(0.5)
    assert j["status"] == "done", j.get("message")
    z = client.get(f"/api/jobs/{jid}/download")
    assert z.status_code == 200
    return j, zipfile.ZipFile(io.BytesIO(z.content))


def images(zf):
    return sorted(n for n in zf.namelist() if n.startswith("images/"))


def test_lecture_wav(tmp_path):
    wav = tmp_path / "t.wav"
    ffmpeg("-f", "lavfi", "-i", "sine=f=440:d=1", "-ac", "1", "-ar", "16000", "-c:a", "pcm_s16le", str(wav))
    a = main.load_wav(wav)
    assert a.dtype.name == "float32" and len(a) == 16000 and 0.05 < abs(a).max() <= 1.0


def test_config():
    c = client.get("/api/config").json()
    assert c["name"] == "Vidéo pas à pas" and "small" in c["models"]


def test_video_captures_plans(media):
    _, zf = run_job(media / "video.mp4")
    imgs = images(zf)
    assert [i.split("_", 2)[2] for i in imgs] == ["000m01s.jpg", "000m08s.jpg", "000m16s.jpg"]
    for f in ("preparation.md", "LISEZMOI.md", "CONSIGNE_IA.md", "transcription.json"):
        assert f in zf.namelist()
    assert "dossier de préparation" in zf.read("LISEZMOI.md").decode().lower()


def test_sortie_pdf_par_defaut(media):
    """Le format par défaut (sans output_format) est le PDF unique, lisible par une IA qui
    n'accepte pas les ZIP (ex. Copilot)."""
    from pypdf import PdfReader

    data = {"transcribe_audio": "false", "images": "true", "model": "tiny"}  # pas d'output_format
    with open(media / "video.mp4", "rb") as f:
        r = client.post("/api/jobs", files={"file": ("video.mp4", f)}, data=data)
    jid = r.json()["id"]
    for _ in range(240):
        j = client.get(f"/api/jobs/{jid}").json()
        if j["status"] in ("done", "error"):
            break
        time.sleep(0.5)
    assert j["status"] == "done", j.get("message")
    assert j["format"] == "pdf"
    rep = client.get(f"/api/jobs/{jid}/download")
    assert rep.status_code == 200
    assert rep.headers["content-type"] == "application/pdf"
    assert rep.headers["content-disposition"].endswith('.pdf"')
    reader = PdfReader(io.BytesIO(rep.content))
    texte = "\n".join(p.extract_text() for p in reader.pages)
    assert "Préparation" in texte and "Consigne pour l'IA" in texte and "Transcription complète" in texte
    assert len(reader.pages) >= 3  # page de garde + au moins une capture + transcription


def test_sortie_zip_explicite(media):
    j, zf = run_job(media / "video.mp4", output_format="zip")
    assert j["format"] == "zip"
    assert "preparation.md" in zf.namelist()


@pytest.mark.parametrize("name", ["son.mp3", "son_pochette.mp3", "son.m4a"])
def test_audio_seul_sans_captures(media, name):
    _, zf = run_job(media / name)
    assert images(zf) == []  # la pochette n'est pas prise pour une vidéo
    assert "audio uniquement" in zf.read("LISEZMOI.md").decode()


def test_fichier_invalide(tmp_path):
    p = tmp_path / "pas_une_video.mp4"
    p.write_text("bonjour")
    with open(p, "rb") as f:
        jid = client.post("/api/jobs", files={"file": (p.name, f)}).json()["id"]
    for _ in range(40):
        j = client.get(f"/api/jobs/{jid}").json()
        if j["status"] != "queued" and j["status"] != "running":
            break
        time.sleep(0.25)
    assert j["status"] == "error"


def test_mot_de_passe(monkeypatch):
    monkeypatch.setattr(main, "PASSWORD", "secret")
    assert client.get("/api/config").status_code == 401
    assert client.get("/healthz").status_code == 200
    assert client.get("/api/config", auth=("x", "secret")).status_code == 200
    assert client.get("/api/config", auth=("x", "faux")).status_code == 401


@pytest.mark.skipif(os.environ.get("RUN_WHISPER") != "1" or not shutil.which("espeak-ng"),
                    reason="RUN_WHISPER=1 et espeak-ng requis (télécharge le modèle tiny)")
def test_transcription_reelle(tmp_path):
    wav = tmp_path / "voix.wav"
    subprocess.run(["espeak-ng", "-v", "fr", "-w", str(wav),
                    "Bonjour. Ouvrez le menu fichier puis cliquez sur enregistrer."], check=True)
    _, zf = run_job(wav, transcribe_audio="true", language="fr")
    txt = zf.read("transcription.txt").decode().lower()
    assert "fichier" in txt or "enregistr" in txt, txt


def test_pwa():
    assert client.get("/manifest.webmanifest").json()["name"] == "Vidéo pas à pas"
    assert client.get("/sw.js").headers["content-type"].startswith("application/javascript")
    assert client.get("/static/icons/icon-192.png").status_code == 200


def test_partage_depuis_telephone(media):
    with open(media / "video.mp4", "rb") as f:
        r = client.post("/share", files={"file": ("video.mp4", f)}, follow_redirects=False)
    assert r.status_code == 303 and "partage=" in r.headers["location"]
    jid = r.headers["location"].split("partage=")[1]
    assert client.get(f"/api/shared/{jid}").json()["filename"] == "video.mp4"
    r = client.post(f"/api/shared/{jid}/start", data={"transcribe_audio": "false", "images": "true"})
    assert r.status_code == 200
    for _ in range(120):
        j = client.get(f"/api/jobs/{jid}").json()
        if j["status"] in ("done", "error"):
            break
        time.sleep(0.5)
    assert j["status"] == "done", j.get("message")


# ---------------------------------------------------------------- YouTube (sans réseau réel)
@pytest.mark.parametrize("url,ok", [
    ("https://www.youtube.com/watch?v=dQw4w9WgXcQ", True),
    ("https://youtu.be/dQw4w9WgXcQ", True),
    ("youtube.com/watch?v=dQw4w9WgXcQ", True),           # sans schéma : accepté, complété
    ("https://www.youtube.com/playlist?list=PL123", False),  # pas une vidéo seule
    ("https://vimeo.com/12345", False),
    ("https://example.com/youtube.com", False),           # ne doit pas se laisser tromper
])
def test_validation_adresse_youtube(url, ok):
    if ok:
        assert main.validate_youtube_url(url).startswith("https://")
    else:
        with pytest.raises(Exception):  # noqa: B017 — HTTPException de FastAPI
            main.validate_youtube_url(url)


def test_vtt_vers_segments():
    vtt = """WEBVTT
Kind: captions
Language: fr

00:00:01.000 --> 00:00:04.000
Bonjour, on va <c>installer</c> l'imprimante.

00:00:01.000 --> 00:00:04.000
Bonjour, on va installer l'imprimante.

00:00:04.500 --> 00:00:07.200 align:start position:0%
<00:00:04.560><c>Ouvrez</c> les paramètres.
"""
    segs = main.vtt_to_segs(vtt)
    assert [s["text"] for s in segs] == ["Bonjour, on va installer l'imprimante.",
                                         "Ouvrez les paramètres."]
    assert segs[0]["start"] == 1.0 and segs[0]["end"] == 4.0


def test_youtube_desactivable(monkeypatch):
    monkeypatch.setattr(main, "ENABLE_YOUTUBE", False)
    assert client.get("/api/config").json()["enable_youtube"] is False
    r = client.post("/api/jobs-from-url", data={"url": "https://youtu.be/dQw4w9WgXcQ"})
    assert r.status_code == 404


def test_youtube_sous_titres_sans_whisper(monkeypatch):
    """La vidéo est « téléchargée » (fonction remplacée par un test local) et ses sous-titres
    servent directement de transcription : pas d'appel à Whisper."""
    monkeypatch.setattr(main, "ENABLE_YOUTUBE", True)

    def fake_fetch_youtube(jid, d, url, language):
        src = d / "source.mp4"
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-f", "lavfi",
                        "-i", "color=c=green:d=2:s=320x240", "-f", "lavfi", "-i", "sine=f=440:d=2",
                        "-shortest", str(src)], check=True)
        segs = [{"start": 0.0, "end": 1.0, "text": "Bonjour."}]
        return src, segs, "fr", "ma vidéo youtube"

    monkeypatch.setattr(main, "fetch_youtube", fake_fetch_youtube)
    monkeypatch.setattr(main, "transcribe", lambda *a, **k: pytest.fail("Whisper ne doit pas être appelé"))

    r = client.post("/api/jobs-from-url", data={"url": "https://youtu.be/dQw4w9WgXcQ",
                                                "transcribe_audio": "true", "images": "false"})
    assert r.status_code == 200, r.text
    jid = r.json()["id"]
    for _ in range(120):
        j = client.get(f"/api/jobs/{jid}").json()
        if j["status"] in ("done", "error"):
            break
        time.sleep(0.5)
    assert j["status"] == "done", j.get("message")
    assert j["filename"] == "ma vidéo youtube"
    rep = client.get(f"/api/jobs/{jid}/download")
    assert rep.headers["content-type"] == "application/pdf"
