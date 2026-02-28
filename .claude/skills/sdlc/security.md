# security

## Input Handling
- Validate all input (type, length, format, range)
- Sanitize before use in: SQL, HTML, shell, filesystem
- Allowlist over blocklist
- Reject invalid, don't fix

## Authentication
- Hash passwords: argon2/bcrypt, never md5/sha1
- Tokens: cryptographically random, short-lived
- MFA for sensitive ops
- Rate limit auth endpoints
- No credentials in code/logs

## Authorization
- Check on every request
- Deny by default
- Validate object ownership
- No client-side only checks

## Data Protection
- Encrypt at rest: AES-256
- Encrypt in transit: TLS 1.2+
- Minimize data collected
- Mask PII in logs

## OWASP Top 10 Checklist
- [ ] Injection: parameterized queries
- [ ] Broken auth: session management
- [ ] XSS: output encoding
- [ ] CSRF: tokens on state changes
- [ ] Misconfig: secure defaults
- [ ] Sensitive data: encryption
- [ ] Access control: per-resource checks
- [ ] SSRF: validate URLs
- [ ] Logging: security events

## Commands
```bash
npm audit
snyk test
semgrep --config=auto
```

## Red Flags
- ❌ `eval()`, `exec()`, `dangerouslySetInnerHTML`
- ❌ SQL string concatenation
- ❌ Secrets in source code
- ❌ `*` in CORS
- ❌ Disabled HTTPS verification
