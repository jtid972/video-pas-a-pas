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
    data = {"transcribe_audio": "false", "images": "true", "model": "tiny", **form}
    with open(path, "rb") as f:
        r = client.post("/api/jobs", files={"file": (path.name, f)}, data=data)
    assert r.status_code == 200, r.text
    jid = r.json()["id"]
    for _ in range(240):
        j = client.get(f"/api/jobs/{jid}").json()
        if j["status"] in ("done", "error"):
            break
        time.sleep(0.5)
    assert j["status"] == "done", j
    z = client.get(f"/api/jobs/{jid}/download")
    assert z.status_code == 200
    return j, zipfile.ZipFile(io.BytesIO(z.content))


def images(zf):
    return sorted(n for n in zf.namelist() if n.startswith("images/"))


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
    assert j["status"] == "done", j
