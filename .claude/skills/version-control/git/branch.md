# branch

## Naming Convention
```
{type}/{ticket}-{short-description}
```

## Types
- `feature/` - New functionality
- `fix/` - Bug fixes
- `hotfix/` - Urgent production fix
- `refactor/` - Code improvement
- `test/` - Adding tests
- `docs/` - Documentation
- `chore/` - Maintenance

## Examples
```
feature/AUTH-123-jwt-refresh
fix/API-456-null-response
hotfix/PROD-789-payment-failure
```

## Workflow
```bash
# Start work
git checkout main
git pull origin main
git checkout -b feature/TICKET-description

# During work
git add -p
git commit  # use commit skill

# Ready for review
git push -u origin HEAD
```

## Rules
- Branch from latest main/develop
- One concern per branch
- Keep branches short-lived (<1 week)
- Delete after merge
- Rebase to update, merge to integrate

## Commands
```bash
# Create and switch
git checkout -b {branch-name}

# List branches
git branch -a

# Delete local
git branch -d {branch-name}

# Delete remote
git push origin --delete {branch-name}

# Rename
git branch -m {old} {new}
```
