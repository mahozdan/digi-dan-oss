# config

## Hierarchy (precedence low→high)
```
defaults → config file → env vars → CLI args
```

## Environment Files
```
.env              # Local defaults (git-ignored)
.env.example      # Template (committed)
.env.test         # Test overrides
.env.production   # Prod (never commit secrets)
```

## Naming Convention
```bash
{APP}_{CATEGORY}_{NAME}
```
Examples:
```bash
APP_DB_HOST=localhost
APP_DB_PORT=5432
APP_REDIS_URL=redis://localhost
APP_JWT_SECRET=***
APP_LOG_LEVEL=info
```

## Config Module Pattern
```javascript
const config = {
  db: {
    host: env('DB_HOST', 'localhost'),
    port: env('DB_PORT', 5432),
  },
  required: {
    jwtSecret: requireEnv('JWT_SECRET'),
  }
};
```

## Rules
- Never commit secrets
- Validate config at startup
- Fail fast on missing required
- Provide sensible defaults
- Document all variables in .env.example
- Different config per environment

## Secrets Management
- Use secret manager (Vault, AWS SM, etc.)
- Rotate regularly
- Audit access
- Never log secrets
- Different secrets per environment

## Checklist
- [ ] `.env` in `.gitignore`
- [ ] `.env.example` committed
- [ ] Required vars validated at boot
- [ ] Secrets not in code/logs
- [ ] Config documented
- [ ] Type coercion handled (string→int/bool)
