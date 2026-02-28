# Imperial Arms - Development Startup Script
# Starts all required services for local development

Write-Host "Starting development services..." -ForegroundColor Cyan

# Check if Docker is running
$null = docker info 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker is not running. Please start Docker Desktop first." -ForegroundColor Red
    exit 1
}

# Start PostgreSQL container if not running
$containerName = "imperial-arms-postgres"
$existingContainer = docker ps -a --filter "name=$containerName" --format "{{.Names}}" 2>$null

if ($existingContainer -eq $containerName) {
    $runningContainer = docker ps --filter "name=$containerName" --format "{{.Names}}" 2>$null
    if ($runningContainer -eq $containerName) {
        Write-Host "PostgreSQL container already running" -ForegroundColor Green
    } else {
        Write-Host "Starting existing PostgreSQL container..." -ForegroundColor Yellow
        $null = docker start $containerName 2>$null
        Write-Host "PostgreSQL started" -ForegroundColor Green
    }
} else {
    Write-Host "Creating new PostgreSQL container..." -ForegroundColor Yellow
    $null = docker run --name $containerName `
        -e POSTGRES_USER=postgres `
        -e POSTGRES_PASSWORD=postgres `
        -e POSTGRES_DB=imperial_arms `
        -p 5432:5432 `
        -d postgres:16 2>$null

    Write-Host "Waiting for PostgreSQL to be ready..." -ForegroundColor Yellow
    Start-Sleep -Seconds 3
    Write-Host "PostgreSQL container created and running" -ForegroundColor Green
}

# Verify database connection
Write-Host "Verifying database connection..." -ForegroundColor Yellow
$maxRetries = 10
$retryCount = 0
$connected = $false

while (-not $connected -and $retryCount -lt $maxRetries) {
    $null = docker exec $containerName pg_isready -U postgres 2>$null
    if ($LASTEXITCODE -eq 0) {
        $connected = $true
    } else {
        $retryCount++
        Start-Sleep -Seconds 1
    }
}

if ($connected) {
    Write-Host "Database connection verified" -ForegroundColor Green
} else {
    Write-Host "Could not verify database connection" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "All services started successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Database URL: postgresql://postgres:postgres@localhost:5432/imperial_arms" -ForegroundColor Cyan
Write-Host ""

# Generate Prisma client if needed
Write-Host "Generating Prisma client..." -ForegroundColor Yellow
npx prisma generate 2>$null
Write-Host "Prisma client ready" -ForegroundColor Green

Write-Host ""
Write-Host "Starting Next.js development server..." -ForegroundColor Cyan

# Start Next.js dev server
npm run dev:next
