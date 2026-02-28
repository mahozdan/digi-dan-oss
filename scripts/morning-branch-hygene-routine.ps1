# Good Morning Routine
# Phase 1: Git branch sync with develop + Claude-assisted conflict resolution
# Phase 2: Shuru asset sync (diff, pull, contribute)
# Phase 3: DoD health check

# Configuration
$MAIN_BRANCH = if ($env:GIT_MAIN_BRANCH) { $env:GIT_MAIN_BRANCH } else { "develop" }
$STASH_PREFIX = "morning-hygiene"

# State tracking (script scope for function access)
$script:ORIGINAL_BRANCH = ""
$script:STASHED = $false
$script:STASH_NAME = ""
$script:ACTIONS_LOG = [System.Collections.ArrayList]@()

# Dot-source helpers
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
foreach ($helper in @("git-helpers.ps1", "shuru-sync.ps1")) {
    $helperPath = Join-Path $ScriptDir "morning-helpers\$helper"
    if (Test-Path $helperPath) { . $helperPath }
}

# Logging helpers
function Log-Action([string]$Message) {
    [void]$script:ACTIONS_LOG.Add($Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Log-Warning([string]$Message) {
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Log-Error([string]$Message) {
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Log-Info([string]$Message) {
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

# ===================================================================
#  PHASE 1: Git Branch Hygiene
# ===================================================================
Write-Host ""
Write-Host "===========================================" -ForegroundColor Blue
Write-Host "         Good Morning Routine              " -ForegroundColor Blue
Write-Host "===========================================" -ForegroundColor Blue
Write-Host ""
Write-Host "Phase 1: Git Branch Hygiene" -ForegroundColor Cyan
Write-Host "-------------------------------------------" -ForegroundColor DarkGray

Test-GitRepo
$script:ORIGINAL_BRANCH = git branch --show-current

if (-not $script:ORIGINAL_BRANCH) {
    Log-Error "Could not determine current branch (detached HEAD?)"
    exit 1
}

Log-Info "Current branch: $($script:ORIGINAL_BRANCH)"

# Already on main branch — just pull and continue to Phase 2
if ($script:ORIGINAL_BRANCH -eq $MAIN_BRANCH) {
    Log-Info "Already on $MAIN_BRANCH, just pulling latest..."
    git pull origin $MAIN_BRANCH
    Log-Action "Pulled latest $MAIN_BRANCH"
} else {
    # Stash uncommitted changes
    $status = git status --porcelain
    if ($status) {
        $script:STASH_NAME = "$STASH_PREFIX-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Log-Info "Uncommitted changes detected, stashing..."
        git stash push -m $script:STASH_NAME
        $script:STASHED = $true
        Log-Action "Stashed uncommitted changes as '$($script:STASH_NAME)'"
    } else {
        Log-Info "Working directory clean, no stash needed"
    }

    # Checkout develop
    Log-Info "Switching to $MAIN_BRANCH..."
    git checkout $MAIN_BRANCH 2>$null
    if ($LASTEXITCODE -ne 0) {
        Show-CleanupInstructions "Could not checkout $MAIN_BRANCH"
        exit 1
    }
    Log-Action "Checked out $MAIN_BRANCH"

    # Pull from remote
    Log-Info "Pulling latest from origin/$MAIN_BRANCH..."
    $pullOutput = git pull origin $MAIN_BRANCH 2>&1
    if ($LASTEXITCODE -ne 0) {
        if (Test-MergeConflicts) {
            Log-Warning "Merge conflicts detected on $MAIN_BRANCH pull"
            if (-not (Resolve-ConflictsWithClaude)) {
                Show-CleanupInstructions "Could not resolve conflicts on $MAIN_BRANCH."
                exit 1
            }
            git commit -m "Merge remote $MAIN_BRANCH (conflicts resolved by Claude)"
            Log-Action "Resolved conflicts and completed merge on $MAIN_BRANCH"
        } else {
            Show-CleanupInstructions "Pull from origin/$MAIN_BRANCH failed"
            exit 1
        }
    } else {
        Log-Action "Pulled latest $MAIN_BRANCH from origin"
    }

    # Return to original branch
    Log-Info "Returning to $($script:ORIGINAL_BRANCH)..."
    git checkout $script:ORIGINAL_BRANCH 2>$null
    if ($LASTEXITCODE -ne 0) {
        Show-CleanupInstructions "Could not checkout $($script:ORIGINAL_BRANCH)"
        exit 1
    }
    Log-Action "Checked out $($script:ORIGINAL_BRANCH)"

    # Restore stash
    if ($script:STASHED) {
        Log-Info "Restoring stashed changes..."
        git stash pop 2>$null
        if ($LASTEXITCODE -ne 0) {
            Log-Warning "Could not auto-apply stash. It's still saved - apply manually with 'git stash pop'"
            $script:STASHED = $false
        } else {
            Log-Action "Restored stashed changes"
        }
    }

    # Merge develop into branch
    Log-Info "Merging $MAIN_BRANCH into $($script:ORIGINAL_BRANCH)..."
    $mergeOutput = git merge $MAIN_BRANCH --no-edit 2>&1
    if ($LASTEXITCODE -ne 0) {
        if (Test-MergeConflicts) {
            Log-Warning "Merge conflicts detected"
            $conflictedFiles = Get-ConflictedFiles
            Write-Host ""
            Write-Host "Conflicted files:" -ForegroundColor Yellow
            foreach ($file in $conflictedFiles) { Write-Host "  - $file" }
            Write-Host ""

            if (Resolve-ConflictsWithClaude) {
                git commit -m "Merge $MAIN_BRANCH into $($script:ORIGINAL_BRANCH) (conflicts resolved by Claude)"
                Log-Action "Merged $MAIN_BRANCH with Claude-resolved conflicts"
            } else {
                Write-Host ""
                Log-Error "Could not auto-resolve merge conflicts"
                Write-Host ""
                Write-Host "Manual resolution required. Conflicted files:" -ForegroundColor Yellow
                foreach ($file in $conflictedFiles) { Write-Host "  - $file" }
                Write-Host ""
                Write-Host "After resolving: git add <files> && git commit" -ForegroundColor Yellow
                Write-Host "Or abort:        git merge --abort" -ForegroundColor Yellow
                exit 1
            }
        } else {
            Show-CleanupInstructions "Merge failed for unknown reason"
            exit 1
        }
    } else {
        Log-Action "Merged $MAIN_BRANCH into $($script:ORIGINAL_BRANCH)"
    }
}

# ===================================================================
#  PHASE 2: Shuru Asset Sync
# ===================================================================
Write-Host ""
Write-Host "Phase 2: Shuru Asset Sync" -ForegroundColor Cyan
Write-Host "-------------------------------------------" -ForegroundColor DarkGray

if (Get-Command Test-ShuruInstalled -ErrorAction SilentlyContinue) {
    if (Test-ShuruInstalled) {
        $shuruCmd = Update-ShuruPackage
        $diffResult = Get-ShuruDiff -ShuruCmd $shuruCmd

        if ($diffResult) {
            $summary = Get-DiffSummary -DiffResult $diffResult

            if ($summary.HasDifferences) {
                Show-SyncSummary -Summary $summary
                $action = Invoke-SyncMenu

                switch ($action) {
                    "pull"       { Invoke-PullFromShuru -ShuruCmd $shuruCmd }
                    "contribute" { Invoke-ContributeToShuru -ShuruCmd $shuruCmd }
                    "both" {
                        Invoke-PullFromShuru -ShuruCmd $shuruCmd
                        Invoke-ContributeToShuru -ShuruCmd $shuruCmd
                    }
                    "skip"       { Log-Info "Skipping shuru sync." }
                }
            } else {
                Log-Action "Project is in sync with shuru assets"
            }
        } else {
            Log-Warning "Could not retrieve shuru diff. Run 'npx shuru diff' manually."
        }
    } else {
        Log-Warning "shuru CLI not available. Skipping asset sync."
        Log-Info "Install with: npm install -D shuru"
    }
} else {
    Log-Warning "Shuru sync helpers not found. Skipping asset sync."
}

# ===================================================================
#  PHASE 3: DoD Health Check
# ===================================================================
Write-Host ""
Write-Host "Phase 3: Health Check" -ForegroundColor Cyan
Write-Host "-------------------------------------------" -ForegroundColor DarkGray

if (Get-Command Invoke-DodCheck -ErrorAction SilentlyContinue) {
    Invoke-DodCheck
} else {
    npm run dod core 2>&1 | ForEach-Object { Write-Host "  $_" }
}

# ===================================================================
#  Final Summary
# ===================================================================
Write-Host ""
Write-Host "===========================================" -ForegroundColor Green
Write-Host "        Good Morning Complete!             " -ForegroundColor Green
Write-Host "===========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Summary of actions:" -ForegroundColor Blue
foreach ($action in $script:ACTIONS_LOG) {
    Write-Host "  * $action"
}
Write-Host ""

try {
    $branch = if ($script:ORIGINAL_BRANCH) { $script:ORIGINAL_BRANCH } else { git branch --show-current }
    $aheadBehind = git rev-list --left-right --count "origin/$branch...$branch" 2>$null
    if ($aheadBehind) {
        $parts = $aheadBehind -split '\s+'
        if ($parts.Count -ge 2) {
            $ahead = [int]$parts[1]
            if ($ahead -gt 0) {
                Log-Info "Branch is $ahead commit(s) ahead of origin. Consider pushing."
            }
        }
    }
} catch { }

Write-Host "Ready to work!" -ForegroundColor Green
Write-Host ""
