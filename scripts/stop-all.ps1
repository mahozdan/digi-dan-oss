# Imperial Arms - Stop All Services Script
# Stops all development services

$ErrorActionPreference = "SilentlyContinue"

Write-Host "Stopping development services..." -ForegroundColor Cyan

# Stop PostgreSQL container
$containerName = "imperial-arms-postgres"
$runningContainer = docker ps --filter "name=$containerName" --format "{{.Names}}" 2>&1

if ($runningContainer -eq $containerName) {
    Write-Host "Stopping PostgreSQL container..." -ForegroundColor Yellow
    docker stop $containerName
    Write-Host "PostgreSQL stopped" -ForegroundColor Green
} else {
    Write-Host "PostgreSQL container is not running" -ForegroundColor Gray
}

# Kill any running Next.js dev servers on port 3000
$process = Get-NetTCPConnection -LocalPort 3000 -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty OwningProcess -ErrorAction SilentlyContinue

if ($process) {
    Write-Host "Stopping Next.js server (PID: $process)..." -ForegroundColor Yellow
    Stop-Process -Id $process -Force -ErrorAction SilentlyContinue
    Write-Host "Next.js server stopped" -ForegroundColor Green
} else {
    Write-Host "No Next.js server running on port 3000" -ForegroundColor Gray
}

Write-Host ""
Write-Host "All services stopped" -ForegroundColor Green
