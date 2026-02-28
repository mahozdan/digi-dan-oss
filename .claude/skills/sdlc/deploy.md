# deploy

## Pipeline Stages
```
lint → test → build → deploy-staging → test-e2e → deploy-prod
```

## Pre-Deploy Checklist
- [ ] All tests pass
- [ ] Build succeeds
- [ ] No security vulnerabilities (npm audit)
- [ ] Env vars configured
- [ ] Database migrations ready
- [ ] Rollback plan documented
- [ ] Team notified

## Environment Promotion
```
local → dev → staging → production
```

## Deployment Strategies
| Strategy | Use When |
|---|---|
| Rolling | Default, zero-downtime |
| Blue-Green | Need instant rollback |
| Canary | High-risk, gradual rollout |
| Recreate | Downtime acceptable |

## Rollback
```bash
# Revert to previous version
git revert HEAD
# Or redeploy previous tag
git checkout v1.2.3
```

## Post-Deploy
- [ ] Health check passes
- [ ] Smoke tests pass
- [ ] Monitor error rates
- [ ] Monitor latency
- [ ] Check logs for anomalies

## CI Config Essentials
```yaml
- Cache dependencies
- Parallel test jobs
- Fail fast on lint/test
- Deploy only from main/release branches
- Require PR approval
- Secrets in env, not code
```

## Rules
- Never deploy Friday afternoon
- Always have rollback ready
- Monitor for 15min post-deploy
- Document what was deployed
