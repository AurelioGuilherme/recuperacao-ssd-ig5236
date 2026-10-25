<#
.SYNOPSIS
  Diagnostico SOMENTE LEITURA para SSDs InnoGrit IG5236 em ROM mode ("MN-5236", ~2 GB) no Windows.

.DESCRIPTION
  Lista os discos, destaca candidatos em ROM mode e mostra dispositivos PCI com vendor 1DBE (InnoGrit).
  Nao grava nada em nenhum disco. Salva uma copia da saida em logs\ (transcript).

.EXAMPLE
  # PowerShell como Administrador, dentro da pasta do repositorio:
  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
  .\scripts\windows\diagnostico.ps1
#>
$ErrorActionPreference = 'Continue'
$raiz = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$logs = Join-Path $raiz 'logs'
New-Item -ItemType Directory -Force -Path $logs | Out-Null
$arq = Join-Path $logs ("diagnostico-windows-{0}.txt" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
Start-Transcript -Path $arq | Out-Null

Write-Host "=== Discos (Win32_DiskDrive) ===" -ForegroundColor Cyan
$discos = Get-CimInstance Win32_DiskDrive
$discos | ForEach-Object {
    [pscustomobject]@{
        Indice    = $_.Index
        Modelo    = $_.Model
        Serial    = $_.SerialNumber
        Firmware  = $_.FirmwareRevision
        TamanhoGB = [math]::Round($_.Size / 1GB, 2)
        Interface = $_.InterfaceType
        PnP       = $_.PNPDeviceID
    }
} | Format-List

Write-Host "=== Candidatos em ROM mode (modelo MN-5236, ou disco de ~2 GB) ===" -ForegroundColor Cyan
$cand = $discos | Where-Object { $_.Model -match 'MN-5236' -or ($_.Size -gt 1GB -and $_.Size -lt 3GB) }
if ($cand) {
    $cand | ForEach-Object { Write-Host ("Disco {0}: {1} - {2} GB" -f $_.Index, $_.Model, [math]::Round($_.Size / 1GB, 2)) -ForegroundColor Yellow }
    Write-Host "Se for o seu SSD (modelo MN-5236, ~2 GB), siga docs/04-windows-mputility.md ou docs/05-windows-via-linux-live.md" -ForegroundColor Yellow
} else {
    Write-Host "Nenhum candidato. O SSD pode nao estar sendo enumerado (veja docs/08-solucao-de-problemas.md)." -ForegroundColor Green
}

Write-Host "`n=== Dispositivos PCI InnoGrit (VEN_1DBE) ===" -ForegroundColor Cyan
Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
    Where-Object { $_.InstanceId -like 'PCI\VEN_1DBE*' } |
    Select-Object FriendlyName, InstanceId, Status | Format-List
Write-Host "DEV_5636 = ROM mode (visto ate agora). DEV_5236 = firmware completo." 

Stop-Transcript | Out-Null
Write-Host "`nSalvo em: $arq" -ForegroundColor Green
