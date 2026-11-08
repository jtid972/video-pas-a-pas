# SPDX-License-Identifier: AGPL-3.0-or-later
# Video pas a pas - construit l'image Docker, la fait analyser par Trivy, puis la lance
# seulement si aucune faille CRITIQUE ou HAUTE corrigeable n'est trouvee. Windows + Docker Desktop.
#   .\scripts\verifier-et-lancer.ps1            construit, verifie, lance
#   $env:FORCER="1"; .\scripts\verifier-et-lancer.ps1   lance malgre des failles (deconseille)
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

# Version figee de Trivy (les versions 0.69.4 a 0.69.6 ont ete compromises en mars 2026).
$trivy = if ($env:TRIVY_IMAGE) { $env:TRIVY_IMAGE } else { "ghcr.io/aquasecurity/trivy:0.76.2" }
$image = "video-pas-a-pas:local"

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "Docker Desktop est requis : https://www.docker.com/products/docker-desktop/"; exit 1
}

Write-Host "1/3  Construction de l'image..."
docker compose build --pull
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host "2/3  Analyse de securite Trivy de $image..."
docker run --rm -v //var/run/docker.sock:/var/run/docker.sock -v vpap-trivy-cache:/root/.cache/ `
    $trivy image --quiet --ignore-unfixed --severity CRITICAL,HIGH --exit-code 1 $image
if ($LASTEXITCODE -ne 0) {
    Write-Host "     Trivy a trouve des failles critiques ou hautes corrigeables (detail ci-dessus)."
    Write-Host "     Mettez le depot a jour (git pull) puis relancez ce script."
    if ($env:FORCER -ne "1") { Write-Host "     Lancement annule."; exit 1 }
    Write-Host "     FORCER=1 : lancement malgre tout."
} else {
    Write-Host "     Aucune faille critique ou haute corrigeable."
}

Write-Host "3/3  Demarrage..."
docker compose up -d
Write-Host "Video pas a pas est pret sur http://localhost:8080"
