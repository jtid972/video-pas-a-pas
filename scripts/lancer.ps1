# Video pas a pas - lancement sans Docker sous Windows (PowerShell 5.1 ou 7)
# Usage : clic droit > Executer avec PowerShell, ou double-clic sur lancer.bat
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Write-Host "ffmpeg est manquant. Installez-le avec :  winget install Gyan.FFmpeg"
    Write-Host "puis fermez et rouvrez cette fenetre."
    exit 1
}
if (Get-Command py -ErrorAction SilentlyContinue) { $py = "py" }
elseif (Get-Command python -ErrorAction SilentlyContinue) { $py = "python" }
else {
    Write-Host "Python est manquant. Installez-le avec :  winget install Python.Python.3.13"
    exit 1
}

if (-not (Test-Path ".venv")) { & $py -m venv .venv }
$venvPy = ".\.venv\Scripts\python.exe"
& $venvPy -m pip install -q --upgrade pip
& $venvPy -m pip install -q -r requirements.txt

$port = if ($env:PORT) { $env:PORT } else { "8080" }
$hostAddr = if ($env:HOST) { $env:HOST } else { "127.0.0.1" }
$url = "http://localhost:$port"
Write-Host "Video pas a pas demarre sur $url  (Ctrl+C pour arreter)"
Start-Job -ScriptBlock { Start-Sleep 3; Start-Process $using:url } | Out-Null
& $venvPy -m uvicorn app.main:app --host $hostAddr --port $port
