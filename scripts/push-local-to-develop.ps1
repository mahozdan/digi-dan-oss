# Push Local Branch to Develop - Automated Merge Script
# This script automates the process of merging a local branch into develop
# Usage: ./scripts/push-local-to-develop.ps1 [-ManualConflict]

param(
    [switch]$ManualConflict
)

# Colors for output
function Write-Step { param($msg) Write-Host "`n========================================" -ForegroundColor Cyan; Write-Host "STEP: $msg" -ForegroundColor Cyan; Write-Host "========================================" -ForegroundColor Cyan }
function Write-Success { param($msg) Write-Host "[SUCCESS] $msg" -ForegroundColor Green }
function Write-Info { param($msg) Write-Host "[INFO] $msg" -ForegroundColor Yellow }
function Write-Err { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }
function Write-Warning { param($msg) Write-Host "[WARNING] $msg" -ForegroundColor Magenta }

# Store the original branch
$originalBranch = git rev-parse --abbrev-ref HEAD 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Err "Not a git repository or git is not installed"
    exit 1
}

if ($originalBranch -eq "develop") {
    Write-Err "You are already on the develop branch. Please switch to your feature branch first."
    exit 1
}

if ($originalBranch -eq "master" -or $originalBranch -eq "main") {
    Write-Err "Cannot merge master/main into develop using this script. Please use a feature branch."
    exit 1
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Magenta
Write-Host "  PUSH LOCAL BRANCH TO DEVELOP" -ForegroundColor Magenta
Write-Host "============================================================" -ForegroundColor Magenta
Write-Host ""
Write-Info "Original branch: $originalBranch"
Write-Info "Target branch: develop"
if ($ManualConflict) {
    Write-Warning "Manual conflict mode enabled - will NOT attempt automatic conflict resolution"
} else {
    Write-Info "Automatic conflict resolution enabled (use -ManualConflict to disable)"
}
Write-Host ""

# Function to check for conflicts
function Test-GitConflicts {
    $conflicts = git diff --name-only --diff-filter=U 2>$null
    return ($conflicts -and $conflicts.Length -gt 0)
}

# Function to get conflicting files
function Get-ConflictingFiles {
    return git diff --name-only --diff-filter=U 2>$null
}

# Function to abort merge and return to original state
function Invoke-AbortAndCleanup {
    param($targetBranch)
    Write-Err "Aborting merge..."
    git merge --abort 2>$null
    git checkout $targetBranch 2>$null
}

# Function to attempt automatic conflict resolution
function Invoke-AutoResolveConflicts {
    if ($ManualConflict) {
        return $false
    }

    Write-Info "Attempting automatic conflict resolution..."

    $conflictFiles = Get-ConflictingFiles
    foreach ($file in $conflictFiles) {
        Write-Info "Attempting to resolve: $file"

        # Try to use 'theirs' strategy for simple cases (accept incoming changes)
        # This is a simple strategy - in a real scenario, you might want more sophisticated resolution
        git checkout --theirs "$file" 2>$null
        git add "$file" 2>$null
    }

    # Check if all conflicts are resolved
    if (Test-GitConflicts) {
        Write-Err "Automatic conflict resolution failed. Some conflicts remain."
        return $false
    }

    Write-Success "Automatic conflict resolution succeeded"
    return $true
}

# ============================================================
# STEP 1: Stage all files in current branch
# ============================================================
Write-Step "1/10 - Staging all files in current branch ($originalBranch)"

$status = git status --porcelain 2>$null
if ($status) {
    Write-Info "Found uncommitted changes, staging and committing..."
    git add -A
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Failed to stage files"
        exit 1
    }

    # Commit if there are staged changes
    $staged = git diff --cached --name-only 2>$null
    if ($staged) {
        git commit -m "WIP: Auto-commit before merge to develop"
        if ($LASTEXITCODE -ne 0) {
            Write-Err "Failed to commit staged changes"
            exit 1
        }
        Write-Success "Staged and committed changes"
    } else {
        Write-Info "No changes to commit"
    }
} else {
    Write-Success "Working directory is clean, no changes to stage"
}

# ============================================================
# STEP 2: Checkout develop branch
# ============================================================
Write-Step "2/10 - Checking out develop branch"

git checkout develop 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Err "Failed to checkout develop branch"
    Write-Info "Make sure develop branch exists locally. Try: git fetch origin develop:develop"
    exit 1
}
Write-Success "Checked out develop branch"

# ============================================================
# STEP 3: Pull from remote
# ============================================================
Write-Step "3/10 - Pulling latest changes from remote develop"

git pull origin develop 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Err "Failed to pull from remote develop"
    git checkout $originalBranch 2>$null
    exit 1
}
Write-Success "Pulled latest changes from remote develop"

# ============================================================
# STEP 4: Check for conflicts after pull (shouldn't happen on clean develop)
# ============================================================
Write-Step "4/10 - Checking for conflicts after pull"

if (Test-GitConflicts) {
    $conflictFiles = Get-ConflictingFiles
    Write-Err "Conflicts detected after pulling develop!"
    Write-Err "Conflicting files:"
    foreach ($file in $conflictFiles) {
        Write-Host "  - $file" -ForegroundColor Red
    }
    Write-Warning "Please resolve conflicts manually and try again."
    git merge --abort 2>$null
    git checkout $originalBranch 2>$null
    exit 1
}
Write-Success "No conflicts after pulling develop"

# ============================================================
# STEP 5: Checkout original branch
# ============================================================
Write-Step "5/10 - Checking out original branch ($originalBranch)"

git checkout $originalBranch 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Err "Failed to checkout original branch: $originalBranch"
    exit 1
}
Write-Success "Checked out $originalBranch"

# ============================================================
# STEP 6: Merge develop into original branch
# ============================================================
Write-Step "6/10 - Merging develop into $originalBranch"

git merge develop --no-edit 2>$null
$mergeExitCode = $LASTEXITCODE

# ============================================================
# STEP 7: Check and resolve conflicts
# ============================================================
Write-Step "7/10 - Checking for merge conflicts"

if ($mergeExitCode -ne 0 -or (Test-GitConflicts)) {
    $conflictFiles = Get-ConflictingFiles

    if ($conflictFiles) {
        Write-Warning "Merge conflicts detected!"
        Write-Info "Conflicting files:"
        foreach ($file in $conflictFiles) {
            Write-Host "  - $file" -ForegroundColor Yellow
        }

        if (-not $ManualConflict) {
            if (Invoke-AutoResolveConflicts) {
                git commit -m "Merge develop into $originalBranch (auto-resolved conflicts)"
                if ($LASTEXITCODE -ne 0) {
                    Write-Err "Failed to commit after conflict resolution"
                    Invoke-AbortAndCleanup $originalBranch
                    exit 1
                }
                Write-Success "Conflicts resolved and committed"
            } else {
                Write-Err "Automatic conflict resolution failed"
                Write-Warning "Please resolve conflicts manually:"
                Write-Host "  1. Resolve conflicts in the files listed above" -ForegroundColor Cyan
                Write-Host "  2. Run: git add ." -ForegroundColor Cyan
                Write-Host "  3. Run: git commit" -ForegroundColor Cyan
                Write-Host "  4. Re-run this script" -ForegroundColor Cyan
                git merge --abort 2>$null
                exit 1
            }
        } else {
            Write-Err "Manual conflict mode enabled - stopping for manual resolution"
            Write-Warning "Please resolve conflicts manually:"
            Write-Host "  1. Resolve conflicts in the files listed above" -ForegroundColor Cyan
            Write-Host "  2. Run: git add ." -ForegroundColor Cyan
            Write-Host "  3. Run: git commit" -ForegroundColor Cyan
            Write-Host "  4. Re-run this script" -ForegroundColor Cyan
            git merge --abort 2>$null
            exit 1
        }
    } else {
        Write-Err "Merge failed for unknown reason"
        git merge --abort 2>$null
        exit 1
    }
} else {
    Write-Success "Merged develop into $originalBranch without conflicts"
}

# ============================================================
# STEP 8: Checkout develop
# ============================================================
Write-Step "8/10 - Checking out develop branch"

git checkout develop 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Err "Failed to checkout develop branch"
    exit 1
}
Write-Success "Checked out develop branch"

# ============================================================
# STEP 9: Merge original branch into develop
# ============================================================
Write-Step "9/10 - Merging $originalBranch into develop"

git merge $originalBranch --no-edit 2>$null
$mergeExitCode = $LASTEXITCODE

if ($mergeExitCode -ne 0 -or (Test-GitConflicts)) {
    $conflictFiles = Get-ConflictingFiles

    if ($conflictFiles) {
        Write-Warning "Merge conflicts detected when merging into develop!"
        Write-Info "Conflicting files:"
        foreach ($file in $conflictFiles) {
            Write-Host "  - $file" -ForegroundColor Yellow
        }

        if (-not $ManualConflict) {
            if (Invoke-AutoResolveConflicts) {
                git commit -m "Merge $originalBranch into develop (auto-resolved conflicts)"
                if ($LASTEXITCODE -ne 0) {
                    Write-Err "Failed to commit after conflict resolution"
                    Invoke-AbortAndCleanup $originalBranch
                    exit 1
                }
                Write-Success "Conflicts resolved and committed"
            } else {
                Write-Err "Automatic conflict resolution failed"
                Write-Warning "Please resolve conflicts manually:"
                Write-Host "  1. Resolve conflicts in the files listed above" -ForegroundColor Cyan
                Write-Host "  2. Run: git add ." -ForegroundColor Cyan
                Write-Host "  3. Run: git commit" -ForegroundColor Cyan
                Write-Host "  4. Run: git push origin develop" -ForegroundColor Cyan
                git merge --abort 2>$null
                git checkout $originalBranch 2>$null
                exit 1
            }
        } else {
            Write-Err "Manual conflict mode enabled - stopping for manual resolution"
            Write-Warning "Please resolve conflicts manually:"
            Write-Host "  1. Resolve conflicts in the files listed above" -ForegroundColor Cyan
            Write-Host "  2. Run: git add ." -ForegroundColor Cyan
            Write-Host "  3. Run: git commit" -ForegroundColor Cyan
            Write-Host "  4. Run: git push origin develop" -ForegroundColor Cyan
            git merge --abort 2>$null
            git checkout $originalBranch 2>$null
            exit 1
        }
    } else {
        Write-Err "Merge failed for unknown reason"
        git merge --abort 2>$null
        git checkout $originalBranch 2>$null
        exit 1
    }
} else {
    Write-Success "Merged $originalBranch into develop without conflicts"
}

# ============================================================
# STEP 10: Push to remote
# ============================================================
Write-Step "10/10 - Pushing develop to remote"

git push origin develop 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Err "Failed to push develop to remote"
    Write-Warning "You may need to push manually: git push origin develop"
    git checkout $originalBranch 2>$null
    exit 1
}
Write-Success "Pushed develop to remote"

# Return to original branch
Write-Info "Returning to original branch: $originalBranch"
git checkout $originalBranch 2>$null

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  SUCCESS! Branch $originalBranch merged into develop" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Info "Summary:"
Write-Host "  - Original branch: $originalBranch" -ForegroundColor Cyan
Write-Host "  - develop branch updated and pushed to remote" -ForegroundColor Cyan
Write-Host "  - You are now on: $originalBranch" -ForegroundColor Cyan
Write-Host ""
